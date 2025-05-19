# Notification System Security

This document outlines the security measures implemented to protect user notification data in the PULSE application.

## Authentication & Authorization

### Firebase Authentication

The notification API uses Firebase Authentication to verify user identity. All secure endpoints require a valid Firebase ID token to be provided in the Authorization header:

```
Authorization: Bearer <firebase-id-token>
```

### User Authorization

We enforce strict authorization rules to ensure users can only access their own data:

1. **User-specific data restriction**: Users can only access notifications, tokens, and preferences for their own account
2. **Admin privileges**: Admin users have access to additional functionality for troubleshooting and system management
3. **Owner verification**: Before modifying any resource, the system verifies the requesting user is the owner

## Secure Endpoints

The following endpoints are protected with authentication and authorization:

### Notification Endpoints

- `GET /api/notifications/user/:userId` - Get user's notifications (user must match authenticated user)
- `POST /api/notifications/read/:statusId` - Mark notification as read (notification must belong to authenticated user)
- `POST /api/notifications/read-all/:userId` - Mark all notifications as read (user must match authenticated user)
- `POST /api/notifications/send` - Send notification (restricted by authorization rules)
- `POST /api/notifications/send-community` - Send to community (admin only)
- `POST /api/notifications/test` - Test notification (restricted to self unless admin)
- `POST /api/notifications/diagnose` - Diagnostic endpoint (admin only)
- `POST /api/notifications/cleanup` - Cleanup notifications (admin only)

### Token Endpoints

- `POST /api/tokens/register` - Register FCM token (only for own account)
- `POST /api/tokens/preferences` - Update preferences (only for own account)
- `GET /api/tokens/preferences/:userId` - Get preferences (only for own account)
- `DELETE /api/tokens/token` - Delete token (only for own account)

## Security Validations

The system implements multiple layers of validation:

1. **Token Validation**: All Firebase tokens are cryptographically verified
2. **Owner Verification**: Before accessing any resource, user ownership is verified
3. **Input Validation**: All inputs are validated for correctness and safety
4. **Error Handling**: Secure error handling to prevent information disclosure

## Best Practices

The notification system follows these security best practices:

1. **Principle of Least Privilege**: Users can only access the minimum data needed
2. **Defense in Depth**: Multiple layers of security controls
3. **Secure by Default**: All endpoints require authentication unless explicitly public
4. **Comprehensive Logging**: Security events are logged for auditing

## Implementation

The security measures are implemented through Express middleware:

- `verifyToken`: Authenticates users via Firebase Auth
- `authorizeUser`: Ensures users can only access their own resources
- `requireAdmin`: Restricts certain endpoints to admin users only

## Testing Security

To verify security is working properly:

1. Attempt to access another user's notifications (should return 403 Forbidden)
2. Try to register a token for another user (should return 403 Forbidden)
3. Attempt admin operations as a regular user (should return 403 Forbidden)

## Future Enhancements

Planned security enhancements:

1. Rate limiting to prevent abuse
2. Enhanced audit logging
3. Automated security testing 