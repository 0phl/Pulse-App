import 'package:flutter/material.dart';
import '../services/file_downloader_service.dart';
import 'image_viewer_page.dart';
import 'pdf_viewer_page.dart';
import 'video_player_page.dart';
import 'docx_viewer_page.dart';

class DocumentViewerDialog extends StatefulWidget {
  final List<String> documents;
  final String? title;

  const DocumentViewerDialog({
    super.key,
    required this.documents,
    this.title,
  });

  @override
  State<DocumentViewerDialog> createState() => _DocumentViewerDialogState();
}

class _DocumentViewerDialogState extends State<DocumentViewerDialog>
    with SingleTickerProviderStateMixin {
  final _fileDownloader = FileDownloaderService();
  String? _downloadingUrl;
  double _downloadProgress = 0.0;
  String? _selectedDocument;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: widget.documents.length, vsync: this);

    if (widget.documents.length == 1 && _isPdfUrl(widget.documents.first)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPdfDirectly(widget.documents.first);
      });
    }
  }

  void _openPdfDirectly(String url) {
    final fileName = _getFileNameFromUrl(url);
    String fileUrl = url;
    // Ensure we're using the download link if needed
    if (!url.contains('dl=1')) {
      fileUrl = '$url${url.contains('?') ? '&' : '?'}dl=1';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerPage(
          pdfUrl: fileUrl,
          fileName: fileName,
        ),
      ),
    ).then((_) {
      // Close the dialog when returning from PDF viewer
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isImageUrl(String url) {
    final lowercaseUrl = url.toLowerCase();
    if (lowercaseUrl.endsWith('.jpg') ||
        lowercaseUrl.endsWith('.jpeg') ||
        lowercaseUrl.endsWith('.png') ||
        lowercaseUrl.endsWith('.gif') ||
        lowercaseUrl.endsWith('.webp')) {
      return true;
    }
    return lowercaseUrl.contains('/image/upload/');
  }

  bool _isPdfUrl(String url) {
    final lowercaseUrl = url.toLowerCase();
    return lowercaseUrl.contains('.pdf') ||
        lowercaseUrl.contains('/admin_docs/pdfs/');
  }

  bool _isDocxUrl(String url) {
    final lowercaseUrl = url.toLowerCase();
    return lowercaseUrl.endsWith('.docx') ||
        lowercaseUrl.endsWith('.doc') ||
        lowercaseUrl.contains('/admin_docs/docx/');
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
    } else if (_isDocxUrl(url)) {
      return 'document_${DateTime.now().millisecondsSinceEpoch}.docx';
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

  Widget _buildDocumentViewer(String url) {
    final isImage = _isImageUrl(url);
    final isPdf = _isPdfUrl(url);
    final isDocx = _isDocxUrl(url);
    final isVideo = _isVideoUrl(url);
    final fileName = _getFileNameFromUrl(url);

    if (isPdf) {
      // For PDFs, show a button to open the viewer
      return _buildDocumentPreview(
        icon: Icons.picture_as_pdf,
        title: fileName,
        subtitle: 'PDF Document',
        buttonText: 'Open PDF',
        onButtonPressed: () => _openPdfDirectly(url),
        color: const Color(0xFFE53935), // Red
      );
    } else if (isDocx) {
      return _buildDocumentPreview(
        icon: Icons.description,
        title: fileName,
        subtitle: 'Word Document',
        buttonText: 'Open Document',
        onButtonPressed: () {
          String fileUrl = url;
          if (!url.contains('dl=1')) {
            fileUrl = '$url${url.contains('?') ? '&' : '?'}dl=1';
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DocxViewerPage(
                docxUrl: fileUrl,
                fileName: fileName,
              ),
            ),
          );
        },
        color: const Color(0xFF1565C0), // Blue
      );
    } else if (isVideo) {
      return _buildDocumentPreview(
        icon: Icons.videocam,
        title: fileName,
        subtitle: 'Video File',
        buttonText: 'Play Video',
        onButtonPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPlayerPage(
                videoUrl: url,
              ),
            ),
          );
        },
        color: const Color(0xFF4CAF50), // Green
      );
    } else if (isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildDocumentPreview(
              icon: Icons.image,
              title: fileName,
              subtitle: 'Image failed to load',
              buttonText: 'Open in Viewer',
              onButtonPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImageViewerPage(imageUrl: url),
                  ),
                );
              },
              color: const Color(0xFFFFA000), // Amber
            );
          },
        ),
      );
    } else {
      return _buildDownloadOption(url);
    }
  }

  Widget _buildDocumentPreview({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback? onButtonPressed,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            child: FilledButton.icon(
              icon: Icon(
                _getButtonIcon(icon),
                size: 20,
              ),
              label: Text(buttonText),
              style: FilledButton.styleFrom(
                backgroundColor: onButtonPressed == null ? Colors.grey : color,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onButtonPressed,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getButtonIcon(IconData fileIcon) {
    if (fileIcon == Icons.picture_as_pdf) {
      return Icons.visibility;
    } else if (fileIcon == Icons.description) {
      return Icons.visibility;
    } else if (fileIcon == Icons.videocam) {
      return Icons.play_arrow;
    } else if (fileIcon == Icons.image) {
      return Icons.open_in_new;
    } else {
      return Icons.download;
    }
  }

  Widget _buildDownloadOption(String url) {
    final fileName = _getFileNameFromUrl(url);
    final isDownloading = _downloadingUrl == url;

    return _buildDocumentPreview(
      icon: Icons.insert_drive_file,
      title: fileName,
      subtitle: 'Unknown file type',
      buttonText: isDownloading ? 'Downloading...' : 'Download File',
      onButtonPressed: isDownloading ? null : () => _downloadFile(url),
      color: const Color(0xFF607D8B), // Blue Grey
    );
  }

  Future<void> _downloadFile(String url) async {
    if (_downloadingUrl == url) return;

    setState(() {
      _downloadingUrl = url;
      _downloadProgress = 0.0;
    });

    try {
      final fileName = _getFileNameFromUrl(url);

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$fileName downloaded successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download file: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title ?? 'Documents',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),

            // Document selector tabs
            if (widget.documents.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.documents.length,
                    itemBuilder: (context, index) {
                      final url = widget.documents[index];
                      final isSelected = _tabController.index == index;

                      // Determine icon
                      IconData fileIcon;
                      if (_isImageUrl(url)) {
                        fileIcon = Icons.image;
                      } else if (_isPdfUrl(url)) {
                        fileIcon = Icons.picture_as_pdf;
                      } else if (_isDocxUrl(url)) {
                        fileIcon = Icons.description;
                      } else if (_isVideoUrl(url)) {
                        fileIcon = Icons.videocam;
                      } else {
                        fileIcon = Icons.file_present;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _tabController.animateTo(index);
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF00C49A).withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF00C49A)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  fileIcon,
                                  size: 16,
                                  color: isSelected
                                      ? const Color(0xFF00C49A)
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Document ${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? const Color(0xFF00C49A)
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // Document content
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: widget.documents.isEmpty
                    ? const Center(
                        child: Text('No documents available'),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: widget.documents
                            .map((url) => _buildDocumentViewer(url))
                            .toList(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
