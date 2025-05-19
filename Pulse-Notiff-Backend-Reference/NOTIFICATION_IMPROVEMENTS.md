# PULSE Notification System Improvements

This document summarizes the improvements made to the notification system to address token registration issues and increase notification reliability.

## Problems Addressed

1. **Missing FCM Tokens**: Some users (3 out of 7 in provided examples) weren't receiving notifications due to missing or invalid tokens.

2. **Overly Strict Token Validation**: The system was filtering out valid tokens due to strict validation criteria.

3. **Skipping Relevant Notices**: Notices were being skipped if they were more than 30 seconds old, potentially causing missed notifications.

4. **No Retry Mechanism**: When notification delivery failed, there was no automatic retry system in place.

5. **No Token Recovery Process**: The system did not keep track of users with missing tokens for recovery purposes.

## Implemented Solutions

### 1. Improved Token Validation Logic

- Extended token lifetime from 30 days to 60 days for better coverage
- Implemented a smarter fallback strategy to use the most recent token instead of all tokens
- Added tracking of token recovery attempts

```javascript
// If no tokens are valid after filtering, use the most recent token as fallback
if (validTokens.length === 0 && tokens.length > 0) {
  console.log(`[NOTIFICATION WARNING] No valid tokens found for user ${userId} after filtering, using most recent token as fallback`);
  
  // Find most recent token by lastActive timestamp
  let mostRecentToken = tokens[0];
  let mostRecentTimestamp = 0;
  
  // Find and use the most recent token
  // ...
}
```

### 2. Enhanced Notice Processing

- Extended time window for processing notices from 30 seconds to 2 minutes
- Only skip extremely old notices (> 1 hour) instead of 30 seconds
- Process notices between 2 minutes and 1 hour old with a warning

```javascript
// Only skip notices that are extremely old (> 1 hour)
if (now - createdAt > 60 * 60 * 1000) {
  // Skip notices older than 1 hour
  console.log(`Skipping notice ${noticeId} - too old (${Math.floor((now - createdAt)/1000)} seconds)`);
  return;
}
```

### 3. Added Retry Mechanism for Failed Notifications

- Implemented a retry system with up to 3 attempts for failed notifications
- Added exponential backoff between retry attempts (3 seconds)
- Implemented tracking of failed notification attempts for later analysis

```javascript
// Retry logic for failed notification attempts
let retryCount = 0;
const maxRetries = 3;
let notificationResult;

while (retryCount < maxRetries) {
  try {
    notificationResult = await sendNotificationToCommunity(
      // notification details
    );
    
    // If successful or partially successful, break out of retry loop
    if (notificationResult.success || notificationResult.sentCount > 0) {
      break;
    }
    
    // Wait 3 seconds before retry
    retryCount++;
    await new Promise(resolve => setTimeout(resolve, 3000));
  } catch (retryError) {
    // Handle errors and continue retries
  }
}
```

### 4. Token Recovery System

- Created a token recovery script (`scripts/token_recovery.js`) to identify and attempt to recover missing tokens
- Set up a daily scheduled job to run the token recovery process
- Created collections to track users with missing tokens and successful recoveries

```javascript
// Daily token recovery script
async function recoverMissingTokens() {
  // Get users with missing tokens
  const missingTokensSnapshot = await db.collection('missing_tokens').get();
  
  // Check each user to see if they've registered new tokens
  // Remove from missing tokens list if tokens have been recovered
  // Generate reports on users still missing tokens
}
```

### 5. Improved Token Registration Process

- Added automatic cleanup of old or logged out tokens during registration
- Limited the number of tokens per user to 10 to prevent edge cases
- Added token recovery detection to remove users from the missing tokens list when they register a new token
- Improved logging for better diagnostics

```javascript
// Clean up any logged out or very old tokens during registration
let cleanupCount = 0;
const updatedTokens = tokens.filter(t => {
  // Remove explicitly logged out tokens
  if (t.loggedOut === true) {
    cleanupCount++;
    return false;
  }
  
  // Remove tokens older than 90 days without activity
  // ...
});
```

### 6. Scheduled Maintenance

- Created a cron job setup script for token recovery and maintenance
- Added support for both Unix/Linux crontab and instructions for Windows Task Scheduler
- Set up scheduled jobs to run daily at 2 AM

## How to Use the New Features

### Run Token Recovery Manually

```
npm run recover-tokens
```

### Set Up Scheduled Tasks

```
npm run setup-cron
```

This will either:
- Install cron jobs automatically (on systems with crontab)
- Create a `SCHEDULED_TASKS.md` file with instructions for manual setup

### Check Missing Tokens Status

Monitor the `missing_tokens` collection in Firestore for users with token issues.

## Monitoring and Reporting

The improved system now keeps track of:

1. Users with missing tokens (`missing_tokens` collection)
2. Token recovery attempts (`token_recovery_attempts` collection)
3. Successful token recoveries (`token_recovery_success` collection)
4. Failed notifications (`failed_notifications` collection)
5. Notification errors (`notification_errors` collection)

Use these collections to generate reports on notification system health and identify users who consistently have issues. 