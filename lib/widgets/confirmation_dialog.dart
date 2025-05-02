import 'package:flutter/material.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final Color confirmColor;
  final IconData icon;
  final Color iconBackgroundColor;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.confirmColor = Colors.red,
    this.icon = Icons.warning_rounded,
    this.iconBackgroundColor = Colors.red,
  });

  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color confirmColor = Colors.red,
    IconData icon = Icons.warning_rounded,
    Color iconBackgroundColor = Colors.red,
  }) async {
    debugPrint('ConfirmationDialog: Showing dialog');

    // Use completer to ensure we always get a response
    bool dialogResult = false;

    try {
      // Use await to ensure we get a proper response
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false, // Prevent dismissing by tapping outside
        builder: (context) => PopScope(
          // Prevent dismissing by back button
          canPop: false,
          child: ConfirmationDialog(
            title: title,
            message: message,
            confirmText: confirmText,
            cancelText: cancelText,
            confirmColor: confirmColor,
            icon: icon,
            iconBackgroundColor: iconBackgroundColor,
          ),
        ),
      );

      // Set the result, defaulting to false if null
      dialogResult = result ?? false;
      debugPrint('ConfirmationDialog: Dialog closed with result: $dialogResult');
    } catch (e) {
      debugPrint('ConfirmationDialog: Error showing dialog: $e');
      dialogResult = false;
    }

    // Return explicit result
    return dialogResult;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: iconBackgroundColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconBackgroundColor,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            // Content
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 25),
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cancel button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      debugPrint('Confirmation dialog: Cancel button pressed');
                      // Explicitly return false and close the dialog
                      Navigator.of(context).pop(false);
                      debugPrint('Confirmation dialog: Dialog popped with false');
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.grey[800],
                      backgroundColor: Colors.grey[200],
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      cancelText,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                // Confirm button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      debugPrint('Confirmation dialog: Delete button pressed');
                      // Explicitly return true and close the dialog immediately
                      Navigator.of(context).pop(true);
                      debugPrint('Confirmation dialog: Dialog popped with true');
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: confirmColor,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      confirmText,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
