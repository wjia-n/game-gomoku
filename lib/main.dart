import 'package:flutter/material.dart';

import 'audio/sound.dart';
import 'screens/game_over_screen.dart';
import 'screens/game_screen.dart';
import 'screens/howto_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/settings_screen.dart';
import 'state/game.dart';
import 'state/settings.dart';
import 'theme.dart';

void main() => runApp(const GomokuApp());

enum _Nav { menu, game, gameOver, settings, howto }

/// Gomoku — the scholar's five-in-a-row duel.
/// Navigation is a tiny explicit state machine; screens are pure views over
/// [GomokuSettings] and [GameState].
class GomokuApp extends StatefulWidget {
  const GomokuApp({super.key});

  @override
  State<GomokuApp> createState() => _GomokuAppState();
}

class _GomokuAppState extends State<GomokuApp>
    with WidgetsBindingObserver {
  late final GomokuSettings settings;
  late final SoundService sound;
  late final GameState game;

  _Nav _nav = _Nav.menu;
  _Nav _settingsReturn = _Nav.menu;
  bool _reviewing = false;
  bool _hasSave = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    settings = GomokuSettings();
    sound = SoundService();
    game = GameState(settings: settings, sound: sound);
    game.addListener(_onGameChanged);
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  Future<void> _boot() async {
    await settings.load();
    await sound.init();
    sound.applySettings(
        sfxOn: settings.sfxOn,
        musicOn: settings.musicOn,
        sfxVolume: settings.sfxVolume,
        musicVolume: settings.musicVolume);
    sound.setMusicMode('menu');
    _hasSave = await settings.loadSavedGame() != null;
    if (mounted) setState(() => _ready = true);
  }

  void _onGameChanged() {
    // the finished game hands off to the results screen exactly once
    if (game.over &&
        _nav == _Nav.game &&
        !_reviewing &&
        mounted) {
      setState(() {
        _nav = _Nav.gameOver;
        _hasSave = false;
      });
      sound.setMusicMode('menu');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      game.pause();
    } else if (state == AppLifecycleState.resumed) {
      // stay paused on return — the player resumes deliberately
    }
  }

  // ---- navigation helpers ----

  Future<void> _goMenu() async {
    game.cancelBot();
    _hasSave = await settings.loadSavedGame() != null;
    sound.setMusicMode('menu');
    if (mounted) {
      setState(() {
        _nav = _Nav.menu;
        _reviewing = false;
      });
    }
  }

  void _onPlay() {
    sound.setMusicMode('game');
    setState(() {
      _nav = _Nav.game;
      _reviewing = false;
    });
  }

  Future<void> _onResume() async {
    final j = await settings.loadSavedGame();
    if (j != null && game.restore(j)) {
      sound.setMusicMode('game');
      setState(() {
        _nav = _Nav.game;
        _reviewing = false;
      });
    } else {
      _goMenu();
    }
  }

  void _onRematch() {
    game.newGame(
      mode: game.mode,
      difficulty: game.difficulty,
      humanColor: game.humanColor,
      swapOpening: game.swapOpening,
    );
    sound.setMusicMode('game');
    setState(() {
      _nav = _Nav.game;
      _reviewing = false;
    });
  }

  void _openSettings(_Nav from) {
    setState(() {
      _settingsReturn = from;
      _nav = _Nav.settings;
    });
  }

  void _closeSettings() {
    setState(() => _nav = _settingsReturn);
    if (_settingsReturn == _Nav.game && !game.paused) {
      game.nudgeBot();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    game.removeListener(_onGameChanged);
    game.disposeState();
    sound.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gomoku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: GomokuTheme.ricePaper,
        colorScheme: ColorScheme.fromSeed(
            seedColor: GomokuTheme.kayaDeep),
        useMaterial3: true,
      ),
      home: !_ready
          ? const Scaffold(
              backgroundColor: GomokuTheme.ricePaper,
              body: Center(
                  child: CircularProgressIndicator(
                      color: GomokuTheme.kayaDeep)),
            )
          : _screen(),
    );
  }

  Widget _screen() {
    switch (_nav) {
      case _Nav.menu:
        return MenuScreen(
          settings: settings,
          sound: sound,
          game: game,
          hasSave: _hasSave,
          onPlay: _onPlay,
          onResume: _onResume,
          onHowTo: () => setState(() => _nav = _Nav.howto),
          onOpenSettings: () => _openSettings(_Nav.menu),
        );
      case _Nav.game:
        return GameScreen(
          game: game,
          settings: settings,
          sound: sound,
          reviewMode: _reviewing,
          onReviewDone: () => setState(() {
            _reviewing = false;
            _nav = _Nav.gameOver;
          }),
          onPauseSettings: () {
            game.pause();
            _openSettings(_Nav.game);
          },
          onQuitToMenu: () {
            game.resume();
            _goMenu();
          },
        );
      case _Nav.gameOver:
        return GameOverScreen(
          game: game,
          settings: settings,
          sound: sound,
          onRematch: _onRematch,
          onReview: () => setState(() {
            _reviewing = true;
            _nav = _Nav.game;
          }),
          onMenu: _goMenu,
        );
      case _Nav.settings:
        return SettingsScreen(
          settings: settings,
          sound: sound,
          onBack: _closeSettings,
        );
      case _Nav.howto:
        return HowToScreen(
          sound: sound,
          onBack: () => setState(() => _Nav.menu),
        );
    }
  }
}
