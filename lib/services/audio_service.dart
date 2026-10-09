import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural audio for Gomoku — all sounds synthesized in code as WAV bytes.
/// No asset files. Identity: ink-wash scholar's desk — slate stone knocks on
/// kaya wood, soft brush sweeps, warm mallet chimes, a muted hand drum, and
/// a calm koto-and-courtyard ambient loop.
///
/// Reliability design (every call is safe to repeat and safe to overlap):
/// - Music clips are synthesized ONCE and cached; starting music never blocks
///   the UI thread after the first build.
/// - A [_musicGen] generation counter serializes track changes: every
///   start/stop bumps the generation, in-flight work from an older request
///   aborts, and the LATEST request always wins. Overlapping calls (menu in/out,
///   pause/resume, toggles) can never swallow a start or leave the player
///   half-started — music is app-scoped and never silently dies.
/// - Lifecycle uses pause()/resume() so an interruption (call, backgrounding)
///   resumes exactly where it left off instead of restarting or dying.
/// - Every public method catches player errors; audio can never crash the app.
class ScholarAudio {
  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  // Cache synthesized clips so we only build them once.
  final Map<String, Uint8List> _cache = {};

  // Music state machine. [_musicGen] is bumped by every start/stop request;
  // async work checks it still owns the latest generation before touching
  // the player, so overlapping requests can never desync the music.
  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  ScholarAudio() {
    // Fire-and-forget is fine here: configure() runs before any play.
    _music.setReleaseMode(ReleaseMode.loop);
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    volume = volume.clamp(0.0, 1.0);
    this.volume = volume;
    _music.setVolume(musicOn ? volume * 0.55 : 0.0);
    _sfx.setVolume(sfxOn ? volume : 0.0);
    if (!musicOn) {
      stopMusic();
    }
  }

  /// Pre-build music clips off the critical path. Safe to call any time.
  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _noise() => _rand.nextDouble() * 2 - 1;

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  // ------------------------------- scholar's-desk sound synthesis

