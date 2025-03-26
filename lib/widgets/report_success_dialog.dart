import 'package:flutter/material.dart';

class ReportSuccessDialog extends StatelessWidget {
  final VoidCallback onViewReports;

  const ReportSuccessDialog({
    Key? key,
    required this.onViewReports,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00C49A).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Color(0xFF00C49A),
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Report Submitted',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your report has been submitted successfully. We will review it shortly.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onViewReports();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C49A),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('View My Reports'),
            ),
          ),
        ],
      ),
    );
  }

  static void show(BuildContext context, VoidCallback onViewReports) {
    showDialog(
      context: context,
      builder: (context) => ReportSuccessDialog(onViewReports: onViewReports),
    );
  }
}
