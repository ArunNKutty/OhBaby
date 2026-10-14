import 'dart:typed_data';

import 'package:baby_feed_tracker/data/feeding_store.dart';
import 'package:baby_feed_tracker/data/memory_repository.dart';
import 'package:baby_feed_tracker/models/entry.dart';
import 'package:baby_feed_tracker/models/live_timer.dart';
import 'package:baby_feed_tracker/models/trends.dart';
import 'package:baby_feed_tracker/screens/profile_screen.dart';
import 'package:baby_feed_tracker/sync/entry_codec.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('codec', () {
    final at = DateTime(2026, 10, 13, 9, 15);
    final samples = [
      entry(EntryType.breast, at, left: const Duration(minutes: 9), right: const Duration(minutes: 4), side: BreastSide.right),
      entry(EntryType.bottle, at, ml: 150),
      entry(EntryType.breastMilk, at, ml: 90),
      Entry(id: 'p', type: EntryType.pump, start: at, end: at.add(const Duration(minutes: 18)), amountMl: 100, leftMl: 50, rightMl: 50),
      Entry(id: 'd', type: EntryType.diaper, start: at, end: at, diaper: DiaperKind.both, rash: true),
      entry(EntryType.routine, at, title: 'Tummy time'),
      Entry(id: 'o', type: EntryType.other, start: at, end: at, title: 'Weight', value: '4.87', unit: 'kg', notes: 'after bath'),
    ];
    for (final e in samples) {
      test('${e.type.name} round-trips', () {
        final json = entryToApi(e)..['id'] = e.id;
        final back = entryFromApi(json)!;
        expect(back.type, e.type);
        expect(back.start, e.start);
        expect(back.end, e.end);
        expect(back.leftDuration, e.leftDuration);
        expect(back.rightDuration, e.rightDuration);
        expect(back.endSide, e.endSide);
        expect(back.amountMl, e.amountMl);
        expect(back.leftMl, e.leftMl);
        expect(back.rightMl, e.rightMl);
        expect(back.diaper, e.diaper);
        expect(back.rash, e.rash);
        expect(back.title, e.title);
        expect(back.value, e.value);
        expect(back.unit, e.unit);
        expect(back.notes, e.notes);
      });
    }

    test('formula is sent as formula', () {
      expect(entryToApi(samples[1])['type'], 'formula');
    });

    test('an unknown type is skipped, not shown as something else', () {
      expect(entryFromApi({'id': 'x', 'type': 'sleep', 'start_utc': '2026-10-13T09:00:00Z', 'end_utc': '2026-10-13T09:00:00Z'}), isNull);
    });
  });

  group('entry text', () {
    final at = DateTime(2026, 10, 13, 9);
    test('timeline detail lines', () {
      expect(entry(EntryType.breast, at, left: const Duration(minutes: 10), right: const Duration(minutes: 6)).detail, '16 m · L 10 m · R 6 m');
      expect(entry(EntryType.breast, at, right: const Duration(minutes: 11)).detail, '11 m · R 11 m');
      expect(
        Entry(id: 'p', type: EntryType.pump, start: at, end: at.add(const Duration(minutes: 18)), amountMl: 100, leftMl: 50, rightMl: 50).detail,
        '100 ml · L 50 ml · R 50 ml · 18 m',
      );
      expect(Entry(id: 'd', type: EntryType.diaper, start: at, end: at, diaper: DiaperKind.both).detail, 'Wet and dirty');
      expect(entry(EntryType.bottle, at, ml: 150).heading, 'Formula (bottle)');
      expect(entry(EntryType.routine, at, title: 'Bath').heading, 'Bath');
      expect(Entry(id: 'o', type: EntryType.other, start: at, end: at, title: 'Weight', value: '4.87', unit: 'kg').detail, '4.87 kg');
    });

    test('a decimal comma reads as a number', () {
      expect(Entry(id: 'o', type: EntryType.other, start: at, end: at, value: '4,87').numericValue, 4.87);
      expect(Entry(id: 'o', type: EntryType.other, start: at, end: at, value: 'Hep B').numericValue, isNull);
    });
  });

  group('trends', () {
    // Monday 5 to Sunday 11 October is last week; this week began Monday 12.
    final today = testNow;
    final thisWeek = startOfWeek(today);
    final all = [
      // Last week: 300 ml formula on two days → 600 over 7 days.
      entry(EntryType.bottle, DateTime(2026, 10, 6, 9), ml: 300),
      entry(EntryType.bottle, DateTime(2026, 10, 8, 9), ml: 300),
      // This week: Monday 280 ml. Today's 999 ml must not count yet.
      entry(EntryType.bottle, DateTime(2026, 10, 12, 9), ml: 280),
      entry(EntryType.bottle, DateTime(2026, 10, 13, 9), ml: 999),
      entry(EntryType.diaper, DateTime(2026, 10, 12, 10), diaper: DiaperKind.wet),
      entry(EntryType.routine, DateTime(2026, 10, 12, 18), title: 'Bath'),
      entry(EntryType.routine, DateTime(2026, 10, 7, 18), title: 'Bath'),
      entry(EntryType.routine, DateTime(2026, 10, 9, 18), title: 'Bath'),
      entry(EntryType.routine, DateTime(2026, 10, 9, 10), title: 'Tummy time'),
    ];

    test('the average leaves today out until it is over', () {
      expect(countedDays(thisWeek, Period.week, today), 1);
      expect(averagePerDay(all, Metric.formula, thisWeek, Period.week, today), 280);
      expect(averagePerDay(all, Metric.formula, Period.week.shift(thisWeek, -1), Period.week, today), closeTo(600 / 7, 0.01));
    });

    test('months use their own length', () {
      final sept = DateTime(2026, 9);
      expect(Period.month.endOf(sept), DateTime(2026, 10));
      expect(countedDays(sept, Period.month, today), 30);
      expect(countedDays(DateTime(2026, 2), Period.month, today), 28);
      expect(Period.month.startOf(today), DateTime(2026, 10));
    });

    test('change labels', () {
      expect(changeLabel(290, 281, Period.week), 'Up 3% on last week');
      expect(changeLabel(59, 60.2, Period.week), 'Down 2% on last week');
      expect(changeLabel(6, 6, Period.month), 'Same as last month');
      expect(changeLabel(5, 0, Period.week), 'New this week');
      expect(changeLabel(0, 0, Period.week), 'Same as last week');
    });

    test('series covers the last periods, oldest first', () {
      final s = series(all, Metric.formula, thisWeek, Period.week, 8, today);
      expect(s, hasLength(8));
      expect(s.last.start, thisWeek);
      expect(s.first.start, DateTime(2026, 8, 24));
      expect(s.last.value, 280);
    });

    test('routines this week so far against all of last week', () {
      final counts = routineCounts(all, thisWeek, Period.week);
      expect(counts.first.title, 'Bath');
      expect(counts.first.thisPeriod, 1);
      expect(counts.first.lastPeriod, 2);
      expect(counts[1].title, 'Tummy time');
      expect(counts[1].thisPeriod, 0);
    });

    test('measurements: latest reading and change since the one before', () {
      final readings = measurements([
        entry(EntryType.other, DateTime(2026, 10, 5, 9), title: 'Weight', value: '4.67', unit: 'kg'),
        entry(EntryType.other, DateTime(2026, 10, 12, 9), title: 'Weight', value: '4,87', unit: 'kg'),
        entry(EntryType.other, DateTime(2026, 10, 12, 9), title: 'Vaccine', value: 'Hepatitis B'),
        entry(EntryType.other, DateTime(2026, 10, 11, 9), title: 'Temperature', value: '36.9', unit: '°C'),
      ]);
      expect([for (final m in readings) m.title], ['Weight', 'Temperature']);
      expect(readings.first.latest.value, 4.87);
      expect(formatChange(readings.first.change!, 'kg'), '+0.2 kg');
      expect(formatChange(-0.3, '°C'), '−0.3 °C');
      expect(readings.first.previous!.at, DateTime(2026, 10, 5, 9));
    });

    test('each day, newest first, up to today', () {
      final rows = dayRows(all, thisWeek, Period.week, today);
      expect([for (final r in rows) r.day.day], [13, 12]);
      expect(rows.last.totals.formulaMl, 280);
      expect(rows.last.totals.diapers, 1);
    });
  });

  group('live timer', () {
    test('counts from the wall clock and keeps one side running', () {
      final start = DateTime(2026, 10, 13, 9);
      var t = LiveTimer(type: EntryType.breast, start: start).startSide(TimerSide.left, start);
      final later = start.add(const Duration(minutes: 7));
      expect(t.leftAt(later), const Duration(minutes: 7));
      t = t.startSide(TimerSide.right, later);
      expect(t.leftAt(later.add(const Duration(minutes: 3))), const Duration(minutes: 7));
      expect(t.rightAt(later.add(const Duration(minutes: 3))), const Duration(minutes: 3));
      expect(t.edit(TimerSide.left, const Duration(minutes: 2), later).left, const Duration(minutes: 2));
    });

    test('survives the app being closed and opened again', () async {
      final repo = MemoryFeedingRepository();
      final clock = TestClock();
      final store = FeedingStore(repository: repo)..now = () => clock.now;
      await store.load();
      await store.setLiveTimer(LiveTimer(type: EntryType.pump, start: clock.now).startSide(TimerSide.pump, clock.now));

      clock.advance(const Duration(minutes: 12));
      final reopened = FeedingStore(repository: repo)..now = () => clock.now;
      await reopened.load();
      expect(reopened.liveTimer!.leftAt(clock.now), const Duration(minutes: 12));
      expect(reopened.liveTimer!.isRunning, isTrue);
    });
  });

  group('store', () {
    test('next side, last bottle and last feeding', () async {
      final store = await newStore();
      await store.upsert(entry(EntryType.breast, DateTime(2026, 10, 13, 8), side: BreastSide.left, left: const Duration(minutes: 5)));
      await store.upsert(entry(EntryType.bottle, DateTime(2026, 10, 13, 9), ml: 150));
      await store.upsert(entry(EntryType.diaper, DateTime(2026, 10, 13, 10), diaper: DiaperKind.wet));
      expect(store.nextSide, BreastSide.right);
      expect(store.lastBottle!.amountMl, 150);
      expect(store.lastFeeding!.type, EntryType.bottle);
    });

    test('signing out keeps the appearance but forgets the photo', () async {
      final store = await newStore();
      await store.setThemeMode(ThemeMode.dark);
      await store.setBabyPhoto(Uint8List.fromList([1, 2, 3]));
      await store.signOutLocal();
      expect(store.themeMode, ThemeMode.dark);
      expect(store.babyPhoto, isNull);
      expect(store.signedIn, isFalse);
    });
  });

  test('age label', () {
    final now = DateTime(2026, 10, 13);
    expect(ageLabel(DateTime(2026, 10, 13), now), 'Born today');
    expect(ageLabel(DateTime(2026, 10, 12), now), '1 day old');
    expect(ageLabel(DateTime(2026, 9, 20), now), '3 weeks old');
    expect(ageLabel(DateTime(2026, 9, 1), now), '6 weeks old');
    expect(ageLabel(DateTime(2026, 7, 13), now), '3 months old');
    expect(ageLabel(DateTime(2024, 9, 1), now), '2 years old');
  });
}
