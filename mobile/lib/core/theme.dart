import 'package:flutter/material.dart';

/// Design tokens from `brand/README.md` (ModaHouse design system).
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.card,
    required this.text,
    required this.muted,
    required this.border,
    required this.brandHover,
    required this.success,
    required this.tint,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color card;
  final Color text;
  final Color muted;
  final Color border;
  final Color brandHover;
  final Color success;

  /// Very light brand-tinted background (info boxes, unread rows).
  final Color tint;

  /// Brand red: logo, primary buttons, prices, active icons.
  static const accent = Color(0xFFD7263D);

  /// Brand red on dark backgrounds.
  static const accentDark = Color(0xFFE8455A);

  /// Logo letters and headings (light mode text).
  static const ink = Color(0xFF262B2F);
  static const accentHover = Color(0xFFB01E31);
  static const onAccent = Colors.white;
  static const danger = Color(0xFFD7263D);
  static const errorToast = Color(0xFFB01E31);

  /// Stars and the 1st place.
  static const gold = Color(0xFFF5B400);
  static const silver = Color(0xFFA7ADB7);
  static const bronze = Color(0xFFCD7F32);
  static const successLight = Color(0xFF1E8E3E);

  /// Instagram story ring gradient.
  static const storyGradient = [
    Color(0xFFFEDA75),
    Color(0xFFFA7E1E),
    Color(0xFFD62976),
    Color(0xFF962FBF),
    Color(0xFF4F5BD5),
  ];

  static const radius = 16.0;
  static const cardRadius = 22.0;
  static const gutter = 16.0;

  static const light = AppPalette(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFEFEFEF),
    surface2: Color(0xFFE2E2E2),
    card: Color(0xFFFFFFFF),
    text: Color(0xFF262B2F),
    muted: Color(0xFF767676),
    border: Color(0xFFE5E5E5),
    brandHover: Color(0xFFB01E31),
    success: Color(0xFF1E8E3E),
    tint: Color(0xFFFDF0F2),
  );

  static const dark = AppPalette(
    bg: Color(0xFF111111),
    surface: Color(0xFF262626),
    surface2: Color(0xFF333333),
    card: Color(0xFF1A1A1A),
    text: Color(0xFFF5F5F5),
    muted: Color(0xFFA8A8A8),
    border: Color(0xFF333333),
    brandHover: Color(0xFFFF5A6E),
    success: Color(0xFF4CC26A),
    tint: Color(0xFF2A1418),
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? light;

  @override
  AppPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? card,
    Color? text,
    Color? muted,
    Color? border,
    Color? brandHover,
    Color? success,
    Color? tint,
  }) => AppPalette(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surface2: surface2 ?? this.surface2,
    card: card ?? this.card,
    text: text ?? this.text,
    muted: muted ?? this.muted,
    border: border ?? this.border,
    brandHover: brandHover ?? this.brandHover,
    success: success ?? this.success,
    tint: tint ?? this.tint,
  );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      card: Color.lerp(card, other.card, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      brandHover: Color.lerp(brandHover, other.brandHover, t)!,
      success: Color.lerp(success, other.success, t)!,
      tint: Color.lerp(tint, other.tint, t)!,
    );
  }
}

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.light ? AppPalette.light : AppPalette.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: brightness == Brightness.light
        ? AppPalette.accent
        : AppPalette.accentDark,
    onPrimary: AppPalette.onAccent,
    secondary: p.text,
    onSecondary: p.bg,
    error: AppPalette.danger,
    onError: Colors.white,
    surface: p.bg,
    onSurface: p.text,
    onSurfaceVariant: p.muted,
    surfaceContainerLowest: p.bg,
    surfaceContainerLow: p.card,
    surfaceContainer: p.card,
    surfaceContainerHigh: p.surface,
    surfaceContainerHighest: p.surface,
    outline: p.border,
    outlineVariant: p.border,
  );

  const pill = StadiumBorder();
  const btnText = TextStyle(fontWeight: FontWeight.w700, fontSize: 15);
  const btnSize = Size(64, 44);
  const btnPadding = EdgeInsets.symmetric(horizontal: 18);

  OutlineInputBorder field(Color c, [double w = 1.5]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppPalette.radius),
    borderSide: BorderSide(color: c, width: w),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    dividerColor: p.border,
    extensions: [p],
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: p.text,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppPalette.accent,
        foregroundColor: AppPalette.onAccent,
        disabledBackgroundColor: AppPalette.accent.withValues(alpha: 0.45),
        disabledForegroundColor: Colors.white70,
        shape: pill,
        minimumSize: btnSize,
        padding: btnPadding,
        textStyle: btnText,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.surface,
        foregroundColor: p.text,
        elevation: 0,
        shape: pill,
        minimumSize: btnSize,
        padding: btnPadding,
        textStyle: btnText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        side: BorderSide(color: p.border, width: 2),
        shape: pill,
        minimumSize: btnSize,
        padding: btnPadding,
        textStyle: btnText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppPalette.accent,
        shape: pill,
        textStyle: btnText,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: p.text),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.bg,
      prefixIconColor: p.muted,
      suffixIconColor: p.muted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: field(p.border),
      enabledBorder: field(p.border),
      focusedBorder: field(AppPalette.accent, 2),
      errorBorder: field(AppPalette.danger),
      focusedErrorBorder: field(AppPalette.danger),
      disabledBorder: field(p.border.withValues(alpha: 0.5)),
      labelStyle: TextStyle(color: p.muted),
      floatingLabelStyle: const TextStyle(
        color: AppPalette.accent,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(color: p.muted),
      helperStyle: TextStyle(color: p.muted, fontSize: 12),
      helperMaxLines: 2,
      errorMaxLines: 3,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppPalette.accent,
      selectionColor: AppPalette.accent.withValues(alpha: 0.3),
      selectionHandleColor: AppPalette.accent,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppPalette.accent,
      linearTrackColor: p.surface2,
      circularTrackColor: Colors.transparent,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppPalette.accent : null,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.text,
      contentTextStyle: TextStyle(
        color: p.bg,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppPalette.radius),
      ),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: TextStyle(
        color: p.text,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: p.card,
      showDragHandle: true,
      dragHandleColor: p.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppPalette.radius),
      ),
      textStyle: TextStyle(
        color: p.text,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11.5,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          color: s.contains(WidgetState.selected) ? AppPalette.accent : p.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 26,
          color: s.contains(WidgetState.selected) ? AppPalette.accent : p.text,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.text,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: TextStyle(color: p.text, fontWeight: FontWeight.w600),
      secondaryLabelStyle: TextStyle(color: p.bg, fontWeight: FontWeight.w700),
      checkmarkColor: p.bg,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.text,
      unselectedLabelColor: p.muted,
      indicatorColor: p.text,
      dividerColor: p.border,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    ),
    dividerTheme: DividerThemeData(color: p.border, space: 1, thickness: 1),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(p.card),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppPalette.radius),
          ),
        ),
      ),
    ),
  );
}
