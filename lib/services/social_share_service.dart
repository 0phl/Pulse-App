import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import '../models/community_notice.dart';
import '../widgets/share_card_widget.dart';

/// Social media-style sharing service
/// Generates beautiful shareable images from community notices
class SocialShareService {
  final ScreenshotController _screenshotController = ScreenshotController();

  /// Share notice as a beautifully designed image (like Instagram/Facebook posts)
  Future<void> shareAsImage(
    CommunityNotice notice,
    BuildContext context,
  ) async {
    try {
      // Show loading dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF00C49A)),
                    SizedBox(height: 16),
                    Text('Creating shareable image...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // Capture the share card widget as image
      final Uint8List? imageBytes = await _screenshotController.captureFromWidget(
        ShareCardWidget(notice: notice),
        context: context,
        pixelRatio: 3.0, // Higher quality
      );

      if (imageBytes == null) {
        throw Exception('Failed to generate share image');
      }

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final fileName = 'pulse_share_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Share the image with text
      final shareText = _generateShareText(notice);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: shareText,
        subject: 'Community Notice from PULSE',
      );

      // Clean up
      try {
        await file.delete();
      } catch (e) {
        debugPrint('Error deleting temp file: $e');
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Shared successfully!'),
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
    } catch (e) {
      debugPrint('Error sharing as image: $e');
      
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to share: $e')),
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
  }

  /// Generate companion text for the share
  String _generateShareText(CommunityNotice notice) {
    final buffer = StringBuffer();
    
    buffer.writeln('📢 ${notice.title}');
    buffer.writeln();
    buffer.writeln('Check out this community notice from PULSE!');
    
    // Add a call-to-action
    if (notice.poll != null) {
      buffer.writeln();
      buffer.writeln('🗳️ Vote on the poll in the PULSE app!');
    }
    
    buffer.writeln();
    buffer.writeln('#PULSEApp #CommunityNotice');
    
    return buffer.toString();
  }

  /// Share with a preview dialog first
  Future<void> shareWithPreview(
    CommunityNotice notice,
    BuildContext context,
  ) async {
    // Show preview dialog
    final shouldShare = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF00C49A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.share, color: Colors.white),
                    SizedBox(width: 12),
                    Text(
                      'Share Preview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Preview
              Container(
                constraints: const BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ShareCardWidget(notice: notice),
                ),
              ),
              
              // Info text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'This is how your share will look',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              // Actions
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C49A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.share, size: 20),
                            SizedBox(width: 8),
                            Text('Share'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (shouldShare == true && context.mounted) {
      await shareAsImage(notice, context);
    }
  }
}