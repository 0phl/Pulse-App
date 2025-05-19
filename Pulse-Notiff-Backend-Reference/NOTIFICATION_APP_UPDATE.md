# Flutter App Update for Comment Notifications

This guide explains how to update your Flutter app to properly display comment content in notifications.

## Issue Overview

The issue occurs when comments appear with empty content in notifications, showing only `""` in the notification message. This is happening because:

1. The comment text might be stored in different fields in the database
2. The backend wasn't properly handling empty comments
3. The app might not be using the comment data from the notification payload

## Backend Fixes (Already Applied)

The backend has been updated to:
- Check both `text` and `content` fields for comment content
- Provide a default message for empty comments ("No comment text")
- Include the comment text in the notification data payload
- Add detailed debug logging

## Flutter App Updates

### 1. Update FCM Notification Handling

Ensure your notification handling code processes the comment text from the notification data:

```dart
// In your notification handling class
void handleNotification(RemoteMessage message) {
  final data = message.data;
  
  // Check if this is a comment notification
  if (data['type'] == 'socialInteractions' && data.containsKey('commentId')) {
    // Extract comment text from data payload if available
    final commentText = data['commentText'] ?? '';
    
    // If commentText is available in the payload, use it
    if (commentText.isNotEmpty) {
      // Use the comment text directly from the payload
      showNotification(
        title: message.notification?.title ?? 'New Comment',
        body: message.notification?.body ?? 'You received a new comment',
        payload: jsonEncode(data),
      );
    }
  } else {
    // Handle other notification types
    showNotification(
      title: message.notification?.title ?? 'New Notification',
      body: message.notification?.body ?? 'You have a new notification',
      payload: jsonEncode(data),
    );
  }
}
```

### 2. Update Notification Display

If you're displaying notifications in your app UI (like a notifications page), update the display code:

```dart
Widget buildNotificationItem(NotificationModel notification) {
  // For comment notifications, ensure you're displaying the comment text
  if (notification.type == 'socialInteractions' && notification.data.containsKey('commentId')) {
    // Try to get comment text from the notification data
    final commentText = notification.data['commentText'] ?? '';
    
    return ListTile(
      leading: Icon(Icons.comment),
      title: Text('New Comment on Your Notice'),
      subtitle: Text(commentText.isNotEmpty
          ? 'Comment: "$commentText"'
          : 'New comment from ${notification.data['authorName'] ?? 'Someone'}'),
      // Other notification display code...
    );
  }
  
  // Handle other notification types
  // ...
}
```

### 3. Fetch Comment Details When Needed

For a better user experience, fetch the complete comment when the user taps on the notification:

```dart
void onNotificationTap(NotificationModel notification) {
  if (notification.type == 'socialInteractions' && notification.data.containsKey('commentId')) {
    final noticeId = notification.data['noticeId'];
    final commentId = notification.data['commentId'];
    
    // Navigate to the notice detail page and highlight the comment
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoticeDetailPage(
          noticeId: noticeId,
          highlightedCommentId: commentId,
        ),
      ),
    );
  }
}
```

## Debugging

If you're still having issues with comment notifications:

1. Enable verbose logging in your Flutter app:

```dart
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  print('Received notification: ${message.notification?.title}');
  print('Notification data: ${message.data}');
  
  // Continue handling the notification...
});
```

2. Check the backend logs for the `[COMMENT DEBUG]` messages to see how comments are being processed

3. Verify that your database has comment text stored consistently (either in `text` or `content` fields)

## Testing

To test the fixed notifications:

1. Post a comment on a notice
2. Check the backend logs to ensure the comment text is being correctly detected
3. Verify that the notification shows the proper comment text on the device

## Contact

If you continue to have issues with comment notifications, please gather the following information:

1. Backend logs showing the `[COMMENT DEBUG]` messages
2. Flutter app logs showing the received notification data
3. A screenshot of the database structure for a problematic comment 