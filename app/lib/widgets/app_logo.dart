import 'package:flutter/material.dart';

import '../theme.dart';

/// The app's mark: a sleepy baby face with a curl, saying "oh".
/// Matches assets/branding/ohbaby_mark.svg.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter()),
    );
  }
}

/// Mark plus the "Oh baby baby!" wordmark.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 30, this.color = Colors.white});

  static const name = 'Oh baby baby!';

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: name,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppMark(size: height),
            SizedBox(width: height * 0.3),
            Text(
              name,
              style: TextStyle(
                color: color,
                fontFamily: wordmarkFont,
                fontSize: height * 0.75,
                fontWeight: FontWeight.w800,
                fontVariations: const [FontVariation('wght', 800)],
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  static const _face = Color(0xFFF3DCCB);
  static const _cheek = Color(0xFFEBBCAA);
  static const _ink = Color(0xFF263241);

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 100 x 100 grid, same as the SVG.
    canvas.scale(size.width / 100, size.height / 100);

    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;

    // Curl of hair.
    canvas.drawPath(
      Path()
        ..moveTo(47, 23)
        ..cubicTo(40, 15, 46, 6, 54, 9)
        ..cubicTo(60, 11, 59, 19, 53, 19),
      stroke(_face, 5),
    );

    // Face and cheeks.
    canvas.drawCircle(const Offset(50, 57), 35, Paint()..color = _face);
    final cheek = Paint()..color = _cheek;
    canvas.drawCircle(const Offset(30, 66), 5, cheek);
    canvas.drawCircle(const Offset(70, 66), 5, cheek);

    // Sleepy eyes.
    final eyes = Path()
      ..moveTo(33, 55)
      ..quadraticBezierTo(39, 62, 45, 55)
      ..moveTo(55, 55)
      ..quadraticBezierTo(61, 62, 67, 55);
    canvas.drawPath(eyes, stroke(_ink, 4));

    // "Oh" mouth.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 71), width: 10, height: 12),
      Paint()..color = _ink,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => false;
}
