import express from 'express';
import { body, validationResult, query } from 'express-validator';
import { authMiddleware } from '../middleware/auth';
import db from '../config/database';
import { User, Tweet, ApiResponse } from '../types';
import { publishToKafka } from '../services/kafkaService';

const router = express.Router();

// Validation for profile updates
const updateProfileValidation = [
  body('display_name')
    .optional()
    .isLength({ min: 1, max: 100 })
    .withMessage('Display name must be between 1 and 100 characters'),
  body('bio')
    .optional()
    .isLength({ max: 500 })
    .withMessage('Bio must be less than 500 characters'),
  body('avatar_url')
    .optional()
    .isURL()
    .withMessage('Avatar URL must be a valid URL')
];

// Get user profile by username
router.get('/profile/:username', async (req, res) => {
  try {
    const { username } = req.params;

    const userQuery = `
      SELECT id, username, email, display_name, bio, avatar_url, verified,
             followers_count, following_count, tweets_count, created_at
      FROM users 
      WHERE username = $1
    `;

    const userResult = await db.query(userQuery, [username]);
    if (userResult.rowCount === 0) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    const user = userResult.rows[0];

    // Get user's recent tweets
    const tweetsQuery = `
      SELECT 
        t.id, t.content, t.image_url, t.likes_count, t.retweets_count, 
        t.replies_count, t.reply_to_id, t.created_at,
        u.id as user_id, u.username, u.display_name, u.avatar_url, u.verified
      FROM tweets t
      INNER JOIN users u ON t.user_id = u.id
      WHERE t.user_id = $1
      ORDER BY t.created_at DESC
      LIMIT 20
    `;

    const tweetsResult = await db.query(tweetsQuery, [user.id]);
    const tweets = tweetsResult.rows;

    const response: ApiResponse<{user: User, tweets: Tweet[]}> = {
      success: true,
      data: { user, tweets }
    };

    res.json(response);
  } catch (error) {
    console.error('Profile fetch error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch user profile'
    });
  }
});

// Update user profile
router.put('/profile', authMiddleware, updateProfileValidation, async (req: any, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors.array()
      });
    }

    const { display_name, bio, avatar_url } = req.body;
    const updateFields: string[] = [];
    const updateValues: any[] = [];
    let paramCount = 1;

    if (display_name !== undefined) {
      updateFields.push(`display_name = $${paramCount++}`);
      updateValues.push(display_name);
    }

    if (bio !== undefined) {
      updateFields.push(`bio = $${paramCount++}`);
      updateValues.push(bio);
    }

    if (avatar_url !== undefined) {
      updateFields.push(`avatar_url = $${paramCount++}`);
      updateValues.push(avatar_url);
    }

    if (updateFields.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'No fields to update'
      });
    }

    updateFields.push(`updated_at = CURRENT_TIMESTAMP`);
    updateValues.push(req.userId);

    const updateQuery = `
      UPDATE users 
      SET ${updateFields.join(', ')}
      WHERE id = $${paramCount}
      RETURNING id, username, email, display_name, bio, avatar_url, verified,
                followers_count, following_count, tweets_count, created_at, updated_at
    `;

    const result = await db.query(updateQuery, updateValues);
    const updatedUser = result.rows[0];

    const response: ApiResponse<User> = {
      success: true,
      data: updatedUser,
      message: 'Profile updated successfully'
    };

    res.json(response);
  } catch (error) {
    console.error('Profile update error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update profile'
    });
  }
});

// Follow user
router.post('/follow/:userId', authMiddleware, async (req: any, res) => {
  try {
    const targetUserId = parseInt(req.params.userId);
    if (isNaN(targetUserId)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid user ID'
      });
    }

    if (targetUserId === req.userId) {
      return res.status(400).json({
        success: false,
        error: 'Cannot follow yourself'
      });
    }

    // Check if target user exists
    const userCheck = await db.query('SELECT id, username FROM users WHERE id = $1', [targetUserId]);
    if (userCheck.rowCount === 0) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    const targetUser = userCheck.rows[0];

    // Check if already following
    const followCheck = await db.query(
      'SELECT id FROM follows WHERE follower_id = $1 AND following_id = $2',
      [req.userId, targetUserId]
    );

    if (followCheck.rowCount > 0) {
      return res.status(409).json({
        success: false,
        error: 'Already following this user'
      });
    }

    // Create follow relationship
    await db.query(
      'INSERT INTO follows (follower_id, following_id) VALUES ($1, $2)',
      [req.userId, targetUserId]
    );

    // Update follower/following counts
    await db.query('UPDATE users SET following_count = following_count + 1 WHERE id = $1', [req.userId]);
    await db.query('UPDATE users SET followers_count = followers_count + 1 WHERE id = $1', [targetUserId]);

    // Create notification
    await db.query(`
      INSERT INTO notifications (user_id, type, from_user_id, message)
      VALUES ($1, 'follow', $2, 'started following you')
    `, [targetUserId, req.userId]);

    // Publish to Kafka for real-time updates
    try {
      await publishToKafka('user-activity', {
        type: 'user_followed',
        followerId: req.userId,
        followingId: targetUserId,
        timestamp: new Date().toISOString()
      });
    } catch (kafkaError) {
      console.error('Kafka publish error:', kafkaError);
    }

    const response: ApiResponse<{following: boolean}> = {
      success: true,
      data: { following: true },
      message: `Now following ${targetUser.username}`
    };

    res.json(response);
  } catch (error) {
    console.error('Follow error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to follow user'
    });
  }
});

