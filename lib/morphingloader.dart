import 'dart:math' as math;
import 'package:flutter/material.dart';

class WavyCircularProgressIndicator extends StatefulWidget {
  final Color color;
  final double strokeWidth;
  final double size;
  final int waveCount;
  final double waveAmplitude;

  const WavyCircularProgressIndicator({
    Key? key,
    this.color = Colors.blue,
    this.strokeWidth = 4.0,
    this.size = 48.0,
    this.waveCount = 5,
    this.waveAmplitude = 3.0,
  }) : super(key: key);

  @override
  State<WavyCircularProgressIndicator> createState() => _WavyCircularProgressIndicatorState();
}

class _WavyCircularProgressIndicatorState extends State<WavyCircularProgressIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _WavyCirclePainter(
              color: widget.color,
              strokeWidth: widget.strokeWidth,
              animationValue: _controller.value,
              waveCount: widget.waveCount,
              waveAmplitude: widget.waveAmplitude,
            ),
          ),
        );
      },
    );
  }
}

class _WavyCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double animationValue;
  final int waveCount;
  final double waveAmplitude;

  _WavyCirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.animationValue,
    required this.waveCount,
    required this.waveAmplitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    var firstPoint = true;
    
    for (double i = 0; i < 360; i += 1) {
      // Convert to radians
      final radians = (i - 90) * (math.pi / 180);
      
      // Create the wave effect
      final waveOffset = math.sin((i / 360 * waveCount * 2 * math.pi) + (animationValue * 2 * math.pi)) * waveAmplitude;
      
      // Calculate point on the circle, adjusted by the wave
      final adjustedRadius = radius + waveOffset;
      final x = center.dx + adjustedRadius * math.cos(radians);
      final y = center.dy + adjustedRadius * math.sin(radians);
      
      if (firstPoint) {
        path.moveTo(x, y);
        firstPoint = false;
      } else {
        path.lineTo(x, y);
      }
    }
    
    // Close the path to form a complete circle
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavyCirclePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}