import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small trend line with a dot on the latest value.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, required this.color, this.fromZero = true, this.width = 64, this.height = 24});

  final List<double> values;
  final Color color;

  /// Measure from zero, so a small change in an average looks small. Readings
  /// such as weight use their own range instead.
  final bool fromZero;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(width: width, height: height, child: CustomPaint(painter: _SparklinePainter(values, color, fromZero))),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, this.color, this.fromZero);

  final List<double> values;
  final Color color;
  final bool fromZero;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final hi = values.reduce(math.max);
    final bottom = fromZero ? 0.0 : values.reduce(math.min);
    final span = hi - bottom;
    const pad = 4.0;
    Offset at(int i) {
      final x = values.length == 1 ? size.width - pad : pad + (size.width - 2 * pad) * i / (values.length - 1);
      // A flat series sits in the middle rather than on an edge.
      final t = span == 0 ? 0.5 : (values[i] - bottom) / span;
      return Offset(x, size.height - pad - (size.height - 2 * pad) * t);
    }

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(at(values.length - 1), 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values || old.color != color || old.fromZero != fromZero;
}
