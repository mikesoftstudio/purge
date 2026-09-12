import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/bytes.dart';
import '../engine/types.dart';
import '../theme.dart';

class DiskOverview extends StatelessWidget {
  const DiskOverview({super.key, required this.disk, this.reclaimableBytes});

  final DiskInfo disk;
  final int? reclaimableBytes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final usedPct = disk.totalBytes > 0
        ? (disk.usedBytes / disk.totalBytes).clamp(0.0, 1.0)
        : 0.0;
    final reclaimPct = disk.totalBytes > 0 && reclaimableBytes != null
        ? (reclaimableBytes! / disk.totalBytes).clamp(0.0, usedPct)
        : 0.0;
    final muted = scheme.onSurfaceVariant;
    final showReclaim = reclaimableBytes != null && reclaimableBytes! > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 430;
        final metrics = Column(
          crossAxisAlignment: narrow
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Metric(
              color: purgeGreen,
              label: 'Used',
              value: formatBytes(disk.usedBytes),
              muted: muted,
            ),
            const SizedBox(height: 12),
            if (showReclaim) ...[
              _Metric(
                color: purgeAmber,
                label: 'Reclaimable',
                value: formatBytes(reclaimableBytes!),
                muted: muted,
                highlight: true,
              ),
              const SizedBox(height: 12),
            ],
            _Metric(
              color: scheme.surfaceContainerHighest,
              label: 'Free',
              value: formatBytes(disk.freeBytes),
              muted: muted,
              large: true,
            ),
          ],
        );

        final donut = SizedBox(
          width: 148,
          height: 148,
          child: CustomPaint(
            painter: _DonutPainter(
              usedFraction: usedPct,
              reclaimableFraction: reclaimPct,
              usedColor: purgeGreen,
              reclaimableColor: purgeAmber,
              trackColor: scheme.surfaceContainerHighest,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(usedPct * 100).round()}%',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    'used',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Free space',
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatBytes(disk.freeBytes),
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (showReclaim)
                        Text(
                          '${formatBytes(reclaimableBytes!)} of it is safe to reclaim',
                          style: TextStyle(
                            color: purgeAmber,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  disk.filesystem,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (narrow)
              Row(
                children: [
                  donut,
                  const SizedBox(width: 24),
                  Expanded(child: metrics),
                ],
              )
            else
              Row(
                children: [
                  donut,
                  const SizedBox(width: 32),
                  Expanded(child: metrics),
                  if (disk.home.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Home',
                            style: TextStyle(color: muted, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            disk.home,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: muted,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.color,
    required this.label,
    required this.value,
    required this.muted,
    this.large = false,
    this.highlight = false,
  });

  final Color color;
  final String label;
  final String value;
  final Color muted;
  final bool large;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: muted, fontSize: 11),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: large ? 20 : 16,
                fontWeight: large ? FontWeight.w700 : FontWeight.w600,
                color: highlight ? purgeAmber : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.usedFraction,
    required this.reclaimableFraction,
    required this.usedColor,
    required this.reclaimableColor,
    required this.trackColor,
  });

  final double usedFraction;
  final double reclaimableFraction;
  final Color usedColor;
  final Color reclaimableColor;
  final Color trackColor;

  static const _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 16.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    if (usedFraction > 0) {
      final used = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = usedColor;
      canvas.drawArc(rect, _start, usedFraction * math.pi * 2, false, used);
    }
    if (reclaimableFraction > 0) {
      final reclaim = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = reclaimableColor;
      canvas.drawArc(
        rect,
        _start + usedFraction * math.pi * 2,
        reclaimableFraction * math.pi * 2,
        false,
        reclaim,
      );
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.usedFraction != usedFraction ||
      oldDelegate.reclaimableFraction != reclaimableFraction ||
      oldDelegate.usedColor != usedColor ||
      oldDelegate.reclaimableColor != reclaimableColor ||
      oldDelegate.trackColor != trackColor;
}