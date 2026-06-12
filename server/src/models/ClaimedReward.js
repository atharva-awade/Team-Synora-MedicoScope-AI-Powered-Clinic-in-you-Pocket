const mongoose = require('mongoose');

const claimedRewardSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  rewardType: { type: String, required: true },
  title: { type: String, required: true },
  content: { type: String, required: true },
  coinsCost: { type: Number, required: true },
}, { timestamps: true });

claimedRewardSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('ClaimedReward', claimedRewardSchema);
