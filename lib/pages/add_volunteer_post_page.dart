import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/volunteer_post.dart';
import 'package:intl/intl.dart';

class AddVolunteerPostPage extends StatefulWidget {
  final Function(VolunteerPost) onPostAdded;

  const AddVolunteerPostPage({
    Key? key,
    required this.onPostAdded,
  }) : super(key: key);

  @override
  State<AddVolunteerPostPage> createState() => _AddVolunteerPostPageState();
}

class _AddVolunteerPostPageState extends State<AddVolunteerPostPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _spotLimitController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = false;
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _spotLimitController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'User not authenticated';

      // Get user data from Realtime Database
      final userSnapshot = await _database
          .ref()
          .child('users')
          .child(currentUser.uid)
          .get();

      if (!userSnapshot.exists) throw 'User data not found';

      final userData = userSnapshot.value as Map<dynamic, dynamic>;
      final communityId = userData['communityId'] as String?;
      if (communityId == null) throw 'Community ID not found';

      final spotLimit = int.parse(_spotLimitController.text);
      
      // Create the volunteer post in Firestore
      final docRef = await _firestore.collection('volunteer_posts').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'date': Timestamp.fromDate(_selectedDate!),
        'spotLimit': spotLimit,
        'spotsLeft': spotLimit,
        'userId': currentUser.uid,
        'userName': userData['fullName'] ?? userData['username'] ?? 'Unknown User',
        'communityId': communityId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Wait for the server timestamp to be set
      final docSnapshot = await docRef.get();
      final docData = docSnapshot.data() as Map<String, dynamic>;
      
      // Create VolunteerPost object with the new data
      final post = VolunteerPost(
        id: docRef.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        date: _selectedDate!,
        spotLimit: spotLimit,
        spotsLeft: spotLimit,
        userId: currentUser.uid,
        userName: userData['fullName'] ?? userData['username'] ?? 'Unknown User',
        communityId: communityId,
        createdAt: (docData['createdAt'] as Timestamp).toDate(),
      );

      widget.onPostAdded(post);
      Navigator.pop(context);
      
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Volunteer Post',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF00C49A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _spotLimitController,
                decoration: const InputDecoration(
                  labelText: 'Number of Spots',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter number of spots';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Event Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _selectedDate == null
                        ? 'Select Date'
                        : DateFormat('MMM dd, yyyy').format(_selectedDate!),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C49A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Create Post',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
