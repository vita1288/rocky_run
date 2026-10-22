import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../strings.dart';
import '../ui/art_icon.dart';
import '../ui/style.dart';

/// Full-screen How to Play page.
/// Pops `true` when the player taps LET'S RUN! (start a run),
/// `false` when they exit with ✕ / BACK / Esc / the phone's Back button.
class HowToPlayPage extends StatefulWidget {
  const HowToPlayPage({super.key});

  @override
  State<HowToPlayPage> createState() => _HowToPlayPageState();
}

class _HowToPlayPageState extends State<HowToPlayPage>
    with SingleTickerProviderStateMixin {
  // Long-running clock that animates the little Rocky / bone icons.
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(minutes: 10))
        ..forward();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _run() => Navigator.of(context).pop(true);
  void _exit() => Navigator.of(context).pop(false);

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter) {
      _run();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.keyH) {
      _exit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  List<_Rule> _rules(double t) => [
        _Rule(ArtIcon(ArtKind.poodle, t), tr('Run!', 'Lari!'),
            tr('Rocky runs on his own and gets faster over time.',
                'Rocky berlari sendiri dan makin cepat seiring waktu.')),
        _Rule(const Icon(Icons.touch_app, size: 34, color: kPeach), tr('Jump', 'Lompat'),
            ctl(
                tr('Tap the screen, or press Space / ↑ / W.',
                    'Ketuk layar, atau tekan Spasi / ↑ / W.'),
                tr('Tap anywhere on the screen.', 'Ketuk di mana saja pada layar.'))),
        _Rule(const Icon(Icons.keyboard_double_arrow_up, size: 34, color: kPeach),
            tr('Double jump', 'Lompat ganda'),
            tr('Tap again while Rocky is in the air.',
                'Ketuk lagi saat Rocky masih di udara.')),
        _Rule(const Icon(Icons.height, size: 34, color: kPeach),
            tr('High or low', 'Tinggi atau rendah'),
            tr('Hold for a high jump, quick tap for a short hop.',
                'Tahan untuk lompat tinggi, ketuk cepat untuk lompat pendek.')),
        _Rule(ArtIcon(ArtKind.rock, t), tr('Dodge the rocks', 'Hindari batu'),
            tr('You have 3 hearts. Each rock bump costs one; lose all 3 and it\'s game over.',
                'Kamu punya 3 nyawa. Tiap menabrak batu berkurang satu; habis semua, kalah.')),
        _Rule(ArtIcon(ArtKind.bone, t), tr('Grab bones', 'Ambil tulang'),
            tr('+25 points each. A chime plays every 500 points.',
                '+25 poin per tulang. Ada bunyi setiap 500 poin.')),
        _Rule(const Icon(Icons.settings, size: 32, color: kPeach),
            tr('Sound & language', 'Suara & bahasa'),
            ctl(
                tr('Open ⚙ Settings from the title screen. M = quick mute.',
                    'Buka ⚙ Pengaturan dari layar judul. M = bisu cepat.'),
                tr('Open ⚙ Settings from the title screen. Tap the speaker for a quick mute.',
                    'Buka ⚙ Pengaturan dari layar judul. Ketuk speaker untuk bisu cepat.'))),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A1C14), Color(0xFF5A2618)],
          ),
        ),
        child: SafeArea(
          child: Focus(
            autofocus: true,
            onKeyEvent: _onKey,
            child: LayoutBuilder(builder: (context, box) {
              final compact = box.maxHeight < 560;
              final twoCols = box.maxWidth >= 700;
              return Column(
                children: [
                  // ---- top bar: exit + title ----
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _exit,
                          icon: const Icon(Icons.close, color: Colors.white),
                          tooltip: ctl(tr('Exit (Esc)', 'Keluar (Esc)'), tr('Exit', 'Keluar')),
                        ),
                        Expanded(
                          child: gameLabel(tr('HOW TO PLAY', 'CARA BERMAIN'),
                              compact ? 22 : 28,
                              color: kPeach),
                        ),
                        const SizedBox(width: 48), // balances the ✕ button
                      ],
                    ),
                  ),
                  // ---- rules ----
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: twoCols ? 820 : 560),
                          child: LayoutBuilder(builder: (context, inner) {
                            final colW =
                                twoCols ? (inner.maxWidth - 20) / 2 : inner.maxWidth;
                            return AnimatedBuilder(
                              animation: _clock,
                              builder: (context, _) {
                                final t = _clock.value * 600; // seconds
                                return Wrap(
                                  spacing: 20,
                                  children: [
                                    for (final r in _rules(t)) _RuleRow(r, width: colW),
                                  ],
                                );
                              },
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                  // ---- bottom bar: back + run ----
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, compact ? 6 : 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _exit,
                              style: outlinedOnDark.copyWith(
                                padding: const WidgetStatePropertyAll(
                                    EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                              ),
                              icon: const Icon(Icons.arrow_back),
                              label: Text(tr('BACK', 'KEMBALI')),
                            ),
                            FilledButton.icon(
                              onPressed: _run,
                              style: accentFilled.copyWith(
                                padding: const WidgetStatePropertyAll(
                                    EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
                                textStyle: const WidgetStatePropertyAll(TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1)),
                              ),
                              icon: const Icon(Icons.pets),
                              label: Text(tr("LET'S RUN!", 'AYO LARI!')),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 4 : 8),
                        Text(
                          tr('Created by Jovita', 'Dibuat oleh Jovita'),
                          style: const TextStyle(
                              color: kPeach,
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 0.8),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Rule {
  const _Rule(this.icon, this.title, this.text);
  final Widget icon;
  final String title;
  final String text;
}

class _RuleRow extends StatelessWidget {
  const _RuleRow(this.rule, {required this.width});
  final _Rule rule;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(width: 56, height: 42, child: Center(child: rule.icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rule.title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w900)),
                  Text(rule.text,
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
