# 🧪 End-to-End Cross-User Testing Guide

## Overview
This guide walks through complete end-to-end testing of TweetStream's cross-user functionality with two users following each other.

## 🎯 Test Scenario: Two Users Following Each Other

**Test Users:**
- **User A**: `alice_dev` (will follow Bob)
- **User B**: `bob_tester` (will follow Alice back)

**Test Flow:**
1. User registration for both users
2. User authentication/login
3. User A follows User B
4. User B follows User A back
5. User A posts a tweet
6. User B sees User A's tweet in their feed
7. User B likes/retweets User A's tweet
8. User A receives notification of the interaction

## 🚀 Current System Status

### Frontend Access
- **URL**: http://sanzad-ubuntu-21:30951
- **Status**: ✅ Running
- **Features**: Registration, Login, Timeline, Post tweets

### Backend Options
- **Production TypeScript**: http://sanzad-ubuntu-21:30955 ⏳ (Building)
- **Legacy Backend**: http://sanzad-ubuntu-21:30950 ❌ (Pod deleted, service exists)

## 📋 Step-by-Step Testing Instructions

### Phase 1: User Registration & Setup

#### Step 1.1: Register User A (Alice)
```bash
# Method 1: Browser (Recommended)
# Open: http://sanzad-ubuntu-21:30951
# Click "Register"
# Username: alice_dev
# Email: alice@test.com
# Password: testpass123

# Method 2: API Call
curl -X POST http://sanzad-ubuntu-21:30955/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "alice_dev",
    "email": "alice@test.com", 
    "password": "testpass123",
    "display_name": "Alice Developer"
  }'
```

#### Step 1.2: Register User B (Bob)
```bash
# Browser method:
# Open new incognito window: http://sanzad-ubuntu-21:30951
# Click "Register"
# Username: bob_tester
# Email: bob@test.com
# Password: testpass123

# API method:
curl -X POST http://sanzad-ubuntu-21:30955/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "bob_tester",
    "email": "bob@test.com",
    "password": "testpass123", 
    "display_name": "Bob Tester"
  }'
```

### Phase 2: Authentication Testing

#### Step 2.1: Login User A
```bash
# Get Alice's JWT token
ALICE_TOKEN=$(curl -X POST http://sanzad-ubuntu-21:30955/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "alice@test.com", "password": "testpass123"}' \
  | jq -r '.data.token')

echo "Alice Token: $ALICE_TOKEN"
```

#### Step 2.2: Login User B  
```bash
# Get Bob's JWT token
BOB_TOKEN=$(curl -X POST http://sanzad-ubuntu-21:30955/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "bob@test.com", "password": "testpass123"}' \
  | jq -r '.data.token')

echo "Bob Token: $BOB_TOKEN"
```

### Phase 3: Follow Relationships

#### Step 3.1: Alice Follows Bob
```bash
# Alice searches for Bob
curl -X GET "http://sanzad-ubuntu-21:30955/api/users/search?q=bob_tester" \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Get Bob's user ID from search results, then follow
BOB_ID=$(curl -s -X GET "http://sanzad-ubuntu-21:30955/api/users/search?q=bob_tester" \
  -H "Authorization: Bearer $ALICE_TOKEN" | jq -r '.data[0].id')

# Alice follows Bob
curl -X POST http://sanzad-ubuntu-21:30955/api/users/$BOB_ID/follow \
  -H "Authorization: Bearer $ALICE_TOKEN"
```

#### Step 3.2: Bob Follows Alice Back
```bash
# Bob searches for Alice
ALICE_ID=$(curl -s -X GET "http://sanzad-ubuntu-21:30955/api/users/search?q=alice_dev" \
  -H "Authorization: Bearer $BOB_TOKEN" | jq -r '.data[0].id')

# Bob follows Alice
curl -X POST http://sanzad-ubuntu-21:30955/api/users/$ALICE_ID/follow \
  -H "Authorization: Bearer $BOB_TOKEN"
```

### Phase 4: Cross-User Tweet Testing

#### Step 4.1: Alice Posts a Tweet
```bash
# Alice creates a tweet
curl -X POST http://sanzad-ubuntu-21:30955/api/tweets \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Hello from Alice! 👋 Testing cross-user functionality with Bob. Can you see this @bob_tester?"
  }'
```

#### Step 4.2: Verify Tweet Appears in Bob's Feed
```bash
# Bob checks his personalized feed (should see Alice's tweet)
curl -X GET http://sanzad-ubuntu-21:30955/api/tweets/feed \
  -H "Authorization: Bearer $BOB_TOKEN"

# Bob checks public timeline (should also see Alice's tweet)  
curl -X GET http://sanzad-ubuntu-21:30955/api/tweets/public
```

