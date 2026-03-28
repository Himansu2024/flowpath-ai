// backend/src/routes/userRoutes.js
const express = require('express');
const router  = express.Router();
const { body } = require('express-validator');
const { authenticate } = require('../middleware/authMiddleware');
const user = require('../controllers/userController');

router.post('/auth/register',
  [
    body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
    body('password').isLength({ min: 8 }).withMessage('Password must be at least 8 characters'),
    body('fullName').optional().trim().isLength({ min: 2 }),
  ],
  user.register
);

router.post('/auth/login',
  [
    body('email').isEmail().normalizeEmail(),
    body('password').notEmpty(),
  ],
  user.login
);

router.get('/auth/me',  authenticate, user.getProfile);
router.put('/auth/me',  authenticate, user.updateProfile);

module.exports = router;
