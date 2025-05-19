import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../widgets/admin_scaffold.dart';

class AdminNotificationTestPage extends StatefulWidget {
  const AdminNotificationTestPage({super.key});

  @override
  State<AdminNotificationTestPage> createState() => _AdminNotificationTestPageState();
}

class _AdminNotificationTestPageState extends State<AdminNotificationTestPage> {
  final NotificationService _notificationService = NotificationService();
  String? _fcmToken;
  bool _isLoading = false;
  String _testResult = '';

  @override
  void initState() {
    super.initState();
    _loadFcmToken();
  }

  Future<void> _loadFcmToken() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _notificationService.getFcmToken();
      setState(() {
        _fcmToken = token;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _fcmToken = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testRegularNotification() async {
    setState(() {
      _isLoading = true;
      _testResult = 'Testing regular notification...';
    });

    try {
      await _notificationService.testLocalNotification();
      setState(() {
        _testResult = 'Regular notification test successful!';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResult = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testAdminNotification() async {
    setState(() {
      _isLoading = true;
      _testResult = 'Testing admin notification...';
    });

    try {
      await _notificationService.testAdminNotification();
      setState(() {
        _testResult = 'Admin notification test successful!';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResult = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Notification Test',
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notification Test Page',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This page allows you to test different types of notifications.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FCM Token',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : SelectableText(
                            _fcmToken ?? 'No token available',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadFcmToken,
                      child: const Text('Refresh Token'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _testRegularNotification,
                            child: const Text('Test Regular Notification'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _testAdminNotification,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Test Admin Notification'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_testResult.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _testResult.contains('Error')
                              ? Colors.red.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _testResult,
                          style: TextStyle(
                            color: _testResult.contains('Error')
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
