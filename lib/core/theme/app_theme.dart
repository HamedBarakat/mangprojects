import 'package:flutter/material.dart';

/// ── Mang Projects — Unified Design System ──────────────────────────────────
/// 4 themes: Cyan (dark+light), Purple (dark+light), Green (dark+light), White (light only)
/// ──────────────────────────────────────────────────────────────────────────

enum AppThemeVariant { cyan, purple, green, white }

class AppThemeConfig {
  final AppThemeVariant variant;
  final Brightness brightness;

  const AppThemeConfig({
    this.variant = AppThemeVariant.cyan,
    this.brightness = Brightness.dark,
  });

  AppThemeConfig copyWith({AppThemeVariant? variant, Brightness? brightness}) =>
      AppThemeConfig(variant: variant ?? this.variant, brightness: brightness ?? this.brightness);

  String get id {
    final b = brightness == Brightness.dark ? 'dark' : 'light';
    return '${variant.name}_$b';
  }

  static AppThemeConfig fromId(String id) {
    final parts = id.split('_');
    final bStr = parts.last;
    final vStr = parts.sublist(0, parts.length - 1).join('_');
    final brightness = bStr == 'light' ? Brightness.light : Brightness.dark;
    final variant = AppThemeVariant.values.firstWhere((v) => v.name == vStr, orElse: () => AppThemeVariant.cyan);
    return AppThemeConfig(variant: variant, brightness: brightness);
  }

