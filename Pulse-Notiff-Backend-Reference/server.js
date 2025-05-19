require('dotenv').config();
const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');

// Import services from central index file to avoid circular dependencies
const services = require('./services');
const { initializeApp } = services.firebase;
const { startAllMonitoring } = services.monitoring;

// Import routes
const tokenRoutes = require('./routes/tokens');
const notificationRoutes = require('./routes/notifications');

// Initialize Firebase Admin SDK
initializeApp();

// Create Express app
const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Add request logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`[API] ${req.method} ${req.originalUrl} - Status: ${res.statusCode} - ${duration}ms`);
  });
  next();
});

// API Documentation
app.get('/', (req, res) => {
  res.status(200).json({
    name: 'PULSE Notification API',
    version: '1.0.0',
    description: 'API for managing push notifications in the PULSE app',
    endpoints: {
      health: {
        path: '/health',
        method: 'GET',
        description: 'Health check endpoint',
        auth: false
      },
      tokens: {
        register: {
          path: '/api/tokens/register',
          method: 'POST',
          description: 'Register a new FCM token',
          auth: true
        },
        preferences: {
          path: '/api/tokens/preferences',
          method: 'POST',
          description: 'Update notification preferences',
          auth: true
        },
        getPreferences: {
          path: '/api/tokens/preferences/:userId',
          method: 'GET',
          description: 'Get notification preferences',
          auth: true
        },
        deleteToken: {
          path: '/api/tokens/token',
          method: 'DELETE',
          description: 'Delete an FCM token',
          auth: true
        }
      },
      notifications: {
        send: {
          path: '/api/notifications/send',
          method: 'POST',
          description: 'Send a notification to a user',
          auth: true
        },
        sendCommunity: {
          path: '/api/notifications/send-community',
          method: 'POST',
          description: 'Send a notification to all users in a community',
          auth: true,
          adminOnly: true
        },
        test: {
          path: '/api/notifications/test',
          method: 'POST',
          description: 'Send a test notification',
          auth: true
        },
        getUserNotifications: {
          path: '/api/notifications/user/:userId',
          method: 'GET',
          description: 'Get notifications for a user',
          auth: true
        },
        markAsRead: {
          path: '/api/notifications/read/:statusId',
          method: 'POST',
          description: 'Mark a notification as read',
          auth: true
        },
        markAllAsRead: {
          path: '/api/notifications/read-all/:userId',
          method: 'POST',
          description: 'Mark all notifications as read for a user',
          auth: true
        }
      }
    },
    security: {
      authentication: 'Bearer token authentication using Firebase Authentication',
      authorization: 'Users can only access their own resources'
    }
  });
});

// Routes
app.use('/api/tokens', tokenRoutes);
app.use('/api/notifications', notificationRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Global error handling middleware
app.use((err, req, res, next) => {
  console.error('[SERVER ERROR]', err);
  res.status(500).json({
    success: false,
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'production' ? 'An unexpected error occurred' : err.message
  });
});

// Handle 404 errors
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Not Found',
    message: `The requested endpoint '${req.originalUrl}' does not exist`
  });
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`API documentation available at http://localhost:${PORT}/`);

  // Start monitoring for events that trigger notifications
  startAllMonitoring();

  // Run initial cleanup of old read notifications (older than 30 days)
  const { cleanupReadNotifications } = services.notifications;
  cleanupReadNotifications(30)
    .then(result => {
      console.log(`Initial cleanup completed: ${result.count} old notifications deleted`);
    })
    .catch(error => {
      console.error('Error in initial cleanup:', error);
    });
});

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  process.exit(0);
});
