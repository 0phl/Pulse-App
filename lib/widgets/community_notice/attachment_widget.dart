import 'package:flutter/material.dart';
import '../../models/community_notice.dart';
import '../../services/file_downloader_service.dart';
import '../file_download_progress.dart';
import '../image_viewer_page.dart';
import '../pdf_viewer_page.dart';
import '../video_player_page.dart';
import '../docx_viewer_page.dart';

class AttachmentWidget extends StatefulWidget {
  final FileAttachment attachment;

  const AttachmentWidget({super.key, required this.attachment});

  @override
  State<AttachmentWidget> createState() => _AttachmentWidgetState();
}

class _AttachmentWidgetState extends State<AttachmentWidget> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  final _fileDownloader = FileDownloaderService();

  IconData _getIconForFileType(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getColorForFileType(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Colors.purple;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Colors.red[700]!;
      default:
        return Colors.grey;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  Future<void> _downloadAndOpenFile() async {
    // Check file type to determine how to handle it
    final fileType = widget.attachment.type.toLowerCase();
    final url = widget.attachment.url;
    final fileName = widget.attachment.name;

    // Handle different file types
    if (fileType == 'pdf' || url.toLowerCase().contains('.pdf')) {
      // Open PDF in the PDF viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerPage(
            pdfUrl: url,
            fileName: fileName,
          ),
        ),
      );
    } else if (fileType == 'doc' || fileType == 'docx' || url.toLowerCase().contains('.doc') || url.toLowerCase().contains('.docx')) {
      // Open DOCX in the DOCX viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocxViewerPage(
            docxUrl: url,
            fileName: fileName,
          ),
        ),
      );
    } else if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(fileType)) {
      // Open image in the image viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerPage(
            imageUrl: url,
          ),
        ),
      );
    } else if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(fileType)) {
      // Open video in the video player
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerPage(
            videoUrl: url,
          ),
        ),
      );
    } else {
      // For other file types, download and open using the system
      if (_isDownloading) return;

      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      try {
        // Show download options dialog
        final bool? shouldDownload = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Download File'),
            content: Text('Do you want to download "$fileName"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Download'),
              ),
            ],
          ),
        );

        if (shouldDownload != true || !mounted) return;

        // Download and save to PULSE album
        await _fileDownloader.downloadAndSaveToPulseAlbum(
          url: url,
          fileName: fileName,
          context: context,
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _downloadProgress = progress;
              });
            }
          },
        );
      } finally {
        if (mounted) {
          setState(() {
            _isDownloading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey[300]!),
          ),
          child: InkWell(
            onTap: _downloadAndOpenFile,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    _getIconForFileType(widget.attachment.type),
                    color: _getColorForFileType(widget.attachment.type),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.attachment.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatFileSize(widget.attachment.size),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isDownloading ? Icons.downloading : Icons.download,
                    color: _isDownloading ? const Color(0xFF00C49A) : Colors.grey[600],
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isDownloading)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                      maxHeight: 100, // Limit the height to prevent overflow
                    ),
                    child: FileDownloadProgress(
                      progress: _downloadProgress,
                      fileName: widget.attachment.name,
                      onCancel: () {
                        setState(() {
                          _isDownloading = false;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