  /// White theme is always light
  AppThemeConfig get effective {
    if (variant == AppThemeVariant.white) return copyWith(brightness: Brightness.light);
    return this;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PALETTE — all 7 combinations
// ══════════════════════════════════════════════════════════════════════════════

class _P {
  // accent
  final Color a5, a4, a6, a2, a9, a8;
  // bg scale: bg0=deepest(scaffold), bg1=appbar, bg2=card, bg3=border/elevated,
  //           bg4=divider, bg5=disabled, bg6=secondary text,
  //           bg7=hint, bg8=body, bg9=heading, bg10=near-white
  final Color bg0, bg1, bg2, bg3, bg4, bg5, bg6, bg7, bg8, bg9, bg10;
  final Brightness brightness;

  const _P({
    required this.a5, required this.a4, required this.a6,
    required this.a2, required this.a9, required this.a8,
    required this.bg0, required this.bg1, required this.bg2,
    required this.bg3, required this.bg4, required this.bg5,
    required this.bg6, required this.bg7, required this.bg8,
    required this.bg9, required this.bg10,
    required this.brightness,
  });
}

// ── Cyan Dark ─────────────────────────────────────────────────────────────────
const _cD = _P(
  a5:Color(0xFF00BCD4),a4:Color(0xFF26C6DA),a6:Color(0xFF00ACC1),
  a2:Color(0xFF80DEEA),a9:Color(0xFF006064),a8:Color(0xFF00838F),
  bg0:Color(0xFF0F172A),bg1:Color(0xFF141E2E),bg2:Color(0xFF1E293B),
  bg3:Color(0xFF253447),bg4:Color(0xFF334155),bg5:Color(0xFF475569),
  bg6:Color(0xFF64748B),bg7:Color(0xFF94A3B8),bg8:Color(0xFFCBD5E1),
  bg9:Color(0xFFE2E8F0),bg10:Color(0xFFF1F5F9),
  brightness:Brightness.dark,
);

// ── Cyan Light ────────────────────────────────────────────────────────────────
const _cL = _P(
  a5:Color(0xFF0097A7),a4:Color(0xFF00ACC1),a6:Color(0xFF00838F),
  a2:Color(0xFFB2EBF2),a9:Color(0xFFE0F7FA),a8:Color(0xFFB2EBF2),
  bg0:Color(0xFFF0F4F8),bg1:Color(0xFFFFFFFF),bg2:Color(0xFFFFFFFF),
  bg3:Color(0xFFE2E8F0),bg4:Color(0xFFCBD5E1),bg5:Color(0xFF94A3B8),
  bg6:Color(0xFF64748B),bg7:Color(0xFF475569),bg8:Color(0xFF334155),
  bg9:Color(0xFF1E293B),bg10:Color(0xFF0F172A),
  brightness:Brightness.light,
);

// ── Purple Dark ───────────────────────────────────────────────────────────────
const _pD = _P(
  a5:Color(0xFF8B5CF6),a4:Color(0xFFA78BFA),a6:Color(0xFF7C3AED),
  a2:Color(0xFFDDD6FE),a9:Color(0xFF2E1065),a8:Color(0xFF4C1D95),
  bg0:Color(0xFF0D0B1A),bg1:Color(0xFF131024),bg2:Color(0xFF1C1834),
  bg3:Color(0xFF261F42),bg4:Color(0xFF342B54),bg5:Color(0xFF4A3F6E),
  bg6:Color(0xFF6B5F8A),bg7:Color(0xFF9B8FB5),bg8:Color(0xFFCEC6E0),
  bg9:Color(0xFFE6E2F0),bg10:Color(0xFFF3F0F9),
  brightness:Brightness.dark,
);

// ── Purple Light ──────────────────────────────────────────────────────────────
const _pL = _P(
  a5:Color(0xFF7C3AED),a4:Color(0xFF8B5CF6),a6:Color(0xFF6D28D9),
  a2:Color(0xFFEDE9FE),a9:Color(0xFFF5F3FF),a8:Color(0xFFEDE9FE),
  bg0:Color(0xFFF5F0FF),bg1:Color(0xFFFFFFFF),bg2:Color(0xFFFFFFFF),
  bg3:Color(0xFFEDE9FE),bg4:Color(0xFFDDD6FE),bg5:Color(0xFFA78BFA),
  bg6:Color(0xFF7C6AA6),bg7:Color(0xFF5B4D8A),bg8:Color(0xFF3D2F70),
  bg9:Color(0xFF2E1A5E),bg10:Color(0xFF1A0F3A),
  brightness:Brightness.light,
);

// ── Green Dark ────────────────────────────────────────────────────────────────
const _gD = _P(
  a5:Color(0xFF10B981),a4:Color(0xFF34D399),a6:Color(0xFF059669),
  a2:Color(0xFFA7F3D0),a9:Color(0xFF064E3B),a8:Color(0xFF065F46),
  bg0:Color(0xFF0A1612),bg1:Color(0xFF0F1E18),bg2:Color(0xFF162820),
  bg3:Color(0xFF1E3828),bg4:Color(0xFF274A34),bg5:Color(0xFF3A6447),
  bg6:Color(0xFF5A8068),bg7:Color(0xFF8AAF9B),bg8:Color(0xFFC0D6CB),
  bg9:Color(0xFFDDEDE6),bg10:Color(0xFFEFF6F2),
  brightness:Brightness.dark,
);

// ── Green Light ───────────────────────────────────────────────────────────────
const _gL = _P(
  a5:Color(0xFF059669),a4:Color(0xFF10B981),a6:Color(0xFF047857),
  a2:Color(0xFFD1FAE5),a9:Color(0xFFECFDF5),a8:Color(0xFFD1FAE5),
  bg0:Color(0xFFEEFAF4),bg1:Color(0xFFFFFFFF),bg2:Color(0xFFFFFFFF),
  bg3:Color(0xFFD1FAE5),bg4:Color(0xFFA7F3D0),bg5:Color(0xFF6EE7B7),
  bg6:Color(0xFF3A7A5C),bg7:Color(0xFF236047),bg8:Color(0xFF145233),
  bg9:Color(0xFF0D3D26),bg10:Color(0xFF042918),
  brightness:Brightness.light,
);

// ── White / Clean ─────────────────────────────────────────────────────────────
const _wL = _P(
  a5:Color(0xFF2563EB),a4:Color(0xFF3B82F6),a6:Color(0xFF1D4ED8),
  a2:Color(0xFFDBEAFE),a9:Color(0xFFEFF6FF),a8:Color(0xFFDBEAFE),
  bg0:Color(0xFFF8F9FA),bg1:Color(0xFFFFFFFF),bg2:Color(0xFFFFFFFF),
  bg3:Color(0xFFE9ECEF),bg4:Color(0xFFDEE2E6),bg5:Color(0xFFADB5BD),
  bg6:Color(0xFF6C757D),bg7:Color(0xFF495057),bg8:Color(0xFF343A40),
  bg9:Color(0xFF212529),bg10:Color(0xFF0D0F12),
  brightness:Brightness.light,
);

_P _getPal(AppThemeConfig cfg) {
  final c = cfg.effective;
  if (c.variant == AppThemeVariant.cyan)   return c.brightness==Brightness.dark ? _cD : _cL;
  if (c.variant == AppThemeVariant.purple) return c.brightness==Brightness.dark ? _pD : _pL;
  if (c.variant == AppThemeVariant.green)  return c.brightness==Brightness.dark ? _gD : _gL;
  return _wL; // white always light
}

// ══════════════════════════════════════════════════════════════════════════════
// LEGACY AppColors — stays exactly the same for backward compat
// ══════════════════════════════════════════════════════════════════════════════

abstract class AppColors {
  static const cyan50  = Color(0xFFE0F7FA);
  static const cyan100 = Color(0xFFB2EBF2);
  static const cyan200 = Color(0xFF80DEEA);
  static const cyan300 = Color(0xFF4DD0E1);
  static const cyan400 = Color(0xFF26C6DA);
  static const cyan500 = Color(0xFF00BCD4);
  static const cyan600 = Color(0xFF00ACC1);
  static const cyan700 = Color(0xFF0097A7);
  static const cyan800 = Color(0xFF00838F);
  static const cyan900 = Color(0xFF006064);

  static const slate900 = Color(0xFF0F172A);
  static const slate850 = Color(0xFF141E2E);
  static const slate800 = Color(0xFF1E293B);
  static const slate700 = Color(0xFF253447);
  static const slate600 = Color(0xFF334155);
  static const slate500 = Color(0xFF475569);
  static const slate400 = Color(0xFF64748B);
  static const slate300 = Color(0xFF94A3B8);
  static const slate200 = Color(0xFFCBD5E1);
  static const slate100 = Color(0xFFE2E8F0);
  static const slate50  = Color(0xFFF1F5F9);

  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error   = Color(0xFFEF4444);
  static const info    = Color(0xFF3B82F6);

  static const primaryGradient = LinearGradient(
    colors: [cyan600, cyan400], begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const cardGradient = LinearGradient(
    colors: [slate800, slate700], begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const heroGradient = LinearGradient(
    colors: [slate900, slate850], begin: Alignment.topCenter, end: Alignment.bottomCenter,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// THEME BUILDER
// ══════════════════════════════════════════════════════════════════════════════

class AppTheme {
  static ThemeData buildTheme(AppThemeConfig cfg) {
    final p = _getPal(cfg);
    final isDark = p.brightness == Brightness.dark;
    final shadow = isDark ? Colors.black : const Color(0x22000000);

    final cs = ColorScheme(
      brightness: p.brightness,
      // PRIMARY = accent
      primary: p.a5,
      onPrimary: Colors.white,
      primaryContainer: p.a9,
      onPrimaryContainer: p.a2,
      // SECONDARY = muted text
      secondary: p.bg6,
      onSecondary: Colors.white,
      secondaryContainer: p.bg3,
      onSecondaryContainer: p.bg9,
      // TERTIARY = success green
      tertiary: const Color(0xFF10B981),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFF064E3B),
      onTertiaryContainer: const Color(0xFFD1FAE5),
      // SURFACE (scaffold, cards, sheets)
      surface: p.bg0,          // scaffold background
      onSurface: p.bg9,        // primary text
      surfaceContainerLowest: p.bg0,
      surfaceContainerLow: p.bg1,
      surfaceContainer: p.bg2, // cards
      surfaceContainerHigh: p.bg3,
      surfaceContainerHighest: p.bg3,
      // OUTLINE
      outline: p.bg4,
      outlineVariant: p.bg3,
      // ERROR
      error: const Color(0xFFEF4444),
      onError: Colors.white,
      errorContainer: const Color(0xFF7F1D1D),
      onErrorContainer: const Color(0xFFFECACA),
      // MISC
      shadow: shadow,
      scrim: Colors.black54,
      inverseSurface: p.bg9,
      onInverseSurface: p.bg0,
      inversePrimary: p.a8,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      fontFamily: 'Cairo',
      scaffoldBackgroundColor: p.bg0,

      appBarTheme: AppBarTheme(
        backgroundColor: p.bg1,
        foregroundColor: p.bg9,
        elevation: 0,
        scrolledUnderElevation: isDark ? 1 : 0.5,
        surfaceTintColor: Colors.transparent,
        shadowColor: isDark ? Colors.black38 : const Color(0x22000000),
        titleTextStyle: TextStyle(fontFamily:'Cairo',fontWeight:FontWeight.bold,fontSize:18,color:p.bg10),
        iconTheme: IconThemeData(color: p.bg7),
        actionsIconTheme: IconThemeData(color: p.bg7),
      ),

      cardTheme: CardThemeData(
        color: p.bg2,
        elevation: isDark ? 0 : 1,
        shadowColor: shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.bg3, width: 1),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.bg1,
        indicatorColor: p.a5.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected)
            ? IconThemeData(color: p.a4, size: 24)
            : IconThemeData(color: p.bg6, size: 22)),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected)
            ? TextStyle(fontFamily:'Cairo',color:p.a4,fontSize:11,fontWeight:FontWeight.w600)
            : TextStyle(fontFamily:'Cairo',color:p.bg6,fontSize:11)),
        elevation: 0,
        shadowColor: shadow,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.bg2,
        contentPadding: const EdgeInsets.symmetric(horizontal:16,vertical:14),
        border: OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide(color:p.bg4)),
        enabledBorder: OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide(color:p.bg4)),
        focusedBorder: OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide(color:p.a5,width:2)),
        errorBorder: OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:Color(0xFFEF4444))),
        hintStyle: TextStyle(color:p.bg5,fontFamily:'Cairo'),
        labelStyle: TextStyle(color:p.bg7,fontFamily:'Cairo'),
        prefixIconColor: p.bg6,
        suffixIconColor: p.bg6,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor:p.a5,foregroundColor:Colors.white,elevation:0,
        padding:const EdgeInsets.symmetric(horizontal:24,vertical:14),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
        textStyle:const TextStyle(fontFamily:'Cairo',fontWeight:FontWeight.w600,fontSize:14),
      )),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        backgroundColor:p.a5,foregroundColor:Colors.white,elevation:0,
        padding:const EdgeInsets.symmetric(horizontal:24,vertical:14),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
        textStyle:const TextStyle(fontFamily:'Cairo',fontWeight:FontWeight.w600,fontSize:14),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor:p.a4,side:BorderSide(color:p.a6),
        padding:const EdgeInsets.symmetric(horizontal:24,vertical:14),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
        textStyle:const TextStyle(fontFamily:'Cairo',fontWeight:FontWeight.w600,fontSize:14),
      )),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
        foregroundColor:p.a4,
        textStyle:const TextStyle(fontFamily:'Cairo',fontWeight:FontWeight.w600,fontSize:14),
      )),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor:p.a5,foregroundColor:Colors.white,elevation:4,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor:p.bg3,selectedColor:p.a5.withValues(alpha:0.2),
        side:BorderSide(color:p.bg4),
        labelStyle:TextStyle(fontFamily:'Cairo',color:p.bg8,fontSize:12),
        padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(color:p.bg3,thickness:1,space:1),
      listTileTheme: ListTileThemeData(
        tileColor:Colors.transparent,
        contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:4),
        iconColor:p.bg6,textColor:p.bg8,
        titleTextStyle:TextStyle(fontFamily:'Cairo',color:p.bg9,fontSize:14,fontWeight:FontWeight.w500),
        subtitleTextStyle:TextStyle(fontFamily:'Cairo',color:p.bg6,fontSize:12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor:p.bg2,elevation:8,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
        titleTextStyle:TextStyle(fontFamily:'Cairo',color:p.bg10,fontSize:18,fontWeight:FontWeight.bold),
        contentTextStyle:TextStyle(fontFamily:'Cairo',color:p.bg7,fontSize:14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor:p.bg2,modalBackgroundColor:p.bg2,
        shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),
        elevation:8,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:p.bg3,
        contentTextStyle:TextStyle(fontFamily:'Cairo',color:p.bg9),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
        behavior:SnackBarBehavior.floating,
      ),
      switchTheme: SwitchThemeData(
        thumbColor:WidgetStateProperty.resolveWith((s)=>s.contains(WidgetState.selected)?p.a4:p.bg6),
        trackColor:WidgetStateProperty.resolveWith((s)=>s.contains(WidgetState.selected)?p.a5.withValues(alpha:0.4):p.bg4),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color:p.a5,linearTrackColor:p.bg3,circularTrackColor:p.bg3),
      tabBarTheme: TabBarThemeData(
        labelColor:p.a4,unselectedLabelColor:p.bg6,indicatorColor:p.a5,
        labelStyle:const TextStyle(fontFamily:'Cairo',fontWeight:FontWeight.w600,fontSize:13),
        unselectedLabelStyle:const TextStyle(fontFamily:'Cairo',fontSize:13),
        dividerColor:p.bg3,
      ),
      textTheme: TextTheme(
        displayLarge:  TextStyle(fontFamily:'Cairo',color:p.bg10,fontWeight:FontWeight.bold),
        displayMedium: TextStyle(fontFamily:'Cairo',color:p.bg10,fontWeight:FontWeight.bold),
        displaySmall:  TextStyle(fontFamily:'Cairo',color:p.bg10,fontWeight:FontWeight.bold),
        headlineLarge: TextStyle(fontFamily:'Cairo',color:p.bg9, fontWeight:FontWeight.bold),
        headlineMedium:TextStyle(fontFamily:'Cairo',color:p.bg9, fontWeight:FontWeight.bold),
        headlineSmall: TextStyle(fontFamily:'Cairo',color:p.bg9, fontWeight:FontWeight.w600),
        titleLarge:    TextStyle(fontFamily:'Cairo',color:p.bg9, fontWeight:FontWeight.bold,fontSize:20),
        titleMedium:   TextStyle(fontFamily:'Cairo',color:p.bg9, fontWeight:FontWeight.w600,fontSize:16),
        titleSmall:    TextStyle(fontFamily:'Cairo',color:p.bg8, fontWeight:FontWeight.w600,fontSize:14),
        bodyLarge:     TextStyle(fontFamily:'Cairo',color:p.bg8, fontSize:16),
        bodyMedium:    TextStyle(fontFamily:'Cairo',color:p.bg7, fontSize:14),
        bodySmall:     TextStyle(fontFamily:'Cairo',color:p.bg6, fontSize:12),
        labelLarge:    TextStyle(fontFamily:'Cairo',color:p.bg8, fontWeight:FontWeight.w600,fontSize:14),
        labelMedium:   TextStyle(fontFamily:'Cairo',color:p.bg7, fontWeight:FontWeight.w500,fontSize:12),
        labelSmall:    TextStyle(fontFamily:'Cairo',color:p.bg6, fontSize:10),
      ),
    );
  }

  static ThemeData get darkTheme =>
      buildTheme(const AppThemeConfig(variant: AppThemeVariant.cyan, brightness: Brightness.dark));
}

