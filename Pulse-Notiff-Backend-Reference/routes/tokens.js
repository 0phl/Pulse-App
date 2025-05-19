const express = require('express');
const admin = require('firebase-admin');
const services = require('../services');
const { getFirestore } = services.firebase;

// Import auth middleware
const { verifyToken, authorizeUser } = require('../middleware/auth');

const router = express.Router();

// Register a new FCM token (requires authentication)
router.post('/register', verifyToken, async (req, res) => {
  try {
    const { userId, token, platform } = req.body;
    const authenticatedUserId = req.user.uid;
    
    console.log(`[TOKEN DEBUG] Received token registration request:`);
    console.log(`[TOKEN DEBUG] User ID: ${userId}`);
    console.log(`[TOKEN DEBUG] Platform: ${platform}`);
    console.log(`[TOKEN DEBUG] Token (truncated): ${token ? token.substring(0, 15) + '...' : 'undefined'}`);
    console.log(`[TOKEN DEBUG] Authenticated User ID: ${authenticatedUserId}`);

    // Validate required fields
    if (!userId || !token || !platform) {
      console.error(`[TOKEN ERROR] Missing required fields: ${!userId ? 'userId' : ''}${!token ? 'token' : ''}${!platform ? 'platform' : ''}`);
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: userId, token, platform'
      });
    }
    
    // Security check: Ensure the authenticated user can only register tokens for themselves
    if (userId !== authenticatedUserId && !req.user.isAdmin) {
      console.error(`[TOKEN ERROR] Security violation: User ${authenticatedUserId} attempted to register token for ${userId}`);
      return res.status(403).json({
        success: false,
        error: 'Forbidden - You can only register tokens for your own account'
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

    // IMPROVED: Check if user was in the missing tokens list and remove them
    try {
      const missingTokenDoc = await db.collection('missing_tokens').doc(userId).get();
      if (missingTokenDoc.exists) {
        console.log(`[TOKEN RECOVERY] User ${userId} was in missing tokens list and is now registering a token`);
        
        // Record the recovery success
        await db.collection('token_recovery_success').add({
          userId,
          recoveredAt: admin.firestore.FieldValue.serverTimestamp(),
          tokenValue: token.substring(0, 15) + '...',
          platform,
          missingTokenData: missingTokenDoc.data()
        });
        
        // Remove from missing tokens list
        await db.collection('missing_tokens').doc(userId).delete();
        console.log(`[TOKEN RECOVERY] Removed user ${userId} from missing tokens list`);
      }
    } catch (recoveryError) {
      console.error(`[TOKEN ERROR] Error checking missing tokens status: ${recoveryError.message}`);
      // Don't fail the main operation if this step fails
    }

    // Get existing tokens
    const userTokenDoc = await db.collection('user_tokens').doc(userId).get();

    if (userTokenDoc.exists) {
      console.log(`[TOKEN DEBUG] Found existing token document for user ${userId}`);
      
      // Get existing tokens
      const userData = userTokenDoc.data();
      const tokens = userData.tokens || [];
      
      console.log(`[TOKEN DEBUG] User has ${tokens.length} existing tokens`);
      
      // IMPROVED: Clean up any logged out or very old tokens
      let cleanupCount = 0;
      const updatedTokens = tokens.filter(t => {
        // Remove explicitly logged out tokens
        if (t.loggedOut === true) {
          cleanupCount++;
          return false;
        }
        
        // Remove tokens older than 90 days without activity
        if (t.lastActive) {
          const lastActiveMs = t.lastActive.toMillis ? 
            t.lastActive.toMillis() : 
            (t.lastActive._seconds ? t.lastActive._seconds * 1000 : 0);
          
          const ninetyDaysMs = 90 * 24 * 60 * 60 * 1000;
          if (Date.now() - lastActiveMs > ninetyDaysMs) {
            console.log(`[TOKEN DEBUG] Removing token inactive for > 90 days: ${t.token?.substring(0, 15) || 'unknown format'}`);
            cleanupCount++;
            return false;
          }
        }
        
        return true;
      });
      
      if (cleanupCount > 0) {
        console.log(`[TOKEN DEBUG] Cleaned up ${cleanupCount} old or logged out tokens`);
      }

      // Check if token already exists
      const tokenExists = updatedTokens.some(t => t.token === token);

      if (tokenExists) {
        console.log(`[TOKEN DEBUG] Token already exists, updating lastActive timestamp`);
        
        // Update existing token's lastActive timestamp and ensure loggedOut is false
        const refreshedTokens = updatedTokens.map(t => {
          if (t.token === token) {
            return { 
              ...t, 
              lastActive: now,
              loggedOut: false,  // Ensure token is marked as active
              // IMPROVED: Record device info
              platform,
              updatedAt: now
            };
          }
          return t;
        });

        // Update document
        await db.collection('user_tokens').doc(userId).update({
          tokens: refreshedTokens,
          lastActive: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        console.log(`[TOKEN DEBUG] Token updated successfully for user ${userId}`);

        return res.status(200).json({
          success: true,
          message: 'Token updated successfully'
        });
      } else {
        console.log(`[TOKEN DEBUG] New token for existing user, adding to tokens array`);
        
        // Limit total number of tokens per user to prevent edge cases
        if (updatedTokens.length >= 10) {
          console.log(`[TOKEN DEBUG] User has reached token limit, removing oldest token`);
          // Find and remove the oldest token by creation date
          let oldestTimestamp = Date.now();
          let oldestIndex = -1;
          
          updatedTokens.forEach((t, index) => {
            if (t.createdAt) {
              const createdAtMs = t.createdAt.toMillis ? 
                t.createdAt.toMillis() : 
                (t.createdAt._seconds ? t.createdAt._seconds * 1000 : 0);
              
              if (createdAtMs < oldestTimestamp) {
                oldestTimestamp = createdAtMs;
                oldestIndex = index;
              }
            }
          });
          
          if (oldestIndex >= 0) {
            console.log(`[TOKEN DEBUG] Removing oldest token from ${new Date(oldestTimestamp).toISOString()}`);
            updatedTokens.splice(oldestIndex, 1);
          } else {
            // If we couldn't determine oldest, remove first token
            updatedTokens.shift();
          }
        }
        
        // Add new token to array
        updatedTokens.push(tokenData);

        // Update document
        await db.collection('user_tokens').doc(userId).update({
          tokens: updatedTokens,
          lastActive: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        console.log(`[TOKEN DEBUG] New token added successfully for user ${userId}, total tokens: ${updatedTokens.length}`);

        return res.status(200).json({
          success: true,
          message: 'Token added successfully'
        });
      }
    } else {
      console.log(`[TOKEN DEBUG] No existing token document found, creating new document for user ${userId}`);
      
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
      
      console.log(`[TOKEN DEBUG] New token document created successfully for user ${userId}`);
      console.log(`[TOKEN DEBUG] Default notification preferences enabled for all notification types`);

      return res.status(201).json({
        success: true,
        message: 'Token document created successfully'
      });
    }
  } catch (error) {
    console.error('[TOKEN ERROR] Error registering token:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Update notification preferences (requires authentication)
router.post('/preferences', verifyToken, async (req, res) => {
  try {
    const { userId, preferences } = req.body;
    const authenticatedUserId = req.user.uid;
    
    console.log(`[TOKEN DEBUG] Received preference update request for user ${userId}`);
    console.log(`[TOKEN DEBUG] Preferences:`, JSON.stringify(preferences));
    console.log(`[TOKEN DEBUG] Authenticated User ID: ${authenticatedUserId}`);

    // Validate required fields
    if (!userId || !preferences) {
      console.error(`[TOKEN ERROR] Missing required fields: ${!userId ? 'userId' : ''}${!preferences ? 'preferences' : ''}`);
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: userId, preferences'
      });
    }
    
    // Security check: Ensure users can only update their own preferences
    if (userId !== authenticatedUserId && !req.user.isAdmin) {
      console.error(`[TOKEN ERROR] Security violation: User ${authenticatedUserId} attempted to update preferences for ${userId}`);
      return res.status(403).json({
        success: false,
        error: 'Forbidden - You can only update your own notification preferences'
      });
    }

    const db = getFirestore();

    // Get user token document
    const userTokenDoc = await db.collection('user_tokens').doc(userId).get();

    if (!userTokenDoc.exists) {
      console.error(`[TOKEN ERROR] User token document not found for user ${userId}`);
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
    
    console.log(`[TOKEN DEBUG] Notification preferences updated successfully for user ${userId}`);

    return res.status(200).json({
      success: true,
      message: 'Notification preferences updated successfully'
    });
  } catch (error) {
    console.error('[TOKEN ERROR] Error updating notification preferences:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Get user's notification preferences (requires authentication)
router.get('/preferences/:userId', verifyToken, async (req, res) => {
  try {
    const userId = req.params.userId;
    const authenticatedUserId = req.user.uid;
    
    console.log(`[TOKEN DEBUG] Getting notification preferences for user ${userId}`);
    console.log(`[TOKEN DEBUG] Authenticated User ID: ${authenticatedUserId}`);
    
    // Security check: Ensure users can only get their own preferences
    if (userId !== authenticatedUserId && !req.user.isAdmin) {
      console.error(`[TOKEN ERROR] Security violation: User ${authenticatedUserId} attempted to get preferences for ${userId}`);
      return res.status(403).json({
        success: false,
        error: 'Forbidden - You can only access your own notification preferences'
      });
    }
    
    const db = getFirestore();
    
    // Get user token document
    const userTokenDoc = await db.collection('user_tokens').doc(userId).get();
    
    if (!userTokenDoc.exists) {
      console.error(`[TOKEN ERROR] User token document not found for user ${userId}`);
      return res.status(404).json({
        success: false,
        error: 'User token document not found'
      });
    }
    
    const userData = userTokenDoc.data();
    const preferences = userData.notificationPreferences || {};
    
    return res.status(200).json({
      success: true,
      preferences
    });
  } catch (error) {
    console.error('[TOKEN ERROR] Error getting notification preferences:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Delete a user's FCM token (requires authentication)
router.delete('/token', verifyToken, async (req, res) => {
  try {
    const { userId, token } = req.body;
    const authenticatedUserId = req.user.uid;
    
    console.log(`[TOKEN DEBUG] Received token deletion request:`);
    console.log(`[TOKEN DEBUG] User ID: ${userId}`);
    console.log(`[TOKEN DEBUG] Token (truncated): ${token ? token.substring(0, 15) + '...' : 'undefined'}`);
    console.log(`[TOKEN DEBUG] Authenticated User ID: ${authenticatedUserId}`);
    
    // Validate required fields
    if (!userId || !token) {
      console.error(`[TOKEN ERROR] Missing required fields: ${!userId ? 'userId' : ''}${!token ? 'token' : ''}`);
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: userId, token'
      });
    }
    
    // Security check: Ensure users can only delete their own tokens
    if (userId !== authenticatedUserId && !req.user.isAdmin) {
      console.error(`[TOKEN ERROR] Security violation: User ${authenticatedUserId} attempted to delete token for ${userId}`);
      return res.status(403).json({
        success: false,
        error: 'Forbidden - You can only delete your own tokens'
      });
    }
    
    const db = getFirestore();
    
    // Get existing tokens
    const userTokenDoc = await db.collection('user_tokens').doc(userId).get();
    
    if (!userTokenDoc.exists) {
      console.error(`[TOKEN ERROR] User token document not found for user ${userId}`);
      return res.status(404).json({
        success: false,
        error: 'User token document not found'
      });
    }
    
    const userData = userTokenDoc.data();
    const tokens = userData.tokens || [];
    
    // Filter out the token to delete
    const updatedTokens = tokens.filter(t => t.token !== token);
    
    // Check if token was found and removed
    if (updatedTokens.length === tokens.length) {
      console.log(`[TOKEN DEBUG] Token not found for user ${userId}`);
      return res.status(404).json({
        success: false,
        error: 'Token not found'
      });
    }
    
    // Update document
    await db.collection('user_tokens').doc(userId).update({
      tokens: updatedTokens,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`[TOKEN DEBUG] Token deleted successfully for user ${userId}, remaining tokens: ${updatedTokens.length}`);
    
    return res.status(200).json({
      success: true,
      message: 'Token deleted successfully',
      tokenCount: updatedTokens.length
    });
  } catch (error) {
    console.error('[TOKEN ERROR] Error deleting token:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Add new logout endpoint
router.post('/logout', verifyToken, async (req, res) => {
  try {
    const { userId } = req.body;
    const authenticatedUserId = req.user.uid;
    
    console.log(`[TOKEN DEBUG] Received logout request:`);
    console.log(`[TOKEN DEBUG] User ID: ${userId}`);
    console.log(`[TOKEN DEBUG] Authenticated User ID: ${authenticatedUserId}`);
    
    // Validate required fields
    if (!userId) {
      console.error(`[TOKEN ERROR] Missing required field: userId`);
      return res.status(400).json({
        success: false,
        error: 'Missing required field: userId'
      });
    }
    
    // Security check: Ensure users can only logout themselves
    if (userId !== authenticatedUserId && !req.user.isAdmin) {
      console.error(`[TOKEN ERROR] Security violation: User ${authenticatedUserId} attempted to logout user ${userId}`);
      return res.status(403).json({
        success: false,
        error: 'Forbidden - You can only logout your own account'
      });
    }
    
    const db = getFirestore();
    
    // Get user token document
    const userTokenDoc = await db.collection('user_tokens').doc(userId).get();
    
    if (!userTokenDoc.exists) {
      console.log(`[TOKEN WARNING] User token document not found for user ${userId} during logout`);
      return res.status(200).json({
        success: true,
        message: 'No tokens to clear'
      });
    }
    
    // Mark all tokens as inactive by setting lastActive to a very old date
    // This is better than deleting them all, as it allows for token reuse if the user logs back in
    const userData = userTokenDoc.data();
    const tokens = userData.tokens || [];
    
    // Instead of using an old timestamp (which can cause date/time issues),
    // simply mark tokens with a loggedOut flag. This is more reliable.
    const updatedTokens = tokens.map(t => ({
      ...t, 
      loggedOut: true
    }));
    
    // Update document
    await db.collection('user_tokens').doc(userId).update({
      tokens: updatedTokens,
      lastLogout: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`[TOKEN DEBUG] All tokens marked as inactive for user ${userId} during logout. Token count: ${updatedTokens.length}`);
    
    return res.status(200).json({
      success: true,
      message: 'All tokens marked as inactive on logout',
      tokenCount: updatedTokens.length
    });
  } catch (error) {
    console.error('[TOKEN ERROR] Error during logout:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
