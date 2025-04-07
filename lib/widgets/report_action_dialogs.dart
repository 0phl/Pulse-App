import 'package:flutter/material.dart';

class ReportActionDialogs {
  static Future<String?> showAssignDialog(BuildContext context) {
    final TextEditingController assigneeController = TextEditingController();

    return showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: assigneeController,
              decoration: const InputDecoration(
                labelText: 'Assignee Name/Department',
                hintText: 'e.g., Maintenance Team',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (assigneeController.text.isNotEmpty) {
                Navigator.pop(context, assigneeController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C49A),
            ),
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  static Future<String?> showResolveDialog(BuildContext context) {
    final TextEditingController resolutionController = TextEditingController();

    return showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: resolutionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'How Was This Resolved',
                hintText: 'Describe what was done to fix this issue',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (resolutionController.text.isNotEmpty) {
                Navigator.pop(context, resolutionController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
  }

  static Future<String?> showRejectDialog(BuildContext context) {
    final TextEditingController reasonController = TextEditingController();

    return showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                hintText: 'Explain why this report is being rejected',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.isNotEmpty) {
                Navigator.pop(context, reasonController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  static Future<String?> showAddNoteDialog(BuildContext context) {
    final TextEditingController noteController = TextEditingController();

    return showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Add additional information or updates',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (noteController.text.isNotEmpty) {
                Navigator.pop(context, noteController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C49A),
            ),
            child: const Text('Add Note'),
          ),
        ],
      ),
    );
  }
}