// ══════════════════════════════════════════════════════════════════════════════
// THEME METADATA for picker
// ══════════════════════════════════════════════════════════════════════════════

class AppThemeInfo {
  final AppThemeVariant variant;
  final String nameAr;
  final String nameEn;
  final Color previewAccent;
  final Color previewBgDark;
  final Color previewBgLight;
  final bool darkOnly;  // if true, dark toggle is disabled

  const AppThemeInfo({
    required this.variant,
    required this.nameAr,
    required this.nameEn,
    required this.previewAccent,
    required this.previewBgDark,
    required this.previewBgLight,
    this.darkOnly = false,
  });
}

const List<AppThemeInfo> kAppThemes = [
  AppThemeInfo(
    variant: AppThemeVariant.cyan,
    nameAr: 'سماوي', nameEn: 'Cyan',
    previewAccent: Color(0xFF00BCD4),
    previewBgDark: Color(0xFF1E293B), previewBgLight: Color(0xFFF0F4F8),
  ),
  AppThemeInfo(
    variant: AppThemeVariant.purple,
    nameAr: 'بنفسجي', nameEn: 'Purple',
    previewAccent: Color(0xFF8B5CF6),
    previewBgDark: Color(0xFF1C1834), previewBgLight: Color(0xFFF5F0FF),
  ),
  AppThemeInfo(
    variant: AppThemeVariant.green,
    nameAr: 'زمردي', nameEn: 'Emerald',
    previewAccent: Color(0xFF10B981),
    previewBgDark: Color(0xFF162820), previewBgLight: Color(0xFFEEFAF4),
  ),
  AppThemeInfo(
    variant: AppThemeVariant.white,
    nameAr: 'أبيض', nameEn: 'White',
    previewAccent: Color(0xFF2563EB),
    previewBgDark: Color(0xFFF8F9FA), previewBgLight: Color(0xFFF8F9FA),
    darkOnly: true, // white = always light
  ),
];

