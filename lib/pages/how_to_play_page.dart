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
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _PawPatternPainter()),
            SafeArea(
              child: Focus(
                autofocus: true,
                onKeyEvent: _onKey,
                child: LayoutBuilder(builder: (context, box) {
                  // Wide screens (PC / tablet landscape) get a centred panel;
                  // phones keep the full-height layout.
                  final wide = box.maxWidth >= 900 && box.maxHeight >= 500;
                  return wide ? _wideLayout() : _phoneLayout(box);
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- phone layout (title on top, rules, buttons at the bottom) ----------

  Widget _phoneLayout(BoxConstraints box) {
    final compact = box.maxHeight < 560;
    final twoCols = box.maxWidth >= 700;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(
            children: [
              _closeButton(),
              Expanded(
                child: gameLabel(tr('HOW TO PLAY', 'CARA BERMAIN'), compact ? 22 : 28,
                    color: kPeach),
              ),
              const SizedBox(width: 48), // balances the ✕ button
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: twoCols ? 820 : 560),
                child: LayoutBuilder(
                  builder: (context, inner) => _rulesWrap(
                      twoCols ? (inner.maxWidth - 20) / 2 : inner.maxWidth),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, compact ? 6 : 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [_backButton(), _runButton()],
              ),
              SizedBox(height: compact ? 4 : 8),
              _credit(),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- wide layout (one centred panel: Rocky + buttons | rules) ----------

  Widget _wideLayout() {
    return Stack(
      children: [
        Positioned(top: 4, left: 4, child: _closeButton()),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1060),
              child: Container(
                padding: const EdgeInsets.fromLTRB(28, 28, 32, 28),
                decoration: BoxDecoration(
                  color: const Color(0xCC2B1712),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: kAccent, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 10)),
                  ],
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // left: Rocky, title, buttons
                      SizedBox(
                        width: 290,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _clock,
                              builder: (context, _) => ArtIcon(
                                  ArtKind.poodle, _clock.value * 600,
                                  size: const Size(230, 190)),
                            ),
                            const SizedBox(height: 10),
                            gameLabel(tr('HOW TO PLAY', 'CARA BERMAIN'), 30, color: kPeach),
                            const SizedBox(height: 6),
                            Text(
                              tr('Help Rocky dodge the rocks!',
                                  'Bantu Rocky menghindari batu!'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(width: double.infinity, child: _runButton()),
                            const SizedBox(height: 10),
                            SizedBox(width: double.infinity, child: _backButton()),
                            const SizedBox(height: 14),
                            _credit(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 28),
                      Container(width: 1, height: 340, color: const Color(0x26FFFFFF)),
                      const SizedBox(width: 28),
                      // right: the rules in two columns
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, inner) =>
                              _rulesWrap((inner.maxWidth - 24) / 2, spacing: 24),
                        ),
                      ),
                    ],
                  ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- shared pieces ----------

  Widget _rulesWrap(double colW, {double spacing = 20}) {
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final t = _clock.value * 600; // seconds
        return Wrap(
          spacing: spacing,
          runSpacing: 4,
          children: [for (final r in _rules(t)) _RuleRow(r, width: colW)],
        );
      },
    );
  }

  Widget _closeButton() => IconButton(
        onPressed: _exit,
        icon: const Icon(Icons.close, color: Colors.white),
        tooltip: ctl(tr('Exit (Esc)', 'Keluar (Esc)'), tr('Exit', 'Keluar')),
      );

  Widget _backButton() => OutlinedButton.icon(
        onPressed: _exit,
        style: outlinedOnDark.copyWith(
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
        ),
        icon: const Icon(Icons.arrow_back),
        label: Text(tr('BACK', 'KEMBALI')),
      );

  Widget _runButton() => FilledButton.icon(
        onPressed: _run,
        style: accentFilled.copyWith(
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
          textStyle: const WidgetStatePropertyAll(
              TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ),
        icon: const Icon(Icons.pets),
        label: Text(tr("LET'S RUN!", 'AYO LARI!')),
      );

  Widget _credit() => Text(
        tr('Created by Jovita', 'Dibuat oleh Jovita'),
        style: const TextStyle(
            color: kPeach, fontSize: 12.5, fontStyle: FontStyle.italic, letterSpacing: 0.8),
      );
}

/// Faint paw prints scattered over the background.
class _PawPatternPainter extends CustomPainter {
  const _PawPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x0FFFFFFF);
    const step = 120.0;
    var row = 0;
    for (double y = 40; y < size.height + step; y += step * 0.75, row++) {
      final shift = row.isOdd ? step / 2 : 0.0;
      for (double x = 30 + shift; x < size.width + step; x += step) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(row.isOdd ? 0.35 : -0.3);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 22, height: 18), paint);
        for (final o in const [Offset(-13, -15), Offset(-4, -21), Offset(6, -21), Offset(14, -14)]) {
          canvas.drawOval(Rect.fromCenter(center: o, width: 8, height: 10), paint);
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
