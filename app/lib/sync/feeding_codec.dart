import '../models/feeding.dart';

String apiTypeFor(FeedingType type) => switch (type) {
      FeedingType.breast => 'breast',
      FeedingType.bottle => 'formula',
      FeedingType.breastMilk => 'breast_milk',
    };

FeedingType feedingTypeFromApi(String type) => switch (type) {
      'formula' || 'bottle' => FeedingType.bottle,
      'breast_milk' => FeedingType.breastMilk,
      _ => FeedingType.breast,
    };

Map<String, dynamic> feedingToApi(Feeding feeding) {
  final offset = feeding.utcOffsetMin ?? feeding.start.timeZoneOffset.inMinutes;
  return {
    'type': apiTypeFor(feeding.type),
    'start_utc': feeding.start.toUtc().toIso8601String(),
    'end_utc': feeding.end.toUtc().toIso8601String(),
    'utc_offset_min': offset,
    'left_ms': feeding.leftDuration.inMilliseconds,
    'right_ms': feeding.rightDuration.inMilliseconds,
    'end_side': feeding.endSide?.name,
    'amount_ml': feeding.amountMl,
    'notes': feeding.notes,
    'updated_at': (feeding.updatedAt ?? feeding.end).toUtc().toIso8601String(),
  };
}

Feeding feedingFromApi(Map<String, dynamic> json) {
  final offset = (json['utc_offset_min'] as num?)?.toInt() ?? 0;
  DateTime local(String raw) {
    final utc = DateTime.parse(raw).toUtc();
    return DateTime.fromMillisecondsSinceEpoch(
      utc.millisecondsSinceEpoch + offset * 60000,
      isUtc: false,
    );
  }

  final type = feedingTypeFromApi(json['type'] as String);
  final endSide = json['end_side'] as String?;
  return Feeding(
    id: json['id'] as String,
    type: type,
    start: local(json['start_utc'] as String),
    end: local(json['end_utc'] as String),
    leftDuration: Duration(milliseconds: (json['left_ms'] as num?)?.toInt() ?? 0),
    rightDuration: Duration(milliseconds: (json['right_ms'] as num?)?.toInt() ?? 0),
    endSide: endSide == null ? null : BreastSide.values.byName(endSide),
    amountMl: (json['amount_ml'] as num?)?.toInt() ?? 0,
    notes: json['notes'] as String? ?? '',
    updatedAt: json['updated_at'] == null ? null : DateTime.parse(json['updated_at'] as String),
    utcOffsetMin: offset,
  );
}

String amountBucket(int ml) {
  if (ml < 30) return '0-30 ml';
  if (ml < 60) return '30-60 ml';
  if (ml < 90) return '60-90 ml';
  if (ml < 120) return '90-120 ml';
  if (ml < 180) return '120-180 ml';
  return '180+ ml';
}

String durationBucket(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 5) return '0-5 min';
  if (minutes < 10) return '5-10 min';
  if (minutes < 20) return '10-20 min';
  if (minutes < 30) return '20-30 min';
  return '30+ min';
}
