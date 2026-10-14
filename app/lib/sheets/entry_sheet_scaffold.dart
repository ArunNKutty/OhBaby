import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/trends.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Opens [sheet] as a tall bottom sheet. Resolves to true when it saved.
Future<bool> showEntrySheet(BuildContext context, Widget sheet) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(heightFactor: 0.94, child: sheet),
  );
  return saved == true;
}

/// "Today 21:20", "Yesterday 06:10", "Mon 12 Oct 18:50".
String formatWhen(DateTime t, DateTime now) {
  final time = DateFormat('HH:mm').format(t);
  final day = dateOnly(t);
  final today = dateOnly(now);
  if (day == today) return 'Today $time';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday $time';
  return '${DateFormat('EEE d MMM').format(t)} $time';
}

/// The frame every entry sheet shares: a tinted header with Close, the title
/// and Save, then divided rows.
class EntrySheetScaffold extends StatelessWidget {
  const EntrySheetScaffold({
    super.key,
    required this.title,
    required this.tint,
    required this.onClose,
    required this.onSave,
    required this.children,
    this.error,
  });

  final String title;
  final TintKind tint;
  final VoidCallback onClose;
  final VoidCallback onSave;
  final List<Widget> children;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final headerColor = tint == TintKind.other ? c.pill : c.tint(tint).bg;
    return Material(
      color: c.card,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Column(
        children: [
          Container(
            color: headerColor,
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
            child: Row(
              children: [
                IconButton(tooltip: 'Close', onPressed: onClose, icon: Icon(Icons.close, color: c.ink)),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: c.ink),
                  ),
                ),
                TextButton(onPressed: onSave, child: const Text('Save')),
              ],
            ),
          ),
          if (error != null)
            Container(
              width: double.infinity,
              color: c.pill,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(error!, style: TextStyle(color: c.ink, fontWeight: FontWeight.w700)),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                for (final child in children) ...[child, const Divider()],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A label on the left and something on the right.
class SheetRow extends StatelessWidget {
  const SheetRow({super.key, required this.label, required this.trailing, this.onTap});

  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
          trailing,
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// "Start time  Today 21:20". Tapping picks a date, then a time.
class TimeRow extends StatelessWidget {
  const TimeRow({super.key, required this.label, required this.value, required this.onChanged, required this.now});

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime now;

  Future<void> _pick(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: now.subtract(const Duration(days: 365 * 3)),
      lastDate: now,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(value));
    if (time == null) return;
    var picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (picked.isAfter(now)) picked = now;
    onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return SheetRow(
      label: label,
      onTap: () => _pick(context),
      trailing: Text(formatWhen(value, now), style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// "−  150 ml  +" in steps of [step].
class AmountStepper extends StatelessWidget {
  const AmountStepper({super.key, required this.value, required this.onChanged, this.step = 10, this.max = 2000});

  final int value;
  final ValueChanged<int> onChanged;
  final int step;
  final int max;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Less',
          onPressed: value <= 0 ? null : () => onChanged((value - step).clamp(0, max)),
          icon: Icon(Icons.remove, color: c.ink),
        ),
        SizedBox(
          width: 76,
          child: Text('$value ml', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        ),
        RoundIconButton(icon: Icons.add, tooltip: 'More', size: 40, onPressed: () => onChanged((value + step).clamp(0, max))),
      ],
    );
  }
}

/// A big round choice: "Formula", "Wet".
class ChoiceCircle extends StatelessWidget {
  const ChoiceCircle({super.key, required this.label, required this.selected, required this.onTap, required this.fill});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 96,
          height: 96,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? fill : Colors.transparent,
            border: Border.all(color: c.ink, width: selected ? 2.5 : 1.2),
          ),
          child: Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        ),
      ),
    );
  }
}

/// The free-text Notes row at the bottom of every sheet.
class NotesField extends StatelessWidget {
  const NotesField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: TextField(
        controller: controller,
        minLines: 1,
        maxLines: 4,
        maxLength: 4000,
        decoration: const InputDecoration(
          hintText: 'Notes',
          border: InputBorder.none,
          counterText: '',
        ),
      ),
    );
  }
}

/// A pill chip with an icon, for routine and measurement choices.
class PresetChip extends StatelessWidget {
  const PresetChip({super.key, required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: Icon(icon, size: 18, color: context.colors.ink),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

/// Asks how many minutes a side took. Null when cancelled.
Future<Duration?> askMinutes(BuildContext context, String title, Duration current) async {
  final text = await askText(
    context,
    title: title,
    initial: current.inMinutes == 0 ? '' : '${current.inMinutes}',
    hint: '0',
    suffix: 'min',
    maxLength: 3,
    keyboardType: TextInputType.number,
  );
  if (text == null) return null;
  final minutes = int.tryParse(text.trim()) ?? 0;
  return Duration(minutes: minutes.clamp(0, 600));
}

/// "Discard this timer?" Resolves to true to discard, false to keep it running.
Future<bool?> confirmDiscardTimer(BuildContext context) => showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this timer?'),
        content: const Text('The time counted so far will not be saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep timing')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
        ],
      ),
    );
