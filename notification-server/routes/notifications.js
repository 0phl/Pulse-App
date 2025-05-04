const express = require('express');
const services = require('../services');
const {
  sendNotificationToUser,
  sendNotificationToCommunity,
  markAllNotificationsAsRead,
  cleanupReadNotifications
} = services.notifications;

const router = express.Router();

// Send a notification to a specific user
router.post('/send', async (req, res) => {
  try {
    const { userId, title, body, data } = req.body;

    // Validate required fields
    if (!userId || !title || !body) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: userId, title, body'
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

// Send a notification to all users in a community
router.post('/send-community', async (req, res) => {
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

// Send a test notification
router.post('/test', async (req, res) => {
  try {
    const { userId } = req.body;

    // Validate required fields
    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'Missing required field: userId'
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

// Mark all notifications as read for a user
router.post('/mark-all-read', async (req, res) => {
  try {
    const { userId } = req.body;

    // Validate required fields
    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'Missing required field: userId'
      });
    }

    // Mark all notifications as read
    const result = await markAllNotificationsAsRead(userId);

    return res.status(200).json({
      success: true,
      message: `Marked all notifications as read for user ${userId}`,
      ...result
    });
  } catch (error) {
    console.error('Error marking all notifications as read:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Cleanup read notifications to save storage
router.post('/cleanup', async (_, res) => {
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