// ══════════════════════════════════════════════════════════════════════════════
// THEME-AWARE HELPER EXTENSIONS
// ══════════════════════════════════════════════════════════════════════════════

/// Use these in widgets instead of hardcoded AppColors.slate*
extension ThemeColors on ColorScheme {
  // Maps to bg palette:
  Color get cardBg    => surfaceContainer;          // bg2 — card background
  Color get appBarBg  => surfaceContainerLow;       // bg1 — appbar
  Color get scaffoldBg=> surface;                   // bg0 — scaffold
  Color get border    => outlineVariant;             // bg3 — borders
  Color get dividerC  => outline;                   // bg4 — dividers
  Color get hintText  => onSurface.withValues(alpha:0.38);
  Color get subtleText=> onSurface.withValues(alpha:0.55);
  Color get bodyText  => onSurface.withValues(alpha:0.75);
  Color get headText  => onSurface;
}

// ══════════════════════════════════════════════════════════════════════════════
// REUSABLE DECORATIONS — now fully theme-aware via BuildContext
// ══════════════════════════════════════════════════════════════════════════════

class AppDecorations {
  /// Theme-aware card decoration
  static BoxDecoration cardOf(BuildContext context, {double radius = 16}) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return BoxDecoration(
      color: cs.cardBg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: cs.border),
      boxShadow: isDark ? null : [
        BoxShadow(color: Colors.black.withValues(alpha:0.06), blurRadius: 8, offset: const Offset(0,2)),
      ],
    );
  }

  /// Theme-aware hero banner (adapts gradient to accent color)
  static BoxDecoration heroBannerOf(BuildContext context, {double radius = 20}) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        colors: isDark
            ? [cs.primaryContainer, cs.primary.withValues(alpha:0.7)]
            : [cs.primary, cs.primary.withValues(alpha:0.75)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: cs.primary.withValues(alpha:0.3),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  /// Status badge
  static BoxDecoration statusBadge(Color color) => BoxDecoration(
    color: color.withValues(alpha:0.12),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: color.withValues(alpha:0.3)),
  );

  /// Legacy static (uses default dark-cyan palette, for screens not yet migrated)
  static BoxDecoration card({Color? color, double radius = 16}) => BoxDecoration(
    color: color ?? AppColors.slate800,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.slate700),
  );

  static BoxDecoration glowCard({double radius = 16}) => BoxDecoration(
    color: AppColors.slate800,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.cyan900, width: 1.5),
    boxShadow: [BoxShadow(color: AppColors.cyan500.withValues(alpha:0.06),blurRadius:16,spreadRadius:2)],
  );

  static BoxDecoration heroBanner({double radius = 20}) => BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFF0E4A5C), Color(0xFF006064)],
      begin: Alignment.topLeft, end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [BoxShadow(color:AppColors.cyan800.withValues(alpha:0.3),blurRadius:20,offset:const Offset(0,6))],
  );

  static BoxDecoration panel({double radius = 14}) => BoxDecoration(
    color: AppColors.slate800,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.slate700),
    boxShadow: [BoxShadow(color:Colors.black.withValues(alpha:0.2),blurRadius:8,offset:const Offset(0,2))],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// STATUS COLOR HELPERS
