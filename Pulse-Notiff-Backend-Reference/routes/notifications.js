const express = require('express');
const services = require('../services');
const {
  sendNotificationToUser,
  sendNotificationToCommunity,
  getUserNotifications,
  markNotificationAsRead,
  markAllNotificationsAsRead,
  cleanupReadNotifications
} = services.notifications;
const { getFirestore, getMessaging } = services.firebase;

// Import auth middleware
const { verifyToken, authorizeUser, requireAdmin } = require('../middleware/auth');

const router = express.Router();

// Secure routes with auth middleware
// Get notifications for the authenticated user
router.get('/user/:userId', verifyToken, authorizeUser, async (req, res) => {
  try {
    const userId = req.params.userId;
    const limit = parseInt(req.query.limit) || 20;
    const offset = parseInt(req.query.offset) || 0;
    
    console.log(`[SECURE] Getting notifications for authenticated user ${userId}`);
    
    const result = await getUserNotifications(userId, limit, offset);
    
    if (result.success) {
      return res.status(200).json(result);
    } else {
      return res.status(400).json(result);
    }
  } catch (error) {
    console.error('[SECURE] Error getting user notifications:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Mark a notification as read (requires authentication)
router.post('/read/:statusId', verifyToken, async (req, res) => {
  try {
    const { statusId } = req.params;
    const authenticatedUserId = req.user.uid;
    
    console.log(`[SECURE] Marking notification ${statusId} as read for user ${authenticatedUserId}`);
    
    // First verify that this notification belongs to the authenticated user
    const db = getFirestore();
    const statusDoc = await db.collection('notification_status').doc(statusId).get();
    
    if (!statusDoc.exists) {
      return res.status(404).json({
        success: false,
        error: 'Notification not found'
      });
    }
    
    const statusData = statusDoc.data();
    
    // Check if the notification belongs to the authenticated user
    if (statusData.userId !== authenticatedUserId && !req.user.isAdmin) {
      console.log(`[SECURE] Authorization failed: User ${authenticatedUserId} attempted to access notification of user ${statusData.userId}`);
      return res.status(403).json({
        success: false,
        error: 'Forbidden - You can only access your own notifications'
      });
    }
    
    // Proceed with marking as read
    const result = await markNotificationAsRead(statusId);
    
    if (result.success) {
      return res.status(200).json(result);
    } else {
      return res.status(400).json(result);
    }
  } catch (error) {
    console.error('[SECURE] Error marking notification as read:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Mark all notifications as read for a user (requires authentication)
router.post('/read-all/:userId', verifyToken, authorizeUser, async (req, res) => {
  try {
    const userId = req.params.userId;
    
    console.log(`[SECURE] Marking all notifications as read for user ${userId}`);
    
    const result = await markAllNotificationsAsRead(userId);
    
    if (result.success) {
      return res.status(200).json(result);
    } else {
      return res.status(400).json(result);
    }
  } catch (error) {
    console.error('[SECURE] Error marking all notifications as read:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Send a notification to a specific user (admin or internal only)
router.post('/send', verifyToken, async (req, res) => {
  try {
    const { userId, title, body, data } = req.body;
    const authenticatedUserId = req.user.uid;
    
    // Validate required fields
    if (!userId || !title || !body) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: userId, title, body'
      });
    }
    
    // Only allow admins to send notifications to other users
    if (userId !== authenticatedUserId && !req.user.isAdmin) {
      console.log(`[SECURE] Authorization failed: User ${authenticatedUserId} attempted to send notification to user ${userId}`);
      return res.status(403).json({
        success: false,
        error: 'Forbidden - You can only send notifications to yourself unless you are an admin'
      });
    }

    // Send notification
    const result = await sendNotificationToUser(userId, title, body, data || {});

    if (result.success) {
      return res.status(200).json(result);
    } else {
      return res.status(400).json(result);
    }
  } catch (error) {
    console.error('Error sending notification:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Send a notification to all users in a community (admin only)
router.post('/send-community', verifyToken, requireAdmin, async (req, res) => {
  try {
    const { communityId, title, body, data, excludeUserId } = req.body;

    // Validate required fields
    if (!communityId || !title || !body) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: communityId, title, body'
      });
    }

    // Send notification
    const result = await sendNotificationToCommunity(
      communityId,
      title,
      body,
      data || {},
      excludeUserId
    );

    if (result.success) {
      return res.status(200).json(result);
    } else {
      return res.status(400).json(result);
    }
  } catch (error) {
    console.error('Error sending community notification:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Send a test notification (protected by authentication)
router.post('/test', verifyToken, async (req, res) => {
  try {
    const { userId } = req.body;
    const authenticatedUserId = req.user.uid;

    // Validate required fields
    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'Missing required field: userId'
      });
    }
    
    // Only allow sending test notifications to yourself unless admin
    if (userId !== authenticatedUserId && !req.user.isAdmin) {
      return res.status(403).json({
        success: false,
        error: 'Forbidden - You can only send test notifications to yourself unless you are an admin'
      });
    }

    // Send test notification
    const result = await sendNotificationToUser(
      userId,
      'Test Notification',
      'This is a test notification from the PULSE notification server',
      { type: 'test', timestamp: new Date().toISOString() }
    );

    if (result.success) {
      return res.status(200).json(result);
    } else {
      return res.status(400).json(result);
    }
  } catch (error) {
    console.error('Error sending test notification:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Diagnostic endpoint to check notification setup (admin only)
router.post('/diagnose', verifyToken, requireAdmin, async (req, res) => {
  try {
    const { userId } = req.body;

    // Validate required fields
    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'Missing required field: userId'
      });
    }

    console.log(`[DIAGNOSTIC] Starting notification diagnostic for user ${userId}`);
    
    const db = getFirestore();
    const messaging = getMessaging();
    
    // Step 1: Check if user exists
    const userDoc = await db.collection('users').doc(userId).get();
    const userExists = userDoc.exists;
    console.log(`[DIAGNOSTIC] User document exists: ${userExists}`);
    
    // Step 2: Check user tokens
    const userTokensDoc = await db.collection('user_tokens').doc(userId).get();
    let tokensInfo = { exists: false, count: 0, tokens: [] };
    
    if (userTokensDoc.exists) {
      const userData = userTokensDoc.data();
      const tokens = userData.tokens || [];
      const validTokens = tokens.filter(tokenData => tokenData.token);
      
      tokensInfo = { 
        exists: true,
        count: validTokens.length,
        tokens: validTokens.map(t => ({
          platform: t.platform,
          tokenPreview: t.token ? `${t.token.substring(0, 15)}...` : 'invalid',
          createdAt: t.createdAt ? t.createdAt.toDate().toISOString() : 'unknown',
          lastActive: t.lastActive ? t.lastActive.toDate().toISOString() : 'unknown'
        })),
        preferences: userData.notificationPreferences || {}
      };
      
      console.log(`[DIAGNOSTIC] User has ${validTokens.length} valid tokens`);
    } else {
      console.log(`[DIAGNOSTIC] No tokens document found for user ${userId}`);
    }
    
    // Step 3: Check recent notifications
    const recentNotifications = [];
    const notificationStatusQuery = await db.collection('notification_status')
      .where('userId', '==', userId)
      .orderBy('createdAt', 'desc')
      .limit(5)
      .get();
    
    for (const doc of notificationStatusQuery.docs) {
      const statusData = doc.data();
      let notificationData = { notFound: true };
      
      // Get the actual notification
      if (statusData.notificationId) {
        try {
          const notificationDoc = await db.collection('user_notifications').doc(statusData.notificationId).get();
          if (notificationDoc.exists) {
            notificationData = notificationDoc.data();
          }
        } catch (e) {
          console.error(`[DIAGNOSTIC] Error fetching notification: ${e.message}`);
        }
      }
      
      recentNotifications.push({
        statusId: doc.id,
        read: statusData.read || false,
        createdAt: statusData.createdAt ? statusData.createdAt.toDate().toISOString() : 'unknown',
        notification: notificationData.notFound ? { notFound: true } : {
          title: notificationData.title,
          body: notificationData.body,
          type: notificationData.type,
          createdAt: notificationData.createdAt ? notificationData.createdAt.toDate().toISOString() : 'unknown'
        }
      });
    }
    
    console.log(`[DIAGNOSTIC] Found ${recentNotifications.length} recent notifications for user ${userId}`);
    
    // Return diagnostic information
    const diagnosticInfo = {
      userId,
      userExists,
      tokens: tokensInfo,
      recentNotifications,
      serverTime: new Date().toISOString(),
      firebase: {
        projectId: process.env.FIREBASE_PROJECT_ID || 'unknown'
      }
    };
    
    return res.status(200).json({
      success: true,
      diagnostic: diagnosticInfo
    });
  } catch (error) {
    console.error('[DIAGNOSTIC ERROR]', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Cleanup read notifications to save storage (admin only)
router.post('/cleanup', verifyToken, requireAdmin, async (_, res) => {
  try {
    // Run the cleanup
    const result = await cleanupReadNotifications();

    return res.status(200).json({
      success: true,
      message: `Cleaned up ${result.count} read notifications`,
      ...result
    });
  } catch (error) {
    console.error('Error cleaning up read notifications:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
