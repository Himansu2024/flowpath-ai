// backend/src/config/database.js
// Fixed: removed sequelize.sync() — use SQL migrations instead.
// sync({alter:true}) breaks PostGIS generated columns and causes crash-loop.
const { Sequelize } = require('sequelize');
const logger = require('../utils/logger');

// Standardize configuration options
const dbConfig = {
  dialect:  'postgres',
  logging:  (sql) => logger.debug(sql),
  pool: {
    max:     parseInt(process.env.DB_POOL_MAX)  || 20,
    min:     parseInt(process.env.DB_POOL_MIN)  || 2,
    acquire: 60000, // Increased to 60s to prevent cloud cold-start timeouts
    idle:    parseInt(process.env.DB_POOL_IDLE) || 10000,
  },
  dialectOptions: {
    ssl: process.env.NODE_ENV === 'production'
      ? { require: true, rejectUnauthorized: false }
      : false,
    connectTimeout: 20000,
  },
  define: { underscored: true, timestamps: true },
};

// 🔥 THE FIX: Prefer DATABASE_URL (Render standard) but fallback to local variables
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

    // DO NOT call sequelize.sync() here — it breaks PostGIS generated columns.
    // Use: docker exec flowpath-db psql ... -f migrations/00X_xxx.sql

  } catch (error) {
    logger.error('❌ Database connection failed: ' + error.message);
    throw error; // Let server.js handle retry
  }
};

module.exports = { sequelize, connectDatabase };