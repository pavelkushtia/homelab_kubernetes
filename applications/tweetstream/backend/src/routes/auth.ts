import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { body, validationResult } from 'express-validator';
import db from '../config/database';
import { redisClient } from '../config/redis';
import { User, CreateUserRequest, LoginRequest, AuthResponse, ApiResponse } from '../types';

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';

// Registration validation
const registerValidation = [
  body('username')
    .isLength({ min: 3, max: 50 })
    .matches(/^[a-zA-Z0-9_]+$/)
    .withMessage('Username must be 3-50 characters and contain only letters, numbers, and underscores'),
  body('email').isEmail().withMessage('Valid email is required'),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
  body('display_name').isLength({ min: 1, max: 100 }).withMessage('Display name is required')
];

// Login validation
const loginValidation = [
  body('username').notEmpty().withMessage('Username is required'),
  body('password').notEmpty().withMessage('Password is required')
];

// Register new user
router.post('/register', registerValidation, async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors.array()
      });
    }

    const { username, email, password, display_name, bio }: CreateUserRequest = req.body;

    // Check if user already exists
    const existingUser = await db.query(
      'SELECT id FROM users WHERE username = $1 OR email = $2',
      [username, email]
    );

    if (existingUser.rowCount && existingUser.rowCount > 0) {
      return res.status(409).json({
        success: false,
        error: 'Username or email already exists'
      });
    }

    // Hash password
    const saltRounds = 12;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    // Create user
    const result = await db.query(`
      INSERT INTO users (username, email, password_hash, display_name, bio)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id, username, email, display_name, bio, avatar_url, verified, 
                followers_count, following_count, tweets_count, created_at, updated_at
    `, [username, email, passwordHash, display_name, bio || null]);

    const user: User = result.rows[0];

    // Generate JWT token
    const token = jwt.sign(
      { userId: user.id, username: user.username },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );

    // Store session in Redis
    const sessionKey = `session:${user.id}:${token}`;
    await redisClient.setEx(sessionKey, 7 * 24 * 60 * 60, JSON.stringify({ userId: user.id })); // 7 days

    const response: ApiResponse<AuthResponse> = {
      success: true,
      data: { user, token },
      message: 'Registration successful'
    };

    res.status(201).json(response);
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({
      success: false,
      error: 'Registration failed'
    });
  }
});

// Login user
router.post('/login', loginValidation, async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors.array()
      });
    }

    const { username, password }: LoginRequest = req.body;

    // Find user
    const result = await db.query(`
      SELECT id, username, email, password_hash, display_name, bio, avatar_url, verified,
             followers_count, following_count, tweets_count, created_at, updated_at
      FROM users 
      WHERE username = $1 OR email = $1
    `, [username]);

    if (!result.rowCount || result.rowCount === 0) {
      return res.status(401).json({
        success: false,
        error: 'Invalid credentials'
      });
    }

    const user = result.rows[0];

    // Verify password
    const passwordValid = await bcrypt.compare(password, user.password_hash);
    if (!passwordValid) {
      return res.status(401).json({
        success: false,
        error: 'Invalid credentials'
      });
    }

    // Remove password hash from response
    delete user.password_hash;

    // Generate JWT token
    const token = jwt.sign(
      { userId: user.id, username: user.username },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );

    // Store session in Redis
    const sessionKey = `session:${user.id}:${token}`;
    await redisClient.setEx(sessionKey, 7 * 24 * 60 * 60, JSON.stringify({ userId: user.id }));

    const response: ApiResponse<AuthResponse> = {
      success: true,
      data: { user, token },
      message: 'Login successful'
    };

    res.json(response);
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      error: 'Login failed'
    });
  }
});

// Logout user
router.post('/logout', async (req, res) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');
    
    if (token) {
      try {
        const decoded = jwt.verify(token, JWT_SECRET) as any;
        const sessionKey = `session:${decoded.userId}:${token}`;
        await redisClient.del(sessionKey);
      } catch (error) {
        // Token invalid, but that's okay for logout
      }
    }

    res.json({
      success: true,
      message: 'Logged out successfully'
    });
  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({
      success: false,
      error: 'Logout failed'
    });
  }
});

// Verify token
router.get('/verify', async (req, res) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({
        success: false,
        error: 'No token provided'
      });
    }

    const decoded = jwt.verify(token, JWT_SECRET) as any;
    const sessionKey = `session:${decoded.userId}:${token}`;
    const session = await redisClient.get(sessionKey);

    if (!session) {
      return res.status(401).json({
        success: false,
        error: 'Session expired'
      });
    }

    // Get current user data
    const result = await db.query(`
      SELECT id, username, email, display_name, bio, avatar_url, verified,
             followers_count, following_count, tweets_count, created_at, updated_at
      FROM users 
      WHERE id = $1
    `, [decoded.userId]);

    if (!result.rowCount || result.rowCount === 0) {
      return res.status(401).json({
        success: false,
        error: 'User not found'
      });
    }

    const user: User = result.rows[0];

    res.json({
      success: true,
      data: { user, token },
      message: 'Token valid'
    });
  } catch (error) {
    console.error('Token verification error:', error);
    res.status(401).json({
      success: false,
      error: 'Invalid token'
    });
  }
});

export default router; 