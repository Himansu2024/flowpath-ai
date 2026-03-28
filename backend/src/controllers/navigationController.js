// backend/src/controllers/navigationController.js
// Handles all navigation API endpoints including route planning,
// vehicle tracking, and optimal speed recommendations

const { validationResult } = require('express-validator');
const Route = require('../models/Route');
const Vehicle = require('../models/Vehicle');
const TrafficSignal = require('../models/TrafficSignal');
const { calculateRoute, getSignalsAlongRoute, getNearbyParking } = require('../services/routingService');
const { optimizeForSignal, optimizeRoute } = require('../services/greenwaveService');
const logger = require('../utils/logger');

/**
 * POST /api/v1/navigation/start
 * Begin a navigation session: calculate route, fetch signals,
 * run GreenWave optimization, return full navigation plan.
 */
const startNavigation = async (req, res, next) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const { startLat, startLon, endLat, endLon, vehicleType = 'car' } = req.body;
    const userId = req.user.user_id;

    // 1. Calculate driving route via OSRM
    const routeData = await calculateRoute(startLat, startLon, endLat, endLon);

    // 2. Find traffic signals along route using PostGIS
    const signals = await getSignalsAlongRoute(routeData.geometry, 120);

    // 3. Create Route record in database
    const route = await Route.create({
      user_id: userId,
      start_lat: startLat,
      start_lon: startLon,
      end_lat: endLat,
      end_lon: endLon,
      distance_km: routeData.distanceKm,
      estimated_duration_min: routeData.durationMinutes,
      signal_sequence: signals.map(s => s.id),
      waypoints: routeData.geometry.coordinates,
      osrm_route: routeData,
      status: 'active',
      started_at: new Date(),
    });

    // 4. Update Vehicle tracking record
    await Vehicle.upsert({
      user_id: userId,
      current_lat: startLat,
      current_lon: startLon,
      destination_lat: endLat,
      destination_lon: endLon,
      route_id: route.route_id,
      vehicle_type: vehicleType,
      is_navigating: true,
      last_updated: new Date(),
    }, { conflictFields: ['user_id'] });

    // 5. Run GreenWave optimization across all route signals
    const greenwaveOptimizations = signals.length
      ? await optimizeRoute(signals, { lat: startLat, lon: startLon, speedKmh: 40 })
      : [];

    // 6. Attach parking finder at destination
    const nearbyParking = await getNearbyParking(endLat, endLon, 600);

    res.status(200).json({
      success: true,
      data: {
        routeId: route.route_id,
        route: {
          distanceKm: routeData.distanceKm,
          durationMinutes: routeData.durationMinutes,
          geometry: routeData.geometry,
          steps: routeData.steps,
        },
        signals: signals.map((s, i) => ({
          ...s,
          optimization: greenwaveOptimizations[i] || null,
        })),
        greenwaveScore: computeGreenwaveScore(greenwaveOptimizations),
        nearbyParking: nearbyParking.slice(0, 10),
        estimatedFuelSavedMl: greenwaveOptimizations.reduce((sum, o) => sum + (o.co2SavedGrams || 0), 0),
      },
    });
  } catch (error) {
    logger.error('startNavigation error:', error);
    next(error);
  }
};

/**
 * POST /api/v1/vehicle/location
 * Update vehicle's real-time position and get updated speed advice.
 * Called by mobile app every 2-3 seconds while navigating.
 */
