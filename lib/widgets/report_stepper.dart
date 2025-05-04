import 'package:flutter/material.dart';

class ReportStepIndicator extends StatelessWidget {
  final int step;
  final String title;
  final bool isActive;
  final bool isCompleted;
  final VoidCallback? onTap;

  const ReportStepIndicator({
    Key? key,
    required this.step,
    required this.title,
    required this.isActive,
    required this.isCompleted,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF00C49A);
    final inactiveColor = Colors.grey.shade300;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Line before (except for first step)
            if (step > 0)
              Expanded(
                child: Container(
                  height: 3, // Slightly thicker line
                  decoration: BoxDecoration(
                    gradient: isActive || isCompleted
                        ? LinearGradient(
                            colors: [
                              primaryColor.withAlpha(179), // 0.7 opacity
                              primaryColor,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    color: isActive || isCompleted ? null : inactiveColor,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),

            // Circle indicator
            GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 32, // Larger circle
                height: 32, // Larger circle
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? primaryColor
                      : isActive
                          ? Colors.white
                          : inactiveColor,
                  border: Border.all(
                    color: isActive || isCompleted
                        ? primaryColor
                        : inactiveColor,
                    width: 2.5,
                  ),
                  boxShadow: isActive || isCompleted
                      ? [
                          BoxShadow(
                            color: primaryColor.withAlpha(77), // 0.3 opacity
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : Text(
                          '${step + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? primaryColor
                                : Colors.grey.shade600,
                          ),
                        ),
                ),
              ),
            ),

            // Line after (except for last step)
            if (step < 2)
              Expanded(
                child: Container(
                  height: 3, // Slightly thicker line
                  decoration: BoxDecoration(
                    gradient: isCompleted
                        ? LinearGradient(
                            colors: [
                              primaryColor,
                              primaryColor.withAlpha(179), // 0.7 opacity
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    color: isCompleted ? null : inactiveColor,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8), // More spacing
        Text(
          title,
          style: TextStyle(
            fontSize: 13, // Slightly larger font
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500, // w500 is medium
            color: isActive ? primaryColor : Colors.grey.shade600,
            letterSpacing: 0.3, // Better letter spacing
          ),
        ),
      ],
    );
  }
}

class ReportStepper extends StatelessWidget {
  final int currentStep;
  final Function(int) onStepTapped;
  final int maxAllowedStep;

  const ReportStepper({
    super.key,
    required this.currentStep,
    required this.onStepTapped,
    required this.maxAllowedStep,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: ReportStepIndicator(
                step: 0,
                title: 'Details',
                isActive: currentStep >= 0,
                isCompleted: currentStep > 0,
                onTap: () {
                  if (0 <= maxAllowedStep) {
                    _animateToStep(context, 0);
                  }
                },
              ),
            ),
            Expanded(
              child: ReportStepIndicator(
                step: 1,
                title: 'Location',
                isActive: currentStep >= 1,
                isCompleted: currentStep > 1,
                onTap: () {
                  if (1 <= maxAllowedStep) {
                    _animateToStep(context, 1);
                  }
                },
              ),
            ),
            Expanded(
              child: ReportStepIndicator(
                step: 2,
                title: 'Review',
                isActive: currentStep >= 2,
                isCompleted: currentStep > 2,
                onTap: () {
                  if (2 <= maxAllowedStep) {
                    _animateToStep(context, 2);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _animateToStep(BuildContext context, int step) {
    // Add a subtle haptic feedback if available
    // HapticFeedback.lightImpact();

    // Call the onStepTapped callback with animation
    onStepTapped(step);
  }
}
