import 'package:flutter/material.dart';
import 'dart:math' show pi, min, cos, sin;

class PieChartPainter extends CustomPainter {
  final List<int> values;
  final List<Color> colors;
  final bool isDonut;
  final double donutWidth;
  final bool showValues;

  PieChartPainter({
    required this.values,
    required this.colors,
    this.isDonut = true,
    this.donutWidth = 0.3,
    this.showValues = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) {
      // Draw empty state circle with dashed border
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.grey.withOpacity(0.5)
        ..strokeWidth = 2.0;

      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width / 2.5,
        paint,
      );

      // Draw text in the center
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'No Data',
          style: TextStyle(color: Colors.grey[400], fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          size.width / 2 - textPainter.width / 2,
          size.height / 2 - textPainter.height / 2,
        ),
      );
      return;
    }

    // Calculate the smaller dimension to ensure a perfect circle
    final diameter = size.width < size.height ? size.width : size.height;
    final radius = diameter / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: diameter,
      height: diameter,
    );

    double startAngle = -pi / 2; // Start from the top (12 o'clock position)

    for (int i = 0; i < values.length; i++) {
      if (values[i] == 0) continue; // Skip zero values

      final sweepAngle = values[i] / total * 2 * pi;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = colors[i]
        ..strokeWidth = 2.0
        ..isAntiAlias = true;

      // Draw arc with slight padding between segments
      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle - 0.02,
        true,
        paint,
      );

      // Draw percentage value inside the segment if enabled
      if (showValues && values[i] > 0) {
        final percentage = (values[i] / total * 100).toStringAsFixed(0);
        // Only show percentage if it's at least 5% to avoid clutter
        if (values[i] / total >= 0.05) {
          // Calculate position for text (middle of the segment)
          final segmentAngle = startAngle + (sweepAngle / 2);
          final textRadius = radius * 0.7; // Position at 70% of radius
          final x = center.dx + textRadius * cos(segmentAngle);
          final y = center.dy + textRadius * sin(segmentAngle);

          // Draw text
          final textPainter = TextPainter(
            text: TextSpan(
              text: '$percentage%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1))
                ],
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(x - textPainter.width / 2, y - textPainter.height / 2),
          );
        }
      }

      startAngle += sweepAngle;
    }

    // Draw center circle for donut chart
    if (isDonut) {
      canvas.drawCircle(
        center,
        radius * donutWidth,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PieChart extends StatelessWidget {
  final List<int> values;
  final List<Color> colors;
  final List<String>? labels;
  final bool isDonut;
  final double donutWidth;
  final double height;
  final bool showValues;

  const PieChart({
    super.key,
    required this.values,
    required this.colors,
    this.labels,
    this.isDonut = true,
    this.donutWidth = 0.3,
    this.height = 200,
    this.showValues = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate appropriate chart height based on available space
        final availableHeight = constraints.maxHeight;
        final double chartHeight = availableHeight > 0 ?
            min(height, availableHeight * 0.7).toDouble() : // Use 70% of available height
            150.0; // Fallback minimum height

        // Calculate appropriate label height
        final double labelHeight = availableHeight > 0 ?
            min(40.0, availableHeight * 0.3).toDouble() : // Use 30% of available height
            40.0; // Fallback minimum height

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: chartHeight,
              child: CustomPaint(
                painter: PieChartPainter(
                  values: values,
                  colors: colors,
                  isDonut: isDonut,
                  donutWidth: donutWidth,
                  showValues: showValues,
                ),
                size: Size.infinite,
              ),
            ),
            if (labels != null) ...[
              const SizedBox(height: 8), // Reduced spacing
              SizedBox(
                height: labelHeight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      labels!.length,
                      (index) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: colors[index],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              labels![index],
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
