const express = require('express');
const { body, validationResult } = require('express-validator');
const auth = require('../middleware/auth');
const roleCheck = require('../middleware/roleCheck');
const User = require('../models/User');
const Patient = require('../models/Patient');
const Doctor = require('../models/Doctor');
const NearbyDoctor = require('../models/NearbyDoctor');

const router = express.Router();

// All admin routes require auth + admin role
router.use(auth, roleCheck('admin'));

// GET /api/admin/patients - Get all patients with their profiles
router.get('/patients', async (req, res) => {
  try {
    const patients = await Patient.find()
      .populate('userId', 'name email phone uniqueCode createdAt')
      .populate('linkedDoctorId', 'name email')
      .sort({ createdAt: -1 });

    res.json({ patients });
  } catch (error) {
    console.error('Admin get patients error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// GET /api/admin/doctors - Get all registered doctors with their profiles
router.get('/doctors', async (req, res) => {
  try {
    const doctors = await Doctor.find()
      .populate('userId', 'name email phone uniqueCode createdAt')
      .sort({ createdAt: -1 });

    res.json({ doctors });
  } catch (error) {
    console.error('Admin get doctors error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// GET /api/admin/stats - Dashboard stats
router.get('/stats', async (req, res) => {
  try {
    const [totalPatients, totalDoctors, totalNearbyDoctors] = await Promise.all([
      Patient.countDocuments(),
      Doctor.countDocuments(),
      NearbyDoctor.countDocuments(),
    ]);

    res.json({
      totalPatients,
      totalDoctors,
      totalNearbyDoctors,
    });
  } catch (error) {
    console.error('Admin stats error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// POST /api/admin/nearby-doctors - Add a nearby doctor
router.post('/nearby-doctors', [
  body('name').trim().notEmpty().withMessage('Doctor name is required'),
  body('hospitalName').trim().notEmpty().withMessage('Hospital name is required'),
  body('contactNumber').trim().notEmpty().withMessage('Contact number is required'),
  body('specialization').trim().notEmpty().withMessage('Specialization is required'),
  body('latitude').isFloat({ min: -90, max: 90 }).withMessage('Valid latitude is required'),
  body('longitude').isFloat({ min: -180, max: 180 }).withMessage('Valid longitude is required'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ message: errors.array()[0].msg });
    }

    const { name, hospitalName, contactNumber, specialization, latitude, longitude, address } = req.body;

    const nearbyDoctor = await NearbyDoctor.create({
      name,
      hospitalName,
      contactNumber,
      specialization,
      location: {
        type: 'Point',
        coordinates: [parseFloat(longitude), parseFloat(latitude)],
      },
      address: address || '',
      addedBy: req.user._id,
    });

    res.status(201).json({ nearbyDoctor });
  } catch (error) {
    console.error('Admin add nearby doctor error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// GET /api/admin/nearby-doctors - Get all nearby doctors added by admin
router.get('/nearby-doctors', async (req, res) => {
  try {
    const nearbyDoctors = await NearbyDoctor.find()
      .sort({ createdAt: -1 });

    res.json({ nearbyDoctors });
  } catch (error) {
    console.error('Admin get nearby doctors error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// DELETE /api/admin/nearby-doctors/:id - Remove a nearby doctor
router.delete('/nearby-doctors/:id', async (req, res) => {
  try {
    const doctor = await NearbyDoctor.findByIdAndDelete(req.params.id);
    if (!doctor) {
      return res.status(404).json({ message: 'Nearby doctor not found' });
    }
    res.json({ message: 'Nearby doctor removed successfully' });
  } catch (error) {
    console.error('Admin delete nearby doctor error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
