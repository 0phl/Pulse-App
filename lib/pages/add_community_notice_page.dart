import 'package:flutter/material.dart';
import '../services/community_notice_service.dart';
import '../services/community_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddCommunityNoticePage extends StatefulWidget {
  final Function(String) onNoticeAdded;

  const AddCommunityNoticePage({
    super.key,
    required this.onNoticeAdded,
  });

  @override
  State<AddCommunityNoticePage> createState() => _AddCommunityNoticePageState();
}

class _AddCommunityNoticePageState extends State<AddCommunityNoticePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = false;
  final _noticeService = CommunityNoticeService();
  final _communityService = CommunityService();
  final _auth = FirebaseAuth.instance;
  String? _communityId;

  @override
  void initState() {
    super.initState();
    _loadCommunityId();
  }

  Future<void> _loadCommunityId() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final community = await _communityService.getUserCommunity(user.uid);
      if (community != null && mounted) {
        setState(() {
          _communityId = community.id;
        });
      }
    } catch (e) {
      print('Error loading community ID: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submitNotice() async {
    if (!_formKey.currentState!.validate()) return;
    if (_communityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Community not found')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final noticeId = await _noticeService.createNotice(
        title: _titleController.text,
        content: _contentController.text,
        authorId: user.uid,
        authorName: user.displayName ?? 'Community Admin',
        communityId: _communityId!,
      );

      if (mounted) {
        widget.onNoticeAdded(noticeId);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating notice: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Notice'),
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
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter content';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitNotice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C49A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Post Notice'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
