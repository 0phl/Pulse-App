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

// Routes
app.use('/api/tokens', tokenRoutes);
app.use('/api/notifications', notificationRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);

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
