import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// Removed map-related imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_compress/video_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/report.dart';
import '../models/report_status.dart';
import '../services/report_service.dart';
import '../services/cloudinary_service.dart';
import '../services/auth_service.dart';
import '../widgets/report_stepper.dart';
import '../widgets/report_form_field.dart';
import '../widgets/searchable_dropdown.dart';
import '../widgets/user_report_card.dart';
import '../widgets/report_filter_chip.dart';
import '../widgets/report_success_dialog.dart';
// Removed map widget import
import '../widgets/report_review_item.dart';
import '../widgets/user_report_detail_dialog.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage>
    with SingleTickerProviderStateMixin {
  // Location details storage - simplified

  final List<String> _issueTypes = const [
    'Fires',
    'Street Light Damage',
    'Road Damage/Potholes',
    'Flooding/Drainage Issues',
    'Illegal Parking',
    'Garbage Collection Problems',
    'Noise Disturbances',
    'Stray Animals',
    'Illegal Dumping of Waste',
    'Suspicious Activities/Security Concerns',
    'Others'
  ];

  final ReportService _reportService = ReportService(CloudinaryService());
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedIssueType;
  final TextEditingController _issueTypeController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _addressDetailsController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _hasConfirmedInfo = false;
  List<String> _filteredIssueTypes = [];
  bool _isUploading = false;
  int _currentStep = 0;
  late TabController _tabController;
  final List<String> _tabs = ['New Report', 'My Reports'];
  String _selectedFilter = 'All';
  final List<File> _selectedPhotos = [];
  final List<File> _selectedVideos = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isVideoUploading = false;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    _filteredIssueTypes = List.from(_issueTypes);
    _tabController = TabController(length: 2, vsync: this);

    // Listen to tab changes
    _tabController.addListener(() {
      if (mounted) {
        if (_tabController.index == 1) { // My Reports tab
          // Reset cache when entering My Reports tab
          setState(() {});
        }
      }
    });

    _descriptionController.addListener(_updateState);
    _addressController.addListener(_updateState);
    _addressDetailsController.addListener(_updateState);
  }

  void _updateState() {
    if (mounted) {
      setState(() {
        // This empty setState will trigger a rebuild with the updated text values
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isGettingLocation = true;
      });

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showSnackBar('Please enable location services in your device settings');
        setState(() {
          _isGettingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permission is required. Please grant permission in app settings.');
          setState(() {
            _isGettingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationPermissionDialog();
        setState(() {
          _isGettingLocation = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // Changed from high to medium for better compatibility
        timeLimit: const Duration(seconds: 15), // Increased timeout
        forceAndroidLocationManager: false, // Use Google Play Services if available
      );

      // Convert coordinates to address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = _formatAddress(place);

        setState(() {
          _addressController.text = address;
          _isGettingLocation = false;
        });

        _showSnackBar('Location found successfully!');
      } else {
        setState(() {
          _addressController.text = "Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}";
          _isGettingLocation = false;
        });
        _showSnackBar('Location found but address lookup failed. Coordinates used instead.');
      }
    } catch (e) {
      setState(() {
        _isGettingLocation = false;
      });

      String errorMessage = 'Failed to get location';

      if (e.toString().contains('timeout') || e.toString().contains('TIMEOUT')) {
        errorMessage = 'Location request timed out. Please check your GPS/network connection and try again.';
      } else if (e.toString().contains('PERMISSION_DENIED')) {
        errorMessage = 'Location permission denied. Please enable location permission in app settings.';
      } else if (e.toString().contains('LOCATION_SERVICES_DISABLED')) {
        errorMessage = 'Location services are disabled. Please enable them in device settings.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error while getting location. Please check your internet connection.';
      } else {
        errorMessage = 'Failed to get location: ${e.toString()}';
      }

      _showSnackBar(errorMessage);

      _showLocationErrorDialog();
    }
  }

  String _formatAddress(Placemark place) {
    List<String> addressParts = [];

    if (place.subThoroughfare != null && place.subThoroughfare!.isNotEmpty) {
      addressParts.add(place.subThoroughfare!);
    }
    if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
      addressParts.add(place.thoroughfare!);
    }

    if (place.locality != null && place.locality!.isNotEmpty) {
      addressParts.add(place.locality!);
    }

    // Removed administrative area (state/province) and country
    // to show only street and city information

    return addressParts.join(', ');
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'This app needs location permission to automatically fill in your current address. Please enable location permission in your device settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C49A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _showLocationErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_off,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Location Unavailable',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We\'re unable to access your current location at the moment.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Please check your location settings and try again, or enter your address manually.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 14),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C49A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Open Settings',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        );
      },
    );
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_updateState);
    _addressController.removeListener(_updateState);
    _addressDetailsController.removeListener(_updateState);

    // Dispose controllers
    _issueTypeController.dispose();
    _addressController.dispose();
    _addressDetailsController.dispose();
    _descriptionController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _filterIssueTypes(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredIssueTypes = List.from(_issueTypes);
      } else {
        _filteredIssueTypes = _issueTypes
            .where((type) => type.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Stream<List<Report>> _getFilteredReportsStream() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      return Stream<List<Report>>.value([]);
    }

    // Always create a new stream - don't use cache since we want fresh data when switching tabs
    return Stream.fromFuture(_firestore.collection('users').doc(currentUser.uid).get())
        .asyncExpand((userDoc) {
          if (!userDoc.exists || userDoc.data() == null || userDoc.data()!['communityId'] == null) {
            return Stream<List<Report>>.value([]);
          }

          final communityId = userDoc.data()!['communityId'];
          return _reportService.getReports(
            communityId: communityId,
            status: _selectedFilter != 'All'
                ? ReportStatus.fromString(_selectedFilter)
                : null,
            userId: currentUser.uid,
          );
        }).asBroadcastStream();
  }


  Future<void> _showPhotoSourceOptions() async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickSinglePhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickMultiplePhotos();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickSinglePhoto(ImageSource source) async {
    final XFile? image = await _imagePicker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _selectedPhotos.add(File(image.path));
      });
    }
  }

  Future<void> _pickMultiplePhotos() async {
    final List<XFile> images = await _imagePicker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedPhotos.addAll(images.map((image) => File(image.path)));
      });
    }
  }

  Future<void> _showVideoSourceOptions() async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Record a video'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickVideo(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickVideo(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        final File videoFile = File(video.path);
        final int fileSizeInBytes = await videoFile.length();
        final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

        if (fileSizeInMB > 50) {
          if (mounted) {
            _showSnackBar('Video size exceeds 50MB limit. Please select a smaller video.');
          }
          return;
        }

        setState(() {
          _isVideoUploading = true;
        });

        // Compress video if it's larger than 10MB while maintaining HD quality
        File compressedVideoFile = videoFile;
        if (fileSizeInMB > 10) {
          try {
            if (mounted) {
              _showSnackBar('Compressing video to maintain quality...');
            }

            // Start compression with HD quality
            final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
              videoFile.path,
              quality: VideoQuality.MediumQuality, // HD quality
              deleteOrigin: false,
              includeAudio: true,
            );

            if (mediaInfo != null && mediaInfo.file != null) {
              compressedVideoFile = mediaInfo.file!;
            }
          } catch (e) {
            if (mounted) {
              _showSnackBar('Error compressing video: $e. Using original video.');
            }
          }
        }

        setState(() {
          _isVideoUploading = false;
          _selectedVideos.add(compressedVideoFile);
        });
      }
    } catch (e) {
      setState(() {
        _isVideoUploading = false;
      });
      if (mounted) {
        _showSnackBar('Error picking video: $e');
      }
    }
  }

  void _removeVideo(int index) {
    setState(() {
      _selectedVideos.removeAt(index);
    });
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  Future<void> _submitReport() async {
    // Validate form
    if (_selectedIssueType == null || _selectedIssueType!.isEmpty) {
      _showSnackBar('Please select an issue type');
      return;
    }

    if (_addressController.text.trim().isEmpty) {
      _showSnackBar('Please enter an address');
      return;
    }

    if (_addressDetailsController.text.trim().isEmpty) {
      _showSnackBar('Please provide address details (landmarks, nearby establishments, etc.)');
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      _showSnackBar('Please provide a description');
      return;
    }

    try {
      setState(() {
        _isUploading = true;
      });

      // Upload photos if any
      List<String> photoUrls = [];
      if (_selectedPhotos.isNotEmpty) {
        photoUrls = await _reportService.uploadReportPhotos(_selectedPhotos);
      }

      // Upload videos if any
      List<String> videoUrls = [];
      if (_selectedVideos.isNotEmpty) {
        setState(() {
          _isVideoUploading = true;
        });
        videoUrls = await _reportService.uploadReportVideos(_selectedVideos);
        setState(() {
          _isVideoUploading = false;
        });
      }

      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw 'You must be logged in to submit a report';
      }

      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        throw 'User data not found';
      }

      await _reportService.createReport(
        userId: currentUser.uid,
        communityId: userDoc.data()!['communityId'],
        issueType: _selectedIssueType!,
        description: _descriptionController.text,
        address: _addressDetailsController.text.isNotEmpty
            ? "${_addressController.text} (${_addressDetailsController.text})"
            : _addressController.text,
        location: {}, // Map implementation removed
        photoUrls: photoUrls,
        videoUrls: videoUrls,
      );

      setState(() {
        _isUploading = false;
      });

      if (mounted) {
        ReportSuccessDialog.show(context, () {
          _tabController.animateTo(1); // Switch to My Reports tab
        });
      }

      // Reset form
      setState(() {
        _selectedIssueType = null;
        _issueTypeController.clear();
        _addressController.clear();
        _addressDetailsController.clear();
        _descriptionController.clear();
        _selectedPhotos.clear();
        _selectedVideos.clear();
        // Location reset simplified
        _currentStep = 0;
        _hasConfirmedInfo = false;
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
        _isVideoUploading = false;
      });
      _showSnackBar('Failed to submit report: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF00C49A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Community Reports',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF00C49A),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside
          FocusScope.of(context).unfocus();
        },
        child: TabBarView(
          controller: _tabController,
          children: [
            // New Report Tab
            _buildNewReportTab(),

            // My Reports Tab
            _buildMyReportsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildNewReportTab() {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              // Progress Stepper
              ReportStepper(
                currentStep: _currentStep,
                maxAllowedStep: _getMaxAllowedStep(),
                onStepTapped: (step) {
                  setState(() {
                    _currentStep = step;
                  });
                },
              ),

              // Form Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildStepContent(),
              ),
            ],
          ),
        ),

        // Loading Overlay
        if (_isUploading || _isVideoUploading || _isGettingLocation)
          Container(
            color: Colors.black.withAlpha(77), // 0.3 opacity
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isGettingLocation
                        ? 'Getting your location...'
                        : (_isVideoUploading ? 'Compressing video...' : 'Uploading report...'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  int _getMaxAllowedStep() {
    if (_selectedIssueType == null || _selectedIssueType!.isEmpty) {
      return 0;
    }

    if (_addressController.text.trim().isEmpty ||
        _addressDetailsController.text.trim().isEmpty) {
      return 1;
    }

    return 2;
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildDetailsStep();
      case 1:
        return _buildLocationStep();
      case 2:
        return _buildReviewStep();
      default:
        return _buildDetailsStep();
    }
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step Title
        const Text(
          'Report Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Provide information about the issue you want to report',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 20),

        // Issue Type Field
        ReportFormField(
          label: 'Issue Type',
          isRequired: true,
          child: SearchableDropdown(
            controller: _issueTypeController,
            items: _filteredIssueTypes,
            selectedItem: _selectedIssueType,
            hintText: 'Select or type issue type',
            onSearch: _filterIssueTypes,
            allowCustomValue: true, // Allow users to enter custom issue types
            onItemSelected: (value) {
              setState(() {
                _selectedIssueType = value;
                _issueTypeController.text = value;
              });
            },
          ),
        ),

        // Description Field
        ReportFormField(
          label: 'Description',
          isRequired: true,
          child: TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Describe the issue in detail...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.all(12),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ),

        // Photo Upload Section
        ReportFormField(
          label: 'Photos/Videos',
          isRequired: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showPhotoSourceOptions(),
                    icon: const Icon(Icons.add_a_photo, size: 16),
                    label: const Text('Add Photos'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00C49A),
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showVideoSourceOptions(),
                    icon: const Icon(Icons.videocam, size: 16),
                    label: const Text('Add Video'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00C49A),
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Max file size: 50MB (larger files will be compressed)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (_selectedPhotos.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedPhotos.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(_selectedPhotos[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 12,
                            top: 4,
                            child: GestureDetector(
                              onTap: () => _removePhoto(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(128), // 0.5 opacity
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
              if (_selectedVideos.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Selected Videos:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedVideos.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.play_circle_fill,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 12,
                            top: 4,
                            child: GestureDetector(
                              onTap: () => _removeVideo(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(128), // 0.5 opacity
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),

        // Next Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _selectedIssueType != null &&
                    _descriptionController.text.isNotEmpty
                ? () {
                    setState(() {
                      _currentStep = 1;
                    });
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C49A),
              disabledBackgroundColor: Colors.grey.shade300,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Next: Location'),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step Title
        const Text(
          'Location Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Provide the exact location of the issue',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 20),

        // Address Field
        ReportFormField(
          label: 'Address',
          isRequired: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  hintText: 'Enter the full address',
                  prefixIcon:
                      const Icon(Icons.location_on, color: Color(0xFF00C49A)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              TextButton.icon(
                onPressed: _isGettingLocation ? null : () {
                  _getCurrentLocation();
                },
                icon: _isGettingLocation
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
                        ),
                      )
                    : const Icon(Icons.my_location, size: 14),
                label: Text(_isGettingLocation ? 'Getting location...' : 'Use current location'),
                style: TextButton.styleFrom(
                  foregroundColor: _isGettingLocation ? Colors.grey : const Color(0xFF00C49A),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),

        // Address Details Field
        ReportFormField(
          label: 'Address Details',
          isRequired: true,
          child: TextFormField(
            controller: _addressDetailsController,
            decoration: InputDecoration(
              hintText: 'e.g., Near SM Mall, beside 7-Eleven, Barangay Hall, etc.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ),

        // Map View removed as requested
        const SizedBox(height: 16),

        // Navigation Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep = 0;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00C49A),
                  side: const BorderSide(color: Color(0xFF00C49A)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _addressController.text.isNotEmpty &&
                           _addressDetailsController.text.trim().isNotEmpty
                    ? () {
                        setState(() {
                          _currentStep = 2;
                        });
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C49A),
                  disabledBackgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Next: Review'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step Title
        const Text(
          'Review Your Report',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Please review your report details before submitting',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 20),

        // Review Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              // Issue Type
              ReportReviewItem(
                icon: Icons.report_problem_outlined,
                label: 'Issue Type',
                value: _selectedIssueType ?? '',
                onEdit: () => setState(() => _currentStep = 0),
              ),
              const Divider(height: 24),

              // Description
              ReportReviewItem(
                icon: Icons.description_outlined,
                label: 'Description',
                value: _descriptionController.text,
                onEdit: () => setState(() => _currentStep = 0),
              ),
              const Divider(height: 24),

              // Location
              ReportReviewItem(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: '${_addressController.text}${_addressDetailsController.text.isNotEmpty ? " (${_addressDetailsController.text})" : ""}',
                onEdit: () => setState(() => _currentStep = 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Terms Checkbox
        Row(
          children: [
            Checkbox(
              value: _hasConfirmedInfo,
              onChanged: (value) {
                setState(() {
                  _hasConfirmedInfo = value ?? false;
                });
              },
              activeColor: const Color(0xFF00C49A),
            ),
            Expanded(
              child: Text(
                'I confirm that the information provided is accurate to the best of my knowledge',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Navigation Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep = 1;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00C49A),
                  side: const BorderSide(color: Color(0xFF00C49A)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _hasConfirmedInfo ? _submitReport : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C49A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Submit Report'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMyReportsTab() {
    return Column(
      children: [
        // Status Filter
        Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ReportFilterChip(
                  label: 'All',
                  isSelected: _selectedFilter == 'All',
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = 'All';
                    });
                  },
                ),
                ...ReportStatus.values
                    .where((status) => status != ReportStatus.underReview) // Exclude Under Review status
                    .map((status) => ReportFilterChip(
                      label: status.value
                          .split('_')
                          .map((word) => word[0].toUpperCase() + word.substring(1))
                          .join(' '),
                      isSelected: _selectedFilter == status.value,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = status.value;
                        });
                      },
                    )),
              ],
            ),
          ),
        ),

        // Reports Stream
        Expanded(
          child: StreamBuilder<List<Report>>(
            stream: _getFilteredReportsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading reports: ${snapshot.error}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
                  ),
                );
              }

              final reports = snapshot.data!;
              if (reports.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.report_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No reports found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index];
                  return UserReportCard(
                    title: report.issueType,
                    location: report.address,
                    date: _formatDate(report.createdAt),
                    status: report.status.value
                        .split('_')
                        .map((word) => word[0].toUpperCase() + word.substring(1))
                        .join(' '),
                    statusColor: _getStatusColor(report.status),
                    onViewDetails: () {
                      showDialog(
                        context: context,
                        builder: (context) => UserReportDetailDialog(report: report),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    // Convert to 12-hour format
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final formattedTime = '$hour:${date.minute.toString().padLeft(2, '0')} $period';

    if (difference.inDays == 0) {
      return 'Today, $formattedTime';
    } else if (difference.inDays == 1) {
      return 'Yesterday, $formattedTime';
    } else {
      return '${date.day}/${date.month}/${date.year}, $formattedTime';
    }
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return Colors.orange;
      case ReportStatus.underReview:
        return Colors.blue;
      case ReportStatus.inProgress:
        return Colors.purple;
      case ReportStatus.resolved:
        return Colors.green;
      case ReportStatus.rejected:
        return Colors.red;
    }
  }
}
