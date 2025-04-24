import 'package:flutter/material.dart';
import '../../widgets/create_notice_sheet.dart';
import '../../widgets/admin_scaffold.dart';

class ShowCreateNoticeSheet extends StatefulWidget {
  const ShowCreateNoticeSheet({super.key});

  @override
  State<ShowCreateNoticeSheet> createState() => _ShowCreateNoticeSheetState();
}

class _ShowCreateNoticeSheetState extends State<ShowCreateNoticeSheet> {
  @override
  void initState() {
    super.initState();
    // Show the modal sheet after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showCreateNoticeSheet();
    });
  }

  Future<void> _showCreateNoticeSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateNoticeSheet(),
    ).then((_) {
      // When the sheet is closed, navigate back to the notices page
      Navigator.pushReplacementNamed(context, '/admin/notices');
    });
  }

  @override
  Widget build(BuildContext context) {
    // This is just a placeholder while the modal is being shown
    return AdminScaffold(
      title: 'Create Notice',
      appBar: AppBar(
        title: const Text('Create Notice'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/admin/notices');
          },
        ),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
