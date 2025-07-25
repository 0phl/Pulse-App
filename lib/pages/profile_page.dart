import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'dart:io';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _isUpdating = false;
  Map<String, dynamic>? _userData;
  File? _newProfileImage;

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('User data not found');
      }

      final userData = userDoc.data()!;

      setState(() {
        _userData = userData;

        if (userData['firstName'] != null) {
          _firstNameController.text = userData['firstName'] ?? '';
          _middleNameController.text = userData['middleName'] ?? '';
          _lastNameController.text = userData['lastName'] ?? '';
        } else if (userData['fullName'] != null) {
          // Parse fullName into components
          final nameParts = (userData['fullName'] as String).split(' ');
          if (nameParts.length >= 2) {
            _firstNameController.text = nameParts.first;
            _lastNameController.text = nameParts.last;
            if (nameParts.length > 2) {
              // Join any middle parts as the middle name
              _middleNameController.text = nameParts.sublist(1, nameParts.length - 1).join(' ');
            }
          } else if (nameParts.length == 1) {
            _firstNameController.text = nameParts.first;
          }
        }

        _usernameController.text = userData['username'] ?? '';
        _mobileController.text = (userData['mobile'] ?? '').replaceFirst('+63', '');
        _addressController.text = userData['address'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      await showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Take a photo'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _getImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _getImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  // Loading state for image processing
  bool _isProcessingImage = false;

  Future<void> _getImage(ImageSource source) async {
    try {
      setState(() {
        _isProcessingImage = true; // Show loading indicator
      });

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (image != null) {
        // Crop the image
        final croppedFile = await _cropImage(File(image.path));

        if (croppedFile != null && mounted) {
          setState(() {
            _newProfileImage = croppedFile;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingImage = false; // Hide loading indicator
        });
      }
    }
  }

  Future<File?> _cropImage(File imageFile) async {
    setState(() {
      _isProcessingImage = true; // Show loading indicator during cropping
    });

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: const Color(0xFF00C49A),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            activeControlsWidgetColor: const Color(0xFF00C49A),
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Profile Picture',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
            ],
          ),
        ],
      );

      if (croppedFile == null) return null;
      return File(croppedFile.path);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingImage = false; // Hide loading indicator after cropping
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

  // Helper method to compress images before uploading
  Future<File> _compressImage(File file) async {
    final String filePath = file.path;
    final int lastIndex = filePath.lastIndexOf(Platform.isWindows ? '\\' : '/');
    final String fileName = filePath.substring(lastIndex + 1);

    final tempDir = await path_provider.getTemporaryDirectory();
    final targetPath = '${tempDir.path}${Platform.isWindows ? '\\' : '/'}compressed_$fileName';

    // Compress the image with reduced quality (50%)
    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: 50,
      minWidth: 1000,
      minHeight: 1000,
    );

    if (result != null) {
      return File(result.path);
    }

    // If compression fails, return the original file
    return file;
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
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'mobile': '+63${_mobileController.text.trim()}',
        'address': _addressController.text.trim(),
      };

      if (_middleNameController.text.trim().isNotEmpty) {
        updateData['middleName'] = _middleNameController.text.trim();
      }

      // Compute full name for backward compatibility
      final fullName = _middleNameController.text.trim().isNotEmpty
          ? '${_firstNameController.text.trim()} ${_middleNameController.text.trim()} ${_lastNameController.text.trim()}'
          : '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
      updateData['fullName'] = fullName;

      if (profileImageUrl != null) {
        updateData['profileImageUrl'] = profileImageUrl;
      }

      await _authService.updateUserProfile(user.uid, updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload user data
        await _loadUserData();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: const Color(0xFF00C49A),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _isProcessingImage ? null : _pickImage,
                      child: Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F7F3),
                              borderRadius: BorderRadius.circular(60),
                              border: Border.all(color: const Color(0xFF00C49A), width: 2),
                            ),
                            child: _newProfileImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(58),
                                    child: Image.file(
                                      _newProfileImage!,
                                      width: 116,
                                      height: 116,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : _userData != null && _userData!['profileImageUrl'] != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(58),
                                        child: Image.network(
                                          _userData!['profileImageUrl'],
                                          width: 116,
                                          height: 116,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress.expectedTotalBytes != null
                                                    ? loadingProgress.cumulativeBytesLoaded /
                                                        loadingProgress.expectedTotalBytes!
                                                    : null,
                                              ),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.person,
                                              color: Color(0xFF00C49A),
                                              size: 50,
                                            );
                                          },
                                        ),
                                      )
                                    : const Icon(
                                        Icons.person,
                                        color: Color(0xFF00C49A),
                                        size: 50,
                                      ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C49A),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          if (_isProcessingImage)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(60),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _userData?['email'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // First Name field
                    TextFormField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your first name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Middle Name field (optional)
                    TextFormField(
                      controller: _middleNameController,
                      decoration: InputDecoration(
                        labelText: 'Middle Name (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Last Name field
                    TextFormField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your last name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.alternate_email),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your username';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mobileController,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.phone_outlined),
                        prefixText: '+63 ',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your mobile number';
                        }
                        if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                          return 'Please enter 10 digits for mobile number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.home_outlined),
                      ),
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
    );
  }
}
