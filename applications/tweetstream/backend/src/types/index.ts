// User types
export interface User {
  id: number;
  username: string;
  email: string;
  display_name: string;
  bio?: string;
  avatar_url?: string;
  verified: boolean;
  followers_count: number;
  following_count: number;
  tweets_count: number;
  created_at: Date;
  updated_at: Date;
}

export interface CreateUserRequest {
  username: string;
  email: string;
  password: string;
  display_name: string;
  bio?: string;
}

export interface LoginRequest {
  username: string;
  password: string;
}

export interface AuthResponse {
  user: User;
  token: string;
}

// Tweet types
export interface Tweet {
  id: number;
  user_id: number;
  content: string;
  image_url?: string;
  likes_count: number;
  retweets_count: number;
  replies_count: number;
  reply_to_id?: number;
  created_at: Date;
  updated_at: Date;
  user?: User;
  liked_by_current_user?: boolean;
  retweeted_by_current_user?: boolean;
}

export interface CreateTweetRequest {
  content: string;
  image_url?: string;
  reply_to_id?: number;
}

export interface TweetFeed {
  tweets: Tweet[];
  hasMore: boolean;
  nextCursor?: string;
}

// Follow types
export interface Follow {
  id: number;
  follower_id: number;
  following_id: number;
  created_at: Date;
}

// Like types
export interface Like {
  id: number;
  user_id: number;
  tweet_id: number;
  created_at: Date;
}

// Notification types
export type NotificationType = 'like' | 'retweet' | 'follow' | 'reply' | 'mention';

export interface Notification {
  id: number;
  user_id: number;
  type: NotificationType;
  from_user_id?: number;
  tweet_id?: number;
  message?: string;
  read: boolean;
  created_at: Date;
  from_user?: User;
  tweet?: Tweet;
}

// Hashtag types
export interface Hashtag {
  id: number;
  tag: string;
  usage_count: number;
  created_at: Date;
}

// API Response types
export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
  pagination?: {
    page: number;
    limit: number;
    total: number;
    hasMore: boolean;
  };
  details?: any[];
}

export interface PaginationQuery {
  page?: number;
  limit?: number;
  cursor?: string;
}

// Socket.IO event types
export interface SocketEvents {
  'tweet:new': Tweet;
  'tweet:like': { tweet_id: number; user_id: number; likes_count: number };
  'tweet:unlike': { tweet_id: number; user_id: number; likes_count: number };
  'notification:new': Notification;
  'user:follow': { follower_id: number; following_id: number };
  'user:unfollow': { follower_id: number; following_id: number };
}

// Kafka message types
export interface KafkaMessage {
  topic: string;
  key?: string;
  value: any;
  timestamp?: Date;
}

export interface TweetKafkaMessage {
  type: 'tweet:created' | 'tweet:liked' | 'tweet:retweeted';
  tweet: Tweet;
  user: User;
  timestamp: Date;
}

export interface NotificationKafkaMessage {
  type: 'notification:created';
  notification: Notification;
  target_user_id: number;
  timestamp: Date;
}

// Database query result types
export interface QueryResult<T = any> {
  rows: T[];
  rowCount: number;
}

// Express request extensions
export interface AuthenticatedRequest extends Request {
  user?: User;
  userId?: number;
} 