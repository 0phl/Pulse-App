const admin = require('firebase-admin');
const { getFirestore, getMessaging } = require('./firebase');

// Helper function to store a community notification
async function storeNotificationForCommunity(db, communityId, title, body, data, excludeUserId) {
  try {
    // Create a community notification record
    const notificationRef = await db.collection('community_notifications').add({
      communityId,
      title,
      body,
      type: data.type || 'general',
      data,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: data.authorId || excludeUserId || 'system',
    });

    console.log(`Community notification stored with ID: ${notificationRef.id}`);
    return notificationRef.id;
  } catch (error) {
    console.error('Error storing community notification:', error);
    // Generate a unique ID if Firestore fails
    return `local_${Date.now()}_${Math.random().toString(36).substring(2, 15)}`;
  }
}

// Helper function to create a user-specific notification status record
async function createUserNotificationRecord(db, userId, notificationId, communityId) {
  try {
    // Create a notification status record that references the community notification
    // This avoids duplicating the notification content for each user
    const statusRef = await db.collection('notification_status').add({
      userId,
      communityId,
      notificationId, // Reference to the community notification
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Created notification status with ID: ${statusRef.id} for user ${userId} and notification ${notificationId}`);
    return true;
  } catch (error) {
    console.error(`Error creating notification status record for user ${userId}:`, error);
    return false;
  }
}

// Send a notification to a specific user
const sendNotificationToUser = async (userId, title, body, data = {}) => {
  try {
    const db = getFirestore();
    const messaging = getMessaging();

    // Get user's FCM tokens
    const userTokensDoc = await db.collection('user_tokens').doc(userId).get();

    if (!userTokensDoc.exists) {
      console.log(`No tokens found for user ${userId}`);
      return { success: false, error: 'No tokens found' };
    }

    const userData = userTokensDoc.data();
    const tokens = userData.tokens || [];
    const preferences = userData.notificationPreferences || {};

    // Check if user has enabled this notification type
    if (data.type && preferences[data.type] === false) {
      console.log(`User ${userId} has disabled ${data.type} notifications`);
      return { success: false, error: 'Notification type disabled by user' };
    }

    // Extract valid tokens
    const validTokens = tokens
      .filter(tokenData => tokenData.token)
      .map(tokenData => tokenData.token);

    if (validTokens.length === 0) {
      console.log(`No valid tokens found for user ${userId}`);
      return { success: false, error: 'No valid tokens found' };
    }

    // Convert all data values to strings and ensure no undefined values
    const stringifiedData = {};
    Object.keys(data).forEach(key => {
      if (data[key] !== undefined && data[key] !== null) {
        stringifiedData[key] = String(data[key]);
      }
    });

    // Add timestamp to ensure uniqueness
    stringifiedData.timestamp = String(Date.now());
    stringifiedData.click_action = 'FLUTTER_NOTIFICATION_CLICK';

    // Store the notification in Firestore first
    let notificationId;
    try {
      // Create a single notification record
      const notificationRef = await db.collection('user_notifications').add({
        title,
        body,
        type: data.type || 'general',
        data: stringifiedData,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: 'system',
      });
      notificationId = notificationRef.id;

      // Create a status record for this user
      await db.collection('notification_status').add({
        userId,
        notificationId,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      stringifiedData.notificationId = notificationId; // Add to data payload
      console.log(`Notification stored in Firestore for user ${userId} with ID: ${notificationId}`);
    } catch (firestoreError) {
      console.error('Error storing notification in Firestore:', firestoreError);
      // Generate a unique ID if Firestore fails
      notificationId = `local_${Date.now()}_${Math.random().toString(36).substring(2, 15)}`;
      stringifiedData.notificationId = notificationId; // Add to data payload
      // Continue anyway - we still want to try sending the push notification
    }

    // Send notifications one by one instead of using multicast
    // This is more reliable but slower
    let successCount = 0;
    let failureCount = 0;
    const failedTokens = [];

    for (const token of validTokens) {
      try {
        // Create notification message for a single token
        const message = {
          notification: {
            title,
            body,
          },
          data: stringifiedData,
          token: token, // Send to a single token
          android: {
            priority: 'high',
            notification: {
              channelId: 'high_importance_channel',
              priority: 'high',
              defaultSound: true,
              defaultVibrateTimings: true,
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        };

        // Send the notification to this token
        await messaging.send(message);
        successCount++;
        console.log(`Successfully sent notification to token: ${token.substring(0, 10)}...`);
      } catch (tokenError) {
        console.error(`Error sending to token ${token.substring(0, 10)}...`, tokenError.message);
        failedTokens.push(token);
        failureCount++;
      }
    }

    console.log(`Notification sent to ${userId}: ${successCount} successful, ${failureCount} failed`);

    // Remove failed tokens
    if (failedTokens.length > 0) {
      const updatedTokens = tokens.filter(tokenData => !failedTokens.includes(tokenData.token));

      try {
        await db.collection('user_tokens').doc(userId).update({
          tokens: updatedTokens,
        });
        console.log(`Removed ${failedTokens.length} invalid tokens for user ${userId}`);
      } catch (updateError) {
        console.error('Error updating tokens:', updateError);
      }
    }

    return {
      success: successCount > 0,
      successCount,
      failureCount
    };
  } catch (error) {
    console.error('Error sending notification:', error);
    return { success: false, error: error.message };
  }
};

// Send a notification to all users in a community
const sendNotificationToCommunity = async (communityId, title, body, data = {}, excludeUserId = null) => {
  try {
    if (!communityId) {
      console.error('Community ID is undefined or null');
      return { success: false, error: 'Invalid community ID' };
    }

    const db = getFirestore();
    const messaging = getMessaging();
    console.log(`Sending notification to community: ${communityId}`);

    // First, store a single notification record for the community
    // This will be used to track which notification was sent
    const notificationId = await storeNotificationForCommunity(db, communityId, title, body, data, excludeUserId);

    // Get all users in the community
    let usersSnapshot;
    try {
      usersSnapshot = await db.collection('users')
        .where('communityId', '==', communityId)
        .get();
    } catch (queryError) {
      console.error(`Error querying users for community ${communityId}:`, queryError);
      return { success: false, error: `Error querying users: ${queryError.message}` };
    }

    if (usersSnapshot.empty) {
      console.log(`No users found in community ${communityId}`);
      return { success: false, error: 'No users found in community' };
    }

    // Filter users to exclude specific user if provided
    const userDocs = usersSnapshot.docs.filter(doc => !excludeUserId || doc.id !== excludeUserId);
    console.log(`Found ${userDocs.length} users in community ${communityId} (excluding ${excludeUserId || 'none'})`);

    if (userDocs.length === 0) {
      return { success: true, sentCount: 0, message: 'No users to notify after exclusion' };
    }

    // Send notification to each user sequentially to avoid overwhelming the FCM API
    const results = [];
    let successCount = 0;

    for (const doc of userDocs) {
      const userId = doc.id;
      try {
        console.log(`Sending notification to user ${userId} in community ${communityId}`);

        // Get user's FCM tokens
        const userTokensDoc = await db.collection('user_tokens').doc(userId).get();

        if (!userTokensDoc.exists) {
          console.log(`No tokens found for user ${userId}`);
          results.push({ success: false, error: 'No tokens found', userId });
          continue;
        }

        const userData = userTokensDoc.data();
        const tokens = userData.tokens || [];
        const preferences = userData.notificationPreferences || {};

        // Check if user has enabled this notification type
        if (data.type && preferences[data.type] === false) {
          console.log(`User ${userId} has disabled ${data.type} notifications`);
          results.push({ success: false, error: 'Notification type disabled by user', userId });
          continue;
        }

        // Extract valid tokens
        const validTokens = tokens
          .filter(tokenData => tokenData.token)
          .map(tokenData => tokenData.token);

        if (validTokens.length === 0) {
          console.log(`No valid tokens found for user ${userId}`);
          results.push({ success: false, error: 'No valid tokens found', userId });
          continue;
        }

        // Create user-specific notification status record in Firestore
        // This links to the community notification but tracks read status for this user
        await createUserNotificationRecord(db, userId, notificationId, communityId);

        // Log the creation of the user notification status record
        console.log(`Created notification status record for user ${userId} linked to community notification ${notificationId}`);

        // Convert all data values to strings and ensure no undefined values
        const stringifiedData = {};
        Object.keys(data).forEach(key => {
          if (data[key] !== undefined && data[key] !== null) {
            stringifiedData[key] = String(data[key]);
          }
        });

        // Add timestamp to ensure uniqueness
        stringifiedData.timestamp = String(Date.now());
        stringifiedData.click_action = 'FLUTTER_NOTIFICATION_CLICK';
        stringifiedData.notificationId = notificationId;

        // Send FCM notifications to this user's devices
        let userSuccessCount = 0;
        let userFailureCount = 0;
        const failedTokens = [];

        for (const token of validTokens) {
          try {
            // Create notification message for a single token
            const message = {
              notification: {
                title,
                body,
              },
              data: stringifiedData,
              token: token,
              android: {
                priority: 'high',
                notification: {
                  channelId: 'high_importance_channel',
                  priority: 'high',
                  defaultSound: true,
                  defaultVibrateTimings: true,
                },
              },
              apns: {
                payload: {
                  aps: {
                    sound: 'default',
                    badge: 1,
                  },
                },
              },
            };

            // Send the notification to this token
            await messaging.send(message);
            userSuccessCount++;
            console.log(`Successfully sent notification to token: ${token.substring(0, 10)}...`);
          } catch (tokenError) {
            console.error(`Error sending to token ${token.substring(0, 10)}...`, tokenError.message);
            failedTokens.push(token);
            userFailureCount++;
          }
        }

        // Remove failed tokens
        if (failedTokens.length > 0) {
          const updatedTokens = tokens.filter(tokenData => !failedTokens.includes(tokenData.token));

          try {
            await db.collection('user_tokens').doc(userId).update({
              tokens: updatedTokens,
            });
            console.log(`Removed ${failedTokens.length} invalid tokens for user ${userId}`);
          } catch (updateError) {
            console.error('Error updating tokens:', updateError);
          }
        }

        const result = {
          success: userSuccessCount > 0,
          successCount: userSuccessCount,
          failureCount: userFailureCount,
          userId
        };

        results.push(result);

        if (result.success) {
          successCount++;
        }

        // Add a longer delay between requests to avoid rate limiting and reduce duplicates
        await new Promise(resolve => setTimeout(resolve, 500));
      } catch (userError) {
        console.error(`Error sending notification to user ${userId}:`, userError);
        results.push({ success: false, error: userError.message, userId });
      }
    }

    console.log(`Notification sent to ${successCount} out of ${userDocs.length} users in community ${communityId}`);

    return {
      success: successCount > 0,
      sentCount: successCount,
      totalUsers: userDocs.length,
      notificationId,
      results
    };
  } catch (error) {
    console.error('Error sending community notification:', error);
    return { success: false, error: error.message };
  }
};

// Helper function to get notifications for a user
const getUserNotifications = async (userId, limit = 20, offset = 0) => {
  try {
    const db = getFirestore();

    // Get the user's notification status records
    const statusSnapshot = await db.collection('notification_status')
      .where('userId', '==', userId)
      .orderBy('createdAt', 'desc')
      .limit(limit)
      .offset(offset)
      .get();

    if (statusSnapshot.empty) {
      return { success: true, notifications: [] };
    }

    // Extract notification IDs from status records
    const notificationIds = statusSnapshot.docs.map(doc => {
      const data = doc.data();
      return {
        statusId: doc.id,
        notificationId: data.notificationId,
        read: data.read,
        communityId: data.communityId
      };
    });

    // Fetch community notifications
    const communityNotifications = [];
    const userNotifications = [];

    // Process in batches to avoid excessive parallel queries
    const batchSize = 10;
    for (let i = 0; i < notificationIds.length; i += batchSize) {
      const batch = notificationIds.slice(i, i + batchSize);

      // Process community notifications
      const communityBatch = batch.filter(item => item.communityId);
      if (communityBatch.length > 0) {
        const communityQueries = communityBatch.map(item =>
          db.collection('community_notifications').doc(item.notificationId).get()
        );

        const communityResults = await Promise.all(communityQueries);

        for (let j = 0; j < communityResults.length; j++) {
          const doc = communityResults[j];
          const statusInfo = communityBatch[j];

          if (doc.exists) {
            const notificationData = doc.data();
            communityNotifications.push({
              id: doc.id,
              statusId: statusInfo.statusId,
              read: statusInfo.read,
              ...notificationData,
              source: 'community'
            });
          }
        }
      }

      // Process user notifications
      const userBatch = batch.filter(item => !item.communityId);
      if (userBatch.length > 0) {
        const userQueries = userBatch.map(item =>
          db.collection('user_notifications').doc(item.notificationId).get()
        );

        const userResults = await Promise.all(userQueries);

        for (let j = 0; j < userResults.length; j++) {
          const doc = userResults[j];
          const statusInfo = userBatch[j];

          if (doc.exists) {
            const notificationData = doc.data();
            userNotifications.push({
              id: doc.id,
              statusId: statusInfo.statusId,
              read: statusInfo.read,
              ...notificationData,
              source: 'user'
            });
          }
        }
      }
    }

    // Combine and sort all notifications by createdAt
    const allNotifications = [...communityNotifications, ...userNotifications]
      .sort((a, b) => {
        const dateA = a.createdAt ? a.createdAt.toDate() : new Date(0);
        const dateB = b.createdAt ? b.createdAt.toDate() : new Date(0);
        return dateB - dateA; // Descending order (newest first)
      });

    return { success: true, notifications: allNotifications };
  } catch (error) {
    console.error('Error getting user notifications:', error);
    return { success: false, error: error.message };
  }
};

// Mark a notification as read and delete from notification_status
// Returns the notification data so it can still be displayed in the app
const markNotificationAsRead = async (statusId) => {
  try {
    const db = getFirestore();

    // Get the notification status record first to retrieve the notificationId
    const statusDoc = await db.collection('notification_status').doc(statusId).get();

    if (!statusDoc.exists) {
      console.log(`Notification status ${statusId} not found`);
      return { success: false, error: 'Notification status not found' };
    }

    const statusData = statusDoc.data();
    const notificationId = statusData.notificationId;
    const communityId = statusData.communityId;

    if (!notificationId) {
      console.log(`Notification ID not found in status document`);
      return { success: false, error: 'Notification ID not found' };
    }

    // Determine which collection to query based on whether it's a community notification
    const collection = communityId ? 'community_notifications' : 'user_notifications';

    // Get the actual notification document
    const notificationDoc = await db.collection(collection).doc(notificationId).get();

    if (!notificationDoc.exists) {
      console.log(`Notification document ${notificationId} not found`);
      return { success: false, error: 'Notification document not found' };
    }

    // Get the notification data
    const notificationData = notificationDoc.data();

    // Create a combined data object with both status and notification data
    const combinedData = {
      ...notificationData,
      statusId,
      notificationId,
      read: true,
      communityId,
    };

    // Delete the notification status document to save storage
    await db.collection('notification_status').doc(statusId).delete();
    console.log(`Notification status ${statusId} deleted to save storage`);

    return { success: true, data: combinedData };
  } catch (error) {
    console.error('Error processing notification status:', error);
    return { success: false, error: error.message };
  }
};

// Mark all notifications as read for a user and delete from notification_status
// Returns the notification data so it can still be displayed in the app
const markAllNotificationsAsRead = async (userId) => {
  try {
    const db = getFirestore();

    // Get all unread notifications for this user
    const unreadNotifications = await db.collection('notification_status')
      .where('userId', '==', userId)
      .where('read', '==', false)
      .get();

    if (unreadNotifications.empty) {
      console.log(`No unread notifications for user ${userId}`);
      return { success: true, data: [] };
    }

    // Process each notification to get its data before deleting
    const notificationDataList = [];
    const batch = db.batch();

    // Process notifications in batches to avoid loading too many at once
    for (const doc of unreadNotifications.docs) {
      try {
        const statusData = doc.data();
        const notificationId = statusData.notificationId;
        const communityId = statusData.communityId;

        if (notificationId) {
          // Determine which collection to query
          const collection = communityId ? 'community_notifications' : 'user_notifications';

          // Get the actual notification document
          const notificationDoc = await db.collection(collection).doc(notificationId).get();

          if (notificationDoc.exists) {
            const notificationData = notificationDoc.data();

            // Create a combined data object
            const combinedData = {
              ...notificationData,
              statusId: doc.id,
              notificationId,
              read: true,
              communityId,
            };

            notificationDataList.push(combinedData);
          }
        }

        // Mark for deletion
        batch.delete(doc.ref);
      } catch (error) {
        console.error('Error processing notification:', error);
      }
    }

    // Execute the batch delete
    await batch.commit();

    console.log(`Marked and deleted ${unreadNotifications.docs.length} notifications for user ${userId}`);
    return { success: true, data: notificationDataList };
  } catch (error) {
    console.error('Error marking all notifications as read:', error);
    return { success: false, error: error.message };
  }
};

// Clean up old read notifications to save storage
const cleanupReadNotifications = async (olderThanDays = 30) => {
  try {
    const db = getFirestore();

    // Calculate the cutoff date (notifications older than this will be deleted)
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - olderThanDays);

    // Get all notification status records that are marked as read
    const readNotifications = await db.collection('notification_status')
      .where('read', '==', true)
      .get();

    if (readNotifications.empty) {
      console.log('No read notifications to clean up');
      return { success: true, count: 0 };
    }

    // Filter to only include notifications older than the cutoff date
    const oldNotifications = [];
    readNotifications.forEach(doc => {
      const data = doc.data();
      const createdAt = data.createdAt ? data.createdAt.toDate() : null;

      if (createdAt && createdAt < cutoffDate) {
        oldNotifications.push(doc);
      }
    });

    if (oldNotifications.length === 0) {
      console.log('No old read notifications to clean up');
      return { success: true, count: 0 };
    }

    // Delete old read notifications
    const batch = db.batch();
    let count = 0;

    oldNotifications.forEach(doc => {
      batch.delete(doc.ref);
      count++;
    });

    await batch.commit();
    console.log(`Cleaned up ${count} old read notifications (older than ${olderThanDays} days)`);

    return { success: true, count };
  } catch (error) {
    console.error('Error cleaning up read notifications:', error);
    return { success: false, error: error.message };
  }
};

// Schedule cleanup to run periodically (once a day)
setInterval(async () => {
  console.log('Running scheduled cleanup of old read notifications...');
  try {
    // Clean up notifications older than 30 days
    const result = await cleanupReadNotifications(30);
    console.log(`Scheduled cleanup completed: ${result.count} old notifications deleted`);
  } catch (error) {
    console.error('Error in scheduled cleanup:', error);
  }
}, 24 * 60 * 60 * 1000); // 24 hours in milliseconds

module.exports = {
  sendNotificationToUser,
  sendNotificationToCommunity,
  getUserNotifications,
  markNotificationAsRead,
  markAllNotificationsAsRead,
  cleanupReadNotifications
};