// Unfollow user
router.delete('/follow/:userId', authMiddleware, async (req: any, res) => {
  try {
    const targetUserId = parseInt(req.params.userId);
    if (isNaN(targetUserId)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid user ID'
      });
    }

    // Check if currently following
    const followCheck = await db.query(
      'SELECT id FROM follows WHERE follower_id = $1 AND following_id = $2',
      [req.userId, targetUserId]
    );

    if (followCheck.rowCount === 0) {
      return res.status(404).json({
        success: false,
        error: 'Not following this user'
      });
    }

    // Remove follow relationship
    await db.query(
      'DELETE FROM follows WHERE follower_id = $1 AND following_id = $2',
      [req.userId, targetUserId]
    );

    // Update follower/following counts
    await db.query('UPDATE users SET following_count = following_count - 1 WHERE id = $1', [req.userId]);
    await db.query('UPDATE users SET followers_count = followers_count - 1 WHERE id = $1', [targetUserId]);

    // Publish to Kafka for real-time updates
    try {
      await publishToKafka('user-activity', {
        type: 'user_unfollowed',
        followerId: req.userId,
        followingId: targetUserId,
        timestamp: new Date().toISOString()
      });
    } catch (kafkaError) {
      console.error('Kafka publish error:', kafkaError);
    }

    const response: ApiResponse<{following: boolean}> = {
      success: true,
      data: { following: false },
      message: 'Unfollowed successfully'
    };

    res.json(response);
  } catch (error) {
    console.error('Unfollow error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to unfollow user'
    });
  }
});

// Get user's followers
router.get('/:userId/followers', [
  query('page').optional().isInt({ min: 1 }).withMessage('Page must be a positive integer'),
  query('limit').optional().isInt({ min: 1, max: 50 }).withMessage('Limit must be between 1 and 50')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors.array()
      });
    }

    const userId = parseInt(req.params.userId);
    if (isNaN(userId)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid user ID'
      });
    }

    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;
    const offset = (page - 1) * limit;

    const followersQuery = `
      SELECT 
        u.id, u.username, u.display_name, u.avatar_url, u.verified,
        u.followers_count, u.following_count, u.tweets_count,
        f.created_at as followed_at
      FROM follows f
      INNER JOIN users u ON f.follower_id = u.id
      WHERE f.following_id = $1
      ORDER BY f.created_at DESC
      LIMIT $2 OFFSET $3
    `;

    const result = await db.query(followersQuery, [userId, limit, offset]);
    const followers = result.rows;

    const response: ApiResponse<User[]> = {
      success: true,
      data: followers,
      pagination: {
        page,
        limit,
        total: followers.length,
        hasMore: followers.length === limit
      }
    };

    res.json(response);
  } catch (error) {
    console.error('Followers fetch error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch followers'
    });
  }
});

// Get user's following
router.get('/:userId/following', [
  query('page').optional().isInt({ min: 1 }).withMessage('Page must be a positive integer'),
  query('limit').optional().isInt({ min: 1, max: 50 }).withMessage('Limit must be between 1 and 50')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors.array()
      });
    }

    const userId = parseInt(req.params.userId);
    if (isNaN(userId)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid user ID'
      });
    }

    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;
    const offset = (page - 1) * limit;

    const followingQuery = `
      SELECT 
        u.id, u.username, u.display_name, u.avatar_url, u.verified,
        u.followers_count, u.following_count, u.tweets_count,
        f.created_at as followed_at
      FROM follows f
      INNER JOIN users u ON f.following_id = u.id
      WHERE f.follower_id = $1
      ORDER BY f.created_at DESC
      LIMIT $2 OFFSET $3
    `;

    const result = await db.query(followingQuery, [userId, limit, offset]);
    const following = result.rows;

    const response: ApiResponse<User[]> = {
      success: true,
      data: following,
      pagination: {
        page,
        limit,
        total: following.length,
        hasMore: following.length === limit
      }
    };

    res.json(response);
  } catch (error) {
    console.error('Following fetch error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch following'
    });
  }
});

// Search users
router.get('/search', [
  query('q').notEmpty().withMessage('Search query is required'),
  query('page').optional().isInt({ min: 1 }).withMessage('Page must be a positive integer'),
  query('limit').optional().isInt({ min: 1, max: 50 }).withMessage('Limit must be between 1 and 50')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors.array()
      });
    }

    const searchQuery = req.query.q as string;
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;
    const offset = (page - 1) * limit;

    const usersQuery = `
      SELECT 
        id, username, display_name, avatar_url, verified,
        followers_count, following_count, tweets_count, bio
      FROM users
      WHERE 
        username ILIKE $1 OR 
        display_name ILIKE $1 OR 
        bio ILIKE $1
      ORDER BY followers_count DESC, username ASC
      LIMIT $2 OFFSET $3
    `;

    const searchPattern = `%${searchQuery}%`;
    const result = await db.query(usersQuery, [searchPattern, limit, offset]);
    const users = result.rows;

    const response: ApiResponse<User[]> = {
      success: true,
      data: users,
      pagination: {
        page,
        limit,
        total: users.length,
        hasMore: users.length === limit
      }
    };

    res.json(response);
  } catch (error) {
    console.error('User search error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to search users'
    });
  }
});

export default router; 