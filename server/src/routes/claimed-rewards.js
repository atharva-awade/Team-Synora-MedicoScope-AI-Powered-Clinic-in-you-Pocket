const express = require('express');
const auth = require('../middleware/auth');
const ClaimedReward = require('../models/ClaimedReward');

const router = express.Router();

// POST /api/claimed-rewards — save a claimed reward
router.post('/', auth, async (req, res) => {
  try {
    const { rewardType, title, content, coinsCost } = req.body;

    if (!rewardType || !title || !content) {
      return res.status(400).json({ message: 'Missing required fields' });
    }

    const reward = await ClaimedReward.create({
      userId: req.user._id,
      rewardType,
      title,
      content,
      coinsCost: coinsCost || 0,
    });

    res.status(201).json({ reward });
  } catch (error) {
    console.error('Save claimed reward error:', error);
    res.status(500).json({ message: 'Failed to save reward' });
  }
});

// GET /api/claimed-rewards — get all claimed rewards for user
router.get('/', auth, async (req, res) => {
  try {
    const rewards = await ClaimedReward.find({ userId: req.user._id })
      .sort({ createdAt: -1 })
      .lean();

    const mapped = rewards.map(r => ({
      id: r._id.toString(),
      rewardType: r.rewardType,
      title: r.title,
      content: r.content,
      coinsCost: r.coinsCost,
      createdAt: r.createdAt.toISOString(),
    }));

    res.json({ rewards: mapped });
  } catch (error) {
    console.error('Get claimed rewards error:', error);
    res.status(500).json({ message: 'Failed to fetch rewards' });
  }
});

// DELETE /api/claimed-rewards/:id — delete a claimed reward
router.delete('/:id', auth, async (req, res) => {
  try {
    const reward = await ClaimedReward.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!reward) {
      return res.status(404).json({ message: 'Reward not found' });
    }

    await ClaimedReward.findByIdAndDelete(req.params.id);
    res.json({ message: 'Deleted' });
  } catch (error) {
    console.error('Delete claimed reward error:', error);
    res.status(500).json({ message: 'Failed to delete reward' });
  }
});

module.exports = router;
