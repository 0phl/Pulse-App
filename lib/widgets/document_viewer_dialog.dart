import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'image_viewer_page.dart';

class DocumentViewerDialog extends StatelessWidget {
  final List<String> documents;
  
  const DocumentViewerDialog({
    super.key,
    required this.documents,
  });

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

  Future<void> _openDocument(BuildContext context, String url) async {
    try {
      if (_isPdfUrl(url)) {
        // For PDFs, ensure we have the download parameter
        final pdfUrl = url.contains('dl=1') ? url : '$url${url.contains('?') ? '&' : '?'}dl=1';
        final Uri uri = Uri.parse(pdfUrl);
        // Try to open in platform default viewer first
        if (!await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        )) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not open PDF file. Please ensure you have a PDF viewer installed.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      } else if (_isImageUrl(url)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageViewerPage(imageUrl: url),
          ),
        );
      } else {
        throw Exception('Unsupported file type');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isPdfUrl(url) 
              ? 'Could not open PDF file. Please ensure you have a PDF viewer installed.'
              : 'Could not open document: ${e.toString()}'
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
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
            if (documents.isEmpty)
              const Center(
                child: Text('No documents available'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final url = documents[index];
                    final isImage = _isImageUrl(url);
                    final isPdf = _isPdfUrl(url);
                    
                    return ListTile(
                      leading: Icon(
                        isImage ? Icons.image : (isPdf ? Icons.picture_as_pdf : Icons.file_present),
                        color: Theme.of(context).primaryColor,
                      ),
                      title: Text('Document ${index + 1}'),
                      subtitle: Text(
                        isImage ? 'Image File' : (isPdf ? 'PDF File' : 'Document File'),
                      ),
                      onTap: () => _openDocument(context, url),
                      trailing: const Icon(Icons.open_in_new),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
