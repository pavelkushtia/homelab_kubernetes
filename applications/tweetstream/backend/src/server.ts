import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import { createServer } from 'http';
import { Server } from 'socket.io';
import dotenv from 'dotenv';

import { connectRedis } from './config/redis';
import { connectKafka, disconnectKafka } from './config/kafka';
import db from './config/database';

// Import routes
import authRoutes from './routes/auth';
import userRoutes from './routes/users';
import tweetRoutes from './routes/tweets';
import notificationRoutes from './routes/notifications';

// Import services
import { initializeSocketHandlers } from './services/socketService';
import { initializeKafkaConsumer, initializeKafkaProducer } from './services/kafkaService';

dotenv.config();

const app = express();
const server = createServer(app);
const io = new Server(server, {
  cors: {
    origin: process.env.FRONTEND_URL || "http://localhost:3000",
    methods: ["GET", "POST"]
  }
});

const PORT = process.env.PORT || 5000;

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});

// Middleware
app.use(helmet());
app.use(compression());
app.use(morgan('combined'));
app.use(cors({
  origin: process.env.FRONTEND_URL || "http://localhost:3000",
  credentials: true
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use('/api/', limiter);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    services: {
      database: 'connected',
      redis: 'connected', 
      kafka: 'connected'
    }
  });
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/tweets', tweetRoutes);
app.use('/api/notifications', notificationRoutes);

// Error handling middleware
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('❌ Error:', err);
  res.status(err.status || 500).json({
    success: false,
    error: process.env.NODE_ENV === 'production' ? 'Internal server error' : err.message
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    error: 'Route not found'
  });
});

// Initialize connections and start server
async function startServer() {
  try {
    // Test database connection
    await db.query('SELECT 1');
    console.log('✅ Database connection established');

    // Connect to Redis
    await connectRedis();

    // Connect to Kafka
    await connectKafka();

    // Initialize Kafka producer
    await initializeKafkaProducer();

    // Initialize Socket.IO handlers
    initializeSocketHandlers(io);

    // Initialize Kafka consumer for real-time updates
    await initializeKafkaConsumer(io);

    // Start server
    server.listen(PORT, () => {
      console.log(`🚀 TweetStream Backend running on port ${PORT}`);
      console.log(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
      console.log(`🔗 Health check: http://localhost:${PORT}/health`);
    });

  } catch (error) {
    console.error('❌ Failed to start server:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('📴 Received SIGTERM, shutting down gracefully...');
  
  server.close(async () => {
    await disconnectKafka();
    await db.end();
    console.log('✅ Server shutdown complete');
    process.exit(0);
  });
});

process.on('SIGINT', async () => {
  console.log('📴 Received SIGINT, shutting down gracefully...');
  
  server.close(async () => {
    await disconnectKafka();
    await db.end();
    console.log('✅ Server shutdown complete');
    process.exit(0);
  });
});

// Start the server
startServer();

export { app, server, io }; 