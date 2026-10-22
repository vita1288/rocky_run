import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Sound effects + looping background music.
class GameAudio {
  static const _sfxNames = [
    'jump',
    'double_jump',
    'bone',
    'milestone',
    'hit',
    'game_over',
    'bark',
    'hurt',
  ];

  final AudioPlayer _bgm = AudioPlayer(playerId: 'bgm');
  final Map<String, AudioPlayer> _sfx = {};
  bool muted = false; // quick mute (speaker button / M)
  bool _bgmStarted = false;

  // Settings page
  bool bgmOn = true;
  bool sfxOn = true;
  double bgmVolume = 0.5; // 0..1
  double sfxVolume = 0.8; // 0..1

  bool get _bgmAllowed => !muted && bgmOn;

  /// True while the music is supposed to be playing (a run is in progress).
  /// If the player stops on its own while this is set, it is resumed.
  bool _wantBgm = false;
  DateTime _lastHeal = DateTime.fromMillisecondsSinceEpoch(0);
  StreamSubscription<PlayerState>? _bgmWatch;

  Future<void> init() async {
    // Let the music and the sound effects play together. By default every
    // player asks Android for "audio focus", so each jump / bone sound made
    // the music player lose focus and stop.
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
    } catch (e) {
      debugPrint('Audio context not set: $e');
    }
    try {
      await _bgm.setReleaseMode(ReleaseMode.loop);
      await _bgm.setVolume(bgmVolume);
      await _bgm.setSource(AssetSource('audio/bgm.wav'));
      // Safety net: if the music stops by itself during a run, start it again.
      _bgmWatch = _bgm.onPlayerStateChanged.listen((state) {
        final stoppedByItself = state == PlayerState.paused ||
            state == PlayerState.stopped ||
            state == PlayerState.completed;
        final now = DateTime.now();
        if (_wantBgm && _bgmAllowed && stoppedByItself &&
            now.difference(_lastHeal).inMilliseconds > 800) {
          _lastHeal = now;
          _bgm.resume().catchError((_) {});
        }
      });
      for (final name in _sfxNames) {
        final p = AudioPlayer(playerId: 'sfx_$name');
        if (!kIsWeb) await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(AssetSource('audio/$name.wav'));
        _sfx[name] = p;
      }
    } catch (e) {
      debugPrint('Audio init failed: $e');
    }
  }

  Future<void> play(String name, {double volume = 1.0}) async {
    if (muted || !sfxOn) return;
    final p = _sfx[name];
    if (p == null) return;
    try {
      await p.stop();
      await p.setVolume((volume * sfxVolume).clamp(0.0, 1.0));
      await p.resume();
    } catch (e) {
      debugPrint('SFX $name failed: $e');
    }
  }

  /// Must be called from a user gesture on web (autoplay policy).
  Future<void> startBgm() async {
    if (!_bgmAllowed) return;
    _wantBgm = true;
    try {
      if (!_bgmStarted) {
        _bgmStarted = true;
        await _bgm.resume();
      } else if (_bgm.state != PlayerState.playing) {
        await _bgm.resume();
      }
    } catch (e) {
      debugPrint('BGM failed: $e');
    }
  }

  Future<void> pauseBgm() async {
    _wantBgm = false; // set before pausing so the safety net does not undo it
    try {
      await _bgm.pause();
    } catch (_) {}
  }

  Future<void> restartBgm() async {
    if (!_bgmAllowed) return;
    _wantBgm = true;
    try {
      await _bgm.seek(Duration.zero);
      _bgmStarted = true;
      await _bgm.resume();
    } catch (_) {}
  }

  Future<void> setBgmOn(bool on, {required bool playing}) async {
    bgmOn = on;
    if (!on) {
      await pauseBgm();
    } else if (playing) {
      await startBgm();
    }
  }

  Future<void> setBgmVolume(double v) async {
    bgmVolume = v;
    try {
      await _bgm.setVolume(v);
    } catch (_) {}
  }

  void setSfxVolume(double v) => sfxVolume = v;

  Future<void> toggleMute({required bool playing}) async {
    muted = !muted;
    if (muted) {
      await pauseBgm();
    } else if (playing) {
      await startBgm();
    }
  }

  void dispose() {
    _bgmWatch?.cancel();
    _bgm.dispose();
    for (final p in _sfx.values) {
      p.dispose();
    }
  }
}
