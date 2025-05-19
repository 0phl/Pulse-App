/**
 * Notification Delivery Diagnostic Tool
 * 
 * This script helps diagnose issues with push notification delivery.
 * It checks:
 * 1. Firebase configuration
 * 2. User token registration
 * 3. Notification delivery
 * 4. Notification payload structure
 */

const admin = require('firebase-admin');
const axios = require('axios');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
let app;
try {
  const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || './service-account-key.json';
  const serviceAccount = require(path.resolve(serviceAccountPath));
  
  app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: process.env.FIREBASE_DATABASE_URL || 'https://pulse-app-ea5be-default-rtdb.asia-southeast1.firebasedatabase.app'
  }, 'diagnostic-app');
  
  console.log('✅ Firebase initialized successfully for diagnostics');
} catch (error) {
  console.error('❌ Failed to initialize Firebase:', error);
  process.exit(1);
}

const db = admin.firestore(app);
const messaging = admin.messaging(app);

/**
 * Diagnose notification issues for a specific user
 * @param {string} userId The user ID to diagnose
 */
async function diagnoseUserNotifications(userId) {
  console.log(`\n🔍 Diagnosing notification issues for user: ${userId}`);
  
  // Check if user exists
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) {
    console.error(`❌ User ${userId} does not exist in Firestore`);
    return;
  }
  
  const userData = userDoc.data();
  console.log(`📝 User details:`);
  console.log(`  Display Name: ${userData.displayName || 'Not set'}`);
  console.log(`  Email: ${userData.email || 'Not set'}`);
  console.log(`  Role: ${userData.role || 'regular user'}`);
  
  // Check if user is admin
  const isAdmin = userData.role === 'admin' || userData.isAdmin === true;
  console.log(`  Admin Status: ${isAdmin ? '✅ User is an admin' : '❌ User is not an admin'}`);
  
  // Get user tokens
  const userTokensDoc = await db.collection('user_tokens').doc(userId).get();
  if (!userTokensDoc.exists) {
    console.error(`❌ No tokens found for user ${userId}`);
    console.log(`   This user won't receive any push notifications until they log in again`);
    return;
  }
  
  const userTokenData = userTokensDoc.data();
  const tokens = userTokenData.tokens || [];
  
  console.log(`📱 Found ${tokens.length} device tokens for this user`);
  
  for (const [index, tokenData] of tokens.entries()) {
    console.log(`\nToken #${index + 1}:`);
    console.log(`  Platform: ${tokenData.platform || 'unknown'}`);
    console.log(`  Token: ${tokenData.token ? tokenData.token.substring(0, 15) + '...' : 'invalid'}`);
    console.log(`  Created: ${tokenData.createdAt ? tokenData.createdAt.toDate().toLocaleString() : 'unknown'}`);
    console.log(`  Last Active: ${tokenData.lastActive ? tokenData.lastActive.toDate().toLocaleString() : 'unknown'}`);
    
    // Test token validity by sending a silent notification
    try {
      console.log(`  Testing token validity...`);
      await messaging.send({
        token: tokenData.token,
        data: {
          type: 'diagnostic',
          timestamp: Date.now().toString()
        },
        android: {
          priority: 'high',
          ttl: 60 * 1000,
          directBootOk: true
        }
      }, true); // dryRun = true, won't actually send notification
      
      console.log(`  ✅ Token appears valid`);
    } catch (error) {
      console.error(`  ❌ Token validation failed:`, error.message);
    }
  }
  
  // Check notification preferences
  console.log(`\n⚙️ Notification Preferences:`);
  const preferences = userTokenData.notificationPreferences || {};
  if (Object.keys(preferences).length === 0) {
    console.log(`  No preferences set, will use defaults (all notifications enabled)`);
  } else {
    for (const [type, enabled] of Object.entries(preferences)) {
      console.log(`  ${type}: ${enabled ? '✅ Enabled' : '❌ Disabled'}`);
    }
  }
  
  // Check recent notifications
  console.log(`\n📬 Recent Notifications:`);
  const notificationQuery = await db.collection('notification_status')
    .where('userId', '==', userId)
    .orderBy('createdAt', 'desc')
    .limit(5)
    .get();
  
  if (notificationQuery.empty) {
    console.log(`  No recent notifications found for this user`);
  } else {
    for (const doc of notificationQuery.docs) {
      const data = doc.data();
      const notificationType = await getNotificationType(data.notificationId);
      console.log(`  - ${data.createdAt.toDate().toLocaleString()}: ${notificationType} (${data.read ? 'Read' : 'Unread'})`);
    }
  }
  
  // Test admin notification for admin users
  if (isAdmin) {
    console.log(`\n👑 Testing Admin Notification Delivery:`);
    testAdminNotification(userId, tokens[0].token);
  }
  
  console.log(`\n🔍 Diagnosis Complete for user ${userId}`);
}

// Helper function to get notification type
async function getNotificationType(notificationId) {
  try {
    const notificationDoc = await db.collection('user_notifications').doc(notificationId).get();
    if (notificationDoc.exists) {
      return notificationDoc.data().type || 'general';
    }
  } catch (error) {
    console.error(`Error getting notification type:`, error.message);
  }
  return 'unknown';
}

// Test admin notification specifically to debug admin notification issues
async function testAdminNotification(userId, tokenData) {
  console.log(`  Creating test admin notification payload...`);
  
  try {
    // Extract token safely
    const token = typeof tokenData === 'string' ? tokenData : 
                 (tokenData && tokenData.token ? tokenData.token : null);
    
    if (!token) {
      console.error(`  ❌ Invalid token format:`, JSON.stringify(tokenData));
      return;
    }
    
    // Create a properly formatted admin notification
    const message = {
      notification: {
        title: 'Test Admin Notification',
        body: 'This is a diagnostic test for admin notifications',
      },
      data: {
        type: 'diagnostic',
        isForAdmin: 'true',
        priority: 'high',
        forceAlert: 'true',
        timestamp: String(Date.now()),
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
          tag: `diagnostic_${Date.now()}`,
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
    
    console.log(`  Full admin notification message payload:`, JSON.stringify(message, null, 2));
    
    // Send the notification as dry-run first to check for payload errors
    await messaging.send(message, true); // dryRun = true
    console.log(`  ✅ Admin notification payload validation passed`);
    
    // Now send for real if the dry run worked
    console.log(`  Sending real admin test notification...`);
    const response = await messaging.send(message);
    console.log(`  ✅ Admin notification sent successfully!`);
    console.log(`  FCM Message ID: ${response}`);
    
  } catch (error) {
    console.error(`  ❌ Admin notification test failed:`, error.message);
    console.error(`  Error code:`, error.code);
    console.error(`  Full error:`, error);
  }
}

// Main function
async function main() {
  const userId = process.argv[2];
  
  if (!userId) {
    console.error('\n❌ Please provide a user ID');
    console.log('Usage: node scripts/diagnose-notification-issues.js USER_ID');
    process.exit(1);
  }
  
  console.log('🔍 Starting Notification Diagnostic Tool');
  
  try {
    await diagnoseUserNotifications(userId);
  } catch (error) {
    console.error('❌ Error during diagnosis:', error);
  } finally {
    // Clean up
    console.log('\nCleaning up...');
    await app.delete();
    console.log('Done.');
  }
}

// Run the main function
main(); 