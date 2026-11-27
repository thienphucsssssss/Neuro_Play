import 'package:material_ui/material_ui.dart';

abstract final class NeuroTheme {
  static const primary = Color(0xFF2347BA);
  static const onPrimary = Colors.white;
  static const primaryPressed = Color(0xFF19358F);
  static const primaryContainer = Color(0xFFE2E9FF);
  static const onPrimaryContainer = Color(0xFF172F7D);
  static const surface = Color(0xFFF3F6FC);
  static const card = Colors.white;
  static const inset = Color(0xFFE9EFF9);
  static const overlay = Color(0xFFE3EAF8);
  static const ink = Color(0xFF15213A);
  static const muted = Color(0xFF4B5972);
  static const outline = Color(0xFF657795);
  static const rule = Color(0xFFCFD9EB);
  static const error = Color(0xFF9D3843);
  static const errorFill = Color(0xFFF9E6E6);
  static const success = Color(0xFF266447);
  static const successFill = Color(0xFFDDEFE5);
  static const board = Colors.white;
  static const grid = Color(0xFF70819E);
  static const group = Color(0xFF405473);
  static const related = Color(0xFFEEF3FB);
  static const selected = Color(0xFFDCE7FF);
  static const sudoku = Color(0xFF356872);
  static const sudokuFill = Color(0xFFD9EDEF);
  static const cube = Color(0xFF65518A);
  static const cubeFill = Color(0xFFEDE6F7);
  static const sliding = Color(0xFF7C5728);
  static const slidingFill = Color(0xFFF5EADA);
  static const caro = Color(0xFF834A5B);
  static const caroFill = Color(0xFFF5E5EB);

  static const touch = 48.0;
  static const gutter = 16.0;
  static const controlRadius = 8.0;
  static const cardRadius = 12.0;
  static const sheetRadius = 16.0;
  static const select = Duration(milliseconds: 100);
  static const correct = Duration(milliseconds: 140);
  static const wrong = Duration(milliseconds: 160);
  static const result = Duration(milliseconds: 240);
  static const digits = [
    FontFeature.tabularFigures(),
    FontFeature.liningFigures(),
  ];
  static const metric = TextStyle(
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
    fontFeatures: digits,
  );
  static const score = TextStyle(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    fontFeatures: digits,
  );

  static const _type = TextTheme(
    displaySmall: TextStyle(
      fontSize: 36,
      height: 44 / 36,
      fontWeight: FontWeight.w700,
    ),
    headlineMedium: TextStyle(
      fontSize: 30,
      height: 38 / 30,
      fontWeight: FontWeight.w700,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      height: 32 / 24,
      fontWeight: FontWeight.w700,
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      height: 24 / 18,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 24 / 16),
    bodyMedium: TextStyle(fontSize: 14, height: 20 / 14),
    bodySmall: TextStyle(fontSize: 12, height: 16 / 12),
    labelLarge: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w600,
    ),
  );

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: primary).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondaryContainer: primaryContainer,
      onSecondaryContainer: onPrimaryContainer,
      surface: surface,
      surfaceContainerLow: card,
      surfaceContainer: inset,
      surfaceContainerHigh: overlay,
      onSurface: ink,
      onSurfaceVariant: muted,
      outline: outline,
      outlineVariant: rule,
      error: error,
      errorContainer: errorFill,
      onErrorContainer: error,
      scrim: const Color(0x6615213A),
      surfaceTint: Colors.transparent,
    );
    const control = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(controlRadius)),
    );
    const controlSize = Size(touch, touch);
    const panel = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(sheetRadius)),
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      fontFamily: 'Source Sans 3',
      textTheme: _type,
      appBarTheme: const AppBarTheme(
        backgroundColor: card,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: controlSize, shape: control)
            .copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) return inset;
                if (states.contains(WidgetState.pressed)) return primaryPressed;
                return null;
              }),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: card,
          foregroundColor: ink,
          minimumSize: controlSize,
          shape: control,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: controlSize, shape: control),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(controlRadius)),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: primaryContainer,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: overlay,
        modalBackgroundColor: overlay,
        shape: panel,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: overlay,
        shape: panel,
      ),
    );
  }
}
