import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/notification_service.dart';
import '../../widgets/admin_scaffold.dart';

class AdminNotificationSettingsPage extends StatefulWidget {
  const AdminNotificationSettingsPage({super.key});

  @override
  State<AdminNotificationSettingsPage> createState() => _AdminNotificationSettingsPageState();
}

class _AdminNotificationSettingsPageState extends State<AdminNotificationSettingsPage> {
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
    }
  }

  Future<void> _savePreferences() async {
    try {
      await _notificationService.updateNotificationPreferences(_preferences);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification preferences saved'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
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

  Future<void> _showFcmToken() async {
    try {
      final token = await _notificationService.getFcmToken();

      if (mounted) {
        // Show a dialog with the token
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
                const SizedBox(height: 16),
                const Text(
                  'Copy this token to use in Firebase Console to send test notifications.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (token != null && token.isNotEmpty && !token.startsWith('Error:')) {
                    Clipboard.setData(ClipboardData(text: token));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Token copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                  Navigator.of(context).pop();
                },
                child: const Text('Copy & Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
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
        activeColor: const Color(0xFF00C49A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Notification Settings',
      actions: [
        IconButton(
          icon: const Icon(Icons.save),
          onPressed: _savePreferences,
          tooltip: 'Save Preferences',
        ),
      ],
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
                  subtitle: 'New listings and updates in the marketplace',
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
                  subtitle: 'New messages in your chats',
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
                  subtitle: 'Updates on community reports',
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
                  title: 'Volunteer Posts',
                  subtitle: 'New volunteer opportunities and updates',
                  value: _preferences['volunteer'] ?? true,
                  onChanged: (value) {
                    setState(() {
                      _preferences['volunteer'] = value;
                    });
                  },
                  icon: Icons.volunteer_activism,
                  color: Colors.teal,
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.token,
                      color: Colors.grey,
                    ),
                  ),
                  title: const Text('Show FCM Token'),
                  subtitle: const Text('View your device token for testing notifications'),
                  onTap: _showFcmToken,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: _savePreferences,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C49A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Save Preferences'),
                  ),
                ),
              ],
            ),
    );
  }
}
