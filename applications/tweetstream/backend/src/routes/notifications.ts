import express from 'express';
import { query, validationResult } from 'express-validator';
import { authMiddleware } from '../middleware/auth';
import db from '../config/database';
import { Notification, ApiResponse } from '../types';

const router = express.Router();

// Get notifications for authenticated user
router.get('/', authMiddleware, [
  query('page').optional().isInt({ min: 1 }).withMessage('Page must be a positive integer'),
  query('limit').optional().isInt({ min: 1, max: 50 }).withMessage('Limit must be between 1 and 50'),
  query('unread_only').optional().isBoolean().withMessage('Unread only must be a boolean')
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
    const unreadOnly = req.query.unread_only === 'true';

    let whereClause = 'WHERE n.user_id = $1';
    const queryParams = [req.userId, limit, offset];

    if (unreadOnly) {
      whereClause += ' AND n.read = false';
    }

    const notificationsQuery = `
      SELECT 
        n.id, n.type, n.message, n.read, n.created_at, n.tweet_id,
        fu.id as from_user_id, fu.username as from_username, 
        fu.display_name as from_display_name, fu.avatar_url as from_avatar_url,
        fu.verified as from_verified,
        CASE WHEN n.tweet_id IS NOT NULL THEN
          json_build_object(
            'id', t.id,
            'content', t.content,
            'created_at', t.created_at
          )
        ELSE NULL END as tweet
      FROM notifications n
      LEFT JOIN users fu ON n.from_user_id = fu.id
      LEFT JOIN tweets t ON n.tweet_id = t.id
      ${whereClause}
      ORDER BY n.created_at DESC
      LIMIT $2 OFFSET $3
    `;

    const result = await db.query(notificationsQuery, queryParams);
    const notifications = result.rows.map(row => ({
      id: row.id,
      type: row.type,
      message: row.message,
      read: row.read,
      created_at: row.created_at,
      tweet_id: row.tweet_id,
      from_user: row.from_user_id ? {
        id: row.from_user_id,
        username: row.from_username,
        display_name: row.from_display_name,
        avatar_url: row.from_avatar_url,
        verified: row.from_verified
      } : null,
      tweet: row.tweet
    }));

    // Get unread count
    const unreadCountResult = await db.query(
      'SELECT COUNT(*) as unread_count FROM notifications WHERE user_id = $1 AND read = false',
      [req.userId]
    );
    const unreadCount = parseInt(unreadCountResult.rows[0].unread_count);

    const response: ApiResponse<{notifications: Notification[], unreadCount: number}> = {
      success: true,
      data: { notifications, unreadCount },
      pagination: {
        page,
        limit,
        total: notifications.length,
        hasMore: notifications.length === limit
      }
    };

    res.json(response);
  } catch (error) {
    console.error('Notifications fetch error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch notifications'
    });
  }
});

// Mark notification as read
router.put('/:id/read', authMiddleware, async (req: any, res) => {
  try {
    const notificationId = parseInt(req.params.id);
    if (isNaN(notificationId)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid notification ID'
      });
    }

    // Check if notification exists and belongs to user
    const notificationCheck = await db.query(
      'SELECT id, user_id, read FROM notifications WHERE id = $1',
      [notificationId]
    );

    if (notificationCheck.rowCount === 0) {
      return res.status(404).json({
        success: false,
        error: 'Notification not found'
      });
    }

    const notification = notificationCheck.rows[0];
    if (notification.user_id !== req.userId) {
      return res.status(403).json({
        success: false,
        error: 'You can only mark your own notifications as read'
      });
    }

    if (notification.read) {
      return res.status(200).json({
        success: true,
        message: 'Notification already marked as read'
      });
    }

    // Mark as read
    await db.query(
      'UPDATE notifications SET read = true WHERE id = $1',
      [notificationId]
    );

    res.json({
      success: true,
      message: 'Notification marked as read'
    });
  } catch (error) {
    console.error('Mark notification read error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to mark notification as read'
    });
  }
});

// Mark all notifications as read
router.put('/read-all', authMiddleware, async (req: any, res) => {
  try {
    const result = await db.query(
      'UPDATE notifications SET read = true WHERE user_id = $1 AND read = false',
      [req.userId]
    );

    const markedCount = result.rowCount || 0;

    res.json({
      success: true,
      message: `Marked ${markedCount} notifications as read`,
      data: { markedCount }
    });
  } catch (error) {
    console.error('Mark all notifications read error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to mark all notifications as read'
    });
  }
});

// Delete notification
router.delete('/:id', authMiddleware, async (req: any, res) => {
  try {
    const notificationId = parseInt(req.params.id);
    if (isNaN(notificationId)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid notification ID'
      });
    }

    // Check if notification exists and belongs to user
    const notificationCheck = await db.query(
      'SELECT id, user_id FROM notifications WHERE id = $1',
      [notificationId]
    );

    if (notificationCheck.rowCount === 0) {
      return res.status(404).json({
        success: false,
        error: 'Notification not found'
      });
    }

    const notification = notificationCheck.rows[0];
    if (notification.user_id !== req.userId) {
      return res.status(403).json({
        success: false,
        error: 'You can only delete your own notifications'
      });
    }

    // Delete notification
    await db.query('DELETE FROM notifications WHERE id = $1', [notificationId]);

    res.json({
      success: true,
      message: 'Notification deleted successfully'
    });
  } catch (error) {
    console.error('Delete notification error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete notification'
    });
  }
});

// Get notification statistics
router.get('/stats', authMiddleware, async (req: any, res) => {
  try {
    const statsQuery = `
      SELECT 
        COUNT(*) as total_count,
        COUNT(CASE WHEN read = false THEN 1 END) as unread_count,
        COUNT(CASE WHEN type = 'like' THEN 1 END) as likes_count,
        COUNT(CASE WHEN type = 'retweet' THEN 1 END) as retweets_count,
        COUNT(CASE WHEN type = 'follow' THEN 1 END) as follows_count,
        COUNT(CASE WHEN type = 'reply' THEN 1 END) as replies_count,
        COUNT(CASE WHEN type = 'mention' THEN 1 END) as mentions_count
      FROM notifications 
      WHERE user_id = $1
    `;

    const result = await db.query(statsQuery, [req.userId]);
    const stats = result.rows[0];

    // Convert string counts to numbers
    const formattedStats = {
      total_count: parseInt(stats.total_count),
      unread_count: parseInt(stats.unread_count),
      likes_count: parseInt(stats.likes_count),
      retweets_count: parseInt(stats.retweets_count),
      follows_count: parseInt(stats.follows_count),
      replies_count: parseInt(stats.replies_count),
      mentions_count: parseInt(stats.mentions_count)
    };

    const response: ApiResponse<typeof formattedStats> = {
      success: true,
      data: formattedStats
    };

    res.json(response);
  } catch (error) {
    console.error('Notification stats error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch notification statistics'
    });
  }
});

export default router; 