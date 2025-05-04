import 'package:flutter/material.dart';
import '../../services/notification_service.dart';

class NotificationBadge extends StatefulWidget {
  final Widget child;
  final double? top;
  final double? right;
  final double? size;
  final Color? color;
  final Color? textColor;

  const NotificationBadge({
    super.key,
    required this.child,
    this.top = -5,
    this.right = -5,
    this.size = 18,
    this.color,
    this.textColor,
  });

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge>
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
                  return Transform.scale(
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
                            fontSize: count > 99 ? 8 : (count > 9 ? 10 : 12),
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
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
