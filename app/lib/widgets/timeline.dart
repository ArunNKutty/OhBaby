import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/entry.dart';
import '../sheets/presets.dart';
import '../theme.dart';
import 'common.dart';

/// One entry on a day's timeline: its time, a tinted icon on the line, and
/// what was logged.
class TimelineRow extends StatelessWidget {
  const TimelineRow({super.key, required this.entry, required this.first, required this.last, this.onTap});

  final Entry entry;
  final bool first;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final time = DateFormat('HH:mm');
    final showEnd = entry.end.difference(entry.start).inMinutes >= 1;
    final detail = entry.detail;
    final icon = entry.type == EntryType.routine || entry.type == EntryType.other ? presetIcon(entry.title, iconFor(entry.type)) : null;
    return InkWell(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 56,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(time.format(entry.start), style: TextStyle(fontWeight: FontWeight.w700, color: c.muted, fontSize: 16)),
                    if (showEnd) Text(time.format(entry.end), style: TextStyle(color: c.muted, fontSize: 12)),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 32,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    top: first ? 22 : 0,
                    bottom: last ? null : 0,
                    height: last ? 22 : null,
                    child: Container(width: 2, color: c.divider),
                  ),
                  Padding(padding: const EdgeInsets.only(top: 8), child: TypeIcon(entry.type, size: 30, icon: icon)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.heading, style: textTheme.titleMedium),
                    if (detail.isNotEmpty) Text(detail, style: textTheme.bodyMedium?.copyWith(fontSize: 15)),
                    if (entry.notes.isNotEmpty)
                      Text(entry.notes, style: textTheme.bodySmall?.copyWith(color: c.muted, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
