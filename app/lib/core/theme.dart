import 'package:cute_kid_fonts/cute_kid_fonts.dart';
import 'package:flutter/material.dart';

/// Night palette: near-black, dim warm accent, no white surfaces.
abstract final class Night {
  static const background = Color(0xFF07070A);
  static const surface = Color(0xFF111116);
  static const surfaceHigh = Color(0xFF1A1A20);
  static const accent = Color(0xFF8A6A3A);
  static const accentDim = Color(0xFF4A3A22);
  static const text = Color(0xFF8C8478);
  static const textDim = Color(0xFF5A544C);
  static const outline = Color(0xFF26262C);

  /// Minimum tap target for a parent fumbling in the dark.
  static const tap = 56.0;
}

ThemeData buildNightTheme() {
  const scheme = ColorScheme.dark(
    surface: Night.background,
    surfaceContainerLowest: Night.background,
    surfaceContainerLow: Night.surface,
    surfaceContainer: Night.surface,
    surfaceContainerHigh: Night.surfaceHigh,
    surfaceContainerHighest: Night.surfaceHigh,
    primary: Night.accent,
    onPrimary: Night.background,
    primaryContainer: Night.accentDim,
    onPrimaryContainer: Night.text,
    secondary: Night.accentDim,
    onSecondary: Night.text,
    onSurface: Night.text,
    onSurfaceVariant: Night.textDim,
    outline: Night.outline,
    outlineVariant: Night.outline,
    error: Color(0xFF7A3A32),
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Night.background,
    // No ripples/splashes flashing in a dark room.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Night.background,
      foregroundColor: Night.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 64,
    ),
    iconTheme: const IconThemeData(color: Night.text, size: 28),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(Night.tap),
        foregroundColor: Night.text,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(Night.tap * 2, Night.tap),
        backgroundColor: Night.accentDim,
        foregroundColor: Night.text,
        textStyle: const TextStyle(fontSize: 18),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(Night.tap, Night.tap),
        foregroundColor: Night.text,
        side: const BorderSide(color: Night.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(Night.tap, Night.tap),
        foregroundColor: Night.accent,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 12,
      minTileHeight: Night.tap + 8,
      textColor: Night.text,
      iconColor: Night.text,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Night.accentDim,
      inactiveTrackColor: Night.outline,
      thumbColor: Night.accent,
      trackHeight: 6,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Night.accent : Night.textDim,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Night.accentDim : Night.surfaceHigh,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Night.surface,
      modalBackgroundColor: Night.surface,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Night.surface),
    dividerTheme: const DividerThemeData(color: Night.outline),
    textTheme: base.textTheme.apply(bodyColor: Night.text, displayColor: Night.text),
  );
}

/// Child-facing text (tale titles) uses the kid font; parent controls stay plain.
TextStyle kidTitleStyle({double size = 22, Color color = Night.text}) => TextStyle(
      fontFamily: KidFonts.baloo2,
      fontFamilyFallback: KidFonts.fallback,
      fontVariations: const [FontVariation('wght', 600)],
      fontSize: size,
      height: 1.15,
      color: color,
    );
