const express = require('express');
const admin = require('firebase-admin');
const services = require('../services');
const { getFirestore } = services.firebase;

const router = express.Router();

// Register a new FCM token
router.post('/register', async (req, res) => {
  try {
    const { userId, token, platform } = req.body;

    // Validate required fields
    if (!userId || !token || !platform) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: userId, token, platform'
      });
    }

    const db = getFirestore();

    // Get current timestamp
    const now = admin.firestore.Timestamp.now();

    // Create token data
    const tokenData = {
      token,
      platform,
      createdAt: now,
      lastActive: now,
    };

    // Get existing tokens
    const userTokenDoc = await db.collection('user_tokens').doc(userId).get();

    if (userTokenDoc.exists) {
      // Get existing tokens
      const userData = userTokenDoc.data();
      const tokens = userData.tokens || [];

      // Check if token already exists
      const tokenExists = tokens.some(t => t.token === token);

      if (tokenExists) {
        // Update existing token's lastActive timestamp
        const updatedTokens = tokens.map(t => {
          if (t.token === token) {
            return { ...t, lastActive: now };
          }
          return t;
        });

        // Update document
        await db.collection('user_tokens').doc(userId).update({
          tokens: updatedTokens,
          lastActive: admin.firestore.FieldValue.serverTimestamp(),
        });

        return res.status(200).json({
          success: true,
          message: 'Token updated successfully'
        });
      } else {
        // Add new token to array
        tokens.push(tokenData);

        // Update document
        await db.collection('user_tokens').doc(userId).update({
          tokens: tokens,
          lastActive: admin.firestore.FieldValue.serverTimestamp(),
        });

        return res.status(200).json({
          success: true,
          message: 'Token added successfully'
        });
      }
    } else {
      // Create new token document
      await db.collection('user_tokens').doc(userId).set({
        tokens: [tokenData],
        notificationPreferences: {
          communityNotices: true,
          socialInteractions: true,
          marketplace: true,
          chat: true,
          reports: true,
          volunteer: true,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastActive: admin.firestore.FieldValue.serverTimestamp(),
      });

      return res.status(201).json({
        success: true,
        message: 'Token document created successfully'
      });
    }
  } catch (error) {
    console.error('Error registering token:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Update notification preferences
router.post('/preferences', async (req, res) => {
  try {
    const { userId, preferences } = req.body;

    // Validate required fields
    if (!userId || !preferences) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: userId, preferences'
      });
    }

    const db = getFirestore();

    // Get user token document
    const userTokenDoc = await db.collection('user_tokens').doc(userId).get();

    if (!userTokenDoc.exists) {
      return res.status(404).json({
        success: false,
        error: 'User token document not found'
      });
    }

    // Update preferences
    await db.collection('user_tokens').doc(userId).update({
      notificationPreferences: preferences,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(200).json({
      success: true,
      message: 'Notification preferences updated successfully'
    });
  } catch (error) {
    console.error('Error updating notification preferences:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
