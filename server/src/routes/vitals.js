const express = require('express');
const auth = require('../middleware/auth');
const roleCheck = require('../middleware/roleCheck');
const VitalsSummary = require('../models/VitalsSummary');

const router = express.Router();

// POST /api/vitals/summary - save a vitals session summary (patient only)
router.post('/summary', auth, roleCheck('patient'), async (req, res) => {
  try {
    const {
      sessionId,
      duration,
      dataPointCount,
      avgHeartRate,
      maxHeartRate,
      minHeartRate,
      avgSystolic,
      maxSystolic,
      avgDiastolic,
      avgSpO2,
      minSpO2,
      alerts,
      location,
    } = req.body;

    if (!sessionId) {
      return res.status(400).json({ message: 'sessionId is required' });
    }

    const summary = await VitalsSummary.create({
      patientId: req.user._id,
      sessionId,
      duration: duration || 0,
      dataPointCount: dataPointCount || 0,
      avgHeartRate: avgHeartRate || 0,
      maxHeartRate: maxHeartRate || 0,
      minHeartRate: minHeartRate || 0,
      avgSystolic: avgSystolic || 0,
      maxSystolic: maxSystolic || 0,
      avgDiastolic: avgDiastolic || 0,
      avgSpO2: avgSpO2 || 0,
      minSpO2: minSpO2 || 0,
      alerts: alerts || [],
      location: location || 'Unknown',
    });

    res.status(201).json({ summary });
  } catch (error) {
    console.error('Save vitals summary error:', error);
    res.status(500).json({ message: 'Server error saving vitals summary' });
  }
});

// GET /api/vitals/summaries - get own vitals summaries (patient)
router.get('/summaries', auth, roleCheck('patient'), async (req, res) => {
  try {
    const summaries = await VitalsSummary.find({ patientId: req.user._id })
      .sort({ createdAt: -1 })
      .limit(20);

    res.json({ summaries });
  } catch (error) {
    console.error('Fetch vitals summaries error:', error);
    res.status(500).json({ message: 'Server error fetching vitals summaries' });
  }
});

// GET /api/vitals/summaries/:patientId - get patient's vitals summaries (doctor)
router.get('/summaries/:patientId', auth, roleCheck('doctor'), async (req, res) => {
  try {
    const summaries = await VitalsSummary.find({ patientId: req.params.patientId })
      .sort({ createdAt: -1 })
      .limit(20);

    res.json({ summaries });
  } catch (error) {
    console.error('Fetch patient vitals error:', error);
    res.status(500).json({ message: 'Server error fetching patient vitals' });
  }
});

module.exports = router;
