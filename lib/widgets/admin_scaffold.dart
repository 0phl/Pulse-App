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
            title: Text(widget.title),
            actions: [
              // Add notification badge
              AdminNotificationBadge(
                child: IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {
                    Navigator.pushNamed(context, '/admin/notifications');
                  },
                  tooltip: 'Notifications',
                ),
              ),
              // Add other actions if provided
              if (widget.actions != null) ...widget.actions!,
            ],
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
