import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/feeding_store.dart';
import '../models/entry.dart';
import '../models/trends.dart';
import '../sheets/presets.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/line_chart.dart';
import '../widgets/sparkline.dart';
import '../widgets/timeline.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key, required this.store, required this.onOpenDay});

  final FeedingStore store;
  final ValueChanged<DateTime> onOpenDay;

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  Period period = Period.week;
  DateTime? _start;

  FeedingStore get store => widget.store;

  DateTime get start => _start ?? period.startOf(store.now());

  /// How many periods the sparklines and charts look back over.
  int get history => period == Period.week ? 8 : 6;

  String _periodTitle(DateTime now) {
    final current = period.startOf(now);
    if (start == current) return 'This ${period.noun}';
    if (start == period.shift(current, -1)) return 'Last ${period.noun}';
    return period == Period.week ? 'Week of ${DateFormat('d MMM').format(start)}' : DateFormat('MMMM y').format(start);
  }

  String _range() {
    final last = period.endOf(start).subtract(const Duration(days: 1));
    final sameMonth = start.month == last.month;
    final from = DateFormat(sameMonth ? 'd' : 'd MMM').format(start);
    return '$from – ${DateFormat('d MMM y').format(last)}';
  }

  Future<void> _pickPeriod() async {
    final now = store.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      helpText: period == Period.week ? 'Go to the week of' : 'Go to the month of',
    );
    if (picked != null) setState(() => _start = period.startOf(picked));
  }

  void _openChart(Metric metric) {
    final now = store.now();
    final values = series(store.entries, metric, start, period, history, now);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: MetricChartSheet(metric: metric, period: period, values: values),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = store.now();
        final all = store.entries;
        final isCurrent = start == period.startOf(now);
        final prevStart = period.shift(start, -1);
        final routines = routineCounts(all, start, period);
        final readings = measurements(all);
        final days = dayRows(all, start, period, now);
        return ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            const AppHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: Text('Trends', style: textTheme.headlineLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Segmented<Period>(
                  options: const {Period.week: 'Week', Period.month: 'Month'},
                  selected: period,
                  onChanged: (p) => setState(() {
                    period = p;
                    _start = null;
                    store.track('trends_viewed', {'period': p.name});
                  }),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_periodTitle(now), style: textTheme.headlineMedium),
                              InkWell(
                                onTap: _pickPeriod,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _range(),
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontWeight: FontWeight.w700, color: context.colors.muted, fontSize: 15),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.calendar_month_outlined, size: 18, color: context.colors.muted),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        RoundIconButton(
                          icon: Icons.chevron_left,
                          tooltip: 'Previous ${period.noun}',
                          onPressed: () => setState(() => _start = prevStart),
                        ),
                        const SizedBox(width: 6),
                        RoundIconButton(
                          icon: Icons.chevron_right,
                          tooltip: 'Next ${period.noun}',
                          onPressed: isCurrent ? null : () => setState(() => _start = period.shift(start, 1)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text('Average per day', style: textTheme.titleLarge),
                    if (isCurrent) Text("Today is added once it's over.", style: textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    for (final metric in Metric.values)
                      _MetricRow(
                        metric: metric,
                        value: averagePerDay(all, metric, start, period, now),
                        previous: averagePerDay(all, metric, prevStart, period, now),
                        period: period,
                        spark: [for (final v in series(all, metric, start, period, history, now)) v.value],
                        onTap: () => _openChart(metric),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'The small lines show the last ${period == Period.week ? '8 weeks' : '6 months'}. Tap a row for its chart.',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            if (routines.isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Routines', style: textTheme.titleLarge),
                      Text(
                        isCurrent
                            ? 'Times this ${period.noun} so far, against last ${period.noun}.'
                            : 'Times this ${period.noun}, against the ${period.noun} before.',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      for (final r in routines)
                        _InfoRow(
                          icon: TypeIcon(EntryType.routine, icon: presetIcon(r.title, iconFor(EntryType.routine))),
                          title: r.title,
                          value: '${r.thisPeriod} ${r.thisPeriod == 1 ? 'time' : 'times'}${isCurrent ? ' so far' : ''}',
                          detail: '${r.lastPeriod} ${r.lastPeriod == 1 ? 'time' : 'times'} last ${period.noun}',
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (readings.isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Measurements', style: textTheme.titleLarge),
                      Text(
                        'Numbers logged under Other, such as weight. The small lines show the latest readings.',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      for (final m in readings) _MeasurementRow(measurement: m),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Each day', style: textTheme.titleLarge),
                    Text('Tap a day to see its timeline.', style: textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    if (days.isEmpty) Text('Nothing logged yet.', style: textTheme.bodyMedium),
                    for (final d in days) ...[
                      const Divider(),
                      _DayRow(
                        row: d,
                        now: now,
                        onTap: () => showDaySheet(context, d, onOpenDay: () => widget.onOpenDay(d.day)),
                      ),
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

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.metric,
    required this.value,
    required this.previous,
    required this.period,
    required this.spark,
    required this.onTap,
  });

  final Metric metric;
  final double value;
  final double previous;
  final Period period;
  final List<double> spark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            TypeIcon(metric.type),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(metric.label, style: TextStyle(color: c.muted, fontSize: 14)),
                  Text(metric.format(value), style: Theme.of(context).textTheme.headlineSmall),
                  Text(changeLabel(value, previous, period), style: TextStyle(color: c.muted, fontSize: 14)),
                ],
              ),
            ),
            Sparkline(values: spark, color: c.tintFor(metric.type).line),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: c.ink),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.value, required this.detail, this.trailing});

  final Widget icon;
  final String title;
  final String value;
  final String detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: c.muted, fontSize: 14)),
                Text(value, style: Theme.of(context).textTheme.titleLarge),
                Text(detail, style: TextStyle(color: c.muted, fontSize: 14)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _MeasurementRow extends StatelessWidget {
  const _MeasurementRow({required this.measurement});

  final Measurement measurement;

  @override
  Widget build(BuildContext context) {
    final m = measurement;
    String number(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '${(v * 100).round() / 100}';
    final unit = m.unit.isEmpty ? '' : ' ${m.unit}';
    final count = '${m.readings.length} ${m.readings.length == 1 ? 'reading' : 'readings'}';
    final change = m.change == null ? count : '${formatChange(m.change!, m.unit)} since ${DateFormat('d MMM').format(m.previous!.at)} · $count';
    final recent = m.readings.length > 10 ? m.readings.sublist(m.readings.length - 10) : m.readings;
    return _InfoRow(
      icon: TypeIcon(EntryType.other, icon: presetIcon(m.title, iconFor(EntryType.other))),
      title: m.title,
      value: '${number(m.latest.value)}$unit',
      detail: change,
      trailing: recent.length < 2
          ? null
          : Sparkline(values: [for (final r in recent) r.value], color: context.colors.tint(TintKind.other).line, fromZero: false),
    );
  }
}

/// "♥ 36m  🍼 360 ml  💧 100 ml  🚼 5": a day's totals, leaving out what is zero.
class DaySummary extends StatelessWidget {
  const DaySummary({super.key, required this.totals, this.oneLine = false});

  final Totals totals;

  /// Keep to one line, shrinking a little if the row is narrow.
  final bool oneLine;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget item(EntryType type, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconFor(type), size: oneLine ? 16 : 20, color: c.tintFor(type).line),
            SizedBox(width: oneLine ? 4 : 6),
            Text(text, style: TextStyle(color: c.ink, fontSize: oneLine ? 14 : 16, fontWeight: FontWeight.w700)),
          ],
        );
    final t = totals;
    final items = [
      if (t.breast > Duration.zero) item(EntryType.breast, formatCompact(t.breast)),
      if (t.bottleMl > 0) item(EntryType.bottle, '${t.bottleMl} ml'),
      if (t.pumpedMl > 0) item(EntryType.pump, '${t.pumpedMl} ml'),
      if (t.diapers > 0) item(EntryType.diaper, '${t.diapers}'),
    ];
    if (oneLine) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(children: [for (final (i, w) in items.indexed) Padding(padding: EdgeInsets.only(left: i == 0 ? 0 : 10), child: w)]),
      );
    }
    return Wrap(spacing: 16, runSpacing: 6, children: items);
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.row, required this.now, required this.onTap});

  final DayRow row;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = row.totals;
    final hasTotals = t.breast > Duration.zero || t.bottleMl > 0 || t.pumpedMl > 0 || t.diapers > 0;
    final n = row.entries.length;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isSameDay(row.day, now) ? 'Today' : DateFormat('EEE').format(row.day), style: TextStyle(color: c.muted, fontSize: 14)),
                  Text(DateFormat('d MMM').format(row.day), style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: n == 0
                  ? Text('Nothing logged', style: TextStyle(color: c.muted, fontSize: 16))
                  : hasTotals
                      ? DaySummary(totals: t, oneLine: true)
                      : Text(n == 1 ? '1 entry' : '$n entries', style: TextStyle(color: c.ink, fontSize: 16)),
            ),
            Icon(Icons.chevron_right, color: c.muted),
          ],
        ),
      ),
    );
  }
}

