// backend/src/services/routingService.js
// Handles route calculation using OSRM (free, full India coverage)
// and fetches traffic signals along the route using PostGIS queries

const axios = require('axios');
const { sequelize } = require('../config/database');
const logger = require('../utils/logger');

const OSRM_URL = 'https://router.project-osrm.org';

/**
 * Calculate driving route between two coordinates.
 * Uses OSRM public API (OpenStreetMap data — full India coverage).
 *
 * @param {number} startLat
 * @param {number} startLon
 * @param {number} endLat
 * @param {number} endLon
 * @returns {Promise<Object>} Route with geometry, steps, distance, duration
 */
const calculateRoute = async (startLat, startLon, endLat, endLon) => {
  try {
    const url = `${OSRM_URL}/route/v1/driving/${startLon},${startLat};${endLon},${endLat}`;
    const params = {
      overview: 'full',
      geometries: 'geojson',
      steps: true,
      annotations: true,
    };

    const response = await axios.get(url, { params, timeout: 10000 });

    if (response.data.code !== 'Ok' || !response.data.routes.length) {
      throw new Error('OSRM returned no routes');
    }

    const route = response.data.routes[0];
    return {
      distanceMetres: route.distance,
      distanceKm: parseFloat((route.distance / 1000).toFixed(2)),
      durationSeconds: route.duration,
      durationMinutes: Math.round(route.duration / 60),
      geometry: route.geometry,           // GeoJSON LineString
      waypoints: response.data.waypoints,
      steps: route.legs[0].steps,        // Turn-by-turn instructions
      legs: route.legs,
    };
  } catch (error) {
    logger.error('Route calculation failed:', error.message);
    // Return straight-line fallback
    return calculateStraightLineRoute(startLat, startLon, endLat, endLon);
  }
};

/**
 * Find all traffic signals within a corridor around a route.
 * Uses PostGIS ST_DWithin for geospatial query.
 *
 * @param {Object} routeGeometry - GeoJSON LineString of the route
 * @param {number} corridorMetres - Buffer distance around route (default 120m)
 * @returns {Promise<Object[]>} Ordered list of signals along route
 */
/**
 * Find all traffic signals within a corridor around a route.
 * Uses PostGIS ST_DWithin for geospatial query.
 */
const getSignalsAlongRoute = async (routeGeometry, corridorMetres = 500) => {
  try {
    // 1. Force the OSRM route to be recognized as GPS coordinates using ST_SetSRID(... 4326)
    // 2. Expand the search radius to 500 meters to guarantee we catch the signals
    const query = `
      SELECT 
        id, 
        intersection_name AS "intersectionName", 
        latitude, 
        longitude, 
        current_phase AS phase, 
        seconds_remaining AS "secondsRemaining",
        ST_Distance(
          ST_SetSRID(ST_GeomFromGeoJSON(:routeGeom), 4326)::geography, 
          location::geography
        ) AS "distanceMetres"
      FROM signals
      WHERE ST_DWithin(
        ST_SetSRID(ST_GeomFromGeoJSON(:routeGeom), 4326)::geography, 
        location::geography, 
        :corridor
      )
      ORDER BY ST_LineLocatePoint(
        ST_SetSRID(ST_GeomFromGeoJSON(:routeGeom), 4326), 
        location::geometry
      ) ASC;
    `;

    const [results] = await sequelize.query(query, {
      replacements: {
        routeGeom: JSON.stringify(routeGeometry),
        corridor: corridorMetres,
      },
    });

    return results;
  } catch (error) {
    logger.error('Failed to fetch signals along route:', error.message);
    return [];
  }
};

/**
 * Find nearby signals within radius using PostGIS.
 * @param {number} lat
 * @param {number} lon
 * @param {number} radiusMetres - Default 1000m
 * @returns {Promise<Object[]>}
 */
const getNearbySignals = async (lat, lon, radiusMetres = 1000) => {
  try {
    const query = `
      SELECT 
        id, 
        intersection_name AS "intersectionName", 
        latitude, 
        longitude, 
        current_phase AS phase, 
        seconds_remaining AS "secondsRemaining",
        ST_Distance(
          ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography,
          location::geography
        ) AS "distanceMetres"
      FROM signals
      WHERE ST_DWithin(
        ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography,
        location::geography,
        :radius
      )
      ORDER BY "distanceMetres" ASC
      LIMIT 20;
    `;

    const [results] = await sequelize.query(query, {
      replacements: { lat, lon, radius: radiusMetres },
    });
    
    return results;
  } catch (error) {
    logger.error('getNearbySignals failed:', error.message);
    return [];
  }
};

/**
 * Find nearby parking using Overpass API (OpenStreetMap).
 * @param {number} lat
 * @param {number} lon
 * @param {number} radiusMetres
 */
const getNearbyParking = async (lat, lon, radiusMetres = 500) => {
  try {
    const overpassQuery = `
      [out:json][timeout:10];
      (
        node["amenity"="parking"](around:${radiusMetres},${lat},${lon});
        way["amenity"="parking"](around:${radiusMetres},${lat},${lon});
      );
      out center 20;
    `;
    const response = await axios.post(
      'https://overpass-api.de/api/interpreter',
      overpassQuery,
      { headers: { 'Content-Type': 'text/plain' }, timeout: 12000 }
    );

    return (response.data.elements || []).map(el => ({
      id: el.id,
      name: el.tags?.name || 'Parking Area',
      lat: el.lat || el.center?.lat,
      lon: el.lon || el.center?.lon,
      type: el.tags?.parking || 'surface',
      fee: el.tags?.fee || 'unknown',
      capacity: parseInt(el.tags?.capacity) || null,
      access: el.tags?.access || 'yes',
    }));
  } catch (error) {
    logger.warn('Parking lookup failed:', error.message);
    return [];
  }
};

/**
 * Straight-line route fallback when OSRM is unavailable.
 */
const calculateStraightLineRoute = (sLat, sLon, eLat, eLon) => {
  const R = 6371000;
  const dLat = (eLat - sLat) * Math.PI / 180;
  const dLon = (eLon - sLon) * Math.PI / 180;
  const a = Math.sin(dLat/2)**2 + Math.cos(sLat*Math.PI/180) * Math.cos(eLat*Math.PI/180) * Math.sin(dLon/2)**2;
  const distanceMetres = R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));

  return {
    distanceMetres: Math.round(distanceMetres),
    distanceKm: parseFloat((distanceMetres / 1000).toFixed(2)),
    durationSeconds: Math.round(distanceMetres / 10),  // Assume ~36 km/h avg
    durationMinutes: Math.round(distanceMetres / 600),
    geometry: {
      type: 'LineString',
      coordinates: [[sLon, sLat], [eLon, eLat]],
    },
    steps: [],
    waypoints: [],
    legs: [],
    isFallback: true,
  };
};

module.exports = {
  calculateRoute,
  getSignalsAlongRoute,
  getNearbySignals,
  getNearbyParking,
};
