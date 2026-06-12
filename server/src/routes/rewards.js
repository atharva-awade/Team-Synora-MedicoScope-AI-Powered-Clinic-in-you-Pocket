const express = require('express');
const auth = require('../middleware/auth');
const Rewards = require('../models/Rewards');

const router = express.Router();

// GET /api/rewards — get user rewards data
router.get('/', auth, async (req, res) => {
  try {
    let rewards = await Rewards.findOne({ userId: req.user._id }).lean();

    if (!rewards) {
      rewards = {
        totalCoins: 0,
        totalSessions: 0,
        currentStreak: 0,
        longestStreak: 0,
        lastSessionDate: null,
        lastChatRewardDate: null,
        streak3Claimed: false,
        streak7Claimed: false,
      };
    }

    res.json({ rewards });
  } catch (error) {
    console.error('Get rewards error:', error);
    res.status(500).json({ message: 'Failed to fetch rewards' });
  }
});

// PUT /api/rewards — sync/update rewards from client
router.put('/', auth, async (req, res) => {
  try {
    const {
      totalCoins,
      totalSessions,
      currentStreak,
      longestStreak,
      lastSessionDate,
      lastChatRewardDate,
      streak3Claimed,
      streak7Claimed,
    } = req.body;

    const rewards = await Rewards.findOneAndUpdate(
      { userId: req.user._id },
      {
        $set: {
          totalCoins: totalCoins ?? 0,
          totalSessions: totalSessions ?? 0,
          currentStreak: currentStreak ?? 0,
          longestStreak: longestStreak ?? 0,
          lastSessionDate: lastSessionDate ?? null,
          lastChatRewardDate: lastChatRewardDate ?? null,
          streak3Claimed: streak3Claimed ?? false,
          streak7Claimed: streak7Claimed ?? false,
        },
      },
      { upsert: true, new: true }
    );

    res.json({ rewards });
  } catch (error) {
    console.error('Update rewards error:', error);
    res.status(500).json({ message: 'Failed to update rewards' });
  }
});

module.exports = router;
