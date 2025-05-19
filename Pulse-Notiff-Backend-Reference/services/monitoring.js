const admin = require('firebase-admin');
const { getDatabase, getFirestore } = require('./firebase');

// Monitor for new community notices
const monitorCommunityNotices = () => {
  const db = getDatabase();
  const firestore = getFirestore();
  const noticesRef = db.ref('/community_notices');

  console.log('Starting monitoring for new community notices...');

  // Listen for new notices
  noticesRef.on('child_added', async (snapshot) => {
    try {
      const noticeData = snapshot.val();
      const noticeId = snapshot.key;

      if (!noticeData || !noticeData.communityId) {
        console.log('Invalid notice data');
        return;
      }

      // IMPROVED: Extended time window for processing notices
      // Check if notice was created recently (within the last 2 minutes)
      // Increased from 30 seconds to 2 minutes to ensure we don't miss notices
      const now = Date.now();
      const createdAt = noticeData.createdAt || 0;

      // Only skip notices that are extremely old (> 1 hour)
      if (now - createdAt > 60 * 60 * 1000) {
        // Skip notices older than 1 hour
        console.log(`Skipping notice ${noticeId} - too old (${Math.floor((now - createdAt)/1000)} seconds)`);
        return;
      }
      
      // For notices between 2 minutes and 1 hour old, log but still process them
      if (now - createdAt > 2 * 60 * 1000) {
        console.log(`Notice ${noticeId} is older than expected (${Math.floor((now - createdAt)/1000)} seconds), but still processing`);
      } else {
        console.log(`New community notice detected: ${noticeId}`);
      }
      
      // Enhanced logging for better debugging
      console.log(`[NOTICE DEBUG] Notice created by user: ${noticeData.authorId || 'unknown'}`);
      console.log(`[NOTICE DEBUG] Notice title: "${noticeData.title || 'No title'}"`);
      console.log(`[NOTICE DEBUG] Notice community: ${noticeData.communityId}`);
      console.log(`[NOTICE DEBUG] Notice created at: ${new Date(createdAt).toISOString()}`);
      
      // Check if author is admin and store the status
      let authorIsAdmin = false;
      if (noticeData.authorId) {
        try {
          const authorDocRef = await firestore.collection('users').doc(noticeData.authorId).get();
          if (authorDocRef.exists) {
            const authorData = authorDocRef.data();
            authorIsAdmin = authorData.isAdmin === true || authorData.role === 'admin';
            if (authorIsAdmin) {
              console.log(`[NOTICE DEBUG] Notice author ${noticeData.authorId} is an admin`);
              // Don't exclude admins - they should get notifications like other users
            }
          }
        } catch (error) {
          console.error(`[NOTICE ERROR] Failed to check author admin status: ${error.message}`);
        }
      }

      // Check if notification for this notice already exists in Firestore
      // to prevent duplicate notifications
      const existingNotifications = await firestore
        .collection('community_notifications')
        .where('data.noticeId', '==', noticeId)
        .limit(1)
        .get();

      if (!existingNotifications.empty) {
        console.log(`Notification for notice ${noticeId} already exists, skipping`);
        return;
      }

      // Send notification to all users in the community except the author
      const { sendNotificationToCommunity } = require('./notifications');
      
      // Make sure to pass the authorId to exclude from notifications
      if (!noticeData.authorId) {
        console.log(`[NOTICE WARNING] No author ID found for notice ${noticeId}. Notifications might be sent to the author.`);
      }
      
      // IMPROVED: Add retry logic for failed notification attempts
      let retryCount = 0;
      const maxRetries = 3;
      let notificationResult;
      
      while (retryCount < maxRetries) {
        try {
          notificationResult = await sendNotificationToCommunity(
            noticeData.communityId,
            'Community Notice',
            `${noticeData.authorName || 'Administrator'} posted new community notice: "${noticeData.title || 'Community Announcement'}"\n\n${noticeData.content?.substring(0, 100) || 'No additional details provided.'}${noticeData.content?.length > 100 ? '...' : ''}`,
            {
              type: 'communityNotices',
              noticeId,
              communityId: noticeData.communityId,
              authorId: noticeData.authorId, // Include authorId in data for additional filtering
              authorIsAdmin: authorIsAdmin ? 'true' : 'false', // Add admin status flag
            },
            noticeData.authorId // Exclude the author
          );
          
          // If successful or partially successful, break out of retry loop
          if (notificationResult.success || notificationResult.sentCount > 0) {
            break;
          }
          
          retryCount++;
          console.log(`[NOTICE RETRY] Attempt ${retryCount}/${maxRetries} failed, retrying in 3 seconds...`);
          await new Promise(resolve => setTimeout(resolve, 3000)); // Wait 3 seconds before retry
        } catch (retryError) {
          console.error(`[NOTICE ERROR] Retry ${retryCount + 1} failed with error:`, retryError);
          retryCount++;
          await new Promise(resolve => setTimeout(resolve, 3000)); // Wait 3 seconds before retry
        }
      }
      
      // Log outcome of notification attempt after retries
      if (retryCount === maxRetries) {
        console.error(`[NOTICE ERROR] Failed to send notification for notice ${noticeId} after ${maxRetries} attempts`);
        // Record the failure for later analysis
        await firestore.collection('failed_notifications').add({
          noticeId,
          communityId: noticeData.communityId,
          authorId: noticeData.authorId,
          title: noticeData.title,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          error: 'Maximum retry attempts reached',
          noticeTimestamp: createdAt
        });
      } else if (notificationResult && notificationResult.sentCount > 0) {
        console.log(`[NOTICE SUCCESS] Notification sent for notice ${noticeId} to ${notificationResult.sentCount} users after ${retryCount} retries`);
      }
      
    } catch (error) {
      console.error('Error processing new community notice:', error);
      // Record the error for debugging
      try {
        const firestore = getFirestore();
        await firestore.collection('notification_errors').add({
          type: 'communityNotice',
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          error: error.message,
          stack: error.stack
        });
      } catch (logError) {
        console.error('Failed to log error:', logError);
      }
    }
  });
};

