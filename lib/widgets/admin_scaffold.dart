import 'package:flutter/material.dart';
import '../pages/admin/admin_drawer.dart';
import 'admin/admin_notification_badge.dart';

/// A base scaffold for all admin pages that includes the back button confirmation.
/// This ensures consistent back button behavior across the admin section.
class AdminScaffold extends StatefulWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;
  final PreferredSizeWidget? appBar;
  final bool showNotificationIcon;

  const AdminScaffold({
    Key? key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.extendBodyBehindAppBar = false,
    this.appBar,
    this.showNotificationIcon = true,
  }) : super(key: key);

  @override
  State<AdminScaffold> createState() => _AdminScaffoldState();
}

class _AdminScaffoldState extends State<AdminScaffold> {
  DateTime? _lastPressedAt;

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        // Double-press back to exit
        if (_lastPressedAt == null ||
            DateTime.now().difference(_lastPressedAt!) >
                const Duration(seconds: 2)) {
          _lastPressedAt = DateTime.now();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: widget.appBar ??
            AppBar(
              // Use standard title
              title: Text(widget.title),
              // Standard title spacing
              titleSpacing: 16.0,
              // Add notification icon to actions
              actions: [
                // Add notification badge with increased padding to move away from the screen edge
                if (widget.showNotificationIcon)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, right: 16.0),
                    child: AdminNotificationBadge(
                      onTap: () {
                        Navigator.pushNamed(context, '/admin/notifications');
                      },
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/admin/notifications');
                        },
                        child: const Icon(Icons.notifications, size: 24),
                      ),
                    ),
                  ),
                // Add other actions if provided
                if (widget.actions != null) ...widget.actions!,
                // Add extra space after all actions
                const SizedBox(width: 8),
              ],
              // Customize AppBar to reduce spacing
              toolbarHeight: 56.0,
              leadingWidth: 40.0,
            ),
        drawer: const AdminDrawer(),
        body: widget.body,
        floatingActionButton: widget.floatingActionButton,
        floatingActionButtonLocation: widget.floatingActionButtonLocation,
        backgroundColor: widget.backgroundColor,
        extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
      ),
    );
  }
}
