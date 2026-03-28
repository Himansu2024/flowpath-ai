// backend/src/controllers/signalController.js
const TrafficSignal = require('../models/TrafficSignal');
const { getNearbySignals } = require('../services/routingService');
const logger = require('../utils/logger');

// GET /api/v1/signals - All active signals with current state
const getAllSignals = async (req, res, next) => {
  try {
    const { city, zone, page = 1, limit = 50 } = req.query;
    const where = { is_active: true };
    if (city) where.city = city;
    if (zone) where.zone = zone;
    const { count, rows } = await TrafficSignal.findAndCountAll({ where, limit: parseInt(limit), offset: (page-1)*parseInt(limit) });
    const now = new Date();
    const signalsWithState = rows.map(s => ({ ...s.toJSON(), currentState: s.calculateCurrentState(now) }));
    res.json({ success: true, data: signalsWithState, total: count });
  } catch (err) { next(err); }
};

// GET /api/v1/signal/:id - Single signal with current phase
const getSignalById = async (req, res, next) => {
  try {
    const signal = await TrafficSignal.findByPk(req.params.id);
    if (!signal) return res.status(404).json({ message: 'Signal not found' });
    const currentState = signal.calculateCurrentState();
    res.json({ success: true, data: { ...signal.toJSON(), currentState } });
  } catch (err) { next(err); }
};

// GET /api/v1/signals/nearby - Signals near coordinates
const getNearbySignalsController = async (req, res, next) => {
  try {
    const { lat, lon, radius = 1000 } = req.query;
    const signals = await getNearbySignals(parseFloat(lat), parseFloat(lon), parseInt(radius));
    const now = new Date();
    res.json({ success: true, data: signals });
  } catch (err) { next(err); }
};

// POST /api/v1/signals - Create signal (admin only)
const createSignal = async (req, res, next) => {
  try {
    const signal = await TrafficSignal.create(req.body);
    res.status(201).json({ success: true, data: signal });
  } catch (err) { next(err); }
};

// PUT /api/v1/signal/:id - Update signal
const updateSignal = async (req, res, next) => {
  try {
    const signal = await TrafficSignal.findByPk(req.params.id);
    if (!signal) return res.status(404).json({ message: 'Signal not found' });
    await signal.update(req.body);
    res.json({ success: true, data: signal });
  } catch (err) { next(err); }
};

module.exports = { getAllSignals, getSignalById, getNearbySignalsController, createSignal, updateSignal };
