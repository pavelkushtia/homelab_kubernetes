import express from 'express';
import { body, validationResult, query } from 'express-validator';
import { authMiddleware } from '../middleware/auth';
import db from '../config/database';
import { Tweet, ApiResponse, CreateTweetRequest } from '../types';
import { publishToKafka } from '../services/kafkaService';

const router = express.Router();

// Get all tweets (public endpoint for cross-user functionality)
router.get('/', [
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

    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;
    const offset = (page - 1) * limit;

    // Get all tweets from all users (true cross-user functionality)
    const allTweetsQuery = `
      SELECT 
        t.id, t.content, t.image_url, t.likes_count, t.retweets_count, 
        t.replies_count, t.reply_to_id, t.created_at,
        u.id as user_id, u.username, u.display_name, u.avatar_url, u.verified,
        CASE WHEN t.reply_to_id IS NOT NULL THEN
          json_build_object(
            'id', rt.id,
            'content', rt.content,
            'user', json_build_object(
              'username', ru.username,
              'display_name', ru.display_name
            )
          )
        ELSE NULL END as reply_to
      FROM tweets t
      INNER JOIN users u ON t.user_id = u.id
      LEFT JOIN tweets rt ON t.reply_to_id = rt.id
      LEFT JOIN users ru ON rt.user_id = ru.id
      ORDER BY t.created_at DESC
      LIMIT $1 OFFSET $2
    `;

    const result = await db.query(allTweetsQuery, [limit, offset]);
    const tweets = result.rows;

    // Get total count for pagination
    const countResult = await db.query('SELECT COUNT(*) as total FROM tweets');
    const total = parseInt(countResult.rows[0].total);

    const response: ApiResponse<Tweet[]> = {
      success: true,
      data: tweets,
      pagination: {
        page,
        limit,
        total,
        hasMore: offset + tweets.length < total
      },
      message: `Retrieved ${tweets.length} tweets from all users`
    };

    res.json(response);
  } catch (error) {
    console.error('All tweets fetch error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch tweets'
    });
  }
});

// Validation for creating tweets
const createTweetValidation = [
  body('content')
    .isLength({ min: 1, max: 280 })
    .withMessage('Tweet content must be between 1 and 280 characters'),
  body('reply_to_id')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Reply to ID must be a valid tweet ID')
];

// Get tweet feed with pagination
router.get('/feed', authMiddleware, [
  query('page').optional().isInt({ min: 1 }).withMessage('Page must be a positive integer'),
  query('limit').optional().isInt({ min: 1, max: 50 }).withMessage('Limit must be between 1 and 50')
], async (req: any, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors.array()
      });
    }

    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    // Get tweets from users that the current user follows + own tweets
    const feedQuery = `
      WITH user_feed AS (
        SELECT DISTINCT t.id
        FROM tweets t
        LEFT JOIN follows f ON t.user_id = f.following_id
        WHERE f.follower_id = $1 OR t.user_id = $1
      )
      SELECT 
        t.id, t.content, t.image_url, t.likes_count, t.retweets_count, 
        t.replies_count, t.reply_to_id, t.created_at,
        u.id as user_id, u.username, u.display_name, u.avatar_url, u.verified,
        EXISTS(SELECT 1 FROM likes WHERE user_id = $1 AND tweet_id = t.id) as liked_by_user,
        EXISTS(SELECT 1 FROM retweets WHERE user_id = $1 AND tweet_id = t.id) as retweeted_by_user,
        CASE WHEN t.reply_to_id IS NOT NULL THEN
          json_build_object(
            'id', rt.id,
            'content', rt.content,
            'user', json_build_object(
              'username', ru.username,
              'display_name', ru.display_name
            )
          )
        ELSE NULL END as reply_to
      FROM tweets t
      INNER JOIN user_feed uf ON t.id = uf.id
      INNER JOIN users u ON t.user_id = u.id
      LEFT JOIN tweets rt ON t.reply_to_id = rt.id
      LEFT JOIN users ru ON rt.user_id = ru.id
      ORDER BY t.created_at DESC
      LIMIT $2 OFFSET $3
    `;

    const result = await db.query(feedQuery, [req.userId, limit, offset]);
    const tweets = result.rows;

    const response: ApiResponse<Tweet[]> = {
      success: true,
      data: tweets,
      pagination: {
        page,
        limit,
        total: tweets.length,
        hasMore: tweets.length === limit
      }
    };

    res.json(response);
  } catch (error) {
    console.error('Feed fetch error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch feed'
    });
  }
});

