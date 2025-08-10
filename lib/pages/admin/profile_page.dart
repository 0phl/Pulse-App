import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/admin_scaffold.dart';

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _adminService = AdminService();
  final _authService = AuthService();
  final _cloudinaryService = CloudinaryService();

  bool _isLoading = true;
  bool _isUpdating = false;
  bool _isProcessingImage = false;
  File? _newProfileImage;
  String? _currentProfileImageUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    debugPrint('AdminProfilePage: initState called');
    _loadAdminData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('AdminProfilePage: App lifecycle state changed to $state');

    if (state == AppLifecycleState.resumed) {
      // Reload admin data when app is resumed
      debugPrint('AdminProfilePage: App resumed - reloading admin data');
      _loadAdminData();

      // Force a rebuild to ensure the drawer is properly displayed
      if (mounted) {
        setState(() {
          // This empty setState will trigger a rebuild
        });
      }
    }
  }

  Future<void> _loadAdminData() async {
    if (!mounted) return;

    debugPrint('AdminProfilePage: _loadAdminData called');
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      final user = _authService.currentUser;
      if (user == null) {
        debugPrint('AdminProfilePage: User not authenticated');
        throw Exception('User not authenticated');
      }

      debugPrint('AdminProfilePage: Current user ID: ${user.uid}');

      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!adminDoc.exists) {
        debugPrint('AdminProfilePage: Admin not found in Firestore');
        throw Exception('Admin not found');
      }

      final adminData = adminDoc.data() as Map<String, dynamic>;
      debugPrint('AdminProfilePage: Admin data loaded: ${adminData['fullName']}');

      if (mounted) {
        setState(() {
          _fullNameController.text = adminData['fullName'] ?? '';
          _emailController.text = adminData['email'] ?? '';
          _currentProfileImageUrl = adminData['profileImageUrl'];
          _isLoading = false;
        });
        debugPrint('AdminProfilePage: State updated with admin data');
      }
    } catch (e) {
      debugPrint('AdminProfilePage: Error loading admin data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error loading profile data. Please try again.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadAdminData,
            ),
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final croppedFile = await _cropImage(File(pickedFile.path));
      if (croppedFile != null) {
        setState(() {
          _newProfileImage = croppedFile;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<File?> _cropImage(File imageFile) async {
    setState(() {
      _isProcessingImage = true;
    });

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 85,
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: const Color(0xFF00C49A),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile == null) return null;
      return File(croppedFile.path);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
        });
      }
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (_newProfileImage == null) return null;

    try {
      // Compress the image before uploading to reduce file size
      final File compressedFile = await _compressImage(_newProfileImage!);

      return await _cloudinaryService.uploadProfileImage(compressedFile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading profile image: $e')),
        );
      }
      return null;
    }
  }

  Future<File> _compressImage(File file) async {
    try {
      // In a production app, you might want to use a more sophisticated compression library
      return file;
    } catch (e) {
      // If compression fails, return the original file
      return file;
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Upload new profile image if selected
      String? profileImageUrl;
      if (_newProfileImage != null) {
        profileImageUrl = await _uploadProfileImage();
        if (profileImageUrl == null) {
          throw Exception('Failed to upload profile image');
        }
      }

      // Prepare update data
      final updateData = <String, dynamic>{
        'fullName': _fullNameController.text.trim(),
      };

      if (profileImageUrl != null) {
        updateData['profileImageUrl'] = profileImageUrl;
      }

      await _adminService.updateAdminProfile(user.uid, updateData);

      // This will update both the profile picture and name in all notices
      // Run this in the background to avoid blocking the UI
      _adminService.updateExistingNoticesWithProfileInfo();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: const Color(0xFF00C49A),
          ),
        );

        // Reload admin data
        await _loadAdminData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Admin Profile',
      appBar: AppBar(
        title: const Text('Admin Profile'),
        backgroundColor: const Color(0xFF00C49A),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Profile image
                      GestureDetector(
                        onTap: _isProcessingImage ? null : _pickImage,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[200],
                                image: _newProfileImage != null
                                    ? DecorationImage(
                                        image: FileImage(_newProfileImage!),
                                        fit: BoxFit.cover,
                                      )
                                    : _currentProfileImageUrl != null
                                        ? DecorationImage(
                                            image: NetworkImage(
                                                _currentProfileImageUrl!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                              ),
                              child: _isProcessingImage
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : (_newProfileImage == null &&
                                          _currentProfileImageUrl == null)
                                      ? const Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Colors.grey,
                                        )
                                      : null,
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C49A),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Full Name
                      TextFormField(
                        controller: _fullNameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Email (read-only)
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        readOnly: true,
                        enabled: false,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isUpdating ? null : _updateProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C49A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isUpdating
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
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
}
