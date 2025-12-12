import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../services/location_service.dart';
import '../models/community.dart';
import '../models/registration_data.dart';
import 'otp_verification_page.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import '../services/cloudinary_service.dart';
import 'package:uuid/uuid.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  DateTime? _selectedDate;
  final LocationService _locationService = LocationService();
  Region? _selectedRegion;
  Province? _selectedProvince;
  Municipality? _selectedMunicipality;
  Barangay? _selectedBarangay;
  List<Region> _regions = [];
  List<Province> _provinces = [];
  List<Municipality> _municipalities = [];
  List<Barangay> _barangays = [];
  final GlobalKey<DropdownSearchState<Region>> _regionDropdownKey = GlobalKey();
  final GlobalKey<DropdownSearchState<Province>> _provinceDropdownKey =
      GlobalKey();
  final GlobalKey<DropdownSearchState<Municipality>> _municipalityDropdownKey =
      GlobalKey();
  final GlobalKey<DropdownSearchState<Barangay>> _barangayDropdownKey =
      GlobalKey();
  bool _obscurePassword = true;
  bool _isLoading = false;
  late AnimationController _shakeController;
  final ScrollController _scrollController = ScrollController();
  bool _isEmailAvailable = true;
  bool _isCheckingEmail = false;
  Timer? _emailCheckDebouncer;
  File? _profileImage;
  bool _isUploadingImage = false;
  final ImagePicker _imagePicker = ImagePicker();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  bool _isCommunityActive = false;
  String? _communityStatusMessage;

  @override
  void initState() {
    super.initState();
    _loadRegions();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _emailCheckDebouncer?.cancel();
    _shakeController.dispose();
    _scrollController.dispose();
    _birthDateController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
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

  Future<void> _getImage(ImageSource source) async {
    try {
      setState(() {
        _isUploadingImage = true; // Show loading indicator
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
            _profileImage = croppedFile;
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
          _isUploadingImage = false; // Hide loading indicator
        });
      }
    }
  }

  Future<File?> _cropImage(File imageFile) async {
    setState(() {
      _isUploadingImage = true; // Show loading indicator during cropping
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
          _isUploadingImage = false; // Hide loading indicator after cropping
        });
      }
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (_profileImage == null) return null;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      // Compress the image before uploading to reduce file size
      final File compressedFile = await _compressImage(_profileImage!);

      return await _cloudinaryService.uploadProfileImage(compressedFile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading profile image: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
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

  Future<void> _loadRegions() async {
    try {
      final regions = await _locationService.getRegions();
      setState(() {
        _regions = regions;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading regions: $e')),
        );
      }
    }
  }

  Future<void> _loadProvinces(String regionCode) async {
    try {
      final provinces = await _locationService.getProvinces(regionCode);
      setState(() {
        _provinces = provinces;
        _selectedProvince = null;
        _municipalities = [];
        _selectedMunicipality = null;
        _barangays = [];
        _selectedBarangay = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading provinces: $e')),
        );
      }
    }
  }

  Future<void> _loadMunicipalities(String provinceCode) async {
    try {
      final municipalities =
          await _locationService.getMunicipalities(provinceCode);
      setState(() {
        _municipalities = municipalities;
        _selectedMunicipality = null;
        _barangays = [];
        _selectedBarangay = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading municipalities: $e')),
        );
      }
    }
  }

  Future<void> _loadBarangays(String municipalityCode) async {
    try {
      final barangays = await _locationService.getBarangays(municipalityCode);
      setState(() {
        _barangays = barangays;
        _selectedBarangay = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading barangays: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 8)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _birthDateController.text = DateFormat('MMMM dd, yyyy').format(picked);
      });
    }
  }

  void _scrollToField(GlobalKey fieldKey) {
    final context = fieldKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Map<String, bool> _checkPasswordStrength(String password) {
    return {
      'length': password.length >= 8,
      'uppercase': password.contains(RegExp(r'[A-Z]')),
      'lowercase': password.contains(RegExp(r'[a-z]')),
      'number': password.contains(RegExp(r'[0-9]')),
      'special': password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
    };
  }

  bool _isPasswordStrong(String password) {
    final checks = _checkPasswordStrength(password);
    return checks.values.every((isValid) => isValid);
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet ? const Color(0xFF00C49A) : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isMet ? Colors.black87 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkEmailAvailability(String email) async {
    if (email.isEmpty) {
      setState(() {
        _isEmailAvailable = true;
        _isCheckingEmail = false;
      });
      return;
    }

    setState(() {
      _isCheckingEmail = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (mounted) {
        setState(() {
          _isEmailAvailable = querySnapshot.docs.isEmpty;
          _isCheckingEmail = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isEmailAvailable = true;
          _isCheckingEmail = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking email: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFFF5FBF9),
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _pickProfileImage,
                    child: Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F7F3),
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: const Color(0xFF00C49A), width: 2),
                            ),
                            child: _profileImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(48),
                                    child: Image.file(
                                      _profileImage!,
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person_outline,
                                    color: Color(0xFF00C49A),
                                    size: 40,
                                  ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
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
                          if (_isUploadingImage)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(50),
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
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00C49A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fill in your details to get started',
                    style: TextStyle(
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
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00C49A)),
                      ),
                      prefixIcon: const Icon(Icons.person_outline),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
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
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00C49A)),
                      ),
                      prefixIcon: const Icon(Icons.person_outline),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
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
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00C49A)),
                      ),
                      prefixIcon: const Icon(Icons.person_outline),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
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
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00C49A)),
                      ),
                      prefixIcon: const Icon(Icons.alternate_email),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00C49A)),
                      ),
                      prefixIcon: const Icon(Icons.mail_outline),
                      suffixIcon: _isCheckingEmail
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : _emailController.text.isNotEmpty &&
                                  !_isEmailAvailable
                              ? const Icon(
                                  Icons.error,
                                  color: Colors.red,
                                )
                              : null,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onChanged: (value) {
                      // Cancel previous debounced call
                      _emailCheckDebouncer?.cancel();
                      _emailCheckDebouncer = Timer(
                        const Duration(milliseconds: 500),
                        () => _checkEmailAvailability(value),
                      );
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Please enter a valid email address';
                      }
                      if (!_isEmailAvailable) {
                        return 'This email is already registered';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00C49A)),
                      ),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    obscureText: _obscurePassword,
                    onChanged: (value) {
                      // Force rebuild to update password requirements
                      setState(() {});
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (!_isPasswordStrong(value)) {
                        return 'Password does not meet requirements';
                      }
                      return null;
                    },
                  ),
                  if (_passwordController.text.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Password Requirements',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildRequirement(
                            'At least 8 characters',
                            _checkPasswordStrength(
                                    _passwordController.text)['length'] ??
                                false,
                          ),
                          _buildRequirement(
                            'Contains uppercase letter',
                            _checkPasswordStrength(
                                    _passwordController.text)['uppercase'] ??
                                false,
                          ),
                          _buildRequirement(
                            'Contains lowercase letter',
                            _checkPasswordStrength(
                                    _passwordController.text)['lowercase'] ??
                                false,
                          ),
                          _buildRequirement(
                            'Contains number',
                            _checkPasswordStrength(
                                    _passwordController.text)['number'] ??
                                false,
                          ),
                          _buildRequirement(
                            'Contains special character',
                            _checkPasswordStrength(
                                    _passwordController.text)['special'] ??
                                false,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00C49A)),
                      ),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  _buildNewFields(),
                  const SizedBox(height: 16),
                  if (_selectedBarangay != null &&
                      _communityStatusMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _communityStatusMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    width: double.infinity,
                    height: 50,
                    margin: const EdgeInsets.only(top: 8),
                    child: AnimatedBuilder(
                      animation: _shakeController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(
                            sin(_shakeController.value * 2 * pi) * 10,
                            0,
                          ),
                          child: child,
                        );
                      },
                      child: ElevatedButton(
                        onPressed: _isLoading || !_isFormValid()
                            ? null
                            : () async {
                                if (_formKey.currentState!.validate() &&
                                    _selectedDate != null &&
                                    _selectedRegion != null &&
                                    _selectedProvince != null &&
                                    _selectedMunicipality != null &&
                                    _selectedBarangay != null) {
                                  setState(() {
                                    _isLoading = true;
                                  });

                                  final locationId = Community.createLocationId(
                                    _selectedRegion!.code,
                                    _selectedProvince!.code,
                                    _selectedMunicipality!.code,
                                    _selectedBarangay!.code,
                                  );

                                  Map<String, String> location = {
                                    'region': _selectedRegion!.name,
                                    'regionCode': _selectedRegion!.code,
                                    'province': _selectedProvince!.name,
                                    'provinceCode': _selectedProvince!.code,
                                    'municipality': _selectedMunicipality!.name,
                                    'municipalityCode':
                                        _selectedMunicipality!.code,
                                    'barangay': _selectedBarangay!.name,
                                    'barangayCode': _selectedBarangay!.code,
                                    'locationId': locationId,
                                  };

                                  // Upload profile image if selected
                                  String? profileImageUrl;
                                  if (_profileImage != null) {
                                    setState(() {
                                      _isUploadingImage = true;
                                    });
                                    profileImageUrl = await _uploadProfileImage();
                                    setState(() {
                                      _isUploadingImage = false;
                                    });
                                  }
                                  // Generate unique registration ID for QR code
                                  final registrationId = const Uuid().v4();

                                  final registrationData = RegistrationData(
                                    email: _emailController.text.trim(),
                                    password: _passwordController.text,
                                    firstName: _firstNameController.text.trim(),
                                    middleName: _middleNameController.text.trim().isNotEmpty
                                        ? _middleNameController.text.trim()
                                        : null,
                                    lastName: _lastNameController.text.trim(),
                                    username: _usernameController.text.trim(),
                                    mobile:
                                        '+63${_mobileController.text.trim()}',
                                    birthDate: _selectedDate!,
                                    address: _addressController.text.trim(),
                                    location: location,
                                    profileImageUrl: profileImageUrl,
                                    registrationId: registrationId,
                                  );

                                  // Navigate to OTP verification page
                                  try {
                                    if (mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              OTPVerificationPage(
                                            registrationData: registrationData,
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(e.toString()),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _isLoading = false;
                                      });
                                    }
                                  }
                                } else {
                                  // Shake the button
                                  _shakeController.forward(from: 0);

                                  if (_firstNameController.text.isEmpty) {
                                    _scrollToField(_formKey);
                                  } else if (_lastNameController.text.isEmpty) {
                                    _scrollToField(_formKey);
                                  } else if (_usernameController.text.isEmpty) {
                                    _scrollToField(_formKey);
                                  } else if (_emailController.text.isEmpty) {
                                    _scrollToField(_formKey);
                                  } else if (_passwordController.text.isEmpty ||
                                      !_isPasswordStrong(
                                          _passwordController.text)) {
                                    _scrollToField(_formKey);
                                  } else if (_confirmPasswordController
                                          .text.isEmpty ||
                                      _confirmPasswordController.text !=
                                          _passwordController.text) {
                                    _scrollToField(_formKey);
                                  } else if (_mobileController.text.isEmpty ||
                                      !RegExp(r'^\d{10}$')
                                          .hasMatch(_mobileController.text)) {
                                    _scrollToField(_formKey);
                                  } else if (_selectedDate == null) {
                                    _scrollToField(_formKey);
                                  } else if (_selectedRegion == null) {
                                    _scrollToField(_regionDropdownKey);
                                  } else if (_selectedProvince == null) {
                                    _scrollToField(_provinceDropdownKey);
                                  } else if (_selectedMunicipality == null) {
                                    _scrollToField(_municipalityDropdownKey);
                                  } else if (_selectedBarangay == null) {
                                    _scrollToField(_barangayDropdownKey);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C49A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          disabledBackgroundColor:
                              const Color(0xFF00C49A).withOpacity(0.5),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Register',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewFields() {
    return Column(
      children: [
        const SizedBox(height: 16),
        TextFormField(
          controller: _mobileController,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Mobile Number',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF00C49A)),
            ),
            prefixIcon: const Icon(Icons.phone_outlined),
            prefixText: '+63 ',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
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
        GestureDetector(
          onTap: () => _selectDate(context),
          child: AbsorbPointer(
            child: TextFormField(
              controller: _birthDateController,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(
                labelText: 'Birth Date',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00C49A)),
                ),
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                errorMaxLines: 2,
              ),
              validator: (_) {
                if (_selectedDate == null) {
                  return 'Please select your birth date';
                }


                final today = DateTime.now();
                final age = today.year - _selectedDate!.year -
                    (today.month < _selectedDate!.month ||
                            (today.month == _selectedDate!.month &&
                                today.day < _selectedDate!.day)
                        ? 1
                        : 0);

                if (age < 8) {
                  return 'You must be at least 8 years old to register.';
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00C49A)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          child: Column(
            children: [
              DropdownSearch<Region>(
                key: _regionDropdownKey,
                items: _regions,
                itemAsString: (Region? region) => region?.name ?? '',
                onChanged: (Region? region) {
                  setState(() {
                    _selectedRegion = region;
                    if (region != null) {
                      _loadProvinces(region.code);
                    }
                  });
                },
                selectedItem: _selectedRegion,
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Region',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null) {
                    return 'Please select a region';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownSearch<Province>(
                key: _provinceDropdownKey,
                enabled: _selectedRegion != null,
                items: _provinces,
                itemAsString: (Province? province) => province?.name ?? '',
                onChanged: (Province? province) {
                  setState(() {
                    _selectedProvince = province;
                    if (province != null) {
                      _loadMunicipalities(province.code);
                    }
                  });
                },
                selectedItem: _selectedProvince,
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Province',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null) {
                    return 'Please select a province';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownSearch<Municipality>(
                key: _municipalityDropdownKey,
                enabled: _selectedProvince != null,
                items: _municipalities,
                itemAsString: (Municipality? municipality) =>
                    municipality?.name ?? '',
                onChanged: (Municipality? municipality) {
                  setState(() {
                    _selectedMunicipality = municipality;
                    if (municipality != null) {
                      _loadBarangays(municipality.code);
                    }
                  });
                },
                selectedItem: _selectedMunicipality,
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'City / Municipality',
                    prefixIcon: const Icon(Icons.location_city_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null) {
                    return 'Please select a city / municipality';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownSearch<Barangay>(
                key: _barangayDropdownKey,
                enabled: _selectedMunicipality != null,
                items: _barangays,
                itemAsString: (Barangay? barangay) => barangay?.name ?? '',
                onChanged: (Barangay? barangay) async {
                  setState(() {
                    _selectedBarangay = barangay;
                  });

                  if (barangay != null &&
                      _selectedRegion != null &&
                      _selectedProvince != null &&
                      _selectedMunicipality != null) {
                    await _checkCommunityStatus();
                  }
                },
                selectedItem: _selectedBarangay,
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Barangay',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null) {
                    return 'Please select a barangay';
                  }
                  // We're showing the community status message in a separate container
                  // so we don't need to show it here as well
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  labelText: 'Address / Street No.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF00C49A)),
                  ),
                  prefixIcon: const Icon(Icons.home_outlined),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your address';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _checkCommunityStatus() async {
    if (_selectedRegion == null ||
        _selectedProvince == null ||
        _selectedMunicipality == null ||
        _selectedBarangay == null) {
      return;
    }

    setState(() {
      _isCommunityActive = false;
      _communityStatusMessage = null;
    });

    try {
      // We'll manually check each community for a match

      final communitiesRef =
          FirebaseDatabase.instance.ref().child('communities');
      final allCommunitiesSnapshot = await communitiesRef.get();

      if (allCommunitiesSnapshot.exists) {
        final allCommunities =
            allCommunitiesSnapshot.value as Map<dynamic, dynamic>;
        bool foundActiveMatch = false;

        // Manually check each community since we can't query by locationStatusId without an index
        for (var entry in allCommunities.entries) {
          final community = entry.value as Map<dynamic, dynamic>;

          if (community['barangayCode'] == _selectedBarangay!.code &&
              community['status'] == 'active' &&
              community['adminId'] != null) {
            // Found an active community for this barangay
            setState(() {
              _isCommunityActive = true;
              _communityStatusMessage =
                  null; // Clear any previous error message
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Community is active and ready for registration'),
                  backgroundColor: Colors.green,
                ),
              );
            }

            foundActiveMatch = true;
            break;
          }
        }

        // If no active community was found
        if (!foundActiveMatch) {
          setState(() {
            _isCommunityActive = false;
            _communityStatusMessage =
                'This community is not yet active or has no admin. Registration is not available.';
          });
        }
      } else {
        // No communities found at all
        setState(() {
          _isCommunityActive = false;
          _communityStatusMessage = 'No communities found in the database.';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking community status: $e')),
        );
      }
      setState(() {
        _isCommunityActive = false;
        _communityStatusMessage = 'Error checking community status';
      });
    }
  }

  bool _isFormValid() {
    return _firstNameController.text.isNotEmpty &&
        _lastNameController.text.isNotEmpty &&
        _usernameController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _isPasswordStrong(_passwordController.text) &&
        _confirmPasswordController.text == _passwordController.text &&
        _mobileController.text.isNotEmpty &&
        RegExp(r'^\d{10}$').hasMatch(_mobileController.text) &&
        _selectedDate != null &&
        _selectedRegion != null &&
        _selectedProvince != null &&
        _selectedMunicipality != null &&
        _selectedBarangay != null &&
        _addressController.text.isNotEmpty &&
        _isCommunityActive; // Add check for active community
  }
}
