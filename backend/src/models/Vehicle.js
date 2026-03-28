// backend/src/models/Vehicle.js
const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Vehicle = sequelize.define('Vehicle', {
  vehicle_id:      { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  user_id:         { type: DataTypes.UUID, allowNull: false },
  current_lat:     { type: DataTypes.DECIMAL(10,8) },
  current_lon:     { type: DataTypes.DECIMAL(11,8) },
  speed_kmh:       { type: DataTypes.DECIMAL(5,2), defaultValue: 0 },
  heading:         { type: DataTypes.DECIMAL(5,2), defaultValue: 0 },
  destination_lat: { type: DataTypes.DECIMAL(10,8) },
  destination_lon: { type: DataTypes.DECIMAL(11,8) },
  route_id:        { type: DataTypes.UUID },
  vehicle_type:    { type: DataTypes.STRING(20), defaultValue: 'car' },
  license_plate:   { type: DataTypes.STRING(20) },
  is_navigating:   { type: DataTypes.BOOLEAN, defaultValue: false },
  socket_id:       { type: DataTypes.STRING(100) },
  last_updated:    { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
}, {
  tableName: 'vehicles', timestamps: true, underscored: true,
});

module.exports = Vehicle;
