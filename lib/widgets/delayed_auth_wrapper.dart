import 'package:flutter/material.dart';
import 'dart:async';
import 'auth_wrapper.dart';
import 'loading_screen.dart';

class DelayedAuthWrapper extends StatefulWidget {
  const DelayedAuthWrapper({super.key});

  @override
  State<DelayedAuthWrapper> createState() => _DelayedAuthWrapperState();
}

class _DelayedAuthWrapperState extends State<DelayedAuthWrapper> {
  bool _delayComplete = false;

  @override
  Widget build(BuildContext context) {
    // Show loading screen with delay
    if (!_delayComplete) {
      return LoadingScreen(
        message: '', // Empty message for a cleaner look
        delay: const Duration(seconds: 7),
        onDelayComplete: () {
          setState(() {
            _delayComplete = true;
          });
        },
      );
    }

    // After delay is complete, show the actual auth wrapper
    return const AuthWrapper();
  }
}
