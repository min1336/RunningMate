import 'package:flutter/material.dart';
import 'dart:math';

class SpeedDashboard extends StatelessWidget {
  final double speed;
  final double distance;
  final double calories;
  final String elapsedTime;
  final int heartRate;

  const SpeedDashboard({
    super.key,
    required this.speed,
    required this.distance,
    required this.calories,
    required this.elapsedTime,
    required this.heartRate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(calories.toStringAsFixed(2),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text("칼로리", style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Text(distance.toStringAsFixed(2),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text("주행한 km", style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomPaint(
                    size: const Size(180, 90),
                    painter: SpeedometerPainter(speed),
                  ),
                  const SizedBox(height: 8),
                  Text("${speed.toStringAsFixed(1)} km/h",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                children: [
                  Text(elapsedTime,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text("시간", style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Text("$heartRate", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text("BPM", style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SpeedometerPainter extends CustomPainter {
  final double speed;

  SpeedometerPainter(this.speed);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;

    // 반원 그리기
    final arcPaint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, pi, pi, false, arcPaint);

    // 눈금 그리기
    for (int i = 0; i <= 20; i++) {
      final angle = pi + (pi / 20) * i;
      final outerRadius = radius;
      final innerRadius = (i % 5 == 0) ? radius - 20 : radius - 10;

      final startX = center.dx + outerRadius * cos(angle);
      final startY = center.dy + outerRadius * sin(angle);
      final endX = center.dx + innerRadius * cos(angle);
      final endY = center.dy + innerRadius * sin(angle);

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        Paint()
          ..color = (i % 5 == 0) ? Colors.black : Colors.grey
          ..strokeWidth = (i % 5 == 0) ? 3 : 2,
      );
    }

    // 바늘 그리기
    final needlePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final needleAngle = pi + (pi * (speed / 20));
    final needleLength = radius - 30;
    final needleX = center.dx + needleLength * cos(needleAngle);
    final needleY = center.dy + needleLength * sin(needleAngle);

    canvas.drawLine(center, Offset(needleX, needleY), needlePaint);

    // 중앙 원
    final centerCircle = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 5, centerCircle);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// SpeedDashboard 코드 수정: 속도계 디자인 개선
