const admin = require('firebase-admin');
const { initializeApp, getFirestore, getDatabase } = require('../services/firebase');

// Initialize Firebase Admin SDK
initializeApp();

// Script to recover or report on missing FCM tokens
async function recoverMissingTokens() {
  console.log('Starting token recovery process...');
  const db = getFirestore();
  
  try {
    // Get users with missing tokens
    const missingTokensSnapshot = await db.collection('missing_tokens').get();
    
    if (missingTokensSnapshot.empty) {
      console.log('No users with missing tokens found');
      return;
    }
    
    console.log(`Found ${missingTokensSnapshot.size} users with missing tokens`);
    const usersChecked = [];
    
    // Check each user to see if they've registered new tokens since
    for (const doc of missingTokensSnapshot.docs) {
      const userId = doc.id;
      const missingTokenData = doc.data();
      
      console.log(`Checking recovery options for user ${userId}...`);
      usersChecked.push(userId);
      
      // Check if user has tokens now
      const userTokensDoc = await db.collection('user_tokens').doc(userId).get();
      
      if (!userTokensDoc.exists) {
        console.log(`User ${userId} still has no token document`);
        
        // Check if user still exists in the system
        const userDoc = await db.collection('users').doc(userId).get();
        
        if (!userDoc.exists) {
          console.log(`User ${userId} no longer exists, removing from missing tokens list`);
          await db.collection('missing_tokens').doc(userId).delete();
          continue;
        }
        
        // Update last checked timestamp
        await db.collection('missing_tokens').doc(userId).update({
          lastChecked: admin.firestore.FieldValue.serverTimestamp(),
          recoveryAttempts: admin.firestore.FieldValue.increment(1)
        });
        continue;
      }
      
      const userData = userTokensDoc.data();
      const tokens = userData.tokens || [];
      
      if (tokens.length === 0) {
        console.log(`User ${userId} has token document but no tokens`);
        // Update last checked timestamp
        await db.collection('missing_tokens').doc(userId).update({
          lastChecked: admin.firestore.FieldValue.serverTimestamp(),
          recoveryAttempts: admin.firestore.FieldValue.increment(1)
        });
        continue;
      }
      
      console.log(`User ${userId} now has ${tokens.length} tokens, removing from missing tokens list`);
      
      // Log successful recovery
      await db.collection('token_recovery_success').add({
        userId,
        recoveredAt: admin.firestore.FieldValue.serverTimestamp(),
        tokenCount: tokens.length,
        previousMissingData: missingTokenData
      });
      
      // Remove from missing tokens collection
      await db.collection('missing_tokens').doc(userId).delete();
    }
    
    console.log(`Token recovery process completed for ${usersChecked.length} users`);
    
    // Generate report on users still missing tokens
    const remainingMissingSnapshot = await db.collection('missing_tokens').get();
    console.log(`${remainingMissingSnapshot.size} users still have missing tokens`);
    
    // Check for users with extremely old missing tokens (> 30 days)
    const thirtyDaysAgo = admin.firestore.Timestamp.fromMillis(Date.now() - (30 * 24 * 60 * 60 * 1000));
    const oldMissingTokensSnapshot = await db.collection('missing_tokens')
      .where('firstDetected', '<', thirtyDaysAgo)
      .get();
      
    if (!oldMissingTokensSnapshot.empty) {
      console.log(`WARNING: ${oldMissingTokensSnapshot.size} users have been missing tokens for over 30 days`);
      
      // Create a report for admin review
      await db.collection('reports').add({
        type: 'missing_tokens_report',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        usersMissingTokens: remainingMissingSnapshot.size,
        usersWithLongTermIssues: oldMissingTokensSnapshot.size,
        longTermIssueUserIds: oldMissingTokensSnapshot.docs.map(doc => doc.id)
      });
    }
    
  } catch (error) {
    console.error('Error in token recovery process:', error);
  }
}

// Run token recovery process
recoverMissingTokens()
  .then(() => {
    console.log('Token recovery process finished');
    process.exit(0);
  })
  .catch(error => {
    console.error('Unhandled error in token recovery:', error);
    process.exit(1);
  }); 