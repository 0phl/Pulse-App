import 'package:flutter/material.dart';

class ReportFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Function(bool)? onSelected;

  const ReportFilterChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: onSelected,
        backgroundColor: Colors.grey.shade100,
        selectedColor: const Color(0xFF00C49A).withOpacity(0.1),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF00C49A) : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? const Color(0xFF00C49A) : Colors.transparent,
          ),
        ),
      ),
    );
  }
}
