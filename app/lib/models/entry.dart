/// The kinds of thing a parent can log. Breastfeeding and the two bottle
/// kinds are feeds; the rest are logged alongside them.
enum EntryType {
  breast('Breastfeeding', 'Breastfeeding'),
  bottle('Formula (bottle)', 'Formula'),
  breastMilk('Breast milk (bottle)', 'Breast milk'),
  pump('Pumping', 'Pumped'),
  diaper('Diaper', 'Diaper'),
  routine('Routine', 'Routine'),
  other('Other', 'Other');

  const EntryType(this.label, this.shortLabel);

  final String label;
  final String shortLabel;

  bool get isFeed => this == breast || this == bottle || this == breastMilk;
  bool get isBottle => this == bottle || this == breastMilk;
}

enum BreastSide { left, right }

enum DiaperKind {
  wet('Wet'),
  dirty('Dirty'),
  both('Wet and dirty'),
  dry('Dry');

  const DiaperKind(this.label);

  final String label;
}

class Entry {
  Entry({
    required this.id,
    required this.type,
    required this.start,
    required this.end,
    this.leftDuration = Duration.zero,
    this.rightDuration = Duration.zero,
    this.endSide,
    this.amountMl = 0,
    this.leftMl = 0,
    this.rightMl = 0,
    this.diaper,
    this.rash = false,
    this.title = '',
    this.value = '',
    this.unit = '',
    this.notes = '',
    this.updatedAt,
    this.utcOffsetMin,
  });

  final String id;
  final EntryType type;
  final DateTime start;

  /// The same as [start] for things logged at one moment (diapers, routines,
  /// measurements, bottles without a duration).
  final DateTime end;

  /// Breastfeeding.
  final Duration leftDuration;
  final Duration rightDuration;
  final BreastSide? endSide;

  /// Bottles, and the total pumped.
  final int amountMl;

  /// Pumping, when logged per side. [amountMl] is then their sum.
  final int leftMl;
  final int rightMl;

  /// Diapers.
  final DiaperKind? diaper;
  final bool rash;

  /// Routines and Other: what was logged ("Bath", "Weight", a custom name).
  final String title;

  /// Other: the reading and its unit ("4.87" "kg", "Hepatitis B" "").
  final String value;
  final String unit;

  final String notes;

  /// Last edit, in UTC when set by the store. Used for last-write-wins sync.
  final DateTime? updatedAt;

  /// Device UTC offset, in minutes, at the moment the entry was saved.
  final int? utcOffsetMin;

  Entry copyWith({
    DateTime? start,
    DateTime? end,
    DateTime? updatedAt,
    int? utcOffsetMin,
  }) =>
      Entry(
        id: id,
        type: type,
        start: start ?? this.start,
        end: end ?? this.end,
        leftDuration: leftDuration,
        rightDuration: rightDuration,
        endSide: endSide,
        amountMl: amountMl,
        leftMl: leftMl,
        rightMl: rightMl,
        diaper: diaper,
        rash: rash,
        title: title,
        value: value,
        unit: unit,
        notes: notes,
        updatedAt: updatedAt ?? this.updatedAt,
        utcOffsetMin: utcOffsetMin ?? this.utcOffsetMin,
      );

  bool get isFeed => type.isFeed;
  bool get isBottle => type.isBottle;

  /// Time spent breastfeeding. Uses the per-side timers when they were used,
  /// otherwise falls back to the start/end window.
  Duration get breastDuration {
    if (type != EntryType.breast) return Duration.zero;
    final sides = leftDuration + rightDuration;
    if (sides > Duration.zero) return sides;
    return _window;
  }

  Duration get pumpDuration => type == EntryType.pump ? _window : Duration.zero;

  Duration get _window {
    final window = end.difference(start);
    return window.isNegative ? Duration.zero : window;
  }

  bool get wet => diaper == DiaperKind.wet || diaper == DiaperKind.both;
  bool get dirty => diaper == DiaperKind.dirty || diaper == DiaperKind.both;

  /// The reading as a number, accepting a decimal comma. Null when it is text.
  double? get numericValue => double.tryParse(value.trim().replaceAll(',', '.'));

  /// What the timeline shows as the entry's name.
  String get heading => switch (type) {
        EntryType.routine || EntryType.other => title.isEmpty ? type.label : title,
        _ => type.label,
      };

  /// The line under the heading, e.g. "11 m · R 11 m" or "100 ml · L 50 ml · R 50 ml · 18 m".
  String get detail {
    String sides(String l, String r) => [
          if (l.isNotEmpty) 'L $l',
          if (r.isNotEmpty) 'R $r',
        ].join(' · ');
    String mins(Duration d) => d == Duration.zero ? '' : formatDuration(d);
    return switch (type) {
      EntryType.breast => [
          formatDuration(breastDuration),
          sides(mins(leftDuration), mins(rightDuration)),
        ].where((s) => s.isNotEmpty).join(' · '),
      EntryType.bottle || EntryType.breastMilk => '$amountMl ml',
      EntryType.pump => [
          if (amountMl > 0) '$amountMl ml',
          sides(leftMl > 0 ? '$leftMl ml' : '', rightMl > 0 ? '$rightMl ml' : ''),
          mins(pumpDuration),
        ].where((s) => s.isNotEmpty).join(' · '),
      EntryType.diaper => [diaper?.label ?? '', if (rash) 'Rash'].where((s) => s.isNotEmpty).join(' · '),
      EntryType.routine => '',
      EntryType.other => [value, unit].where((s) => s.isNotEmpty).join(' '),
    };
  }
}

/// "1 h 5 m", "11 m", "0 m".
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '$m m';
  if (m == 0) return '$h h';
  return '$h h $m m';
}
