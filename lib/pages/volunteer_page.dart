import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/volunteer_post.dart';
import 'add_volunteer_post_page.dart';
import '../services/community_service.dart';
import 'package:intl/intl.dart';

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
      
      final community = await _communityService.getUserCommunity(currentUser.uid);
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
          .where('communityId', isEqualTo: _currentUserCommunityId);

      // Create the stream
      _postsStream = query
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => VolunteerPost.fromFirestore(doc))
                .where((post) => post.date.isAfter(DateTime.now()))
                .toList()
              ..sort((a, b) => a.date.compareTo(b.date));
          });

      print("Stream initialized successfully");
    } catch (e) {
      print("Error initializing stream: $e");
    }
  }

  Future<void> _handleNewPost(VolunteerPost post) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _firestore.collection('volunteer_posts').add(post.toMap());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post created successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating post: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signUpForVolunteer(VolunteerPost post) async {
    if (_currentUserCommunityId == null) return;

    try {
      final docRef = _firestore.collection('volunteer_posts').doc(post.id);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        final currentSpotsLeft = snapshot.data()?['spotsLeft'] as int;
        
        if (currentSpotsLeft > 0) {
          transaction.update(docRef, {
            'spotsLeft': currentSpotsLeft - 1,
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully signed up!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No spots left!')),
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing up: $e')),
      );
    }
  }

  Widget _buildVolunteerCard(VolunteerPost post) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Posted ${post.getTimeAgo()}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              post.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 8),
                      Text(DateFormat('MMM dd, yyyy').format(post.date)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 16),
                      const SizedBox(width: 8),
                      Text(post.location),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person, size: 16),
                      const SizedBox(width: 4),
                      Text('${post.spotsLeft} spots left'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: post.spotsLeft > 0
                    ? () => _signUpForVolunteer(post)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C49A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Sign Up to Volunteer'),
              ),
            ),
          ],
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
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF00C49A),
      ),
      body: _currentUserCommunityId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<VolunteerPost>>(
              stream: _postsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final posts = snapshot.data ?? [];

                if (posts.isEmpty) {
                  return const Center(
                    child: Text(
                      'No volunteer opportunities available',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildVolunteerCard(posts[index]),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading || _currentUserCommunityId == null
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddVolunteerPostPage(
                      onPostAdded: _handleNewPost,
                    ),
                  ),
                );
              },
        backgroundColor: const Color(0xFF00C49A),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