/// A day's timeline in a drawer, from the "Each day" list.
Future<void> showDaySheet(BuildContext context, DayRow row, {required VoidCallback onOpenDay}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        final c = context.colors;
        final entries = row.entries.reversed.toList();
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Text(DateFormat('EEEE d MMMM').format(row.day), style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 10),
            DaySummary(totals: row.totals),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Nothing logged on this day.', style: TextStyle(color: c.muted, fontSize: 16)),
              ),
            for (var i = 0; i < entries.length; i++)
              TimelineRow(entry: entries[i], first: i == 0, last: i == entries.length - 1),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                onOpenDay();
              },
              child: const Text('Open on Today to edit'),
            ),
          ],
        );
      },
    ),
  );
}

/// One metric's average per day over the last weeks or months, as a chart
/// and a list.
class MetricChartSheet extends StatefulWidget {
  const MetricChartSheet({super.key, required this.metric, required this.period, required this.values});

  final Metric metric;
  final Period period;
  final List<PeriodValue> values;

  @override
  State<MetricChartSheet> createState() => _MetricChartSheetState();
}

class _MetricChartSheetState extends State<MetricChartSheet> {
  late int selected = widget.values.length - 1;

  String _name(DateTime start) =>
      widget.period == Period.week ? 'Week of ${DateFormat('d MMM').format(start)}' : DateFormat('MMMM y').format(start);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final metric = widget.metric;
    final tint = c.tintFor(metric.type);
    final values = widget.values;
    final pick = values.isEmpty ? null : values[selected];
    final span = widget.period == Period.week ? 'the last 8 weeks' : 'the last 6 months';
    return Material(
      color: c.card,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Column(
        children: [
          Container(
            color: tint.bg,
            padding: const EdgeInsets.fromLTRB(4, 8, 52, 8),
            child: Row(
              children: [
                IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: c.ink)),
                Expanded(child: Text(metric.label, textAlign: TextAlign.center, style: textTheme.headlineSmall)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Row(
                  children: [
                    TypeIcon(metric.type, size: 36),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Average per day for each of $span', style: textTheme.bodyMedium)),
                  ],
                ),
                const SizedBox(height: 18),
                if (pick != null)
                  Text.rich(TextSpan(children: [
                    TextSpan(text: metric.formatShort(pick.value), style: textTheme.titleMedium),
                    TextSpan(text: '   ${_name(pick.start)}', style: TextStyle(color: c.muted)),
                  ])),
                const SizedBox(height: 8),
                LineChart(
                  points: [for (final v in values) ChartPoint(DateFormat(widget.period == Period.week ? 'd MMM' : 'MMM').format(v.start), v.value)],
                  color: tint.line,
                  formatAxis: (v) => metric.formatShort(v),
                  selected: selected,
                  onSelect: (i) => setState(() => selected = i),
                  semanticLabel: 'Chart. ${[for (final v in values) '${_name(v.start)}: ${metric.formatShort(v.value)}'].join(', ')}',
                ),
                const SizedBox(height: 8),
                Text('Tap the chart to read a point.', style: textTheme.bodyMedium),
                const SizedBox(height: 22),
                Text('All values', style: textTheme.titleLarge),
                const SizedBox(height: 4),
                for (final v in values.reversed) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(child: Text(_name(v.start), style: TextStyle(color: c.ink, fontSize: 16))),
                        Text(metric.formatShort(v.value), style: textTheme.titleMedium),
                      ],
                    ),
                  ),
                  const Divider(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
