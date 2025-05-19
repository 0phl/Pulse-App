/**
 * Test Admin Notification Script
 * 
 * This script sends a test admin notification to a specified user.
 * Usage: node scripts/test-admin-notification.js USER_ID
 */

require('dotenv').config();
const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin SDK
let app;
try {
  const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || './service-account-key.json';
  const serviceAccount = require(path.resolve(serviceAccountPath));
  
  app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: process.env.FIREBASE_DATABASE_URL || 'https://pulse-app-ea5be-default-rtdb.asia-southeast1.firebasedatabase.app'
  }, 'admin-notification-test-app');
  
  console.log('✅ Firebase initialized successfully');
} catch (error) {
  console.error('❌ Failed to initialize Firebase:', error);
  process.exit(1);
}

const db = admin.firestore(app);
const messaging = admin.messaging(app);

// Send admin test notification
async function sendAdminTestNotification(userId) {
  try {
    console.log(`\n🔔 Sending admin test notification to user: ${userId}`);
    
    // Check if user exists
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      console.error(`❌ User ${userId} does not exist in Firestore`);
      return;
    }
    
    const userData = userDoc.data();
    console.log(`✅ Found user: ${userData.displayName || userData.email || 'No name'}`);
    
    // Get user tokens
    const userTokensDoc = await db.collection('user_tokens').doc(userId).get();
    if (!userTokensDoc.exists) {
      console.error(`❌ No tokens found for user ${userId}`);
      return;
    }
    
    const userTokenData = userTokensDoc.data();
    const tokens = userTokenData.tokens || [];
    
    if (tokens.length === 0) {
      console.error(`❌ No tokens found in user_tokens document for ${userId}`);
      return;
    }
    
    console.log(`✅ Found ${tokens.length} device tokens`);
    
    // Create notification in Firestore
    const notificationRef = await db.collection('user_notifications').add({
      title: 'Admin Test Notification',
      body: 'This is a test admin notification sent from the server',
      type: 'admin_test',
      data: {
        isForAdmin: 'true',
        test: 'true',
        timestamp: Date.now().toString(),
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: 'system',
    });
    
    // Create status record
    await db.collection('notification_status').add({
      userId,
      notificationId: notificationRef.id,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`✅ Created notification record in Firestore with ID: ${notificationRef.id}`);
    
    // Loop through all tokens and send notification
    for (const tokenData of tokens) {
      try {
        // Extract token
        const token = typeof tokenData === 'string' ? tokenData : 
                     (tokenData && tokenData.token ? tokenData.token : null);
        
        if (!token) {
          console.error(`❌ Invalid token format:`, tokenData);
          continue;
        }
        
        console.log(`Sending to token: ${token.substring(0, 15)}...`);
        
        // Create message with correct FCM format
        const message = {
          notification: {
            title: 'Admin Test Notification',
            body: 'This is a test admin notification sent from the server',
          },
          data: {
            type: 'admin_test',
            isForAdmin: 'true',
            priority: 'high',
            forceAlert: 'true',
            notificationId: notificationRef.id,
            timestamp: Date.now().toString(),
            click_action: 'FLUTTER_NOTIFICATION_CLICK'
          },
          token: token,
          android: {
            priority: 'high',
            ttl: 60 * 1000,
            notification: {
              channelId: 'admin_high_importance_channel',
              defaultSound: true,
              defaultVibrateTimings: true,
              visibility: 'public',
              sound: 'default',
              tag: `admin_test_${Date.now()}`,
            },
            directBootOk: true,
          },
          apns: {
            headers: {
              'apns-priority': '10',
              'apns-push-type': 'alert',
            },
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
                'content-available': 1,
                'mutable-content': 1,
                'interruption-level': 'time-sensitive',
                category: 'ADMIN_NOTIFICATION',
              },
            },
          },
        };
        
        const response = await messaging.send(message);
        console.log(`✅ Notification sent successfully! FCM Response: ${response}`);
      } catch (error) {
        console.error(`❌ Error sending notification to token:`, error);
      }
    }
    
    console.log(`\n🎉 Admin notification test completed`);
  } catch (error) {
    console.error(`❌ Error sending admin test notification:`, error);
  }
}

// Get user ID from command line arguments
const userId = process.argv[2];
if (!userId) {
  console.error('❌ Please provide a user ID as command line argument');
  console.log('Usage: node scripts/test-admin-notification.js USER_ID');
  process.exit(1);
}

// Execute
sendAdminTestNotification(userId)
  .then(() => {
    console.log('Test completed, cleaning up...');
    app.delete().then(() => process.exit(0));
  })
  .catch(error => {
    console.error('Unhandled error:', error);
    app.delete().then(() => process.exit(1));
  }); 