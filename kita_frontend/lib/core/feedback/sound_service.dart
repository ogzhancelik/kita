import 'package:audioplayers/audioplayers.dart';

/// Singleton audio service for in-game sound effects.
///
/// Uses a small pool of [AudioPlayer] instances for move/capture sounds so that
/// rapid successive calls (e.g. human move → auto-retaliation) do not cut each
/// other off. The game-over sound uses a dedicated player.
///
/// Configured with [AndroidAudioFocus.none] and [AVAudioSessionCategory.ambient]
/// so in-game sound effects mix seamlessly with background audio (e.g. Spotify,
/// YouTube) without pausing or ducking external media.
class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  /// When false all [play*] calls are no-ops. Wire to a settings toggle later.
  bool enabled = true;

  // Pool for short, repeatable sounds (move / capture)
  static const int _poolSize = 4;
  final List<AudioPlayer> _pool = [];
  int _poolIndex = 0;

  // Dedicated player for the game-over fanfare
  AudioPlayer? _gameOverPlayer;

  bool _initialized = false;

  /// Game sound effect audio context:
  /// - Android: sonification / game usage with AUDIOFOCUS_NONE so background
  ///   music or videos (YouTube, Spotify, etc.) are NOT paused or interrupted.
  /// - iOS: ambient audio session so sound effects mix with other audio sources
  ///   and respect the device's mute switch.
  static final AudioContext _gameAudioContext = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.ambient,
      options: const {},
    ),
  );

  /// Pre-warm the player pool. Call once from [main] or early in the widget
  /// tree so the first move is instant. Safe to await or fire-and-forget.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await AudioPlayer.global.setAudioContext(_gameAudioContext);
    } catch (_) {}

    try {
      for (int i = 0; i < _poolSize; i++) {
        final player = AudioPlayer();
        await player.setAudioContext(_gameAudioContext);
        await player.setReleaseMode(ReleaseMode.stop);
        _pool.add(player);
      }

      _gameOverPlayer = AudioPlayer();
      await _gameOverPlayer?.setAudioContext(_gameAudioContext);
      await _gameOverPlayer?.setReleaseMode(ReleaseMode.stop);
    } catch (_) {}
  }

  // ─── Public API ────────────────────────────────────────────────────────

  /// Play the normal piece-move sound.
  Future<void> playMove() => _playPooled('sounds/move.mp3');

  /// Play the king-capture sound.
  Future<void> playCapture() => _playPooled('sounds/capture.mp3');

  /// Play the end-of-game notification sound.
  Future<void> playGameOver() async {
    if (!enabled) return;
    if (!_initialized) {
      await initialize();
    }
    try {
      _gameOverPlayer ??= AudioPlayer();
      await _gameOverPlayer?.stop();
      await _gameOverPlayer?.play(
        AssetSource('sounds/game_over.mp3'),
        ctx: _gameAudioContext,
      );
    } catch (_) {}
  }

  // ─── Internals ─────────────────────────────────────────────────────────

  Future<void> _playPooled(String assetPath) async {
    if (!enabled) return;
    if (!_initialized) {
      await initialize();
    }
    if (_pool.isEmpty) return;
    try {
      final player = _pool[_poolIndex % _pool.length];
      _poolIndex++;
      await player.stop();
      await player.play(
        AssetSource(assetPath),
        ctx: _gameAudioContext,
      );
    } catch (_) {}
  }
}
