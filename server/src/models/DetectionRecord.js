const mongoose = require('mongoose');

const detectionRecordSchema = new mongoose.Schema({
  className: {
    type: String,
    required: [true, 'Class name is required'],
  },
  confidence: {
    type: Number,
    required: [true, 'Confidence score is required'],
  },
  category: {
    type: String,
    required: [true, 'Category is required'],
    enum: ['skin', 'chest', 'brain', 'heart_sound'],
  },
  description: {
    type: String,
    default: '',
  },
  patientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null,
  },
  doctorId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null,
  },
  performedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
}, {
  timestamps: true,
});

module.exports = mongoose.model('DetectionRecord', detectionRecordSchema);
