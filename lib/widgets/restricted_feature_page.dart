import 'package:flutter/material.dart';
import '../services/age_restriction_service.dart';

/// A professional-looking page that displays when a feature is restricted
/// based on the user's age
class RestrictedFeaturePage extends StatelessWidget {
  final RestrictedFeature feature;
  final AgeGroup userAgeGroup;

  const RestrictedFeaturePage({
    super.key,
    required this.feature,
    required this.userAgeGroup,
  });

  @override
  Widget build(BuildContext context) {
    final service = AgeRestrictionService();
    final message = service.getRestrictionMessage(feature, userAgeGroup);
    final featureTitle = service.getFeatureTitle(feature);
    final minimumAge = service.getMinimumAge(feature);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          featureTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF00C49A),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Animated lock icon container
                _buildLockIcon(),
                const SizedBox(height: 32),
                // Feature unavailable title
                Text(
                  'Feature Unavailable',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Age requirement badge
                _buildAgeRequirementBadge(minimumAge),
                const SizedBox(height: 24),
                // Restriction message card
                _buildMessageCard(message),
                const SizedBox(height: 32),
                // What you can do section
                _buildWhatYouCanDoSection(),
                const SizedBox(height: 24),
                // Fun encouragement section
                _buildEncouragementSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockIcon() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00C49A).withValues(alpha: 0.15),
            const Color(0xFF00A085).withValues(alpha: 0.25),
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C49A).withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF00C49A).withValues(alpha: 0.3),
                width: 2,
              ),
            ),
          ),
          // Inner icon container
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              _getFeatureIcon(),
              size: 44,
              color: Colors.grey[400],
            ),
          ),
          // Lock badge
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFeatureIcon() {
    switch (feature) {
      case RestrictedFeature.marketplace:
        return Icons.shopping_cart_outlined;
      case RestrictedFeature.volunteer:
        return Icons.volunteer_activism_outlined;
      case RestrictedFeature.report:
        return Icons.report_outlined;
    }
  }

  Widget _buildAgeRequirementBadge(int minimumAge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF00C49A).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00C49A).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cake_outlined,
            size: 18,
            color: const Color(0xFF00C49A),
          ),
          const SizedBox(width: 8),
          Text(
            'Requires $minimumAge+ years',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF00C49A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
            size: 28,
            color: Colors.blue[400],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWhatYouCanDoSection() {
    final availableFeatures = _getAvailableFeatures();

    if (availableFeatures.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00C49A).withValues(alpha: 0.05),
            const Color(0xFF00A085).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00C49A).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 22,
                color: const Color(0xFF00C49A),
              ),
              const SizedBox(width: 8),
              const Text(
                'What You Can Do',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00C49A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...availableFeatures.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        feature['icon'] as IconData,
                        size: 18,
                        color: const Color(0xFF00C49A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        feature['text'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getAvailableFeatures() {
    final features = <Map<String, dynamic>>[];

    // Home is always available
    features.add({
      'icon': Icons.home_outlined,
      'text': 'Browse community notices and updates',
    });

    // Volunteer is available for youth (12+)
    if (userAgeGroup == AgeGroup.youth) {
      features.add({
        'icon': Icons.volunteer_activism_outlined,
        'text': 'Join volunteer activities in your community',
      });
    }

    // Children can browse notices
    if (userAgeGroup == AgeGroup.children) {
      features.add({
        'icon': Icons.people_outline,
        'text': 'Stay connected with your community',
      });
    }

    return features;
  }

  Widget _buildEncouragementSection() {
    String emoji;
    String title;
    String subtitle;

    switch (userAgeGroup) {
      case AgeGroup.children:
        emoji = '🌟';
        title = 'Keep Growing!';
        subtitle =
            'Every day you\'re one step closer to unlocking new features. Focus on learning and having fun!';
        break;
      case AgeGroup.youth:
        emoji = '🚀';
        title = 'Almost There!';
        subtitle =
            'You\'re growing up fast! In a few years, you\'ll have access to all community features.';
        break;
      default:
        emoji = '✨';
        title = 'Stay Connected';
        subtitle = 'Explore the features available to you and stay connected with your community!';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}



