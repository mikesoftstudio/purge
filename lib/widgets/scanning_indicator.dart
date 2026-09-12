import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class ScanningIndicator extends StatefulWidget {
  const ScanningIndicator({super.key, this.size = 120});

  final double size;

  @override
  State<ScanningIndicator> createState() => _ScanningIndicatorState();
}

class _ScanningIndicatorState extends State<ScanningIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _RadarPainter(
              progress: _controller.value,
              primary: purgeGreen,
              track: scheme.surfaceContainerHighest,
            ),
            child: Center(
              child: Container(
                width: widget.size * 0.34,
                height: widget.size * 0.34,
                decoration: BoxDecoration(
                  color: purgeGreen.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.radar,
                  color: purgeGreen,
                  size: widget.size * 0.18,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.progress,
    required this.primary,
    required this.track,
  });

  final double progress;
  final Color primary;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2 - 4;
    final sweep = progress * math.pi * 2;
    final radar = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = track;
    canvas.drawCircle(center, maxRadius, radar);
    canvas.drawCircle(center, maxRadius * 0.68, radar);
    canvas.drawCircle(center, maxRadius * 0.36, radar);

    final sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = primary;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxRadius),
      -math.pi / 2,
      sweep,
      false,
      sweepPaint,
    );

    final dotAngle = -math.pi / 2 + sweep;
    final dotPaint = Paint()..color = primary;
    canvas.drawCircle(
      Offset(
        center.dx + math.cos(dotAngle) * maxRadius * 0.7,
        center.dy + math.sin(dotAngle) * maxRadius * 0.7,
      ),
      3.5,
      dotPaint,
    );

    final fill = Paint()..color = primary.withValues(alpha: 0.10);
    final gradRect = Rect.fromCircle(center: center, radius: maxRadius);
    canvas.save();
    canvas.clipPath(
      Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(gradRect, -math.pi / 2, sweep, false)
        ..close(),
    );
    canvas.drawCircle(center, maxRadius, fill);
    canvas.restore();

    final sweepLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = primary.withValues(alpha: 0.45);
    canvas.drawLine(
      center,
      Offset(center.dx + math.cos(dotAngle) * maxRadius, center.dy + math.sin(dotAngle) * maxRadius),
      sweepLine,
    );
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.primary != primary ||
      oldDelegate.track != track;
}