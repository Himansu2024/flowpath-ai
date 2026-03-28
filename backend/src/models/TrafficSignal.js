// backend/src/models/TrafficSignal.js
const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const TrafficSignal = sequelize.define('TrafficSignal', {
  id: {
    type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true,
  },
  intersection_name: { type: DataTypes.STRING(200), allowNull: false },
  latitude:          { type: DataTypes.DECIMAL(10,8), allowNull: false },
  longitude:         { type: DataTypes.DECIMAL(11,8), allowNull: false },
  green_duration:    { type: DataTypes.INTEGER, defaultValue: 45 },
  yellow_duration:   { type: DataTypes.INTEGER, defaultValue: 5  },
  red_duration:      { type: DataTypes.INTEGER, defaultValue: 60 },
  // cycle_time is a GENERATED column in DB — do NOT include it here (breaks sync)
  offset:            { type: DataTypes.INTEGER, defaultValue: 0, field: 'offset_seconds' },
  current_phase:     { type: DataTypes.STRING(10), defaultValue: 'red' },
  seconds_remaining: { type: DataTypes.INTEGER, defaultValue: 0 },
  road_name:         { type: DataTypes.STRING(200) },
  city:              { type: DataTypes.STRING(100), defaultValue: 'Bengaluru' },
  zone:              { type: DataTypes.STRING(100) },
  avg_wait_time:     { type: DataTypes.DECIMAL(5,2), defaultValue: 0 },
  efficiency_score:  { type: DataTypes.DECIMAL(5,2), defaultValue: 100 },
  is_active:         { type: DataTypes.BOOLEAN, defaultValue: true },
  atms_id:           { type: DataTypes.STRING(100) },
  metadata:          { type: DataTypes.JSONB, defaultValue: {} },
}, {
  tableName: 'traffic_signals',
  timestamps: true,
  underscored: true,
});

// Calculate current phase without needing DB
TrafficSignal.prototype.calculateCurrentState = function (currentTime = new Date()) {
  const cycle   = (this.green_duration + this.yellow_duration + this.red_duration) || 110;
  const elapsed = (Math.floor(currentTime.getTime() / 1000) + (this.offset || 0)) % cycle;
  let phase, remaining, nextGreenIn;

  if (elapsed < this.green_duration) {
    phase = 'green';  remaining = this.green_duration - elapsed;  nextGreenIn = 0;
  } else if (elapsed < this.green_duration + this.yellow_duration) {
    phase = 'yellow'; remaining = this.green_duration + this.yellow_duration - elapsed;
    nextGreenIn = remaining + this.red_duration;
  } else {
    phase = 'red';    remaining = cycle - elapsed;               nextGreenIn = remaining;
  }
  return { phase, remaining, nextGreenIn };
};

module.exports = TrafficSignal;
