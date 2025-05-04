# Push Notification Implementation Plan for PULSE App

## Overview

This document outlines the implementation plan for adding push notifications to the PULSE app using a custom backend server with Firebase Cloud Messaging (FCM), while remaining on the Firebase Spark (Free) Plan.

## Architecture

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│                 │      │                 │      │                 │
│   Flutter App   │◄────►│  Custom Node.js │◄────►│  Firebase FCM   │
│   (Client)      │      │  Backend Server │      │                 │
│                 │      │  (on Render)    │      │                 │
│                 │      │                 │      │                 │
└─────────────────┘      └─────────────────┘      └─────────────────┘
        ▲                        ▲                        ▲
        │                        │                        │
        │                        │                        │
        ▼                        ▼                        ▼
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│                 │      │                 │      │                 │
│    Firebase     │◄────►│    Firebase     │◄────►│    Firebase     │
│  Authentication │      │    Firestore    │      │  Realtime DB    │
│                 │      │                 │      │                 │
│                 │      │                 │      │                 │
└─────────────────┘      └─────────────────┘      └─────────────────┘
```

## Components

1. **Flutter App (Client)**
   - Registers FCM tokens
   - Handles incoming notifications
   - Displays notifications to users

2. **Custom Backend Server**
   - Stores user FCM tokens
   - Monitors database for events
   - Sends notifications via FCM

3. **Firebase Services**
   - Authentication
   - Firestore/Realtime Database
   - FCM for message delivery

## Implementation Plan

### Phase 1: Flutter App Setup (2-3 days)

1. **FCM Integration**
   - Add firebase_messaging package to pubspec.yaml
   - Configure Android and iOS for FCM
   - Request notification permissions

2. **Token Management**
   - Implement token retrieval on app start
   - Handle token refreshes
   - Send tokens to backend server

3. **Notification Handling**
   - Implement foreground notification handling
   - Implement background notification handling
   - Add notification tap handling for navigation

### Phase 2: Backend Server Setup (3-4 days)

1. **Server Infrastructure**
   - Set up Node.js project
   - Install required dependencies
   - Configure Firebase Admin SDK

2. **API Endpoints**
   - Create endpoint for token registration
   - Create endpoint for manual notification sending
   - Implement security middleware

3. **Database Monitoring**
   - Set up listeners for database events
   - Implement notification triggers
   - Add error handling and logging

### Phase 3: Notification Types Implementation (2-3 days)

1. **Community Notice Notifications**
   - Monitor for new community notices
   - Send notifications to community members
   - Include relevant data for deep linking

2. **Comment and Like Notifications**
   - Monitor for new comments on posts
   - Monitor for new likes on posts
   - Send notifications to post authors

3. **Chat Message Notifications**
   - Monitor for new chat messages
   - Send notifications to message recipients
   - Include chat data for navigation

4. **Marketplace Notifications**
   - Monitor for new marketplace items
   - Send notifications to community members
   - Include item data for deep linking

### Phase 4: Testing and Optimization (2-3 days)

1. **Testing**
   - Test token registration
   - Test notification delivery
   - Test notification handling in different app states
   - Test deep linking from notifications

2. **Optimization**
   - Optimize database listeners
   - Implement batching for multiple notifications
   - Add error handling and retry logic

3. **Monitoring**
   - Add logging for debugging
   - Implement basic analytics
   - Set up error reporting

## Technical Details

### Flutter App Implementation

```dart
// Initialize Firebase Messaging
Future<void> initializeFirebaseMessaging() async {
  await Firebase.initializeApp();

  // Request permission
  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Get FCM token
  String? token = await FirebaseMessaging.instance.getToken();
  if (token != null) {
    await sendTokenToBackend(token);
  }

  // Listen for token refreshes
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    sendTokenToBackend(newToken);
  });

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    showLocalNotification(message);
  });

  // Handle notification taps
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    handleNotificationTap(message);
  });
}

// Send token to backend
Future<void> sendTokenToBackend(String token) async {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return;

  try {
    final response = await http.post(
      Uri.parse('https://your-backend.com/api/register-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'token': token,
        'platform': Platform.isAndroid ? 'android' : 'ios',
      }),
    );

    if (response.statusCode == 200) {
      print('Token registered successfully');
    } else {
      print('Failed to register token: ${response.body}');
    }
  } catch (e) {
    print('Error sending token to backend: $e');
  }
}
```

### Backend Server Implementation

```javascript
// server.js
const express = require('express');
const admin = require('firebase-admin');
const cors = require('cors');
const bodyParser = require('body-parser');

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(require('./service-account-key.json'))
});

const app = express();
app.use(cors());
app.use(bodyParser.json());

// Database references
const db = admin.firestore();
const rtdb = admin.database();

// Store user tokens
app.post('/api/register-token', async (req, res) => {
  try {
    const { userId, token, platform } = req.body;

    // Store token in your database
    await db.collection('user_tokens').doc(userId).set({
      tokens: admin.firestore.FieldValue.arrayUnion({
        token,
        platform,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      })
    }, { merge: true });

    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error registering token:', error);
    res.status(500).json({ error: error.message });
  }
});