#### Step 4.3: Bob Interacts with Alice's Tweet
```bash
# Get Alice's tweet ID
TWEET_ID=$(curl -s -X GET http://sanzad-ubuntu-21:30955/api/tweets/feed \
  -H "Authorization: Bearer $BOB_TOKEN" | jq -r '.data[0].id')

# Bob likes Alice's tweet
curl -X POST http://sanzad-ubuntu-21:30955/api/tweets/$TWEET_ID/like \
  -H "Authorization: Bearer $BOB_TOKEN"

# Bob retweets Alice's tweet  
curl -X POST http://sanzad-ubuntu-21:30955/api/tweets/$TWEET_ID/retweet \
  -H "Authorization: Bearer $BOB_TOKEN"
```

### Phase 5: Real-Time Notifications

#### Step 5.1: Alice Checks Notifications
```bash
# Alice should see notifications about Bob's interactions
curl -X GET http://sanzad-ubuntu-21:30955/api/notifications \
  -H "Authorization: Bearer $ALICE_TOKEN"
```

#### Step 5.2: Bob Posts Reply
```bash
# Bob replies to Alice's tweet
curl -X POST http://sanzad-ubuntu-21:30955/api/tweets \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Hey @alice_dev! Yes, I can see your tweet! Cross-user functionality is working! 🎉",
    "reply_to_id": '$TWEET_ID'
  }'
```

## 🌐 Browser Testing Checklist

### User A Browser Window:
1. ✅ Register as alice_dev
2. ✅ Login successfully  
3. ✅ Search for bob_tester
4. ✅ Follow bob_tester
5. ✅ Post a tweet mentioning Bob
6. ✅ See notifications when Bob interacts
7. ✅ See Bob's reply in timeline

### User B Browser Window (Incognito):
1. ✅ Register as bob_tester
2. ✅ Login successfully
3. ✅ Search for alice_dev
4. ✅ Follow alice_dev back
5. ✅ See Alice's tweet in feed
6. ✅ Like Alice's tweet
7. ✅ Retweet Alice's tweet
8. ✅ Reply to Alice's tweet

## 🔍 Verification Points

### Database Verification:
```bash
# Check users table
kubectl exec -n platform-services postgresql-0 -- \
  psql -U postgres -d tweetstream \
  -c "SELECT username, display_name, followers_count, following_count FROM users;"

# Check follows table  
kubectl exec -n platform-services postgresql-0 -- \
  psql -U postgres -d tweetstream \
  -c "SELECT f.id, u1.username as follower, u2.username as following FROM follows f JOIN users u1 ON f.follower_id = u1.id JOIN users u2 ON f.following_id = u2.id;"

# Check tweets
kubectl exec -n platform-services postgresql-0 -- \
  psql -U postgres -d tweetstream \
  -c "SELECT t.id, u.username, t.content, t.likes_count, t.retweets_count FROM tweets t JOIN users u ON t.user_id = u.id ORDER BY t.created_at DESC;"

# Check interactions
kubectl exec -n platform-services postgresql-0 -- \
  psql -U postgres -d tweetstream \
  -c "SELECT 'like' as type, u.username, t.content FROM likes l JOIN users u ON l.user_id = u.id JOIN tweets t ON l.tweet_id = t.id UNION SELECT 'retweet' as type, u.username, t.content FROM retweets r JOIN users u ON r.user_id = u.id JOIN tweets t ON r.tweet_id = t.id;"
```

## ✅ Success Criteria

**✅ Cross-User Registration**: Both users can register independently  
**✅ Cross-User Discovery**: Users can search and find each other  
**✅ Follow Relationships**: Users can follow each other bidirectionally  
**✅ Cross-User Timeline**: Followed users' tweets appear in personal feed  
**✅ Cross-User Interactions**: Likes, retweets, replies work across users  
**✅ Real-Time Notifications**: Users receive notifications of interactions  
**✅ Database Persistence**: All interactions are stored in PostgreSQL  
**✅ Real-Time Updates**: Changes appear immediately via Kafka/Socket.IO  

## 🚨 Troubleshooting

**Issue**: TypeScript backend not ready  
**Solution**: Use the building backend or wait for deployment

**Issue**: Authentication tokens not working  
**Solution**: Check JWT secret configuration and token format

**Issue**: Cross-user tweets not appearing  
**Solution**: Verify follow relationships and feed query logic

**Issue**: Notifications not working  
**Solution**: Check Kafka service and notification table

## 📊 Expected Results

After successful testing, you should see:
- **2 users** in the database with follow relationships
- **Cross-user tweets** in both feeds  
- **Interaction counts** (likes, retweets) updated
- **Real-time notifications** delivered
- **Reply threads** working between users
- **Timeline consistency** across all users

---
**Status**: Ready for Testing  
**Backend**: TypeScript (port 30955) - Building  
**Frontend**: React (port 30951) - Ready  
**Database**: PostgreSQL with full schema  