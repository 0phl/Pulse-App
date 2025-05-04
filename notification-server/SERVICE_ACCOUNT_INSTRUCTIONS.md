# Firebase Service Account Setup Instructions

This document provides instructions for setting up a proper Firebase service account for your notification server.

## Issues with FCM Notifications

If you're experiencing 404 errors with the `/batch` endpoint, it's likely due to issues with your Firebase service account. The service account needs to have the proper permissions to use Firebase Cloud Messaging (FCM).

## Creating a New Service Account

1. **Go to the Firebase Console**:
   - Visit [https://console.firebase.google.com/](https://console.firebase.google.com/)
   - Select your project

2. **Navigate to Project Settings**:
   - Click on the gear icon (⚙️) in the top left
   - Select "Project settings"

3. **Go to Service Accounts Tab**:
   - Click on the "Service accounts" tab
   - You should see "Firebase Admin SDK" listed

4. **Generate a New Private Key**:
   - Click "Generate new private key"
   - Confirm by clicking "Generate key"
   - A JSON file will be downloaded to your computer

5. **Replace Your Existing Service Account Key**:
   - Copy the downloaded JSON file to your notification server directory
   - Rename it to `service-account-key.json`
   - Make sure it's in the root directory of your notification server (or update the path in your `.env` file)

## Verifying Service Account Permissions

Your service account should have the following roles:

1. **Firebase Admin SDK Administrator Service Agent**
2. **Firebase Messaging Admin**

To verify or add these roles:

1. **Go to Google Cloud Console**:
   - Visit [https://console.cloud.google.com/](https://console.cloud.google.com/)
   - Select your Firebase project

2. **Navigate to IAM & Admin**:
   - In the left sidebar, click on "IAM & Admin" > "IAM"

3. **Find Your Service Account**:
   - Look for the service account email that matches the one in your JSON file
   - Click the pencil icon to edit its permissions

4. **Add the Required Roles**:
   - Click "Add another role"
   - Search for and add "Firebase Admin SDK Administrator Service Agent"
   - Click "Add another role" again
   - Search for and add "Firebase Messaging Admin"
   - Click "Save"

## Testing Your Service Account

After replacing your service account key and ensuring it has the proper permissions:

1. **Restart Your Notification Server**:
   ```bash
   npm run dev
   ```

2. **Check the Console Logs**:
   - Look for "Firebase Admin SDK initialized successfully"
   - Check for any error messages related to authentication or permissions

3. **Send a Test Notification**:
   - Use the test endpoint to send a notification to a specific user
   ```bash
   curl -X POST http://localhost:3000/api/notifications/test \
     -H "Content-Type: application/json" \
     -d '{"userId": "YOUR_USER_ID"}'
   ```

## Additional Troubleshooting

If you continue to experience issues:

1. **Check Firebase Project Status**:
   - Make sure your Firebase project is active and not suspended
   - Verify that FCM is enabled for your project

2. **Check API Restrictions**:
   - In Google Cloud Console, go to "APIs & Services" > "Credentials"
   - Make sure there are no API restrictions that would block FCM

3. **Verify Network Connectivity**:
   - Ensure your server can reach the FCM endpoints
   - Check for any firewalls or proxy settings that might be blocking connections

4. **Check for Rate Limiting**:
   - FCM has rate limits that might be affecting your notifications
   - Try sending fewer notifications at a time

5. **Update Firebase Admin SDK**:
   - Make sure you're using the latest version of the firebase-admin package
   ```bash
   npm install firebase-admin@latest
   ```
