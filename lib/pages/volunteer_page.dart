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
  bool _isLoading = false;

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

      // Create the stream
      _postsStream = query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => VolunteerPost.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .where((post) => post.eventDate.isAfter(DateTime.now()))
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

      await FirebaseFirestore.instance
          .collection('volunteer_posts')
          .doc(post.id)
          .update({
        'joinedUsers': FieldValue.arrayUnion([currentUser.uid]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Successfully joined the volunteer activity!')),
      );
    } catch (e) {
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

      if (!post.joinedUsers.contains(currentUser.uid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You have not joined this activity')),
        );
        return;
      }

      // Show confirmation dialog
      final bool confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel Registration'),
          content: const Text('Are you sure you want to cancel your registration for this volunteer activity?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],
        ),
      ) ?? false;

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

  Widget _buildVolunteerCard(VolunteerPost post) {
    final spotsLeft = post.maxVolunteers - post.joinedUsers.length;
    final currentUser = AuthService().currentUser;
    final bool hasJoined = currentUser != null && post.joinedUsers.contains(currentUser.uid);
    final bool isFull = spotsLeft <= 0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title section with teal background
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF00C49A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  post.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$spotsLeft spots left',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Description
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: GestureDetector(
              onTap: () => _showDescriptionDialog(context, post),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Only show 'Tap to read more' if description is longer than ~100 characters
                  // which would likely cause it to be truncated in 2 lines
                  if (post.description.length > 100) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Tap to read more',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF00C49A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Location
                _buildDetailRow(
                  Icons.location_on,
                  post.location,
                ),
                const Divider(height: 16, thickness: 0.5),

                // Date
                _buildDetailRow(
                  Icons.calendar_today,
                  DateFormat('EEEE, MMMM d, yyyy').format(post.eventDate),
                ),
                const Divider(height: 16, thickness: 0.5),

                // Time
                _buildDetailRow(
                  Icons.access_time,
                  post.formattedTime,
                ),
                const Divider(height: 16, thickness: 0.5),

                // Volunteers count
                _buildDetailRow(
                  Icons.people,
                  '${post.joinedUsers.length}/${post.maxVolunteers} volunteers joined',
                  trailing: SizedBox(
                    width: 50,
                    height: 4,
                    child: LinearProgressIndicator(
                      value: post.maxVolunteers > 0
                          ? post.joinedUsers.length / post.maxVolunteers
                          : 0,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        post.joinedUsers.length >= post.maxVolunteers
                            ? Colors.redAccent
                            : const Color(0xFF00C49A),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Join/Cancel button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: hasJoined
                  ? Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _cancelVolunteerPost(context, post),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Cancel Registration',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ElevatedButton(
                      onPressed: isFull ? null : () => _joinVolunteerPost(context, post),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C49A),
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        isFull ? 'Activity Full' : 'Join Activity',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: !isFull ? Colors.white : Colors.grey[600],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Show full description dialog
  void _showDescriptionDialog(BuildContext context, VolunteerPost post) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF00C49A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Text(
                post.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Description content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    post.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // Close button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text, {Widget? trailing}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF00C49A),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 13,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
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
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
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