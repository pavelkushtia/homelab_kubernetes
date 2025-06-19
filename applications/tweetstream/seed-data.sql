-- TweetStream Synthetic Data Seeding
-- Representative data for testing and demonstration

-- Insert sample users
INSERT INTO users (username, email, password_hash, display_name, bio, verified, followers_count, following_count, tweets_count) VALUES
('john_doe', 'john@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj/VcSAg9S6O', 'John Doe', 'Software Engineer passionate about cloud technologies', false, 150, 89, 45),
('jane_smith', 'jane@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj/VcSAg9S6O', 'Jane Smith', 'DevOps Engineer | Kubernetes enthusiast | Coffee lover ☕', true, 320, 156, 78),
('tech_guru', 'guru@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj/VcSAg9S6O', 'Tech Guru', 'Sharing insights about modern software architecture', true, 1250, 234, 156),
('startup_founder', 'founder@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj/VcSAg9S6O', 'Alex Chen', 'Building the future of social platforms 🚀', false, 89, 67, 23),
('data_scientist', 'data@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj/VcSAg9S6O', 'Dr. Sarah Wilson', 'ML Engineer | Data Science | AI Research', true, 567, 123, 89);

-- Insert sample tweets
INSERT INTO tweets (user_id, content, likes_count, retweets_count, replies_count) VALUES
(1, 'Just deployed TweetStream on Kubernetes! The platform services integration is amazing 🚀 #kubernetes #microservices', 12, 3, 2),
(2, 'Loving the new monitoring setup with Prometheus and Grafana. Real-time metrics are game-changing! 📊', 18, 5, 4),
(3, 'Modern architecture tip: Use platform services to reduce configuration overhead by 85%+. Less YAML, more value! 💡', 45, 12, 8),
(1, 'The Redis integration for session management is so smooth. Sub-millisecond response times! ⚡', 8, 2, 1),
(4, 'Building TweetStream taught me so much about real-time systems. Kafka + Socket.IO = perfect combo 🔥', 23, 6, 3),
(2, 'Hot take: Container orchestration is not just about scaling, it''s about operational simplicity 🎯', 34, 9, 7),
(5, 'Analyzing user engagement patterns in real-time social platforms. The data insights are fascinating! 📈', 19, 4, 5),
(3, 'PostgreSQL performance optimization: proper indexing can improve query speed by 100x. Always profile first! 🔍', 67, 15, 12),
(1, 'Working on the frontend with React 18 and Tailwind CSS. The developer experience is incredible! ⚛️', 15, 3, 2),
(4, 'Startup lesson: Focus on platform services integration early. It saves months of infrastructure work 💪', 28, 7, 4);

-- Insert sample follows
INSERT INTO follows (follower_id, following_id) VALUES
(1, 2), (1, 3), (1, 4),
(2, 1), (2, 3), (2, 5),
(3, 1), (3, 2), (3, 4), (3, 5),
(4, 1), (4, 2), (4, 3),
(5, 2), (5, 3), (5, 4);

-- Insert sample likes
INSERT INTO likes (user_id, tweet_id) VALUES
(2, 1), (3, 1), (4, 1), (5, 1),
(1, 2), (3, 2), (4, 2), (5, 2),
(1, 3), (2, 3), (4, 3), (5, 3),
(2, 4), (3, 4),
(1, 5), (2, 5), (3, 5),
(1, 6), (3, 6), (4, 6), (5, 6),
(1, 7), (2, 7), (3, 7), (4, 7),
(1, 8), (2, 8), (4, 8), (5, 8),
(2, 9), (3, 9), (4, 9),
(1, 10), (2, 10), (3, 10), (5, 10);

-- Insert sample retweets
INSERT INTO retweets (user_id, tweet_id) VALUES
(2, 1), (3, 1), (4, 1),
(1, 2), (3, 2), (4, 2), (5, 2),
(1, 3), (2, 3), (4, 3), (5, 3),
(2, 4), (3, 4),
(1, 5), (2, 5), (3, 5),
(1, 6), (3, 6), (4, 6),
(1, 7), (2, 7), (3, 7), (4, 7),
(1, 8), (2, 8), (4, 8),
(2, 9), (3, 9),
(1, 10), (2, 10), (3, 10);

-- Insert sample notifications
INSERT INTO notifications (user_id, type, from_user_id, tweet_id, message, read) VALUES
(1, 'like', 2, 1, 'Jane Smith liked your tweet', false),
(1, 'retweet', 3, 1, 'Tech Guru retweeted your tweet', false),
(1, 'follow', 4, NULL, 'Alex Chen started following you', true),
(2, 'like', 1, 2, 'John Doe liked your tweet', true),
(2, 'follow', 5, NULL, 'Dr. Sarah Wilson started following you', false),
(3, 'like', 1, 3, 'John Doe liked your tweet', true),
(3, 'retweet', 2, 3, 'Jane Smith retweeted your tweet', false),
(4, 'like', 1, 5, 'John Doe liked your tweet', true),
(4, 'follow', 3, NULL, 'Tech Guru started following you', false),
(5, 'like', 2, 7, 'Jane Smith liked your tweet', true);

-- Insert sample hashtags
INSERT INTO hashtags (tag, usage_count) VALUES
('kubernetes', 5),
('microservices', 3),
('devops', 4),
('react', 2),
('nodejs', 3),
('postgresql', 2),
('redis', 1),
('kafka', 2),
('monitoring', 3),
('startup', 2);

-- Insert sample tweet hashtags
INSERT INTO tweet_hashtags (tweet_id, hashtag_id) VALUES
(1, 1), (1, 2),  -- kubernetes, microservices
(3, 1),          -- kubernetes
(4, 7),          -- redis
(5, 8),          -- kafka
(9, 4),          -- react
(10, 10);        -- startup

-- Update user tweet counts based on actual tweets
UPDATE users SET tweets_count = (
    SELECT COUNT(*) FROM tweets WHERE tweets.user_id = users.id
);

-- Update user follower counts
UPDATE users SET followers_count = (
    SELECT COUNT(*) FROM follows WHERE follows.following_id = users.id
);

-- Update user following counts
UPDATE users SET following_count = (
    SELECT COUNT(*) FROM follows WHERE follows.follower_id = users.id
);

-- Update tweet like counts
UPDATE tweets SET likes_count = (
    SELECT COUNT(*) FROM likes WHERE likes.tweet_id = tweets.id
);

-- Update tweet retweet counts
UPDATE tweets SET retweets_count = (
    SELECT COUNT(*) FROM retweets WHERE retweets.tweet_id = tweets.id
);

-- Insert some reply tweets
INSERT INTO tweets (user_id, content, reply_to_id, likes_count, retweets_count, replies_count) VALUES
(2, 'Totally agree! The operational benefits are huge when you get the architecture right 👍', 6, 5, 1, 0),
(4, 'Which monitoring tools do you recommend for Kubernetes workloads?', 2, 3, 0, 1),
(5, 'Great point about indexing! I''ve seen similar performance gains in my ML pipelines 🚀', 8, 8, 2, 0);

-- Update reply counts for parent tweets
UPDATE tweets SET replies_count = (
    SELECT COUNT(*) FROM tweets AS replies WHERE replies.reply_to_id = tweets.id
);

-- Add some sessions for active users (simulating logged-in state)
INSERT INTO sessions (user_id, token_hash, expires_at) VALUES
(1, 'hash_john_session_token', NOW() + INTERVAL '7 days'),
(2, 'hash_jane_session_token', NOW() + INTERVAL '7 days'),
(3, 'hash_guru_session_token', NOW() + INTERVAL '7 days');

COMMIT; 