// ══════════════════════════════════════════════════════════════════════════════

class AppStatusColors {
  static Color forProjectStatus(String status) {
    switch (status) {
      case 'active':    return AppColors.success;
      case 'completed': return AppColors.cyan500;
      case 'suspended': return AppColors.warning;
      case 'cancelled': return AppColors.error;
      default:          return AppColors.slate400;
    }
  }
  static String labelForProjectStatus(String status) {
    switch (status) {
      case 'active':    return 'Active';
      case 'completed': return 'Completed';
      case 'suspended': return 'Suspended';
      case 'cancelled': return 'Cancelled';
      default:          return status;
    }
  }
  static Color forTaskStatus(String status) {
    switch (status) {
      case 'not_started':        return AppColors.slate400;
      case 'in_progress':        return AppColors.info;
      case 'team_leader_review': return AppColors.warning;
      case 'qc_review':          return AppColors.cyan500;
      case 'client_review':      return Colors.purple;
      case 'completed':          return AppColors.success;
      case 'rejected':           return AppColors.error;
      default:                   return AppColors.slate400;
    }
  }
  static Color forRole(String role) {
    switch (role) {
      case 'admin':          return AppColors.cyan500;
      case 'engineer':       return AppColors.info;
      case 'team_leader':    return AppColors.success;
      case 'reviewer':       return Colors.indigo;
      case 'management':     return Colors.purple;
      case 'administration': return AppColors.slate400;
      case 'dc':             return AppColors.warning;
      case 'client':         return AppColors.warning;
      default:               return AppColors.slate400;
    }
  }
}
