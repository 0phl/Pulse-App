import 'package:flutter/material.dart';

class FileDownloadProgress extends StatelessWidget {
  final double progress;
  final String fileName;
  final VoidCallback onCancel;

  const FileDownloadProgress({
    super.key,
    required this.progress,
    required this.fileName,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min, // Ensure row takes minimum space
            children: [
              const Icon(Icons.file_download, color: Color(0xFF00C49A), size: 18), // Smaller icon
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Downloading $fileName',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14, // Smaller font
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector( // Replaced IconButton with GestureDetector to save space
                onTap: onCancel,
                child: const Icon(Icons.close, size: 18, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8), // Reduced spacing
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
            borderRadius: BorderRadius.circular(10),
            minHeight: 6, // Thinner progress bar
          ),
          const SizedBox(height: 4), // Reduced spacing
          Text(
            '${(progress * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
