const mongoose = require('mongoose');

const rewardsSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true,
  },
  totalCoins: {
    type: Number,
    default: 0,
  },
  totalSessions: {
    type: Number,
    default: 0,
  },
  currentStreak: {
    type: Number,
    default: 0,
  },
  longestStreak: {
    type: Number,
    default: 0,
  },
  lastSessionDate: {
    type: String,
    default: null,
  },
  lastChatRewardDate: {
    type: String,
    default: null,
  },
  streak3Claimed: {
    type: Boolean,
    default: false,
  },
  streak7Claimed: {
    type: Boolean,
    default: false,
  },
}, {
  timestamps: true,
});

module.exports = mongoose.model('Rewards', rewardsSchema);
