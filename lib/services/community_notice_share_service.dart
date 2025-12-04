import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/community_notice.dart';

/// Service for sharing community notices via native share functionality
/// Supports text-only sharing and sharing with images
class CommunityNoticeShareService {
  /// Maximum length for content in share message
  static const int _maxContentLength = 280;

  /// Share a community notice with text only
  /// 
  /// Opens the native share dialog with formatted notice content
  Future<void> shareNotice(
    CommunityNotice notice,
    BuildContext context,
  ) async {
    try {
      final shareText = _formatShareText(notice);
      
      await Share.share(
        shareText,
        subject: '${notice.title} - PULSE Community Notice',
      );

      if (context.mounted) {
        _showSuccessSnackBar(context);
      }
    } catch (e) {
      debugPrint('Error sharing notice: $e');
      if (context.mounted) {
        _showErrorSnackBar(context, 'Failed to share notice');
      }
    }
  }

  /// Share a community notice with the first image
  /// 
  /// Downloads the image temporarily and shares it along with the text
  Future<void> shareNoticeWithImage(
    CommunityNotice notice,
    BuildContext context,
  ) async {
    try {
      // Check if notice has images
      if (notice.imageUrls == null || notice.imageUrls!.isEmpty) {
        // Fallback to text-only sharing
        await shareNotice(notice, context);
        return;
      }

      final shareText = _formatShareText(notice);
      final imageUrl = notice.imageUrls!.first;

      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 16),
                Text('Preparing to share...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Download image to temporary directory
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download image');
      }

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final fileName = 'pulse_notice_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      // Share with image
      await Share.shareXFiles(
        [XFile(file.path)],
        text: shareText,
        subject: '${notice.title} - PULSE Community Notice',
      );

      // Clean up temporary file
      try {
        await file.delete();
      } catch (e) {
        debugPrint('Error deleting temporary file: $e');
      }

      if (context.mounted) {
        _showSuccessSnackBar(context);
      }
    } catch (e) {
      debugPrint('Error sharing notice with image: $e');
      if (context.mounted) {
        _showErrorSnackBar(
          context,
          'Failed to share with image. Try sharing without image.',
        );
      }
    }
  }

  /// Show options dialog to choose share method
  /// 
  /// Allows user to choose between text-only or with image
  Future<void> showShareOptions(
    CommunityNotice notice,
    BuildContext context,
  ) async {
    final hasImages = notice.imageUrls != null && notice.imageUrls!.isNotEmpty;

    if (!hasImages) {
      // No images, share text only
      await shareNotice(notice, context);
      return;
    }

    if (!context.mounted) return;

    // Show dialog with options
    final choice = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.share, color: Color(0xFF00C49A)),
              SizedBox(width: 12),
              Text('Share Notice'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'How would you like to share this notice?',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.text_fields, color: Color(0xFF00C49A)),
                title: const Text('Share Text Only'),
                subtitle: const Text('Share notice content'),
                onTap: () => Navigator.pop(dialogContext, 'text'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.image, color: Color(0xFF00C49A)),
                title: const Text('Share with Image'),
                subtitle: const Text('Include first image'),
                onTap: () => Navigator.pop(dialogContext, 'image'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );

    if (choice == null || !context.mounted) return;

    if (choice == 'text') {
      await shareNotice(notice, context);
    } else if (choice == 'image') {
      await shareNoticeWithImage(notice, context);
    }
  }

  /// Format notice content for sharing
  /// 
  /// Creates a well-formatted text representation of the notice
  String _formatShareText(CommunityNotice notice) {
    final buffer = StringBuffer();

    // Header with emoji
    buffer.writeln('🔔 Community Notice from PULSE');
    buffer.writeln();

    // Title
    buffer.writeln('📌 ${notice.title}');
    buffer.writeln();

    // Author
    buffer.writeln('By: ${notice.authorName}');
    buffer.writeln();

    // Content (truncated if too long)
    final content = _truncateContent(notice.content, _maxContentLength);
    buffer.writeln(content);
    
    if (notice.content.length > _maxContentLength) {
      buffer.writeln('... [Read more in PULSE app]');
    }
    buffer.writeln();

    // Poll information if present
    if (notice.poll != null) {
      buffer.writeln('📊 Poll: ${notice.poll!.question}');
      
      // Add poll options (max 5 to keep it concise)
      final optionsToShow = notice.poll!.options.take(5).toList();
      for (var i = 0; i < optionsToShow.length; i++) {
        buffer.writeln('  ${i + 1}. ${optionsToShow[i].text}');
      }
      
      if (notice.poll!.options.length > 5) {
        buffer.writeln('  ... and ${notice.poll!.options.length - 5} more options');
      }
      
      buffer.writeln();
    }

    // Attachments info if present
    if (notice.attachments != null && notice.attachments!.isNotEmpty) {
      buffer.writeln('📎 ${notice.attachments!.length} attachment(s) included');
      buffer.writeln();
    }

    // Footer
    buffer.writeln('---');
    buffer.writeln('Shared from PULSE - Community Engagement App');

    return buffer.toString();
  }

  /// Truncate content to specified length with ellipsis
  String _truncateContent(String content, int maxLength) {
    if (content.length <= maxLength) {
      return content;
    }

    // Find the last space before maxLength to avoid cutting words
    final truncateAt = content.lastIndexOf(' ', maxLength);
    if (truncateAt == -1) {
      return '${content.substring(0, maxLength)}...';
    }

    return '${content.substring(0, truncateAt)}...';
  }

  /// Show success snackbar
  void _showSuccessSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Notice shared successfully!'),
          ],
        ),
        backgroundColor: const Color(0xFF00C49A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show error snackbar
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}