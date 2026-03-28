// backend/src/models/User.js
// Sequelize model for user accounts with JWT auth

const { DataTypes } = require('sequelize');
const bcrypt = require('bcryptjs');
const { sequelize } = require('../config/database');

const User = sequelize.define('User', {
  user_id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  email: {
    type: DataTypes.STRING(255),
    allowNull: false,
    unique: true,
    validate: { isEmail: true },
  },
  password_hash: {
    type: DataTypes.STRING(255),
    allowNull: false,
  },
  full_name: {
    type: DataTypes.STRING(100),
  },
  phone: {
    type: DataTypes.STRING(20),
  },
  role: {
    type: DataTypes.ENUM('user', 'admin', 'traffic_manager'),
    defaultValue: 'user',
  },
  vehicle_type: {
    type: DataTypes.ENUM('car', 'bike', 'truck', 'bus'),
    defaultValue: 'car',
  },
  eco_score: {
    type: DataTypes.DECIMAL(5, 2),
    defaultValue: 100.00,
  },
  total_trips: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
  },
  total_distance_km: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0.00,
  },
  fuel_saved_litres: {
    type: DataTypes.DECIMAL(8, 3),
    defaultValue: 0.000,
  },
  is_active: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
  },
  last_login: {
    type: DataTypes.DATE,
  },
  push_token: {
    type: DataTypes.STRING(500),  // For push notifications
  },
  preferences: {
    type: DataTypes.JSONB,
    defaultValue: {
      voice_navigation: true,
      eco_mode: true,
      notifications: true,
      map_style: 'dark',
    },
  },
}, {
  tableName: 'users',
  indexes: [
    { unique: true, fields: ['email'] },
    { fields: ['role'] },
  ],
  hooks: {
    // Hash password before saving
    beforeCreate: async (user) => {
      if (user.password_hash) {
        user.password_hash = await bcrypt.hash(user.password_hash, 12);
      }
    },
    beforeUpdate: async (user) => {
      if (user.changed('password_hash')) {
        user.password_hash = await bcrypt.hash(user.password_hash, 12);
      }
    },
  },
});

/**
 * Verify password against stored hash.
 * @param {string} plainPassword
 * @returns {Promise<boolean>}
 */
User.prototype.comparePassword = async function (plainPassword) {
  return bcrypt.compare(plainPassword, this.password_hash);
};

/**
 * Return safe user object without sensitive fields.
 */
User.prototype.toPublicJSON = function () {
  const { password_hash, push_token, ...safe } = this.toJSON();
  return safe;
};

module.exports = User;
