import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/notification_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final NotificationService _notificationService = NotificationService();

  bool _isLoading = true;
  Map<String, bool> _preferences = {};

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final preferences = await _notificationService.getNotificationPreferences();

      setState(() {
        _preferences = preferences;
        _isLoading = false;
      });

      // Ensure preferences are saved to Firestore when the page is loaded
      // This ensures that default preferences are saved even if the user doesn't click "Save Preferences"
      await _notificationService.updateNotificationPreferences(_preferences);
      debugPrint('Notification preferences automatically saved on page load');
    } catch (e) {
      debugPrint('Error loading notification preferences: $e');

      setState(() {
        _preferences = {
          'communityNotices': true,
          'socialInteractions': true,
          'marketplace': true,
          'chat': true,
          'reports': true,
          'volunteer': true,
        };
        _isLoading = false;
      });

      // Try to save default preferences even if there was an error loading
      try {
        await _notificationService.updateNotificationPreferences(_preferences);
        debugPrint('Default notification preferences saved after load error');
      } catch (saveError) {
        debugPrint('Error saving default notification preferences: $saveError');
      }
    }
  }

  Future<void> _savePreferences() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _notificationService.updateNotificationPreferences(_preferences);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification preferences saved'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving notification preferences: $e');

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Test notification
  Future<void> _testNotification() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _notificationService.testLocalNotification();

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification sent'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending test notification: $e');

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending test notification: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showFcmToken() async {
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('Requesting FCM token from notification service...');
      final token = await _notificationService.getFcmToken();
      debugPrint('Token received: $token');

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('FCM Token'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Use this token to send test notifications from Firebase Console:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    token != null && token.isNotEmpty && !token.startsWith('Error:')
                        ? token
                        : 'No token available',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                if (token != null && token.startsWith('Error:'))
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Error Details:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          token,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Try restarting the app after rebuilding with the updated configuration.',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Tap the token to select it, then long-press to copy.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              if (token != null && token.isNotEmpty && !token.startsWith('Error:'))
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: token));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Token copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Copy & Close'),
                ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting FCM token: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _savePreferences,
            tooltip: 'Save preferences',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildSectionHeader('Notification Categories'),
                _buildSwitchTile(
                  title: 'Community Notices',
                  subtitle: 'New announcements and updates from your community',
                  value: _preferences['communityNotices'] ?? true,
                  onChanged: (value) {
                    setState(() {
                      _preferences['communityNotices'] = value;
                    });
                  },
                  icon: Icons.campaign,
                  color: Colors.blue,
                ),
                _buildSwitchTile(
                  title: 'Social Interactions',
                  subtitle: 'Likes, comments, and mentions on your posts',
                  value: _preferences['socialInteractions'] ?? true,
                  onChanged: (value) {
                    setState(() {
                      _preferences['socialInteractions'] = value;
                    });
                  },
                  icon: Icons.thumb_up,
                  color: Colors.green,
                ),
                _buildSwitchTile(
                  title: 'Marketplace',
                  subtitle: 'Updates on your listings and interested buyers',
                  value: _preferences['marketplace'] ?? true,
                  onChanged: (value) {
                    setState(() {
                      _preferences['marketplace'] = value;
                    });
                  },
                  icon: Icons.shopping_bag,
                  color: Colors.orange,
                ),
                _buildSwitchTile(
                  title: 'Chat Messages',
                  subtitle: 'New messages from other users',
                  value: _preferences['chat'] ?? true,
                  onChanged: (value) {
                    setState(() {
                      _preferences['chat'] = value;
                    });
                  },
                  icon: Icons.chat,
                  color: Colors.purple,
                ),
                _buildSwitchTile(
                  title: 'Reports',
                  subtitle: 'Updates on reports you\'ve submitted',
                  value: _preferences['reports'] ?? true,
                  onChanged: (value) {
                    setState(() {
                      _preferences['reports'] = value;
                    });
                  },
                  icon: Icons.report_problem,
                  color: Colors.red,
                ),
                _buildSwitchTile(
                  title: 'Volunteer Opportunities',
                  subtitle: 'New volunteer opportunities in your community',
                  value: _preferences['volunteer'] ?? true,
                  onChanged: (value) {
                    setState(() {
                      _preferences['volunteer'] = value;
                    });
                  },
                  icon: Icons.volunteer_activism,
                  color: Colors.teal,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _savePreferences,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                    child: const Text('Save Preferences'),
                  ),
                ),
                const SizedBox(height: 16),

                // Test notification section
                _buildSectionHeader('Testing'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _testNotification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                    child: const Text('Send Test Notification'),
                  ),
                ),
                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _showFcmToken,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                    child: const Text('Show FCM Token'),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18.0,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Color color,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color,
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Theme.of(context).primaryColor,
      ),
      onTap: () {
        onChanged(!value);
      },
    );
  }
}
