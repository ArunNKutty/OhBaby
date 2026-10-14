import 'package:flutter/material.dart';

import '../data/feeding_store.dart';
import '../models/entry.dart';
import '../theme.dart';
import 'entry_sheet_scaffold.dart';
import 'presets.dart';

/// State shared by the sheets that log a moment: the time, notes, an error,
/// and saving.
mixin _MomentSheet<T extends StatefulWidget> on State<T> {
  FeedingStore get store;
  Entry? get existing;

  late DateTime time;
  final notes = TextEditingController();
  String? error;

  void initMoment() {
    time = existing?.start ?? store.now();
    notes.text = existing?.notes ?? '';
  }

  void fail(String message) => setState(() => error = message);

  void change(void Function() update) => setState(() {
        update();
        error = null;
      });

  Future<void> finish(Entry entry) async {
    await store.upsert(entry);
    store.track('entry_saved', {'type': entry.type.name, 'edit': existing != null});
    if (mounted) Navigator.pop(context, true);
  }

  void close() => Navigator.pop(context, false);

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }
}

class BottleSheet extends StatefulWidget {
  const BottleSheet({super.key, required this.store, this.existing});

  final FeedingStore store;
  final Entry? existing;

  @override
  State<BottleSheet> createState() => _BottleSheetState();
}

class _BottleSheetState extends State<BottleSheet> with _MomentSheet {
  @override
  FeedingStore get store => widget.store;
  @override
  Entry? get existing => widget.existing;

  late EntryType kind;
  late int amount;

  @override
  void initState() {
    super.initState();
    initMoment();
    kind = existing?.type ?? store.lastBottle?.type ?? EntryType.bottle;
    amount = existing?.amountMl ?? 0;
  }

  Future<void> _save() async {
    if (amount <= 0) return fail('Add the amount.');
    await finish(Entry(
      id: existing?.id ?? store.newId(),
      type: kind,
      start: time,
      end: time,
      amountMl: amount,
      notes: notes.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final last = existing == null ? store.lastBottle?.amountMl : null;
    return EntrySheetScaffold(
      title: 'Bottle feeding',
      tint: TintKind.feed,
      error: error,
      onClose: close,
      onSave: _save,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceCircle(
                label: 'Breast milk',
                selected: kind == EntryType.breastMilk,
                fill: c.tint(TintKind.feed).bg,
                onTap: () => change(() => kind = EntryType.breastMilk),
              ),
              const SizedBox(width: 20),
              ChoiceCircle(
                label: 'Formula',
                selected: kind == EntryType.bottle,
                fill: c.tint(TintKind.feed).bg,
                onTap: () => change(() => kind = EntryType.bottle),
              ),
            ],
          ),
        ),
        TimeRow(label: 'Start time', value: time, now: store.now(), onChanged: (t) => change(() => time = t)),
        Column(
          children: [
            SheetRow(label: 'Amount', trailing: AmountStepper(value: amount, onChanged: (v) => change(() => amount = v))),
            if (last != null && last != amount)
              Container(
                color: c.pill,
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                child: Row(
                  children: [
                    Expanded(child: Text('Use last amount: $last ml?', style: TextStyle(color: c.ink))),
                    OutlinedButton(onPressed: () => change(() => amount = last), child: const Text('Yes')),
                  ],
                ),
              ),
          ],
        ),
        NotesField(controller: notes),
      ],
    );
  }
}

class DiaperSheet extends StatefulWidget {
  const DiaperSheet({super.key, required this.store, this.existing});

  final FeedingStore store;
  final Entry? existing;

  @override
  State<DiaperSheet> createState() => _DiaperSheetState();
}

class _DiaperSheetState extends State<DiaperSheet> with _MomentSheet {
  @override
  FeedingStore get store => widget.store;
  @override
  Entry? get existing => widget.existing;

  bool wet = false;
  bool dirty = false;
  bool dry = false;
  bool rash = false;

  @override
  void initState() {
    super.initState();
    initMoment();
    final e = existing;
    if (e != null) {
      wet = e.wet;
      dirty = e.dirty;
      dry = e.diaper == DiaperKind.dry;
      rash = e.rash;
    }
  }

  DiaperKind? get kind => dry
      ? DiaperKind.dry
      : wet && dirty
          ? DiaperKind.both
          : wet
              ? DiaperKind.wet
              : dirty
                  ? DiaperKind.dirty
                  : null;

