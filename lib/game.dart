import 'dart:math';
import 'dart:ui';

enum GameState { ready, playing, over }

enum RockKind { small, big, pair, tall }

class Rock {
  Rock(this.x, this.kind, this.seed)
      : w = switch (kind) {
          RockKind.small => 34,
          RockKind.big => 48,
          RockKind.pair => 74,
          RockKind.tall => 38,
        },
        h = switch (kind) {
          RockKind.small => 30,
          RockKind.big => 44,
          RockKind.pair => 30,
          RockKind.tall => 58,
        };

  double x;
  final RockKind kind;
  final int seed;
  final double w;
  final double h;

  Rect hitbox(double groundY) =>
      Rect.fromLTWH(x + 5, groundY - h + 5, w - 10, h - 5);
}

class Bone {
  Bone(this.x, this.height, this.phase);
  double x;
  final double height; // above ground
  final double phase;
  bool taken = false;
}

class Particle {
  Particle(this.pos, this.vel, this.life, this.color, this.size,
      {this.gravity = 0})
      : maxLife = life;
  Offset pos;
  Offset vel;
  double life;
  final double maxLife;
  final Color color;
  final double size;
  final double gravity;
}

class Poodle {
  double y = 0; // height above ground
  double vy = 0;
  int jumpsUsed = 0;
  double runPhase = 0;
  bool get onGround => y <= 0.001;
}

class RockyRunGame {
  static const double gravity = 2300;
  static const double jumpVelocity = 770;
  static const double doubleJumpVelocity = 650;
  static const double poodleX = 90;
  static const double poodleW = 99; // ~104 units * PoodleDrawer.scale
  static const double poodleH = 92;

  final Random rng = Random();
  Size size = const Size(800, 400); // logical world size
  double viewScale = 1; // screen pixels per world unit (zooms out in portrait)
  GameState state = GameState.ready;
  final Poodle poodle = Poodle();
  final List<Rock> rocks = [];
  final List<Bone> bones = [];
  final List<Particle> particles = [];

  double speed = 0;
  double distance = 0;
  double playTime = 0;
  double overTime = 0;
  double time = 0;
  double worldScroll = 0;
  double shake = 0;
  double _nextRockIn = 0;
  double _nextBoneIn = 0;
  int bonesCollected = 0;
  int highScore = 0;

  /// Hearts: hitting a rock costs one; game over when none are left.
  static const int maxLives = 3;
  int lives = maxLives;

  /// Seconds of post-hit invincibility left (Rocky flashes meanwhile).
  double invincible = 0;
  static const double invincibleTime = 1.6;
  int _lastMilestone = 0;
  bool newRecord = false;

  void Function(String sfx)? onSfx;
  void Function()? onGameOver;

  int get score => (distance / 12).floor() + bonesCollected * 25;
  // Portrait screens get a thicker ground band so the sky isn't empty.
  double get groundY =>
      size.height * (size.height > size.width * 1.2 ? 0.70 : 0.80);

  Rect get poodleHitbox => Rect.fromLTWH(
        poodleX + 22,
        groundY - poodle.y - poodleH + 18,
        poodleW - 40,
        poodleH - 26,
      );

  void reset() {
    rocks.clear();
    bones.clear();
    poodle
      ..y = 0
      ..vy = 0
      ..jumpsUsed = 0;
    speed = 360;
    distance = 0;
    playTime = 0;
    overTime = 0;
    bonesCollected = 0;
    lives = maxLives;
    invincible = 0;
    _lastMilestone = 0;
    newRecord = false;
    _nextRockIn = size.width * 0.6;
    _nextBoneIn = 500;
  }

  void start() {
    reset();
    state = GameState.playing;
  }

  /// Back to the title screen (no rocks, Rocky standing idle).
  void backToTitle() {
    reset();
    particles.clear();
    shake = 0;
    state = GameState.ready;
  }

  void jump() {
    if (state != GameState.playing) return;
    if (poodle.onGround) {
      poodle
        ..vy = jumpVelocity
        ..jumpsUsed = 1;
      onSfx?.call('jump');
      _dust(6);
    } else if (poodle.jumpsUsed < 2) {
      poodle
        ..vy = doubleJumpVelocity
        ..jumpsUsed = 2;
      onSfx?.call('double_jump');
      _sparkle(Offset(poodleX + 30, groundY - poodle.y - 10),
          const Color(0xFFFFFFFF), 10);
    }
  }

  /// Releasing early gives a shorter hop (variable jump height).
  void releaseJump() {
    if (state == GameState.playing && poodle.vy > 320) poodle.vy = 320;
  }

