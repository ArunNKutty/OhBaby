import 'package:flutter/material.dart';

import 'models/entry.dart';

/// One tinted colour pair: the circle or header behind an icon, the icon on
/// it, and a deeper line colour for sparklines and charts.
class Tint {
  const Tint(this.bg, this.fg, this.line);

  final Color bg;
  final Color fg;
  final Color line;
}

/// The colour groups entries are drawn in.
enum TintKind { feed, pump, diaper, routine, other }

TintKind tintKindOf(EntryType type) => switch (type) {
      EntryType.breast || EntryType.bottle || EntryType.breastMilk => TintKind.feed,
      EntryType.pump => TintKind.pump,
      EntryType.diaper => TintKind.diaper,
      EntryType.routine => TintKind.routine,
      EntryType.other => TintKind.other,
    };

/// The app's colours for one brightness. Read with `context.colors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.card,
    required this.ink,
    required this.muted,
    required this.pill,
    required this.divider,
    required this.primary,
    required this.onPrimary,
    required this.selected,
    required this.tints,
  });

  final Color bg;
  final Color card;
  final Color ink;
  final Color muted;

  /// Summary pills, round icon buttons and other soft fills on a card.
  final Color pill;
  final Color divider;

  /// Filled buttons and the add button.
  final Color primary;
  final Color onPrimary;

  /// The chosen tab, segment or chip.
  final Color selected;
  final Map<TintKind, Tint> tints;

  Tint tint(TintKind kind) => tints[kind]!;
  Tint tintFor(EntryType type) => tint(tintKindOf(type));

  static const light = AppColors(
    bg: Color(0xFFE9E7E1),
    card: Colors.white,
    ink: Color(0xFF263241),
    muted: Color(0xFF5E6873),
    pill: Color(0xFFEFEDE8),
    divider: Color(0xFFE2E0DA),
    primary: Color(0xFF3D5A73),
    onPrimary: Colors.white,
    selected: Color(0xFFB9CCD9),
    tints: {
      TintKind.feed: Tint(Color(0xFFEACFC0), Color(0xFF5E3A2C), Color(0xFF8A6150)),
      TintKind.pump: Tint(Color(0xFFCCDCE3), Color(0xFF2F4A5C), Color(0xFF4F6F86)),
      TintKind.diaper: Tint(Color(0xFFCFE0DA), Color(0xFF2F5D50), Color(0xFF4F8A73)),
      TintKind.routine: Tint(Color(0xFFDCD6EA), Color(0xFF4A3F6B), Color(0xFF6E5FA0)),
      TintKind.other: Tint(Color(0xFFEFEDE8), Color(0xFF263241), Color(0xFF3D5A73)),
    },
  );

  static const dark = AppColors(
    bg: Color(0xFF15191E),
    card: Color(0xFF1F262D),
    ink: Color(0xFFE8ECEF),
    muted: Color(0xFFA3ADB7),
    pill: Color(0xFF29313A),
    divider: Color(0xFF2E3740),
    primary: Color(0xFFB9CCD9),
    onPrimary: Color(0xFF15191E),
    selected: Color(0xFF3D5A73),
    tints: {
      TintKind.feed: Tint(Color(0xFF5A4237), Color(0xFFF2D6C8), Color(0xFFD9A58C)),
      TintKind.pump: Tint(Color(0xFF34495A), Color(0xFFD3E3EC), Color(0xFF8FB2CB)),
      TintKind.diaper: Tint(Color(0xFF30473F), Color(0xFFD2E6DE), Color(0xFF86C2A9)),
      TintKind.routine: Tint(Color(0xFF433B5C), Color(0xFFE3DDF2), Color(0xFFB2A5DD)),
      TintKind.other: Tint(Color(0xFF29313A), Color(0xFFE8ECEF), Color(0xFFB9CCD9)),
    },
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) => t < 0.5 || other == null ? this : other;
}

extension AppColorsOf on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

/// The icon for each kind of entry.
IconData iconFor(EntryType type) => switch (type) {
      EntryType.breast => Icons.favorite,
      EntryType.bottle => Icons.local_drink,
      EntryType.breastMilk => Icons.water_drop,
      EntryType.pump => Icons.opacity,
      EntryType.diaper => Icons.baby_changing_station,
      EntryType.routine => Icons.light_mode_outlined,
      EntryType.other => Icons.edit_note,
    };

/// Headings and the interface use Heros (a Helvetica-style face); the
/// "Oh baby baby!" wordmark keeps Nunito.
const uiFont = 'Heros';
const wordmarkFont = 'Nunito';

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: c.primary,
    brightness: brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    surface: c.card,
    onSurface: c.ink,
  );
  final base = brightness == Brightness.dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  final text = base.textTheme.apply(fontFamily: uiFont, bodyColor: c.ink, displayColor: c.ink);
  final pill = StadiumBorder(side: BorderSide(color: c.ink.withValues(alpha: 0.85)));
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    dividerColor: c.divider,
    extensions: [c],
    textTheme: text.copyWith(
      headlineLarge: text.headlineLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 30),
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 26),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 22),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 20),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 16),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, color: c.muted),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
    ),
    dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: uiFont, fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        side: BorderSide(color: c.ink.withValues(alpha: 0.85)),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: uiFont, fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.ink,
        textStyle: const TextStyle(fontFamily: uiFont, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.card,
      selectedColor: c.selected,
      shape: pill,
      labelStyle: TextStyle(fontFamily: uiFont, color: c.ink, fontWeight: FontWeight.w700, fontSize: 14),
      side: BorderSide(color: c.ink.withValues(alpha: 0.85)),
      showCheckmark: false,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.card,
      indicatorColor: c.selected,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontFamily: uiFont, fontSize: 13, color: c.ink)),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: c.ink)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: TextStyle(fontFamily: uiFont, color: c.bg),
      actionTextColor: c.selected,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onPrimary : c.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : c.pill),
    ),
    dialogTheme: DialogThemeData(backgroundColor: c.card, surfaceTintColor: Colors.transparent),
    datePickerTheme: DatePickerThemeData(backgroundColor: c.card, surfaceTintColor: Colors.transparent),
    timePickerTheme: TimePickerThemeData(backgroundColor: c.card),
  );
}
