import 'entry.dart';

/// Which counter is running: a breast side, or the pump.
enum TimerSide { left, right, pump }

/// A breastfeeding or pumping timer that keeps counting while the app is
/// closed. Elapsed time comes from the wall clock, so a suspended or reloaded
/// app loses nothing.
class LiveTimer {
  const LiveTimer({
    required this.type,
    required this.start,
    this.left = Duration.zero,
    this.right = Duration.zero,
    this.running,
    this.runningSince,
  });

  /// [EntryType.breast] or [EntryType.pump]. Pumping counts in [left].
  final EntryType type;

  /// When the feed or session began, for the entry's start time.
  final DateTime start;

  /// Time counted before [runningSince].
  final Duration left;
  final Duration right;

  final TimerSide? running;
  final DateTime? runningSince;

  bool get isRunning => running != null;

  Duration _live(DateTime now) =>
      runningSince == null ? Duration.zero : now.difference(runningSince!).isNegative ? Duration.zero : now.difference(runningSince!);

  Duration leftAt(DateTime now) => left + (running == TimerSide.left || running == TimerSide.pump ? _live(now) : Duration.zero);

  Duration rightAt(DateTime now) => right + (running == TimerSide.right ? _live(now) : Duration.zero);

  Duration totalAt(DateTime now) => leftAt(now) + rightAt(now);

  /// Starts [side]; a running side stops first, so only one counts at a time.
  LiveTimer startSide(TimerSide side, DateTime now) {
    final stopped = stop(now);
    return LiveTimer(type: type, start: stopped.start, left: stopped.left, right: stopped.right, running: side, runningSince: now);
  }

  LiveTimer stop(DateTime now) =>
      LiveTimer(type: type, start: start, left: leftAt(now), right: rightAt(now));

  /// Replaces the counted time for a side with a typed-in duration.
  LiveTimer edit(TimerSide side, Duration value, DateTime now) {
    final stopped = stop(now);
    return LiveTimer(
      type: type,
      start: stopped.start,
      left: side == TimerSide.right ? stopped.left : value,
      right: side == TimerSide.right ? value : stopped.right,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'start': start.toIso8601String(),
        'leftMs': left.inMilliseconds,
        'rightMs': right.inMilliseconds,
        'running': running?.name,
        'runningSince': runningSince?.toIso8601String(),
      };

  static LiveTimer? fromJson(Map<String, dynamic> json) {
    final type = EntryType.values.asNameMap()[json['type']];
    if (type == null) return null;
    return LiveTimer(
      type: type,
      start: DateTime.parse(json['start'] as String),
      left: Duration(milliseconds: (json['leftMs'] as num?)?.toInt() ?? 0),
      right: Duration(milliseconds: (json['rightMs'] as num?)?.toInt() ?? 0),
      running: TimerSide.values.asNameMap()[json['running']],
      runningSince: json['runningSince'] == null ? null : DateTime.parse(json['runningSince'] as String),
    );
  }
}
