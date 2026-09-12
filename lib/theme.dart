import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const purgeGreen = Color(0xFF16A364);
const purgeGreenDark = Color(0xFF1FBF78);
const purgeTeal = Color(0xFF14B8A6);
const purgeAmber = Color(0xFFF59E0B);
const purgeRed = Color(0xFFDC2626);

const List<Color> purgeBrandGradient = [Color(0xFF16A364), Color(0xFF1FBF8B)];

const sora = 'Sora';
const fraunces = 'Fraunces';

const _desktopTargets = {
  TargetPlatform.macOS,
  TargetPlatform.windows,
  TargetPlatform.linux,
};

bool get isDesktopPlatform => _desktopTargets.contains(defaultTargetPlatform);

TextTheme _buildTextTheme(TextTheme base) {
  TextStyle display(double size, {double spacing = -0.15}) => TextStyle(
        fontFamily: fraunces,
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.12,
        letterSpacing: spacing * size / 57,
      );
  return base.apply(fontFamily: sora).copyWith(
    displayLarge: display(57),
    displayMedium: display(45),
    displaySmall: display(36),
    headlineLarge: display(32),
    headlineMedium: display(28),
    headlineSmall: display(24),
    titleLarge: base.titleLarge
        ?.copyWith(fontFamily: sora, fontWeight: FontWeight.w700, letterSpacing: -0.3),
  );
}

ThemeData purgeTheme({required Brightness brightness}) {
  final isDark = brightness == Brightness.dark;
  final isDesktop = isDesktopPlatform;
  final scheme = ColorScheme.fromSeed(
    seedColor: purgeGreen,
    brightness: brightness,
    primary: isDark ? purgeGreenDark : purgeGreen,
    onPrimary: Colors.white,
    surface: isDark ? const Color(0xFF0B1220) : const Color(0xFFF7F9FC),
    onSurface: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F1729),
    error: isDark ? const Color(0xFF9B2C2C) : const Color(0xFFDC2626),
  );

  final baseTextTheme =
      ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness).textTheme;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: sora,
    scaffoldBackgroundColor: scheme.surface,
    visualDensity: isDesktop ? VisualDensity.compact : VisualDensity.standard,
    textTheme: _buildTextTheme(baseTextTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface.withValues(alpha: 0.92),
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: const ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: const FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: const FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    cardTheme: CardThemeData(
      color: isDark ? const Color(0xFF121A2A) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: scheme.primary,
      labelStyle: TextStyle(color: scheme.onSurface, fontSize: 12),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface.withValues(alpha: 0.94),
      indicatorColor: isDark ? const Color(0xFF14532D) : const Color(0xFFD1FAE5),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: isDark ? const Color(0xFF14532D) : const Color(0xFFD1FAE5),
      selectedIconTheme: IconThemeData(color: scheme.primary),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      selectedLabelTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontSize: 12,
        color: scheme.onSurfaceVariant,
      ),
    ),
  );
}
