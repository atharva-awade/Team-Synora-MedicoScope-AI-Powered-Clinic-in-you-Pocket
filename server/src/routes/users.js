const express = require('express');
const auth = require('../middleware/auth');
const Patient = require('../models/Patient');
const Doctor = require('../models/Doctor');

const router = express.Router();

// GET /api/users/profile
router.get('/profile', auth, async (req, res) => {
  try {
    const userJSON = req.user.toPublicJSON();

    let profile = null;
    if (req.user.role === 'patient') {
      profile = await Patient.findOne({ userId: req.user._id })
        .populate('linkedDoctorId', 'name email uniqueCode');
    } else if (req.user.role === 'doctor') {
      profile = await Doctor.findOne({ userId: req.user._id });
    }

    res.json({
      user: userJSON,
      profile: profile || {},
    });
  } catch (error) {
    console.error('Profile fetch error:', error);
    res.status(500).json({ message: 'Server error fetching profile' });
  }
});

// PUT /api/users/profile
router.put('/profile', auth, async (req, res) => {
  try {
    const { name, phone } = req.body;

    if (name) req.user.name = name;
    if (phone) req.user.phone = phone;
    await req.user.save();

    if (req.user.role === 'patient') {
      const { dateOfBirth, bloodGroup, emergencyContact, medications, conditions } = req.body;
      const update = {};
      if (dateOfBirth !== undefined) update.dateOfBirth = dateOfBirth;
      if (bloodGroup !== undefined) update.bloodGroup = bloodGroup;
      if (emergencyContact !== undefined) update.emergencyContact = emergencyContact;
      if (medications !== undefined) update.medications = medications;
      if (conditions !== undefined) update.conditions = conditions;

      if (Object.keys(update).length > 0) {
        await Patient.findOneAndUpdate({ userId: req.user._id }, update);
      }
    } else if (req.user.role === 'doctor') {
      const { specialization, hospital, yearsOfExperience } = req.body;
      const update = {};
      if (specialization !== undefined) update.specialization = specialization;
      if (hospital !== undefined) update.hospital = hospital;
      if (yearsOfExperience !== undefined) update.yearsOfExperience = yearsOfExperience;

      if (Object.keys(update).length > 0) {
        await Doctor.findOneAndUpdate({ userId: req.user._id }, update);
      }
    }

    res.json({ message: 'Profile updated successfully' });
  } catch (error) {
    console.error('Profile update error:', error);
    res.status(500).json({ message: 'Server error updating profile' });
  }
});

module.exports = router;
