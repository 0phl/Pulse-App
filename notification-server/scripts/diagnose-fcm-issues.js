/**
 * Comprehensive FCM diagnostic script
 * 
 * This script performs a series of tests to diagnose issues with FCM connectivity
 * 
 * Run this script with:
 * node scripts/diagnose-fcm-issues.js
 */

require('dotenv').config();
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const https = require('https');
const axios = require('axios');

// Configure HTTP agent with longer timeout
const httpAgent = new https.Agent({
  keepAlive: true,
  timeout: 30000, // 30 seconds
  maxSockets: 10
});

async function diagnoseFirebaseSetup() {
  console.log('🔍 Starting Firebase FCM Diagnostic Tool');
  console.log('=======================================');
  
  // Step 1: Check service account file
  console.log('\n📄 Step 1: Checking service account file');
  const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || './service-account-key.json';
  
  if (!fs.existsSync(serviceAccountPath)) {
    console.error('❌ Service account file not found at', serviceAccountPath);
    console.error('Please create a service account key file and place it in the correct location');
    process.exit(1);
  }
  
  console.log('✅ Service account file found at', serviceAccountPath);
  
  // Step 2: Validate service account format
  console.log('\n🔑 Step 2: Validating service account format');
  let serviceAccount;
  try {
    serviceAccount = require(path.resolve(serviceAccountPath));
    
    // Check required fields
    const requiredFields = ['type', 'project_id', 'private_key_id', 'private_key', 'client_email', 'client_id', 'auth_uri', 'token_uri', 'auth_provider_x509_cert_url', 'client_x509_cert_url'];
    const missingFields = requiredFields.filter(field => !serviceAccount[field]);
    
    if (missingFields.length > 0) {
      console.error('❌ Service account file is missing required fields:', missingFields.join(', '));
      process.exit(1);
    }
    
    console.log('✅ Service account format is valid');
    console.log('   Project ID:', serviceAccount.project_id);
    console.log('   Client Email:', serviceAccount.client_email);
  } catch (error) {
    console.error('❌ Failed to parse service account file:', error.message);
    process.exit(1);
  }
  
  // Step 3: Initialize Firebase Admin SDK
  console.log('\n🔥 Step 3: Initializing Firebase Admin SDK');
  let app;
  try {
    app = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      httpAgent: httpAgent
    });
    console.log('✅ Firebase Admin SDK initialized successfully');
  } catch (error) {
    console.error('❌ Failed to initialize Firebase Admin SDK:', error.message);
    console.error(error);
    process.exit(1);
  }
  
  // Step 4: Test Firebase Authentication
  console.log('\n🔐 Step 4: Testing Firebase Authentication');
  try {
    const authToken = await app.auth().createCustomToken('test-user');
    console.log('✅ Firebase Authentication is working');
  } catch (error) {
    console.error('❌ Failed to create custom token:', error.message);
    console.error('This indicates an issue with your service account permissions');
    console.error(error);
  }
  
  // Step 5: Test FCM API access
  console.log('\n📱 Step 5: Testing FCM API access');
  try {
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
      await messaging.send(message);
      console.log('⚠️ Unexpected success! The test token should not exist.');
    } catch (sendError) {
      if (sendError.code === 'messaging/invalid-argument' || 
          sendError.code === 'messaging/invalid-recipient' ||
          sendError.code === 'messaging/registration-token-not-registered') {
        console.log('✅ FCM API access is working');
        console.log('   Error details (expected because we used a fake token):');
        console.log('   ', sendError.message);
      } else if (sendError.code === 'messaging/unknown-error' && sendError.message.includes('404')) {
        console.error('❌ FCM API returned a 404 error');
        console.error('   This typically indicates that your service account does not have the');
        console.error('   proper permissions to use Firebase Cloud Messaging.');
        console.error('   Please make sure your service account has the "Firebase Messaging Admin" role.');
        console.error('   Error details:', sendError.message);
      } else {
        console.error('❌ FCM API access failed with an unexpected error:');
        console.error('   Code:', sendError.code);
        console.error('   Message:', sendError.message);
      }
    }
  } catch (error) {
    console.error('❌ Failed to initialize Firebase Messaging:', error.message);
    console.error(error);
  }
  
  // Step 6: Test network connectivity to FCM endpoints
  console.log('\n🌐 Step 6: Testing network connectivity to FCM endpoints');
  const fcmEndpoints = [
    'https://fcm.googleapis.com/v1/projects/' + serviceAccount.project_id + '/messages:send',
    'https://fcm.googleapis.com/fcm/send',
    'https://firebase.googleapis.com/v1beta1/projects/' + serviceAccount.project_id + '/messages:send'
  ];
  
  for (const endpoint of fcmEndpoints) {
    try {
      console.log('   Testing connectivity to:', endpoint);
      // We're just testing connectivity, not actually sending a request
      const response = await axios.head(endpoint, {
        timeout: 5000,
        validateStatus: () => true // Accept any status code
      });
      
      console.log('   ✅ Connection successful (Status:', response.status + ')');
    } catch (error) {
      if (error.response) {
        // The request was made and the server responded with a status code
        // that falls out of the range of 2xx
        console.log('   ✅ Connection successful (Status:', error.response.status + ')');
      } else if (error.request) {
        // The request was made but no response was received
        console.error('   ❌ Connection failed: No response received');
      } else {
        // Something happened in setting up the request that triggered an Error
        console.error('   ❌ Connection failed:', error.message);
      }
    }
  }
  
  // Step 7: Check Firebase project status
  console.log('\n📊 Step 7: Checking Firebase project status');
  console.log('   Project ID:', serviceAccount.project_id);
  console.log('   ℹ️ Please verify in the Firebase Console that:');
  console.log('     - Your project is active (not suspended)');
  console.log('     - Firebase Cloud Messaging API is enabled');
  console.log('     - Your service account has the "Firebase Messaging Admin" role');
  
  // Clean up
  await app.delete();
  console.log('\n✨ Diagnostic tests completed');
  console.log('Please review the results above to identify any issues with your FCM setup');
}

// Run the diagnostic
diagnoseFirebaseSetup().catch(error => {
  console.error('Diagnostic failed with an unexpected error:', error);
  process.exit(1);
});