  void update(double dt) {
    time += dt;
    _updateParticles(dt);
    shake = max(0, shake - dt * 40);
    invincible = max(0, invincible - dt);

    if (state == GameState.ready) {
      worldScroll += 80 * dt;
      poodle.runPhase += dt * 3;
      return;
    }
    if (state == GameState.over) {
      overTime += dt;
      // let the poodle fall back to the ground
      if (poodle.y > 0) {
        poodle.vy -= gravity * dt;
        poodle.y = max(0, poodle.y + poodle.vy * dt);
      }
      return;
    }

    playTime += dt;
    speed = min(860, 360 + playTime * 9);
    final dx = speed * dt;
    distance += dx;
    worldScroll += dx;

    // poodle physics
    final wasAir = !poodle.onGround;
    poodle.vy -= gravity * dt;
    poodle.y += poodle.vy * dt;
    if (poodle.y <= 0) {
      if (wasAir) _dust(5);
      poodle
        ..y = 0
        ..vy = 0
        ..jumpsUsed = 0;
    }
    if (poodle.onGround) poodle.runPhase += dt * speed / 26;

    // rocks
    for (final r in rocks) {
      r.x -= dx;
    }
    rocks.removeWhere((r) => r.x + r.w < -60);
    _nextRockIn -= dx;
    if (_nextRockIn <= 0) {
      _spawnRock();
      _nextRockIn = speed * (0.85 + rng.nextDouble() * 0.95) + 90;
    }

    // bones
    for (final b in bones) {
      b.x -= dx;
    }
    bones.removeWhere((b) => b.x < -40 || b.taken);
    _nextBoneIn -= dx;
    if (_nextBoneIn <= 0) {
      bones.add(Bone(size.width + 30, 30 + rng.nextDouble() * 110,
          rng.nextDouble() * pi * 2));
      _nextBoneIn = 700 + rng.nextDouble() * 1100;
    }

    // collisions
    final hb = poodleHitbox;
    if (invincible <= 0) {
      for (final r in rocks) {
        if (hb.overlaps(r.hitbox(groundY))) {
          _hitRock();
          if (state == GameState.over) return;
          break;
        }
      }
    }
    for (final b in bones) {
      final bob = sin(time * 4 + b.phase) * 5;
      final rect = Rect.fromCenter(
          center: Offset(b.x, groundY - b.height - bob), width: 34, height: 20);
      if (!b.taken && hb.overlaps(rect)) {
        b.taken = true;
        bonesCollected++;
        onSfx?.call('bone');
        _sparkle(rect.center, const Color(0xFFFFFFFF), 14);
      }
    }

    // milestone every 500 points
    final m = score ~/ 500;
    if (m > _lastMilestone) {
      _lastMilestone = m;
      onSfx?.call('milestone');
    }
  }

  void _spawnRock() {
    final kinds = <RockKind>[RockKind.small, RockKind.small, RockKind.big];
    if (speed > 430) kinds.add(RockKind.pair);
    if (speed > 520) kinds.add(RockKind.tall);
    final kind = kinds[rng.nextInt(kinds.length)];
    rocks.add(Rock(size.width + 20, kind, rng.nextInt(1 << 30)));
  }

  void _hitRock() {
    lives--;
    if (lives <= 0) {
      lives = 0;
      _die();
      return;
    }
    invincible = invincibleTime;
    shake = 8;
    onSfx?.call('hurt');
    // little bounce so Rocky pops up off the rock
    poodle
      ..vy = 520
      ..jumpsUsed = 1;
    _sparkle(Offset(poodleX + 50, groundY - poodle.y - 40),
        const Color(0xFFFF5A6E), 12);
  }

  void _die() {
    state = GameState.over;
    overTime = 0;
    shake = 14;
    onSfx?.call('hit');
    if (score > highScore) {
      highScore = score;
      newRecord = true;
    }
    _sparkle(Offset(poodleX + 50, groundY - poodle.y - 40),
        const Color(0xFFBC4A2C), 18);
    onGameOver?.call();
  }

  void _dust(int n) {
    for (var i = 0; i < n; i++) {
      particles.add(Particle(
        Offset(poodleX + 20 + rng.nextDouble() * 30, groundY - 2),
        Offset(-60 - rng.nextDouble() * 120, -20 - rng.nextDouble() * 60),
        0.35 + rng.nextDouble() * 0.25,
        const Color(0xFFC8955A),
        3 + rng.nextDouble() * 3,
        gravity: 200,
      ));
    }
  }

  void _sparkle(Offset at, Color color, int n) {
    for (var i = 0; i < n; i++) {
      final a = rng.nextDouble() * pi * 2;
      final s = 80 + rng.nextDouble() * 160;
      particles.add(Particle(at, Offset(cos(a) * s, sin(a) * s),
          0.4 + rng.nextDouble() * 0.3, color, 2 + rng.nextDouble() * 3,
          gravity: 300));
    }
  }

  void _updateParticles(double dt) {
    for (final p in particles) {
      p.vel = Offset(p.vel.dx, p.vel.dy + p.gravity * dt);
      p.pos += p.vel * dt;
      p.life -= dt;
    }
    particles.removeWhere((p) => p.life <= 0);
  }
}
