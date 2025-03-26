import 'package:flutter/material.dart';
import 'dart:math' show pi;

class PieChartPainter extends CustomPainter {
  final List<int> values;
  final List<Color> colors;
  final bool isDonut;
  final double donutWidth;

  PieChartPainter({
    required this.values,
    required this.colors,
    this.isDonut = true,
    this.donutWidth = 0.3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    double startAngle = 0;

    for (int i = 0; i < values.length; i++) {
      final sweepAngle = values[i] / total * 2 * pi;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = colors[i];

      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }

    // Draw center circle for donut chart
    if (isDonut) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width * donutWidth,
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

  const PieChart({
    Key? key,
    required this.values,
    required this.colors,
    this.labels,
    this.isDonut = true,
    this.donutWidth = 0.3,
    this.height = 200,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: PieChartPainter(
              values: values,
              colors: colors,
              isDonut: isDonut,
              donutWidth: donutWidth,
            ),
            size: Size.infinite,
          ),
        ),
        if (labels != null) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(
              labels!.length,
              (index) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[index],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    labels![index],
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