// Monitor for new community notices
const monitorCommunityNotices = () => {
  const db = getDatabase();
  const noticesRef = db.ref('/community_notices');

  console.log('Starting monitoring for new community notices...');

  // Listen for new notices
  noticesRef.on('child_added', async (snapshot) => {
    try {
      const noticeData = snapshot.val();
      const noticeId = snapshot.key;

      if (!noticeData || !noticeData.communityId) {
        console.log('Invalid notice data');
        return;
      }

      console.log(`New community notice detected: ${noticeId}`);

      // Send notification to all users in the community except the author
      await sendNotificationToCommunity(
        noticeData.communityId,
        noticeData.title || 'New Community Notice',
        noticeData.content?.substring(0, 100) || 'A new notice has been posted in your community.',
        {
          type: 'communityNotices',
          noticeId,
          communityId: noticeData.communityId,
          authorId: noticeData.authorId,
        },
        noticeData.authorId // Exclude the author
      );
    } catch (error) {
      console.error('Error processing new community notice:', error);
    }
  });
};

// Send a notification to all users in a community
const sendNotificationToCommunity = async (communityId, title, body, data = {}, excludeUserId = null) => {
  try {
    const db = getFirestore();

    // Get all users in the community
    const usersSnapshot = await db.collection('users')
      .where('communityId', '==', communityId)
      .get();

    if (usersSnapshot.empty) {
      console.log(`No users found in community ${communityId}`);
      return { success: false, error: 'No users found in community' };
    }

    // Send notification to each user
    const promises = usersSnapshot.docs
      .filter(doc => !excludeUserId || doc.id !== excludeUserId) // Exclude specific user if provided
      .map(doc => {
        const userId = doc.id;
        return sendNotificationToUser(userId, title, body, data);
      });

    const results = await Promise.all(promises);

    console.log(`Notification sent to ${results.length} users in community ${communityId}`);

    return {
      success: true,
      sentCount: results.length,
      results
    };
  } catch (error) {
    console.error('Error sending community notification:', error);
    return { success: false, error: error.message };
  }
};

// Start all monitoring functions
function startAllMonitoring() {
  monitorCommunityNotices();
  // Add other monitoring functions here
}

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  startAllMonitoring();
});
```

## Notification Types

| Type | Trigger | Recipients | Content |
|------|---------|------------|---------|
| Community Notice | New notice created | All community members except author | Title and preview of notice |
| Comment | New comment on notice | Notice author | Commenter name and comment preview |
| Like | New like on notice/comment | Notice/comment author | Liker name and content liked |
| Chat Message | New message received | Message recipient | Sender name and message preview |
| Marketplace Item | New item listed | All community members except seller | Item title, price, and seller name |
| Report Status | Report status changed | Report creator | New status and any admin message |

## Deployment Options

1. **Render**
   - Free tier available
   - Easy GitHub integration
   - Automatic deployments
   - Recommended option for this implementation

2. **Railway**
   - Free tier available
   - Simple deployment process
   - Good performance

3. **Heroku**
   - Free tier available (with limitations)
   - Well-established platform
   - Good documentation

4. **Digital Ocean App Platform**
   - Starting at $5/month
   - Reliable performance
   - Good scaling options

## Testing Plan

1. **Unit Testing**
   - Test token registration logic
   - Test notification sending functions
   - Test database monitoring functions

2. **Integration Testing**
   - Test end-to-end notification flow
   - Test different notification types
   - Test notification handling in different app states

3. **User Testing**
   - Test with real devices
   - Test with different Android/iOS versions
   - Test with different network conditions

## Timeline

- **Week 1**: Flutter app implementation and backend setup
- **Week 2**: Notification types implementation and initial testing
- **Week 3**: Optimization, comprehensive testing, and deployment

## Maintenance Considerations

1. **Server Uptime**
   - Choose a reliable hosting provider
   - Implement health checks
   - Set up monitoring alerts

2. **Token Management**
   - Implement token cleanup for inactive users
   - Handle token refreshes properly
   - Batch token updates

3. **Error Handling**
   - Implement comprehensive error logging
   - Add retry logic for failed notifications
   - Set up error alerts

## Cost Considerations

1. **Hosting Costs**
   - Most providers offer free tiers for low-traffic applications
   - Estimated cost: $0-$7/month depending on provider and traffic

2. **Firebase Costs**
   - FCM is free for unlimited notifications
   - Firestore/RTDB usage within Spark Plan limits
   - Estimated cost: $0 (within free tier)

3. **Scaling Costs**
   - Consider costs if user base grows significantly
   - Monitor usage to stay within free tiers
   - Implement cost optimization strategies

## Conclusion

This implementation plan provides a comprehensive approach to adding push notifications to the PULSE app while remaining on the Firebase Spark Plan. By using a custom Node.js backend server deployed on Render to monitor database changes and send notifications via FCM, we can achieve the desired functionality without requiring Firebase Cloud Functions.

The solution is cost-effective, scalable, and provides a good user experience with real-time notifications for various app activities. The implementation uses database listeners instead of polling, which provides more immediate notifications and reduces server load.

The code for this implementation has been created in the `notification-server` directory, which can be deployed to Render or another hosting provider of your choice.
