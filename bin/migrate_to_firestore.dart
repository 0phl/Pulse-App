import 'package:firebase_core/firebase_core.dart';
import '../lib/firebase_options.dart';
import '../lib/services/migration_service.dart';

/// This script performs a full migration of data from Realtime Database to Firestore.
/// 
/// Usage:
/// ```bash
/// # Run the migration
/// flutter run bin/migrate_to_firestore.dart
/// ```
/// 
/// Prerequisites:
/// - Firebase project must have both RTDB and Firestore enabled
/// - Firebase configuration must be set up correctly
/// - Proper authentication credentials with admin access
/// - Backup of RTDB data recommended before running
/// 
/// The migration process:
/// 1. Migrates all users from RTDB to Firestore
/// 2. Preserves user data including roles and community associations
/// 3. Migrates all community data
/// 4. Verifies the migration by comparing record counts
/// 
/// After migration:
/// - Check the migration logs in the admin dashboard
/// - Verify user access and permissions
/// - Test key functionalities with migrated data
/// 
/// Note: This script should be run only once. Running it multiple times
/// may cause duplicate data or overwrite existing Firestore records.
Future<void> main() async {
  try {
    // Initialize Firebase with the default options
    print('Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final migrationService = MigrationService();

    print('\nStarting migration...');
    print('===================');
    print('1. Users and related data');
    print('2. Community information');
    print('3. Permission structures');
    print('===================\n');

    // Start the migration process
    final sessionId = await migrationService.migrateUsersToFirestore();
    print('Migration session ID: $sessionId');
    
    print('\nVerifying migration...');
    print('===================');
    print('• Checking record counts');
    print('• Validating data integrity');
    print('• Confirming relationships');
    print('===================\n');

    // Verify the migration results
    await migrationService.verifyMigration();

    print('\nMigration completed successfully!');
    print('\nNext steps:');
    print('1. View detailed logs in the admin dashboard');
    print('2. Test user authentication');
    print('3. Verify community access');
    print('4. Check migrated data integrity');
  } catch (e) {
    print('\n❌ Error during migration: $e');
    print('\nRecommended actions:');
    print('1. Check Firebase configuration');
    print('2. Verify database access permissions');
    print('3. Review error logs in admin dashboard');
    print('4. Ensure both databases are accessible');
  } finally {
    print('\nMigration process completed.');
    print('For detailed logs, visit: /admin/migration/logs');
  }
}
