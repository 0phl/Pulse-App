import 'package:flutter/material.dart';
import '../../services/notification_service.dart';

class AdminNotificationBadge extends StatefulWidget {
  final Widget child;
  final double? top;
  final double? right;
  final double? size;
  final Color? color;
  final Color? textColor;
  final VoidCallback? onTap;

  const AdminNotificationBadge({
    super.key,
    required this.child,
    this.top = -2,
    this.right = -2,
    this.size = 14,
    this.color,
    this.textColor,
    this.onTap,
  });

  @override
  State<AdminNotificationBadge> createState() => _AdminNotificationBadgeState();
}

class _AdminNotificationBadgeState extends State<AdminNotificationBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _previousCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Create a curved animation
    _animation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.2)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationService = NotificationService();
    final badgeColor = widget.color ?? Colors.red;
    final badgeTextColor = widget.textColor ?? Colors.white;

    return StreamBuilder<int>(
      stream: notificationService.getUnreadNotificationCountStream(),
      initialData: 0,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        // Trigger animation when count changes
        if (count > 0 && count != _previousCount) {
          _controller.reset();
          _controller.forward();
          _previousCount = count;
        }

        if (count == 0) {
          return widget.child;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            widget.child,
            Positioned(
              top: widget.top,
              right: widget.right,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return GestureDetector(
                    onTap: widget.onTap,
                    child: Transform.scale(
                      scale: _animation.value,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: BoxConstraints(
                          minWidth: widget.size!,
                          minHeight: widget.size!,
                        ),
                        child: Center(
                          child: Text(
                            count > 99 ? '99+' : count.toString(),
                            style: TextStyle(
                              color: badgeTextColor,
                              fontSize: count > 99 ? 7 : (count > 9 ? 9 : 10),
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