// Monitor for new comments on community notices
const monitorCommunityNoticeComments = () => {
  const db = getDatabase();

  console.log('Starting monitoring for new comments on community notices...');

  // Listen for new comments
  db.ref('/community_notices').on('child_changed', async (snapshot) => {
    try {
      const noticeData = snapshot.val();
      const noticeId = snapshot.key;

      if (!noticeData || !noticeData.comments) {
        return;
      }

      // Get the latest comment
      const commentsArray = Object.entries(noticeData.comments || {}).map(([id, data]) => ({
        id,
        ...data,
        createdAt: data.createdAt || 0
      }));

      // Sort by createdAt (newest first)
      commentsArray.sort((a, b) => b.createdAt - a.createdAt);

      if (commentsArray.length === 0) {
        return;
      }

      const latestComment = commentsArray[0];
      
      // DEBUG LOGGING: Log the entire comment object to diagnose issues
      console.log(`[COMMENT DEBUG] Latest comment on notice ${noticeId}:`, JSON.stringify(latestComment));

      // Check if the comment was just added (within the last 10 seconds)
      const now = Date.now();
      if (now - latestComment.createdAt > 10000) {
        return;
      }

      console.log(`New comment detected on notice ${noticeId}`);

      // Don't send notification if the comment author is the same as the notice author
      if (latestComment.authorId === noticeData.authorId) {
        return;
      }

      // Send notification to the notice author
      const { sendNotificationToUser } = require('./notifications');

      // Make sure text exists and is a string before using substring
      let commentText = latestComment.text || '';
      
      // Handle the case where text might be in a different property
      if (!commentText && latestComment.content) {
        commentText = latestComment.content;
        console.log(`[COMMENT DEBUG] Using 'content' property instead of 'text' for comment ${latestComment.id}`);
      }
      
      // Check if comment text is empty
      if (!commentText || commentText.trim() === '') {
        console.log(`[COMMENT DEBUG] WARNING: Empty comment text for comment ${latestComment.id}`);
        commentText = "(No comment text)";
      }
      
      // Ensure string type
      commentText = String(commentText);
      
      // Truncate long comments
      const truncatedText = `"${commentText.substring(0, 50)}${commentText.length > 50 ? '...' : ''}"`;
      
      console.log(`[COMMENT DEBUG] Sending notification with comment text: ${truncatedText}`);

      await sendNotificationToUser(
        noticeData.authorId,
        'New Comment on Your Notice',
        `${latestComment.authorName || 'Someone'} commented: ${truncatedText}`,
        {
          type: 'socialInteractions',
          noticeId,
          commentId: latestComment.id,
          communityId: noticeData.communityId,
          authorId: latestComment.authorId,
          commentText: commentText.substring(0, 100) // Include comment text in the data payload
        }
      );
    } catch (error) {
      console.error('Error processing new comment:', error);
    }
  });
};

