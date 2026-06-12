const express = require('express');
const auth = require('../middleware/auth');
const roleCheck = require('../middleware/roleCheck');
const Doctor = require('../models/Doctor');
const Patient = require('../models/Patient');
const User = require('../models/User');
const DetectionRecord = require('../models/DetectionRecord');

const router = express.Router();

// GET /api/doctors/patients - list linked patients
router.get('/patients', auth, roleCheck('doctor'), async (req, res) => {
  try {
    const doctor = await Doctor.findOne({ userId: req.user._id });
    if (!doctor) {
      return res.status(404).json({ message: 'Doctor profile not found' });
    }

    const patients = await User.find(
      { _id: { $in: doctor.linkedPatients } },
      'name email phone uniqueCode'
    );

    const patientDetails = await Promise.all(
      patients.map(async (patient) => {
        const profile = await Patient.findOne({ userId: patient._id });
        return {
          userId: patient._id,
          name: patient.name,
          email: patient.email,
          phone: patient.phone,
          uniqueCode: patient.uniqueCode,
          conditions: profile?.conditions || [],
          bloodGroup: profile?.bloodGroup || '',
          dateOfBirth: profile?.dateOfBirth || '',
        };
      })
    );

    res.json({ patients: patientDetails });
  } catch (error) {
    console.error('Fetch patients error:', error);
    res.status(500).json({ message: 'Server error fetching patients' });
  }
});

// GET /api/doctors/patients/:patientUserId - get specific patient
router.get('/patients/:patientUserId', auth, roleCheck('doctor'), async (req, res) => {
  try {
    const doctor = await Doctor.findOne({ userId: req.user._id });
    if (!doctor) {
      return res.status(404).json({ message: 'Doctor profile not found' });
    }

    if (!doctor.linkedPatients.includes(req.params.patientUserId)) {
      return res.status(403).json({ message: 'Patient not linked to you' });
    }

    const patient = await User.findById(req.params.patientUserId, 'name email phone uniqueCode');
    if (!patient) {
      return res.status(404).json({ message: 'Patient not found' });
    }

    const profile = await Patient.findOne({ userId: patient._id });

    res.json({
      userId: patient._id,
      name: patient.name,
      email: patient.email,
      phone: patient.phone,
      uniqueCode: patient.uniqueCode,
      conditions: profile?.conditions || [],
      medications: profile?.medications || [],
      bloodGroup: profile?.bloodGroup || '',
      dateOfBirth: profile?.dateOfBirth || '',
      emergencyContact: profile?.emergencyContact || {},
    });
  } catch (error) {
    console.error('Fetch patient error:', error);
    res.status(500).json({ message: 'Server error fetching patient' });
  }
});

// GET /api/doctors/patients/:patientUserId/records - get patient detection records
router.get('/patients/:patientUserId/records', auth, roleCheck('doctor'), async (req, res) => {
  try {
    const doctor = await Doctor.findOne({ userId: req.user._id });
    if (!doctor || !doctor.linkedPatients.includes(req.params.patientUserId)) {
      return res.status(403).json({ message: 'Patient not linked to you' });
    }

    const records = await DetectionRecord.find({ patientId: req.params.patientUserId })
      .sort({ createdAt: -1 })
      .populate('performedBy', 'name role');

    res.json({ records });
  } catch (error) {
    console.error('Fetch records error:', error);
    res.status(500).json({ message: 'Server error fetching records' });
  }
});

module.exports = router;
