import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/feeding_store.dart';
import '../models/entry.dart';
import '../models/live_timer.dart';
import '../models/trends.dart';
import '../sheets/add_entry_sheet.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/timeline.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.store, required this.day});

  final FeedingStore store;

  /// The day shown. Trends sets it when a day is tapped.
  final ValueNotifier<DateTime> day;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  /// Swiped away but not deleted yet: the delete happens when the Undo
  /// snackbar closes, so an undo never races a delete on the server.
  final Set<String> _pendingDelete = {};

  /// Repaints each second while a timer runs, so its quick-add chip counts.
  Timer? _tick;

  FeedingStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && store.liveTimer?.isRunning == true) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _swiped(Entry entry) {
    setState(() => _pendingDelete.add(entry.id));
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger
        .showSnackBar(SnackBar(
          content: const Text('Entry deleted'),
          action: SnackBarAction(label: 'Undo', onPressed: () {}),
          duration: const Duration(seconds: 5),
          // A snackbar with an action stays until dismissed unless told
          // otherwise, and the delete only happens once this one goes.
          persist: false,
        ))
        .closed
        .then((reason) async {
      if (reason == SnackBarClosedReason.action) {
        if (mounted) setState(() => _pendingDelete.remove(entry.id));
        return;
      }
      await store.delete(entry.id);
      store.track('entry_deleted', {'type': entry.type.name});
      _pendingDelete.remove(entry.id);
    });
  }

  /// Saves a quick-add entry straight away, with Undo.
  Future<void> _quickSave(Entry entry, String what) async {
    await store.upsert(entry);
    store.track('quick_add', {'type': entry.type.name});
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Logged $what'),
        action: SnackBarAction(label: 'Undo', onPressed: () => store.delete(entry.id)),
        persist: false,
      ));
  }

  Future<void> _pickDay() async {
    final now = store.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.day.value,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      helpText: 'Go to a day',
    );
    if (picked != null) widget.day.value = dateOnly(picked);
  }

  List<Widget> _quickAdd() {
    final now = store.now();
    final timer = store.liveTimer;
    final chips = <Widget>[];
    if (timer != null && timer.type == EntryType.breast) {
      final side = timer.running == TimerSide.right ? 'right' : 'left';
      chips.add(_QuickChip(
        type: EntryType.breast,
        title: 'Breastfeed',
        subtitle: timer.isRunning ? 'Timing $side · ${formatClock(timer.totalAt(now))}' : 'Paused · ${formatClock(timer.totalAt(now))}',
        onTap: () => openEntrySheet(context, store, EntryType.breast),
      ));
    } else {
      chips.add(_QuickChip(
        type: EntryType.breast,
        title: 'Breastfeed',
        subtitle: 'Next: ${store.nextSide.name} side',
        onTap: () => openEntrySheet(context, store, EntryType.breast),
      ));
    }
    if (timer != null && timer.type == EntryType.pump) {
      chips.add(_QuickChip(
        type: EntryType.pump,
        title: 'Pump',
        subtitle: '${timer.isRunning ? 'Timing' : 'Paused'} · ${formatClock(timer.totalAt(now))}',
        onTap: () => openEntrySheet(context, store, EntryType.pump),
      ));
    } else {
      chips.add(_QuickChip(
        type: EntryType.pump,
        title: 'Pump',
        subtitle: 'Timer',
        onTap: () => openEntrySheet(context, store, EntryType.pump, startTimer: true),
      ));
    }
    final last = store.lastBottle;
    chips.add(_QuickChip(
      type: last?.type ?? EntryType.bottle,
      title: last == null ? 'Bottle' : 'Bottle ${last.amountMl} ml',
      subtitle: last?.type.shortLabel ?? 'Add amount',
      onTap: () {
        if (last == null) {
          openEntrySheet(context, store, EntryType.bottle);
          return;
        }
        final at = store.now();
        _quickSave(
          Entry(id: store.newId(), type: last.type, start: at, end: at, amountMl: last.amountMl),
          '${last.type.shortLabel.toLowerCase()} ${last.amountMl} ml',
        );
      },
    ));
    for (final kind in [DiaperKind.wet, DiaperKind.dirty]) {
      chips.add(_QuickChip(
        type: EntryType.diaper,
        title: 'Diaper',
        subtitle: kind.label,
        onTap: () {
          final at = store.now();
          _quickSave(Entry(id: store.newId(), type: EntryType.diaper, start: at, end: at, diaper: kind), 'diaper (${kind.label.toLowerCase()})');
        },
      ));
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: Listenable.merge([store, widget.day]),
      builder: (context, _) {
        final now = store.now();
        final day = widget.day.value;
        final isToday = isSameDay(day, now);
        final entries = entriesOnDay(store.entries, day).where((e) => !_pendingDelete.contains(e.id)).toList().reversed.toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            const AppHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  BabyAvatar(photo: store.babyPhoto),
                  const SizedBox(width: 16),
                  Expanded(child: Text(store.babyName, style: textTheme.headlineLarge, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
            const Padding(padding: EdgeInsets.fromLTRB(20, 8, 20, 10), child: SectionLabel('Quick add')),
            SizedBox(
              height: 64,
              child: Semantics(
                container: true,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    for (final chip in _quickAdd()) Padding(padding: const EdgeInsets.only(right: 10), child: chip),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DayHeader(
                      day: day,
                      now: now,
                      onPick: _pickDay,
                      onPrevious: () => widget.day.value = DateTime(day.year, day.month, day.day - 1),
                      onNext: isToday ? null : () => widget.day.value = DateTime(day.year, day.month, day.day + 1),
                    ),
                    if (isToday) ...[
                      const SizedBox(height: 14),
                      _LastFeeding(store: store, now: now),
                    ],
                    const SizedBox(height: 14),
                    _Pills(totals: Totals.of(entries)),
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('Timeline', style: textTheme.titleLarge),
                        const SizedBox(width: 10),
                        Text(entries.length == 1 ? '1 entry' : '${entries.length} entries', style: textTheme.bodyMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (entries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(isToday ? 'Nothing logged yet today.' : 'Nothing logged on this day.', style: textTheme.bodyMedium),
                      )
                    else ...[
                      for (var i = 0; i < entries.length; i++)
                        Dismissible(
                          key: ValueKey(entries[i].id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(color: context.colors.pill, borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.delete_outline, color: context.colors.ink),
                          ),
                          onDismissed: (_) => _swiped(entries[i]),
                          child: TimelineRow(
                            entry: entries[i],
                            first: i == 0,
                            last: i == entries.length - 1,
                            onTap: () => openEntrySheet(context, store, entries[i].type, existing: entries[i]),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text('Tap to edit · swipe left to delete', style: textTheme.bodySmall?.copyWith(color: context.colors.muted)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.type, required this.title, required this.subtitle, required this.onTap});

  final EntryType type;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      excludeSemantics: true,
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 18, 8),
            child: Row(
              children: [
                TypeIcon(type, size: 40),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    Text(subtitle, style: TextStyle(color: c.muted, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.now, required this.onPick, required this.onPrevious, this.onNext});

  final DateTime day;
  final DateTime now;
  final VoidCallback onPick;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final title = isSameDay(day, now)
        ? 'Today'
        : isSameDay(day, yesterday)
            ? 'Yesterday'
            : DateFormat('EEEE').format(day);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.headlineMedium),
              Semantics(
                button: true,
                hint: 'Go to a day',
                child: InkWell(
                  onTap: onPick,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            DateFormat('d MMMM y').format(day),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700, color: c.muted, fontSize: 15),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.calendar_month_outlined, size: 18, color: c.muted),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        RoundIconButton(icon: Icons.chevron_left, tooltip: 'Previous day', onPressed: onPrevious),
        const SizedBox(width: 6),
        RoundIconButton(icon: Icons.chevron_right, tooltip: 'Next day', onPressed: onNext),
      ],
    );
  }
}

/// "Last feeding 2 h 29 m ago · Formula 150 ml".
class _LastFeeding extends StatelessWidget {
  const _LastFeeding({required this.store, required this.now});

  final FeedingStore store;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final last = store.lastFeeding;
    if (last == null) return Text('No feeding logged yet.', style: TextStyle(color: c.muted, fontSize: 15));
    final ago = now.difference(last.end.isAfter(now) ? now : last.end);
    final what = last.type == EntryType.breast ? 'Breastfeeding ${formatDuration(last.breastDuration)}' : '${last.type.shortLabel} ${last.amountMl} ml';
    return Text.rich(
      TextSpan(children: [
        const TextSpan(text: 'Last feeding '),
        TextSpan(text: '${formatDuration(ago)} ago', style: TextStyle(fontWeight: FontWeight.w700, color: c.ink)),
        TextSpan(text: ' · $what'),
      ]),
      style: TextStyle(color: c.muted, fontSize: 15),
    );
  }
}

class _Pills extends StatelessWidget {
  const _Pills({required this.totals});

  final Totals totals;

  @override
  Widget build(BuildContext context) {
    final pills = [
      if (totals.breast > Duration.zero) SummaryPill(type: EntryType.breast, value: formatDuration(totals.breast), label: 'breastfed'),
      if (totals.bottleMl > 0) SummaryPill(type: EntryType.bottle, value: '${totals.bottleMl} ml', label: 'bottle'),
      if (totals.pumpedMl > 0) SummaryPill(type: EntryType.pump, value: '${totals.pumpedMl} ml', label: 'pumped'),
      if (totals.diapers > 0) SummaryPill(type: EntryType.diaper, value: '${totals.diapers}', label: totals.diapers == 1 ? 'diaper' : 'diapers'),
    ];
    if (pills.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: pills);
  }
}
