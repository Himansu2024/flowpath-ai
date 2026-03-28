// backend/src/services/greenwaveService.js
// =============================================================
// GREENWAVE OPTIMIZATION ENGINE
// Core algorithm: calculates optimal vehicle speed so it
// arrives at each signal during its GREEN phase, eliminating
// unnecessary stops and reducing fuel consumption.
// =============================================================

const axios = require('axios');
const logger = require('../utils/logger');
const TrafficSignal = require('../models/TrafficSignal');
const { calculateDistance, metersToKm } = require('../utils/geoUtils');

// Comfort speed boundaries (km/h)
const MIN_SPEED_KMH = 15;
const MAX_SPEED_KMH = 80;
const DEFAULT_SPEED_KMH = 40;

/**
 * Main GreenWave optimization function.
 * Given vehicle's current position, speed, and the next signal,
 * returns the optimal speed recommendation.
 *
 * Algorithm:
 *   arrival_time = current_time + (distance / speed)
 *   signal_phase = arrival_time % signal_cycle
 *   If arrival is during GREEN → maintain speed
 *   If arrival is during RED  → adjust speed to hit next GREEN start
 *
 * @param {Object} params
 * @param {number} params.vehicleLat
 * @param {number} params.vehicleLon
 * @param {number} params.vehicleSpeedKmh
 * @param {string} params.signalId - UUID of next signal
 * @param {Date}   params.currentTime
 * @returns {Promise<Object>} Optimization result
 */
const optimizeForSignal = async ({
  vehicleLat,
  vehicleLon,
  vehicleSpeedKmh = DEFAULT_SPEED_KMH,
  signalId,
  currentTime = new Date(),
}) => {
  // Fetch signal data from database
  const signal = await TrafficSignal.findByPk(signalId);
  if (!signal) throw new Error(`Signal ${signalId} not found`);

  // Distance from vehicle to signal (metres)
  const distanceMetres = calculateDistance(
    vehicleLat, vehicleLon,
    parseFloat(signal.latitude), parseFloat(signal.longitude)
  );

  // Current phase of the signal
  const { phase, remaining, nextGreenIn } = signal.calculateCurrentState(currentTime);

  // Travel time at current speed (seconds)
  const currentSpeedMs = (vehicleSpeedKmh * 1000) / 3600;
  const travelTimeSeconds = distanceMetres / currentSpeedMs;

  // Determine what phase the vehicle will arrive during at current speed
  const arrivalInPhase = computeArrivalPhase(
    travelTimeSeconds, remaining, phase,
    signal.green_duration, signal.yellow_duration,
    signal.red_duration, signal.cycle_time
  );

  let result = {
    signalId,
    intersectionName: signal.intersection_name,
    distanceMetres: Math.round(distanceMetres),
    currentPhase: phase,
    secondsRemaining: remaining,
    nextGreenIn,
    currentSpeedKmh: vehicleSpeedKmh,
    optimalSpeedKmh: vehicleSpeedKmh,
    action: 'maintain',
    expectedDelay: 0,
    willCatchGreen: false,
    confidenceScore: 0.85,
  };

  if (arrivalInPhase === 'green') {
    // Already optimal — vehicle will arrive during GREEN
    result.action = 'maintain';
    result.willCatchGreen = true;
    result.optimalSpeedKmh = Math.round(vehicleSpeedKmh);
    result.adviceText = `Maintain ${Math.round(vehicleSpeedKmh)} km/h — you'll catch the green! 🟢`;
  } else {
    // Need to adjust speed to hit next green window
    const { optimalSpeed, delay } = calculateOptimalSpeed(
      distanceMetres, nextGreenIn, signal
    );

    result.optimalSpeedKmh = Math.round(Math.max(MIN_SPEED_KMH, Math.min(MAX_SPEED_KMH, optimalSpeed)));
    result.expectedDelay = Math.round(delay);
    result.willCatchGreen = optimalSpeed >= MIN_SPEED_KMH && optimalSpeed <= MAX_SPEED_KMH;
    result.action = optimalSpeed < vehicleSpeedKmh ? 'slow_down' : 'speed_up';

    if (result.willCatchGreen) {
      result.adviceText = result.action === 'slow_down'
        ? `Slow to ${result.optimalSpeedKmh} km/h — arrive on next green 🟡`
        : `Speed up to ${result.optimalSpeedKmh} km/h — catch the green wave 🟢`;
    } else {
      result.adviceText = `Signal RED for ${remaining}s — slow to ${MIN_SPEED_KMH} km/h 🔴`;
      result.optimalSpeedKmh = MIN_SPEED_KMH;
    }
  }

  // Fuel savings estimate (grams CO2 per stop avoided)
  result.co2SavedGrams = result.willCatchGreen ? estimateCO2Savings(distanceMetres) : 0;

  logger.info(`GreenWave: Signal ${signal.intersection_name} → ${result.action} @ ${result.optimalSpeedKmh} km/h`);
  return result;
};

/**
 * Multi-signal greenwave optimization for full route.
 * Coordinates timing across all signals on route.
 * @param {Object[]} signals - Ordered list of signals on route
 * @param {Object} vehicleState - Current vehicle position and speed
 * @returns {Promise<Object[]>} Per-signal optimization results
 */
