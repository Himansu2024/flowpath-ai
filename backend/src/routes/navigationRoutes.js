// backend/src/routes/navigationRoutes.js
const express = require('express');
const router  = express.Router();
const { body, query } = require('express-validator');
const { authenticate } = require('../middleware/authMiddleware');
const nav = require('../controllers/navigationController');

router.post('/navigation/start', authenticate,
  [
    body('startLat').isFloat({ min: -90,  max: 90  }).withMessage('Invalid startLat'),
    body('startLon').isFloat({ min: -180, max: 180 }).withMessage('Invalid startLon'),
    body('endLat').isFloat({ min: -90,  max: 90  }).withMessage('Invalid endLat'),
    body('endLon').isFloat({ min: -180, max: 180 }).withMessage('Invalid endLon'),
  ],
  nav.startNavigation
);

router.post('/vehicle/location', authenticate, nav.updateVehicleLocation);
router.get('/route',         authenticate, nav.getRoute);
router.get('/optimal-speed', authenticate, [query('signalId').notEmpty()], nav.getOptimalSpeed);
router.get('/eco-stats',     authenticate, nav.getEcoStats);
router.get('/trip-history',  authenticate, nav.getTripHistory);
router.get('/parking-nearby',authenticate, async (req, res, next) => {
  try {
    const { lat, lon, radius = 500 } = req.query;
    const { getNearbyParking } = require('../services/routingService');
    const results = await getNearbyParking(parseFloat(lat), parseFloat(lon), parseInt(radius));
    res.json({ success: true, data: results });
  } catch (e) { next(e); }
});

module.exports = router;
