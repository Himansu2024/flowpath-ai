// backend/src/routes/signalRoutes.js
const express = require('express');
const router  = express.Router();
const { authenticate, authorize } = require('../middleware/authMiddleware');
const sig = require('../controllers/signalController');

router.get('/signals',        authenticate, sig.getAllSignals);
router.get('/signals/nearby', authenticate, sig.getNearbySignalsController);
router.get('/signal/:id',     authenticate, sig.getSignalById);
router.post('/signals',       authenticate, authorize('admin', 'traffic_manager'), sig.createSignal);
router.put('/signal/:id',     authenticate, authorize('admin', 'traffic_manager'), sig.updateSignal);

module.exports = router;