const optimizeRoute = async (signals, vehicleState) => {
  const { lat, lon, speedKmh } = vehicleState;
  const currentTime = new Date();
  const results = [];

  let cumulativeDistanceMetres = 0;
  let timeOffsetSeconds = 0;

  for (const signal of signals) {
    const distToSignal = calculateDistance(lat, lon, signal.latitude, signal.longitude);
    cumulativeDistanceMetres += distToSignal;

    // Project time when vehicle will reach this signal
    const speedMs = (speedKmh * 1000) / 3600;
    timeOffsetSeconds = cumulativeDistanceMetres / speedMs;
    const projectedArrivalTime = new Date(currentTime.getTime() + timeOffsetSeconds * 1000);

    try {
      const optimization = await optimizeForSignal({
        vehicleLat: lat,
        vehicleLon: lon,
        vehicleSpeedKmh: speedKmh,
        signalId: signal.id,
        currentTime: projectedArrivalTime,
      });

      // Adjust future speed based on this signal's recommendation
      if (optimization.optimalSpeedKmh) speedKmh = optimization.optimalSpeedKmh;

      results.push({
        ...optimization,
        sequenceIndex: results.length,
        distanceFromStart: Math.round(cumulativeDistanceMetres),
        estimatedArrival: projectedArrivalTime.toISOString(),
      });
    } catch (err) {
      logger.warn(`Failed to optimize signal ${signal.id}: ${err.message}`);
    }
  }

  return results;
};

/**
 * Calculate optimal speed for vehicle to reach signal during green phase.
 * @param {number} distanceMetres - Distance to signal
 * @param {number} nextGreenIn - Seconds until next green phase
 * @param {Object} signal - Signal model instance
 * @returns {{ optimalSpeed: number, delay: number }}
 */
const calculateOptimalSpeed = (distanceMetres, nextGreenIn, signal) => {
  if (nextGreenIn <= 0) {
    // Signal is currently green — maintain or accelerate
    const arrivalTime = signal.green_duration / 2;  // Aim for middle of green
    const optimalSpeed = (distanceMetres / arrivalTime) * 3.6;
    return { optimalSpeed, delay: 0 };
  }

  // Calculate speed to arrive exactly when green starts
  const speedToHitGreenMs = distanceMetres / nextGreenIn;
  const speedToHitGreenKmh = speedToHitGreenMs * 3.6;

  // Also try the NEXT green cycle
  const nextCycleGreenIn = nextGreenIn + signal.cycle_time;
  const speedNextCycleMs = distanceMetres / nextCycleGreenIn;
  const speedNextCycleKmh = speedNextCycleMs * 3.6;

  // Pick the speed that's within comfortable range
  const candidates = [speedToHitGreenKmh, speedNextCycleKmh];
  const validCandidate = candidates.find(s => s >= MIN_SPEED_KMH && s <= MAX_SPEED_KMH);

  if (validCandidate) {
    const delay = validCandidate === speedToHitGreenKmh ? 0 : signal.cycle_time;
    return { optimalSpeed: validCandidate, delay };
  }

  // No valid speed found — return comfortable stop speed
  return { optimalSpeed: MIN_SPEED_KMH, delay: nextGreenIn };
};

/**
 * Determine which signal phase the vehicle will arrive during.
 */
const computeArrivalPhase = (
  travelTime, currentRemaining, currentPhase,
  greenDuration, yellowDuration, redDuration, cycleTime
) => {
  // Time into current phase when vehicle arrives
  const phaseElapsed = getPhaseElapsed(currentPhase, currentRemaining, greenDuration, yellowDuration, redDuration);
  const totalElapsed = (phaseElapsed + travelTime) % cycleTime;

  if (totalElapsed < greenDuration) return 'green';
  if (totalElapsed < greenDuration + yellowDuration) return 'yellow';
  return 'red';
};

const getPhaseElapsed = (phase, remaining, g, y, r) => {
  if (phase === 'green') return g - remaining;
  if (phase === 'yellow') return g + y - remaining;
  return g + y + r - remaining;
};

/**
 * Estimate CO2 saved by avoiding a stop (grams).
 * Based on average vehicle emissions during deceleration + idling + acceleration.
 */
const estimateCO2Savings = (distanceMetres) => {
  // Average: ~30g CO2 saved per stop avoided for a mid-size car
  return Math.round(30 + distanceMetres * 0.001);
};

/**
 * Call Python AI engine for ML-based signal prediction.
 * Falls back to rule-based if AI engine unavailable.
 */
const callAIEngine = async (payload) => {
  try {
    const response = await axios.post(
      `${process.env.AI_ENGINE_URL}/predict/signal`,
      payload,
      {
        timeout: 3000,
        headers: { 'X-API-Key': process.env.AI_ENGINE_API_KEY },
      }
    );
    return response.data;
  } catch (err) {
    logger.warn('AI engine unavailable, using rule-based fallback');
    return null;
  }
};

module.exports = {
  optimizeForSignal,
  optimizeRoute,
  calculateOptimalSpeed,
  estimateCO2Savings,
};
