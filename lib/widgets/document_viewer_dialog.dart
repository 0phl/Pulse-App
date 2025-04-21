import 'package:flutter/material.dart';
import '../services/file_downloader_service.dart';
import 'image_viewer_page.dart';
import 'file_download_progress.dart';

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

  Future<void> _openDocument(BuildContext context, String url) async {
    if (_isImageUrl(url)) {
      // For images, use the image viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerPage(imageUrl: url),
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
      // For PDFs, ensure we have the download parameter
      String fileUrl = url;
      if (_isPdfUrl(url) && !url.contains('dl=1')) {
        fileUrl = '$url${url.contains('?') ? '&' : '?'}dl=1';
      }

      final fileName = _getFileNameFromUrl(url);

      await _fileDownloader.downloadAndOpenFile(
        url: fileUrl,
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
                        final fileName = _getFileNameFromUrl(url);
                        final isDownloading = _downloadingUrl == url;

                        return ListTile(
                          leading: Icon(
                            isImage ? Icons.image : (isPdf ? Icons.picture_as_pdf : Icons.file_present),
                            color: isDownloading ? const Color(0xFF00C49A) : Theme.of(context).primaryColor,
                          ),
                          title: Text(fileName),
                          subtitle: Text(
                            isImage ? 'Image File' : (isPdf ? 'PDF File' : 'Document File'),
                          ),
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