// Monitor for new likes on community notices
const monitorCommunityNoticeLikes = () => {
  const db = getDatabase();
  const firestore = getFirestore();

  console.log('Starting monitoring for new likes on community notices...');

  // Listen for changes to notices (likes are added as properties)
  db.ref('/community_notices').on('child_changed', async (snapshot) => {
    try {
      const noticeData = snapshot.val();
      const noticeId = snapshot.key;

      if (!noticeData || !noticeData.likes) {
        return;
      }

      // Get all likes
      const likes = noticeData.likes || {};
      
      // Find likes added in the last 10 seconds
      const now = Date.now();
      const recentLikes = Object.entries(likes)
        .filter(([_, likeData]) => {
          const createdAt = likeData.createdAt || 0;
          return (now - createdAt) < 10000; // 10 seconds
        })
        .map(([userId, _]) => userId);

      if (recentLikes.length === 0) {
        return;
      }

      console.log(`[NOTICE_LIKE DEBUG] Recent likes detected on notice ${noticeId}: ${recentLikes.join(', ')}`);
      console.log(`[NOTICE_LIKE DEBUG] Notice author: ${noticeData.authorId || 'unknown'}`);

      // Check if any of the likers or the author is an admin (for debugging)
      // Define authorIsAdmin and likerIsAdmin variables at a wider scope
      let authorIsAdmin = false;
      let likerIsAdmin = false;
      
      try {
        const authorDocRef = await firestore.collection('users').doc(noticeData.authorId).get();
        authorIsAdmin = authorDocRef.exists && (authorDocRef.data().isAdmin || authorDocRef.data().role === 'admin');
        
        if (authorIsAdmin) {
          console.log(`[NOTICE_LIKE DEBUG] Notice author ${noticeData.authorId} is an admin`);
        }
        
        // We'll set likerIsAdmin for the current liker inside the loop below
      } catch (error) {
        console.error(`[NOTICE_LIKE ERROR] Error checking author admin status: ${error.message}`);
      }

      // Process each recent like
      for (const likerId of recentLikes) {
        // Double check to avoid self-notifications
        // Don't send notification if the liker is the same as the notice author
        if (likerId === noticeData.authorId) {
          console.log(`[NOTICE_LIKE DEBUG] Skipping notification as user ${likerId} liked their own notice`);
          continue;
        }

        console.log(`New like detected on notice ${noticeId} by user ${likerId}`);

        // Check if this specific liker is an admin
        try {
          const likerDocRef = await firestore.collection('users').doc(likerId).get();
          likerIsAdmin = likerDocRef.exists && (likerDocRef.data().isAdmin || likerDocRef.data().role === 'admin');
          
          if (likerIsAdmin) {
            console.log(`[NOTICE_LIKE DEBUG] Liker ${likerId} is an admin`);
          }
        } catch (error) {
          console.error(`[NOTICE_LIKE ERROR] Error checking liker admin status: ${error.message}`);
          likerIsAdmin = false; // Reset in case of error
        }
        
        // Get liker's name with enhanced retrieval - check multiple data sources
        let displayName = 'Someone';
        
        try {
          // First try Realtime Database
          const likerSnapshot = await db.ref(`/users/${likerId}`).once('value');
          const likerData = likerSnapshot.val();
          
          if (likerData) {
            console.log(`[NOTICE_LIKE DEBUG] Found user in RTDB: ${likerId}`);
            displayName = likerData.fullName || likerData.displayName || likerData.username || displayName;
          } else {
            console.log(`[NOTICE_LIKE DEBUG] User not found in RTDB: ${likerId}`);
          }
          
          // If we still don't have a name, check Firestore
          if (displayName === 'Someone') {
            const userDocRef = await firestore.collection('users').doc(likerId).get();
            if (userDocRef.exists) {
              const userData = userDocRef.data();
              console.log(`[NOTICE_LIKE DEBUG] Found user in Firestore: ${likerId}`);
              displayName = userData.fullName || userData.displayName || userData.username || displayName;
            } else {
              console.log(`[NOTICE_LIKE DEBUG] User not found in Firestore: ${likerId}`);
            }
          }
          
          // Final check in userProfiles collection if it exists
          if (displayName === 'Someone') {
            const profileDocRef = await firestore.collection('userProfiles').doc(likerId).get();
            if (profileDocRef.exists) {
              const profileData = profileDocRef.data();
              console.log(`[NOTICE_LIKE DEBUG] Found user in userProfiles: ${likerId}`);
              displayName = profileData.fullName || profileData.displayName || profileData.name || displayName;
            }
          }
          
          // If we STILL don't have a name, use first part of email or ID
          if (displayName === 'Someone') {
            // Try to get email from auth
            try {
              const userRecord = await admin.auth().getUser(likerId);
              if (userRecord && userRecord.email) {
                displayName = userRecord.email.split('@')[0]; // Use email username
                console.log(`[NOTICE_LIKE DEBUG] Using email from Auth: ${displayName}`);
              } else if (userRecord && userRecord.displayName) {
                displayName = userRecord.displayName;
                console.log(`[NOTICE_LIKE DEBUG] Using displayName from Auth: ${displayName}`);
              }
            } catch (authError) {
              console.log(`[NOTICE_LIKE DEBUG] Auth lookup failed: ${authError.message}`);
              // If everything fails, use shortened user ID instead of the full one
              displayName = likerId.substring(0, 8) + '...';
            }
          }
        } catch (error) {
          console.error(`[NOTICE_LIKE ERROR] Error retrieving user data: ${error.message}`);
          displayName = likerId.substring(0, 8) + '...'; // Shortened ID as fallback
        }
        
        console.log(`[NOTICE_LIKE DEBUG] Final display name for ${likerId}: ${displayName}`);

        // Prepare notice title
        const noticeTitle = noticeData.title || 'your notice';
        
        // Send notification to the notice author with admin flags
        const { sendNotificationToUser } = require('./notifications');
        await sendNotificationToUser(
          noticeData.authorId,
          'New Like on Your Notice',
          `${displayName} liked your notice: "${noticeTitle}"`,
          {
            type: 'socialInteractions',
            noticeId,
            communityId: noticeData.communityId,
            likerId: likerId,             // ID of the person who liked the post (the actor)
            noticeAuthorId: noticeData.authorId, // ID of the post author (recipient)
            noticeTitle: noticeTitle.substring(0, 30), // Include title in payload
            // Add admin flags to help with notification handling
            authorIsAdmin: authorIsAdmin ? 'true' : 'false',
            likerIsAdmin: likerIsAdmin ? 'true' : 'false',
            isUserAdmin: authorIsAdmin ? 'true' : 'false' // Mark if recipient is admin
          }
        );
      }
    } catch (error) {
      console.error('Error processing new like:', error);
    }
  });
};

