import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../services/media_saver_service.dart';

class PdfViewerPage extends StatefulWidget {
  final String pdfUrl;
  final String fileName;

  const PdfViewerPage({
    super.key,
    required this.pdfUrl,
    required this.fileName,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _localPdfPath;
  String? _errorMessage;
  final int _totalPages = 0;
  final int _currentPage = 0;
  final MediaSaverService _mediaSaverService = MediaSaverService();

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // For web, we don't need to download - just set loading to false
      setState(() {
        _isLoading = false;
      });
    } else {
      // For mobile, download the PDF
      _downloadAndSavePdf();
    }
  }

  Future<void> _downloadAndSavePdf() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final http.Response response = await http.get(Uri.parse(widget.pdfUrl));

      if (response.statusCode == 200) {
        try {
          // Only try to access file system on non-web platforms
          if (!kIsWeb) {
            final Directory tempDir = await getTemporaryDirectory();
            final String filePath = '${tempDir.path}/${widget.fileName}';

            final File file = File(filePath);
            await file.writeAsBytes(response.bodyBytes);

            setState(() {
              _localPdfPath = filePath;
              _isLoading = false;
            });
          } else {
            // For web, we don't need to save the file locally
            setState(() {
              _isLoading = false;
            });
          }
        } catch (e) {
          setState(() {
            _hasError = true;
            _isLoading = false;
            _errorMessage = 'Error saving PDF: $e';
          });
        }
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _errorMessage = 'Failed to download PDF: HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMessage = 'Error downloading PDF: $e';
      });
    }
  }

  Future<void> _openInBrowser() async {
    try {
      final Uri url = Uri.parse(widget.pdfUrl);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open the PDF in a browser'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        backgroundColor: const Color(0xFF00C49A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Open in browser',
            onPressed: _openInBrowser,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C49A)),
            ),
            SizedBox(height: 16),
            Text('Loading PDF...'),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Failed to load PDF',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                _errorMessage ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              onPressed: kIsWeb ? null : _downloadAndSavePdf,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C49A),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Open in Browser'),
              onPressed: _openInBrowser,
            ),
          ],
        ),
      );
    }

    // For web, use a display option that doesn't depend on local file system
    if (kIsWeb) {
      return Center(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.grey[300],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.picture_as_pdf,
                  color: Color(0xFFE53935), size: 64),
              const SizedBox(height: 24),
              const Text(
                'PDF cannot be displayed directly in this view',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please use one of the options below:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Open in Browser'),
                    onPressed: _openInBrowser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C49A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Download PDF'),
                    onPressed: () {
                      launchUrl(Uri.parse(widget.pdfUrl));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // For mobile, use the PDFView if we have a local path
    if (_localPdfPath != null) {
      return Stack(
        children: [
          PDFView(
            filePath: _localPdfPath!,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: true,
            pageSnap: true,
            fitPolicy: FitPolicy.BOTH,
            preventLinkNavigation: false,
            onError: (error) {
              setState(() {
                _hasError = true;
                _errorMessage = error.toString();
              });
            },
            onPageError: (page, error) {
              print('Error on page $page: $error');
            },
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: const Color(0xFF00C49A),
              foregroundColor: Colors.white,
              onPressed: _openInBrowser,
              child: const Icon(Icons.download),
            ),
          ),
        ],
      );
    } else {
      // Fallback if we somehow don't have a local path
      return Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.open_in_browser),
          label: const Text('Open PDF in Browser'),
          onPressed: _openInBrowser,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C49A),
            foregroundColor: Colors.white,
          ),
        ),
      );
    }
  }
}
