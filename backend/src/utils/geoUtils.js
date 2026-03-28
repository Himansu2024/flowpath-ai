// backend/src/utils/geoUtils.js
// Geospatial utility functions

/**
 * Haversine formula — great-circle distance between two coordinates.
 * @param {number} lat1 @param {number} lon1 @param {number} lat2 @param {number} lon2
 * @returns {number} Distance in metres
 */
const calculateDistance = (lat1, lon1, lat2, lon2) => {
  const R = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) *
    Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
};

/** @returns {number} Distance in km */
const metersToKm = (m) => parseFloat((m / 1000).toFixed(3));

/** @returns {number} Distance in metres */
const kmToMeters = (k) => Math.round(k * 1000);

/**
 * Bearing (degrees) from point A to point B.
 * 0° = North, 90° = East, 180° = South, 270° = West.
 */
const calculateBearing = (lat1, lon1, lat2, lon2) => {
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const la1  = lat1 * Math.PI / 180;
  const la2  = lat2 * Math.PI / 180;
  const y = Math.sin(dLon) * Math.cos(la2);
  const x = Math.cos(la1) * Math.sin(la2) - Math.sin(la1) * Math.cos(la2) * Math.cos(dLon);
  return (Math.atan2(y, x) * 180 / Math.PI + 360) % 360;
};

/**
 * Check if a point is within a bounding box.
 */
const isWithinBounds = (lat, lon, swLat, swLon, neLat, neLon) =>
  lat >= swLat && lat <= neLat && lon >= swLon && lon <= neLon;

module.exports = { calculateDistance, metersToKm, kmToMeters, calculateBearing, isWithinBounds };
