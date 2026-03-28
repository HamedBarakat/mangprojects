import 'package:flutter/material.dart';

/// ── Mang Projects — Unified Design System ──────────────────────────────────
/// Theme: Dark Slate + Cyan — Professional SaaS style
/// ──────────────────────────────────────────────────────────────────────────
abstract class AppColors {
  // ── Primary Cyan Palette ─────────────────────────────────────────────────
  static const cyan50 = Color(0xFFE0F7FA);
  static const cyan100 = Color(0xFFB2EBF2);
  static const cyan200 = Color(0xFF80DEEA);
  static const cyan300 = Color(0xFF4DD0E1);
  static const cyan400 = Color(0xFF26C6DA);
  static const cyan500 = Color(0xFF00BCD4); // Main accent
  static const cyan600 = Color(0xFF00ACC1);
  static const cyan700 = Color(0xFF0097A7);
  static const cyan800 = Color(0xFF00838F);
  static const cyan900 = Color(0xFF006064);

  // ── Slate / Background Palette ───────────────────────────────────────────
  static const slate900 = Color(0xFF0F172A); // Deepest bg
  static const slate850 = Color(0xFF141E2E); // AppBar bg
  static const slate800 = Color(0xFF1E293B); // Card bg
  static const slate700 = Color(0xFF253447); // Card border / elevated
  static const slate600 = Color(0xFF334155); // Dividers
  static const slate500 = Color(0xFF475569); // Disabled text
  static const slate400 = Color(0xFF64748B); // Secondary text
  static const slate300 = Color(0xFF94A3B8); // Hint text
  static const slate200 = Color(0xFFCBD5E1); // Body text
  static const slate100 = Color(0xFFE2E8F0); // Headings
  static const slate50 = Color(0xFFF1F5F9); // White near

  // ── Semantic Colors ───────────────────────────────────────────────────────
  static const success = Color(0xFF10B981); // Emerald green
  static const warning = Color(0xFFF59E0B); // Amber
  static const error = Color(0xFFEF4444); // Red
  static const info = Color(0xFF3B82F6); // Blue

  // ── Gradient Definitions ──────────────────────────────────────────────────
  static const primaryGradient = LinearGradient(
    colors: [cyan600, cyan400],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cardGradient = LinearGradient(
    colors: [slate800, slate700],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradient = LinearGradient(
    colors: [slate900, slate850],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

/// App-wide ThemeData ──────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get darkTheme {
    const cs = ColorScheme(
      brightness: Brightness.dark,

      // Primary = Cyan
      primary: AppColors.cyan500,
      onPrimary: Colors.white,
      primaryContainer: AppColors.cyan900,
      onPrimaryContainer: AppColors.cyan100,

      // Secondary = Slate 400
      secondary: AppColors.slate400,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.slate700,
      onSecondaryContainer: AppColors.slate100,

      // Tertiary = Success green
      tertiary: AppColors.success,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFF064E3B),
      onTertiaryContainer: Color(0xFFD1FAE5),

      // Surface / Background
      surface: AppColors.slate900,
      onSurface: AppColors.slate100,
      surfaceContainerHighest: AppColors.slate800,
      surfaceContainerHigh: AppColors.slate700,
      surfaceContainer: AppColors.slate800,
      surfaceContainerLow: AppColors.slate850,
      surfaceContainerLowest: AppColors.slate900,

      // Outline
      outline: AppColors.slate600,
      outlineVariant: AppColors.slate700,

      // Error
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFECACA),

      // Shadow / Scrim
      shadow: Colors.black,
      scrim: Colors.black54,

      inverseSurface: AppColors.slate100,
      onInverseSurface: AppColors.slate900,
      inversePrimary: AppColors.cyan800,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      fontFamily: 'Cairo',
      scaffoldBackgroundColor: AppColors.slate900,

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.slate850,
        foregroundColor: AppColors.slate100,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black38,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: AppColors.slate50,
        ),
        iconTheme: IconThemeData(color: AppColors.slate300),
        actionsIconTheme: IconThemeData(color: AppColors.slate300),
      ),

