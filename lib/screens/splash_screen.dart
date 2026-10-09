import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/scholar.dart';
import '../theme/scholar_themes.dart';
import 'menu_screen.dart';

/// Launch splash: game logo + name, animated loading line, and credits.
/// (Single splash only — the company mark rides in the credits row.)
class SplashScreen extends StatefulWidget {
  final ScholarAudio audio;
  final GomokuSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _run();
  }

  Future<void> _run() async {
    // Pre-warm audio while the splash shows, then start menu music.
    widget.audio.prewarm();
    widget.audio.startMenuMusic();
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ScholarThemes.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    return Scaffold(
      backgroundColor: theme.paper,
      body: PaperBackdrop(theme: theme, child: _GameSplash(theme: theme, loader: _loader)),
    );
  }
}

/// Game splash: logo + name + animated loading line + credits.
class _GameSplash extends StatelessWidget {
  final ScholarThemeDef theme;
  final AnimationController loader;
  const _GameSplash({required this.theme, required this.loader});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: theme.accent, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  offset: const Offset(0, 10),
                  blurRadius: 24,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset('assets/gomoku_logo.png', fit: BoxFit.cover),
          ),
          const SizedBox(height: 22),
          Text('Gomoku', style: Scholar.display(52, theme: theme)),
          const SizedBox(height: 6),
          Text(
            'FIVE IN A ROW · SCHOLAR\'S EDITION',
            style: Scholar.label(13, theme: theme),
          ),
          const SizedBox(height: 30),
          // Animated loading line.
          SizedBox(
            width: 220,
            child: AnimatedBuilder(
              animation: loader,
              builder: (_, _) => Column(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: Colors.black.withValues(alpha: 0.12),
                      border: Border.all(
                          color: theme.accent.withValues(alpha: 0.5)),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: loader.value.clamp(0.02, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: LinearGradient(
                            colors: [
                              theme.accent,
                              theme.accentDeep,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    loader.value < 1 ? 'Grinding the ink…' : 'Ready!',
                    style: Scholar.body(13,
                        theme: theme,
                        color: theme.inkSoft),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 44),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/wajiha_logo.png',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              Text(
                'Credits: WAJIHA',
                style: Scholar.label(14, theme: theme),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
