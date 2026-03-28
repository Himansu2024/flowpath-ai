// backend/src/app.js
// Express application setup with all middleware, routes, and error handling
require('dotenv').config();
const express    = require('express');
const cors       = require('cors');
const helmet     = require('helmet');
const morgan     = require('morgan');
const compression = require('compression');
const rateLimit  = require('express-rate-limit');
const logger     = require('./utils/logger');

const app = express();

// ── Security middleware ──────────────────────────────────────
app.use(helmet({
  contentSecurityPolicy: false, // Disable for API-only service
  crossOriginEmbedderPolicy: false,
}));

app.use(cors({
  origin: (origin, cb) => {
    const allowed = (process.env.CORS_ORIGIN || '*').split(',');
    if (allowed.includes('*') || !origin || allowed.includes(origin)) {
      cb(null, true);
    } else {
      cb(new Error('CORS not allowed'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-API-Key'],
}));

// ── Request parsing ──────────────────────────────────────────
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(compression());

// ── Request logging ──────────────────────────────────────────
app.use(morgan('combined', {
  stream: { write: (msg) => logger.info(msg.trim()) },
  skip: (req) => req.url === '/health', // Skip health check noise
}));

// ── Rate limiting ────────────────────────────────────────────
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 min
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 200,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: 'Too many requests. Retry after 15 minutes.' },
  skip: (req) => req.user?.role === 'admin', // No limit for admins
});
app.use('/api/', limiter);

// Stricter limit for auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { success: false, error: 'Too many auth attempts. Try again in 15 minutes.' },
});
app.use('/api/v1/auth/login', authLimiter);
app.use('/api/v1/auth/register', authLimiter);

// ── Inject Socket.IO instance into every request ─────────────
app.use((req, res, next) => {
  req.io = app.get('io');
  next();
});

// ── API Routes ───────────────────────────────────────────────
const VERSION = `/api/${process.env.API_VERSION || 'v1'}`;
app.use(VERSION, require('./routes/userRoutes'));
app.use(VERSION, require('./routes/navigationRoutes'));
app.use(VERSION, require('./routes/signalRoutes'));

// ── Health check ─────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'FlowPath API',
    version: process.env.API_VERSION || 'v1',
    environment: process.env.NODE_ENV,
    timestamp: new Date().toISOString(),
    uptime: Math.round(process.uptime()),
  });
});

// ── 404 handler ──────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Endpoint ${req.method} ${req.originalUrl} not found`,
  });
});

// ── Global error handler ─────────────────────────────────────
app.use((err, req, res, next) => {
  logger.error({
    message: err.message,
    stack: err.stack,
    url: req.originalUrl,
    method: req.method,
    ip: req.ip,
  });

  // Sequelize validation errors
  if (err.name === 'SequelizeValidationError') {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: err.errors.map(e => ({ field: e.path, message: e.message })),
    });
  }

  // Sequelize unique constraint errors
  if (err.name === 'SequelizeUniqueConstraintError') {
    return res.status(409).json({
      success: false,
      message: 'Duplicate entry',
      field: err.errors[0]?.path,
    });
  }

  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal server error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
});

module.exports = app;
