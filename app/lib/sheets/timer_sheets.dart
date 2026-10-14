import 'dart:async';

import 'package:flutter/material.dart';

import '../data/feeding_store.dart';
import '../models/entry.dart';
import '../models/live_timer.dart';
import '../models/trends.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'entry_sheet_scaffold.dart';

/// Shared by the breastfeeding and pumping sheets: a [LiveTimer] that is kept
/// in the store while a new entry is being timed, so it survives the app
/// closing, and a one-second repaint while it runs.
mixin _TimedSheet<T extends StatefulWidget> on State<T> {
  FeedingStore get store;
  Entry? get existing;
  EntryType get timerType;

  late LiveTimer timer;
  Timer? _ticker;
  final notes = TextEditingController();
  String? error;

  /// A new entry keeps its timer in the store; editing one does not.
  bool get persist => existing == null;

  DateTime get now => store.now();

  void initTimer(LiveTimer fromEntry) {
    final saved = store.liveTimer;
    timer = existing != null
        ? fromEntry
        : saved != null && saved.type == timerType
            ? saved
            : LiveTimer(type: timerType, start: now);
    notes.text = existing?.notes ?? '';
    _syncTicker();
  }

  void _syncTicker() {
    if (timer.isRunning && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!timer.isRunning) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  bool get hasTime => timer.isRunning || timer.totalAt(now) > Duration.zero;

  Future<void> setTimer(LiveTimer next) async {
    setState(() {
      timer = next;
      error = null;
    });
    _syncTicker();
    if (persist) await store.setLiveTimer(hasTime ? next : null);
  }

  /// Starts [side], or stops it when it is the one running. The first start of
  /// a new entry also sets its start time to now.
  Future<void> toggle(TimerSide side) async {
    final at = now;
    if (timer.running == side) return setTimer(timer.stop(at));
    var base = timer;
    if (persist && !hasTime) base = LiveTimer(type: timerType, start: at);
    await setTimer(base.startSide(side, at));
  }

  Future<void> editSide(TimerSide side, String label) async {
    final current = side == TimerSide.right ? timer.rightAt(now) : timer.leftAt(now);
    final picked = await askMinutes(context, label, current);
    if (picked != null) await setTimer(timer.edit(side, picked, now));
  }

  Future<void> setStart(DateTime start) => setTimer(LiveTimer(
        type: timer.type,
        start: start,
        left: timer.left,
        right: timer.right,
        running: timer.running,
        runningSince: timer.runningSince,
      ));

  Future<void> close() async {
    if (persist && hasTime) {
      final discard = await confirmDiscardTimer(context);
      if (discard == null) return;
      if (discard) await store.setLiveTimer(null);
    }
    if (mounted) Navigator.pop(context, false);
  }

  Future<void> finish(Entry entry) async {
    await store.upsert(entry);
    if (persist) await store.setLiveTimer(null);
    store.track('entry_saved', {'type': entry.type.name, 'edit': existing != null});
    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    notes.dispose();
    super.dispose();
  }
}

/// A big "00:00" with a pencil to type the time and a Start/Stop button.
class _Clock extends StatelessWidget {
  const _Clock({required this.time, required this.editLabel, required this.onEdit, required this.button, required this.onToggle, this.badge});

  final Duration time;
  final String editLabel;
  final VoidCallback onEdit;
  final String button;
  final VoidCallback onToggle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        SizedBox(
          height: 30,
          child: badge == null
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: c.tint(TintKind.diaper).bg, borderRadius: BorderRadius.circular(6)),
                  child: Text(badge!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.ink)),
                ),
        ),
        const SizedBox(height: 8),
        // Shrinks rather than overflows on a narrow phone or with large text.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formatClock(time), style: TextStyle(fontSize: 38, color: c.ink, fontFeatures: const [FontFeature.tabularFigures()])),
              IconButton(tooltip: editLabel, onPressed: onEdit, icon: Icon(Icons.edit, size: 20, color: c.ink)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        OutlinedButton(onPressed: onToggle, child: Text(button)),
      ],
    );
  }
}

class BreastfeedingSheet extends StatefulWidget {
  const BreastfeedingSheet({super.key, required this.store, this.existing});

  final FeedingStore store;
  final Entry? existing;

  @override
  State<BreastfeedingSheet> createState() => _BreastfeedingSheetState();
}

class _BreastfeedingSheetState extends State<BreastfeedingSheet> with _TimedSheet {
  @override
  FeedingStore get store => widget.store;
  @override
  Entry? get existing => widget.existing;
  @override
  EntryType get timerType => EntryType.breast;

