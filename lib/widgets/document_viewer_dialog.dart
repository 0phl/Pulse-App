import 'package:flutter/material.dart';
import '../services/file_downloader_service.dart';
import 'image_viewer_page.dart';
import 'file_download_progress.dart';
import 'pdf_viewer_page.dart';
import 'video_player_page.dart';

class DocumentViewerDialog extends StatefulWidget {
  final List<String> documents;

  const DocumentViewerDialog({
    super.key,
    required this.documents,
  });

  @override
  State<DocumentViewerDialog> createState() => _DocumentViewerDialogState();
}

class _DocumentViewerDialogState extends State<DocumentViewerDialog> {
  final _fileDownloader = FileDownloaderService();
  String? _downloadingUrl;
  double _downloadProgress = 0.0;

  bool _isImageUrl(String url) {
    final lowercaseUrl = url.toLowerCase();
    // Check for common image extensions
    if (lowercaseUrl.endsWith('.jpg') ||
        lowercaseUrl.endsWith('.jpeg') ||
        lowercaseUrl.endsWith('.png') ||
        lowercaseUrl.endsWith('.gif') ||
        lowercaseUrl.endsWith('.webp')) {
      return true;
    }
    // Check Cloudinary URL format
    return lowercaseUrl.contains('/image/upload/');
  }

  bool _isPdfUrl(String url) {
    final lowercaseUrl = url.toLowerCase();
    return lowercaseUrl.contains('.pdf') ||
           lowercaseUrl.contains('/admin_docs/pdfs/');
  }

  String _getFileNameFromUrl(String url) {
    // Try to extract filename from URL
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    if (pathSegments.isNotEmpty) {
      final lastSegment = pathSegments.last;
      if (lastSegment.isNotEmpty) {
        return lastSegment;
      }
    }

    // If we can't extract a filename, generate one based on file type
    if (_isPdfUrl(url)) {
      return 'document_${DateTime.now().millisecondsSinceEpoch}.pdf';
    } else if (_isImageUrl(url)) {
      return 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    } else {
      return 'file_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  bool _isVideoUrl(String url) {
    final lowercaseUrl = url.toLowerCase();
    return lowercaseUrl.endsWith('.mp4') ||
           lowercaseUrl.endsWith('.mov') ||
           lowercaseUrl.endsWith('.avi') ||
           lowercaseUrl.endsWith('.mkv') ||
           lowercaseUrl.endsWith('.webm') ||
           lowercaseUrl.contains('/video/upload/');
  }

  Future<void> _openDocument(BuildContext context, String url) async {
    final fileName = _getFileNameFromUrl(url);

    if (_isImageUrl(url)) {
      // For images, use the image viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerPage(imageUrl: url),
        ),
      );
      return;
    } else if (_isPdfUrl(url)) {
      // For PDFs, ensure we have the download parameter
      String fileUrl = url;
      if (!url.contains('dl=1')) {
        fileUrl = '$url${url.contains('?') ? '&' : '?'}dl=1';
      }

      // Open PDF in the PDF viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerPage(
            pdfUrl: fileUrl,
            fileName: fileName,
          ),
        ),
      );
      return;
    } else if (_isVideoUrl(url)) {
      // Open video in the video player
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerPage(
            videoUrl: url,
          ),
        ),
      );
      return;
    }

    // For other files, download and open
    if (_downloadingUrl == url) return; // Already downloading this file

    setState(() {
      _downloadingUrl = url;
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

      if (shouldDownload != true || !mounted) {
        setState(() {
          _downloadingUrl = null;
        });
        return;
      }

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
          _downloadingUrl = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Documents',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.documents.isEmpty)
              const Center(
                child: Text('No documents available'),
              )
            else
              Flexible(
                child: Stack(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.documents.length,
                      itemBuilder: (context, index) {
                        final url = widget.documents[index];
                        final isImage = _isImageUrl(url);
                        final isPdf = _isPdfUrl(url);
                        final isVideo = _isVideoUrl(url);
                        final fileName = _getFileNameFromUrl(url);
                        final isDownloading = _downloadingUrl == url;

                        // Determine file type icon and text
                        IconData fileIcon;
                        String fileTypeText;

                        if (isImage) {
                          fileIcon = Icons.image;
                          fileTypeText = 'Image File';
                        } else if (isPdf) {
                          fileIcon = Icons.picture_as_pdf;
                          fileTypeText = 'PDF File';
                        } else if (isVideo) {
                          fileIcon = Icons.videocam;
                          fileTypeText = 'Video File';
                        } else {
                          fileIcon = Icons.file_present;
                          fileTypeText = 'Document File';
                        }

                        return ListTile(
                          leading: Icon(
                            fileIcon,
                            color: isDownloading ? const Color(0xFF00C49A) : Theme.of(context).primaryColor,
                          ),
                          title: Text(fileName),
                          subtitle: Text(fileTypeText),
                          onTap: () => _openDocument(context, url),
                          trailing: isDownloading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.download),
                        );
                      },
                    ),
                    if (_downloadingUrl != null)
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: FileDownloadProgress(
                          progress: _downloadProgress,
                          fileName: _getFileNameFromUrl(_downloadingUrl!),
                          onCancel: () {
                            setState(() {
                              _downloadingUrl = null;
                            });
                          },
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
