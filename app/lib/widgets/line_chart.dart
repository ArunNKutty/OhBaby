import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class ChartPoint {
  const ChartPoint(this.label, this.value);

  /// Shown under the axis for the first, middle and last points ("24 Aug").
  final String label;
  final double value;
}

/// A line with a dot per point, three gridlines and axis labels. Tapping
/// picks the nearest point and reports it through [onSelect].
class LineChart extends StatelessWidget {
  const LineChart({
    super.key,
    required this.points,
    required this.color,
    required this.formatAxis,
    required this.selected,
    required this.onSelect,
    this.semanticLabel,
  });

  final List<ChartPoint> points;
  final Color color;
  final String Function(double value) formatAxis;
  final int selected;
  final ValueChanged<int> onSelect;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: semanticLabel,
      child: LayoutBuilder(
        builder: (context, box) {
          void pick(Offset local) {
            if (points.isEmpty) return;
            final plot = _plotRect(box.biggest);
            final t = ((local.dx - plot.left) / plot.width).clamp(0.0, 1.0);
            onSelect((t * (points.length - 1)).round());
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => pick(d.localPosition),
            onHorizontalDragUpdate: (d) => pick(d.localPosition),
            child: CustomPaint(
              size: Size(box.maxWidth, 200),
              painter: _LinePainter(
                points: points,
                color: color,
                grid: c.divider,
                text: c.muted,
                formatAxis: formatAxis,
                selected: selected,
              ),
            ),
          );
        },
      ),
    );
  }
}

Rect _plotRect(Size size) => Rect.fromLTRB(56, 8, size.width - 8, size.height - 26);

double _niceMax(double v) {
  if (v <= 0) return 1;
  final mag = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  for (final step in [1, 2, 2.5, 5, 10]) {
    if (step * mag >= v) return step * mag;
  }
  return 10 * mag;
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.color,
    required this.grid,
    required this.text,
    required this.formatAxis,
    required this.selected,
  });

  final List<ChartPoint> points;
  final Color color;
  final Color grid;
  final Color text;
  final String Function(double) formatAxis;
  final int selected;

  void _label(Canvas canvas, String s, Offset at, {TextAlign align = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: uiFont, fontSize: 11, color: text)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.right => at.dx - tp.width,
      TextAlign.center => at.dx - tp.width / 2,
      _ => at.dx,
    };
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = _plotRect(size);
    final top = _niceMax(points.isEmpty ? 1 : points.map((p) => p.value).reduce(math.max));
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = plot.bottom - plot.height * i / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _label(canvas, formatAxis(top * i / 3), Offset(plot.left - 8, y), align: TextAlign.right);
    }
    if (points.isEmpty) return;
    Offset at(int i) => Offset(
          points.length == 1 ? plot.center.dx : plot.left + plot.width * i / (points.length - 1),
          plot.bottom - plot.height * (points[i].value / top).clamp(0.0, 1.0),
        );
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(at(i), i == selected ? 6 : 4.5, Paint()..color = color);
    }
    final labelled = {0, (points.length - 1) ~/ 2, points.length - 1};
    for (final i in labelled) {
      final align = i == 0 ? TextAlign.left : i == points.length - 1 ? TextAlign.right : TextAlign.center;
      final x = i == 0 ? plot.left : i == points.length - 1 ? plot.right : at(i).dx;
      _label(canvas, points[i].label, Offset(x, size.height - 10), align: align);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.points != points || old.selected != selected || old.color != color;
}
