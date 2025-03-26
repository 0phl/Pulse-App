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
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Line before (except for first step)
            if (step > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color:
                      isActive ? const Color(0xFF00C49A) : Colors.grey.shade300,
                ),
              ),

            // Circle indicator
            GestureDetector(
              onTap: onTap,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? const Color(0xFF00C49A)
                      : isActive
                          ? Colors.white
                          : Colors.grey.shade300,
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF00C49A)
                        : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text(
                          '${step + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? const Color(0xFF00C49A)
                                : Colors.grey,
                          ),
                        ),
                ),
              ),
            ),

            // Line after (except for last step)
            if (step < 2)
              Expanded(
                child: Container(
                  height: 2,
                  color: isCompleted
                      ? const Color(0xFF00C49A)
                      : Colors.grey.shade300,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? const Color(0xFF00C49A) : Colors.grey,
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
    Key? key,
    required this.currentStep,
    required this.onStepTapped,
    required this.maxAllowedStep,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.grey.shade50,
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
                  onStepTapped(0);
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
                  onStepTapped(1);
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
                  onStepTapped(2);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
