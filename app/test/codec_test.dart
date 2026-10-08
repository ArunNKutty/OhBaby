import 'package:baby_feed_tracker/models/feeding.dart';
import 'package:baby_feed_tracker/sync/feeding_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formula bottles map to the API type and back', () {
    final feeding = Feeding(
      id: '44444444-4444-4444-8444-444444444444',
      type: FeedingType.bottle,
      start: DateTime.utc(2026, 10, 5, 9),
      end: DateTime.utc(2026, 10, 5, 9, 20),
      amountMl: 90,
      updatedAt: DateTime.utc(2026, 10, 5, 9, 20),
      utcOffsetMin: 0,
    );
    final json = feedingToApi(feeding);
    expect(json['type'], 'formula');
    expect(amountBucket(90), '90-120 ml');
    expect(durationBucket(const Duration(minutes: 12)), '10-20 min');

    final back = feedingFromApi({
      'id': feeding.id,
      'type': 'breast_milk',
      'start_utc': '2026-10-05T09:00:00Z',
      'end_utc': '2026-10-05T09:20:00Z',
      'utc_offset_min': 0,
      'amount_ml': 60,
      'updated_at': '2026-10-05T09:20:00Z',
    });
    expect(back.type, FeedingType.breastMilk);
    expect(back.amountMl, 60);
  });
}