// Get public tweets (trending/discover)
router.get('/public', [
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

    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;
    const offset = (page - 1) * limit;

    const publicQuery = `
      SELECT 
        t.id, t.content, t.image_url, t.likes_count, t.retweets_count, 
        t.replies_count, t.reply_to_id, t.created_at,
        u.id as user_id, u.username, u.display_name, u.avatar_url, u.verified
      FROM tweets t
      INNER JOIN users u ON t.user_id = u.id
      ORDER BY (t.likes_count + t.retweets_count * 2) DESC, t.created_at DESC
      LIMIT $1 OFFSET $2
    `;

    const result = await db.query(publicQuery, [limit, offset]);
    const tweets = result.rows;

    const response: ApiResponse<Tweet[]> = {
      success: true,
      data: tweets,
      pagination: {
        page,
        limit,
        total: tweets.length,
        hasMore: tweets.length === limit
      }
    };

    res.json(response);
  } catch (error) {
    console.error('Public tweets fetch error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch public tweets'
    });
  }
});

// Create new tweet
router.post('/', authMiddleware, createTweetValidation, async (req: any, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors.array()
      });
    }

    const { content, image_url, reply_to_id }: CreateTweetRequest = req.body;

    // If replying to a tweet, verify it exists
    if (reply_to_id) {
      const replyCheck = await db.query('SELECT id FROM tweets WHERE id = $1', [reply_to_id]);
      if (replyCheck.rowCount === 0) {
        return res.status(404).json({
          success: false,
          error: 'Tweet to reply to not found'
        });
      }
    }

    // Insert tweet
    const insertResult = await db.query(`
      INSERT INTO tweets (user_id, content, image_url, reply_to_id)
      VALUES ($1, $2, $3, $4)
      RETURNING id, content, image_url, likes_count, retweets_count, 
                replies_count, reply_to_id, created_at
    `, [req.userId, content, image_url || null, reply_to_id || null]);

    const tweet = insertResult.rows[0];

    // Update user's tweet count
    await db.query('UPDATE users SET tweets_count = tweets_count + 1 WHERE id = $1', [req.userId]);

    // If this is a reply, update the parent tweet's reply count
    if (reply_to_id) {
      await db.query('UPDATE tweets SET replies_count = replies_count + 1 WHERE id = $1', [reply_to_id]);
    }

    // Get user info for the response
    const userResult = await db.query(
      'SELECT username, display_name, avatar_url, verified FROM users WHERE id = $1',
      [req.userId]
    );
    const user = userResult.rows[0];

    const tweetWithUser = {
      ...tweet,
      user_id: req.userId,
      user
    };

    // Publish to Kafka for real-time updates
    try {
      await publishToKafka('tweets', {
        type: 'tweet_created',
        tweet: tweetWithUser,
        timestamp: new Date().toISOString()
      });
    } catch (kafkaError) {
      console.error('Kafka publish error:', kafkaError);
      // Don't fail the request if Kafka fails
    }

    const response: ApiResponse<typeof tweetWithUser> = {
      success: true,
      data: tweetWithUser,
      message: 'Tweet created successfully'
    };

    res.status(201).json(response);
  } catch (error) {
    console.error('Tweet creation error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create tweet'
    });
  }
});

