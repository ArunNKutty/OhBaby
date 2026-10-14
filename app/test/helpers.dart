import 'package:baby_feed_tracker/data/feeding_store.dart';
import 'package:baby_feed_tracker/models/entry.dart';
import 'package:baby_feed_tracker/sheets/entry_sheet_scaffold.dart';
import 'package:baby_feed_tracker/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tuesday 13 October 2026, 21:20: the moment every test runs at.
final testNow = DateTime(2026, 10, 13, 21, 20);

/// A clock tests can move forward.
class TestClock {
  DateTime now = testNow;

  void advance(Duration d) => now = now.add(d);
}

Future<FeedingStore> newStore({TestClock? clock, bool signedIn = true}) async {
  final store = FeedingStore();
  final c = clock ?? TestClock();
  store.now = () => c.now;
  await store.load();
  if (signedIn) {
    await store.rememberSession(accessToken: 'access', refreshToken: 'refresh', userId: 'user-1', email: 'parent@example.com');
  }
  return store;
}

Entry entry(
  EntryType type,
  DateTime start, {
  Duration left = Duration.zero,
  Duration right = Duration.zero,
  BreastSide? side,
  int ml = 0,
  DiaperKind? diaper,
  String title = '',
  String value = '',
  String unit = '',
  Duration length = Duration.zero,
}) =>
    Entry(
      id: '${type.name}-${start.toIso8601String()}-$title',
      type: type,
      start: start,
      end: start.add(length),
      leftDuration: left,
      rightDuration: right,
      endSide: side ?? (type == EntryType.breast ? BreastSide.left : null),
      amountMl: ml,
      diaper: diaper,
      title: title,
      value: value,
      unit: unit,
    );

void phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Opens [sheet] from a button, the way the app does, and returns a holder
/// for what it resolved to.
Future<List<bool>> openSheet(WidgetTester tester, Widget sheet) async {
  phoneSize(tester);
  final result = <bool>[];
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(Brightness.light),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(onPressed: () => showEntrySheet(context, sheet).then(result.add), child: const Text('open')),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}
