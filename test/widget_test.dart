import 'package:flutter_test/flutter_test.dart';
import 'package:rocky_run/game.dart';

void main() {
  test('poodle jumps and lands', () {
    final g = RockyRunGame()..start();
    g.jump();
    expect(g.poodle.vy, greaterThan(0));
    for (var i = 0; i < 120; i++) {
      g.rocks.clear();
      g.update(1 / 60);
    }
    expect(g.poodle.onGround, isTrue);
    expect(g.score, greaterThan(0));
  });
}
