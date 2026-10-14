import 'package:flutter/material.dart';

import '../l10n/strings.dart';

/// A frame over an image, in fractions (0..1) of the image.
@immutable
class CropFrame {
  const CropFrame(this.x, this.y, this.w, this.h);

  /// Centered, [size] of each side.
  const CropFrame.centered([double size = 0.7])
    : x = (1 - size) / 2,
      y = (1 - size) / 2,
      w = size,
      h = size;

  final double x;
  final double y;
  final double w;
  final double h;

  static const minSize = 0.12;

  /// Keeps the frame inside the image and at least [minSize] big.
  CropFrame clamped() {
    final nw = w.clamp(minSize, 1.0);
    final nh = h.clamp(minSize, 1.0);
    return CropFrame(x.clamp(0.0, 1 - nw), y.clamp(0.0, 1 - nh), nw, nh);
  }

  CropFrame moved(double dx, double dy) =>
      CropFrame(x + dx, y + dy, w, h).clamped();

  /// Moves one corner (0 top-left, 1 top-right, 2 bottom-right, 3 bottom-left).
  CropFrame resized(int corner, double dx, double dy) {
    var l = x, t = y, r = x + w, b = y + h;
    if (corner == 0 || corner == 3) l = (l + dx).clamp(0.0, r - minSize);
    if (corner == 1 || corner == 2) r = (r + dx).clamp(l + minSize, 1.0);
    if (corner == 0 || corner == 1) t = (t + dy).clamp(0.0, b - minSize);
    if (corner == 2 || corner == 3) b = (b + dy).clamp(t + minSize, 1.0);
    return CropFrame(l, t, r - l, b - t);
  }

  (double, double, double, double) get record => (x, y, w, h);

  @override
  bool operator ==(Object other) =>
      other is CropFrame &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h;

  @override
  int get hashCode => Object.hash(x, y, w, h);
}

/// Shows [image] (of [imageSize] pixels) fitted inside the available space
/// with a draggable, resizable frame (Pinduoduo / TikTok style).
/// [onChanged] fires while dragging; [onChangeEnd] when the finger lifts.
class CropBox extends StatelessWidget {
  const CropBox({
    super.key,
    required this.image,
    required this.imageSize,
    required this.frame,
    required this.onChanged,
    this.onChangeEnd,
  });

  final Widget image;
  final Size imageSize;
  final CropFrame frame;
  final ValueChanged<CropFrame> onChanged;
  final ValueChanged<CropFrame>? onChangeEnd;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final box = Size(c.maxWidth, c.maxHeight);
      final fitted = applyBoxFit(BoxFit.contain, imageSize, box).destination;
      final img = Alignment.center.inscribe(fitted, Offset.zero & box);
      final f = Rect.fromLTWH(
        img.left + frame.x * img.width,
        img.top + frame.y * img.height,
        frame.w * img.width,
        frame.h * img.height,
      );
      const handle = 34.0;
      Widget corner(int i, Alignment a) {
        final pos = switch (i) {
          0 => f.topLeft,
          1 => f.topRight,
          2 => f.bottomRight,
          _ => f.bottomLeft,
        };
        return Positioned(
          left: pos.dx - handle / 2,
          top: pos.dy - handle / 2,
          width: handle,
          height: handle,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => onChanged(
              frame.resized(i, d.delta.dx / img.width, d.delta.dy / img.height),
            ),
            onPanEnd: (_) => onChangeEnd?.call(frame),
            child: CustomPaint(painter: _CornerPainter(a)),
          ),
        );
      }

      return Stack(
        children: [
          Positioned.fromRect(rect: img, child: image),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _DimPainter(img, f)),
            ),
          ),
          Positioned.fromRect(
            rect: f,
            child: Semantics(
              label: S.cropHint,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) => onChanged(
                  frame.moved(d.delta.dx / img.width, d.delta.dy / img.height),
                ),
                onPanEnd: (_) => onChangeEnd?.call(frame),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          corner(0, Alignment.topLeft),
          corner(1, Alignment.topRight),
          corner(2, Alignment.bottomRight),
          corner(3, Alignment.bottomLeft),
        ],
      );
    },
  );
}

class _DimPainter extends CustomPainter {
  _DimPainter(this.image, this.frame);

  final Rect image;
  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(image)
      ..addRect(frame);
    canvas.drawPath(path, Paint()..color = const Color(0x8C000000));
  }

  @override
  bool shouldRepaint(_DimPainter old) =>
      old.image != image || old.frame != frame;
}

/// White "L" corner of the frame.
class _CornerPainter extends CustomPainter {
  _CornerPainter(this.corner);

  final Alignment corner;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const len = 16.0;
    final sx = corner.x < 0 ? 1.0 : -1.0;
    final sy = corner.y < 0 ? 1.0 : -1.0;
    final path = Path()
      ..moveTo(c.dx, c.dy + sy * len)
      ..lineTo(c.dx, c.dy)
      ..lineTo(c.dx + sx * len, c.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.corner != corner;
}
