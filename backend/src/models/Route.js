// backend/src/models/Route.js
const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Route = sequelize.define('Route', {
  route_id:               { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  user_id:                { type: DataTypes.UUID, allowNull: false },
  start_lat:              { type: DataTypes.DECIMAL(10,8), allowNull: false },
  start_lon:              { type: DataTypes.DECIMAL(11,8), allowNull: false },
  end_lat:                { type: DataTypes.DECIMAL(10,8), allowNull: false },
  end_lon:                { type: DataTypes.DECIMAL(11,8), allowNull: false },
  start_address:          { type: DataTypes.TEXT },
  end_address:            { type: DataTypes.TEXT },
  distance_km:            { type: DataTypes.DECIMAL(8,3) },
  estimated_duration_min: { type: DataTypes.INTEGER },
  actual_duration_min:    { type: DataTypes.INTEGER },
  signal_sequence:        { type: DataTypes.JSONB, defaultValue: [] },
  waypoints:              { type: DataTypes.JSONB, defaultValue: [] },
  osrm_route:             { type: DataTypes.JSONB },
  greenwave_score:        { type: DataTypes.DECIMAL(5,2), defaultValue: 0 },
  stops_avoided:          { type: DataTypes.INTEGER, defaultValue: 0 },
  fuel_saved_ml:          { type: DataTypes.INTEGER, defaultValue: 0 },
  co2_saved_g:            { type: DataTypes.INTEGER, defaultValue: 0 },
  status:                 { type: DataTypes.STRING(20), defaultValue: 'planned' },
  started_at:             { type: DataTypes.DATE },
  completed_at:           { type: DataTypes.DATE },
}, { tableName: 'routes', timestamps: true, underscored: true });

module.exports = Route;
