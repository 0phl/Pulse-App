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
    super.key,
    this.message = 'Loading...',
    this.showLogo = true,
    this.type = LoadingScreenType.login,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;


  @override
  void initState() {
    super.initState();
    // Create a one-way animation controller (small to big)
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..forward(); // Only go forward (small to big)

    // Use a more natural curve for the animation
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    // Create a fade-in animation for a more polished look
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Start the fade-in animation
    _fadeController.forward();


  }

  // Ensure animations are at their final state
  void _ensureAnimationsComplete() {
    if (_controller.status != AnimationStatus.completed) {
      _controller.animateTo(1.0, duration: const Duration(milliseconds: 300));
    }
    if (_fadeController.status != AnimationStatus.completed) {
      _fadeController.animateTo(1.0,
          duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    // Complete animations before disposing to avoid visual glitches
    _ensureAnimationsComplete();

    _controller.dispose();
    _fadeController.dispose();

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
          // Enhanced Animated Logo Container with multiple animations and fade-in
          AnimatedBuilder(
            animation: Listenable.merge([_animation, _fadeAnimation]),
            builder: (context, child) {
              // Calculate a scale that goes from small to big
              final scale =
                  0.85 + (_animation.value * 0.3); // Scale from 0.85 to 1.15

              // Apply fade-in effect
              final opacity = _fadeAnimation.value;

              return Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Image.asset(
                      'assets/icon/pulse_logo.png',
                      width: 260, // Larger logo size
                      height: 260,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 60),
        ],

        // Animated pulsing loading indicator
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            // Create a pulsing effect for the loading indicator
            final pulseValue =
                0.8 + (_animation.value * 0.4); // Pulse between 0.8 and 1.2

            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: pulseValue,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF00C49A).withOpacity(0.8),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Adjust spacing when no message is shown
        SizedBox(height: widget.message.isNotEmpty ? 16 : 0),

        // Loading Message - only show if not empty
        if (widget.message.isNotEmpty)
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
          // Animated logo for returning screen with fade-in effect
          AnimatedBuilder(
            animation: Listenable.merge([_animation, _fadeAnimation]),
            builder: (context, child) {
              final scale = 0.9 +
                  (_animation.value *
                      0.2); // Smaller scale range for returning screen
              final opacity = _fadeAnimation.value;

              return Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Image.asset(
                    'assets/icon/pulse_logo.png',
                    width: 140, // Slightly larger
                    height: 140,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 30),
        ],

        // Animated pulsing loading indicator for returning screen
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            // Create a pulsing effect for the loading indicator
            final pulseValue =
                0.85 + (_animation.value * 0.3); // Pulse between 0.85 and 1.15

            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: pulseValue,
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF00C49A).withOpacity(0.8),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Adjust spacing when no message is shown
        SizedBox(height: widget.message.isNotEmpty ? 12 : 0),

        // Loading Message - only show if not empty
        if (widget.message.isNotEmpty)
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
