import 'package:flutter/material.dart';

import '../data/feeding_store.dart';
import '../models/entry.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'entry_sheet_scaffold.dart';
import 'simple_sheets.dart';
import 'timer_sheets.dart';

/// Opens the sheet for [type]: a new entry, or [existing] to edit. Bottles of
/// either kind share one sheet. Resolves to true when it saved.
Future<bool> openEntrySheet(
  BuildContext context,
  FeedingStore store,
  EntryType type, {
  Entry? existing,
  bool startTimer = false,
}) {
  final Widget sheet = switch (type) {
    EntryType.breast => BreastfeedingSheet(store: store, existing: existing),
    EntryType.bottle || EntryType.breastMilk => BottleSheet(store: store, existing: existing),
    EntryType.pump => PumpSheet(store: store, existing: existing, startTimer: startTimer),
    EntryType.diaper => DiaperSheet(store: store, existing: existing),
    EntryType.routine || EntryType.other => LabelledSheet(store: store, type: type, existing: existing),
  };
  return showEntrySheet(context, sheet);
}

const _choices = [
  (EntryType.breast, 'Breastfeeding', 'Time each side'),
  (EntryType.bottle, 'Bottle feeding', 'Formula or breast milk'),
  (EntryType.pump, 'Pumping', 'Time and amount pumped'),
  (EntryType.diaper, 'Diaper', 'Wet, dirty or dry'),
  (EntryType.routine, 'Routine', 'Bath, tummy time, walks…'),
  (EntryType.other, 'Other', 'Weight, temperature, medicine, vaccines, firsts…'),
];

/// "What do you want to log?", then the chosen kind's sheet.
Future<void> showAddEntry(BuildContext context, FeedingStore store) async {
  final type = await showModalBottomSheet<EntryType>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      final c = context.colors;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: c.selected, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
              child: Text('What do you want to log?', style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final (type, title, subtitle) in _choices)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                leading: TypeIcon(type),
                title: Text(title, style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(subtitle),
                trailing: Icon(Icons.chevron_right, color: c.ink),
                onTap: () => Navigator.pop(context, type),
              ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
  if (type == null || !context.mounted) return;
  store.track('feeding_add_started', {'type': type.name});
  await openEntrySheet(context, store, type);
}
