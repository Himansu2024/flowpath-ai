// backend/src/controllers/userController.js
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const logger = require('../utils/logger');

const generateToken = (userId) => jwt.sign({ userId }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN || '7d' });

// POST /api/v1/auth/register
const register = async (req, res, next) => {
  try {
    const { email, password, fullName, phone } = req.body;
    const existing = await User.findOne({ where: { email } });
    if (existing) return res.status(409).json({ message: 'Email already registered' });
    const user = await User.create({ email, password_hash: password, full_name: fullName, phone });
    const token = generateToken(user.user_id);
    res.status(201).json({ success: true, token, user: user.toPublicJSON() });
  } catch (err) { next(err); }
};

// POST /api/v1/auth/login
const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ where: { email } });
    if (!user || !await user.comparePassword(password)) return res.status(401).json({ message: 'Invalid credentials' });
    await user.update({ last_login: new Date() });
    const token = generateToken(user.user_id);
    res.json({ success: true, token, user: user.toPublicJSON() });
  } catch (err) { next(err); }
};

// GET /api/v1/auth/me
const getProfile = async (req, res, next) => {
  try {
    const user = await User.findByPk(req.user.user_id);
    res.json({ success: true, data: user.toPublicJSON() });
  } catch (err) { next(err); }
};

// PUT /api/v1/auth/me
const updateProfile = async (req, res, next) => {
  try {
    const { fullName, phone, vehicleType, preferences } = req.body;
    await req.user.update({ full_name: fullName, phone, vehicle_type: vehicleType, preferences });
    res.json({ success: true, data: req.user.toPublicJSON() });
  } catch (err) { next(err); }
};

module.exports = { register, login, getProfile, updateProfile };