// Get specific tweet with replies
router.get('/:id', async (req, res) => {
  try {
    const tweetId = parseInt(req.params.id);
    if (isNaN(tweetId)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid tweet ID'
      });
    }

    // Get main tweet
    const tweetQuery = `
      SELECT 
        t.id, t.content, t.image_url, t.likes_count, t.retweets_count, 
        t.replies_count, t.reply_to_id, t.created_at,
        u.id as user_id, u.username, u.display_name, u.avatar_url, u.verified
      FROM tweets t
      INNER JOIN users u ON t.user_id = u.id
      WHERE t.id = $1
    `;

    const tweetResult = await db.query(tweetQuery, [tweetId]);
    if (tweetResult.rowCount === 0) {
      return res.status(404).json({
        success: false,
        error: 'Tweet not found'
      });
    }

    const tweet = tweetResult.rows[0];

    // Get replies
    const repliesQuery = `
      SELECT 
        t.id, t.content, t.image_url, t.likes_count, t.retweets_count, 
        t.replies_count, t.reply_to_id, t.created_at,
        u.id as user_id, u.username, u.display_name, u.avatar_url, u.verified
      FROM tweets t
      INNER JOIN users u ON t.user_id = u.id
      WHERE t.reply_to_id = $1
      ORDER BY t.created_at ASC
    `;

    const repliesResult = await db.query(repliesQuery, [tweetId]);
    const replies = repliesResult.rows;

    const response: ApiResponse<{tweet: typeof tweet, replies: typeof replies}> = {
      success: true,
      data: { tweet, replies }
    };

    res.json(response);
  } catch (error) {
    console.error('Tweet fetch error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch tweet'
    });
  }
});

// Like/unlike tweet
router.post('/:id/like', authMiddleware, async (req: any, res) => {
  try {
    const tweetId = parseInt(req.params.id);
    if (isNaN(tweetId)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid tweet ID'
      });
    }

    // Check if tweet exists
    const tweetCheck = await db.query('SELECT id, user_id FROM tweets WHERE id = $1', [tweetId]);
    if (tweetCheck.rowCount === 0) {
      return res.status(404).json({
        success: false,
        error: 'Tweet not found'
      });
    }

    const tweet = tweetCheck.rows[0];

    // Check if already liked
    const likeCheck = await db.query(
      'SELECT id FROM likes WHERE user_id = $1 AND tweet_id = $2',
      [req.userId, tweetId]
    );

    let liked = false;
    let likesCount = 0;

    if (likeCheck.rowCount > 0) {
      // Unlike
      await db.query('DELETE FROM likes WHERE user_id = $1 AND tweet_id = $2', [req.userId, tweetId]);
      const countResult = await db.query(
        'UPDATE tweets SET likes_count = likes_count - 1 WHERE id = $1 RETURNING likes_count',
        [tweetId]
      );
      likesCount = countResult.rows[0].likes_count;
      liked = false;
    } else {
      // Like
      await db.query(
        'INSERT INTO likes (user_id, tweet_id) VALUES ($1, $2)',
        [req.userId, tweetId]
      );
      const countResult = await db.query(
        'UPDATE tweets SET likes_count = likes_count + 1 WHERE id = $1 RETURNING likes_count',
        [tweetId]
      );
      likesCount = countResult.rows[0].likes_count;
      liked = true;

      // Create notification for tweet owner (if not liking own tweet)
      if (tweet.user_id !== req.userId) {
        await db.query(`
          INSERT INTO notifications (user_id, type, from_user_id, tweet_id, message)
          VALUES ($1, 'like', $2, $3, 'liked your tweet')
        `, [tweet.user_id, req.userId, tweetId]);
      }
    }

    // Publish to Kafka for real-time updates
    try {
      await publishToKafka('user-activity', {
        type: liked ? 'tweet_liked' : 'tweet_unliked',
        userId: req.userId,
        tweetId,
        tweetOwnerId: tweet.user_id,
        likesCount,
        timestamp: new Date().toISOString()
      });
    } catch (kafkaError) {
      console.error('Kafka publish error:', kafkaError);
    }

    const response: ApiResponse<{liked: boolean, likesCount: number}> = {
      success: true,
      data: { liked, likesCount },
      message: liked ? 'Tweet liked' : 'Tweet unliked'
    };

    res.json(response);
  } catch (error) {
    console.error('Like/unlike error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to like/unlike tweet'
    });
  }
});

