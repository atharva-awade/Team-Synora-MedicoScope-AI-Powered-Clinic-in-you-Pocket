const express = require('express');
const auth = require('../middleware/auth');
const NearbyDoctor = require('../models/NearbyDoctor');

const router = express.Router();

// GET /api/nearby-doctors/search?lat=...&lng=...&radius=...&specialization=...
// Search nearby doctors based on user's location
router.get('/search', auth, async (req, res) => {
  try {
    const { lat, lng, radius, specialization } = req.query;

    if (!lat || !lng) {
      return res.status(400).json({ message: 'Latitude and longitude are required' });
    }

    const latitude = parseFloat(lat);
    const longitude = parseFloat(lng);
    const maxDistance = parseInt(radius) || 10000; // Default 10km in meters

    const query = {
      location: {
        $near: {
          $geometry: {
            type: 'Point',
            coordinates: [longitude, latitude],
          },
          $maxDistance: maxDistance,
        },
      },
    };

    // Filter by specialization if provided
    if (specialization && specialization !== 'All') {
      query.specialization = { $regex: new RegExp(specialization, 'i') };
    }

    const nearbyDoctors = await NearbyDoctor.find(query);

    // Calculate distance for each doctor
    const doctorsWithDistance = nearbyDoctors.map((doc) => {
      const docObj = doc.toObject();
      const [docLng, docLat] = doc.location.coordinates;
      docObj.distance = calculateDistance(latitude, longitude, docLat, docLng);
      return docObj;
    });

    res.json({ nearbyDoctors: doctorsWithDistance });
  } catch (error) {
    console.error('Nearby doctors search error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// GET /api/nearby-doctors/specializations - Get list of available specializations
router.get('/specializations', auth, async (req, res) => {
  try {
    const specializations = await NearbyDoctor.distinct('specialization');
    res.json({ specializations });
  } catch (error) {
    console.error('Get specializations error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Haversine formula to calculate distance in meters
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000; // Earth's radius in meters
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c);
}

function toRad(deg) {
  return deg * (Math.PI / 180);
}

module.exports = router;
