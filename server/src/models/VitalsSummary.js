const mongoose = require('mongoose');

const vitalsSummarySchema = new mongoose.Schema({
  patientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  sessionId: {
    type: String,
    required: true,
  },
  duration: {
    type: Number,
    default: 0,
  },
  dataPointCount: {
    type: Number,
    default: 0,
  },
  avgHeartRate: { type: Number, default: 0 },
  maxHeartRate: { type: Number, default: 0 },
  minHeartRate: { type: Number, default: 0 },
  avgSystolic: { type: Number, default: 0 },
  maxSystolic: { type: Number, default: 0 },
  avgDiastolic: { type: Number, default: 0 },
  avgSpO2: { type: Number, default: 0 },
  minSpO2: { type: Number, default: 0 },
  alerts: [{
    type: { type: String },
    severity: String,
    message: String,
    vital: String,
    currentValue: Number,
    predictedValue: Number,
    timestamp: String,
  }],
  location: {
    type: String,
    default: 'Unknown',
  },
}, {
  timestamps: true,
});

module.exports = mongoose.model('VitalsSummary', vitalsSummarySchema);
