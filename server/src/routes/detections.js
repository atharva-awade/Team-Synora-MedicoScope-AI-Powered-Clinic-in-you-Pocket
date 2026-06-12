const express = require('express');
const { body, validationResult } = require('express-validator');
const auth = require('../middleware/auth');
const DetectionRecord = require('../models/DetectionRecord');

const router = express.Router();

// POST /api/detections - save a detection result (no image, metadata only)
router.post('/', auth, [
  body('className').notEmpty().withMessage('Class name is required'),
  body('confidence').isFloat({ min: 0 }).withMessage('Confidence must be a positive number'),
  body('category').isIn(['skin', 'chest', 'brain', 'heart_sound']).withMessage('Invalid category'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ message: errors.array()[0].msg });
    }

    const { className, confidence, category, description, patientId } = req.body;

    const record = await DetectionRecord.create({
      className,
      confidence,
      category,
      description: description || '',
      patientId: patientId || (req.user.role === 'patient' ? req.user._id : null),
      doctorId: req.user.role === 'doctor' ? req.user._id : null,
      performedBy: req.user._id,
    });

    res.status(201).json({ record });
  } catch (error) {
    console.error('Save detection error:', error);
    res.status(500).json({ message: 'Server error saving detection' });
  }
});

// GET /api/detections/:patientId - get detections for a patient (used by doctors)
router.get('/:patientId', auth, async (req, res) => {
  try {
    const records = await DetectionRecord.find({ patientId: req.params.patientId })
      .sort({ createdAt: -1 })
      .populate('performedBy', 'name role');

    res.json({ records });
  } catch (error) {
    console.error('Fetch detections error:', error);
    res.status(500).json({ message: 'Server error fetching detections' });
  }
});

module.exports = router;
