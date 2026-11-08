import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'game.dart';


class GamePainter extends CustomPainter {
  /// [repaint] lets the game redraw every frame without rebuilding widgets.
  GamePainter(this.game, {Listenable? repaint}) : super(repaint: repaint);
  final RockyRunGame game;

  @override
  void paint(Canvas canvas, Size screen) {
    final g = game;
    final size = g.size; // draw in world units
    canvas.save();
    canvas.scale(g.viewScale);
    if (g.shake > 0) {
      final r = Random();
      canvas.translate((r.nextDouble() - 0.5) * g.shake,
          (r.nextDouble() - 0.5) * g.shake);
    }
    _sky(canvas, size);
    // Hard mode: the sky turns to a warm sunset.
    if (g.hardMode) {
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0x40FF6A3D));
    }
    _clouds(canvas, size, g.worldScroll * 0.08);
    _hills(canvas, size, g.worldScroll * 0.15, g.groundY * 0.775, 38, 0.006,
        const Color(0xFFB9A3D6));
    _hills(canvas, size, g.worldScroll * 0.35, g.groundY * 0.9, 26, 0.011,
        const Color(0xFF86BF73));
    _ground(canvas, size, g.groundY, g.worldScroll);

    for (final b in g.bones) {
      if (!b.taken) _bone(canvas, b, g);
    }
    for (final r in g.rocks) {
      _rock(canvas, r, g.groundY);
    }

    // poodle shadow
    final sScale = (1 - (g.poodle.y / 220)).clamp(0.35, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(RockyRunGame.poodleX + 48, g.groundY + 3),
          width: 74 * sScale,
          height: 9 * sScale),
      Paint()..color = const Color(0x33000000),
    );

    canvas.save();
    canvas.translate(RockyRunGame.poodleX, g.groundY - g.poodle.y);
    canvas.scale(PoodleDrawer.scale);
    if (g.state == GameState.playing && !g.poodle.onGround) {
      canvas.translate(50, -40);
      canvas.rotate((-g.poodle.vy * 0.00028).clamp(-0.25, 0.3));
      canvas.translate(-50, 40);
    }
    // Flash while invincible after losing a heart.
    final flashing = g.invincible > 0 && (g.invincible * 12).floor().isEven;
    if (flashing) {
      canvas.saveLayer(null, Paint()..color = const Color(0x59FFFFFF));
    }
    PoodleDrawer.draw(
      canvas,
      phase: g.poodle.runPhase,
      running: g.state == GameState.playing && g.poodle.onGround,
      airborne: g.state == GameState.playing && !g.poodle.onGround,
      dead: g.state == GameState.over,
      idle: g.state == GameState.ready,
      time: g.time,
    );
    if (flashing) canvas.restore();
    canvas.restore();

    for (final p in g.particles) {
      final a = (p.life / p.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(p.pos, p.size * (0.5 + a * 0.5),
          Paint()..color = p.color.withAlpha((a * 255).round()));
    }
    canvas.restore();
  }

  void _sky(Canvas c, Size s) {
    final rect = Offset.zero & s;
    c.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6EC3F0), Color(0xFFBDE6F7), Color(0xFFFFE6BF)],
        ).createShader(rect),
    );
    final sun = Offset(s.width * 0.82, s.height * 0.18);
    c.drawCircle(sun, 62, Paint()..color = const Color(0x33FFF3B0));
    c.drawCircle(sun, 44, Paint()..color = const Color(0x66FFE98A));
    c.drawCircle(sun, 32, Paint()..color = const Color(0xFFFFE066));
  }

  void _clouds(Canvas c, Size s, double off) {
    final p = Paint()..color = const Color(0xE6FFFFFF);
    const spacing = 320.0;
    final count = (s.width / spacing).ceil() + 2;
    for (var i = 0; i < count; i++) {
      final idx = (off / spacing).floor() + i;
      final x = idx * spacing - off + (idx * 97 % 120);
      final y = s.height * (0.12 + (idx * 53 % 30) / 100);
      c.drawCircle(Offset(x, y), 18, p);
      c.drawCircle(Offset(x + 20, y - 10), 22, p);
      c.drawCircle(Offset(x + 44, y), 17, p);
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x - 6, y - 2, 64, 18), const Radius.circular(9)),
          p);
    }
  }

  void _hills(Canvas c, Size s, double off, double base, double amp, double k,
      Color color) {
    final path = Path()..moveTo(0, s.height);
    for (double x = 0; x <= s.width + 8; x += 8) {
      final wx = x + off;
      final y = base -
          amp * (0.6 * sin(wx * k) + 0.4 * sin(wx * k * 2.3 + 1.3)).abs() -
          amp * 0.3 * sin(wx * k * 0.5);
      path.lineTo(x, y);
    }
    path
      ..lineTo(s.width, s.height)
      ..close();
    c.drawPath(path, Paint()..color = color);
  }

  void _ground(Canvas c, Size s, double gy, double scroll) {
    // Extends far below the world so a taller screen (e.g. Safari's address
    // bar hiding mid-run) never shows an empty strip under the ground.
    c.drawRect(Rect.fromLTWH(0, gy, s.width, s.height - gy + 2000),
        Paint()..color = const Color(0xFFD9A066));
    c.drawRect(Rect.fromLTWH(0, gy, s.width, 9),
        Paint()..color = const Color(0xFF6DB353));
    c.drawRect(Rect.fromLTWH(0, gy + 9, s.width, 3),
        Paint()..color = const Color(0xFF4E8F3A));
    // scrolling pebbles
    final peb = Paint()..color = const Color(0xFFB98146);
    const sp = 46.0;
    final start = -(scroll % sp);
    var i = (scroll / sp).floor();
    for (double x = start; x < s.width + sp; x += sp, i++) {
      final row = (i * 7) % 3;
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x + (i * 13 % 20), gy + 20 + row * 16,
                  8 + (i % 3) * 4.0, 4),
              const Radius.circular(2)),
          peb);
    }
  }

  void _rock(Canvas c, Rock r, double gy) {
    if (r.kind == RockKind.pair) {
      drawRockShape(c, Rect.fromLTWH(r.x, gy - 30, 36, 30), r.seed);
      drawRockShape(c, Rect.fromLTWH(r.x + 36, gy - 26, 38, 26), r.seed + 7);
    } else {
      drawRockShape(c, Rect.fromLTWH(r.x, gy - r.h, r.w, r.h), r.seed);
    }
  }

  /// Rounded mossy rock filling [b]; also used on the How to Play screen.
  static void drawRockShape(Canvas c, Rect b, int seed) {
    final rnd = Random(seed);
    final path = Path()
      ..addRRect(RRect.fromRectAndCorners(
        b,
        topLeft: Radius.elliptical(b.width * (0.42 + rnd.nextDouble() * 0.12), b.height * 0.75),
        topRight: Radius.elliptical(b.width * (0.36 + rnd.nextDouble() * 0.12), b.height * 0.6),
        bottomLeft: const Radius.circular(3),
        bottomRight: const Radius.circular(3),
      ));
    c.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(b.topLeft, b.bottomRight,
              const [Color(0xFFC3C9D2), Color(0xFF8D94A0), Color(0xFF666C78)],
              const [0.0, 0.55, 1.0]));
    c.save();
    c.clipPath(path);
    // soft top-left highlight
    c.drawOval(
        Rect.fromLTWH(b.left + b.width * 0.12, b.top + b.height * 0.12,
            b.width * 0.38, b.height * 0.22),
        Paint()..color = const Color(0x8CFFFFFF));
    // moss tuft
    final moss = Paint()..color = const Color(0xFF7BC86C);
    final mx = b.left + b.width * (0.35 + rnd.nextDouble() * 0.3);
    c.drawOval(Rect.fromCenter(center: Offset(mx, b.top + 2), width: b.width * 0.5, height: 10), moss);
    c.restore();
    c.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF3E434A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round);
  }

  void _bone(Canvas c, Bone b, RockyRunGame g) {
    final bob = sin(g.time * 4 + b.phase) * 5;
    drawBone(c, Offset(b.x, g.groundY - b.height - bob), g.time, b.phase);
  }

  /// Glossy white bone centred at [center]; also used on the How to Play screen.
  static void drawBone(Canvas c, Offset center, double time, double phase) {
    c.save();
    c.translate(center.dx, center.dy);
    // glow
    c.drawCircle(
        Offset.zero,
        26,
        Paint()
          ..shader = ui.Gradient.radial(Offset.zero, 26,
              const [Color(0x99FFFFFF), Color(0x00FFFFFF)]));
    c.rotate(sin(time * 2 + phase) * 0.25 - 0.35);
    Path shape(double grow) {
      final p = Path()
        ..addRRect(RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 22 + grow, height: 8 + grow),
            const Radius.circular(4)));
      for (final o in const [Offset(-12, -4.5), Offset(-12, 4.5), Offset(12, -4.5), Offset(12, 4.5)]) {
        p.addOval(Rect.fromCircle(center: o, radius: 5.6 + grow / 2));
      }
      return p;
    }
    c.drawPath(shape(3.2), Paint()..color = const Color(0xFF8C7B5E));
    c.drawPath(
        shape(0),
        Paint()
          ..shader = ui.Gradient.linear(const Offset(0, -10), const Offset(0, 10),
              const [Color(0xFFFFFFFF), Color(0xFFF6F0E4), Color(0xFFD8CCB6)],
              const [0.0, 0.5, 1.0]));
    c.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -3.4, 14, 2.4), const Radius.circular(1.2)),
        Paint()..color = const Color(0xD9FFFFFF));
    c.drawCircle(const Offset(-13.5, -6), 1.8, Paint()..color = const Color(0xD9FFFFFF));
    c.restore();
    // twinkle
    final tw = (sin(time * 6 + phase) + 1) / 2;
    if (tw > 0.6) {
      final s = (tw - 0.6) * 18;
      final sp = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      final at = center + const Offset(12, -12);
      c.drawLine(at - Offset(s, 0), at + Offset(s, 0), sp);
      c.drawLine(at - Offset(0, s), at + Offset(0, s), sp);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Draws Rocky, a chibi red toy poodle (original design).
/// Origin = bottom-left of the sprite on the ground, negative y is up.
/// Unscaled sprite is ~104 x 97 units; [scale] maps it to screen pixels.
class PoodleDrawer {
  static const double scale = 0.95;

  // Caramel / apricot toy poodle palette
  static const _light = Color(0xFFEFC08A);
  static const _base = Color(0xFFCF8B4E);
  static const _dark = Color(0xFFA0602F);
  static const _deep = Color(0xFF74431F);
  static const _outline = Color(0xFF6A3B1C);
  static const _muzzle = Color(0xFFE3AE74);
  static const _muzzleLight = Color(0xFFF6D7AE);
  static const _earLight = Color(0xFFDDA066);
  static const _earBase = Color(0xFFBF7B42);
  static const _earDark = Color(0xFF94592B);
  static const _eye = Color(0xFF2A1408);
  static const _mouth = Color(0xFF4A1A0E);

  // ---- frame cache --------------------------------------------------------
  // Rocky is ~30 shaded fur shapes. Drawing them every frame is slow on iOS
  // Safari, so each animation frame is drawn ONCE into an image and reused.
  // Running = 16 frames, idle = 24 frames (2.4 s loop), jump + crash = 1 each.

  static const int _runFrames = 16;
  static const int _idleFrames = 24;
  static const double _idleLoop = 2.4; // seconds
  static const double _px = 3; // image pixels per sprite unit (sharp on phones)
  static const Rect _bounds = Rect.fromLTWH(-14, -112, 130, 124);
  static final Map<String, ui.Image> _frames = {};

  /// Pre-renders Rocky's animation frames ahead of time, a few per call, so
  /// no frame is ever created in the middle of a run or a jump (creating one
  /// on the spot causes a visible hitch on iOS Safari). Returns true when done.
  static int _warmIndex = 0;
  static bool warmUpStep({int perCall = 3}) {
    const total = 3 + _runFrames + _idleFrames;
    if (_warmIndex >= total) return true;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    for (var n = 0; n < perCall && _warmIndex < total; n++, _warmIndex++) {
      final i = _warmIndex;
      if (i < 3) {
        // most urgent first: jump, crash, standing poses
        draw(c, phase: 0, running: false, airborne: i == 0, dead: i == 1,
            idle: false, time: 0);
      } else if (i < 3 + _runFrames) {
        final f = i - 3;
        draw(c, phase: (f + 0.5) * 2 * pi / _runFrames, running: true,
            airborne: false, dead: false, idle: false, time: 0);
      } else {
        final f = i - 3 - _runFrames;
        draw(c, phase: 0, running: false, airborne: false, dead: false,
            idle: true, time: (f + 0.5) * _idleLoop / _idleFrames);
      }
    }
    rec.endRecording().dispose();
    return _warmIndex >= total;
  }

  static void draw(
    Canvas c, {
    required double phase,
    required bool running,
    required bool airborne,
    required bool dead,
    required bool idle,
    required double time,
  }) {
    late final String key;
    late final void Function(Canvas) paintFrame;
    if (running) {
      final f = ((phase % (2 * pi)) / (2 * pi) * _runFrames).floor() % _runFrames;
      final ph = f * 2 * pi / _runFrames;
      key = 'run$f';
      paintFrame = (k) => _drawPose(k,
          phase: ph, running: true, airborne: false, dead: false,
          bob: -sin(ph).abs() * 3, wag: sin(ph * 2) * 4, blink: false);
    } else if (idle) {
      final f = ((time % _idleLoop) / _idleLoop * _idleFrames).floor() % _idleFrames;
      final t = f * _idleLoop / _idleFrames;
      key = 'idle$f';
      paintFrame = (k) => _drawPose(k,
          phase: 0, running: false, airborne: false, dead: false,
          bob: sin(t * 2 * pi / _idleLoop) * 1.2,
          wag: sin(t * 2 * pi / 0.4) * 4,
          blink: t >= 2.2 && t < 2.34);
    } else {
      key = airborne ? 'air' : (dead ? 'dead' : 'stand');
      paintFrame = (k) => _drawPose(k,
          phase: 0, running: false, airborne: airborne, dead: dead,
          bob: 0, wag: 0, blink: false);
    }

    var img = _frames[key];
    if (img == null) {
      final rec = ui.PictureRecorder();
      final k = Canvas(rec);
      k.scale(_px);
      k.translate(-_bounds.left, -_bounds.top);
      paintFrame(k);
      final pic = rec.endRecording();
      img = pic.toImageSync(
          (_bounds.width * _px).ceil(), (_bounds.height * _px).ceil());
      pic.dispose();
      _frames[key] = img;
    }
    c.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      _bounds,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  static void _drawPose(
    Canvas c, {
    required double phase,
    required bool running,
    required bool airborne,
    required bool dead,
    required double bob,
    required double wag,
    required bool blink,
  }) {
    final sA = running ? sin(phase) : 0.0;
    final sB = running ? sin(phase + pi) : 0.0;
    final lA = running ? max(0.0, cos(phase)) * 4 : 0.0;
    final lB = running ? max(0.0, cos(phase + pi)) * 4 : 0.0;
    final earFlap = airborne ? -6.0 : (running ? sin(phase) * 2 : 0.0);

    // back legs
    _leg(c, 20, airborne ? -10 : sA * 9, lA, false, bob);
    _leg(c, 30, airborne ? -7 : sB * 9, lB, false, bob);

    c.save();
    c.translate(0, bob);
    // tail
    final tail = Path()
      ..moveTo(16, -40)
      ..quadraticBezierTo(8, -46, 7 + wag * 0.3, -54 + wag * 0.5);
    c.drawPath(tail, _stroke(_outline, 7));
    c.drawPath(tail, _stroke(_dark, 4));
    _fluffy(c, 6 + wag * 0.3, -57 + wag * 0.5, 9.5, 9.5, 11);
    // body
    _fluffy(c, 37, -34, 26, 18, 21);
    c.restore();

    // front legs
    _leg(c, 46, airborne ? 11 : sB * 9, lB, true, bob);
    _leg(c, 56, airborne ? 14 : sA * 9, lA, true, bob);

    c.save();
    c.translate(0, bob * 1.2);
    _fluffy(c, 56, -37, 13, 13, 31); // chest
    _fluffy(c, 63, -85, 17, 11, 41); // top knot
    _fluffy(c, 66, -62, 27, 25, 51); // head
    _fluffy(c, 87, -51, 13, 10, 61,
        light: _muzzleLight, base: _muzzle, dark: _base); // muzzle

    // mouth: open smile with the tongue out
    if (!dead) {
      final mouth = Path()
        ..moveTo(81, -47)
        ..quadraticBezierTo(89, -36, 98, -47.5)
        ..quadraticBezierTo(89, -43.5, 81, -47)
        ..close();
      c.drawPath(mouth, Paint()..color = _mouth);
      _oval(c, 89.5, -37.5, 5.2, 7, const Color(0xFFEF7A8A));
      c.drawLine(const Offset(89.5, -42), const Offset(89.5, -34),
          _stroke(const Color(0xFFC9566A), 1.1));
    } else {
      c.drawPath(
          Path()
            ..moveTo(83, -46)
            ..quadraticBezierTo(89, -49, 95, -46),
          _stroke(_mouth, 1.8));
    }

    // nose
    _oval(c, 96.5, -55.5, 5.8, 4.8, const Color(0xFF3B1D10));
    _oval(c, 95, -57.4, 2.2, 1.2, const Color(0xB3FFFFFF));
    // blush
    _oval(c, 78, -52, 5, 3, const Color(0x61FF828C));

    // eye: big round brown eye with highlights, soft brow
    if (dead) {
      final x = _stroke(_eye, 2.4);
      c.drawLine(const Offset(70, -69), const Offset(77, -62), x);
      c.drawLine(const Offset(77, -69), const Offset(70, -62), x);
    } else if (blink) {
      c.drawPath(
          Path()
            ..moveTo(69, -64)
            ..quadraticBezierTo(73.5, -61, 78, -64),
          _stroke(_eye, 2.2));
    } else {
      _oval(c, 73.5, -64.5, 7.2, 7.8, _eye);
      _oval(c, 73.8, -63.6, 5.4, 5.8, const Color(0xFF7A4320)); // iris
      _oval(c, 73.8, -63.2, 3.2, 3.6, _eye); // pupil
      c.drawCircle(const Offset(76, -67.6), 2.9, Paint()..color = Colors.white);
      c.drawCircle(
          const Offset(71.6, -60.8), 1.3, Paint()..color = const Color(0xE6FFFFFF));
      c.drawPath(
          Path()
            ..moveTo(68.5, -75.5)
            ..quadraticBezierTo(73.5, -78, 78.5, -75),
          _stroke(const Color(0xB36A3B1C), 1.4)); // brow
    }

    // long fluffy ear
    c.save();
    c.translate(55, -72);
    c.rotate(earFlap * 0.03);
    c.translate(-55, 72);
    _fluffy(c, 52, -55 + earFlap * 0.4, 10, 12, 71,
        light: _earLight, base: _earBase, dark: _earDark);
    _fluffy(c, 51, -45 + earFlap * 0.7, 9, 9, 72,
        light: _earLight, base: _earBase, dark: _earDark);
    c.restore();

    c.restore();
  }

  static void _leg(Canvas c, double x, double swing, double lift, bool front,
      double bob) {
    final top = Offset(x, -24 + bob);
    final foot = Offset(x + swing, -7 - lift);
    c.drawLine(top, foot, _stroke(_outline, 12));
    c.drawLine(top, foot, _stroke(front ? _base : _dark, 9.4));
    _fluffy(c, foot.dx + 1, foot.dy, 8.5, 7, (x * 7).round(),
        light: front ? _light : _base,
        base: front ? _base : _dark,
        dark: front ? _dark : _deep);
  }

  /// Curly poodle fur blob: many small scallops, soft warm outline,
  /// radial shading and ringlet curls.
  static void _fluffy(Canvas c, double cx, double cy, double rx, double ry,
      int seed,
      {Color light = _light, Color base = _base, Color dark = _dark}) {
    final r = _Lcg(seed);
    final n = max(9, ((rx + ry) * 0.62).round());
    final br = min(rx, ry) * 0.27 + 1.2;
    final bumps = <List<double>>[];
    for (var i = 0; i < n; i++) {
      final a = i / n * pi * 2 + r.next() * 0.25;
      bumps.add([
        cx + cos(a) * rx * 0.93,
        cy + sin(a) * ry * 0.93,
        br * (0.8 + r.next() * 0.4),
        sin(a),
      ]);
    }
    final outline = Paint()..color = _outline;
    for (final b in bumps) {
      c.drawCircle(Offset(b[0], b[1]), b[2] + 1.3, outline);
    }
    _oval(c, cx, cy, rx * 0.95 + 1.3, ry * 0.95 + 1.3, _outline);
    for (final b in bumps) {
      c.drawCircle(Offset(b[0], b[1]), b[2],
          Paint()..color = Color.lerp(base, dark, max(0.0, b[3]) * 0.6)!);
    }
    c.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 1.9, height: ry * 1.9),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, cy),
          max(rx, ry),
          [light, base, Color.lerp(base, dark, 0.5)!],
          const [0.0, 0.6, 1.0],
          TileMode.clamp,
          null,
          Offset(cx - rx * 0.3, cy - ry * 0.35),
          0,
        ),
    );
    // ringlet curls
    final glow = Paint()..color = const Color(0x38FFE4BE);
    final curl = _stroke(const Color(0x616E3C19), 1.1);
    final k = (rx * ry / 75).round();
    for (var i = 0; i < k; i++) {
      final a = r.next() * pi * 2;
      final d = sqrt(r.next()) * 0.78;
      final x = cx + cos(a) * rx * d;
      final y = cy + sin(a) * ry * d;
      final rr = 1.6 + r.next() * 1.4;
      c.drawCircle(Offset(x, y), rr, glow);
      c.drawArc(Rect.fromCircle(center: Offset(x, y), radius: rr), 0.2,
          pi * 1.4, false, curl);
    }
    // top sheen
    c.save();
    c.translate(cx - rx * 0.25, cy - ry * 0.45);
    c.rotate(-0.3);
    c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 0.76, height: ry * 0.4),
        Paint()..color = const Color(0x40FFECCD));
    c.restore();
  }

  static void _oval(Canvas c, double x, double y, double rx, double ry,
      Color color) {
    c.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2),
        Paint()..color = color);
  }

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;
}

/// Tiny deterministic RNG so the fur pattern is identical every frame.
class _Lcg {
  _Lcg(int seed) : _s = seed & 0xFFFFFFFF;
  int _s;
  double next() {
    _s = (_s * 1664525 + 1013904223) & 0xFFFFFFFF;
    return _s / 4294967296;
  }
}
