import 'package:flutter/material.dart';

enum LoadingScreenType {
  login,
  returning,
}

class LoadingScreen extends StatefulWidget {
  final String message;
  final bool showLogo;
  final LoadingScreenType type;

  const LoadingScreen({
    Key? key,
    this.message = 'Loading...',
    this.showLogo = true,
    this.type = LoadingScreenType.login,
  }) : super(key: key);

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: widget.type == LoadingScreenType.login
            ? _buildLoginLoadingScreen()
            : _buildReturningLoadingScreen(),
      ),
    );
  }

  Widget _buildLoginLoadingScreen() {
    // Full login loading screen with large logo
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.showLogo) ...[
          // Animated Logo Container
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0.95, end: 1.05),
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOut,
            builder: (context, double value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Image.asset(
                    'assets/icon/pulse_logo.png',
                    width: 220,
                    height: 220,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 60),
        ],

        // Minimalist Loading Indicator
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              const Color(0xFF00C49A).withOpacity(0.8),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Loading Message
        Text(
          widget.message,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF757575),
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildReturningLoadingScreen() {
    // More compact loading screen for returning to the app
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.showLogo) ...[
          // Smaller, simpler logo display
          Image.asset(
            'assets/icon/pulse_logo.png',
            width: 120,
            height: 120,
          ),
          const SizedBox(height: 30),
        ],

        // Simple loading indicator
        SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              const Color(0xFF00C49A).withOpacity(0.8),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Loading Message
        Text(
          widget.message,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF757575),
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
