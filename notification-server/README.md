# PULSE App Notification Server

This is a custom Node.js server for handling push notifications for the PULSE app using Firebase Cloud Messaging (FCM). This server is designed to be deployed on platforms like Render, allowing you to send push notifications without requiring Firebase Cloud Functions (which are restricted on the Firebase Spark/Free plan).

## Features

- Token registration and management
- Notification preferences management
- Send notifications to specific users
- Send notifications to all users in a community
- Monitor Firebase Realtime Database and Firestore for events that trigger notifications:
  - New community notices
  - Comments on community notices
  - Likes on community notices
  - New marketplace items
  - Chat messages
  - Report status updates
  - Volunteer posts
  - Users joining volunteer posts

## Prerequisites

- Node.js 18.x or later
- Firebase project with Realtime Database and Firestore
- Firebase Admin SDK service account key

## Setup

1. Clone this repository
2. Install dependencies:
   ```
   npm install
   ```
3. Create a Firebase service account key:
   - Go to Firebase Console > Project Settings > Service Accounts
   - Click "Generate new private key"
   - Save the JSON file as `service-account-key.json` in the root directory of this project

4. Create a `.env` file based on the `.env.example` file:
   ```
   cp .env.example .env
   ```

5. Update the `.env` file with your Firebase configuration

## Running Locally

```
npm run dev
```

The server will start on port 3000 (or the port specified in the `.env` file).

## Deployment to Render

1. Create a new Web Service on Render
2. Connect your GitHub repository
3. Configure the service:
   - **Name**: pulse-notification-server
   - **Environment**: Node
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
   - **Environment Variables**: Add all variables from your `.env` file

4. For the service account key, you have two options:
   - Add the entire JSON content as an environment variable named `FIREBASE_SERVICE_ACCOUNT_JSON`
   - Use Render's Secret Files feature to upload the `service-account-key.json` file

5. Click "Create Web Service"

## API Endpoints

### Token Management

- **POST /api/tokens/register**
  - Register a new FCM token
  - Body: `{ userId, token, platform }`

- **POST /api/tokens/preferences**
  - Update notification preferences
  - Body: `{ userId, preferences }`

### Notifications

- **POST /api/notifications/send**
  - Send a notification to a specific user
  - Body: `{ userId, title, body, data }`

- **POST /api/notifications/send-community**
  - Send a notification to all users in a community
  - Body: `{ communityId, title, body, data, excludeUserId }`

- **POST /api/notifications/test**
  - Send a test notification
  - Body: `{ userId }`

## Flutter App Integration

Update your Flutter app to send FCM tokens to this server instead of Firebase Functions:

```dart
// Send token to backend
Future<void> sendTokenToBackend(String token) async {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return;

  try {
    final response = await http.post(
      Uri.parse('https://your-render-service.onrender.com/api/tokens/register'),
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

## Security Considerations

For production use, consider adding:

1. Authentication middleware to secure API endpoints
2. Rate limiting to prevent abuse
3. HTTPS for secure communication
4. Environment-specific configurations

## Troubleshooting FCM Issues

If you're experiencing issues with FCM notifications, such as 404 errors for the `/batch` endpoint or "data must only contain string values" errors, please refer to the following resources:

1. **Service Account Setup**:
   - Check `SERVICE_ACCOUNT_INSTRUCTIONS.md` for detailed instructions on setting up your Firebase service account
   - Make sure your service account has the proper permissions for FCM

2. **Test FCM Connection**:
   - Run the test script to verify FCM connectivity:
   ```bash
   node scripts/test-fcm-connection.js
   ```

3. **Common Issues and Solutions**:

   - **404 Errors for `/batch` Endpoint**:
     - This is often due to service account permission issues
     - Generate a new service account key with the proper permissions
     - Make sure your Firebase project is active and FCM is enabled

   - **Data Payload Errors**:
     - All values in the data payload must be strings
     - The notification service now automatically converts all values to strings
     - Make sure there are no undefined or null values in your data payload

   - **No Tokens Found**:
     - Make sure FCM tokens are being correctly registered in Firestore
     - Check the `user_tokens` collection in Firestore
     - Verify that your Flutter app is sending tokens to the server

4. **Updates Made to Fix Issues**:
   - Updated Firebase Admin SDK initialization with custom HTTP agent
   - Implemented single-token notification sending instead of batch sending
   - Added better error handling and logging
   - Fixed data payload handling to ensure all values are strings
   - Improved error handling throughout the notification service
   - Added sequential processing of notifications to avoid overwhelming the FCM API

## License

This project is licensed under the MIT License.
