import { Server } from 'socket.io';
import jwt from 'jsonwebtoken';
import { redisClient } from '../config/redis';

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';

export const initializeSocketHandlers = (io: Server) => {
  // Authentication middleware for Socket.IO
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.replace('Bearer ', '');
      
      if (!token) {
        return next(new Error('Authentication error: No token provided'));
      }

      const decoded = jwt.verify(token, JWT_SECRET) as any;
      const sessionKey = `session:${decoded.userId}:${token}`;
      const session = await redisClient.get(sessionKey);

      if (!session) {
        return next(new Error('Authentication error: Session expired'));
      }

      socket.userId = decoded.userId;
      socket.username = decoded.username;
      next();
    } catch (error) {
      next(new Error('Authentication error: Invalid token'));
    }
  });

  io.on('connection', (socket) => {
    console.log(`✅ User ${socket.username} connected via Socket.IO`);

    // Join user to their personal room for notifications
    socket.join(`user:${socket.userId}`);

    // Handle joining tweet rooms for real-time updates
    socket.on('join_tweet', (tweetId: string) => {
      socket.join(`tweet:${tweetId}`);
      console.log(`User ${socket.username} joined tweet room: ${tweetId}`);
    });

    // Handle leaving tweet rooms
    socket.on('leave_tweet', (tweetId: string) => {
      socket.leave(`tweet:${tweetId}`);
      console.log(`User ${socket.username} left tweet room: ${tweetId}`);
    });

    // Handle joining user profile rooms
    socket.on('join_user', (username: string) => {
      socket.join(`profile:${username}`);
      console.log(`User ${socket.username} joined profile room: ${username}`);
    });

    // Handle leaving user profile rooms
    socket.on('leave_user', (username: string) => {
      socket.leave(`profile:${username}`);
      console.log(`User ${socket.username} left profile room: ${username}`);
    });

    // Handle typing indicators for replies
    socket.on('typing_start', (data: { tweetId: string }) => {
      socket.to(`tweet:${data.tweetId}`).emit('user_typing', {
        userId: socket.userId,
        username: socket.username,
        tweetId: data.tweetId
      });
    });

    socket.on('typing_stop', (data: { tweetId: string }) => {
      socket.to(`tweet:${data.tweetId}`).emit('user_stopped_typing', {
        userId: socket.userId,
        username: socket.username,
        tweetId: data.tweetId
      });
    });

    // Handle user presence
    socket.on('user_online', () => {
      socket.broadcast.emit('user_status', {
        userId: socket.userId,
        username: socket.username,
        status: 'online'
      });
    });

    // Handle disconnection
    socket.on('disconnect', () => {
      console.log(`❌ User ${socket.username} disconnected from Socket.IO`);
      
      // Broadcast user offline status
      socket.broadcast.emit('user_status', {
        userId: socket.userId,
        username: socket.username,
        status: 'offline'
      });
    });

    // Handle errors
    socket.on('error', (error) => {
      console.error(`Socket error for user ${socket.username}:`, error);
    });
  });

  console.log('✅ Socket.IO handlers initialized');
};

// Helper functions to emit events to specific rooms
export const emitToUser = (io: Server, userId: number, event: string, data: any) => {
  io.to(`user:${userId}`).emit(event, data);
};

export const emitToTweet = (io: Server, tweetId: number, event: string, data: any) => {
  io.to(`tweet:${tweetId}`).emit(event, data);
};

export const emitToProfile = (io: Server, username: string, event: string, data: any) => {
  io.to(`profile:${username}`).emit(event, data);
};

export const emitToAll = (io: Server, event: string, data: any) => {
  io.emit(event, data);
}; 