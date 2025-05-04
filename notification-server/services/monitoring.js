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

      // Check if notice was created recently (within the last 30 seconds)
      // Reduced from 5 minutes to 30 seconds to minimize delay
      const now = Date.now();
      const createdAt = noticeData.createdAt || 0;

      if (now - createdAt > 30 * 1000) {
        // Skip notices older than 30 seconds
        console.log(`Skipping notice ${noticeId} - too old (${Math.floor((now - createdAt)/1000)} seconds)`);
        return;
      }

      console.log(`New community notice detected: ${noticeId}`);

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
      await sendNotificationToCommunity(
        noticeData.communityId,
        noticeData.title || 'New Community Notice',
        noticeData.content?.substring(0, 100) || 'A new notice has been posted in your community.',
        {
          type: 'communityNotices',
          noticeId,
          communityId: noticeData.communityId,
          authorId: noticeData.authorId,
        },
        noticeData.authorId // Exclude the author
      );
    } catch (error) {
      console.error('Error processing new community notice:', error);
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
      const commentText = latestComment.text || '';
      const truncatedText = typeof commentText === 'string' ?
        `"${commentText.substring(0, 50)}${commentText.length > 50 ? '...' : ''}"` :
        '(No text)';

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
      const likeKeys = Object.keys(likes);

      if (likeKeys.length === 0) {
        return;
      }

      // Get the latest like (this is a simplification - in reality, we'd need to track which likes are new)
      // For a production system, you might want to store a timestamp with each like
      const latestLikerId = likeKeys[likeKeys.length - 1];

      // Don't send notification if the liker is the same as the notice author
      if (latestLikerId === noticeData.authorId) {
        return;
      }

      console.log(`New like detected on notice ${noticeId} by user ${latestLikerId}`);

      // Get liker's name
      const likerSnapshot = await db.ref(`/users/${latestLikerId}`).once('value');
      const likerData = likerSnapshot.val();
      const likerName = likerData?.fullName || likerData?.username || 'Someone';

      // Send notification to the notice author
      const { sendNotificationToUser } = require('./notifications');
      await sendNotificationToUser(
        noticeData.authorId,
        'New Like on Your Notice',
        `${likerName} liked your notice: "${noticeData.title}"`,
        {
          type: 'socialInteractions',
          noticeId,
          communityId: noticeData.communityId,
          likerId: latestLikerId,
        }
      );
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
  startAllMonitoring
};
