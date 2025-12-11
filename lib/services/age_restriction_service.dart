import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/firestore_user.dart';

/// Defines the age groups for feature restrictions
enum AgeGroup {
  children, // 8-11 years old
  youth, // 12-17 years old
  adult, // 18+ years old
}

/// Defines the features that can be restricted
enum RestrictedFeature {
  marketplace,
  volunteer,
  report,
}

/// Service to handle age-based feature restrictions
class AgeRestrictionService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static final AgeRestrictionService _instance =
      AgeRestrictionService._internal();
  factory AgeRestrictionService() => _instance;
  AgeRestrictionService._internal();

  // Cache for user age to avoid repeated database calls
  int? _cachedAge;
  String? _cachedUserId;

  /// Get the current user's age
  Future<int?> getUserAge() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // Return cached age if available and user hasn't changed
      if (_cachedAge != null && _cachedUserId == user.uid) {
        return _cachedAge;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data();
      if (userData == null) return null;

      final firestoreUser = FirestoreUser.fromMap(userData);
      _cachedAge = firestoreUser.age;
      _cachedUserId = user.uid;

      return _cachedAge;
    } catch (e) {
      debugPrint('Error getting user age: $e');
      return null;
    }
  }

  /// Get the user's age group based on their age
  Future<AgeGroup?> getUserAgeGroup() async {
    final age = await getUserAge();
    if (age == null) return null;

    if (age >= 8 && age <= 11) {
      return AgeGroup.children;
    } else if (age >= 12 && age <= 17) {
      return AgeGroup.youth;
    } else {
      return AgeGroup.adult;
    }
  }

  /// Check if a specific feature is accessible for the user
  Future<bool> canAccessFeature(RestrictedFeature feature) async {
    final ageGroup = await getUserAgeGroup();

    // If we can't determine age, allow access (fail open for better UX)
    if (ageGroup == null) return true;

    switch (feature) {
      case RestrictedFeature.marketplace:
        // Only adults (18+) can use marketplace
        return ageGroup == AgeGroup.adult;

      case RestrictedFeature.volunteer:
        // Youth (12-17) and adults (18+) can use volunteer
        return ageGroup == AgeGroup.youth || ageGroup == AgeGroup.adult;

      case RestrictedFeature.report:
        // Only adults (18+) can use report
        return ageGroup == AgeGroup.adult;
    }
  }

  /// Get a user-friendly message for why a feature is restricted
  String getRestrictionMessage(RestrictedFeature feature, AgeGroup ageGroup) {
    switch (feature) {
      case RestrictedFeature.marketplace:
        if (ageGroup == AgeGroup.children) {
          return 'The Marketplace feature is available for users 18 years and older. '
              'This feature will be unlocked when you turn 18!';
        } else if (ageGroup == AgeGroup.youth) {
          return 'The Marketplace feature is available for users 18 years and older. '
              'You\'ll be able to access this feature when you turn 18!';
        }
        break;

      case RestrictedFeature.volunteer:
        if (ageGroup == AgeGroup.children) {
          return 'The Volunteer feature is available for users 12 years and older. '
              'Keep growing! You\'ll be able to join volunteer activities soon.';
        }
        break;

      case RestrictedFeature.report:
        if (ageGroup == AgeGroup.children) {
          return 'The Community Reports feature is available for users 18 years and older. '
              'For now, ask a parent or guardian to help report any issues.';
        } else if (ageGroup == AgeGroup.youth) {
          return 'The Community Reports feature is available for users 18 years and older. '
              'You\'ll be able to submit reports when you turn 18!';
        }
        break;
    }
    return 'This feature is not available for your age group.';
  }

  /// Get the feature title for display
  String getFeatureTitle(RestrictedFeature feature) {
    switch (feature) {
      case RestrictedFeature.marketplace:
        return 'Marketplace';
      case RestrictedFeature.volunteer:
        return 'Volunteer';
      case RestrictedFeature.report:
        return 'Community Reports';
    }
  }

  /// Get the icon for a feature
  String getFeatureIcon(RestrictedFeature feature) {
    switch (feature) {
      case RestrictedFeature.marketplace:
        return 'shopping_cart';
      case RestrictedFeature.volunteer:
        return 'volunteer_activism';
      case RestrictedFeature.report:
        return 'report';
    }
  }

  /// Get the minimum age required for a feature
  int getMinimumAge(RestrictedFeature feature) {
    switch (feature) {
      case RestrictedFeature.marketplace:
        return 18;
      case RestrictedFeature.volunteer:
        return 12;
      case RestrictedFeature.report:
        return 18;
    }
  }

  /// Clear the cache (useful when user logs out)
  void clearCache() {
    _cachedAge = null;
    _cachedUserId = null;
  }
}