  Future<void> _save() async {
    if (kind == null) return fail('Choose wet, dirty or dry.');
    await finish(Entry(
      id: existing?.id ?? store.newId(),
      type: EntryType.diaper,
      start: time,
      end: time,
      diaper: kind,
      rash: rash,
      notes: notes.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final fill = context.colors.tint(TintKind.diaper).bg;
    return EntrySheetScaffold(
      title: 'Diaper',
      tint: TintKind.diaper,
      error: error,
      onClose: close,
      onSave: _save,
      children: [
        TimeRow(label: 'Time', value: time, now: store.now(), onChanged: (t) => change(() => time = t)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Wet and dirty can go together; dry is on its own.
              ChoiceCircle(label: 'Wet', selected: wet, fill: fill, onTap: () => change(() {
                wet = !wet;
                dry = false;
              })),
              ChoiceCircle(label: 'Dirty', selected: dirty, fill: fill, onTap: () => change(() {
                dirty = !dirty;
                dry = false;
              })),
              ChoiceCircle(label: 'Dry', selected: dry, fill: fill, onTap: () => change(() {
                dry = !dry;
                wet = false;
                dirty = false;
              })),
            ],
          ),
        ),
        SheetRow(
          label: 'Diaper rash',
          onTap: () => change(() => rash = !rash),
          trailing: Switch(value: rash, onChanged: (v) => change(() => rash = v)),
        ),
        NotesField(controller: notes),
      ],
    );
  }
}

/// Routine and Other: pick a preset chip, or "Something else" and type a name.
class LabelledSheet extends StatefulWidget {
  const LabelledSheet({super.key, required this.store, required this.type, this.existing});

  final FeedingStore store;

  /// [EntryType.routine] or [EntryType.other].
  final EntryType type;
  final Entry? existing;

  @override
  State<LabelledSheet> createState() => _LabelledSheetState();
}

class _LabelledSheetState extends State<LabelledSheet> with _MomentSheet {
  @override
  FeedingStore get store => widget.store;
  @override
  Entry? get existing => widget.existing;

  bool get isOther => widget.type == EntryType.other;
  List<Preset> get presets => isOther ? otherPresets : routinePresets;

  /// The chosen preset title, or [somethingElse].
  String? chosen;
  final custom = TextEditingController();
  final value = TextEditingController();
  final unit = TextEditingController();

  @override
  void initState() {
    super.initState();
    initMoment();
    final e = existing;
    if (e != null) {
      final known = presets.any((p) => p.title == e.title);
      chosen = known ? e.title : somethingElse;
      if (!known) custom.text = e.title;
      value.text = e.value;
      unit.text = e.unit;
    }
  }

  @override
  void dispose() {
    custom.dispose();
    value.dispose();
    unit.dispose();
    super.dispose();
  }

  Preset? get preset => presets.where((p) => p.title == chosen).firstOrNull;

  void _choose(String title) => change(() {
        chosen = title;
        final p = preset;
        if (isOther && p != null) unit.text = p.unit;
      });

  Future<void> _save() async {
    final title = chosen == somethingElse ? custom.text.trim() : chosen ?? '';
    if (title.isEmpty) {
      return fail(isOther ? 'Choose what you are logging or type it.' : 'Choose a routine or type one.');
    }
    await finish(Entry(
      id: existing?.id ?? store.newId(),
      type: widget.type,
      start: time,
      end: time,
      title: title,
      value: isOther ? value.text.trim() : '',
      unit: isOther ? unit.text.trim() : '',
      notes: notes.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = preset;
    return EntrySheetScaffold(
      title: isOther ? 'Other' : 'Routine',
      tint: isOther ? TintKind.other : TintKind.routine,
      error: error,
      onClose: close,
      onSave: _save,
      children: [
        TimeRow(label: 'Time', value: time, now: store.now(), onChanged: (t) => change(() => time = t)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isOther ? 'What are you logging?' : 'Routine', style: textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in presets)
                    PresetChip(label: preset.title, icon: preset.icon, selected: chosen == preset.title, onTap: () => _choose(preset.title)),
                  PresetChip(label: somethingElse, icon: Icons.add, selected: chosen == somethingElse, onTap: () => _choose(somethingElse)),
                ],
              ),
              if (chosen == somethingElse) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: custom,
                  autofocus: existing == null,
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: isOther ? 'What are you logging?' : 'Routine',
                    hintText: 'e.g. Massage',
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() => error = null),
                ),
              ],
            ],
          ),
        ),
        if (isOther && chosen != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: value,
                    maxLength: 200,
                    keyboardType: p?.numeric == true ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
                    decoration: InputDecoration(labelText: p?.numeric == true ? 'Value' : 'Details', hintText: p?.hint, counterText: ''),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: unit,
                    maxLength: 16,
                    decoration: const InputDecoration(labelText: 'Unit', hintText: 'Optional, e.g. ml', counterText: ''),
                  ),
                ),
              ],
            ),
          ),
        NotesField(controller: notes),
      ],
    );
  }
}