const updateVehicleLocation = async (req, res, next) => {
  try {
    const { lat, lon, speedKmh, heading, routeId } = req.body;
    const userId = req.user.user_id;

    // Update vehicle position in database
    await Vehicle.update({
      current_lat: lat,
      current_lon: lon,
      speed_kmh: speedKmh,
      heading,
      last_updated: new Date(),
    }, { where: { user_id: userId } });

    // Get next signal ahead on route
    const vehicle = await Vehicle.findOne({ where: { user_id: userId } });
    const nearbySignals = await getNearbySignalsOnRoute(lat, lon, routeId);

    let speedAdvice = null;
    if (nearbySignals.length > 0) {
      const nextSignal = nearbySignals[0];
      speedAdvice = await optimizeForSignal({
        vehicleLat: lat,
        vehicleLon: lon,
        vehicleSpeedKmh: speedKmh || 40,
        signalId: nextSignal.id,
      });
    }

    // Broadcast to Socket.IO connected admin dashboards
    if (req.io) {
      req.io.to('admin-room').emit('vehicle:update', {
        userId,
        lat, lon, speedKmh, heading,
        timestamp: new Date().toISOString(),
      });
    }

    res.json({
      success: true,
      data: {
        nextSignal: nearbySignals[0] || null,
        speedAdvice,
        isOnRoute: true,  // Off-route detection in production
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /api/v1/optimal-speed
 * Get optimal speed recommendation for a specific signal.
 */
const getOptimalSpeed = async (req, res, next) => {
  try {
    const { lat, lon, speed, signalId } = req.query;

    const optimization = await optimizeForSignal({
      vehicleLat: parseFloat(lat),
      vehicleLon: parseFloat(lon),
      vehicleSpeedKmh: parseFloat(speed) || 40,
      signalId,
    });

    res.json({ success: true, data: optimization });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /api/v1/route
 * Retrieve active or historical route details.
 */
const getRoute = async (req, res, next) => {
  try {
    const { routeId } = req.query;
    const userId = req.user.user_id;

    const where = routeId
      ? { route_id: routeId, user_id: userId }
      : { user_id: userId, status: 'active' };

    const route = await Route.findOne({ where });
    if (!route) return res.status(404).json({ message: 'Route not found' });

    res.json({ success: true, data: route });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /api/v1/eco-stats
 * Get eco-driving statistics for the authenticated user.
 */
const getEcoStats = async (req, res, next) => {
  try {
    const userId = req.user.user_id;
    const routes = await Route.findAll({
      where: { user_id: userId, status: 'completed' },
      order: [['completed_at', 'DESC']],
      limit: 100,
    });

    const stats = {
      totalTrips: routes.length,
      totalDistanceKm: routes.reduce((s, r) => s + parseFloat(r.distance_km || 0), 0).toFixed(1),
      totalStopsAvoided: routes.reduce((s, r) => s + (r.stops_avoided || 0), 0),
      totalFuelSavedMl: routes.reduce((s, r) => s + (r.fuel_saved_ml || 0), 0),
      totalCO2SavedG: routes.reduce((s, r) => s + (r.co2_saved_g || 0), 0),
      avgGreenwaveScore: routes.length
        ? (routes.reduce((s, r) => s + parseFloat(r.greenwave_score || 0), 0) / routes.length).toFixed(1)
        : 0,
      moneySavedINR: Math.round(routes.reduce((s, r) => s + (r.fuel_saved_ml || 0), 0) / 1000 * 102),
    };

    res.json({ success: true, data: stats });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /api/v1/trip-history
 * Paginated trip history for the authenticated user.
 */
const getTripHistory = async (req, res, next) => {
  try {
    const userId = req.user.user_id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;

    const { count, rows } = await Route.findAndCountAll({
      where: { user_id: userId, status: 'completed' },
      order: [['completed_at', 'DESC']],
      limit,
      offset: (page - 1) * limit,
    });

    res.json({
      success: true,
      data: rows,
      pagination: {
        total: count,
        pages: Math.ceil(count / limit),
        currentPage: page,
      },
    });
  } catch (error) {
    next(error);
  }
};

// Helper: get signals on route near current position
const getNearbySignalsOnRoute = async (lat, lon, routeId) => {
  if (!routeId) return [];
  const route = await Route.findByPk(routeId);
  if (!route || !route.signal_sequence?.length) return [];

  const signals = await TrafficSignal.findAll({
    where: { id: route.signal_sequence, is_active: true },
  });
  return signals;
};

const computeGreenwaveScore = (optimizations) => {
  if (!optimizations.length) return 0;
  const greenCount = optimizations.filter(o => o.willCatchGreen).length;
  return Math.round((greenCount / optimizations.length) * 100);
};

module.exports = {
  startNavigation,
  updateVehicleLocation,
  getOptimalSpeed,
  getRoute,
  getEcoStats,
  getTripHistory,
};
