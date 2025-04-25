import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../../models/volunteer_post.dart';
import '../../services/auth_service.dart';
import '../../widgets/admin_scaffold.dart';

class AdminVolunteerPostsPage extends StatefulWidget {
  const AdminVolunteerPostsPage({super.key});

  @override
  State<AdminVolunteerPostsPage> createState() =>
      _AdminVolunteerPostsPageState();
}

class _AdminVolunteerPostsPageState extends State<AdminVolunteerPostsPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxVolunteersController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isCreatingPost = false;

  Future<String?> _getAdminCommunityId() async {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) return null;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (!userDoc.exists) return null;

    final userData = userDoc.data()!;
    return userData['communityId'] as String;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _maxVolunteersController.dispose();
    super.dispose();
  }

  Future<void> _createVolunteerPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreatingPost = true;
    });

    final currentUser = AuthService().currentUser;
    if (currentUser == null) {
      setState(() {
        _isCreatingPost = false;
      });
      return;
    }

    // Get admin's community ID
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (!userDoc.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User data not found')),
        );
        setState(() {
          _isCreatingPost = false;
        });
      }
      return;
    }

    final userData = userDoc.data()!;
    final communityId = userData['communityId'] as String;

    // Create DateTime with both date and time components
    final eventDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final post = VolunteerPost(
      id: '',
      title: _titleController.text,
      description: _descriptionController.text,
      adminId: currentUser.uid,
      adminName: currentUser.displayName ?? 'Admin',
      date: DateTime.now(),
      eventDate: eventDateTime,
      location: _locationController.text,
      maxVolunteers: int.parse(_maxVolunteersController.text),
      joinedUsers: [],
      communityId: communityId,
    );

    try {
      await FirebaseFirestore.instance
          .collection('volunteer_posts')
          .add(post.toMap());

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Volunteer post created successfully!'),
            backgroundColor: Color(0xFF00C49A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingPost = false;
        });
      }
    }
  }

  Future<void> _deletePost(String postId, String title) async {
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post?'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('volunteer_posts')
          .doc(postId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted successfully'),
            backgroundColor: Color(0xFF00C49A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting post: $e')),
        );
      }
    }
  }

  void _showCreatePostDialog({bool keepExistingValues = false, BuildContext? context}) {
    final currentContext = context ?? this.context;
    if (!keepExistingValues) {
      // Only clear values if we're not keeping existing values
      _titleController.clear();
      _descriptionController.clear();
      _locationController.clear();
      _maxVolunteersController.text = "1"; // Default value
      _selectedDate =
          DateTime.now().add(const Duration(days: 1)); // Default to tomorrow
      _selectedTime = const TimeOfDay(hour: 9, minute: 0); // Default to 9 AM
    }

    showDialog(
      context: currentContext,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Create Volunteer Post',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Flexible(
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFormField(
                            label: 'Title',
                            controller: _titleController,
                            hintText: 'Tree Planting',
                            validator: (value) => value?.isEmpty ?? true
                                ? 'Please enter a title'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'Description',
                            controller: _descriptionController,
                            hintText:
                                'Join us for a community tree planting event...',
                            maxLines: 3,
                            validator: (value) => value?.isEmpty ?? true
                                ? 'Please enter a description'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateField(
                                  label: 'Date',
                                  value: DateFormat('MM/dd/yyyy')
                                      .format(_selectedDate),
                                  icon: Icons.calendar_today,
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedDate,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now()
                                          .add(const Duration(days: 365)),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme:
                                                const ColorScheme.light(
                                              primary: Color(0xFF00C49A),
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (date != null && mounted) {
                                      setState(() => _selectedDate = date);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDateField(
                                  label: 'Time',
                                  value: _selectedTime.format(context),
                                  icon: Icons.access_time,
                                  onTap: () async {
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: _selectedTime,
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme:
                                                const ColorScheme.light(
                                              primary: Color(0xFF00C49A),
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (time != null && mounted) {
                                      setState(() => _selectedTime = time);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'Location',
                            controller: _locationController,
                            hintText: 'Barangay Pulse',
                            validator: (value) => value?.isEmpty ?? true
                                ? 'Please enter a location'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'Maximum Volunteers',
                            controller: _maxVolunteersController,
                            hintText: '1',
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'Please enter maximum volunteers';
                              }
                              if (int.tryParse(value!) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isCreatingPost
                                      ? null
                                      : () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    side:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isCreatingPost
                                      ? null
                                      : _createVolunteerPost,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00C49A),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isCreatingPost
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          'Create Post',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Color(0xFF4A5568),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF00C49A)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Color(0xFF4A5568),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                Icon(icon, size: 16, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Manage Volunteer Posts',
      appBar: AppBar(
        title: const Text(
          'Manage Volunteer Posts',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF00C49A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<String?>(
        stream: Stream.fromFuture(_getAdminCommunityId()),
        builder: (context, communitySnapshot) {
          if (communitySnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
              ),
            );
          }

          final communityId = communitySnapshot.data;
          if (communityId == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Could not find community ID',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF4A5568),
                    ),
                  ),
                ],
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('volunteer_posts')
                .where('communityId', isEqualTo: communityId)
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading posts',
                    style: TextStyle(color: Colors.grey.shade700),
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

              final posts = snapshot.data?.docs ?? [];

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
                        'No volunteer posts yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first volunteer post',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showCreatePostDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Create Post'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C49A),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: posts.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final post = VolunteerPost.fromMap(
                    posts[index].data() as Map<String, dynamic>,
                    posts[index].id,
                  );

                  final isPastEvent = post.eventDate.isBefore(DateTime.now());

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isPastEvent
                                ? Colors.grey.shade300
                                : const Color(0xFF00C49A),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  post.title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    decoration: isPastEvent
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  if (isPastEvent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Past',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  // Edit button
                                  Tooltip(
                                    message: 'Edit post',
                                    child: GestureDetector(
                                      onTap: () => _showEditPostDialog(post),
                                      child: const Icon(
                                        Icons.edit_outlined,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Reuse button for past events
                                  if (isPastEvent)
                                    Tooltip(
                                      message: 'Reuse post for a new event',
                                      child: GestureDetector(
                                        onTap: () => _reuseVolunteerPost(post),
                                        child: const Icon(
                                          Icons.refresh_outlined,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  if (isPastEvent) const SizedBox(width: 8),
                                  // Delete button
                                  Tooltip(
                                    message: 'Delete post',
                                    child: GestureDetector(
                                      onTap: () =>
                                          _deletePost(post.id, post.title),
                                      child: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
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
                              const SizedBox(height: 16),
                              _buildPostDetailRow(
                                icon: Icons.location_on,
                                text: post.location,
                              ),
                              const Divider(height: 16, thickness: 0.5),
                              _buildPostDetailRow(
                                icon: Icons.calendar_today,
                                text: DateFormat('EEEE, MMMM d, yyyy')
                                    .format(post.eventDate),
                              ),
                              const Divider(height: 16, thickness: 0.5),
                              _buildPostDetailRow(
                                icon: Icons.access_time,
                                text: post.formattedTime,
                              ),
                              const Divider(height: 16, thickness: 0.5),
                              _buildPostDetailRow(
                                icon: Icons.people,
                                text:
                                    '${post.joinedUsers.length}/${post.maxVolunteers} volunteers',
                                trailing: Row(
                                  children: [
                                    SizedBox(
                                      width: 50,
                                      height: 4,
                                      child: LinearProgressIndicator(
                                        value: post.maxVolunteers > 0
                                            ? post.joinedUsers.length /
                                                post.maxVolunteers
                                            : 0,
                                        backgroundColor: Colors.grey[200],
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          post.joinedUsers.length >=
                                                  post.maxVolunteers
                                              ? Colors.redAccent
                                              : const Color(0xFF00C49A),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Tooltip(
                                      message: 'View interested volunteers',
                                      child: IconButton(
                                        icon: const Icon(Icons.visibility, size: 18),
                                        color: const Color(0xFF00C49A),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _showInterestedUsers(post),
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
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePostDialog,
        backgroundColor: const Color(0xFF00C49A),
        elevation: 2,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPostDetailRow({
    required IconData icon,
    required String text,
    Widget? trailing,
  }) {
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

  Future<void> _showInterestedUsers(VolunteerPost post) async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF00C49A),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Interested Volunteers (${post.joinedUsers.length}/${post.maxVolunteers})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: post.joinedUsers.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No volunteers yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'When users join this volunteer post, they will appear here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : FutureBuilder<List<Map<String, dynamic>>>(
                        future: _fetchVolunteerUsers(post.joinedUsers),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF00C49A)),
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 48,
                                      color: Colors.red.shade300,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Error loading volunteers',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Please try again later.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final users = snapshot.data ?? [];

                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: users.length,
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                            ),
                            itemBuilder: (context, index) {
                              final user = users[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF00C49A).withOpacity(0.1),
                                  backgroundImage: user['profileImageUrl'] != null
                                      ? NetworkImage(user['profileImageUrl'])
                                      : null,
                                  child: user['profileImageUrl'] == null
                                      ? Text(
                                          user['fullName']?.isNotEmpty == true
                                              ? user['fullName'][0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Color(0xFF00C49A),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  user['fullName'] ?? 'Unknown User',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(user['email'] ?? 'No email'),
                                    if (user['mobile'] != null && user['mobile'].isNotEmpty)
                                      Text(user['mobile']),
                                  ],
                                ),
                                isThreeLine: user['mobile'] != null && user['mobile'].isNotEmpty,
                                dense: true,
                              );
                            },
                          );
                        },
                      ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  'Volunteer post: ${post.title}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchVolunteerUsers(List<String> userIds) async {
    try {
      final List<Map<String, dynamic>> users = [];

      // Fetch user data for each user ID
      for (final userId in userIds) {
        // First try to get user from Firestore (admin users)
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          users.add(userData);
        } else {
          // If not found in Firestore, try RTDB (regular users)
          try {
            final rtdbSnapshot = await FirebaseDatabase.instance
                .ref()
                .child('users/$userId')
                .get();

            if (rtdbSnapshot.exists) {
              final rtdbData = rtdbSnapshot.value as Map<dynamic, dynamic>;

              // Get user's name (handle both formats)
              String fullName = '';
              if (rtdbData['firstName'] != null && rtdbData['lastName'] != null) {
                fullName = rtdbData['middleName'] != null &&
                        rtdbData['middleName'].toString().isNotEmpty
                    ? '${rtdbData['firstName']} ${rtdbData['middleName']} ${rtdbData['lastName']}'
                    : '${rtdbData['firstName']} ${rtdbData['lastName']}';
              } else if (rtdbData['fullName'] != null) {
                fullName = rtdbData['fullName'];
              } else {
                fullName = 'User $userId';
              }

              users.add({
                'fullName': fullName,
                'email': rtdbData['email'] ?? '',
                'mobile': rtdbData['mobile'] ?? '',
                'profileImageUrl': rtdbData['profileImageUrl'],
              });
            } else {
              // Add placeholder for users that don't exist
              users.add({
                'fullName': 'Unknown User',
                'email': 'User not found',
                'mobile': '',
                'profileImageUrl': null,
              });
            }
          } catch (rtdbError) {
            debugPrint('Error fetching user from RTDB: $rtdbError');
            // Add placeholder for users that don't exist
            users.add({
              'fullName': 'Unknown User',
              'email': 'User not found',
              'mobile': '',
              'profileImageUrl': null,
            });
          }
        }
      }

      return users;
    } catch (e) {
      debugPrint('Error fetching volunteer users: $e');
      return [];
    }
  }

  void _showEditPostDialog(VolunteerPost post) {
    // Initialize controllers with existing post data
    _titleController.text = post.title;
    _descriptionController.text = post.description;
    _locationController.text = post.location;
    _maxVolunteersController.text = post.maxVolunteers.toString();
    _selectedDate = post.eventDate;
    _selectedTime = TimeOfDay(hour: post.eventDate.hour, minute: post.eventDate.minute);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Volunteer Post',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Flexible(
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFormField(
                            label: 'Title',
                            controller: _titleController,
                            hintText: 'Tree Planting',
                            validator: (value) => value?.isEmpty ?? true
                                ? 'Please enter a title'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'Description',
                            controller: _descriptionController,
                            hintText:
                                'Join us for a community tree planting event...',
                            maxLines: 3,
                            validator: (value) => value?.isEmpty ?? true
                                ? 'Please enter a description'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateField(
                                  label: 'Date',
                                  value: DateFormat('MM/dd/yyyy')
                                      .format(_selectedDate),
                                  icon: Icons.calendar_today,
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedDate,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now()
                                          .add(const Duration(days: 365)),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme:
                                                const ColorScheme.light(
                                              primary: Color(0xFF00C49A),
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (date != null && mounted) {
                                      setState(() => _selectedDate = date);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDateField(
                                  label: 'Time',
                                  value: _selectedTime.format(context),
                                  icon: Icons.access_time,
                                  onTap: () async {
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: _selectedTime,
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme:
                                                const ColorScheme.light(
                                              primary: Color(0xFF00C49A),
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (time != null && mounted) {
                                      setState(() => _selectedTime = time);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'Location',
                            controller: _locationController,
                            hintText: 'Barangay Pulse',
                            validator: (value) => value?.isEmpty ?? true
                                ? 'Please enter a location'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: 'Maximum Volunteers',
                            controller: _maxVolunteersController,
                            hintText: '1',
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'Please enter maximum volunteers';
                              }
                              if (int.tryParse(value!) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isCreatingPost
                                      ? null
                                      : () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    side:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isCreatingPost
                                      ? null
                                      : () => _editVolunteerPost(post.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00C49A),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isCreatingPost
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          'Save Changes',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editVolunteerPost(String postId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreatingPost = true;
    });

    try {
      // Create DateTime with both date and time components
      final eventDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Update the post in Firestore
      await FirebaseFirestore.instance
          .collection('volunteer_posts')
          .doc(postId)
          .update({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'location': _locationController.text,
        'eventDate': eventDateTime,
        'maxVolunteers': int.parse(_maxVolunteersController.text),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Volunteer post updated successfully!'),
            backgroundColor: Color(0xFF00C49A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingPost = false;
        });
      }
    }
  }

  Future<void> _reuseVolunteerPost(VolunteerPost post) async {
    // Show confirmation dialog
    final shouldReuse = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reuse Post?'),
        content: Text('Do you want to reuse "${post.title}" for a new event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF00C49A),
            ),
            child: const Text('Reuse'),
          ),
        ],
      ),
    );

    if (shouldReuse != true) return;

    // Pre-fill the form with the post data
    _titleController.text = post.title;
    _descriptionController.text = post.description;
    _locationController.text = post.location;
    _maxVolunteersController.text = post.maxVolunteers.toString();

    // Set default date to tomorrow
    _selectedDate = DateTime.now().add(const Duration(days: 1));

    // Keep the same time from the original post
    _selectedTime = TimeOfDay(hour: post.eventDate.hour, minute: post.eventDate.minute);

    // Show the create post dialog with existing values
    _showCreatePostDialog(keepExistingValues: true);
  }
}
