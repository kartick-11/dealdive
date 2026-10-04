import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// DealDive's shared design system — Option A (warm/light) for day,
/// Option B (bold/dark) for night. Both themes are built from this one
/// file so every screen stays visually consistent instead of hardcoding
/// colors locally.
class AppColors {
  // Light — warm & energetic
  static const lightBg = Color(0xFFFBF8F3);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightInputBg = Color(0xFFF1ECE2);
  static const lightLine = Color(0xFFE9E4DA);
  static const lightInk = Color(0xFF16181D);
  static const lightInkSoft = Color(0xFF6E7177);
  static const coral = Color(0xFFFF5A36);
  static const navy = Color(0xFF10243E);
  static const mint = Color(0xFF1F8A70);

  // Dark — bold & dark
  static const darkBg = Color(0xFF111216);
  static const darkSurface = Color(0xFF1B1D23);
  static const darkLine = Color(0xFF2A2C33);
  static const darkInk = Color(0xFFF5F5F2);
  static const darkInkSoft = Color(0xFF8D8F98);
  static const lime = Color(0xFFC6FF3D);
  static const electricBlue = Color(0xFF4D7CFE);

  // One signature color per deal category — used as a small tint on deal
  // cards (price bubble + a soft background wash) so a list of cards reads
  // as varied instead of one flat white/dark block repeated over and over.
  // Deliberately theme-agnostic: each is saturated enough to work as a
  // light-background tint and a dark-background tint alike.
  static const _categoryColors = <String, Color>{
    'Food': Color(0xFFFF8A3D),
    'Fast Food': Color(0xFFFF5A5F),
    'Grocery': Color(0xFF2BB673),
    'Retail': Color(0xFF4D7CFE),
    'Electronics': Color(0xFF8B5CF6),
    'Gas': Color(0xFFF2B134),
    'Student': Color(0xFF06B6D4),
    'Black Friday': Color(0xFFD4A017),
    'Happy Hour': Color(0xFFEC4899),
  };

  static Color forCategory(String category) =>
      _categoryColors[category] ?? coral;
}

class AppTheme {
  AppTheme._();

  /// App-wide theme mode, toggleable from the profile screen's sun/moon
  /// button. Starts following the OS setting; once the user taps the
  /// toggle it switches to an explicit light/dark choice.
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier(ThemeMode.system);

  /// Flips between light and dark. If currently following the system
  /// setting, the first tap moves to the opposite of whatever is
  /// currently showing, then keeps alternating from there.
  static void toggleThemeMode(Brightness currentBrightness) {
    final isDark = themeModeNotifier.value == ThemeMode.dark ||
        (themeModeNotifier.value == ThemeMode.system &&
            currentBrightness == Brightness.dark);
    themeModeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
  }

  static ThemeData get light {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    final display = GoogleFonts.spaceGroteskTextTheme(base.textTheme);
    final body = GoogleFonts.manropeTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.coral,
        brightness: Brightness.light,
        primary: AppColors.coral,
        onPrimary: Colors.white,
        secondary: AppColors.navy,
        tertiary: AppColors.mint,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightInk,
      ),
      textTheme: body.copyWith(
        displayLarge: display.displayLarge,
        displayMedium: display.displayMedium,
        displaySmall: display.displaySmall,
        headlineLarge: display.headlineLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
        headlineMedium: display.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
        headlineSmall: display.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBg,
        foregroundColor: AppColors.lightInk,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: display.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.lightInk,
          fontSize: 20,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightInputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.lightLine, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.lightLine, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.coral, width: 1.5),
        ),
        labelStyle: body.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.lightInk,
          letterSpacing: 0.4,
        ),
        hintStyle: body.bodyMedium?.copyWith(color: AppColors.lightInkSoft),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.coral,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: body.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.coral,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: body.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightInk,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: AppColors.lightInk, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: body.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.coral,
          textStyle: body.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.lightSurface,
        selectedColor: AppColors.lightInk,
        labelStyle: body.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: AppColors.lightInk),
        secondaryLabelStyle: body.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
        shape: StadiumBorder(side: BorderSide(color: AppColors.lightLine, width: 1.5)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: AppColors.coral,
        unselectedItemColor: AppColors.lightInkSoft,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerColor: AppColors.lightLine,
    );
  }

  static ThemeData get dark {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    final display = GoogleFonts.soraTextTheme(base.textTheme);
    final body = GoogleFonts.workSansTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.lime,
        brightness: Brightness.dark,
        primary: AppColors.lime,
        onPrimary: AppColors.darkBg,
        secondary: AppColors.electricBlue,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkInk,
      ),
      textTheme: body.apply(bodyColor: AppColors.darkInk, displayColor: AppColors.darkInk).copyWith(
        displayLarge: display.displayLarge,
        displayMedium: display.displayMedium,
        displaySmall: display.displaySmall,
        headlineLarge: display.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.darkInk),
        headlineMedium: display.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.darkInk),
        headlineSmall: display.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3, color: AppColors.darkInk),
        titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.darkInk),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBg,
        foregroundColor: AppColors.darkInk,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: display.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.darkInk,
          fontSize: 20,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkLine, width: 1.5),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkLine, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkLine, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lime, width: 1.5),
        ),
        labelStyle: body.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.darkInkSoft,
          letterSpacing: 0.4,
        ),
        hintStyle: body.bodyMedium?.copyWith(color: AppColors.darkInkSoft),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lime,
          foregroundColor: AppColors.darkBg,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: body.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lime,
          foregroundColor: AppColors.darkBg,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: body.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkInk,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: AppColors.darkLine, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: body.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.lime,
          textStyle: body.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.darkSurface,
        selectedColor: AppColors.lime,
        labelStyle: body.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: AppColors.darkInk),
        secondaryLabelStyle: body.bodySmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.darkBg),
        shape: StadiumBorder(side: const BorderSide(color: AppColors.darkLine, width: 1.5)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.lime,
        unselectedItemColor: AppColors.darkInkSoft,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerColor: AppColors.darkLine,
    );
  }
}