// Monitor for new marketplace items
const monitorMarketplaceItems = () => {
  const firestore = getFirestore();

  console.log('Starting monitoring for new marketplace items...');

  // Listen for new marketplace items
  // Using only orderBy without where to avoid needing a composite index
  firestore.collection('market_items')
    .orderBy('createdAt', 'desc')
    .limit(10) // Limit to recent items
    .onSnapshot(async (snapshot) => {
      try {
        // Process only added documents
        const addedDocs = snapshot.docChanges()
          .filter(change => change.type === 'added')
          .map(change => ({
            id: change.doc.id,
            ...change.doc.data()
          }));

        if (addedDocs.length === 0) {
          return;
        }

        // Get current time
        const now = Date.now();
        // Only process active items created in the last 5 minutes
        const recentItems = addedDocs.filter(item => {
          // Check if item is active
          if (item.status !== 'active') return false;

          // Check if item has createdAt timestamp
          if (!item.createdAt) return false;

          // Convert Firestore timestamp to milliseconds
          const createdAtMs = item.createdAt.toMillis ?
            item.createdAt.toMillis() :
            (item.createdAt._seconds ? item.createdAt._seconds * 1000 : 0);

          // Check if item was created in the last 5 minutes
          return (now - createdAtMs) < 5 * 60 * 1000;
        });

        if (recentItems.length === 0) {
          return;
        }

        for (const item of recentItems) {
          console.log(`New marketplace item detected: ${item.id}`);

          // Send notification to all users in the community except the seller
          const { sendNotificationToCommunity } = require('./notifications');
          await sendNotificationToCommunity(
            item.communityId,
            'New Item in Marketplace',
            `${item.sellerName} is selling: "${item.title}" for ${item.price}`,
            {
              type: 'marketplace',
              itemId: item.id,
              communityId: item.communityId,
              sellerId: item.sellerId,
            },
            item.sellerId // Exclude the seller
          );
        }
      } catch (error) {
        console.error('Error processing new marketplace items:', error);
      }
    });
};

// Monitor for new chat messages
const monitorChatMessages = () => {
  const db = getDatabase();

  console.log('Starting monitoring for new chat messages...');

  // Listen for new messages in all chats
  db.ref('/chats').on('child_changed', async (snapshot) => {
    try {
      const chatData = snapshot.val();
      const chatId = snapshot.key;

      if (!chatData || !chatData.messages) {
        return;
      }

      // Get all messages
      const messages = chatData.messages || {};
      const messageKeys = Object.keys(messages);

      if (messageKeys.length === 0) {
        return;
      }

      // Get the latest message
      const latestMessageKey = messageKeys[messageKeys.length - 1];
      const latestMessage = messages[latestMessageKey];

      if (!latestMessage || !latestMessage.senderId || !latestMessage.text) {
        return;
      }

      // Check if the message was just added (within the last 10 seconds)
      const now = Date.now();
      if (latestMessage.timestamp && now - latestMessage.timestamp > 10000) {
        return;
      }

      console.log(`New chat message detected in chat ${chatId}`);

      // Determine the recipient
      const recipientId = latestMessage.senderId === chatData.buyerId
        ? chatData.sellerId
        : chatData.buyerId;

      // Get sender's name
      const senderSnapshot = await db.ref(`/users/${latestMessage.senderId}`).once('value');
      const senderData = senderSnapshot.val();
      const senderName = senderData?.fullName || senderData?.username || 'Someone';

      // Get item data if available (for future use)
      // Currently not using item title in the notification, but keeping the code for future enhancement
      // if (chatData.itemId) {
      //   try {
      //     const itemDoc = await getFirestore().collection('market_items').doc(chatData.itemId).get();
      //     if (itemDoc.exists) {
      //       const itemTitle = itemDoc.data().title || 'an item';
      //       // Could use itemTitle in the notification message in the future
      //     }
      //   } catch (error) {
      //     console.error('Error getting item data:', error);
      //   }
      // }

      // Send notification to the recipient
      const { sendNotificationToUser } = require('./notifications');
      await sendNotificationToUser(
        recipientId,
        'New Message',
        `${senderName}: "${latestMessage.text.substring(0, 50)}${latestMessage.text.length > 50 ? '...' : ''}"`,
        {
          type: 'chat',
          chatId,
          messageId: latestMessageKey,
          senderId: latestMessage.senderId,
          itemId: chatData.itemId,
        }
      );
    } catch (error) {
      console.error('Error processing new chat message:', error);
    }
  });
};

// Monitor for report status updates
const monitorReportStatusUpdates = () => {
  const firestore = getFirestore();

  console.log('Starting monitoring for report status updates...');

  // Listen for updates to reports
  firestore.collection('reports')
    .onSnapshot(async (snapshot) => {
      try {
        // Process only modified documents
        const modifiedDocs = snapshot.docChanges()
          .filter(change => change.type === 'modified')
          .map(change => ({
            id: change.doc.id,
            ...change.doc.data(),
            oldData: change.doc.metadata.hasPendingWrites ? null : change.doc.data()
          }));

        if (modifiedDocs.length === 0) {
          return;
        }

        for (const report of modifiedDocs) {
          // Skip if we don't have the old data (local change)
          if (!report.oldData) {
            continue;
          }

          // Check if status has changed
          if (report.status === report.oldData.status) {
            continue;
          }

          console.log(`Report status update detected for report ${report.id}: ${report.oldData.status} -> ${report.status}`);

          // Send notification to the report creator
          const { sendNotificationToUser } = require('./notifications');
          await sendNotificationToUser(
            report.userId,
            'Report Status Updated',
            `Your report "${report.issueType}" has been updated to: ${report.status.replace('_', ' ')}`,
            {
              type: 'reports',
              reportId: report.id,
              status: report.status,
            }
          );
        }
      } catch (error) {
        console.error('Error processing report status updates:', error);
      }
    });
};

