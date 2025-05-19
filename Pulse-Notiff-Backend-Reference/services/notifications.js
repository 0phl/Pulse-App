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

    console.log(`[NOTIFICATION DEBUG] Community notification stored with ID: ${notificationRef.id}`);
    return notificationRef.id;
  } catch (error) {
    console.error('[NOTIFICATION ERROR] Error storing community notification:', error);
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

    console.log(`[NOTIFICATION DEBUG] Created notification status with ID: ${statusRef.id} for user ${userId} and notification ${notificationId}`);
    return true;
  } catch (error) {
    console.error(`[NOTIFICATION ERROR] Error creating notification status record for user ${userId}:`, error);
    return false;
  }
}

// Send a notification to a specific user
const sendNotificationToUser = async (userId, title, body, data = {}) => {
  try {
    // Generate a unique request ID for this notification
    const requestId = `req_${Date.now()}_${Math.random().toString(36).substring(2, 10)}`;
    
    console.log(`[NOTIFICATION DEBUG] [${requestId}] Starting sendNotificationToUser for userId: ${userId}`);
    console.log(`[NOTIFICATION DEBUG] [${requestId}] Title: "${title}", Body: "${body}"`);
    console.log(`[NOTIFICATION DEBUG] [${requestId}] Data payload:`, JSON.stringify(data));
    
    const db = getFirestore();
    const messaging = getMessaging();

    // Get user's FCM tokens
    const userTokensDoc = await db.collection('user_tokens').doc(userId).get();

    if (!userTokensDoc.exists) {
      console.log(`[NOTIFICATION ERROR] [${requestId}] No tokens found for user ${userId}`);
      // Track this user for token recovery in a separate collection
      await db.collection('missing_tokens').doc(userId).set({
        userId,
        lastAttemptedNotification: admin.firestore.FieldValue.serverTimestamp(),
        notificationType: data.type || 'general',
        firstDetected: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      return { success: false, error: 'No tokens found', requestId };
    }

    const userData = userTokensDoc.data();
    const tokens = userData.tokens || [];
    const preferences = userData.notificationPreferences || {};
    
    console.log(`[NOTIFICATION DEBUG] [${requestId}] Found ${tokens.length} tokens for user ${userId}`);
    console.log(`[NOTIFICATION DEBUG] [${requestId}] User preferences:`, JSON.stringify(preferences));

    // Check if user is an admin (for better notification handling)
    let isUserAdmin = false;
    try {
      const userDoc = await db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        isUserAdmin = userData.isAdmin === true || userData.role === 'admin';
      }
      // Add isUserAdmin to data for better notification handling
      data.isUserAdmin = isUserAdmin ? 'true' : 'false';
      if (isUserAdmin) {
        console.log(`[NOTIFICATION DEBUG] [${requestId}] User ${userId} is an admin, using admin notification settings`);
      }
    } catch (error) {
      console.error(`[NOTIFICATION ERROR] [${requestId}] Error checking admin status: ${error.message}`);
    }

    // Check if any tokens are from logged out sessions
    // IMPROVED: More lenient token validation to reduce false negatives
    const now = Date.now();
    const validTokens = tokens.filter(tokenData => {
      // If the token has an explicit loggedOut flag, skip it
      if (tokenData.loggedOut === true) {
        console.log(`[NOTIFICATION DEBUG] [${requestId}] Skipping explicitly logged out token for user ${userId}`);
        return false;
      }
      
      // MODIFIED: Always include tokens for admin users
      if (isUserAdmin) {
        console.log(`[NOTIFICATION DEBUG] [${requestId}] Including token for admin user ${userId} regardless of timestamp`);
        return true;
      }
      
      // Always include tokens without a lastActive timestamp (legacy tokens)
      if (!tokenData.lastActive) {
        console.log(`[NOTIFICATION DEBUG] [${requestId}] Including legacy token without timestamp for user ${userId}`);
        return true;
      }
      
      // Convert Firestore timestamp to milliseconds
      const lastActiveMs = tokenData.lastActive.toMillis ? 
        tokenData.lastActive.toMillis() : 
        (tokenData.lastActive._seconds ? tokenData.lastActive._seconds * 1000 : 0);
      
      console.log(`[NOTIFICATION DEBUG] [${requestId}] Token timestamp check: now=${now}, lastActive=${lastActiveMs}, diff=${now - lastActiveMs} ms`);
      
      // Handle future timestamps (system clock issues) by treating them as active
      if (lastActiveMs > now) {
        console.log(`[NOTIFICATION DEBUG] [${requestId}] Token has future timestamp for user ${userId}, treating as active: ${new Date(lastActiveMs).toISOString()}`);
        return true;
      }
      
      // MODIFIED: Significantly increased token lifetime from 60 days to 365 days for better reliability
      const yearInMs = 365 * 24 * 60 * 60 * 1000; // 365 days in milliseconds
      const isRecentlyActive = (now - lastActiveMs) < yearInMs;
      
      if (!isRecentlyActive) {
        console.log(`[NOTIFICATION DEBUG] [${requestId}] Skipping very old token for user ${userId}, last active: ${new Date(lastActiveMs).toISOString()}`);
      }
      
      return isRecentlyActive;
    });
    
    // IMPROVED: More intentional fallback strategy
    // If no tokens are valid after filtering, use only the most recent token as a fallback
    if (validTokens.length === 0 && tokens.length > 0) {
      console.log(`[NOTIFICATION WARNING] [${requestId}] No valid tokens found for user ${userId} after filtering, using most recent token as fallback`);
      
      // MODIFIED: For admin users, just use the first available token without complex filtering
      if (isUserAdmin) {
        console.log(`[NOTIFICATION DEBUG] [${requestId}] Admin user ${userId}: using available token as fallback without complex filtering`);
        validTokens.push(tokens[0]);
      } else {
        // Find most recent token by lastActive timestamp
        let mostRecentToken = tokens[0];
        let mostRecentTimestamp = 0;
        
        tokens.forEach(tokenData => {
          if (tokenData.lastActive) {
            const lastActiveMs = tokenData.lastActive.toMillis ? 
              tokenData.lastActive.toMillis() : 
              (tokenData.lastActive._seconds ? tokenData.lastActive._seconds * 1000 : 0);
            
            if (lastActiveMs > mostRecentTimestamp) {
              mostRecentTimestamp = lastActiveMs;
              mostRecentToken = tokenData;
            }
          }
        });
        
        validTokens.push(mostRecentToken);
        console.log(`[NOTIFICATION DEBUG] [${requestId}] Using most recent token from ${new Date(mostRecentTimestamp).toISOString()}`);
      }
      
      // Record this token recovery attempt
      try {
        await db.collection('token_recovery_attempts').add({
          userId,
          isAdmin: isUserAdmin ? true : false,
          tokenUsed: validTokens[0].token ? validTokens[0].token.substring(0, 15) + '...' : 'unknown format',
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          notificationType: data.type || 'general'
        });
      } catch (err) {
        console.error('[NOTIFICATION ERROR] Failed to record token recovery attempt:', err);
      }
    }
    
    // If there are still no valid tokens (empty tokens array), return error
    if (validTokens.length === 0) {
      console.log(`[NOTIFICATION ERROR] [${requestId}] No tokens found for user ${userId}`);
      // Track this user for token recovery in a separate collection
      await db.collection('missing_tokens').doc(userId).set({
        userId,
        lastAttemptedNotification: admin.firestore.FieldValue.serverTimestamp(),
        notificationType: data.type || 'general',
        firstDetected: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      return { success: false, error: 'No tokens found', requestId };
    }
    
    // Replace the original tokens array with our filtered one
    tokens.length = 0;
    tokens.push(...validTokens);
    
    console.log(`[NOTIFICATION DEBUG] [${requestId}] After filtering inactive tokens: ${tokens.length} remaining for user ${userId}`);

    // Check if user has enabled this notification type
    if (data.type && preferences[data.type] === false) {
      console.log(`[NOTIFICATION ERROR] [${requestId}] User ${userId} has disabled ${data.type} notifications`);
      return { success: false, error: 'Notification type disabled by user', requestId };
    }

    // For social interactions, we check if the user who performed the action (likerId/commenterId) 
    // is the same as the recipient (userId)
    if (data.type === 'socialInteractions') {
      // For likes, check if likerId matches userId
      if (data.likerId && data.likerId === userId) {
        console.log(`[NOTIFICATION ERROR] [${requestId}] Prevented self-notification for user ${userId} (own action - like)`);
        return { success: false, error: 'Self-notification prevented', requestId };
      }
      
      // For comments, check if commenterId matches userId
      if (data.commenterId && data.commenterId === userId) {
        console.log(`[NOTIFICATION ERROR] [${requestId}] Prevented self-notification for user ${userId} (own action - comment)`);
        return { success: false, error: 'Self-notification prevented', requestId };
      }
    } 
    // For other notification types, use the original check if needed
    // MODIFIED: Allow admins to receive their own community notice notifications
    else if (data.type !== 'socialInteractions' && data.type !== 'communityNotices' && data.authorId && data.authorId === userId) {
      console.log(`[NOTIFICATION ERROR] [${requestId}] Prevented self-notification for user ${userId} (own content)`);
      return { success: false, error: 'Self-notification prevented', requestId };
    }

    // IMPROVED: More reliable token extraction
    console.log(`[NOTIFICATION DEBUG] [${requestId}] Analyzing tokens for user ${userId}`);
    
    // First, standardize all tokens to a consistent format
    const standardizedTokens = tokens.map(tokenData => {
      // Handle token format variations
      if (typeof tokenData === 'string') {
        // Simple string token
        return {
          token: tokenData,
          platform: 'unknown',
          standardized: true
        };
      } else if (tokenData && typeof tokenData === 'object') {
        // Standard object format
        if (tokenData.token) {
          return {
            token: tokenData.token,
            platform: tokenData.platform || tokenData.deviceType || 'unknown',
            lastActive: tokenData.lastActive || null,
            standardized: true
          };
        }
      }
      return null; // Invalid token
    }).filter(token => token !== null);
    
    console.log(`[NOTIFICATION DEBUG] [${requestId}] Standardized ${standardizedTokens.length} tokens for user ${userId}`);
    
    // Variables to track successful and failed deliveries and invalidated tokens
    let successCount = 0;
    let failureCount = 0;
    const failedTokens = [];
    
    // Create a deep copy of the data object to avoid reference issues between notifications
    // This is crucial when multiple notifications are sent in quick succession
    const originalData = JSON.parse(JSON.stringify(data || {}));
    
    // Add unique requestId to the notification data to ensure uniqueness
    originalData.requestId = requestId;
    
    // First, stringify all data values
    const stringifiedData = {};
    // Clone and stringify all data fields to avoid reference issues
    Object.keys(originalData).forEach(key => {
      if (originalData[key] !== undefined && originalData[key] !== null) {
        // Ensure every value is a string
        stringifiedData[key] = typeof originalData[key] === 'string' 
          ? originalData[key] 
          : String(originalData[key]);
      }
    });
    
    console.log(`[NOTIFICATION DEBUG] [${requestId}] Sending notification to ${standardizedTokens.length} tokens for user ${userId}`);
    
    // Send to each token individually for better error tracking
    for (const tokenData of standardizedTokens) {
      // Clone messaging data for each token to prevent shared references
      // CRITICAL FIX: Each token gets a fresh copy of notification data
      const tokenSpecificData = JSON.parse(JSON.stringify(stringifiedData));
      
      // Extract token value
      const token = tokenData.token;
      
      // Skip invalid tokens
      if (!token) {
        console.error(`[NOTIFICATION ERROR] [${requestId}] Invalid token format:`, JSON.stringify(tokenData));
        continue;
      }
      
      try {
        console.log(`[NOTIFICATION DEBUG] [${requestId}] Preparing message for token: ${token.substring(0, 15)}...`);
        
        // Check if user is an admin based on data in the notification
        const isAdmin = tokenSpecificData.isUserAdmin === 'true' || 
                      (tokenSpecificData.noticeAuthorId === userId && tokenSpecificData.authorIsAdmin === 'true');
        
        if (isAdmin) {
          console.log(`[NOTIFICATION DEBUG] [${requestId}] Preparing ADMIN notification with special handling for user: ${userId}`);
        }
        
        // Create a unique tag for this specific notification to prevent overwriting
        const uniqueNotificationTag = `${tokenSpecificData.type || 'notification'}_${requestId}_${Date.now()}`;
        
        // Create notification message for a single token with optimized delivery settings
        // Restructuring payload to match exactly what the Flutter app expects
        const message = {
          notification: {
            title,
            body,
          },
          data: {
            ...tokenSpecificData,
            // Add required fields from frontend inspection
            type: tokenSpecificData.type || 'general',
            priority: tokenSpecificData.priority || 'high',
            isForAdmin: isAdmin ? 'true' : 'false',
            forceAlert: 'true',
            // Ensure notificationId is always sent
            notificationId: tokenSpecificData.notificationId || `local_${Date.now()}`,
            // Add timestamp to ensure uniqueness
            timestamp: String(Date.now()),
            // Add unique request ID to ensure each notification is distinct
            requestId: requestId,
            click_action: 'FLUTTER_NOTIFICATION_CLICK'
          },
          token: token, // Send to a single token
          android: {
            priority: 'high',
            ttl: 60 * 1000, // 1 minute expiration for better real-time delivery
            notification: {
              // Use a different channel for admins to bypass potential channel restrictions
              channelId: isAdmin ? 'admin_high_importance_channel' : 'high_importance_channel',
              // FCM doesn't support the importance field directly 
              // Only use fields that FCM API supports
              defaultSound: true,
              defaultVibrateTimings: true,
              visibility: 'public',
              sound: 'default', // Explicitly set sound
              // Add a tag with both type and timestamp to make notifications not replace each other
              tag: uniqueNotificationTag,
            },
            directBootOk: true, // Allow delivery during direct boot mode
          },
          apns: {
            headers: {
              'apns-priority': '10', // Immediate delivery (10) instead of default (5)
              'apns-push-type': 'alert',
            },
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
                'content-available': 1, // Wakes up the app for processing
                'mutable-content': 1,   // Allows notification service extension to modify content
                'interruption-level': 'time-sensitive', // iOS 15+ priority
                // Add alert category for admin
                category: isAdmin ? 'ADMIN_NOTIFICATION' : 'USER_NOTIFICATION',
                // Add unique identifier in the thread-id to prevent grouping of different notifications
                'thread-id': uniqueNotificationTag,
              },
            },
          },
        };
        
        console.log(`[NOTIFICATION DEBUG] [${requestId}] Full message payload:`, JSON.stringify(message));
        
        // Send the notification to this token
        const response = await messaging.send(message);
        successCount++;
        console.log(`[NOTIFICATION SUCCESS] [${requestId}] Sent notification to token: ${token.substring(0, 15)}...`);
        console.log(`[NOTIFICATION DEBUG] [${requestId}] FCM response:`, response);
      } catch (tokenError) {
        // Check if this is a token-specific error that indicates the token is invalid
        const isTokenInvalid = 
          tokenError.code === 'messaging/invalid-argument' ||
          tokenError.code === 'messaging/invalid-registration-token' ||
          tokenError.code === 'messaging/registration-token-not-registered' ||
          tokenError.message?.includes('Invalid registration token') ||
          tokenError.message?.includes('not a valid FCM registration token');
        
        // Detailed logging for better troubleshooting
        console.error(`[NOTIFICATION ERROR] [${requestId}] Failed to send to token ${token.substring(0, 15)}...`);
        console.error(`[NOTIFICATION ERROR] [${requestId}] Error code: ${tokenError.code || 'unknown'}`);
        console.error(`[NOTIFICATION ERROR] [${requestId}] Error message: ${tokenError.message}`);
        
        if (isTokenInvalid) {
          console.error(`[NOTIFICATION ERROR] [${requestId}] Token identified as invalid and will be removed`);
          failedTokens.push(token);
        } else {
          console.error(`[NOTIFICATION ERROR] [${requestId}] This may be a transient error, not removing token`);
          // Count as a failure but don't mark token as invalid
        }
        
        failureCount++;
      }
    }

    console.log(`[NOTIFICATION SUMMARY] [${requestId}] Notification to ${userId}: ${successCount} successful, ${failureCount} failed`);

    // Remove failed tokens
    if (failedTokens.length > 0) {
      const updatedTokens = tokens.filter(tokenData => {
        const tokenValue = typeof tokenData === 'string' ? tokenData : tokenData.token;
        return !failedTokens.includes(tokenValue);
      });

      try {
        await db.collection('user_tokens').doc(userId).update({
          tokens: updatedTokens,
        });
        console.log(`[NOTIFICATION DEBUG] [${requestId}] Removed ${failedTokens.length} invalid tokens for user ${userId}`);
      } catch (updateError) {
        console.error(`[NOTIFICATION ERROR] [${requestId}] Error updating tokens:`, updateError);
      }
    }

    return {
      success: successCount > 0,
      successCount,
      failureCount,
      requestId
    };
  } catch (error) {
    console.error(`[NOTIFICATION ERROR] [${requestId || 'unknown'}] Error in sendNotificationToUser:`, error);
    return { success: false, error: error.message, requestId };
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

    // Get the excluded user's tokens to further filter out devices
    let excludedUserTokens = new Set();
    if (excludeUserId) {
      try {
        const excludedUserTokensDoc = await db.collection('user_tokens').doc(excludeUserId).get();
        if (excludedUserTokensDoc.exists) {
          const tokenData = excludedUserTokensDoc.data();
          excludedUserTokens = new Set((tokenData.tokens || [])
            .filter(t => t && (typeof t === 'string' || t.token))
            .map(t => typeof t === 'string' ? t : t.token));
          console.log(`[NOTIFICATION DEBUG] Found ${excludedUserTokens.size} tokens belonging to excluded user ${excludeUserId}`);
        }
      } catch (error) {
        console.error(`[NOTIFICATION ERROR] Error getting excluded user tokens: ${error.message}`);
        // Continue with the process, as this is just an optimization
      }
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

        // Extract valid tokens and filter out tokens of excluded user (for shared devices)
        const validTokens = tokens
          .filter(tokenData => {
            // Allow both string tokens and token objects
            const hasToken = typeof tokenData === 'string' || (tokenData && tokenData.token);
            
            // Check for explicit logout flag
            const isLoggedOut = tokenData && tokenData.loggedOut === true;
            
            return hasToken && !isLoggedOut;
          })
          .map(tokenData => typeof tokenData === 'string' ? tokenData : 
                          (tokenData && tokenData.token ? tokenData.token : null))
          .filter(token => token !== null && !excludedUserTokens.has(token)); // Filter out null tokens and tokens of excluded user

        if (validTokens.length === 0) {
          console.log(`No valid tokens found for user ${userId} after filtering out excluded user's devices`);
          results.push({ success: false, error: 'No valid tokens found after filtering', userId });
          continue;
        }

        console.log(`[NOTIFICATION DEBUG] User ${userId} has ${validTokens.length} valid tokens after filtering`);

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
            // Create notification message for a single token with optimized delivery settings
            const isAdmin = data.isUserAdmin === 'true' || 
                        (data.noticeAuthorId === userId && data.authorIsAdmin === 'true');
                        
            if (isAdmin) {
              console.log(`[NOTIFICATION DEBUG] Preparing community ADMIN notification with special handling for user: ${userId}`);
            }
            
            // Restructuring payload to match exactly what the Flutter app expects
            const message = {
              notification: {
                title,
                body,
              },
              data: {
                ...stringifiedData,
                // Add required fields from frontend inspection
                type: data.type || 'communityNotices',
                priority: data.priority || 'high',
                communityId: communityId, // Always include communityId for community notifications
                isForAdmin: isAdmin ? 'true' : 'false',
                forceAlert: 'true',
                // Ensure notificationId is always sent
                notificationId: notificationId
              },
              token: token,
              android: {
                priority: 'high',
                ttl: 60 * 1000, // 1 minute expiration for better real-time delivery
                notification: {
                  // Use a different channel for admins to bypass potential channel restrictions
                  channelId: isAdmin ? 'admin_high_importance_channel' : 'high_importance_channel',
                  // FCM doesn't support the importance field directly
                  // Only use fields that FCM API supports
                  defaultSound: true,
                  defaultVibrateTimings: true,
                  visibility: 'public',
                  sound: 'default', // Explicitly set sound
                  // Add a tag to make notifications not replace each other
                  tag: `${data.type || 'communityNotices'}_${Date.now()}`,
                },
                directBootOk: true, // Allow delivery during direct boot mode
              },
              apns: {
                headers: {
                  'apns-priority': '10', // Immediate delivery (10) instead of default (5)
                  'apns-push-type': 'alert',
                },
                payload: {
                  aps: {
                    sound: 'default',
                    badge: 1,
                    'content-available': 1, // Wakes up the app for processing
                    'mutable-content': 1,   // Allows notification service extension to modify content
                    'interruption-level': 'time-sensitive', // iOS 15+ priority
                    // Add alert category for admin
                    category: isAdmin ? 'ADMIN_NOTIFICATION' : 'USER_NOTIFICATION',
                  },
                },
              },
            };

            // Send the notification to this token
            const response = await messaging.send(message);
            userSuccessCount++;
            console.log(`[NOTIFICATION SUCCESS] Sent notification to token: ${token.substring(0, 15)}...`);
            console.log(`[NOTIFICATION DEBUG] FCM response:`, response);
          } catch (tokenError) {
            // Check if this is a token-specific error that indicates the token is invalid
            const isTokenInvalid = 
              tokenError.code === 'messaging/invalid-argument' ||
              tokenError.code === 'messaging/invalid-registration-token' ||
              tokenError.code === 'messaging/registration-token-not-registered' ||
              tokenError.message?.includes('Invalid registration token') ||
              tokenError.message?.includes('not a valid FCM registration token');
            
            // Detailed logging for better troubleshooting
            console.error(`[NOTIFICATION ERROR] Failed to send to token ${token.substring(0, 15)}...`);
            console.error(`[NOTIFICATION ERROR] Error code: ${tokenError.code || 'unknown'}`);
            console.error(`[NOTIFICATION ERROR] Error message: ${tokenError.message}`);
            
            if (isTokenInvalid) {
              console.error(`[NOTIFICATION ERROR] Token identified as invalid and will be removed`);
              failedTokens.push(token);
            } else {
              console.error(`[NOTIFICATION ERROR] This may be a transient error, not removing token`);
              // Count as a failure but don't mark token as invalid
            }
            
            userFailureCount++;
          }
        }

        // Remove failed tokens
        if (failedTokens.length > 0) {
          const updatedTokens = tokens.filter(tokenData => {
            const tokenValue = typeof tokenData === 'string' ? tokenData : tokenData.token;
            return !failedTokens.includes(tokenValue);
          });

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

        // Use a shorter delay to improve real-time delivery while still avoiding rate limiting
        await new Promise(resolve => setTimeout(resolve, 100));
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
