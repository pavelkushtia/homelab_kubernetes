import { Pool } from 'pg';

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME || 'tweetstream',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
  ssl: false
});

// Test connection
pool.on('connect', () => {
  console.log('✅ Connected to PostgreSQL platform service');
});

pool.on('error', (err: Error) => {
  console.error('❌ PostgreSQL connection error:', err);
});

export default pool; 