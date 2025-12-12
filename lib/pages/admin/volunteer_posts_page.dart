import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/volunteer_post.dart';
import '../../services/auth_service.dart';
import '../../widgets/admin_scaffold.dart';

class AdminVolunteerPostsPage extends StatefulWidget {
  const AdminVolunteerPostsPage({super.key});

  @override
  State<AdminVolunteerPostsPage> createState() =>
      _AdminVolunteerPostsPageState();
}

class _AdminVolunteerPostsPageState extends State<AdminVolunteerPostsPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxVolunteersController = TextEditingController();
  
  // Start date/time fields
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  
  // End date/time fields
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  
  bool _isCreatingPost = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

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
    _tabController.dispose();
    super.dispose();
  }

  /// Records permanent participation for users when a volunteer post transitions to ongoing or done
  Future<void> _recordPermanentParticipation(VolunteerPost post) async {
    if (post.joinedUsers.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();

    for (final userId in post.joinedUsers) {
      // Create a unique document ID based on post and user
      final participationDocId = '${post.id}_$userId';
      final participationRef = FirebaseFirestore.instance
          .collection('volunteer_participation_records')
          .doc(participationDocId);

      // Only add if it doesn't exist (idempotent operation)
      batch.set(
        participationRef,
        {
          'userId': userId,
          'postId': post.id,
          'postTitle': post.title,
          'communityId': post.communityId,
          'eventDate': post.eventDate,
          'recordedAt': FieldValue.serverTimestamp(),
          'status': post.status.name,
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
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

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final endDateTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    // Validate that end date is after start date
    if (endDateTime.isBefore(startDateTime)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End date must be after start date'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isCreatingPost = false;
        });
      }
      return;
    }

    final post = VolunteerPost(
      id: '',
      title: _titleController.text,
      description: _descriptionController.text,
      adminId: currentUser.uid,
      adminName: currentUser.displayName ?? 'Admin',
      date: DateTime.now(),
      startDate: startDateTime,
      endDate: endDateTime,
      location: _locationController.text,
      maxVolunteers: int.parse(_maxVolunteersController.text),
      joinedUsers: [],
      communityId: communityId,
    );

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('volunteer_posts')
          .add(post.toMap());

      await docRef.update({'id': docRef.id});

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
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  Icons.delete_outline_rounded,
                  color: Colors.red[400],
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Delete Post?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to delete "$title"? This action cannot be undone, but participation records will be preserved.',
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
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.grey[50],
                      ),
                      child: Text(
                        'Cancel',
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
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Delete',
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

  void _showPostFormSheet(
      {VolunteerPost? post, bool keepExistingValues = false}) {
    if (post != null) {
      // Edit mode
      _titleController.text = post.title;
      _descriptionController.text = post.description;
      _locationController.text = post.location;
      _maxVolunteersController.text = post.maxVolunteers.toString();
      _startDate = post.startDate;
      _startTime = TimeOfDay(hour: post.startDate.hour, minute: post.startDate.minute);
      _endDate = post.endDate;
      _endTime = TimeOfDay(hour: post.endDate.hour, minute: post.endDate.minute);
    } else if (!keepExistingValues) {
      // Create mode - clear values
      _titleController.clear();
      _descriptionController.clear();
      _locationController.clear();
      _maxVolunteersController.text = "1";
      _startDate = DateTime.now().add(const Duration(days: 1));
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endDate = DateTime.now().add(const Duration(days: 1));
      _endTime = const TimeOfDay(hour: 17, minute: 0);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
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
                // Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        post != null
                            ? 'Edit Volunteer Post'
                            : 'Create Volunteer Post',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A202C),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Form
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(24),
                    children: [
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFormField(
                              label: 'Title',
                              controller: _titleController,
                              hintText: 'e.g. Tree Planting Activity',
                              validator: (value) => value?.isEmpty ?? true
                                  ? 'Please enter a title'
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            _buildFormField(
                              label: 'Description',
                              controller: _descriptionController,
                              hintText:
                                  'Describe the activity, requirements, and other important details...',
                              minLines: 3,
                              maxLines: 8,
                              validator: (value) => value?.isEmpty ?? true
                                  ? 'Please enter a description'
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            // Start Date/Time Section
                            Container(
                              padding: const EdgeInsets.all(16),
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
                                        size: 18,
                                        color: Color(0xFF3B82F6),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Start Date & Time',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Color(0xFF3B82F6),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDateField(
                                          label: 'Date',
                                          value: DateFormat('MMM d, yyyy').format(_startDate),
                                          icon: Icons.calendar_today_rounded,
                                          onTap: () async {
                                            final date = await showDatePicker(
                                              context: context,
                                              initialDate: _startDate,
                                              firstDate: DateTime.now(),
                                              lastDate: DateTime.now().add(const Duration(days: 365)),
                                              builder: (context, child) {
                                                return Theme(
                                                  data: Theme.of(context).copyWith(
                                                    colorScheme: const ColorScheme.light(
                                                      primary: Color(0xFF00C49A),
                                                      onPrimary: Colors.white,
                                                      onSurface: Color(0xFF1A202C),
                                                    ),
                                                  ),
                                                  child: child!,
                                                );
                                              },
                                            );
                                            if (date != null) {
                                              setModalState(() {
                                                _startDate = date;
                                                // Auto-update end date if it's before start date
                                                if (_endDate.isBefore(date)) {
                                                  _endDate = date;
                                                }
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildDateField(
                                          label: 'Time',
                                          value: _startTime.format(context),
                                          icon: Icons.access_time_rounded,
                                          onTap: () async {
                                            final time = await showTimePicker(
                                              context: context,
                                              initialTime: _startTime,
                                              builder: (context, child) {
                                                return Theme(
                                                  data: Theme.of(context).copyWith(
                                                    colorScheme: const ColorScheme.light(
                                                      primary: Color(0xFF00C49A),
                                                      onPrimary: Colors.white,
                                                      onSurface: Color(0xFF1A202C),
                                                    ),
                                                  ),
                                                  child: child!,
                                                );
                                              },
                                            );
                                            if (time != null) {
                                              setModalState(() => _startTime = time);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // End Date/Time Section
                            Container(
                              padding: const EdgeInsets.all(16),
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
                                        size: 18,
                                        color: Color(0xFF10B981),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'End Date & Time',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDateField(
                                          label: 'Date',
                                          value: DateFormat('MMM d, yyyy').format(_endDate),
                                          icon: Icons.calendar_today_rounded,
                                          onTap: () async {
                                            final date = await showDatePicker(
                                              context: context,
                                              initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
                                              firstDate: _startDate,
                                              lastDate: DateTime.now().add(const Duration(days: 365)),
                                              builder: (context, child) {
                                                return Theme(
                                                  data: Theme.of(context).copyWith(
                                                    colorScheme: const ColorScheme.light(
                                                      primary: Color(0xFF00C49A),
                                                      onPrimary: Colors.white,
                                                      onSurface: Color(0xFF1A202C),
                                                    ),
                                                  ),
                                                  child: child!,
                                                );
                                              },
                                            );
                                            if (date != null) {
                                              setModalState(() => _endDate = date);
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildDateField(
                                          label: 'Time',
                                          value: _endTime.format(context),
                                          icon: Icons.access_time_rounded,
                                          onTap: () async {
                                            final time = await showTimePicker(
                                              context: context,
                                              initialTime: _endTime,
                                              builder: (context, child) {
                                                return Theme(
                                                  data: Theme.of(context).copyWith(
                                                    colorScheme: const ColorScheme.light(
                                                      primary: Color(0xFF00C49A),
                                                      onPrimary: Colors.white,
                                                      onSurface: Color(0xFF1A202C),
                                                    ),
                                                  ),
                                                  child: child!,
                                                );
                                              },
                                            );
                                            if (time != null) {
                                              setModalState(() => _endTime = time);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildFormField(
                              label: 'Location',
                              controller: _locationController,
                              hintText: 'e.g. Barangay Hall',
                              icon: Icons.location_on_outlined,
                              validator: (value) => value?.isEmpty ?? true
                                  ? 'Please enter a location'
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            _buildFormField(
                              label: 'Maximum Volunteers',
                              controller: _maxVolunteersController,
                              hintText: 'e.g. 20',
                              keyboardType: TextInputType.number,
                              icon: Icons.people_outline,
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
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isCreatingPost
                                    ? null
                                    : () => post != null
                                        ? _editVolunteerPost(post.id)
                                        : _createVolunteerPost(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00C49A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isCreatingPost
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : Text(
                                        post != null
                                            ? 'Save Changes'
                                            : 'Create Post',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey[600],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                                height:
                                    MediaQuery.of(context).viewInsets.bottom),
                          ],
                        ),
                      ),
                    ],
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
    int minLines = 1,
    TextInputType? keyboardType,
    IconData? icon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: icon != null
                ? Icon(icon, color: Colors.grey.shade400, size: 20)
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF00C49A), width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          minLines: minLines,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 15),
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
          'Manage Volunteers',
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
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () => _showTopEngagedUsersSheet(),
            tooltip: 'Top Volunteers',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Ongoing'),
            Tab(text: 'Done'),
          ],
        ),
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

          return TabBarView(
            controller: _tabController,
            children: [
              _buildPostsTab(communityId, null), // All posts
              _buildPostsTab(communityId, VolunteerPostStatus.ongoing),
              _buildPostsTab(communityId, VolunteerPostStatus.done),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPostFormSheet(),
        backgroundColor: const Color(0xFF00C49A),
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPostsTab(String communityId, VolunteerPostStatus? filterStatus) {
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
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
            ),
          );
        }

        final allPosts = snapshot.data?.docs ?? [];
        
        // Convert to VolunteerPost objects and filter by computed status
        final allPostObjects = allPosts.map((doc) {
          return VolunteerPost.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          );
        }).toList();

        // Auto-record participation for posts that have transitioned
        _checkAndRecordParticipation(allPostObjects);

        // Filter by computed status (based on dates)
        final filteredPosts = filterStatus == null
            ? allPostObjects
            : allPostObjects.where((post) => post.status == filterStatus).toList();

        final posts = filteredPosts;

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  filterStatus == VolunteerPostStatus.ongoing
                      ? Icons.play_circle_outline_rounded
                      : filterStatus == VolunteerPostStatus.done
                          ? Icons.check_circle_outline_rounded
                          : Icons.volunteer_activism,
                  size: 48,
                  color: const Color(0xFF00C49A).withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  filterStatus == VolunteerPostStatus.ongoing
                      ? 'No ongoing activities'
                      : filterStatus == VolunteerPostStatus.done
                          ? 'No completed activities'
                          : 'No volunteer posts yet',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  filterStatus == null
                      ? 'Create your first volunteer post'
                      : 'Posts will appear here when status changes',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                if (filterStatus == null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showPostFormSheet(),
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
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: posts.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            return _buildPostCard(posts[index]);
          },
        );
      },
    );
  }

  /// Check and auto-record participation for posts that have transitioned to ongoing/done
  Future<void> _checkAndRecordParticipation(List<VolunteerPost> posts) async {
    for (final post in posts) {
      // Check if participation should be recorded (ongoing or done, and not already recorded)
      if (post.shouldRecordParticipation) {
        await _recordPermanentParticipation(post);
        // Mark as recorded in Firestore
        try {
          await FirebaseFirestore.instance
              .collection('volunteer_posts')
              .doc(post.id)
              .update({'participationRecorded': true});
        } catch (e) {
          debugPrint('Error updating participationRecorded: $e');
        }
      }
    }
  }

  Widget _buildPostCard(VolunteerPost post) {
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
                      Row(
                        children: [
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
                        ],
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
                _buildActionButtons(post),
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
                
                // Date/Time Info Row
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
                              Icon(
                                Icons.play_circle_outline_rounded,
                                size: 16,
                                color: const Color(0xFF3B82F6),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${DateFormat('MMM d, yyyy').format(post.startDate)} • ${post.formattedStartTime}',
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
                              Icon(
                                Icons.stop_circle_outlined,
                                size: 16,
                                color: const Color(0xFF10B981),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${DateFormat('MMM d, yyyy').format(post.endDate)} • ${post.formattedEndTime}',
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
                const SizedBox(height: 20),

                // Description
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    post.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

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
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00C49A),
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
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF00C49A),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Bottom Buttons Row
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () => _showInterestedUsers(post),
                          style: OutlinedButton.styleFrom(
                            side:
                                const BorderSide(color: Color(0xFF00C49A)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.people_outline,
                              color: Color(0xFF00C49A), size: 18),
                          label: const Text(
                            'Volunteers',
                            style: TextStyle(
                              color: Color(0xFF00C49A),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Auto Status Indicator (status is now automatic based on dates)
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: _getStatusColor(post.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _getStatusColor(post.status)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(post.status),
                            size: 18,
                            color: _getStatusColor(post.status),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            post.statusLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(post.status),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getHeaderGradient(VolunteerPostStatus status) {
    switch (status) {
      case VolunteerPostStatus.upcoming:
        return [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)];
      case VolunteerPostStatus.ongoing:
        return [const Color(0xFFF59E0B), const Color(0xFFD97706)];
      case VolunteerPostStatus.done:
        return [const Color(0xFF10B981), const Color(0xFF059669)];
    }
  }

  Widget _buildActionButtons(VolunteerPost post) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.white, size: 20),
          onPressed: () => _showPostFormSheet(post: post),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 12),
        if (post.status == VolunteerPostStatus.done) ...[
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
            onPressed: () => _reuseVolunteerPost(post),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Reuse Post',
          ),
          const SizedBox(width: 12),
        ],
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
          onPressed: () => _deletePost(post.id, post.title),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  /// Show Top Engaged Users modal sheet
  Future<void> _showTopEngagedUsersSheet() async {
    final communityId = await _getAdminCommunityId();
    if (communityId == null) return;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
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
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Top Engaged Volunteers',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A202C),
                            ),
                          ),
                          Text(
                            'Based on completed/ongoing activities',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: _buildTopEngagedUsersList(communityId, controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopEngagedUsersList(
      String communityId, ScrollController controller) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('volunteer_participation_records')
          .where('communityId', isEqualTo: communityId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading data',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        final participationRecords = snapshot.data?.docs ?? [];

        if (participationRecords.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No participation records yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Records appear when posts are marked ongoing or done',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        // Aggregate participation counts by user
        final Map<String, int> userParticipationCounts = {};
        for (final doc in participationRecords) {
          final data = doc.data() as Map<String, dynamic>;
          final userId = data['userId'] as String;
          userParticipationCounts[userId] =
              (userParticipationCounts[userId] ?? 0) + 1;
        }

        // Sort by count descending
        final sortedUsers = userParticipationCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        // Get top 20 users
        final topUsers = sortedUsers.take(20).toList();

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchTopUsersDetails(topUsers),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
                ),
              );
            }

            final users = userSnapshot.data ?? [];

            return ListView.builder(
              controller: controller,
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final rank = index + 1;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: rank <= 3
                          ? _getRankColor(rank).withOpacity(0.3)
                          : Colors.grey.shade200,
                      width: rank <= 3 ? 2 : 1,
                    ),
                    boxShadow: rank <= 3
                        ? [
                            BoxShadow(
                              color: _getRankColor(rank).withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Rank Badge
                      _buildRankBadge(rank),
                      const SizedBox(width: 16),
                      // Avatar
                      CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            const Color(0xFF00C49A).withOpacity(0.1),
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
                                  fontSize: 18,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      // User Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['fullName'] ?? 'Unknown User',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Color(0xFF2D3748),
                              ),
                            ),
                            if (user['email'] != null)
                              Text(
                                user['email'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      // Participation Count
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C49A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.volunteer_activism,
                              size: 16,
                              color: Color(0xFF00C49A),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${user['count']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF00C49A),
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
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.grey;
    }
  }

  Widget _buildRankBadge(int rank) {
    if (rank <= 3) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _getRankColor(rank),
              _getRankColor(rank).withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _getRankColor(rank).withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: rank == 1
              ? const Icon(Icons.emoji_events, color: Colors.white, size: 20)
              : Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
        ),
      );
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$rank',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTopUsersDetails(
      List<MapEntry<String, int>> topUsers) async {
    final List<Map<String, dynamic>> users = [];

    for (final entry in topUsers) {
      final userId = entry.key;
      final count = entry.value;

      // Try Firestore first
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        users.add({
          ...userData,
          'count': count,
        });
      } else {
        // Try RTDB
        try {
          final rtdbSnapshot = await FirebaseDatabase.instance
              .ref()
              .child('users/$userId')
              .get();

          if (rtdbSnapshot.exists) {
            final rtdbData = rtdbSnapshot.value as Map<dynamic, dynamic>;

            String fullName = '';
            if (rtdbData['firstName'] != null && rtdbData['lastName'] != null) {
              fullName = rtdbData['middleName'] != null &&
                      rtdbData['middleName'].toString().isNotEmpty
                  ? '${rtdbData['firstName']} ${rtdbData['middleName']} ${rtdbData['lastName']}'
                  : '${rtdbData['firstName']} ${rtdbData['lastName']}';
            } else if (rtdbData['fullName'] != null) {
              fullName = rtdbData['fullName'];
            } else {
              fullName = 'User';
            }

            users.add({
              'fullName': fullName,
              'email': rtdbData['email'] ?? '',
              'profileImageUrl': rtdbData['profileImageUrl'],
              'count': count,
            });
          } else {
            users.add({
              'fullName': 'Unknown User',
              'email': '',
              'profileImageUrl': null,
              'count': count,
            });
          }
        } catch (e) {
          users.add({
            'fullName': 'Unknown User',
            'email': '',
            'profileImageUrl': null,
            'count': count,
          });
        }
      }
    }

    return users;
  }

  Future<void> _showInterestedUsers(VolunteerPost post) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
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
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C49A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.people_rounded,
                        color: Color(0xFF00C49A),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Interested Volunteers',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A202C),
                            ),
                          ),
                          Text(
                            '${post.joinedUsers.length} of ${post.maxVolunteers} joined',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        if (post.joinedUsers.isNotEmpty)
                          IconButton(
                            icon: const Icon(
                              Icons.picture_as_pdf_rounded,
                              color: Color(0xFF00C49A),
                            ),
                            onPressed: () => _generateVolunteersPDF(post),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Export to PDF',
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: post.joinedUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              size: 64,
                              color: Colors.grey.shade300,
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
                              'Users who join will appear here',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
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
                              child: Text(
                                'Error loading volunteers',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            );
                          }

                          final users = snapshot.data ?? [];

                          return ListView.separated(
                            controller: controller,
                            padding: const EdgeInsets.all(16),
                            itemCount: users.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final user = users[index];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: const Color(0xFF00C49A)
                                          .withOpacity(0.1),
                                      backgroundImage: user['profileImageUrl'] !=
                                              null
                                          ? NetworkImage(
                                              user['profileImageUrl'])
                                          : null,
                                      child: user['profileImageUrl'] == null
                                          ? Text(
                                              user['fullName']?.isNotEmpty ==
                                                      true
                                                  ? user['fullName'][0]
                                                      .toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                color: Color(0xFF00C49A),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user['fullName'] ?? 'Unknown User',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                              color: Color(0xFF2D3748),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (user['email'] != null)
                                            Row(
                                              children: [
                                                Icon(Icons.email_outlined,
                                                    size: 14,
                                                    color: Colors.grey[500]),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    user['email'],
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey[600],
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (user['mobile'] != null &&
                                              user['mobile'].isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(Icons.phone_outlined,
                                                    size: 14,
                                                    color: Colors.grey[500]),
                                                const SizedBox(width: 4),
                                                Text(
                                                  user['mobile'],
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchVolunteerUsers(
      List<String> userIds) async {
    try {
      final List<Map<String, dynamic>> users = [];

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

              String fullName = '';
              if (rtdbData['firstName'] != null &&
                  rtdbData['lastName'] != null) {
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
              users.add({
                'fullName': 'Unknown User',
                'email': 'User not found',
                'mobile': '',
                'profileImageUrl': null,
              });
            }
          } catch (rtdbError) {
            debugPrint('Error fetching user from RTDB: $rtdbError');
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

  Future<void> _generateVolunteersPDF(VolunteerPost post) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
        ),
      ),
    );

    try {
      // Fetch volunteer details
      final users = await _fetchVolunteerUsers(post.joinedUsers);

      // Fetch community/barangay name from Realtime Database
      String barangayName = 'Community';
      try {
        final communitySnapshot = await FirebaseDatabase.instance
            .ref()
            .child('communities/${post.communityId}')
            .get();
        if (communitySnapshot.exists) {
          final data = communitySnapshot.value as Map<dynamic, dynamic>;
          // Extract barangay name from community name (e.g., "NIOG II Community" -> "NIOG II")
          String communityName = data['name']?.toString() ?? 'Community';
          // Remove "Community" suffix if present for cleaner display
          if (communityName.toLowerCase().endsWith(' community')) {
            communityName = communityName.substring(0, communityName.length - 10).trim();
          }
          barangayName = 'Barangay $communityName';
        }
      } catch (e) {
        debugPrint('Error fetching community name: $e');
      }

      // Create PDF document
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (context) => _buildPDFHeader(post, barangayName),
          footer: (context) => _buildPDFFooter(context),
          build: (context) => [
            pw.SizedBox(height: 20),
            _buildPDFEventDetails(post),
            pw.SizedBox(height: 30),
            _buildPDFVolunteersTable(users),
          ],
        ),
      );

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show print/share dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Volunteers_${post.title.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(post.eventDate)}',
      );
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Widget _buildPDFHeader(VolunteerPost post, String barangayName) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 20),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColors.teal,
            width: 2,
          ),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  'VOLUNTEER LIST',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal700,
                  ),
                ),
              ),
              pw.Text(
                barangayName,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            post.title,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFEventDetails(VolunteerPost post) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'EVENT DETAILS',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.teal700,
              letterSpacing: 1,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildPDFDetailItem(
                  'Date',
                  DateFormat('EEEE, MMMM d, yyyy').format(post.eventDate),
                ),
              ),
              pw.Expanded(
                child: _buildPDFDetailItem(
                  'Time',
                  post.formattedTime,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          _buildPDFDetailItem(
            'Location',
            post.location,
          ),
          pw.SizedBox(height: 12),
          _buildPDFDetailItem(
            'Description',
            post.description,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFDetailItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey600,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: const pw.TextStyle(
            fontSize: 12,
            color: PdfColors.grey800,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPDFVolunteersTable(List<Map<String, dynamic>> users) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'REGISTERED VOLUNTEERS',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.teal700,
            letterSpacing: 1,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(
            color: PdfColors.grey300,
            width: 0.5,
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(0.5),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(1.5),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfColors.teal700,
              ),
              children: [
                _buildTableCell('#', isHeader: true),
                _buildTableCell('Full Name', isHeader: true),
                _buildTableCell('Email', isHeader: true),
                _buildTableCell('Contact No.', isHeader: true),
              ],
            ),
            // Data rows
            ...users.asMap().entries.map((entry) {
              final index = entry.key;
              final user = entry.value;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: index % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                ),
                children: [
                  _buildTableCell('${index + 1}'),
                  _buildTableCell(user['fullName'] ?? 'Unknown'),
                  _buildTableCell(user['email'] ?? '-'),
                  _buildTableCell(user['mobile']?.isNotEmpty == true ? user['mobile'] : '-'),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.grey800,
        ),
      ),
    );
  }

  pw.Widget _buildPDFFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            color: PdfColors.grey300,
            width: 0.5,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated on ${DateFormat('MMM d, yyyy \'at\' h:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey500,
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editVolunteerPost(String postId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreatingPost = true;
    });

    try {
      final startDateTime = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final endDateTime = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      // Validate that end date is after start date
      if (endDateTime.isBefore(startDateTime)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('End date must be after start date'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isCreatingPost = false;
          });
        }
        return;
      }

      await FirebaseFirestore.instance
          .collection('volunteer_posts')
          .doc(postId)
          .update({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'location': _locationController.text,
        'startDate': startDateTime,
        'endDate': endDateTime,
        'eventDate': startDateTime, // Keep for backward compatibility
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
    final shouldReuse = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  color: const Color(0xFF00C49A).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFF00C49A),
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Reuse Post?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Do you want to reuse "${post.title}" for a new event? This will create a new post with the same details.',
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
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.grey[50],
                      ),
                      child: Text(
                        'Cancel',
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
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C49A),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Reuse',
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
    );

    if (shouldReuse != true) return;

    // Pre-fill the form with the post data
    _titleController.text = post.title;
    _descriptionController.text = post.description;
    _locationController.text = post.location;
    _maxVolunteersController.text = post.maxVolunteers.toString();

    // Set new dates for tomorrow, keeping the same time duration
    _startDate = DateTime.now().add(const Duration(days: 1));
    _startTime = TimeOfDay(hour: post.startDate.hour, minute: post.startDate.minute);
    
    // Calculate the duration and apply to end date
    final duration = post.endDate.difference(post.startDate);
    _endDate = _startDate.add(duration);
    _endTime = TimeOfDay(hour: post.endDate.hour, minute: post.endDate.minute);

    _showPostFormSheet(keepExistingValues: true);
  }
}
