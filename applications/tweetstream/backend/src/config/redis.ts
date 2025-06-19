import { createClient, RedisClientType } from 'redis';

const redisClient: RedisClientType = createClient({
  socket: {
    host: process.env.REDIS_HOST || 'redis-master.platform-services.svc.cluster.local',
    port: parseInt(process.env.REDIS_PORT || '6379')
  },
  password: process.env.REDIS_PASSWORD
});

redisClient.on('connect', () => {
  console.log('✅ Connected to Redis platform service');
});

redisClient.on('error', (err: Error) => {
  console.error('❌ Redis connection error:', err);
});

// Initialize connection
const connectRedis = async (): Promise<void> => {
  try {
    await redisClient.connect();
  } catch (error) {
    console.error('❌ Failed to connect to Redis:', error);
  }
};

export { redisClient, connectRedis }; 