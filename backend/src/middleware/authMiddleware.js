// backend/src/middleware/authMiddleware.js
// JWT authentication middleware — verifies Bearer token on protected routes

const jwt = require('jsonwebtoken');
const User = require('../models/User');
const logger = require('../utils/logger');

/**
 * Middleware: Verify JWT token and attach user to request.
 * Usage: router.get('/protected', authenticate, controller)
 */
const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      return res.status(401).json({ message: 'No authentication token provided' });
    }

    const token = authHeader.substring(7);
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    const user = await User.findOne({
      where: { user_id: decoded.userId, is_active: true },
    });

    if (!user) {
      return res.status(401).json({ message: 'User not found or account deactivated' });
    }

    req.user = user;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ message: 'Token expired. Please login again.' });
    }
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ message: 'Invalid token' });
    }
    next(error);
  }
};

/**
 * Middleware: Require specific role(s).
 * Usage: router.get('/admin', authenticate, authorize('admin'), controller)
 */
const authorize = (...roles) => {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        message: `Access denied. Required role: ${roles.join(' or ')}`,
      });
    }
    next();
  };
};

module.exports = { authenticate, authorize };