      // ── Card ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.slate800,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.slate700, width: 1),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      // ── NavigationBar ─────────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.slate850,
        indicatorColor: AppColors.cyan500.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.cyan400, size: 24);
          }
          return const IconThemeData(color: AppColors.slate400, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: 'Cairo',
              color: AppColors.cyan400,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            fontFamily: 'Cairo',
            color: AppColors.slate400,
            fontSize: 11,
          );
        }),
        elevation: 0,
        shadowColor: Colors.black54,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      // ── Input Decoration ──────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.slate800,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.slate600),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.slate600),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cyan500, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: const TextStyle(
          color: AppColors.slate500,
          fontFamily: 'Cairo',
        ),
        labelStyle: const TextStyle(
          color: AppColors.slate300,
          fontFamily: 'Cairo',
        ),
        prefixIconColor: AppColors.slate400,
        suffixIconColor: AppColors.slate400,
      ),

      // ── ElevatedButton ────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cyan500,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // ── FilledButton ──────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.cyan500,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // ── OutlinedButton ────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.cyan400,
          side: const BorderSide(color: AppColors.cyan600),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // ── TextButton ────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.cyan400,
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // ── FloatingActionButton ──────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.cyan500,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ── Chip ──────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.slate700,
        selectedColor: AppColors.cyan500.withValues(alpha: 0.2),
        side: const BorderSide(color: AppColors.slate600),
        labelStyle: const TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.slate200,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.slate700,
        thickness: 1,
        space: 1,
      ),

      // ── ListTile ─────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: AppColors.slate400,
        textColor: AppColors.slate200,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.slate100,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.slate400,
          fontSize: 12,
        ),
      ),

      // ── Dialog ───────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.slate800,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.slate50,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.slate300,
          fontSize: 14,
        ),
      ),

      // ── BottomSheet ───────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.slate800,
        modalBackgroundColor: AppColors.slate800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        elevation: 8,
      ),

      // ── SnackBar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.slate700,
        contentTextStyle: const TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.slate100,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Switch ────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.cyan400
              : AppColors.slate400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.cyan500.withValues(alpha: 0.4)
              : AppColors.slate600;
        }),
      ),

      // ── Progress Indicator ────────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.cyan500,
        linearTrackColor: AppColors.slate700,
        circularTrackColor: AppColors.slate700,
      ),

      // ── Tab Bar ───────────────────────────────────────────────────────────
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.cyan400,
        unselectedLabelColor: AppColors.slate400,
        indicatorColor: AppColors.cyan500,
        labelStyle: TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13),
        dividerColor: AppColors.slate700,
      ),

      // ── Typography ────────────────────────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.slate50,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.slate50,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.slate50,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.slate100,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.slate100,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.slate100,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.slate100,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.slate100,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.slate200,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.slate200,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.slate300,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.slate400,
          fontSize: 12,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.slate200,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.slate300,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Cairo',
          color: AppColors.slate400,
          fontSize: 10,
        ),
      ),
    );
  }
}

/// ── Reusable Style Helpers ──────────────────────────────────────────────────
class AppDecorations {
  /// Standard card container
  static BoxDecoration card({Color? color, double radius = 16}) =>
      BoxDecoration(
        color: color ?? AppColors.slate800,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.slate700),
      );

  /// Glowing card with cyan border tint
  static BoxDecoration glowCard({double radius = 16}) => BoxDecoration(
    color: AppColors.slate800,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.cyan900, width: 1.5),
    boxShadow: [
      BoxShadow(
        color: AppColors.cyan500.withValues(alpha: 0.06),
        blurRadius: 16,
        spreadRadius: 2,
      ),
    ],
  );

  /// Hero gradient banner (office card, header)
  static BoxDecoration heroBanner({double radius = 20}) => BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFF0E4A5C), Color(0xFF006064)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: AppColors.cyan800.withValues(alpha: 0.3),
        blurRadius: 20,
        offset: const Offset(0, 6),
      ),
    ],
  );

  /// Status badge background
  static BoxDecoration statusBadge(Color color) => BoxDecoration(
    color: color.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: color.withValues(alpha: 0.3)),
  );

  /// Section container (stat cards, panels)
  static BoxDecoration panel({double radius = 14}) => BoxDecoration(
    color: AppColors.slate800,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.slate700),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

/// Status color helpers ───────────────────────────────────────────────────────
class AppStatusColors {
  static Color forProjectStatus(String status) {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'completed':
        return AppColors.cyan500;
      case 'suspended':
        return AppColors.warning;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.slate400;
    }
  }

  static String labelForProjectStatus(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'suspended':
        return 'Suspended';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  static Color forTaskStatus(String status) {
    switch (status) {
      case 'not_started':
        return AppColors.slate400;
      case 'in_progress':
        return AppColors.info;
      case 'team_leader_review':
        return AppColors.warning;
      case 'qc_review':
        return AppColors.cyan500;
      case 'client_review':
        return Colors.purple;
      case 'completed':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.slate400;
    }
  }

  static Color forRole(String role) {
    switch (role) {
      case 'admin':
        return AppColors.cyan500;
      case 'engineer':
        return AppColors.info;
      case 'team_leader':
        return AppColors.success;
      case 'reviewer':
        return Colors.indigo;
      case 'management':
        return Colors.purple;
      case 'administration':
        return AppColors.slate400;
      case 'dc':
        return AppColors.warning;
      case 'client':
        return AppColors.warning;
      default:
        return AppColors.slate400;
    }
  }
}
