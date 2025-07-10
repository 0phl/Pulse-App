import 'dart:io';
import 'package:flutter/material.dart';
import 'package:docx_viewer/docx_viewer.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../services/media_saver_service.dart';

class DocxViewerPage extends StatefulWidget {
  final String docxUrl;
  final String fileName;

  const DocxViewerPage({
    Key? key,
    required this.docxUrl,
    required this.fileName,
  }) : super(key: key);

  @override
  State<DocxViewerPage> createState() => _DocxViewerPageState();
}

class _DocxViewerPageState extends State<DocxViewerPage> {
  final MediaSaverService _mediaSaverService = MediaSaverService();
  bool _isLoading = true;
  bool _hasError = false;
  String? _localDocxPath;
  bool _isOpeningWithExternalApp = false;

  @override
  void initState() {
    super.initState();
    _downloadDocx();
  }

  Future<void> _downloadDocx() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'PULSE_temp_$timestamp.docx';
      final filePath = '${tempDir.path}/$fileName';

      // Ensure we have the download parameter for DOCXs
      String url = widget.docxUrl;
      if (!url.contains('dl=1')) {
        url = '$url${url.contains('?') ? '&' : '?'}dl=1';
      }

      // Download the DOCX
      await Dio().download(
        url,
        filePath,
        options: Options(
          headers: {
            HttpHeaders.acceptEncodingHeader: '*',
          },
        ),
      );

      if (mounted) {
        setState(() {
          _localDocxPath = filePath;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading DOCX: $e')),
        );
      }
    }
  }

  Future<void> _saveDocxToPulseAlbum() async {
    if (_localDocxPath == null) return;

    await _mediaSaverService.saveDocumentToDownloads(
      filePath: _localDocxPath!,
      context: context,
      album: 'PULSE',
    );
  }

  Future<void> _openWithExternalApp() async {
    if (_localDocxPath == null) return;

    setState(() {
      _isOpeningWithExternalApp = true;
    });

    try {
      final result = await OpenFilex.open(_localDocxPath!);
      
      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error opening file: ${result.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningWithExternalApp = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fileName,
          style: const TextStyle(fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!_isLoading && !_hasError && _localDocxPath != null) ...[
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _saveDocxToPulseAlbum,
              tooltip: 'Save to PULSE Album',
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: _isOpeningWithExternalApp ? null : _openWithExternalApp,
              tooltip: 'Open with external app',
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading document...'),
          ],
        ),
      );
    } else if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Failed to load document'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _downloadDocx,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (_localDocxPath != null) {
      return DocxView(
        filePath: _localDocxPath!,
        fontSize: 16,
        onError: (error) {
          setState(() {
            _hasError = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error rendering DOCX: $error')),
          );
        },
      );
    } else {
      return const Center(
        child: Text('No document available'),
      );
    }
  }
}
