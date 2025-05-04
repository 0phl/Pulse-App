const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const https = require('https');

// Initialize Firebase Admin SDK
const initializeApp = () => {
  try {
    const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || './service-account-key.json';

    // Check if service account file exists
    if (!fs.existsSync(serviceAccountPath)) {
      console.error(`Service account file not found at ${serviceAccountPath}`);
      console.error('Please create a service account key file and place it in the correct location');
      process.exit(1);
    }

    // Load service account
    const serviceAccount = require(path.resolve(serviceAccountPath));

    // Configure HTTP agent with longer timeout
    const httpAgent = new https.Agent({
      keepAlive: true,
      timeout: 30000, // 30 seconds
      maxSockets: 10
    });

    // Initialize Firebase Admin SDK with custom HTTP agent
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      databaseURL: process.env.FIREBASE_DATABASE_URL || 'https://pulse-app-ea5be-default-rtdb.asia-southeast1.firebasedatabase.app',
      httpAgent: httpAgent
    });

    // Test FCM connection
    admin.messaging().app.options.httpAgent = httpAgent;

    console.log('Firebase Admin SDK initialized successfully');
    console.log(`Project ID: ${serviceAccount.project_id}`);
    console.log(`Using database URL: ${process.env.FIREBASE_DATABASE_URL || 'https://pulse-app-ea5be-default-rtdb.asia-southeast1.firebasedatabase.app'}`);

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
