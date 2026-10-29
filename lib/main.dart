import 'dart:io' show exit;

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game.dart';
import 'game_audio.dart';
import 'pages/how_to_play_page.dart';
import 'pages/settings_page.dart';
import 'painters.dart';
import 'strings.dart';
import 'ui/art_icon.dart';
import 'ui/style.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const RockyRunApp());
}

class RockyRunApp extends StatelessWidget {
  const RockyRunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rocky Run',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: kAccent),
      home: const GameScreen(),
    );
  }
}

/// The game itself: world, score bar, title / game-over cards.
/// How to Play and Settings are separate pages (see lib/pages/).
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Saved preferences keys
  static const _kHighScore = 'rocky_run_high_score';
  static const _kBgmOn = 'rocky_run_bgm_on';
  static const _kSfxOn = 'rocky_run_sfx_on';
  static const _kBgmVol = 'rocky_run_bgm_volume';
  static const _kSfxVol = 'rocky_run_sfx_volume';
  static const _kLangId = 'rocky_run_lang_id';

  final RockyRunGame _game = RockyRunGame();
  final GameAudio _audio = GameAudio();
  final FocusNode _focus = FocusNode();
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0); // repaints the world
  Object? _hudKey; // what the score bar / cards last showed
  double _sinceHud = 0;
  Size? _screen; // last screen size applied to the world
  Duration _last = Duration.zero;
  SharedPreferences? _prefs;
  bool _pageOpen = false; // a How to Play / Settings page is on top

  // ---------------- lifecycle ----------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game.onSfx = (name) => _audio.play(name);
    _game.onGameOver = _handleGameOver;
    _audio.init();
    _ticker = createTicker(_tick)..start();
    _loadPrefs().then((_) {
      // How to Play opens every time the game starts.
      if (mounted) _openHowToPlay();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only pause when the app really goes to the background. `inactive` also
    // fires for short interruptions (notification shade, system dialogs), and
    // pausing there made the music stop unexpectedly on Android.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _audio.pauseBgm();
    } else if (state == AppLifecycleState.resumed && _game.state == GameState.playing) {
      _audio.startBgm();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _frame.dispose();
    _audio.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ---------------- saved settings ----------------

  Future<void> _loadPrefs() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      _game.highScore = p.getInt(_kHighScore) ?? 0;
      _audio
        ..bgmOn = p.getBool(_kBgmOn) ?? true
        ..sfxOn = p.getBool(_kSfxOn) ?? true;
      await _audio.setBgmVolume(p.getDouble(_kBgmVol) ?? 0.5);
      _audio.setSfxVolume(p.getDouble(_kSfxVol) ?? 0.8);
      useIndonesian = p.getBool(_kLangId) ?? false;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _saveSettings() {
    _prefs
      ?..setBool(_kBgmOn, _audio.bgmOn)
      ..setBool(_kSfxOn, _audio.sfxOn)
      ..setDouble(_kBgmVol, _audio.bgmVolume)
      ..setDouble(_kSfxVol, _audio.sfxVolume)
      ..setBool(_kLangId, useIndonesian);
  }

  Future<void> _clearBest() async {
    _game.highScore = 0;
    await _prefs?.remove(_kHighScore);
  }

  // ---------------- game loop ----------------

  void _tick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    // Allow steps up to 1/15 s so slower devices (e.g. iPhone Safari) keep
    // real-time speed instead of slowing down; longer hitches are capped.
    if (dt > 1 / 15) dt = 1 / 15;
    if (dt <= 0) return;
    _game.update(dt);
    _frame.value++; // redraw the game world only (cheap)

    // Rebuild the widgets (score bar, title / game-over cards) only when what
    // they show changes, and the running score at most 10 times a second.
    _sinceHud += dt;
    final hud = (
      _game.state,
      _game.lives,
      _game.bonesCollected,
      _game.highScore,
      _game.overTime > 0.7,
    );
    if (hud != _hudKey || _sinceHud >= 0.1) {
      _hudKey = hud;
      _sinceHud = 0;
      setState(() {});
    }
  }

  /// Applies the screen size to the game world.
  /// iOS Safari grows / shrinks the page height while its address bar hides or
  /// shows. Mid-run that would move the ground under Rocky, so height-only
  /// changes are ignored during a run (rotation / width changes still apply).
  void _fitWorld(double w, double h) {
    final prev = _screen;
    if (prev != null) {
      final sameWidth = (prev.width - w).abs() < 1;
      final sameHeight = (prev.height - h).abs() < 1;
      if (sameWidth && sameHeight) return;
      final addressBarOnly =
          sameWidth && (prev.height - h).abs() < prev.height * 0.25;
      if (addressBarOnly && _game.state == GameState.playing) return;
    }
    _screen = Size(w, h);
    // Keep at least 640 world units of width so rocks are visible early,
    // even on a narrow portrait phone (the world just zooms out).
    final scale = (w / 640).clamp(0.05, 1.0);
    _game.viewScale = scale;
    _game.size = Size(w / scale, h / scale);
  }

  void _handleGameOver() {
    _audio.pauseBgm();
    Future.delayed(const Duration(milliseconds: 300), () => _audio.play('game_over'));
    _prefs?.setInt(_kHighScore, _game.highScore);
  }

  void _startRun() {
    if (_game.state == GameState.playing) return;
    final firstRun = _game.state == GameState.ready;
    _audio.unlockWeb(); // iPhone Safari: allow sound effects during the run
    _game.start();
    _audio.play('bark');
    firstRun ? _audio.startBgm() : _audio.restartBgm();
  }

  void _backToTitle() {
    _audio.pauseBgm();
    setState(_game.backToTitle);
    _focus.requestFocus();
  }

  Future<void> _exitGame() async {
    await _audio.pauseBgm();
    final mobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (mobile) {
      await SystemNavigator.pop(); // close the app on Android / iOS
    } else {
      exit(0); // close the window on Windows / macOS / Linux
    }
  }

  // ---------------- pages ----------------

  /// Shown before every run. LET'S RUN! starts the run; ✕ / BACK goes to the title.
  Future<void> _openHowToPlay() async {
    if (_pageOpen || _game.state == GameState.playing) return;
    _pageOpen = true;
    final run = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const HowToPlayPage()),
    );
    _pageOpen = false;
    if (!mounted) return;
    _focus.requestFocus();
    if (run == true) {
      _startRun();
    } else if (_game.state == GameState.over) {
      _backToTitle();
    }
  }

  Future<void> _openSettings() async {
    if (_pageOpen || _game.state == GameState.playing) return;
    _pageOpen = true;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          audio: _audio,
          bestScore: _game.highScore,
          onSave: _saveSettings,
          onClearBest: _clearBest,
        ),
      ),
    );
    _pageOpen = false;
    if (!mounted) return;
    _focus.requestFocus();
    setState(() {}); // language may have changed
  }

  // ---------------- input ----------------

  void _press() {
    switch (_game.state) {
      case GameState.playing:
        _game.jump();
      case GameState.ready:
        _openHowToPlay();
      case GameState.over:
        if (_game.overTime > 0.7) _openHowToPlay();
    }
  }

  void _release() => _game.releaseJump();

  void _toggleMute() {
    _audio.toggleMute(playing: _game.state == GameState.playing);
    setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final k = event.logicalKey;
    if (event is KeyDownEvent) {
      if (k == LogicalKeyboardKey.keyM) {
        _toggleMute();
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.keyH) {
        _openHowToPlay();
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.keyS) {
        _openSettings();
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.escape) {
        if (_game.state == GameState.over) _backToTitle();
        return KeyEventResult.handled;
      }
    }
    final isJumpKey = k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.keyW;
    if (!isJumpKey) return KeyEventResult.ignored;
    if (event is KeyDownEvent) _press();
    if (event is KeyUpEvent) _release();
    return KeyEventResult.handled;
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final playing = _game.state == GameState.playing;
    // Android Back button: during a run or on game over -> back to the title.
    // On the title screen it closes the app as usual.
    return PopScope(
      canPop: _game.state == GameState.ready,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToTitle();
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: LayoutBuilder(builder: (context, c) {
          _fitWorld(c.maxWidth, c.maxHeight);
          return Stack(
            fit: StackFit.expand,
            children: [
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => _press(),
                onPointerUp: (_) => _release(),
                // iOS can cancel a touch (e.g. a system gesture); treat it as
                // a release so a held high jump never gets stuck.
                onPointerCancel: (_) => _release(),
                child: CustomPaint(painter: GamePainter(_game, repaint: _frame)),
              ),
              IgnorePointer(child: _scoreBar(playing)),
              if (!playing)
                IgnorePointer(
                  ignoring: _game.state != GameState.over,
                  child: _game.state == GameState.over ? _gameOverCard() : _titleCard(),
                ),
              Positioned(top: 0, right: 0, child: SafeArea(child: _cornerButtons(playing))),
            ],
          );
        }),
      ),
      ),
    );
  }

  Widget _cornerButtons(bool playing) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!playing) ...[
            IconButton.filledTonal(
              onPressed: _openHowToPlay,
              icon: const Icon(Icons.help_outline),
              tooltip: ctl(tr('How to play (H)', 'Cara bermain (H)'), tr('How to play', 'Cara bermain')),
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings),
              tooltip: ctl(tr('Settings (S)', 'Pengaturan (S)'), tr('Settings', 'Pengaturan')),
            ),
            const SizedBox(width: 6),
          ],
          IconButton.filledTonal(
            onPressed: _toggleMute,
            icon: Icon(_audio.muted ? Icons.volume_off : Icons.volume_up),
            tooltip: ctl(tr('Mute (M)', 'Bisukan (M)'), tr('Mute', 'Bisukan')),
          ),
        ],
      ),
    );
  }

  // ---------------- score bar (top-left chips) ----------------

  static const _chip = BoxDecoration(
    color: Color(0x8C2B1712),
    borderRadius: BorderRadius.all(Radius.circular(14)),
    border: Border.fromBorderSide(BorderSide(color: Color(0x40FFFFFF), width: 1.5)),
  );
  static const _tabular = [FontFeature.tabularFigures()];

  Widget _scoreBar(bool playing) {
    return SafeArea(
      child: Padding(
        // leave room for the corner buttons (1 while playing, 3 otherwise)
        padding: EdgeInsets.fromLTRB(12, 10, playing ? 64 : 160, 0),
        child: Align(
          alignment: Alignment.topLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _scoreChip(),
                const SizedBox(width: 8),
                _bonesChip(),
                const SizedBox(width: 8),
                _heartsChip(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scoreChip() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 14, 7),
      decoration: _chip,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.star_rounded, size: 14, color: kGold),
            const SizedBox(width: 4),
            Text(tr('SCORE', 'SKOR'),
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4)),
          ]),
          Text('${_game.score}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  fontFeatures: _tabular)),
          Text('${tr('BEST', 'TERBAIK')} ${_game.highScore}',
              style: const TextStyle(
                  color: kPeach,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  fontFeatures: _tabular)),
        ],
      ),
    );
  }

  Widget _bonesChip() {
    return Container(
      height: 44,
      padding: const EdgeInsets.fromLTRB(6, 0, 12, 0),
      decoration: _chip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ArtIcon(ArtKind.bone, 0, size: Size(36, 30)),
          Text('×${_game.bonesCollected}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontFeatures: _tabular)),
        ],
      ),
    );
  }

  Widget _heartsChip() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: _chip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < RockyRunGame.maxLives; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Icon(
                i < _game.lives ? Icons.favorite : Icons.favorite_border,
                size: 23,
                color: i < _game.lives ? const Color(0xFFFF5A6E) : Colors.white38,
              ),
            ),
        ],
      ),
    );
  }

  // ---------------- title / game-over cards ----------------

  Widget _card({required List<Widget> children}) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xCC2B1712),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kAccent, width: 3),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  Widget _titleCard() {
    return _card(children: [
      FittedBox(
          fit: BoxFit.scaleDown, child: gameLabel('ROCKY RUN', 40, color: kPeach)),
      const SizedBox(height: 8),
      gameLabel(
          tr('Help Rocky the red toy poodle dodge the rocks!',
              'Bantu Rocky si toy poodle merah menghindari batu!'),
          16),
      const SizedBox(height: 10),
      gameLabel(
          ctl(tr('TAP / SPACE TO START', 'KETUK / SPASI UNTUK MULAI'),
              tr('TAP TO START', 'KETUK UNTUK MULAI')),
          20,
          color: kGold),
      const SizedBox(height: 4),
      gameLabel(tr('?  How to Play   •   ⚙  Settings', '?  Cara Bermain   •   ⚙  Pengaturan'),
          13,
          color: Colors.white70),
    ]);
  }

  Widget _gameOverCard() {
    return _card(children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: gameLabel(tr('OUCH! GAME OVER', 'ADUH! KALAH'), 30, color: kPeach),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _statTile(tr('SCORE', 'SKOR'), '${_game.score}', Icons.star_rounded),
          const SizedBox(width: 8),
          _statTile(tr('BONES', 'TULANG'), '${_game.bonesCollected}', Icons.pets),
          const SizedBox(width: 8),
          _statTile(tr('BEST', 'TERBAIK'), '${_game.highScore}', Icons.emoji_events,
              highlight: _game.newRecord),
        ],
      ),
      if (_game.newRecord) ...[
        const SizedBox(height: 8),
        gameLabel(tr('★ NEW HIGH SCORE! ★', '★ REKOR BARU! ★'), 16, color: kGold),
      ],
      if (_game.overTime > 0.7) ...[
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _openHowToPlay,
              style: accentFilled,
              icon: const Icon(Icons.replay),
              label: Text(tr('RUN AGAIN', 'MAIN LAGI')),
            ),
            OutlinedButton.icon(
              onPressed: _backToTitle,
              style: outlinedOnDark,
              icon: const Icon(Icons.home),
              label: Text(tr('TITLE', 'MENU')),
            ),
            if (!kIsWeb)
              OutlinedButton.icon(
                onPressed: _exitGame,
                style: outlinedOnDark,
                icon: const Icon(Icons.exit_to_app),
                label: Text(tr('EXIT', 'KELUAR')),
              ),
          ],
        ),
        const SizedBox(height: 8),
        gameLabel(
            ctl(tr('Space = run again  •  Esc = title', 'Spasi = main lagi  •  Esc = menu'),
                tr('Phone Back button = title', 'Tombol Kembali = menu')),
            13,
            color: Colors.white70),
      ],
    ]);
  }

  Widget _statTile(String label, String value, IconData icon, {bool highlight = false}) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? const Color(0x33FFE066) : const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? kGold : const Color(0x33FFFFFF)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: kPeach),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFeatures: _tabular)),
          ),
          Text(label,
              style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
        ],
      ),
    );
  }
}
