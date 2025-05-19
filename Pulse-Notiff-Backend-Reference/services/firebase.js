const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const https = require('https');

// Initialize Firebase Admin SDK
const initializeApp = () => {
  try {
    let credential;
    let projectId;
    
    // Check for service account JSON string in environment variable first
    if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
      try {
        console.log('Using Firebase service account from environment variable');
        const serviceAccountJson = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
        credential = admin.credential.cert(serviceAccountJson);
        projectId = serviceAccountJson.project_id;
      } catch (jsonError) {
        console.error('Error parsing service account from environment variable:', jsonError);
        console.error('Will try to fall back to service account file');
      }
    }
    
    // If no credential yet, try to load from file
    if (!credential) {
      const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || './service-account-key.json';

      // Check if service account file exists
      if (!fs.existsSync(serviceAccountPath)) {
        console.error(`Service account file not found at ${serviceAccountPath}`);
        console.error('Please create a service account key file and place it in the correct location');
        process.exit(1);
      }

      // Load service account
      const serviceAccount = require(path.resolve(serviceAccountPath));
      credential = admin.credential.cert(serviceAccount);
      projectId = serviceAccount.project_id;
    }

    // Configure HTTP agent with optimized settings for real-time notifications
    const httpAgent = new https.Agent({
      keepAlive: true,
      timeout: 10000, // 10 seconds - shorter timeout for faster failure detection
      maxSockets: 25, // Increased concurrent connections
      keepAliveMsecs: 3000, // Keep connections alive for 3 seconds
      scheduling: 'fifo', // First-in-first-out scheduling for more predictable delivery
      rejectUnauthorized: true // Enforce secure connections
    });

    // Use Firebase project ID from environment variable if provided
    const firebaseProjectId = process.env.FIREBASE_PROJECT_ID || projectId;
    
    // Use the specific regional database URL for this project
    const databaseURL = process.env.FIREBASE_DATABASE_URL || 
                         'https://pulse-app-ea5be-default-rtdb.asia-southeast1.firebasedatabase.app';
    
    // Initialize Firebase Admin SDK with custom HTTP agent
    admin.initializeApp({
      credential: credential,
      databaseURL: databaseURL,
      httpAgent: httpAgent
    });

    // Test FCM connection and apply HTTP agent settings
    admin.messaging().app.options.httpAgent = httpAgent;

    console.log('Firebase Admin SDK initialized successfully');
    console.log(`Project ID: ${firebaseProjectId}`);
    console.log(`Using database URL: ${databaseURL}`);
    
    // Verify messaging service is working
    try {
      const fcmApp = admin.messaging().app;
      console.log('FCM service ready:', fcmApp.name);
    } catch (fcmError) {
      console.error('Warning: Error verifying FCM service:', fcmError.message);
      console.error('Notifications may not work correctly');
    }

    return admin;
  } catch (error) {
    console.error('Error initializing Firebase Admin SDK:', error);
    console.error('Details:', error.stack);
    process.exit(1);
  }
};

// Get Firestore instance
const getFirestore = () => admin.firestore();

// Get Realtime Database instance
const getDatabase = () => admin.database();

// Get Firebase Messaging instance
const getMessaging = () => admin.messaging();

module.exports = {
  initializeApp,
  getFirestore,
  getDatabase,
  getMessaging
};
