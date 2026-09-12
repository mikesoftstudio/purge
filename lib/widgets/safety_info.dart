import 'package:flutter/material.dart';

import '../engine/types.dart';

Future<void> showSafetyTierInfo(BuildContext context, SafetyTier tier) async {
  final (icon, title, body) = switch (tier) {
    SafetyTier.safe => (
        Icons.verified_outlined,
        'Safe',
        'Pure caches and Trash. Removed instantly, and rebuilt automatically '
            'the next time you use your tools. Nothing personal is touched.',
      ),
    SafetyTier.moderate => (
        Icons.warning_amber_rounded,
        'Moderate',
        'Caches that involve a slower one-time rebuild after cleaning — for '
            'example Flutter engine artifacts or old iOS device support files.',
      ),
    SafetyTier.advanced => (
        Icons.construction,
        'Advanced',
        'Heavy, regenerable items such as Docker images and containers. '
            'After cleaning they must be re-pulled or rebuilt before you can '
            'use them again.',
      ),
  };

  await showDialog<void>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final (bg, fg) = switch (tier) {
        SafetyTier.safe => (
            isDark ? const Color(0xFF052E16) : const Color(0xFFECFDF5),
            isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
          ),
        SafetyTier.moderate => (
            isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB),
            isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
          ),
        SafetyTier.advanced => (
            isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
            isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
          ),
      };
      return AlertDialog(
        title: Text('$title to clean'),
        content: SizedBox(
          width: 400,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: fg, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      body,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Every item is regenerable — your projects, source and '
                      'personal files are never touched.',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      );
    },
  );
}