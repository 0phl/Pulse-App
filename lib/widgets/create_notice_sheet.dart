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

class _CreateNoticeSheetState extends State<CreateNoticeSheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _adminService = AdminService();
  final _imagePicker = ImagePicker();
  final _cloudinaryService = CloudinaryService();

  // Media state variables
  List<XFile> _selectedImages = [];
  XFile? _selectedVideo;
  List<XFile> _selectedAttachments = [];
  bool _showPollCreator = false;

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
    if (widget.notice != null) {
      _titleController.text = widget.notice!.title;
      _contentController.text = widget.notice!.content;

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
      }
    }
  }

  @override
  void dispose() {
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

      // Get file info for better error messages
      final String fileName =
          videoFile.path.split(Platform.isWindows ? '\\' : '/').last;
      final String fileExtension =
          fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
      final int fileSizeInBytes = await videoFile.length();
      final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

      print(
          'Uploading video: $fileName, size: ${fileSizeInMB.toStringAsFixed(2)}MB, format: $fileExtension');

      final videoUrl = await _cloudinaryService.uploadNoticeVideo(videoFile);
      print('Video upload successful: $videoUrl');
      return videoUrl;
    } catch (e) {
      print('Video upload error: $e');
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

  Future<void> _saveNotice() async {
    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some content')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload all media
      List<String> imageUrls = [];
      String? videoUrl;
      List<Map<String, dynamic>> attachmentsData = [];
      Map<String, dynamic>? pollData;

      // Upload images if any
      if (_selectedImages.isNotEmpty) {
        setState(() => _isUploadingMedia = true);
        final List<File> imageFiles =
            _selectedImages.map((xFile) => File(xFile.path)).toList();
        imageUrls = await _cloudinaryService.uploadNoticeImages(imageFiles);
        setState(() => _isUploadingMedia = false);
      }

      // Upload video if selected
      if (_selectedVideo != null) {
        setState(() => _isUploadingMedia = true);
        try {
          final videoFile = File(_selectedVideo!.path);

          // Get file info for better error messages
          final String fileName =
              videoFile.path.split(Platform.isWindows ? '\\' : '/').last;
          final String fileExtension = fileName.contains('.')
              ? fileName.split('.').last.toLowerCase()
              : '';
          final int fileSizeInBytes = await videoFile.length();
          final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

          print(
              'Saving notice with video: $fileName, size: ${fileSizeInMB.toStringAsFixed(2)}MB, format: $fileExtension');

          videoUrl = await _cloudinaryService.uploadNoticeVideo(videoFile);
          print('Video upload successful during notice save: $videoUrl');
        } catch (videoError) {
          print('Video upload error during notice save: $videoError');
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

      // Create or update poll data if poll creator is shown
      if (_showPollCreator && _pollQuestionController.text.isNotEmpty) {
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
              'votedBy': existingVotes[text]?['votedBy'] ?? null,
            });
          }
        }

        // Only create poll if there are at least 2 options
        if (options.length >= 2) {
          pollData = {
            'question': _pollQuestionController.text,
            'options': options,
            'expiresAt': _pollExpiryDate.millisecondsSinceEpoch,
            'allowMultipleChoices': _allowMultipleChoices,
          };

          // Debug: Print poll data
          print('Creating poll with data:');
          print('Question: ${_pollQuestionController.text}');
          print('Options: ${options.map((o) => o['text']).toList()}');
          print('Expires at: $_pollExpiryDate');
          print('Allow multiple choices: $_allowMultipleChoices');
        } else {
          print('Not enough valid poll options. Need at least 2.');
        }
      } else if (_showPollCreator) {
        print('Poll creator is shown but question is empty');
      }

      if (widget.notice != null) {
        await _adminService.updateNotice(
          widget.notice!.id,
          _titleController.text,
          _contentController.text,
          null, // No longer using single imageUrl
          imageUrls: imageUrls.isNotEmpty ? imageUrls : null,
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
      width: 120,
      height: 120,
      child: Stack(
        children: [
          // Image container
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(image.path),
              height: 120,
              width: 120,
              fit: BoxFit.cover,
            ),
          ),
          // Close button overlay
          Positioned(
            right: 12,
            top: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
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
      ),
    );
  }

  // Helper method to build video preview
  Widget _buildVideoPreview(XFile video, VoidCallback onRemove) {
    return FutureBuilder<Uint8List?>(
      future: _getVideoThumbnail(video.path),
      builder: (context, snapshot) {
        return SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            children: [
              // Video thumbnail container
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Show a thumbnail of the video file if possible
                      if (snapshot.hasData && snapshot.data != null)
                        Image.memory(
                          snapshot.data!,
                          height: 120,
                          width: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              height: 120,
                              width: 120,
                            );
                          },
                        )
                      else
                        Container(
                          color: Colors.grey[300],
                          height: 120,
                          width: 120,
                          child: snapshot.connectionState ==
                                  ConnectionState.waiting
                              ? const Center(child: CircularProgressIndicator())
                              : null,
                        ),
                      // Play icon overlay
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.play_arrow,
                            color: Colors.white, size: 30),
                      ),
                    ],
                  ),
                ),
              ),
              // Close button overlay
              Positioned(
                right: 252,
                top: 4,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
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
          ),
        );
      },
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(iconData, color: iconColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
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
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        );
                      },
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 16),
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method to build poll option input
  Widget _buildPollOptionInput(TextEditingController controller, int index) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Option ${index + 1}',
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        if (_pollOptionControllers.length >
            2) // Allow removing if more than minimum options
          IconButton(
            onPressed: () {
              setState(() {
                controller.dispose();
                _pollOptionControllers.removeAt(index);
              });
            },
            icon: const Icon(Icons.remove_circle_outline),
            color: Colors.red[400],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
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
                        widget.notice != null ? 'Edit Notice' : 'Create Notice',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Title (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      hintText: 'What\'s happening in your community?',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),

                  // Images preview
                  if (_selectedImages.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Images',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
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
                    const SizedBox(height: 16),
                  ],

                  // Video preview
                  if (_selectedVideo != null) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Video',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: _buildVideoPreview(
                        _selectedVideo!,
                        () => setState(() => _selectedVideo = null),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Attachments preview
                  if (_selectedAttachments.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Attachments',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(
                      _selectedAttachments.length,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildAttachmentPreview(
                          _selectedAttachments[index],
                          () => setState(
                              () => _selectedAttachments.removeAt(index)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Poll creator
                  if (_showPollCreator) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Poll',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _pollQuestionController,
                      decoration: const InputDecoration(
                        hintText: 'Ask a question...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(
                      _pollOptionControllers.length,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildPollOptionInput(
                            _pollOptionControllers[index], index),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _pollOptionControllers
                                  .add(TextEditingController());
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Option'),
                        ),
                        Row(
                          children: [
                            const Text('Multiple choices'),
                            Switch(
                              value: _allowMultipleChoices,
                              onChanged: (value) {
                                setState(() {
                                  _allowMultipleChoices = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('Poll ends: '),
                            TextButton(
                              onPressed: () async {
                                final DateTime? pickedDate =
                                    await showDatePicker(
                                  context: context,
                                  initialDate: _pollExpiryDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                );
                                if (pickedDate != null) {
                                  // Keep current time when changing date
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
                              child: Text(
                                DateFormat('MMM d, y').format(_pollExpiryDate),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Text('Time: '),
                            TextButton(
                              onPressed: () async {
                                final TimeOfDay? pickedTime =
                                    await showTimePicker(
                                  context: context,
                                  initialTime:
                                      TimeOfDay.fromDateTime(_pollExpiryDate),
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
                              child: Text(
                                DateFormat('h:mm a').format(_pollExpiryDate),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showPollCreator = false;
                          _pollQuestionController.clear();
                          for (var controller in _pollOptionControllers) {
                            controller.clear();
                          }
                        });
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Remove Poll'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                  ],

                  // Media buttons
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _pickImages,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Photos'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading || _selectedVideo != null
                              ? null
                              : _pickVideo,
                          icon: const Icon(Icons.videocam),
                          label: const Text('Video'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _pickAttachments,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Attachment'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading || _showPollCreator
                              ? null
                              : () {
                                  setState(() {
                                    _showPollCreator = true;
                                  });
                                },
                          icon: const Icon(Icons.poll),
                          label: const Text('Poll'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed:
                        _isLoading || _isUploadingMedia ? null : _saveNotice,
                    child: _isLoading || _isUploadingMedia
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(widget.notice != null ? 'Save Changes' : 'Post'),
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
