import 'dart:convert';

import 'package:baby_feed_tracker/data/feeding_store.dart';
import 'package:baby_feed_tracker/main.dart';
import 'package:baby_feed_tracker/models/entry.dart';
import 'package:baby_feed_tracker/screens/login_screen.dart';
import 'package:baby_feed_tracker/sync/api_client.dart';
import 'package:baby_feed_tracker/sync/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

Future<void> pumpApp(WidgetTester tester, FeedingStore store) async {
  phoneSize(tester);
  await tester.pumpWidget(BabyFeedTrackerApp(store: store, splashDuration: Duration.zero));
  await tester.pumpAndSettle();
}

/// Scrolls the quick-add row sideways until [text] shows.
Future<void> showQuickAdd(WidgetTester tester, String text) async {
  final row = find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal);
  await tester.dragUntilVisible(find.text(text), row, const Offset(-150, 0));
  await tester.pumpAndSettle();
}

/// Lets a snackbar run out by itself.
Future<void> waitOutSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Today: add a bottle from "Add an entry"', (tester) async {
    final store = await newStore();
    await pumpApp(tester, store);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Nothing logged yet today.'), findsOneWidget);

    await tester.tap(find.text('Add an entry'));
    await tester.pumpAndSettle();
    expect(find.text('What do you want to log?'), findsOneWidget);
    await tester.tap(find.text('Bottle feeding'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 12; i++) {
      await tester.tap(find.byTooltip('More'));
      await tester.pump();
    }
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.entries.single.amountMl, 120);
    expect(find.text('Formula (bottle)'), findsOneWidget);
    expect(find.text('120 ml'), findsWidgets);
    expect(find.textContaining('Last feeding'), findsOneWidget);
  });

  testWidgets('Today: quick add a diaper, then undo it', (tester) async {
    final store = await newStore();
    await pumpApp(tester, store);
    await showQuickAdd(tester, 'Wet');
    await tester.tap(find.text('Wet'));
    await tester.pumpAndSettle();
    expect(store.entries.single.diaper, DiaperKind.wet);
    expect(find.text('Logged diaper (wet)'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(store.entries, isEmpty);
  });

  testWidgets('Today: quick add repeats the last bottle', (tester) async {
    final store = await newStore();
    await store.upsert(entry(EntryType.bottle, testNow.subtract(const Duration(hours: 2)), ml: 150));
    await pumpApp(tester, store);
    expect(find.text('Next: left side'), findsOneWidget);
    await showQuickAdd(tester, 'Bottle 150 ml');
    await tester.tap(find.text('Bottle 150 ml'));
    await tester.pumpAndSettle();
    expect(store.entries.where((e) => e.amountMl == 150), hasLength(2));
  });

  testWidgets('Today: swipe to delete waits for Undo', (tester) async {
    final store = await newStore();
    await store.upsert(entry(EntryType.diaper, testNow.subtract(const Duration(hours: 1)), diaper: DiaperKind.dirty));
    await pumpApp(tester, store);

    await tester.drag(find.text('Diaper'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Entry deleted'), findsOneWidget);
    expect(store.entries, hasLength(1), reason: 'nothing is deleted until the snackbar goes');
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Diaper'), findsOneWidget);
    expect(store.entries, hasLength(1));

    await tester.drag(find.text('Diaper'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await waitOutSnackBar(tester);
    expect(store.entries, isEmpty);
    expect(store.outbox.values, contains('delete'));
  });

  testWidgets('Today: the last feeding line ignores diapers', (tester) async {
    final store = await newStore();
    await store.upsert(entry(EntryType.bottle, testNow.subtract(const Duration(hours: 2, minutes: 29)), ml: 150));
    await store.upsert(entry(EntryType.diaper, testNow.subtract(const Duration(minutes: 10)), diaper: DiaperKind.wet));
    await pumpApp(tester, store);
    expect(find.textContaining('2 h 29 m ago'), findsOneWidget);
    expect(find.textContaining('Formula 150 ml'), findsOneWidget);
  });

  testWidgets('Trends: averages, and a day opens in a drawer', (tester) async {
    final store = await newStore();
    await store.upsert(entry(EntryType.bottle, DateTime(2026, 10, 12, 9), ml: 280));
    await store.upsert(entry(EntryType.routine, DateTime(2026, 10, 12, 18), title: 'Bath'));
    await store.upsert(entry(EntryType.other, DateTime(2026, 10, 12, 9), title: 'Weight', value: '4.87', unit: 'kg'));
    await pumpApp(tester, store);
    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('280 ml'), findsOneWidget);
    expect(find.text('New this week'), findsWidgets);
    await tester.scrollUntilVisible(find.text('4.87 kg'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Bath'), findsOneWidget);
    expect(find.text('4.87 kg'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.text('This month'), findsOneWidget);

    // The "Each day" row for Monday 12 October.
    final monday = find.text('12 Oct');
    await tester.scrollUntilVisible(monday, 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(monday);
    await tester.pumpAndSettle();
    await tester.tap(monday);
    await tester.pumpAndSettle();
    // The day opens in a drawer with its timeline.
    expect(find.text('Monday 12 October'), findsOneWidget);
    expect(find.text('Formula (bottle)'), findsOneWidget);
    expect(find.text('Bath'), findsWidgets);
    await tester.ensureVisible(find.text('Open on Today to edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open on Today to edit'));
    await tester.pumpAndSettle();
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Formula (bottle)'), findsOneWidget);
  });

  testWidgets('Profile: appearance switches the theme and is kept', (tester) async {
    final store = await newStore();
    await pumpApp(tester, store);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(store.themeMode, ThemeMode.dark);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.dark);
    expect(find.text('Everything you log is saved to parent@example.com.'), findsOneWidget);
  });

  testWidgets('Profile: log out goes back to login', (tester) async {
    final store = await newStore();
    store.api = ApiClient(
      base: 'http://api.test',
      httpClient: MockClient((_) async => http.Response(jsonEncode({'configured': false, 'missing': [], 'setup': []}), 200)),
    );
    await pumpApp(tester, store);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(store.signedIn, isFalse);
  });

  test('a name or birth date change reaches the server', () async {
    final store = await newStore();
    final requests = <String>[];
    store.api = ApiClient(
      base: 'http://api.test',
      httpClient: MockClient((req) async {
        requests.add('${req.method} ${req.url.path} ${req.body}');
        if (req.method == 'GET' && req.url.path == '/v1/babies') {
          return http.Response(jsonEncode({
            'babies': [
              {'id': store.babyId, 'name': 'My baby', 'birth_date': null},
            ],
          }), 200);
        }
        if (req.url.path.endsWith('/entries')) return http.Response(jsonEncode({'entries': [], 'sync_token': 0}), 200);
        return http.Response('{}', 200);
      }),
    );
    await store.setBabyName('Ada');
    await store.setBirthDate(DateTime(2026, 9, 1));
    expect(store.babyDirty, isTrue);
    await SyncService(store).syncNow();
    final patch = requests.firstWhere((r) => r.startsWith('PATCH'));
    expect(patch, contains('"name":"Ada"'));
    expect(patch, contains('"birth_date":"2026-09-01"'));
    expect(store.babyDirty, isFalse);

    // Without a local change, the server's values win.
    requests.clear();
    await SyncService(store).syncNow();
    expect(requests.where((r) => r.startsWith('PATCH')), isEmpty);
    expect(store.babyName, 'My baby');
  });
}
