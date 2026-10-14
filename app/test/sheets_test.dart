import 'package:baby_feed_tracker/models/entry.dart';
import 'package:baby_feed_tracker/sheets/simple_sheets.dart';
import 'package:baby_feed_tracker/sheets/timer_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.text('Save'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('breastfeeding: time a side, then save it', (tester) async {
    final clock = TestClock();
    final store = await newStore(clock: clock);
    final result = await openSheet(tester, BreastfeedingSheet(store: store));

    await save(tester);
    expect(find.text('Start a timer or enter the time for a side.'), findsOneWidget);

    await tester.tap(find.text('Start left'));
    await tester.pump();
    expect(store.liveTimer?.isRunning, isTrue, reason: 'the timer is kept so it survives closing the app');
    clock.advance(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('05:00'), findsOneWidget);
    await tester.tap(find.text('Stop left'));
    await tester.pump();

    await save(tester);
    expect(result, [true]);
    final saved = store.entries.single;
    expect(saved.type, EntryType.breast);
    expect(saved.leftDuration, const Duration(minutes: 5));
    expect(saved.endSide, BreastSide.left);
    expect(saved.start, testNow);
    expect(store.liveTimer, isNull);
  });

  testWidgets('breastfeeding: typed time needs the side it ended on', (tester) async {
    final store = await newStore();
    await openSheet(tester, BreastfeedingSheet(store: store));
    await tester.tap(find.byTooltip('Enter Left time'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '7');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(find.text('Choose the side you ended on.'), findsOneWidget);
    await tester.tap(find.text('Right'));
    await save(tester);
    expect(store.entries.single.leftDuration, const Duration(minutes: 7));
    expect(store.entries.single.endSide, BreastSide.right);
  });

  testWidgets('closing a running timer asks before discarding it', (tester) async {
    final store = await newStore();
    await openSheet(tester, BreastfeedingSheet(store: store));
    await tester.tap(find.text('Start right'));
    await tester.pump();
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Discard this timer?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.liveTimer, isNull);
    expect(store.entries, isEmpty);
  });

  testWidgets('bottle: amount, kind and last amount', (tester) async {
    final store = await newStore();
    await store.upsert(entry(EntryType.bottle, testNow.subtract(const Duration(hours: 3)), ml: 150));
    await openSheet(tester, BottleSheet(store: store));
    await save(tester);
    expect(find.text('Add the amount.'), findsOneWidget);
    expect(find.text('Use last amount: 150 ml?'), findsOneWidget);
    await tester.tap(find.text('Yes'));
    await tester.pump();
    expect(find.text('150 ml'), findsOneWidget);
    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    await tester.tap(find.text('Breast milk'));
    await tester.pump();
    await save(tester);
    final saved = store.entries.firstWhere((e) => e.type == EntryType.breastMilk);
    expect(saved.amountMl, 160);
  });

  testWidgets('pumping: per side adds up', (tester) async {
    final store = await newStore();
    await openSheet(tester, PumpSheet(store: store));
    await save(tester);
    expect(find.text('Add the amount pumped or start the timer.'), findsOneWidget);
    await tester.tap(find.text('Per side'));
    await tester.pump();
    await tester.tap(find.byTooltip('More').first);
    await tester.pump();
    await tester.tap(find.byTooltip('More').last);
    await tester.pump();
    await tester.tap(find.byTooltip('More').last);
    await tester.pump();
    await save(tester);
    final saved = store.entries.single;
    expect(saved.type, EntryType.pump);
    expect(saved.leftMl, 5);
    expect(saved.rightMl, 10);
    expect(saved.amountMl, 15);
  });

  testWidgets('diaper: wet and dirty with a rash', (tester) async {
    final store = await newStore();
    await openSheet(tester, DiaperSheet(store: store));
    await save(tester);
    expect(find.text('Choose wet, dirty or dry.'), findsOneWidget);
    await tester.tap(find.text('Wet'));
    await tester.pump();
    await tester.tap(find.text('Dirty'));
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await save(tester);
    expect(store.entries.single.diaper, DiaperKind.both);
    expect(store.entries.single.rash, isTrue);
  });

  testWidgets('diaper: editing keeps what was logged', (tester) async {
    final store = await newStore();
    final logged = entry(EntryType.diaper, testNow, diaper: DiaperKind.dirty);
    await store.upsert(logged);
    await openSheet(tester, DiaperSheet(store: store, existing: logged));
    await save(tester);
    expect(store.entries.single.id, logged.id);
    expect(store.entries.single.diaper, DiaperKind.dirty);
  });

  testWidgets('routine: a preset or something else', (tester) async {
    final store = await newStore();
    await openSheet(tester, LabelledSheet(store: store, type: EntryType.routine));
    await save(tester);
    expect(find.text('Choose a routine or type one.'), findsOneWidget);
    await tester.tap(find.text('Something else'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Massage');
    await save(tester);
    expect(store.entries.single.title, 'Massage');
  });

  testWidgets('other: weight fills in kg', (tester) async {
    final store = await newStore();
    await openSheet(tester, LabelledSheet(store: store, type: EntryType.other));
    await save(tester);
    expect(find.text('Choose what you are logging or type it.'), findsOneWidget);
    await tester.tap(find.text('Weight'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Value'), '4,87');
    await save(tester);
    final saved = store.entries.single;
    expect(saved.title, 'Weight');
    expect(saved.unit, 'kg');
    expect(saved.numericValue, 4.87);
  });
}
