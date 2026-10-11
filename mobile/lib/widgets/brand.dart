import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme.dart';
import '../l10n/strings.dart';

/// The app mark: "d" with the red roof in a white ringed circle
/// (assets/brand/logo-mark.svg).
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: S.appName,
    child: SvgPicture.asset(
      'assets/brand/logo-mark.svg',
      width: size,
      height: size,
      excludeFromSemantics: true,
      placeholderBuilder: (_) => SizedBox.square(dimension: size),
    ),
  );
}

/// The "moda HOUSE" wordmark (assets/brand/logo-wordmark.svg): thin rounded
/// "moda" letters with a red roof over the "d" and a red "HOUSE" below.
///
/// It is painted natively from the same geometry so the letters can switch
/// to white on dark backgrounds (logo-wordmark-light.svg) and "HOUSE" does
/// not depend on a font being available to the SVG renderer.
class LogoWordmark extends StatelessWidget {
  const LogoWordmark({super.key, this.height = 40, this.light});

  /// Height of the logo; the width follows the logo's aspect ratio.
  final double height;

  /// White letters (dark backgrounds). Defaults to the theme brightness.
  final bool? light;

  /// Cropped SVG viewBox: x 8..268, y 9..151.
  static const _viewW = 260.0;
  static const _viewH = 142.0;

  @override
  Widget build(BuildContext context) {
    final dark = light ?? Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: S.appName,
      image: true,
      child: CustomPaint(
        size: Size(height * _viewW / _viewH, height),
        painter: _WordmarkPainter(
          ink: dark ? Colors.white : AppPalette.ink,
          red: AppPalette.accent,
        ),
      ),
    );
  }
}

class _WordmarkPainter extends CustomPainter {
  _WordmarkPainter({required this.ink, required this.red});

  final Color ink;
  final Color red;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.height / LogoWordmark._viewH;
    canvas
      ..save()
      ..scale(k)
      ..translate(-8, -9);
    final letters = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // m
    final m = Path()
      ..moveTo(14, 110)
      ..lineTo(14, 76)
      ..arcToPoint(const Offset(46, 76), radius: const Radius.circular(16))
      ..lineTo(46, 110)
      ..moveTo(46, 76)
      ..arcToPoint(const Offset(78, 76), radius: const Radius.circular(16))
      ..lineTo(78, 110);
    canvas
      ..drawPath(m, letters)
      // o
      ..drawCircle(const Offset(114, 85), 24, letters)
      // d: bowl + tall stem
      ..drawCircle(const Offset(176, 85), 24, letters)
      ..drawLine(const Offset(200, 110), const Offset(200, 38), letters)
      // a: bowl + stem
      ..drawCircle(const Offset(238, 85), 24, letters)
      ..drawLine(const Offset(262, 62), const Offset(262, 110), letters);
    // The house roof above the d.
    final roof = Path()
      ..moveTo(184, 30)
      ..lineTo(200, 15)
      ..lineTo(216, 30);
    canvas.drawPath(
      roof,
      Paint()
        ..color = red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // "HOUSE", right-aligned to x=264 with the baseline at y=147.
    final tp = TextPainter(
      text: TextSpan(
        text: 'HOUSE',
        style: TextStyle(
          color: red,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.5,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final baseline = tp.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    // Trailing letter spacing is part of the width; the SVG anchors the glyphs.
    tp.paint(canvas, Offset(264 + 2.5 - tp.width, 147 - baseline));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WordmarkPainter old) => old.ink != ink || old.red != red;
}
