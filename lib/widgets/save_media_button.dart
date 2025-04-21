import 'package:flutter/material.dart';
import '../services/media_saver_service.dart';

/// A button widget that saves media (images or videos) to the gallery.
class SaveMediaButton extends StatelessWidget {
  /// The path to the media file to save.
  final String filePath;
  
  /// Whether the media is a video. If false, it's treated as an image.
  final bool isVideo;
  
  /// Optional album name to save the media to.
  final String? album;
  
  /// Optional icon to use for the button.
  final IconData icon;
  
  /// Optional text to display on the button.
  final String text;
  
  /// Optional color for the button.
  final Color? color;

  const SaveMediaButton({
    Key? key,
    required this.filePath,
    this.isVideo = false,
    this.album,
    this.icon = Icons.download,
    this.text = 'Save to Gallery',
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
      ),
      onPressed: () => _saveMedia(context),
    );
  }

  Future<void> _saveMedia(BuildContext context) async {
    final mediaSaverService = MediaSaverService();
    
    if (isVideo) {
      await mediaSaverService.saveVideoToGallery(
        filePath: filePath,
        context: context,
        album: album,
      );
    } else {
      await mediaSaverService.saveImageToGallery(
        filePath: filePath,
        context: context,
        album: album,
      );
    }
  }
}
