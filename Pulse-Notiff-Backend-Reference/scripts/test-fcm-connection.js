/**
 * Test script to verify FCM connectivity
 *
 * Run this script with:
 * node scripts/test-fcm-connection.js
 */

require('dotenv').config();
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const https = require('https');

// Configure HTTP agent with longer timeout
const httpAgent = new https.Agent({
  keepAlive: true,
  timeout: 30000, // 30 seconds
  maxSockets: 10
});

async function testFcmConnection() {
  try {
    console.log('Testing FCM connection...');

    // Get service account path
    const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || './service-account-key.json';

    // Check if service account file exists
    if (!fs.existsSync(serviceAccountPath)) {
      console.error(`Service account file not found at ${serviceAccountPath}`);
      console.error('Please create a service account key file and place it in the correct location');
      process.exit(1);
    }

    // Load service account
    const serviceAccount = require(path.resolve(serviceAccountPath));
    console.log(`Using service account for project: ${serviceAccount.project_id}`);
    console.log(`Service account email: ${serviceAccount.client_email}`);

    // Initialize Firebase Admin SDK
    const app = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      httpAgent: httpAgent
    });

    // Get messaging instance
    const messaging = admin.messaging(app);

    // Create a test message (this won't be sent)
    const message = {
      notification: {
        title: 'Test Notification',
        body: 'This is a test notification',
      },
      token: 'fcm-token-that-doesnt-exist-just-for-testing',
    };

    try {
      // Try to send a message to a non-existent token
      // This will fail with a specific error if the FCM connection is working
      await messaging.send(message);

      // We should never reach here since the token is invalid
      console.log('⚠️ Unexpected success! The test token should not exist.');
      console.log('Your Firebase service account has the correct permissions for FCM.');
    } catch (sendError) {
      if (sendError.code === 'messaging/invalid-argument' ||
          sendError.code === 'messaging/invalid-recipient' ||
          sendError.code === 'messaging/registration-token-not-registered') {
        // This is expected since we're using a fake token
        console.log('✅ FCM connection successful!');
        console.log('Your Firebase service account has the correct permissions for FCM.');
        console.log('Error details (expected because we used a fake token):');
        console.log(sendError.message);
      } else {
        // This indicates a problem with the service account or FCM setup
        console.error('❌ FCM connection test failed!');
        console.error('Error details:');
        console.error(sendError);
      }
    }

    // Clean up
    await app.delete();
    console.log('Test completed.');

  } catch (error) {
    console.error('❌ FCM connection test failed!');
    console.error('Error details:');
    console.error(error);
    process.exit(1);
  }
}

// Run the test
testFcmConnection();
