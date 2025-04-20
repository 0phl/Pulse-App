import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:video_compress/video_compress.dart';
import '../models/community_notice.dart';
import '../services/admin_service.dart';
import '../services/cloudinary_service.dart';

class CreateNoticeSheet extends StatefulWidget {
  final CommunityNotice? notice;

  const CreateNoticeSheet({super.key, this.notice});

  @override
  State<CreateNoticeSheet> createState() => _CreateNoticeSheetState();
}

class _CreateNoticeSheetState extends State<CreateNoticeSheet>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _adminService = AdminService();
  final _imagePicker = ImagePicker();
  final _cloudinaryService = CloudinaryService();

  // Tab controller
  late TabController _tabController;
  int _currentTabIndex = 0;

  // Error states
  bool _contentError = false;
  bool _pollQuestionError = false;
  List<bool> _pollOptionErrors = [false, false];

  // Media state variables for Community Notice
  List<XFile> _selectedImages = [];
  XFile? _selectedVideo;
  List<XFile> _selectedAttachments = [];
  bool _showPollCreator = false;

  // Media state variables for Poll
  List<XFile> _pollSelectedImages = [];
  XFile? _pollSelectedVideo;
  List<XFile> _pollSelectedAttachments = [];

  // Variables to track existing media for community notices
  List<String> _existingImageUrls = [];
  String? _existingVideoUrl;
  List<Map<String, dynamic>> _existingAttachments = [];

  // Variables to track existing media for polls
  List<String> _existingPollImageUrls = [];
  String? _existingPollVideoUrl;
  List<Map<String, dynamic>> _existingPollAttachments = [];

  // Poll state variables
  final _pollQuestionController = TextEditingController();
  final List<TextEditingController> _pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  DateTime _pollExpiryDate = DateTime.now().add(const Duration(days: 7));
  bool _allowMultipleChoices = false;

  // Loading state
  bool _isLoading = false;
  bool _isUploadingMedia = false;

  @override
  void initState() {
    super.initState();

    // Determine if this is a new post, a regular notice, or a poll
    bool isNewPost = widget.notice == null;
    bool isPoll = !isNewPost && widget.notice!.poll != null;
    // A poll is considered primary if it has no content or if it has images
    bool isPrimaryPoll = isPoll &&
        (widget.notice!.content.isEmpty ||
            widget.notice!.content.length < 10 ||
            (widget.notice!.poll!.imageUrls != null &&
                widget.notice!.poll!.imageUrls!.isNotEmpty) ||
            (widget.notice!.imageUrls != null &&
                widget.notice!.imageUrls!.isNotEmpty));

    // For new posts: show both tabs
    // For regular notices: show only Community Notice tab
    // For polls: show only Poll tab if it's primarily a poll, otherwise show both tabs
    int tabCount = isNewPost ? 2 : (isPrimaryPoll ? 1 : (isPoll ? 2 : 1));

    // Initialize tab controller with appropriate length
    _tabController = TabController(length: tabCount, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging &&
          _tabController.index != _currentTabIndex) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });

    // Set initial tab for polls
    if (isPrimaryPoll) {
      _currentTabIndex = 0; // Only one tab (Poll)
    } else if (isPoll && tabCount > 1) {
      _currentTabIndex = 1; // Second tab (Poll)
      // Only animate if we have more than one tab
      if (_tabController.length > 1) {
        _tabController.animateTo(1);
      }
    }

    if (widget.notice != null) {
      _titleController.text = widget.notice!.title;
      _contentController.text = widget.notice!.content;

      // Initialize existing media if available
      if (widget.notice!.imageUrls != null &&
          widget.notice!.imageUrls!.isNotEmpty) {
        _existingImageUrls = List<String>.from(widget.notice!.imageUrls!);
      }

      if (widget.notice!.videoUrl != null) {
        _existingVideoUrl = widget.notice!.videoUrl;
      }

      if (widget.notice!.attachments != null &&
          widget.notice!.attachments!.isNotEmpty) {
        _existingAttachments = widget.notice!.attachments!
            .map((attachment) => attachment.toMap())
            .toList();
      }

      // Initialize poll data if exists
      if (widget.notice!.poll != null) {
        _showPollCreator = true;
        _pollQuestionController.text = widget.notice!.poll!.question;
        _pollExpiryDate = widget.notice!.poll!.expiresAt;
        _allowMultipleChoices = widget.notice!.poll!.allowMultipleChoices;

        // Initialize poll options
        _pollOptionControllers.clear();
        for (var option in widget.notice!.poll!.options) {
          _pollOptionControllers.add(TextEditingController(text: option.text));
        }

        // Load poll images if available
        if (widget.notice!.poll!.imageUrls != null &&
            widget.notice!.poll!.imageUrls!.isNotEmpty) {
          // Store poll images in _existingPollImageUrls
          _existingPollImageUrls =
              List<String>.from(widget.notice!.poll!.imageUrls!);

          // We will now display directly from _existingPollImageUrls when on the poll tab,
          // so no need to copy them to _existingImageUrls.
          // _existingImageUrls =
          //     List<String>.from(widget.notice!.poll!.imageUrls!);
        }

        // Load poll video if available
        if (widget.notice!.poll!.videoUrl != null) {
          _existingPollVideoUrl = widget.notice!.poll!.videoUrl;
          _existingVideoUrl =
              widget.notice!.poll!.videoUrl; // For display purposes
        }

        // Load poll attachments if available
        if (widget.notice!.poll!.attachments != null &&
            widget.notice!.poll!.attachments!.isNotEmpty) {
          _existingPollAttachments = widget.notice!.poll!.attachments!
              .map((attachment) => attachment.toMap())
              .toList();

          // Also store in _existingAttachments for display purposes
          _existingAttachments.clear();
          _existingAttachments.addAll(_existingPollAttachments);
        }

        // Always set tab to Poll when editing a poll
        if (_tabController.length == 1) {
          // Single tab poll (primary poll)
          _currentTabIndex = 0;
        } else {
          // Two tabs - select the poll tab
          _tabController.animateTo(1);
          _currentTabIndex = 1;
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _pollQuestionController.dispose();
    for (var controller in _pollOptionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Pick multiple images
  Future<void> _pickImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(
        imageQuality: 70,
      );
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
  }

  // Pick a video
  Future<void> _pickVideo() async {
    try {
      final video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (video != null) {
        // Check file size
        final File videoFile = File(video.path);
        final int fileSizeInBytes = await videoFile.length();
        final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

        // Allow larger videos since we'll compress them
        if (fileSizeInMB > 100) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Video size exceeds 100MB limit. Please select a smaller video.')),
            );
          }
          return;
        }

        // Check file extension
        final String fileName =
            video.path.split(Platform.isWindows ? '\\' : '/').last;
        final String fileExtension = fileName.contains('.')
            ? fileName.split('.').last.toLowerCase()
            : '';
        final List<String> supportedFormats = [
          'mp4',
          'mov',
          'avi',
          'wmv',
          'flv',
          'mkv',
          'webm'
        ];

        if (!supportedFormats.contains(fileExtension)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Unsupported video format: $fileExtension. Supported formats are: ${supportedFormats.join(', ')}')),
            );
          }
          return;
        }

        setState(() {
          _selectedVideo = video;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking video: $e')),
        );
      }
    }
  }

  // Pick file attachments
  Future<void> _pickAttachments() async {
    try {
      // Use a file picker package to pick files
      // For now, we'll use image picker as a placeholder
      final attachment = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (attachment != null) {
        setState(() {
          _selectedAttachments.add(attachment);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking attachment: $e')),
        );
      }
    }
  }

  // Poll-specific media methods
  // Pick images from gallery for Poll
  Future<void> _pickPollImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(
        imageQuality: 70,
      );
      if (images.isNotEmpty) {
        setState(() {
          _pollSelectedImages.addAll(images);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking poll images: $e')),
        );
      }
    }
  }

  // Pick a video for Poll
  Future<void> _pickPollVideo() async {
    try {
      final video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (video != null) {
        // Check file size
        final File videoFile = File(video.path);
        final int fileSizeInBytes = await videoFile.length();
        final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

        // Allow larger videos since we'll compress them
        if (fileSizeInMB > 100) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Video size exceeds 100MB limit. Please select a smaller video.')),
            );
          }
          return;
        }

        // Check file extension
        final String fileName =
            video.path.split(Platform.isWindows ? '\\' : '/').last;
        final String fileExtension = fileName.contains('.')
            ? fileName.split('.').last.toLowerCase()
            : '';
        final List<String> supportedFormats = [
          'mp4',
          'mov',
          'avi',
          'wmv',
          'flv',
          'mkv',
          'webm'
        ];

        if (!supportedFormats.contains(fileExtension)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Unsupported video format: $fileExtension. Supported formats are: ${supportedFormats.join(', ')}')),
            );
          }
          return;
        }

        setState(() {
          _pollSelectedVideo = video;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking poll video: $e')),
        );
      }
    }
  }

  // Pick file attachments for Poll
  Future<void> _pickPollAttachments() async {
    try {
      // Use a file picker package to pick files
      // For now, we'll use image picker as a placeholder
      final attachment = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (attachment != null) {
        setState(() {
          _pollSelectedAttachments.add(attachment);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking poll attachment: $e')),
        );
      }
    }
  }

  // Upload all images
  Future<List<String>> _uploadImages() async {
    if (_selectedImages.isEmpty) return [];

    setState(() => _isUploadingMedia = true);
    try {
      final List<File> imageFiles =
          _selectedImages.map((xFile) => File(xFile.path)).toList();
      final List<String> imageUrls =
          await _cloudinaryService.uploadNoticeImages(imageFiles);
      return imageUrls;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading images: $e')),
        );
      }
      return [];
    } finally {
      if (mounted) {
        setState(() => _isUploadingMedia = false);
      }
    }
  }

  // Upload video
  Future<String?> _uploadVideo() async {
    if (_selectedVideo == null) return null;

    setState(() => _isUploadingMedia = true);
    try {
      final videoFile = File(_selectedVideo!.path);

      // Get file info for debugging if needed
      // final String fileName = videoFile.path.split(Platform.isWindows ? '\\' : '/').last;
      // final String fileExtension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
      // final int fileSizeInBytes = await videoFile.length();
      // final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

      final videoUrl = await _cloudinaryService.uploadNoticeVideo(videoFile);
      return videoUrl;
    } catch (e) {
      // Video upload error occurred
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading video: $e'),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isUploadingMedia = false);
      }
    }
  }

  // Upload attachments
  Future<List<Map<String, dynamic>>> _uploadAttachments() async {
    if (_selectedAttachments.isEmpty) return [];

    setState(() => _isUploadingMedia = true);
    try {
      final List<Map<String, dynamic>> attachmentData = [];

      for (var attachment in _selectedAttachments) {
        final File file = File(attachment.path);
        final String fileName = attachment.name;
        final int fileSize = await file.length();
        final String fileType = fileName.split('.').last.toLowerCase();

        final String url =
            await _cloudinaryService.uploadNoticeAttachment(file);

        attachmentData.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'name': fileName,
          'url': url,
          'type': fileType,
          'size': fileSize,
        });
      }

      return attachmentData;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading attachments: $e')),
        );
      }
      return [];
    } finally {
      if (mounted) {
        setState(() => _isUploadingMedia = false);
      }
    }
  }

  // Upload poll images
  Future<List<String>> _uploadPollImages() async {
    if (_pollSelectedImages.isEmpty) return [];

    setState(() => _isUploadingMedia = true);
    try {
      final List<File> imageFiles =
          _pollSelectedImages.map((xFile) => File(xFile.path)).toList();
      final List<String> newPollImageUrls =
          await _cloudinaryService.uploadNoticeImages(imageFiles);

      if (mounted) {
        setState(() => _isUploadingMedia = false);
      }
      return newPollImageUrls;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading poll images: $e')),
        );
      }
      if (mounted) {
        setState(() => _isUploadingMedia = false);
      }
      return [];
    }
  }

  // Upload poll video
  Future<String?> _uploadPollVideo() async {
    if (_pollSelectedVideo == null) return null;

    setState(() => _isUploadingMedia = true);
    try {
      final videoFile = File(_pollSelectedVideo!.path);
      final videoUrl = await _cloudinaryService.uploadNoticeVideo(videoFile);
      return videoUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading poll video: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isUploadingMedia = false);
      }
    }
  }

  // Upload poll attachments
  Future<List<Map<String, dynamic>>> _uploadPollAttachments() async {
    if (_pollSelectedAttachments.isEmpty) return [];

    setState(() => _isUploadingMedia = true);
    try {
      final List<Map<String, dynamic>> attachmentData = [];

      for (var attachment in _pollSelectedAttachments) {
        final File file = File(attachment.path);
        final String fileName = attachment.name;
        final int fileSize = await file.length();
        final String fileType = fileName.split('.').last.toLowerCase();

        final String url =
            await _cloudinaryService.uploadNoticeAttachment(file);

        attachmentData.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'name': fileName,
          'url': url,
          'type': fileType,
          'size': fileSize,
        });
      }

      return attachmentData;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading poll attachments: $e')),
        );
      }
      return [];
    } finally {
      if (mounted) {
        setState(() => _isUploadingMedia = false);
      }
    }
  }

  Future<void> _saveNotice() async {
    // Reset all error states
    setState(() {
      _contentError = false;
      _pollQuestionError = false;
      for (int i = 0; i < _pollOptionErrors.length; i++) {
        _pollOptionErrors[i] = false;
      }
    });

    // Validate based on current tab
    if (_currentTabIndex == 0 && _contentController.text.isEmpty) {
      // Community Notice tab requires content
      setState(() {
        _contentError = true;
      });
      return;
    } else if (_currentTabIndex == 1) {
      // Poll tab requires question and at least 2 options
      bool hasValidationErrors = false;

      // Check poll question
      if (_pollQuestionController.text.isEmpty) {
        setState(() {
          _pollQuestionError = true;
          hasValidationErrors = true;
        });
      }

      // Check poll options
      int validOptions = 0;
      for (int i = 0; i < _pollOptionControllers.length; i++) {
        // Ensure _pollOptionErrors has enough entries
        while (_pollOptionErrors.length <= i) {
          _pollOptionErrors.add(false);
        }

        if (_pollOptionControllers[i].text.trim().isEmpty) {
          setState(() {
            _pollOptionErrors[i] = true;
            hasValidationErrors = true;
          });
        } else {
          validOptions++;
        }
      }

      // Show a message if we need more options
      if (validOptions < 2) {
        // If we have fewer than 2 valid options, show a message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least 2 poll options')),
        );
        hasValidationErrors = true;
      }

      if (hasValidationErrors) {
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      // Prepare media lists based on the current tab
      List<String> imageUrls = [];
      String? videoUrl;
      List<Map<String, dynamic>> attachmentsData = [];
      Map<String, dynamic>? pollData;

      // Only include media in the appropriate section based on current tab
      if (_currentTabIndex == 0) {
        // Community Notice tab - use notice media
        imageUrls = List<String>.from(_existingImageUrls);
        videoUrl = _existingVideoUrl;
        attachmentsData = List<Map<String, dynamic>>.from(_existingAttachments);
      } else {
        // Poll tab - media will be included in poll data only
        // Explicitly clear notice media when saving from the poll tab
        imageUrls = [];
        videoUrl = null;
        attachmentsData = [];
      }

      // Upload images if any
      if (_selectedImages.isNotEmpty) {
        setState(() => _isUploadingMedia = true);
        final List<File> imageFiles =
            _selectedImages.map((xFile) => File(xFile.path)).toList();
        final List<String> newImageUrls =
            await _cloudinaryService.uploadNoticeImages(imageFiles);
        // Add new images to existing ones instead of replacing them
        imageUrls.addAll(newImageUrls);
        setState(() => _isUploadingMedia = false);
      }

      // Upload video if selected
      if (_selectedVideo != null) {
        setState(() => _isUploadingMedia = true);
        try {
          final videoFile = File(_selectedVideo!.path);

          // Get file info for debugging if needed
          // final String fileName = videoFile.path.split(Platform.isWindows ? '\\' : '/').last;
          // final String fileExtension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
          // final int fileSizeInBytes = await videoFile.length();
          // final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

          videoUrl = await _cloudinaryService.uploadNoticeVideo(videoFile);
        } catch (videoError) {
          // Video upload error occurred
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error uploading video: $videoError'),
                duration: const Duration(seconds: 8),
              ),
            );
          }
          // Continue with the rest of the notice creation without the video
        } finally {
          if (mounted) {
            setState(() => _isUploadingMedia = false);
          }
        }
      }

      // Upload attachments if any
      if (_selectedAttachments.isNotEmpty) {
        setState(() => _isUploadingMedia = true);
        for (var attachment in _selectedAttachments) {
          final File file = File(attachment.path);
          final String fileName = attachment.name;
          final int fileSize = await file.length();
          final String fileType = fileName.split('.').last.toLowerCase();

          final String url =
              await _cloudinaryService.uploadNoticeAttachment(file);

          attachmentsData.add({
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'name': fileName,
            'url': url,
            'type': fileType,
            'size': fileSize,
          });
        }
        setState(() => _isUploadingMedia = false);
      }

      // Create poll data based on current tab or if poll creator is shown
      if (_currentTabIndex == 1 || _showPollCreator) {
        // Get existing poll options if editing
        final Map<String, Map<dynamic, dynamic>> existingVotes = {};
        if (widget.notice?.poll != null) {
          for (var option in widget.notice!.poll!.options) {
            existingVotes[option.text] = {
              'votedBy': option.votedBy.isEmpty
                  ? null
                  : {for (var userId in option.votedBy) userId: true}
            };
          }
        }

        // Filter out empty options and preserve votes for unchanged options
        final List<Map<String, dynamic>> options = [];
        for (int i = 0; i < _pollOptionControllers.length; i++) {
          final text = _pollOptionControllers[i].text.trim();
          if (text.isNotEmpty) {
            options.add({
              'id': i.toString(),
              'text': text,
              // Preserve votes if option text matches an existing option
              'votedBy': existingVotes[text]?['votedBy'],
            });
          }
        }

        // Upload poll media if any
        List<String> pollImageUrls = [];
        String? pollVideoUrl;
        List<Map<String, dynamic>> pollAttachmentsData = [];

        // Upload poll images if any
        if (_pollSelectedImages.isNotEmpty) {
          setState(() => _isUploadingMedia = true);
          final List<File> imageFiles =
              _pollSelectedImages.map((xFile) => File(xFile.path)).toList();
          final List<String> newPollImageUrls =
              await _cloudinaryService.uploadNoticeImages(imageFiles);
          // Add new images to list
          pollImageUrls = newPollImageUrls;
          setState(() => _isUploadingMedia = false);
        }

        // Upload poll video if selected
        if (_pollSelectedVideo != null) {
          setState(() => _isUploadingMedia = true);
          try {
            final videoFile = File(_pollSelectedVideo!.path);
            pollVideoUrl =
                await _cloudinaryService.uploadNoticeVideo(videoFile);
          } catch (videoError) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error uploading poll video: $videoError'),
                  duration: const Duration(seconds: 8),
                ),
              );
            }
          } finally {
            if (mounted) {
              setState(() => _isUploadingMedia = false);
            }
          }
        }

        // Upload poll attachments if any
        if (_pollSelectedAttachments.isNotEmpty) {
          setState(() => _isUploadingMedia = true);
          for (var attachment in _pollSelectedAttachments) {
            final File file = File(attachment.path);
            final String fileName = attachment.name;
            final int fileSize = await file.length();
            final String fileType = fileName.split('.').last.toLowerCase();

            final String url =
                await _cloudinaryService.uploadNoticeAttachment(file);

            pollAttachmentsData.add({
              'id': DateTime.now().millisecondsSinceEpoch.toString(),
              'name': fileName,
              'url': url,
              'type': fileType,
              'size': fileSize,
            });
          }
          setState(() => _isUploadingMedia = false);
        }

        // Handle poll images with separate tracking
        List<String> finalPollImageUrls = [];

        if (_pollSelectedImages.isNotEmpty) {
          // If new images were selected, add them to existing ones (don't completely replace)
          finalPollImageUrls = List<String>.from(_existingPollImageUrls);
          finalPollImageUrls.addAll(pollImageUrls);
        } else if (_existingPollImageUrls.isNotEmpty) {
          // Use the current state of _existingPollImageUrls which already reflects removals
          finalPollImageUrls = List<String>.from(_existingPollImageUrls);
        }

        // Handle poll video with separate tracking
        String? finalPollVideoUrl = pollVideoUrl;

        if (pollVideoUrl == null && _existingPollVideoUrl != null) {
          // Use the current state of _existingPollVideoUrl which already reflects removals
          finalPollVideoUrl = _existingPollVideoUrl;
        }

        // Handle poll attachments with separate tracking
        List<Map<String, dynamic>> finalPollAttachmentsData =
            pollAttachmentsData;

        if (pollAttachmentsData.isEmpty &&
            _existingPollAttachments.isNotEmpty) {
          // Use the current state of _existingPollAttachments which already reflects removals
          finalPollAttachmentsData =
              List<Map<String, dynamic>>.from(_existingPollAttachments);
        }

        // Create the poll data with proper handling of media
        pollData = {
          'question': _pollQuestionController.text,
          'options': options,
          'expiresAt': _pollExpiryDate.millisecondsSinceEpoch,
          'allowMultipleChoices': _allowMultipleChoices,
          // Always include imageUrls (null if empty)
          'imageUrls':
              finalPollImageUrls.isNotEmpty ? finalPollImageUrls : null,
          // Always include videoUrl (null if removed)
          'videoUrl': finalPollVideoUrl,
          // Only include attachments if we have any
          'attachments': finalPollAttachmentsData.isNotEmpty
              ? finalPollAttachmentsData
              : null,
        };

        // No debug logs in production code
      }

      if (widget.notice != null) {
        await _adminService.updateNotice(
          widget.notice!.id,
          _titleController.text,
          _contentController.text,
          null, // No longer using single imageUrl
          imageUrls: imageUrls,
          videoUrl: videoUrl,
          poll: pollData,
          attachments: attachmentsData.isNotEmpty ? attachmentsData : null,
        );
      } else {
        await _adminService.createNotice(
          _titleController.text,
          _contentController.text,
          null, // No longer using single imageUrl
          imageUrls: imageUrls.isNotEmpty ? imageUrls : null,
          videoUrl: videoUrl,
          poll: pollData,
          attachments: attachmentsData.isNotEmpty ? attachmentsData : null,
        );
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving notice: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper method to build image preview
  Widget _buildImagePreview(XFile image, VoidCallback onRemove) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        children: [
          // Image container
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              File(image.path),
              height: 100,
              width: 100,
              fit: BoxFit.cover,
            ),
          ),
          // Close button overlay
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build existing image preview
  Widget _buildExistingImagePreview(String imageUrl, VoidCallback onRemove) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        children: [
          // Image container
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              imageUrl,
              height: 100,
              width: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  height: 100,
                  width: 100,
                  child:
                      const Center(child: Icon(Icons.error_outline, size: 20)),
                );
              },
            ),
          ),
          // Close button overlay
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build video preview
  Widget _buildVideoPreview(XFile video, VoidCallback onRemove) {
    return FutureBuilder<Uint8List?>(
      future: _getVideoThumbnail(video.path),
      builder: (context, snapshot) {
        return SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            children: [
              // Video thumbnail container
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Show a thumbnail of the video file if possible
                      if (snapshot.hasData && snapshot.data != null)
                        Image.memory(
                          snapshot.data!,
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              height: 100,
                              width: 100,
                            );
                          },
                        )
                      else
                        Container(
                          color: Colors.grey[300],
                          height: 100,
                          width: 100,
                          child: snapshot.connectionState ==
                                  ConnectionState.waiting
                              ? const Center(
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : null,
                        ),
                      // Play icon overlay
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.play_arrow,
                            color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                ),
              ),
              // Close button overlay
              Positioned(
                right: 268,
                top: 4,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper method to build existing video preview
  Widget _buildExistingVideoPreview(String videoUrl, VoidCallback onRemove) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        children: [
          // Video thumbnail container
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Video placeholder with network image
                  Image.network(
                    // Extract thumbnail from video URL if possible
                    videoUrl.replaceFirst('.mp4', '.jpg'),
                    height: 100,
                    width: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to a colored container if thumbnail not available
                      return Container(
                        color: Colors.grey[300],
                        height: 100,
                        width: 100,
                      );
                    },
                  ),
                  // Play icon overlay
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.play_arrow,
                        color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),
          ),
          // Close button overlay
          Positioned(
            right: 268,
            top: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Get video thumbnail using VideoCompress
  Future<Uint8List?> _getVideoThumbnail(String videoPath) async {
    try {
      final thumbnail = await VideoCompress.getByteThumbnail(
        videoPath,
        quality: 50, // 0-100, higher is better quality
        position: -1, // -1 means get thumbnail from the middle of the video
      );
      return thumbnail;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating video thumbnail: $e')),
        );
      }
      return null;
    }
  }

  // Helper method to build attachment preview
  Widget _buildAttachmentPreview(XFile file, VoidCallback onRemove) {
    final String fileName = file.name;
    final String extension =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

    IconData iconData;
    Color iconColor;

    // Determine icon based on file type
    if (['pdf'].contains(extension)) {
      iconData = Icons.picture_as_pdf;
      iconColor = Colors.red;
    } else if (['doc', 'docx'].contains(extension)) {
      iconData = Icons.description;
      iconColor = Colors.blue;
    } else if (['xls', 'xlsx'].contains(extension)) {
      iconData = Icons.table_chart;
      iconColor = Colors.green;
    } else if (['ppt', 'pptx'].contains(extension)) {
      iconData = Icons.slideshow;
      iconColor = Colors.orange;
    } else {
      iconData = Icons.insert_drive_file;
      iconColor = Colors.grey;
    }

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(iconData, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    FutureBuilder<int>(
                      future: File(file.path).length(),
                      builder: (context, snapshot) {
                        final size = snapshot.data ?? 0;
                        final sizeText = size < 1024 * 1024
                            ? '${(size / 1024).toStringAsFixed(1)} KB'
                            : '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
                        return Text(
                          sizeText,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600]),
                        );
                      },
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 14),
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method to determine if we should show community notice content
  bool _shouldShowCommunityNoticeContent() {
    bool isNewPost = widget.notice == null;
    bool isPoll = !isNewPost && widget.notice!.poll != null;
    // A poll is considered primary if it has no content or if it has images
    bool isPrimaryPoll = isPoll &&
        (widget.notice!.content.isEmpty ||
            widget.notice!.content.length < 10 ||
            (widget.notice!.poll!.imageUrls != null &&
                widget.notice!.poll!.imageUrls!.isNotEmpty) ||
            (widget.notice!.imageUrls != null &&
                widget.notice!.imageUrls!.isNotEmpty));

    // For primary polls with only one tab, we should show poll content
    if (isPrimaryPoll) {
      return false;
    }

    // For polls, show poll content when tab index is 1 or when there's only one tab
    if (isPoll) {
      if (_tabController.length == 1) {
        return false; // Show poll content for single-tab poll
      }
      return _currentTabIndex ==
          0; // Show community notice content only when tab index is 0
    }

    // For new posts, check the current tab index
    if (isNewPost) {
      return _currentTabIndex ==
          0; // Show community notice content only when tab index is 0
    }

    // For regular notices, always show community notice content
    return true;
  }

  // Helper method to determine which tabs to show based on notice type
  List<Widget> _buildTabsBasedOnNoticeType() {
    bool isNewPost = widget.notice == null;
    bool isPoll = !isNewPost && widget.notice!.poll != null;
    // A poll is considered primary if it has no content or if it has images
    bool isPrimaryPoll = isPoll &&
        (widget.notice!.content.isEmpty ||
            widget.notice!.content.length < 10 ||
            (widget.notice!.poll!.imageUrls != null &&
                widget.notice!.poll!.imageUrls!.isNotEmpty) ||
            (widget.notice!.imageUrls != null &&
                widget.notice!.imageUrls!.isNotEmpty));

    if (isNewPost) {
      // New post - show both tabs
      return const [
        Tab(text: 'Community Notice'),
        Tab(text: 'Poll'),
      ];
    } else if (isPrimaryPoll) {
      // Primary poll - show only Poll tab
      return const [
        Tab(text: 'Poll'),
      ];
    } else if (isPoll) {
      // Poll with content - show both tabs
      return const [
        Tab(text: 'Community Notice'),
        Tab(text: 'Poll'),
      ];
    } else {
      // Regular notice - show only Community Notice tab
      return const [
        Tab(text: 'Community Notice'),
      ];
    }
  }

  // Helper method to build poll option input
  Widget _buildPollOptionInput(TextEditingController controller, int index) {
    // Ensure _pollOptionErrors has enough entries
    while (_pollOptionErrors.length <= index) {
      _pollOptionErrors.add(false);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: const Color(0xFF00C49A).withOpacity(0.1),
          child: Text(
            String.fromCharCode(65 + index), // A, B, C, etc.
            style: const TextStyle(
              color: Color(0xFF00C49A),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Option ${index + 1}',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              filled: true,
              fillColor: Colors.white,
              errorText:
                  _pollOptionErrors[index] ? 'Please enter an option' : null,
              suffixIcon: index > 1
                  ? IconButton(
                      icon:
                          const Icon(Icons.close, size: 16, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _pollOptionControllers.removeAt(index);
                          _pollOptionErrors.removeAt(index);
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              if (_pollOptionErrors[index] && value.isNotEmpty) {
                setState(() {
                  _pollOptionErrors[index] = false;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.notice != null ? 'Edit' : 'Create',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Show tabs based on the type of post
                  TabBar(
                    controller: _tabController,
                    tabs: _buildTabsBasedOnNoticeType(),
                    labelColor: Theme.of(context).primaryColor,
                    indicatorColor: Theme.of(context).primaryColor,
                    dividerColor: Colors.transparent,
                  ),
                  const SizedBox(height: 8),
                  // Dynamic content based on selected tab
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _shouldShowCommunityNoticeContent()
                        // Community Notice Tab
                        ? Column(
                            key: const ValueKey('notice'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _titleController,
                                decoration: const InputDecoration(
                                  hintText: 'Title (optional)',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _contentController,
                                decoration: InputDecoration(
                                  hintText:
                                      'What\'s happening in your community?',
                                  border: const OutlineInputBorder(),
                                  errorBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.red),
                                  ),
                                  focusedErrorBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.red),
                                  ),
                                  errorText: _contentError
                                      ? 'Please enter some content'
                                      : null,
                                  helperText: 'Content is required',
                                  helperStyle: const TextStyle(
                                      fontStyle: FontStyle.italic),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                                maxLines: 3,
                                onChanged: (value) {
                                  if (_contentError && value.isNotEmpty) {
                                    setState(() {
                                      _contentError = false;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          _isLoading ? null : _pickImages,
                                      icon: const Icon(Icons.photo_library,
                                          size: 18),
                                      label: const Text('Photos',
                                          style: TextStyle(fontSize: 13)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _isLoading ||
                                              _selectedVideo != null ||
                                              _existingVideoUrl != null
                                          ? null
                                          : _pickVideo,
                                      icon:
                                          const Icon(Icons.videocam, size: 18),
                                      label: const Text('Video',
                                          style: TextStyle(fontSize: 13)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          _isLoading ? null : _pickAttachments,
                                      icon: const Icon(Icons.attach_file,
                                          size: 18),
                                      label: const Text('Attachment',
                                          style: TextStyle(fontSize: 13)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Column(
                            key: const ValueKey('poll'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _titleController,
                                decoration: InputDecoration(
                                  hintText: 'Poll Title (optional)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  prefixIcon: const Icon(Icons.title,
                                      color: Color(0xFF00C49A)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _pollQuestionController,
                                decoration: InputDecoration(
                                  hintText: 'Ask a question...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: Colors.red),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: Colors.red),
                                  ),
                                  errorText: _pollQuestionError
                                      ? 'Please enter a poll question'
                                      : null,
                                  helperText: 'Poll question is required',
                                  helperStyle: const TextStyle(
                                      fontStyle: FontStyle.italic),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  prefixIcon: const Icon(Icons.help_outline,
                                      color: Color(0xFF00C49A)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Poll Options',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Color(0xFF00C49A)),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  children: [
                                    ...List.generate(
                                      _pollOptionControllers.length,
                                      (index) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: _buildPollOptionInput(
                                            _pollOptionControllers[index],
                                            index),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _pollOptionControllers
                                              .add(TextEditingController());
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        size: 18,
                                        color: Color(0xFF00C49A),
                                      ),
                                      label: const Text('Add Option',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF00C49A),
                                          )),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Poll Settings',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Color(0xFF00C49A)),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Allow multiple choices toggle
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_outline,
                                          size: 20,
                                          color: Color(0xFF00C49A),
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Text(
                                            'Allow multiple choices',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Switch(
                                          value: _allowMultipleChoices,
                                          onChanged: (value) {
                                            setState(() {
                                              _allowMultipleChoices = value;
                                            });
                                          },
                                          activeColor: const Color(0xFF00C49A),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 32),
                                    // Poll end date
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 20,
                                          color: Color(0xFF00C49A),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Poll ends:',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              // Date picker
                                              TextButton(
                                                onPressed: () async {
                                                  final pickedDate =
                                                      await showDatePicker(
                                                    context: context,
                                                    initialDate:
                                                        _pollExpiryDate,
                                                    firstDate: DateTime.now(),
                                                    lastDate:
                                                        DateTime.now().add(
                                                      const Duration(days: 365),
                                                    ),
                                                    builder: (context, child) {
                                                      return Theme(
                                                        data: Theme.of(context)
                                                            .copyWith(
                                                          colorScheme:
                                                              const ColorScheme
                                                                  .light(
                                                            primary: Color(
                                                                0xFF00C49A),
                                                          ),
                                                        ),
                                                        child: child!,
                                                      );
                                                    },
                                                  );
                                                  if (pickedDate != null) {
                                                    final newDate = DateTime(
                                                      pickedDate.year,
                                                      pickedDate.month,
                                                      pickedDate.day,
                                                      _pollExpiryDate.hour,
                                                      _pollExpiryDate.minute,
                                                    );
                                                    setState(() {
                                                      _pollExpiryDate = newDate;
                                                    });
                                                  }
                                                },
                                                style: TextButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    side: BorderSide(
                                                        color: Colors
                                                            .grey.shade300),
                                                  ),
                                                ),
                                                child: Text(
                                                  DateFormat('MMM d, yyyy')
                                                      .format(_pollExpiryDate),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 14,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Time picker
                                              TextButton(
                                                onPressed: () async {
                                                  final pickedTime =
                                                      await showTimePicker(
                                                    context: context,
                                                    initialTime:
                                                        TimeOfDay.fromDateTime(
                                                            _pollExpiryDate),
                                                    builder: (context, child) {
                                                      return Theme(
                                                        data: Theme.of(context)
                                                            .copyWith(
                                                          colorScheme:
                                                              const ColorScheme
                                                                  .light(
                                                            primary: Color(
                                                                0xFF00C49A),
                                                          ),
                                                        ),
                                                        child: child!,
                                                      );
                                                    },
                                                  );
                                                  if (pickedTime != null) {
                                                    final newDate = DateTime(
                                                      _pollExpiryDate.year,
                                                      _pollExpiryDate.month,
                                                      _pollExpiryDate.day,
                                                      pickedTime.hour,
                                                      pickedTime.minute,
                                                    );
                                                    setState(() {
                                                      _pollExpiryDate = newDate;
                                                    });
                                                  }
                                                },
                                                style: TextButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    side: BorderSide(
                                                        color: Colors
                                                            .grey.shade300),
                                                  ),
                                                ),
                                                child: Text(
                                                  DateFormat('h:mm a')
                                                      .format(_pollExpiryDate),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 14,
                                                    color: Colors.black87,
                                                  ),
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
                              const SizedBox(height: 8),
                              const Text(
                                'Description (optional)',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Color(0xFF00C49A)),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _contentController,
                                decoration: InputDecoration(
                                  hintText:
                                      'Add more details about your poll...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  prefixIcon: const Icon(
                                      Icons.description_outlined,
                                      color: Color(0xFF00C49A)),
                                ),
                                maxLines: 3,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Media (optional)',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Color(0xFF00C49A)),
                              ),
                              const SizedBox(height: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed:
                                        _isLoading ? null : _pickPollImages,
                                    icon: const Icon(Icons.photo_library,
                                        size: 18, color: Color(0xFF00C49A)),
                                    label: const Text('Add Photos',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF00C49A))),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: const BorderSide(
                                            color: Color(0xFF00C49A)),
                                      ),
                                      backgroundColor: const Color(0xFF00C49A)
                                          .withOpacity(0.05),
                                    ),
                                  ),

                                  // Directly show selected poll images
                                  if (_pollSelectedImages.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      'New Poll Images (${_pollSelectedImages.length})',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 100,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: _pollSelectedImages.length,
                                        itemBuilder: (context, index) {
                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(right: 8),
                                            child: Container(
                                              width: 100,
                                              height: 100,
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: Colors.grey),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Stack(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    child: Image.file(
                                                      File(_pollSelectedImages[
                                                              index]
                                                          .path),
                                                      width: 100,
                                                      height: 100,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                  Positioned(
                                                    top: 4,
                                                    right: 4,
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        setState(() {
                                                          _pollSelectedImages
                                                              .removeAt(index);
                                                        });
                                                      },
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(4),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.black
                                                              .withOpacity(0.5),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: const Icon(
                                                          Icons.close,
                                                          color: Colors.white,
                                                          size: 16,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                              // MOVED: Existing Poll Images preview - Show only if poll tab is active and images exist
                              if (_existingPollImageUrls.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                const Text(
                                  'Existing Poll Images',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500, fontSize: 14),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 120,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _existingPollImageUrls.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (context, index) {
                                      final imageUrl = _existingPollImageUrls[index];
                                      return _buildExistingImagePreview(
                                        imageUrl,
                                        () => setState(() {
                                          // Remove directly from the poll list
                                          _existingPollImageUrls.removeAt(index);
                                        }),
                                      );
                                    },
                                  ),
                                ),
                              ],
                              // END MOVED SECTION
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Existing Images preview - NOW ONLY FOR COMMUNITY NOTICE TAB
                  if (_currentTabIndex == 0 && _existingImageUrls.isNotEmpty) ...[
                    const Align( // Changed Text widget to const
                      alignment: Alignment.centerLeft,
                      child: Text( // Keep Text widget non-const if needed elsewhere, but seems fine here
                        'Existing Images', // No longer conditional
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _existingImageUrls.length, // Only notice images here
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final imageUrl = _existingImageUrls[index]; // Only notice images here
                          return _buildExistingImagePreview(
                            imageUrl,
                            () => setState(() {
                              // Only remove from notice list here
                              _existingImageUrls.removeAt(index);
                            }),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Existing Video preview
                  if (_existingVideoUrl != null) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Existing Video',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: _buildExistingVideoPreview(
                        _existingVideoUrl!,
                        () => setState(() {
                          // Remove from the appropriate list based on current tab
                          if (_currentTabIndex == 1) {
                            // Remove from poll video
                            _existingPollVideoUrl = null;
                          }
                          // Always remove from display variable
                          _existingVideoUrl = null;
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Media previews with minimal spacing
                  if (_selectedImages.isNotEmpty && _currentTabIndex == 0) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'New Images',
                        style: TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          return _buildImagePreview(
                            _selectedImages[index],
                            () =>
                                setState(() => _selectedImages.removeAt(index)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Video preview
                  if (_selectedVideo != null && _currentTabIndex == 0) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'New Video',
                        style: TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 100,
                      child: _buildVideoPreview(
                        _selectedVideo!,
                        () => setState(() => _selectedVideo = null),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Attachments preview
                  if (_selectedAttachments.isNotEmpty &&
                      _currentTabIndex == 0) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Attachments',
                        style: TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...List.generate(
                      _selectedAttachments.length,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _buildAttachmentPreview(
                          _selectedAttachments[index],
                          () => setState(
                              () => _selectedAttachments.removeAt(index)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Poll media previews - REMOVED - we now use the direct display above
                  // Poll media previews section removed

                  // Poll creator section removed - we now handle poll editing in the poll tab
                  const SizedBox(height: 8),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed:
                        _isLoading || _isUploadingMedia ? null : _saveNotice,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: const Color(0xFF00C49A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: _isLoading || _isUploadingMedia
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.notice != null
                                    ? Icons.save_outlined
                                    : _currentTabIndex == 0
                                        ? Icons.post_add
                                        : Icons.poll_outlined,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.notice != null
                                    ? 'Save Changes'
                                    : _currentTabIndex == 0
                                        ? 'Post Notice'
                                        : 'Create Poll',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
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
      ),
    );
  }
}
