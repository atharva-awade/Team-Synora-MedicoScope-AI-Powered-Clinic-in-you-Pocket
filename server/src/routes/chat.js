const express = require('express');
const auth = require('../middleware/auth');
const ChatHistory = require('../models/ChatHistory');

const router = express.Router();

// POST /api/chat/message — save a chat message pair
router.post('/message', auth, async (req, res) => {
  try {
    const { sessionId, userMessage, assistantMessage } = req.body;
    if (!sessionId || !userMessage) {
      return res.status(400).json({ message: 'sessionId and userMessage are required' });
    }

    let chat = await ChatHistory.findOne({ userId: req.user._id, sessionId });

    if (!chat) {
      // Create new chat session with title from first message
      const title = userMessage.substring(0, 50) + (userMessage.length > 50 ? '...' : '');
      chat = new ChatHistory({
        userId: req.user._id,
        sessionId,
        title,
        messages: [],
      });
    }

    chat.messages.push({ role: 'user', content: userMessage });
    if (assistantMessage) {
      chat.messages.push({ role: 'assistant', content: assistantMessage });
    }

    await chat.save();
    res.json({ success: true });
  } catch (error) {
    console.error('Save chat error:', error);
    res.status(500).json({ message: 'Failed to save chat message' });
  }
});

// GET /api/chat/history — get all chat sessions for user
router.get('/history', auth, async (req, res) => {
  try {
    const chats = await ChatHistory.find({ userId: req.user._id })
      .sort({ updatedAt: -1 })
      .select('sessionId title messages createdAt updatedAt')
      .lean();

    const sessions = chats.map(c => ({
      id: c._id,
      sessionId: c.sessionId,
      title: c.title,
      messageCount: c.messages.length,
      lastMessage: c.messages.length > 0 ? c.messages[c.messages.length - 1].content.substring(0, 100) : '',
      createdAt: c.createdAt,
      updatedAt: c.updatedAt,
    }));

    res.json({ sessions });
  } catch (error) {
    console.error('Get chat history error:', error);
    res.status(500).json({ message: 'Failed to fetch chat history' });
  }
});

// GET /api/chat/session/:sessionId — get full chat session
router.get('/session/:sessionId', auth, async (req, res) => {
  try {
    const chat = await ChatHistory.findOne({
      userId: req.user._id,
      sessionId: req.params.sessionId,
    }).lean();

    if (!chat) {
      return res.status(404).json({ message: 'Chat session not found' });
    }

    res.json({ chat });
  } catch (error) {
    console.error('Get chat session error:', error);
    res.status(500).json({ message: 'Failed to fetch chat session' });
  }
});

// DELETE /api/chat/session/:sessionId — delete a chat session
router.delete('/session/:sessionId', auth, async (req, res) => {
  try {
    const result = await ChatHistory.findOneAndDelete({
      userId: req.user._id,
      sessionId: req.params.sessionId,
    });

    if (!result) {
      return res.status(404).json({ message: 'Chat session not found' });
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Delete chat error:', error);
    res.status(500).json({ message: 'Failed to delete chat session' });
  }
});

module.exports = router;