// Monitor for new volunteer posts
const monitorVolunteerPosts = () => {
  const firestore = getFirestore();

  console.log('Starting monitoring for new volunteer posts...');

  // Listen for new volunteer posts
  firestore.collection('volunteer_posts')
    .orderBy('createdAt', 'desc')
    .limit(20) // Limit to recent posts
    .onSnapshot(async (snapshot) => {
      try {
        // Process only added documents
        const addedDocs = snapshot.docChanges()
          .filter(change => change.type === 'added')
          .map(change => ({
            id: change.doc.id,
            ...change.doc.data()
          }));

        if (addedDocs.length === 0) {
          return;
        }

        // Get current time
        const now = Date.now();
        // Only process active posts created in the last 5 minutes
        const recentPosts = addedDocs.filter(post => {
          // Check if post has createdAt timestamp
          if (!post.createdAt) return false;

          // Convert Firestore timestamp to milliseconds
          const createdAtMs = post.createdAt.toMillis ?
            post.createdAt.toMillis() :
            (post.createdAt._seconds ? post.createdAt._seconds * 1000 : 0);

          // Check if post was created in the last 5 minutes
          if ((now - createdAtMs) >= 5 * 60 * 1000) return false;

          // Check if the event date is in the future
          if (post.eventDate) {
            const eventDateMs = post.eventDate.toMillis ?
              post.eventDate.toMillis() :
              (post.eventDate._seconds ? post.eventDate._seconds * 1000 : 0);

            // Skip events that have already passed
            if (eventDateMs < now) return false;
          }

          return true;
        });

        if (recentPosts.length === 0) {
          return;
        }

        for (const post of recentPosts) {
          console.log(`New volunteer post detected: ${post.id}`);

          // Send notification to all users in the community except the creator
          const { sendNotificationToCommunity } = require('./notifications');
          await sendNotificationToCommunity(
            post.communityId,
            'New Volunteer Opportunity',
            `${post.userName || post.adminName || 'Someone'} posted: "${post.title}"`,
            {
              type: 'volunteer',
              volunteerId: post.id, // Use volunteerId to match what the app expects
              postId: post.id,      // Keep postId for backward compatibility
              communityId: post.communityId,
              userId: post.userId,
            },
            post.userId // Exclude the creator
          );
        }
      } catch (error) {
        console.error('Error processing new volunteer posts:', error);
      }
    });
};

// Monitor for users joining volunteer posts
const monitorVolunteerPostJoins = () => {
  const firestore = getFirestore();

  console.log('Starting monitoring for users joining volunteer posts...');

  // Listen for updates to volunteer posts
  firestore.collection('volunteer_posts')
    .onSnapshot(async (snapshot) => {
      try {
        // Process only modified documents
        const modifiedDocs = snapshot.docChanges()
          .filter(change => change.type === 'modified')
          .map(change => ({
            id: change.doc.id,
            ...change.doc.data(),
            oldData: change.doc.metadata.hasPendingWrites ? null : change.doc.data()
          }));

        if (modifiedDocs.length === 0) {
          return;
        }

        for (const post of modifiedDocs) {
          // Skip if we don't have the old data (local change)
          if (!post.oldData) {
            continue;
          }

          // Check if joinedUsers has changed
          if (!post.joinedUsers || !post.oldData.joinedUsers ||
              post.joinedUsers.length === post.oldData.joinedUsers.length) {
            continue;
          }

          // Find the new users who joined
          const newUsers = post.joinedUsers.filter(userId =>
            !post.oldData.joinedUsers.includes(userId)
          );

          if (newUsers.length === 0) {
            continue;
          }

          console.log(`New users joined volunteer post ${post.id}: ${newUsers.join(', ')}`);

          // For each new user, send notification to the post creator
          for (const newUserId of newUsers) {
            // Get new user's name
            const userDoc = await firestore.collection('users').doc(newUserId).get();
            const userData = userDoc.exists ? userDoc.data() : null;
            const userName = userData?.fullName || userData?.username || 'Someone';

            // Send notification to the post creator
            const { sendNotificationToUser } = require('./notifications');
            await sendNotificationToUser(
              post.userId,
              'New Volunteer Joined',
              `${userName} joined your volunteer post: "${post.title}"`,
              {
                type: 'volunteer',
                volunteerId: post.id, // Use volunteerId to match what the app expects
                postId: post.id,      // Keep postId for backward compatibility
                communityId: post.communityId,
                joinerId: newUserId,
              }
            );
          }
        }
      } catch (error) {
        console.error('Error processing volunteer post joins:', error);
      }
    });
};

