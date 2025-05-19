# Notification Server Update Instructions

This document provides instructions for updating and running the notification server to fix the 404 errors and data payload issues.

## Issues Fixed

1. **404 Errors for `/batch` Endpoint**:
   - Updated firebase-admin package to version 12.0.0
   - This resolves issues with the FCM API endpoint

2. **Data Payload Errors**:
   - Modified the notification service to ensure all data values are strings
   - This fixes the "data must only contain string values" error

3. **Error Handling**:
   - Improved error handling in the monitoring service
   - Added try-catch blocks to prevent the server from crashing

## Update Instructions

1. **Update Dependencies**:
   ```bash
   cd notification-server
   npm install
   ```

2. **Verify Service Account**:
   - Make sure your Firebase service account key file is valid and up-to-date
   - The file should be located at `./service-account-key.json` or at the path specified in your `.env` file

3. **Start the Server**:
   ```bash
   npm run dev
   ```

4. **Test Notifications**:
   - Use the test endpoint to send a test notification:
   ```bash
   curl -X POST http://localhost:3000/api/notifications/test \
     -H "Content-Type: application/json" \
     -d '{"userId": "YOUR_USER_ID"}'
   ```

## Troubleshooting

If you continue to experience issues:

1. **Check Firebase Admin SDK Initialization**:
   - Verify that your service account key file is valid
   - Make sure your Firebase project has FCM enabled

2. **Check FCM Token Registration**:
   - Verify that FCM tokens are being correctly registered in Firestore
   - Check the `user_tokens` collection in Firestore

3. **Check Logs**:
   - Look for specific error messages in the server logs
   - Check for any Firebase Admin SDK initialization errors

4. **Update Firebase Admin SDK**:
   - If issues persist, try updating to the latest firebase-admin version:
   ```bash
   npm install firebase-admin@latest
   ```

5. **Restart the Server**:
   - Sometimes a simple restart can resolve issues:
   ```bash
   npm run dev
   ```

## Additional Resources

- [Firebase Admin SDK Documentation](https://firebase.google.com/docs/admin/setup)
- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
- [Firebase Admin Node.js SDK GitHub Repository](https://github.com/firebase/firebase-admin-node)