// Retweet/unretweet
router.post('/:id/retweet', authMiddleware, async (req: any, res) => {
  try {
    const tweetId = parseInt(req.params.id);
    if (isNaN(tweetId)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid tweet ID'
      });
    }

    // Check if tweet exists
    const tweetCheck = await db.query('SELECT id, user_id FROM tweets WHERE id = $1', [tweetId]);
    if (tweetCheck.rowCount === 0) {
      return res.status(404).json({
        success: false,
        error: 'Tweet not found'
      });
    }

    const tweet = tweetCheck.rows[0];

    // Check if already retweeted
    const retweetCheck = await db.query(
      'SELECT id FROM retweets WHERE user_id = $1 AND tweet_id = $2',
      [req.userId, tweetId]
    );

    let retweeted = false;
    let retweetsCount = 0;

    if (retweetCheck.rowCount > 0) {
      // Unretweet
      await db.query('DELETE FROM retweets WHERE user_id = $1 AND tweet_id = $2', [req.userId, tweetId]);
      const countResult = await db.query(
        'UPDATE tweets SET retweets_count = retweets_count - 1 WHERE id = $1 RETURNING retweets_count',
        [tweetId]
      );
      retweetsCount = countResult.rows[0].retweets_count;
      retweeted = false;
    } else {
      // Retweet
      await db.query(
        'INSERT INTO retweets (user_id, tweet_id) VALUES ($1, $2)',
        [req.userId, tweetId]
      );
      const countResult = await db.query(
        'UPDATE tweets SET retweets_count = retweets_count + 1 WHERE id = $1 RETURNING retweets_count',
        [tweetId]
      );
      retweetsCount = countResult.rows[0].retweets_count;
      retweeted = true;

      // Create notification for tweet owner (if not retweeting own tweet)
      if (tweet.user_id !== req.userId) {
        await db.query(`
          INSERT INTO notifications (user_id, type, from_user_id, tweet_id, message)
          VALUES ($1, 'retweet', $2, $3, 'retweeted your tweet')
        `, [tweet.user_id, req.userId, tweetId]);
      }
    }

    // Publish to Kafka for real-time updates
    try {
      await publishToKafka('user-activity', {
        type: retweeted ? 'tweet_retweeted' : 'tweet_unretweeted',
        userId: req.userId,
        tweetId,
        tweetOwnerId: tweet.user_id,
        retweetsCount,
        timestamp: new Date().toISOString()
      });
    } catch (kafkaError) {
      console.error('Kafka publish error:', kafkaError);
    }

    const response: ApiResponse<{retweeted: boolean, retweetsCount: number}> = {
      success: true,
      data: { retweeted, retweetsCount },
      message: retweeted ? 'Tweet retweeted' : 'Tweet unretweeted'
    };

    res.json(response);
  } catch (error) {
    console.error('Retweet/unretweet error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retweet/unretweet tweet'
    });
  }
});

// Delete tweet
router.delete('/:id', authMiddleware, async (req: any, res) => {
  try {
    const tweetId = parseInt(req.params.id);
    if (isNaN(tweetId)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid tweet ID'
      });
    }

    // Check if tweet exists and belongs to user
    const tweetCheck = await db.query(
      'SELECT id, user_id FROM tweets WHERE id = $1',
      [tweetId]
    );

    if (tweetCheck.rowCount === 0) {
      return res.status(404).json({
        success: false,
        error: 'Tweet not found'
      });
    }

    const tweet = tweetCheck.rows[0];
    if (tweet.user_id !== req.userId) {
      return res.status(403).json({
        success: false,
        error: 'You can only delete your own tweets'
      });
    }

    // Delete tweet (cascade will handle likes, retweets, notifications)
    await db.query('DELETE FROM tweets WHERE id = $1', [tweetId]);

    // Update user's tweet count
    await db.query('UPDATE users SET tweets_count = tweets_count - 1 WHERE id = $1', [req.userId]);

    res.json({
      success: true,
      message: 'Tweet deleted successfully'
    });
  } catch (error) {
    console.error('Tweet deletion error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete tweet'
    });
  }
});

export default router; 