import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/volunteer_post.dart';
import '../services/community_service.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';

class VolunteerPage extends StatefulWidget {
  const VolunteerPage({super.key});

  @override
  State<VolunteerPage> createState() => _VolunteerPageState();
}

class _VolunteerPageState extends State<VolunteerPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CommunityService _communityService = CommunityService();
  Stream<List<VolunteerPost>>? _postsStream;
  String? _currentUserCommunityId;

  @override
  void initState() {
    super.initState();
    _loadUserCommunity();
  }

  Future<void> _loadUserCommunity() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print("No authenticated user found");
        return;
      }

      // Wait for user to be fully authenticated
      await Future.delayed(const Duration(milliseconds: 500));

      final community =
          await _communityService.getUserCommunity(currentUser.uid);
      if (community != null && mounted) {
        setState(() {
          _currentUserCommunityId = community.id;
        });
        _initializeStream();
      } else {
        print("No community found for user");
      }
    } catch (e) {
      print("Error loading user community: $e");
    }
  }

  void _initializeStream() {
    if (_currentUserCommunityId == null) {
      print("Cannot initialize stream - no community ID");
      return;
    }

    try {
      final query = _firestore
          .collection('volunteer_posts')
          .where('communityId', isEqualTo: _currentUserCommunityId)
          .orderBy('date', descending: true)
          .orderBy(FieldPath.documentId, descending: true);

      _postsStream = query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => VolunteerPost.fromMap(
                doc.data(), doc.id))
            // Only show posts that haven't ended yet (upcoming or ongoing)
            .where((post) => post.status != VolunteerPostStatus.done)
            .toList();
      });

      print("Stream initialized successfully");
    } catch (e) {
      print("Error initializing stream: $e");
    }
  }

  Future<void> _joinVolunteerPost(
      BuildContext context, VolunteerPost post) async {
    try {
      final currentUser = AuthService().currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please login to join volunteer activities')),
        );
        return;
      }

      // Check if the activity has already started or ended
      if (post.status == VolunteerPostStatus.ongoing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('This activity has already started. You cannot join anymore.')),
        );
        return;
      }

      if (post.status == VolunteerPostStatus.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('This activity has already ended.')),
        );
        return;
      }

      debugPrint(
          'DEBUG: User ${currentUser.uid} attempting to join volunteer post ${post.id}');
      debugPrint('DEBUG: Post admin ID: ${post.adminId}');

      if (post.joinedUsers.contains(currentUser.uid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You have already joined this activity')),
        );
        return;
      }

      if (post.joinedUsers.length >= post.maxVolunteers) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This activity is already full')),
        );
        return;
      }

      debugPrint('DEBUG: Updating volunteer post with new user');
      await FirebaseFirestore.instance
          .collection('volunteer_posts')
          .doc(post.id)
          .update({
        'joinedUsers': FieldValue.arrayUnion([currentUser.uid]),
      });

      debugPrint('DEBUG: Successfully updated volunteer post');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Successfully joined the volunteer activity!')),
      );
    } catch (e) {
      debugPrint('DEBUG: Error joining volunteer post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining activity: $e')),
      );
    }
  }

  // New function to cancel volunteer registration
  Future<void> _cancelVolunteerPost(
      BuildContext context, VolunteerPost post) async {
    try {
      final currentUser = AuthService().currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please login to manage your activities')),
        );
        return;
      }

      // Check if the activity has already started or ended - cannot cancel
      if (post.status == VolunteerPostStatus.ongoing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('This activity has already started. You cannot cancel your registration.')),
        );
        return;
      }

      if (post.status == VolunteerPostStatus.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('This activity has already ended. You cannot cancel your registration.')),
        );
        return;
      }

      if (!post.joinedUsers.contains(currentUser.uid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have not joined this activity')),
        );
        return;
      }

      final bool confirm = await showDialog(
            context: context,
            builder: (context) => Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10.0,
                      offset: const Offset(0.0, 10.0),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.event_busy_rounded,
                        color: Colors.red[400],
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Cancel Registration?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A202C),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Are you sure you want to cancel your registration? You might lose your spot if you try to join again later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: Colors.grey[50],
                            ),
                            child: Text(
                              'Nevermind',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Yes, Cancel',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ) ??
          false;

      if (!confirm) return;

      await FirebaseFirestore.instance
          .collection('volunteer_posts')
          .doc(post.id)
          .update({
        'joinedUsers': FieldValue.arrayRemove([currentUser.uid]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Successfully cancelled your registration')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling registration: $e')),
      );
    }
  }

  Color _getStatusColor(VolunteerPostStatus status) {
    switch (status) {
      case VolunteerPostStatus.upcoming:
        return const Color(0xFF3B82F6); // Blue
      case VolunteerPostStatus.ongoing:
        return const Color(0xFFF59E0B); // Amber
      case VolunteerPostStatus.done:
        return const Color(0xFF10B981); // Green
    }
  }

  IconData _getStatusIcon(VolunteerPostStatus status) {
    switch (status) {
      case VolunteerPostStatus.upcoming:
        return Icons.schedule_rounded;
      case VolunteerPostStatus.ongoing:
        return Icons.play_circle_rounded;
      case VolunteerPostStatus.done:
        return Icons.check_circle_rounded;
    }
  }

  List<Color> _getHeaderGradient(VolunteerPostStatus status) {
    switch (status) {
      case VolunteerPostStatus.upcoming:
        return [const Color(0xFF00C49A), const Color(0xFF00A884)];
      case VolunteerPostStatus.ongoing:
        return [const Color(0xFFF59E0B), const Color(0xFFD97706)];
      case VolunteerPostStatus.done:
        return [const Color(0xFF10B981), const Color(0xFF059669)];
    }
  }

  String _getButtonText(bool hasJoined, bool isFull, bool isOngoingOrDone, VolunteerPostStatus status) {
    if (hasJoined) {
      if (status == VolunteerPostStatus.ongoing) {
        return 'Activity In Progress';
      } else if (status == VolunteerPostStatus.done) {
        return 'Activity Completed';
      }
      return 'Cancel Registration';
    } else {
      if (status == VolunteerPostStatus.ongoing) {
        return 'Already Started';
      } else if (status == VolunteerPostStatus.done) {
        return 'Activity Ended';
      } else if (isFull) {
        return 'Activity Full';
      }
      return 'Join Activity';
    }
  }

  Widget _buildVolunteerCard(VolunteerPost post) {
    final spotsLeft = post.maxVolunteers - post.joinedUsers.length;
    final currentUser = AuthService().currentUser;
    final bool hasJoined =
        currentUser != null && post.joinedUsers.contains(currentUser.uid);
    final bool isFull = spotsLeft <= 0;
    final bool isOngoingOrDone = post.status == VolunteerPostStatus.ongoing || 
                                  post.status == VolunteerPostStatus.done;
    final bool canJoin = !hasJoined && !isFull && !isOngoingOrDone;
    final bool canCancel = hasJoined && !isOngoingOrDone;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Status-based Gradient
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _getHeaderGradient(post.status),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(post.status),
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              post.statusLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        post.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              post.location,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '$spotsLeft spots left',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time Info Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(post.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: _getStatusColor(post.status),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        post.timeInfo,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _getStatusColor(post.status),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Start & End Date/Time
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Starts',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.play_circle_outline_rounded,
                                size: 16,
                                color: Color(0xFF3B82F6),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${DateFormat('MMM d').format(post.startDate)} • ${post.formattedStartTime}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 36,
                      width: 1,
                      color: Colors.grey.shade200,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ends',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.stop_circle_outlined,
                                size: 16,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${DateFormat('MMM d').format(post.endDate)} • ${post.formattedEndTime}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description Preview
                GestureDetector(
                  onTap: () => _showDescriptionSheet(context, post),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          children: [
                            Text(
                              'Read more details',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF00C49A),
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 12,
                              color: Color(0xFF00C49A),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Volunteers Joined',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${post.joinedUsers.length}/${post.maxVolunteers}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isFull
                                ? Colors.redAccent
                                : const Color(0xFF00C49A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: post.maxVolunteers > 0
                            ? post.joinedUsers.length / post.maxVolunteers
                            : 0,
                        backgroundColor: Colors.grey[100],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isFull ? Colors.redAccent : const Color(0xFF00C49A),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: hasJoined
                        ? (canCancel ? () => _cancelVolunteerPost(context, post) : null)
                        : (canJoin ? () => _joinVolunteerPost(context, post) : null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasJoined
                          ? (canCancel ? Colors.redAccent.withOpacity(0.1) : Colors.grey[200])
                          : (canJoin ? const Color(0xFF00C49A) : Colors.grey[300]),
                      foregroundColor: hasJoined
                          ? (canCancel ? Colors.redAccent : Colors.grey[500])
                          : Colors.white,
                      elevation: (hasJoined && canCancel) ? 0 : (canJoin ? 2 : 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isOngoingOrDone && hasJoined) ...[
                          Icon(
                            post.status == VolunteerPostStatus.ongoing
                                ? Icons.play_circle_rounded
                                : Icons.check_circle_rounded,
                            size: 18,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          _getButtonText(hasJoined, isFull, isOngoingOrDone, post.status),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: (hasJoined && !canCancel) || (!hasJoined && !canJoin)
                                ? Colors.grey[600]
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDescriptionSheet(BuildContext context, VolunteerPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    // Status Badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(post.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getStatusIcon(post.status),
                                size: 14,
                                color: _getStatusColor(post.status),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                post.statusLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _getStatusColor(post.status),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            post.timeInfo,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Header
                    Text(
                      post.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A202C),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Start & End Date/Time Cards
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF3B82F6).withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.play_circle_outline_rounded,
                                      size: 14,
                                      color: Color(0xFF3B82F6),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Starts',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF3B82F6),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  DateFormat('MMM d, yyyy').format(post.startDate),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  post.formattedStartTime,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF10B981).withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.stop_circle_outlined,
                                      size: 14,
                                      color: Color(0xFF10B981),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Ends',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  DateFormat('MMM d, yyyy').format(post.endDate),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  post.formattedEndTime,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    // Content
                    const Text(
                      'About this Activity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      post.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[800],
                        height: 1.6, // Improved line height for readability
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Location Section in Sheet
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6FFFA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFF00C49A),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Location',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  post.location,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Close Button Area
              Padding(
                padding: EdgeInsets.fromLTRB(
                    24, 0, 24, MediaQuery.of(context).padding.bottom + 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      foregroundColor: const Color(0xFF2D3748),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Volunteer Opportunities',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF00C49A),
        elevation: 0,
      ),
      body: _currentUserCommunityId == null
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
              ),
            )
          : StreamBuilder<List<VolunteerPost>>(
              stream: _postsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading opportunities',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
                    ),
                  );
                }

                final posts = snapshot.data ?? [];

                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.volunteer_activism,
                          size: 48,
                          color: const Color(0xFF00C49A).withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Volunteer Opportunities',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Wait for your community administrator to create a volunteer opportunity.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    return _buildVolunteerCard(posts[index]);
                  },
                );
              },
            ),
    );
  }
}
