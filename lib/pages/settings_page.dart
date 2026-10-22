import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game_audio.dart';
import '../strings.dart';
import '../ui/art_icon.dart';
import '../ui/style.dart';

/// Full-screen Settings page: sound levels, language, best score, about.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.audio,
    required this.bestScore,
    required this.onSave,
    required this.onClearBest,
  });

  final GameAudio audio;
  final int bestScore;
  final VoidCallback onSave; // persist audio + language
  final Future<void> Function() onClearBest;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late int _best = widget.bestScore;

  GameAudio get _audio => widget.audio;
  double get _music => _audio.bgmOn ? _audio.bgmVolume : 0;
  double get _sfx => _audio.sfxOn ? _audio.sfxVolume : 0;

  void _setMusic(double v) {
    _audio.bgmOn = v > 0;
    if (v > 0) _audio.setBgmVolume(v);
    setState(() {});
  }

  void _setSfx(double v) {
    _audio.sfxOn = v > 0;
    if (v > 0) _audio.setSfxVolume(v);
    setState(() {});
  }

  void _setLanguage(bool indonesian) {
    setState(() => useIndonesian = indonesian);
    widget.onSave();
  }

  Future<void> _confirmClearBest() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Clear best score?', 'Hapus skor terbaik?')),
        content: Text(tr('Your best score ($_best) will be set back to 0.',
            'Skor terbaikmu ($_best) akan kembali ke 0.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Cancel', 'Batal')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD9434B)),
            child: Text(tr('Clear', 'Hapus')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.onClearBest();
      setState(() => _best = 0);
    }
  }

  void _back() {
    widget.onSave();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, __) => widget.onSave(),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF6EC3F0), Color(0xFFBDE6F7), Color(0xFFFFE6BF)],
            ),
          ),
          child: SafeArea(
            child: Focus(
              autofocus: true,
              onKeyEvent: (node, e) {
                if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
                  _back();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Column(
                children: [
                  _topBar(),
                  Expanded(
                    child: LayoutBuilder(builder: (context, box) {
                      final twoCols = box.maxWidth >= 700;
                      final cardW = twoCols
                          ? (box.maxWidth.clamp(0.0, 900.0) - 46) / 2
                          : (box.maxWidth.clamp(0.0, 560.0) - 32);
                      final cards = [
                        _soundCard(),
                        _languageCard(),
                        _bestCard(),
                        _aboutCard(),
                      ];
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: Center(
                          child: Wrap(
                            spacing: 14,
                            runSpacing: 12,
                            children: [
                              for (final c in cards) SizedBox(width: cardW, child: c),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: _back,
            icon: const Icon(Icons.arrow_back_rounded, color: kInk),
            tooltip: ctl(tr('Back (Esc)', 'Kembali (Esc)'), tr('Back', 'Kembali')),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              tr('Settings', 'Pengaturan'),
              style: const TextStyle(
                  color: kInk, fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ),
          const ArtIcon(ArtKind.poodle, 0, size: Size(54, 46)),
        ],
      ),
    );
  }

  // ---------- cards ----------

  Widget _card({required IconData icon, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xF2FFFFFF),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: kAccent, size: 20),
            const SizedBox(width: 8),
            Text(title.toUpperCase(),
                style: const TextStyle(
                    color: kAccent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4)),
          ]),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _soundCard() {
    return _card(
      icon: Icons.headphones,
      title: tr('Sound', 'Suara'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _levelRow(
            icon: Icons.music_note,
            label: tr('Music', 'Musik'),
            value: _music,
            onChanged: _setMusic,
            onChangeEnd: (_) => widget.onSave(),
          ),
          _levelRow(
            icon: Icons.graphic_eq,
            label: tr('Sound effects', 'Efek suara'),
            value: _sfx,
            onChanged: _setSfx,
            onChangeEnd: (_) {
              _audio.play('bone'); // preview the new level
              widget.onSave();
            },
          ),
          Text(tr('Slide to the left to turn it off.', 'Geser ke kiri untuk mematikan.'),
              style: const TextStyle(color: Colors.black45, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _levelRow({
    required IconData icon,
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    final off = value <= 0;
    return Row(
      children: [
        Icon(off ? Icons.volume_off : icon, color: off ? Colors.black38 : kInk, size: 20),
        const SizedBox(width: 8),
        SizedBox(
          width: 104,
          child: Text(label,
              style: const TextStyle(color: kInk, fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: Slider(
            value: value,
            divisions: 10,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
            activeColor: kAccent,
            inactiveColor: const Color(0x33E8714A),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(off ? tr('Off', 'Mati') : '${(value * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: off ? Colors.black38 : kInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _languageCard() {
    Widget chip(String text, bool indonesian) {
      final selected = useIndonesian == indonesian;
      return ChoiceChip(
        label: Text(text),
        selected: selected,
        onSelected: (_) => _setLanguage(indonesian),
        selectedColor: kAccent,
        labelStyle: TextStyle(
            color: selected ? Colors.white : kInk, fontWeight: FontWeight.w800),
        showCheckmark: false,
        avatar: selected ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
      );
    }

    return _card(
      icon: Icons.translate,
      title: tr('Language', 'Bahasa'),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        children: [chip('English', false), chip('Bahasa Indonesia', true)],
      ),
    );
  }

  Widget _bestCard() {
    return _card(
      icon: Icons.emoji_events,
      title: tr('Best score', 'Skor terbaik'),
      child: Row(
        children: [
          Text('$_best',
              style: const TextStyle(
                  color: kInk,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()])),
          const Spacer(),
          TextButton.icon(
            onPressed: _best > 0 ? _confirmClearBest : null,
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFD9434B)),
            icon: const Icon(Icons.delete_outline),
            label: Text(tr('Clear', 'Hapus')),
          ),
        ],
      ),
    );
  }

  Widget _aboutCard() {
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Icon(icon, size: 18, color: Colors.black54),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text, style: const TextStyle(color: kInk, fontSize: 14))),
          ]),
        );
    return _card(
      icon: Icons.info_outline,
      title: tr('About', 'Tentang'),
      child: Column(
        children: [
          line(Icons.pets, 'Rocky Run  v1.0'),
          line(Icons.brush, tr('Created by Jovita', 'Dibuat oleh Jovita')),
          line(Icons.music_note,
              tr('Original chiptune music & sounds', 'Musik & suara chiptune orisinal')),
          line(Icons.flutter_dash, tr('Built with Flutter', 'Dibuat dengan Flutter')),
        ],
      ),
    );
  }
}
