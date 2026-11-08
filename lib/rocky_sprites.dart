import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// Optional painted sprite frames for Rocky.
///
/// Put PNG frames (transparent background, facing right) in assets/sprites/:
///   run_1.png … run_4.png   running cycle (at least run_1 is required)
///   jump.png                in the air          (optional, falls back to run_1)
///   idle_1.png, idle_2.png  standing / blinking (optional)
///   hurt.png                crash               (optional)
/// Prepare them with:  python tools/prepare_sprites.py <folder with raw images>
///
/// When no frames are found, the game keeps the code-drawn Rocky.
class RockySprites {
  static final Map<String, ui.Image> _img = {};
  static List<ui.Image> _run = [];
  static bool get ready => _run.isNotEmpty;

  /// Width of the sprite in game units (the drawn Rocky is ~104 wide).
  static const double width = 112;

  static Future<void> load() async {
    Future<ui.Image?> one(String name) async {
      try {
        final data = await rootBundle.load('assets/sprites/$name.png');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        return (await codec.getNextFrame()).image;
      } catch (_) {
        return null; // frame not provided
      }
    }

    for (final n in const [
      'run_1', 'run_2', 'run_3', 'run_4', 'jump', 'idle_1', 'idle_2', 'hurt'
    ]) {
      final im = await one(n);
      if (im != null) _img[n] = im;
    }
    _run = [
      for (final n in const ['run_1', 'run_2', 'run_3', 'run_4'])
        if (_img[n] != null) _img[n]!,
    ];
  }

  /// Draws Rocky with his feet at (0, 0) of the canvas, like PoodleDrawer.
  static void draw(
    Canvas c, {
    required double phase,
    required bool running,
    required bool airborne,
    required bool dead,
    required bool idle,
    required double time,
  }) {
    ui.Image frame;
    var bounce = 0.0;
    var squash = 1.0;
    if (airborne) {
      frame = _img['jump'] ?? _run.first;
    } else if (dead) {
      frame = _img['hurt'] ?? _img['idle_1'] ?? _run.first;
    } else if (running) {
      final cycle = (phase % (2 * pi)) / (2 * pi);
      frame = _run[(cycle * _run.length).floor() % _run.length];
      // A little hop + squash makes even 1–2 frames feel like running.
      bounce = -sin(phase).abs() * 4;
      squash = 1 + sin(phase * 2) * 0.03;
    } else {
      final blink = (time % 3.2) < 0.14 && _img['idle_2'] != null;
      frame = blink ? _img['idle_2']! : (_img['idle_1'] ?? _run.first);
      bounce = sin(time * 3) * 1.2;
    }

    // All frames share one scale (taken from run_1) and are centred on it,
    // so poses keep their real size and Rocky doesn't jitter between frames.
    final ref = _run.first;
    final k = width / ref.width;
    final w = frame.width * k;
    final h = frame.height * k;
    final x = (width - w) / 2;
    c.save();
    c.translate(-4, bounce);
    c.scale(1 / squash, squash);
    c.drawImageRect(
      frame,
      Rect.fromLTWH(0, 0, frame.width.toDouble(), frame.height.toDouble()),
      Rect.fromLTWH(x, -h, w, h),
      Paint()..filterQuality = FilterQuality.medium,
    );
    c.restore();
  }
}