// Monitor for likes on comments
const monitorCommentLikes = () => {
  const db = getDatabase();
  const firestore = getFirestore();

  console.log('Starting monitoring for likes on comments...');

  // Listen for changes to notices that have comments with likes
  db.ref('/community_notices').on('child_changed', async (snapshot) => {
    try {
      const noticeData = snapshot.val();
      const noticeId = snapshot.key;

      if (!noticeData || !noticeData.comments) {
        return;
      }

      // Get all comments
      const comments = noticeData.comments || {};
      
      // Convert to array for easier processing
      const commentsArray = Object.entries(comments).map(([commentId, commentData]) => ({
        id: commentId,
        ...commentData
      }));
      
      // Process each comment to check for new likes
      for (const comment of commentsArray) {
        // Skip comments with no likes
        if (!comment.likes) {
          continue;
        }
        
        // Find likes added in the last 10 seconds
        const now = Date.now();
        const recentLikes = Object.entries(comment.likes)
          .filter(([_, likeData]) => {
            const createdAt = likeData.createdAt || 0;
            return (now - createdAt) < 10000; // 10 seconds
          })
          .map(([userId, _]) => userId);
          
        if (recentLikes.length === 0) {
          continue;
        }
        
        console.log(`[COMMENT_LIKE DEBUG] Recent likes detected on comment ${comment.id} in notice ${noticeId}: ${recentLikes.join(', ')}`);
        
        // Enhanced check: Don't send notifications to authors of their own content
        // Check if the comment author is also the notice author
        const isCommentFromNoticeAuthor = comment.authorId === noticeData.authorId;
        if (isCommentFromNoticeAuthor) {
          console.log(`[COMMENT_LIKE DEBUG] Comment ${comment.id} is from the notice author: ${comment.authorId}`);
        }
        
        // Process each like separately
        for (const likerId of recentLikes) {
          // Don't send notification if the comment author and like author are the same
          if (likerId === comment.authorId) {
            console.log(`[COMMENT_LIKE DEBUG] Skipping notification as user ${likerId} liked their own comment`);
            continue;
          }
          
          // FIX: The post author SHOULD receive notifications when people like their comments
          // The only time we want to skip notification is if the post author and comment author are the same
          // AND the liker is different (which is handled by the previous condition)
          
          // Log action for debugging
          if (likerId === noticeData.authorId) {
            console.log(`[COMMENT_LIKE DEBUG] Post author ${likerId} liked a comment from user ${comment.authorId}`);
          }
          
          // Check if either user is an admin and log for debugging purposes
          let likerIsAdmin = false;
          let commentAuthorIsAdmin = false;
          let noticeAuthorIsAdmin = false;
          
          try {
            const [likerDoc, commentAuthorDoc, noticeAuthorDoc] = await Promise.all([
              firestore.collection('users').doc(likerId).get(),
              firestore.collection('users').doc(comment.authorId).get(),
              firestore.collection('users').doc(noticeData.authorId).get()
            ]);
            
            likerIsAdmin = likerDoc.exists && (likerDoc.data().isAdmin || likerDoc.data().role === 'admin');
            commentAuthorIsAdmin = commentAuthorDoc.exists && (commentAuthorDoc.data().isAdmin || commentAuthorDoc.data().role === 'admin');
            noticeAuthorIsAdmin = noticeAuthorDoc.exists && (noticeAuthorDoc.data().isAdmin || noticeAuthorDoc.data().role === 'admin');
            
            if (likerIsAdmin) {
              console.log(`[COMMENT_LIKE DEBUG] Liker ${likerId} is an admin`);
            }
            
            if (commentAuthorIsAdmin) {
              console.log(`[COMMENT_LIKE DEBUG] Comment author ${comment.authorId} is an admin`);
            }
            
            if (noticeAuthorIsAdmin) {
              console.log(`[COMMENT_LIKE DEBUG] Notice author ${noticeData.authorId} is an admin`);
            }
          } catch (error) {
            console.error(`[COMMENT_LIKE ERROR] Error checking admin status: ${error.message}`);
          }
          
          // Get liker's name with enhanced retrieval - check multiple data sources
          let displayName = 'Someone';
          
          try {
            // First try Realtime Database
            const likerSnapshot = await db.ref(`/users/${likerId}`).once('value');
            const likerData = likerSnapshot.val();
            
            if (likerData) {
              console.log(`[COMMENT_LIKE DEBUG] Found user in RTDB: ${likerId}`);
              displayName = likerData.fullName || likerData.displayName || likerData.username || displayName;
            } else {
              console.log(`[COMMENT_LIKE DEBUG] User not found in RTDB: ${likerId}`);
            }
            
            // If we still don't have a name, check Firestore
            if (displayName === 'Someone') {
              const userDocRef = await firestore.collection('users').doc(likerId).get();
              if (userDocRef.exists) {
                const userData = userDocRef.data();
                console.log(`[COMMENT_LIKE DEBUG] Found user in Firestore: ${likerId}`);
                displayName = userData.fullName || userData.displayName || userData.username || displayName;
              } else {
                console.log(`[COMMENT_LIKE DEBUG] User not found in Firestore: ${likerId}`);
              }
            }
            
            // Final check in userProfiles collection if it exists
            if (displayName === 'Someone') {
              const profileDocRef = await firestore.collection('userProfiles').doc(likerId).get();
              if (profileDocRef.exists) {
                const profileData = profileDocRef.data();
                console.log(`[COMMENT_LIKE DEBUG] Found user in userProfiles: ${likerId}`);
                displayName = profileData.fullName || profileData.displayName || profileData.name || displayName;
              }
            }
            
            // If we STILL don't have a name, use first part of email or ID
            if (displayName === 'Someone') {
              // Try to get email from auth
              try {
                const userRecord = await admin.auth().getUser(likerId);
                if (userRecord && userRecord.email) {
                  displayName = userRecord.email.split('@')[0]; // Use email username
                  console.log(`[COMMENT_LIKE DEBUG] Using email from Auth: ${displayName}`);
                } else if (userRecord && userRecord.displayName) {
                  displayName = userRecord.displayName;
                  console.log(`[COMMENT_LIKE DEBUG] Using displayName from Auth: ${displayName}`);
                }
              } catch (authError) {
                console.log(`[COMMENT_LIKE DEBUG] Auth lookup failed: ${authError.message}`);
                // If everything fails, use shortened user ID instead of the full one
                displayName = likerId.substring(0, 8) + '...';
              }
            }
          } catch (error) {
            console.error(`[COMMENT_LIKE ERROR] Error retrieving user data: ${error.message}`);
            displayName = likerId.substring(0, 8) + '...'; // Shortened ID as fallback
          }
          
          console.log(`[COMMENT_LIKE DEBUG] Final display name for ${likerId}: ${displayName}`);
          
          // Get comment text for the notification
          let commentText = comment.text || comment.content || '';
          if (commentText.length > 30) {
            commentText = commentText.substring(0, 30) + '...';
          }
          
          // If comment text is empty or undefined, use a default message
          if (!commentText || commentText.trim() === '') {
            commentText = '(No comment text)';
          }
          
          console.log(`[COMMENT_LIKE DEBUG] Sending notification to ${comment.authorId} about like from ${displayName} on comment: "${commentText}"`);
          
          // Send notification to the comment author with enhanced data
          const { sendNotificationToUser } = require('./notifications');
          await sendNotificationToUser(
            comment.authorId,
            'New Like on Your Comment',
            `${displayName} liked your comment: "${commentText}"`,
            {
              type: 'socialInteractions',
              noticeId,
              commentId: comment.id,
              communityId: noticeData.communityId,
              likerId: likerId,
              commentText: commentText,
              // Include author IDs to help with filtering
              commentAuthorId: comment.authorId,
              noticeAuthorId: noticeData.authorId,
              // Add admin status information
              likerIsAdmin: likerIsAdmin ? 'true' : 'false',
              commentAuthorIsAdmin: commentAuthorIsAdmin ? 'true' : 'false',
              noticeAuthorIsAdmin: noticeAuthorIsAdmin ? 'true' : 'false',
              isUserAdmin: commentAuthorIsAdmin ? 'true' : 'false' // Flag if recipient is admin
            }
          );
        }
      }
    } catch (error) {
      console.error('[COMMENT_LIKE ERROR] Error processing comment likes:', error);
    }
  });
};

