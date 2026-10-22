import 'dart:math';

import 'package:flutter/material.dart';

import '../painters.dart';

enum ArtKind { poodle, rock, bone }

/// Small illustration drawn with the game's own art (Rocky, a rock, a bone).
/// [time] drives the animation (running legs, bobbing bone).
class ArtIcon extends StatelessWidget {
  const ArtIcon(this.kind, this.time, {super.key, this.size = const Size(60, 44)});

  final ArtKind kind;
  final double time;
  final Size size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: size, painter: _ArtIconPainter(kind, time));
}

class _ArtIconPainter extends CustomPainter {
  _ArtIconPainter(this.kind, this.time);

  final ArtKind kind;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case ArtKind.poodle:
        // Sprite is ~104 x 97 units; fit it to the box height.
        final scale = size.height / 100;
        canvas.save();
        canvas.translate((size.width - 104 * scale) / 2, size.height);
        canvas.scale(scale);
        PoodleDrawer.draw(canvas,
            phase: time * 12,
            running: true,
            airborne: false,
            dead: false,
            idle: false,
            time: time);
        canvas.restore();
      case ArtKind.rock:
        final w = size.height * 0.78;
        GamePainter.drawRockShape(canvas,
            Rect.fromLTWH((size.width - w) / 2, size.height - w * 0.94, w, w * 0.92), 42);
      case ArtKind.bone:
        GamePainter.drawBone(canvas,
            Offset(size.width / 2, size.height / 2 + sin(time * 4) * 3), time, 0);
    }
  }

  @override
  bool shouldRepaint(covariant _ArtIconPainter old) =>
      old.time != time || old.kind != kind;
}
