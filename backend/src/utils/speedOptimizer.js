// backend/src/utils/speedOptimizer.js
// Speed optimization helper utilities

const MIN_SPEED_KMH = 15;
const MAX_SPEED_KMH = 80;

/** Clamp speed to safe driving range */
const clampSpeed = (speed) => Math.max(MIN_SPEED_KMH, Math.min(MAX_SPEED_KMH, speed));

/** Human-readable advice text for a given speed action */
const speedAdviceText = (action, speed, remaining = 0) => {
  const msgs = {
    maintain:  `Maintain ${speed} km/h — you will catch the green light 🟢`,
    slow_down: `Slow to ${speed} km/h — arrive on next green phase 🟡`,
    speed_up:  `Speed up to ${speed} km/h to catch the green wave 🟢`,
    stop:      `Red signal for ${remaining}s — coast at ${MIN_SPEED_KMH} km/h 🔴`,
  };
  return msgs[action] || `Drive at ${speed} km/h`;
};

/** Estimate fuel saved (ml) by avoiding N stops */
const estimateFuelSaved = (stopsAvoided) => Math.round(stopsAvoided * 45);

/** Estimate CO₂ saved (grams) by avoiding N stops */
const estimateCO2Saved = (stopsAvoided) => Math.round(stopsAvoided * 105);

/** Estimate money saved (INR) based on fuel saved */
const estimateMoneySaved = (stopsAvoided, fuelPricePerLitre = 102) =>
  parseFloat(((stopsAvoided * 45) / 1000 * fuelPricePerLitre).toFixed(2));

module.exports = {
  MIN_SPEED_KMH,
  MAX_SPEED_KMH,
  clampSpeed,
  speedAdviceText,
  estimateFuelSaved,
  estimateCO2Saved,
  estimateMoneySaved,
};
