// backend/src/config/database.js
const { Sequelize } = require('sequelize');
const logger = require('../utils/logger');

// Standardize configuration options
// Standardize configuration options
const dbConfig = {
  dialect:  'postgres',
  logging:  false,
  pool: {
    max: 10,
    min: 0,          // 🔥 FIX 1: Set to 0 so we don't hold onto dead connections
    acquire: 60000,
    idle: 10000,
    evict: 1000,     // 🔥 FIX 2: Check for and kill zombie connections every 1 second
  },
  dialectOptions: {
    ssl: { 
      require: true, 
      rejectUnauthorized: false 
    },
    keepAlive: true, // 🔥 FIX 3: Send constant heartbeats so Supabase doesn't drop the connection
    connectTimeout: 20000,
  },
  define: { underscored: true, timestamps: true },
};

// Prefer DATABASE_URL (Render standard) but fallback to local variables
const sequelize = process.env.DATABASE_URL
  ? new Sequelize(process.env.DATABASE_URL, dbConfig)
  : new Sequelize({
      ...dbConfig,
      host:     process.env.DB_HOST     || 'localhost',
      port:     parseInt(process.env.DB_PORT) || 5432,
      database: process.env.DB_NAME     || 'flowpath_db',
      username: process.env.DB_USER     || 'flowpath_user',
      password: process.env.DB_PASSWORD,
    });

const connectDatabase = async () => {
  try {
    await sequelize.authenticate();
    logger.info('✅ PostgreSQL connected successfully');

    // Enable PostGIS — safe to run multiple times (IF NOT EXISTS)
    await sequelize.query('CREATE EXTENSION IF NOT EXISTS postgis;');
    await sequelize.query('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";');
    logger.info('✅ PostGIS extension enabled');

  } catch (error) {
    logger.error('❌ Database connection failed: ' + error.message);
    throw error; 
  }
};

module.exports = { sequelize, connectDatabase };