  /// Slate/clamshell stone knock on kaya: noise snap + low woody thump.
  List<double> _stoneClick(double freq, double brightness) {
    final n = (_rate * 0.16).round();
    final s = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / _rate;
      final env = exp(-t * 42);
      final thump = sin(2 * pi * freq * t) * exp(-t * 30) * 0.7;
      final snap = _noise() * exp(-t * 160) * 0.35 * brightness;
      s[i] = (thump + snap) * env * 1.4;
    }
    return s;
  }

  /// Soft wood-tick for illegal taps.
  List<double> _thock() {
    const freq = 105.0, dur = 0.24;
    final n = (_rate * dur).round();
    final s = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / _rate;
      s[i] = (sin(2 * pi * freq * t) * exp(-t * 22) * 0.8 +
              _noise() * exp(-t * 60) * 0.25) *
          1.2;
    }
    return s;
  }

  /// Quiet ink-brush tap on the desk.
  List<double> _woodTap() {
    final n = (_rate * 0.07).round();
    final s = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / _rate;
      s[i] = (sin(2 * pi * 520 * t) * exp(-t * 90) * 0.5 +
              _noise() * exp(-t * 200) * 0.2) *
          1.1;
    }
    return s;
  }

  /// Ink-brush sweep across paper: soft filtered noise whoosh.
  List<double> _brushSweep() {
    final n = (_rate * 0.35).round();
    final s = List<double>.filled(n, 0);
    var last = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / _rate;
      last = (last + 0.08 * _noise()) / 1.08;
      s[i] = last * sin(pi * t / 0.35) * 1.6;
    }
    return s;
  }

  List<double> _sweep(double from, double to, double dur) {
    final n = (_rate * dur).round();
    final s = List<double>.filled(n, 0);
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / _rate;
      final f = from + (to - from) * (t / dur);
      phase += 2 * pi * f / _rate;
      s[i] = sin(phase) * sin(pi * t / dur) * 0.5;
    }
    return s;
  }

  List<double> _twoTone(double f1, double f2) {
    final n = (_rate * 0.7).round();
    final s = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / _rate;
      final a = sin(2 * pi * f1 * t) * exp(-t * 6) * (t < 0.3 ? 1 : 0.4);
      final b = t > 0.22
          ? sin(2 * pi * f2 * (t - 0.22)) * exp(-(t - 0.22) * 6)
          : 0.0;
      s[i] = (a + b) * 0.45;
    }
    return s;
  }

  /// Mallet chime: pentatonic ascent with warm harmonics.
  List<double> _chime() {
    const freqs = [659.3, 784.0, 880.0, 987.8, 1174.7, 1318.5];
    final n = (_rate * 2.4).round();
    final s = List<double>.filled(n, 0);
    for (var k = 0; k < freqs.length; k++) {
      final start = (_rate * k * 0.16).round();
      final f = freqs[k];
      for (var i = 0; i + start < n; i++) {
        final t = i / _rate;
        if (t > 1.6) break;
        final env = exp(-t * 3.2) * (1 - exp(-t * 60));
        s[start + i] += (sin(2 * pi * f * t) * 0.6 +
                sin(2 * pi * f * 2 * t) * 0.18 +
                sin(2 * pi * f * 2.98 * t) * 0.08) *
            env *
            0.35;
      }
    }
    return s;
  }

  /// Muted hand drum.
  List<double> _mutedDrumHit(double gain) {
    final n = (_rate * 0.7).round();
    final s = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / _rate;
      s[i] = (sin(2 * pi * 78 * t) * exp(-t * 9) * 0.9 +
              _noise() * exp(-t * 45) * 0.2) *
          gain;
    }
    return s;
  }

  Uint8List _menuBytes() => _clip('music_menu', () {
        // 24s calm ambient loop: slow warm pad + sparse koto-like plucks.
        const dur = 24.0;
        final n = (_rate * dur).round();
        final s = List<double>.filled(n, 0);
        // chord roots: Dm, Bb, F, C — ink-wash calm
        const chords = [
          [146.8, 174.6, 220.0, 349.2],
          [116.5, 174.6, 233.1, 349.2],
          [174.6, 220.0, 261.6, 349.2],
          [130.8, 196.0, 261.6, 329.6],
        ];
        const seg = 6.0;
        for (var c = 0; c < 4; c++) {
          for (final f in chords[c]) {
            for (var i = 0; i < _rate * seg; i++) {
              final g = c * seg + i / _rate;
              final idx = (g * _rate).round() % n;
              final t = i / _rate;
              final env = (sin(pi * t / seg) * 0.5 + 0.5);
              s[idx] += (sin(2 * pi * f * t) * 0.5 +
                      sin(2 * pi * f * 2.01 * t) * 0.12) *
                  env *
                  0.028;
            }
          }
        }
        const penta = [523.3, 587.3, 659.3, 784.0, 880.0, 1046.5];
        final pluckRng = Random(7);
        for (var k = 0; k < 14; k++) {
          final start = (pluckRng.nextDouble() * dur * _rate).round();
          final f = penta[pluckRng.nextInt(penta.length)];
          for (var i = 0; i < _rate * 2.2 && start + i < n; i++) {
            final t = i / _rate;
            final env = exp(-t * 2.4) * (1 - exp(-t * 120));
            s[(start + i) % n] +=
                (sin(2 * pi * f * t) * 0.7 + sin(2 * pi * f * 2 * t) * 0.2) *
                    env *
                    0.05;
          }
        }
        // gentle loop crossfade on the last/first second
        final fade = _rate;
        for (var i = 0; i < fade; i++) {
          final a = i / fade;
          final v = s[i] * a + s[n - fade + i] * (1 - a);
          s[i] = v;
          s[n - fade + i] = v;
        }
        return s;
      });

  Uint8List _gameBytes() => _clip('music_game', () {
        // 12s quiet courtyard loop: low airy drone with slow breathing and
        // the faintest distant chime — the room behind the game.
        const dur = 12.0;
        final n = (_rate * dur).round();
        final s = List<double>.filled(n, 0);
        var last = 0.0;
        for (var i = 0; i < n; i++) {
          final t = i / _rate;
          last = (last + 0.02 * _noise()) / 1.02;
          final breathe = 0.6 + 0.4 * sin(2 * pi * t / dur);
          s[i] = last * 0.3 * breathe;
        }
        const chimeAt = [2.5, 8.0];
        for (final at in chimeAt) {
          final start = (at * _rate).round();
          for (var i = 0; i < _rate * 3 && start + i < n; i++) {
            final t = i / _rate;
            final env = exp(-t * 1.8) * (1 - exp(-t * 80));
            s[start + i] += sin(2 * pi * 1046.5 * t) * env * 0.035;
          }
        }
        final fade = _rate;
        for (var i = 0; i < fade; i++) {
          final a = i / fade;
          final v = s[i] * a + s[n - fade + i] * (1 - a);
          s[i] = v;
          s[n - fade + i] = v;
        }
        return s;
      });

  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  /// Stone placed: [black] selects the slate or clamshell knock.
  Future<void> playStone(bool black) => _play(_clip(
      black ? 'stone_black' : 'stone_white',
      () => _stoneClick(black ? 150 : 235, black ? 0.9 : 1.25)));

  Future<void> click() => _play(_clip('click', _woodTap));
  Future<void> invalid() => _play(_clip('invalid', _thock));
  Future<void> brush() => _play(_clip('brush', _brushSweep));
  Future<void> undo() =>
      _play(_clip('undo', () => _sweep(520, 220, 0.22)));
  Future<void> resign() => _play(_clip('resign', () => _mutedDrumHit(0.9)));
  Future<void> gameStart() =>
      _play(_clip('start', () => _twoTone(293.7, 392.0)));
  Future<void> win() => _play(_clip('win', _chime));
  Future<void> lose() => _play(_clip('lose', () => _mutedDrumHit(0.6)));
  Future<void> draw() => _play(_clip('draw', _brushSweep));

  // ----------------------------------------------------------------- music
  /// Start (or keep) a music track. Generation-serialized: the latest request
  /// always wins; a start issued while an older one is in flight is never
  /// dropped. Re-requesting the current track just ensures it is audible.
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (_disposed) return;
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      // Already on this track — make sure it is actually audible.
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    // Wait for any in-flight op, then bail if superseded meanwhile.
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !musicOn) return;
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !musicOn) return;
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      if (gen == _musicGen) _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  /// App-scoped stop: cancels any pending start, then stops. Used only when
  /// the user turns music OFF — never on screen navigation.
  Future<void> stopMusic() async {
    ++_musicGen; // cancel any in-flight start
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  /// App went to background / interruption: pause (not stop) so we resume
  /// exactly where it left off.
  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  /// App came back: resume only if we paused it and music is still wanted.
  Future<void> onAppResumed() async {
    if (_disposed || !musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      // Resume failed (e.g. player was released) — restart the track.
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
    } catch (_) {}
  }
}
