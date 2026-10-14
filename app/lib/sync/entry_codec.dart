import '../models/entry.dart';

String apiTypeFor(EntryType type) => switch (type) {
      EntryType.breast => 'breast',
      EntryType.bottle => 'formula',
      EntryType.breastMilk => 'breast_milk',
      EntryType.pump => 'pump',
      EntryType.diaper => 'diaper',
      EntryType.routine => 'routine',
      EntryType.other => 'other',
    };

/// Null for a type this version of the app does not know, so it is skipped
/// instead of shown as something else.
EntryType? entryTypeFromApi(String type) => switch (type) {
      'breast' => EntryType.breast,
      'formula' => EntryType.bottle,
      'breast_milk' => EntryType.breastMilk,
      'pump' => EntryType.pump,
      'diaper' => EntryType.diaper,
      'routine' => EntryType.routine,
      'other' => EntryType.other,
      _ => null,
    };

Map<String, dynamic> entryToApi(Entry e) {
  final offset = e.utcOffsetMin ?? e.start.timeZoneOffset.inMinutes;
  return {
    'type': apiTypeFor(e.type),
    'start_utc': e.start.toUtc().toIso8601String(),
    'end_utc': e.end.toUtc().toIso8601String(),
    'utc_offset_min': offset,
    'left_ms': e.leftDuration.inMilliseconds,
    'right_ms': e.rightDuration.inMilliseconds,
    'end_side': e.endSide?.name,
    'amount_ml': e.amountMl,
    'left_ml': e.leftMl,
    'right_ml': e.rightMl,
    'diaper': e.diaper?.name,
    'rash': e.rash,
    'title': e.title,
    'value': e.value,
    'unit': e.unit,
    'notes': e.notes,
    'updated_at': (e.updatedAt ?? e.end).toUtc().toIso8601String(),
  };
}

/// Null when the server sends a type this app does not know.
Entry? entryFromApi(Map<String, dynamic> json) {
  final type = entryTypeFromApi(json['type'] as String? ?? '');
  if (type == null) return null;
  final offset = (json['utc_offset_min'] as num?)?.toInt() ?? 0;
  DateTime local(String raw) {
    final utc = DateTime.parse(raw).toUtc();
    return DateTime.fromMillisecondsSinceEpoch(utc.millisecondsSinceEpoch + offset * 60000);
  }

  int n(String key) => (json[key] as num?)?.toInt() ?? 0;
  String s(String key) => json[key] as String? ?? '';
  final endSide = json['end_side'] as String?;
  final diaper = json['diaper'] as String?;
  return Entry(
    id: json['id'] as String,
    type: type,
    start: local(json['start_utc'] as String),
    end: local(json['end_utc'] as String),
    leftDuration: Duration(milliseconds: n('left_ms')),
    rightDuration: Duration(milliseconds: n('right_ms')),
    endSide: endSide == null ? null : BreastSide.values.asNameMap()[endSide],
    amountMl: n('amount_ml'),
    leftMl: n('left_ml'),
    rightMl: n('right_ml'),
    diaper: diaper == null ? null : DiaperKind.values.asNameMap()[diaper],
    rash: json['rash'] == true,
    title: s('title'),
    value: s('value'),
    unit: s('unit'),
    notes: s('notes'),
    updatedAt: json['updated_at'] == null ? null : DateTime.parse(json['updated_at'] as String),
    utcOffsetMin: offset,
  );
}