// Monitor for comment replies
const monitorCommentReplies = () => {
  const db = getDatabase();
  const firestore = getFirestore();

  console.log('Starting monitoring for comment replies...');

  // Listen for changes in community notices that might contain new replies
  db.ref('/community_notices').on('child_changed', async (snapshot) => {
    try {
      const noticeData = snapshot.val();
      const noticeId = snapshot.key;

      if (!noticeData || !noticeData.comments) {
        return;
      }

      // Process each comment to check for replies
      const commentsObj = noticeData.comments || {};
      
      for (const commentId in commentsObj) {
        const comment = commentsObj[commentId];
        
        // Skip if no replies
        if (!comment.replies) {
          continue;
        }
        
        // Convert replies object to array with IDs
        const repliesObj = comment.replies || {};
        const repliesArray = Object.entries(repliesObj).map(([replyId, data]) => ({
          id: replyId,
          ...data,
          createdAt: data.createdAt || 0
        }));
        
        // Skip if no replies
        if (repliesArray.length === 0) {
          continue;
        }
        
        // Sort by createdAt (newest first)
        repliesArray.sort((a, b) => b.createdAt - a.createdAt);
        
        // Get the latest reply
        const latestReply = repliesArray[0];
        
        // Check if the reply was just added (within the last 10 seconds)
        const now = Date.now();
        if (now - latestReply.createdAt > 10000) {
          continue;
        }
        
        console.log(`[REPLY DEBUG] Latest reply on comment ${commentId} in notice ${noticeId}:`, JSON.stringify(latestReply));
        
        // Don't send notification if the reply author is the same as the comment author
        if (latestReply.authorId === comment.authorId) {
          console.log(`[REPLY DEBUG] Skipping notification as reply author ${latestReply.authorId} is the same as comment author`);
          continue;
        }
        
        // Get commenter's name for the notification
        let replyAuthorName = 'Someone';
        
        try {
          // Try multiple sources to get the reply author's name
          // First try Realtime Database
          const authorSnapshot = await db.ref(`/users/${latestReply.authorId}`).once('value');
          const authorData = authorSnapshot.val();
          
          if (authorData) {
            replyAuthorName = authorData.fullName || authorData.displayName || authorData.username || replyAuthorName;
          } else {
            // If not in RTDB, check Firestore
            const userDocRef = await firestore.collection('users').doc(latestReply.authorId).get();
            if (userDocRef.exists) {
              const userData = userDocRef.data();
              replyAuthorName = userData.fullName || userData.displayName || userData.username || replyAuthorName;
            } else {
              // Final check in userProfiles collection
              const profileDocRef = await firestore.collection('userProfiles').doc(latestReply.authorId).get();
              if (profileDocRef.exists) {
                const profileData = profileDocRef.data();
                replyAuthorName = profileData.fullName || profileData.displayName || profileData.name || replyAuthorName;
              }
            }
          }
        } catch (error) {
          console.error(`[REPLY ERROR] Error retrieving reply author data: ${error.message}`);
        }
        
        // Format the reply content for notification
        let replyContent = latestReply.content || '';
        if (typeof replyContent !== 'string') {
          replyContent = String(replyContent || '');
        }
        
        if (replyContent.length > 50) {
          replyContent = replyContent.substring(0, 50) + '...';
        }
        
        if (!replyContent || replyContent.trim() === '') {
          replyContent = '(No reply text)';
        }
        
        console.log(`[REPLY DEBUG] Sending notification to ${comment.authorId} about reply from ${replyAuthorName}: "${replyContent}"`);
        
        // Send notification to the comment author
        const { sendNotificationToUser } = require('./notifications');
        await sendNotificationToUser(
          comment.authorId,
          'New Reply to Your Comment',
          `${replyAuthorName} replied to your comment: "${replyContent}"`,
          {
            type: 'socialInteractions',
            noticeId,
            commentId,
            replyId: latestReply.id,
            communityId: noticeData.communityId,
            authorId: latestReply.authorId,
            replyText: replyContent,
            parentCommentId: commentId,
            parentCommentAuthorId: comment.authorId
          }
        );
        
        // Check if this is a reply to a specific user (mentioned with @username)
        // This handles the case where someone replies to a comment and mentions another user
        const content = latestReply.content || '';
        const mentionMatch = content.match(/@([a-zA-Z0-9_\s]+)/);
        
        if (mentionMatch && mentionMatch[1]) {
          const mentionedUsername = mentionMatch[1].trim();
          console.log(`[REPLY DEBUG] Username mention detected: ${mentionedUsername}`);
          
          // Look up the user ID by their username/name
          try {
            // Search for mentioned user in Firestore by displayName or username
            const usersSnapshot = await firestore.collection('users')
              .where('displayName', '==', mentionedUsername)
              .limit(1)
              .get();
            
            if (!usersSnapshot.empty) {
              const mentionedUserDoc = usersSnapshot.docs[0];
              const mentionedUserId = mentionedUserDoc.id;
              
              // Don't send duplicate notification if mentioned user is the comment author
              if (mentionedUserId !== comment.authorId && mentionedUserId !== latestReply.authorId) {
                console.log(`[REPLY DEBUG] Sending mention notification to user ${mentionedUserId}`);
                
                // Send notification to the mentioned user
                await sendNotificationToUser(
                  mentionedUserId,
                  'You Were Mentioned in a Reply',
                  `${replyAuthorName} mentioned you in a reply: "${replyContent}"`,
                  {
                    type: 'socialInteractions',
                    noticeId,
                    commentId,
                    replyId: latestReply.id,
                    communityId: noticeData.communityId,
                    authorId: latestReply.authorId,
                    replyText: replyContent,
                    mentioned: true,
                    mentionedUserId: mentionedUserId
                  }
                );
              }
            }
          } catch (error) {
            console.error(`[REPLY ERROR] Error processing user mention: ${error.message}`);
          }
        }
      }
    } catch (error) {
      console.error('[REPLY ERROR] Error processing comment replies:', error);
      
      // Record the error for debugging
      try {
        await firestore.collection('notification_errors').add({
          type: 'commentReply',
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          error: error.message,
          stack: error.stack
        });
      } catch (logError) {
        console.error('Failed to log error:', logError);
      }
    }
  });
};

// Start all monitoring functions
const startAllMonitoring = () => {
  try {
    monitorCommunityNotices();
    monitorCommunityNoticeComments();
    monitorCommunityNoticeLikes();
    monitorMarketplaceItems();
    monitorChatMessages();
    monitorReportStatusUpdates();
    monitorVolunteerPosts();
    monitorVolunteerPostJoins();
    monitorCommentLikes();
    monitorCommentReplies();

    console.log('All monitoring services started successfully');
  } catch (error) {
    console.error('Error starting monitoring services:', error);
    console.error('Server will continue running, but some notifications may not work');
  }
};

module.exports = {
  monitorCommunityNotices,
  monitorCommunityNoticeComments,
  monitorCommunityNoticeLikes,
  monitorMarketplaceItems,
  monitorChatMessages,
  monitorReportStatusUpdates,
  monitorVolunteerPosts,
  monitorVolunteerPostJoins,
  monitorCommentLikes,
  monitorCommentReplies,
  startAllMonitoring
};
