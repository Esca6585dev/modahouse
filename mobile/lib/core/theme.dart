import 'package:flutter/material.dart';

/// Design tokens mirrored from `frontend/app/globals.css`.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.card,
    required this.text,
    required this.muted,
    required this.border,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color card;
  final Color text;
  final Color muted;
  final Color border;

  static const accent = Color(0xFFD6336C);
  static const accentHover = Color(0xFFB8285A);
  static const onAccent = Colors.white;
  static const danger = Color(0xFFE03131);
  static const errorToast = Color(0xFFC92A2A);
  static const radius = 16.0;
  static const gutter = 16.0;

  static const light = AppPalette(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFEFEFEF),
    surface2: Color(0xFFE2E2E2),
    card: Color(0xFFFFFFFF),
    text: Color(0xFF111111),
    muted: Color(0xFF5F5F5F),
    border: Color(0xFFDDDDDD),
  );

  static const dark = AppPalette(
    bg: Color(0xFF121212),
    surface: Color(0xFF262626),
    surface2: Color(0xFF333333),
    card: Color(0xFF1C1C1C),
    text: Color(0xFFF2F2F2),
    muted: Color(0xFFA8A8A8),
    border: Color(0xFF383838),
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
  }) => AppPalette(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surface2: surface2 ?? this.surface2,
    card: card ?? this.card,
    text: text ?? this.text,
    muted: muted ?? this.muted,
    border: border ?? this.border,
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
    );
  }
}

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.light ? AppPalette.light : AppPalette.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: AppPalette.accent,
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

  OutlineInputBorder field(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppPalette.radius),
    borderSide: BorderSide(color: c, width: 2),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: field(p.border),
      enabledBorder: field(p.border),
      focusedBorder: field(AppPalette.accent),
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
      indicatorColor: p.surface,
      height: 66,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11.5,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          color: s.contains(WidgetState.selected) ? p.text : p.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? p.text : p.muted,
        ),
      ),
    ),
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
