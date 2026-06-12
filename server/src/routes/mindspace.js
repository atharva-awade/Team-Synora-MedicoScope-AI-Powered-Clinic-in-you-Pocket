const express = require('express');
const auth = require('../middleware/auth');
const MindSpaceSession = require('../models/MindSpaceSession');

const router = express.Router();

// POST /api/mindspace/session — save a mindspace session
router.post('/session', auth, async (req, res) => {
  try {
    const { transcript, userMessage, doctorReport, urgency, coinsEarned, doctorId } = req.body;

    const session = new MindSpaceSession({
      userId: req.user._id,
      transcript: transcript || '',
      userMessage: userMessage || '',
      doctorReport: doctorReport || null,
      urgency: urgency || 'low',
      coinsEarned: coinsEarned || 0,
      doctorId: doctorId || null,
    });

    await session.save();
    res.status(201).json({ success: true, sessionId: session._id });
  } catch (error) {
    console.error('Save mindspace session error:', error);
    res.status(500).json({ message: 'Failed to save session' });
  }
});

// GET /api/mindspace/history — get mindspace history for patient
router.get('/history', auth, async (req, res) => {
  try {
    const sessions = await MindSpaceSession.find({ userId: req.user._id })
      .sort({ createdAt: -1 })
      .select('transcript userMessage urgency coinsEarned createdAt')
      .lean();

    res.json({ sessions });
  } catch (error) {
    console.error('Get mindspace history error:', error);
    res.status(500).json({ message: 'Failed to fetch history' });
  }
});

// GET /api/mindspace/doctor/:patientId — get mindspace reports for doctor
router.get('/doctor/:patientId', auth, async (req, res) => {
  try {
    const sessions = await MindSpaceSession.find({
      userId: req.params.patientId,
      doctorId: req.user._id,
      doctorReport: { $ne: null },
    })
      .sort({ createdAt: -1 })
      .select('transcript doctorReport urgency createdAt')
      .lean();

    res.json({ sessions });
  } catch (error) {
    console.error('Get doctor mindspace error:', error);
    res.status(500).json({ message: 'Failed to fetch reports' });
  }
});

// DELETE /api/mindspace/session/:id — delete a mindspace session
router.delete('/session/:id', auth, async (req, res) => {
  try {
    const session = await MindSpaceSession.findById(req.params.id);

    if (!session) {
      return res.status(404).json({ message: 'Session not found' });
    }

    // Allow delete by patient (owner) or linked doctor
    const isOwner = session.userId.toString() === req.user._id.toString();
    const isDoctor = session.doctorId && session.doctorId.toString() === req.user._id.toString();

    if (!isOwner && !isDoctor) {
      return res.status(403).json({ message: 'Not authorized to delete this session' });
    }

    await MindSpaceSession.findByIdAndDelete(req.params.id);
    res.json({ success: true });
  } catch (error) {
    console.error('Delete mindspace session error:', error);
    res.status(500).json({ message: 'Failed to delete session' });
  }
});

module.exports = router;
