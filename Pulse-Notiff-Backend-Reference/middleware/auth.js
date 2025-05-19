/**
 * Authentication Middleware
 * 
 * This middleware verifies Firebase authentication tokens and ensures
 * users can only access their own resources.
 */

const admin = require('firebase-admin');
const { getFirestore } = require('../services/firebase');

/**
 * Middleware to verify Firebase authentication token
 * Extracts the user ID from the token and adds it to the request object
 */
const verifyToken = async (req, res, next) => {
  // Get the authorization header
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    console.log('[AUTH] No valid authorization header found');
    return res.status(401).json({ 
      success: false, 
      error: 'Unauthorized - No valid token provided' 
    });
  }
  
  // Extract the token
  const token = authHeader.split('Bearer ')[1];
  
  try {
    // Verify the token
    const decodedToken = await admin.auth().verifyIdToken(token);
    
    // Add the user ID to the request object
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email || null,
      isAdmin: decodedToken.admin === true,
    };
    
    console.log(`[AUTH] Successfully authenticated user: ${req.user.uid}`);
    
    // Continue to the next middleware or route handler
    next();
  } catch (error) {
    console.error('[AUTH] Error verifying token:', error);
    return res.status(401).json({ 
      success: false, 
      error: 'Unauthorized - Invalid token' 
    });
  }
};

/**
 * Middleware to ensure a user can only access their own resources
 * Validates that the user ID in the request parameters matches the authenticated user's ID
 */
const authorizeUser = (req, res, next) => {
  // Get the user ID from the request parameters or body
  const requestedUserId = req.params.userId || req.body.userId;
  
  if (!requestedUserId) {
    return res.status(400).json({ 
      success: false, 
      error: 'Bad Request - User ID not provided' 
    });
  }
  
  // Ensure the authenticated user matches the requested user
  if (req.user.uid !== requestedUserId && !req.user.isAdmin) {
    console.log(`[AUTH] Authorization failed: User ${req.user.uid} attempted to access resources of user ${requestedUserId}`);
    return res.status(403).json({ 
      success: false, 
      error: 'Forbidden - You can only access your own resources' 
    });
  }
  
  console.log(`[AUTH] User ${req.user.uid} authorized to access resources`);
  
  // Continue to the next middleware or route handler
  next();
};

/**
 * Middleware to ensure only admins can access certain resources
 */
const requireAdmin = (req, res, next) => {
  if (!req.user.isAdmin) {
    console.log(`[AUTH] Admin authorization failed for user: ${req.user.uid}`);
    return res.status(403).json({ 
      success: false, 
      error: 'Forbidden - Admin access required' 
    });
  }
  
  console.log(`[AUTH] Admin authorization successful for user: ${req.user.uid}`);
  
  // Continue to the next middleware or route handler
  next();
};

module.exports = {
  verifyToken,
  authorizeUser,
  requireAdmin
}; 