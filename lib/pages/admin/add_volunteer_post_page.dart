import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/volunteer_post.dart';
import '../../services/auth_service.dart';
import '../../widgets/admin_scaffold.dart';

class AddVolunteerPostPage extends StatefulWidget {
  const AddVolunteerPostPage({super.key});

  @override
  State<AddVolunteerPostPage> createState() => _AddVolunteerPostPageState();
}

class _AddVolunteerPostPageState extends State<AddVolunteerPostPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxVolunteersController = TextEditingController(text: "1");
  
  // Start date/time
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  
  // End date/time
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  
  bool _isCreatingPost = false;

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
        Navigator.pushReplacementNamed(context, '/admin/volunteer-posts');
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

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00C49A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        // Auto-update end date if it's before start date
        if (_endDate.isBefore(picked)) {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00C49A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null && mounted) {
      setState(() => _startTime = time);
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00C49A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00C49A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null && mounted) {
      setState(() => _endTime = time);
    }
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
                const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDateTimeSection({
    required String title,
    required Color color,
    required IconData icon,
    required DateTime date,
    required TimeOfDay time,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onDateTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormat('MMM dd, yyyy').format(date),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: onTimeTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            time.format(context),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Add Volunteer Post',
      appBar: AppBar(
        title: const Text('Add Volunteer Post'),
        backgroundColor: const Color(0xFF00C49A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFormField(
                label: 'Title',
                controller: _titleController,
                hintText: 'Tree Planting',
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              _buildFormField(
                label: 'Description',
                controller: _descriptionController,
                hintText: 'Join us for a community tree planting event...',
                maxLines: 3,
                validator: (value) => value?.isEmpty ?? true
                    ? 'Please enter a description'
                    : null,
              ),
              const SizedBox(height: 16),
              // Start Date/Time Section
              _buildDateTimeSection(
                title: 'Start Date & Time',
                color: const Color(0xFF3B82F6),
                icon: Icons.play_circle_outline_rounded,
                date: _startDate,
                time: _startTime,
                onDateTap: _selectStartDate,
                onTimeTap: _selectStartTime,
              ),
              const SizedBox(height: 12),
              // End Date/Time Section
              _buildDateTimeSection(
                title: 'End Date & Time',
                color: const Color(0xFF10B981),
                icon: Icons.stop_circle_outlined,
                date: _endDate,
                time: _endTime,
                onDateTap: _selectEndDate,
                onTimeTap: _selectEndTime,
              ),
              const SizedBox(height: 16),
              _buildFormField(
                label: 'Location',
                controller: _locationController,
                hintText: 'Barangay Pulse',
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a location' : null,
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
              ElevatedButton(
                onPressed: _isCreatingPost ? null : _createVolunteerPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C49A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: _isCreatingPost
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Create Volunteer Post',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
