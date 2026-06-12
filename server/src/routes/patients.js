const express = require('express');
const auth = require('../middleware/auth');
const roleCheck = require('../middleware/roleCheck');
const User = require('../models/User');
const Patient = require('../models/Patient');
const Doctor = require('../models/Doctor');
const DetectionRecord = require('../models/DetectionRecord');
const VitalsSummary = require('../models/VitalsSummary');
const MindSpaceSession = require('../models/MindSpaceSession');

const router = express.Router();

// POST /api/patients/link - link patient to a doctor using doctor's code
router.post('/link', auth, roleCheck('patient'), async (req, res) => {
  try {
    const { doctorCode } = req.body;
    if (!doctorCode) {
      return res.status(400).json({ message: 'Doctor code is required' });
    }

    const doctorUser = await User.findOne({ uniqueCode: doctorCode, role: 'doctor' });
    if (!doctorUser) {
      return res.status(404).json({ message: 'No doctor found with this code' });
    }

    // Update patient's linked doctor
    await Patient.findOneAndUpdate(
      { userId: req.user._id },
      { linkedDoctorId: doctorUser._id }
    );

    // Add patient to doctor's linked patients (avoid duplicates)
    await Doctor.findOneAndUpdate(
      { userId: doctorUser._id },
      { $addToSet: { linkedPatients: req.user._id } }
    );

    res.json({
      message: 'Successfully linked to doctor',
      doctor: {
        name: doctorUser.name,
        uniqueCode: doctorUser.uniqueCode,
      },
    });
  } catch (error) {
    console.error('Link error:', error);
    res.status(500).json({ message: 'Server error linking to doctor' });
  }
});

// GET /api/patients/records - get own detection records
router.get('/records', auth, roleCheck('patient'), async (req, res) => {
  try {
    const records = await DetectionRecord.find({ patientId: req.user._id })
      .sort({ createdAt: -1 })
      .populate('performedBy', 'name role');

    res.json({ records });
  } catch (error) {
    console.error('Fetch records error:', error);
    res.status(500).json({ message: 'Server error fetching records' });
  }
});

// GET /api/patients/doctor - get linked doctor info
router.get('/doctor', auth, roleCheck('patient'), async (req, res) => {
  try {
    const patient = await Patient.findOne({ userId: req.user._id });
    if (!patient || !patient.linkedDoctorId) {
      return res.json({ doctor: null });
    }

    const doctorUser = await User.findById(patient.linkedDoctorId, 'name email phone uniqueCode');
    const doctorProfile = await Doctor.findOne({ userId: patient.linkedDoctorId });

    res.json({
      doctor: {
        _id: doctorUser._id,
        name: doctorUser.name,
        email: doctorUser.email,
        phone: doctorUser.phone,
        uniqueCode: doctorUser.uniqueCode,
        specialization: doctorProfile?.specialization || '',
        hospital: doctorProfile?.hospital || '',
      },
    });
  } catch (error) {
    console.error('Fetch doctor error:', error);
    res.status(500).json({ message: 'Server error fetching doctor info' });
  }
});

// GET /api/patients/medical-summary - aggregated data for chatbot context
router.get('/medical-summary', auth, roleCheck('patient'), async (req, res) => {
  try {
    // Fetch patient profile, recent detections, vitals, and mindspace sessions in parallel
    const [patient, detections, vitalsSummaries, mindspaceSessions] = await Promise.all([
      Patient.findOne({ userId: req.user._id }),
      DetectionRecord.find({ patientId: req.user._id })
        .sort({ createdAt: -1 })
        .limit(10)
        .populate('performedBy', 'name role'),
      VitalsSummary.find({ patientId: req.user._id })
        .sort({ createdAt: -1 })
        .limit(5),
      MindSpaceSession.find({ userId: req.user._id })
        .sort({ createdAt: -1 })
        .limit(10)
        .select('transcript userMessage urgency coinsEarned createdAt')
        .lean(),
    ]);

    res.json({
      patient: patient ? {
        conditions: patient.conditions || [],
        medications: patient.medications || [],
        bloodGroup: patient.bloodGroup || '',
        dateOfBirth: patient.dateOfBirth || null,
      } : {},
      detections: detections.map(d => ({
        className: d.className,
        confidence: d.confidence,
        category: d.category,
        description: d.description,
        date: d.createdAt,
      })),
      vitals: vitalsSummaries.map(v => ({
        avgHeartRate: v.avgHeartRate,
        maxHeartRate: v.maxHeartRate,
        minHeartRate: v.minHeartRate,
        avgSystolic: v.avgSystolic,
        avgDiastolic: v.avgDiastolic,
        avgSpO2: v.avgSpO2,
        minSpO2: v.minSpO2,
        alerts: v.alerts || [],
        duration: v.duration,
        date: v.createdAt,
      })),
      mindspace: mindspaceSessions.map(s => ({
        transcript: s.transcript,
        aiResponse: s.userMessage,
        urgency: s.urgency,
        date: s.createdAt,
      })),
    });
  } catch (error) {
    console.error('Medical summary error:', error);
    res.status(500).json({ message: 'Server error fetching medical summary' });
  }
});

module.exports = router;