  BreastSide? endSide;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    initTimer(LiveTimer(
      type: EntryType.breast,
      start: e?.start ?? store.now(),
      left: e?.leftDuration ?? Duration.zero,
      right: e?.rightDuration ?? Duration.zero,
    ));
    endSide = e?.endSide ?? switch (timer.running) {
      TimerSide.left => BreastSide.left,
      TimerSide.right => BreastSide.right,
      _ => null,
    };
  }

  Future<void> _toggle(TimerSide side) async {
    await toggle(side);
    if (timer.running == side) setState(() => endSide = side == TimerSide.left ? BreastSide.left : BreastSide.right);
  }

  Future<void> _save() async {
    final at = now;
    final stopped = timer.stop(at);
    final total = stopped.totalAt(at);
    if (total == Duration.zero) {
      setState(() => error = 'Start a timer or enter the time for a side.');
      return;
    }
    if (endSide == null) {
      setState(() => error = 'Choose the side you ended on.');
      return;
    }
    await finish(Entry(
      id: widget.existing?.id ?? store.newId(),
      type: EntryType.breast,
      start: stopped.start,
      end: stopped.start.add(total),
      leftDuration: stopped.left,
      rightDuration: stopped.right,
      endSide: endSide,
      notes: notes.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final at = now;
    final last = widget.existing == null ? store.lastEndSide : null;
    Widget sideButton(BreastSide side) {
      final on = endSide == side;
      final label = side == BreastSide.left ? 'Left' : 'Right';
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Semantics(
          selected: on,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: on ? c.tint(TintKind.feed).bg : null,
              side: BorderSide(color: c.ink, width: on ? 2 : 1),
            ),
            onPressed: () => setState(() {
              endSide = side;
              error = null;
            }),
            child: Text(label),
          ),
        ),
      );
    }

    return EntrySheetScaffold(
      title: 'Breastfeeding',
      tint: TintKind.feed,
      error: error,
      onClose: close,
      onSave: _save,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          child: Row(
            children: [
              for (final (side, name) in [(TimerSide.left, 'Left'), (TimerSide.right, 'Right')])
                Expanded(
                  child: _Clock(
                    time: side == TimerSide.left ? timer.leftAt(at) : timer.rightAt(at),
                    editLabel: 'Enter $name time',
                    onEdit: () => editSide(side, '$name side'),
                    button: timer.running == side ? 'Stop ${name.toLowerCase()}' : 'Start ${name.toLowerCase()}',
                    onToggle: () => _toggle(side),
                    badge: last != null && last.name == side.name ? 'Last side' : null,
                  ),
                ),
            ],
          ),
        ),
        SheetRow(
          label: 'Ended on',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [sideButton(BreastSide.left), sideButton(BreastSide.right)]),
        ),
        TimeRow(label: 'Start time', value: timer.start, now: at, onChanged: setStart),
        SheetRow(
          label: 'Total time',
          trailing: Text(formatDuration(timer.totalAt(at)), style: TextStyle(fontWeight: FontWeight.w700, color: c.muted, fontSize: 16)),
        ),
        NotesField(controller: notes),
      ],
    );
  }
}

class PumpSheet extends StatefulWidget {
  const PumpSheet({super.key, required this.store, this.existing, this.startTimer = false});

  final FeedingStore store;
  final Entry? existing;

  /// Quick add's "Pump · Timer" opens with the timer already running.
  final bool startTimer;

  @override
  State<PumpSheet> createState() => _PumpSheetState();
}

class _PumpSheetState extends State<PumpSheet> with _TimedSheet {
  @override
  FeedingStore get store => widget.store;
  @override
  Entry? get existing => widget.existing;
  @override
  EntryType get timerType => EntryType.pump;

  late bool perSide;
  late int leftMl;
  late int rightMl;
  late int totalMl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    initTimer(LiveTimer(type: EntryType.pump, start: e?.start ?? store.now(), left: e?.pumpDuration ?? Duration.zero));
    perSide = e != null && e.leftMl + e.rightMl > 0;
    leftMl = e?.leftMl ?? 0;
    rightMl = e?.rightMl ?? 0;
    totalMl = e?.amountMl ?? 0;
    if (widget.startTimer && !timer.isRunning) {
      WidgetsBinding.instance.addPostFrameCallback((_) => toggle(TimerSide.pump));
    }
  }

  int get amount => perSide ? leftMl + rightMl : totalMl;

  Future<void> _save() async {
    final at = now;
    final stopped = timer.stop(at);
    final duration = stopped.totalAt(at);
    if (amount == 0 && duration == Duration.zero) {
      setState(() => error = 'Add the amount pumped or start the timer.');
      return;
    }
    await finish(Entry(
      id: widget.existing?.id ?? store.newId(),
      type: EntryType.pump,
      start: stopped.start,
      end: stopped.start.add(duration),
      amountMl: amount,
      leftMl: perSide ? leftMl : 0,
      rightMl: perSide ? rightMl : 0,
      notes: notes.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final at = now;
    void amountChanged(void Function() change) => setState(() {
          change();
          error = null;
        });
    return EntrySheetScaffold(
      title: 'Pumping',
      tint: TintKind.pump,
      error: error,
      onClose: close,
      onSave: _save,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          child: Center(
            child: _Clock(
              time: timer.leftAt(at),
              editLabel: 'Enter the time',
              onEdit: () => editSide(TimerSide.pump, 'Pumping time'),
              button: timer.isRunning ? 'Stop timer' : 'Start timer',
              onToggle: () => toggle(TimerSide.pump),
            ),
          ),
        ),
        TimeRow(label: 'Start time', value: timer.start, now: at, onChanged: setStart),
        SheetRow(
          label: 'Amount',
          trailing: Segmented<bool>(
            options: const {true: 'Per side', false: 'Total'},
            selected: perSide,
            onChanged: (v) => setState(() => perSide = v),
          ),
        ),
        if (perSide) ...[
          SheetRow(label: 'Left side', trailing: AmountStepper(value: leftMl, step: 5, onChanged: (v) => amountChanged(() => leftMl = v))),
          SheetRow(label: 'Right side', trailing: AmountStepper(value: rightMl, step: 5, onChanged: (v) => amountChanged(() => rightMl = v))),
          SheetRow(label: 'Total', trailing: Text('$amount ml', style: Theme.of(context).textTheme.titleMedium)),
        ] else
          SheetRow(label: 'Total amount', trailing: AmountStepper(value: totalMl, step: 10, onChanged: (v) => amountChanged(() => totalMl = v))),
        NotesField(controller: notes),
      ],
    );
  }
}
