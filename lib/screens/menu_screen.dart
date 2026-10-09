import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../engine/bot.dart';
import '../engine/gomoku_engine.dart';
import '../state/game.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/board.dart';
import '../widgets/wood.dart';

/// Scholar's desk main menu: calligraphy title + seal stamp, hero goban,
/// wooden plaques for modes, difficulty discs, stone color choice.
class MenuScreen extends StatefulWidget {
  final GomokuSettings settings;
  final SoundService sound;
  final GameState game;
  final bool hasSave;
  final VoidCallback onPlay;
  final VoidCallback onResume;
  final VoidCallback onHowTo;
  final VoidCallback onOpenSettings;

  const MenuScreen({
    super.key,
    required this.settings,
    required this.sound,
    required this.game,
    required this.hasSave,
    required this.onPlay,
    required this.onResume,
    required this.onHowTo,
    required this.onOpenSettings,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  void initState() {
    super.initState();
    widget.sound.setMusicMode('menu');
  }

  void _start(GameMode mode) {
    widget.sound.playStart();
    widget.game.newGame(
      mode: mode,
      difficulty: widget.settings.difficulty,
      humanColor: widget.settings.humanColor,
      swapOpening: widget.settings.swapOpening,
    );
    widget.onPlay();
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.settings;
    return Scaffold(
      backgroundColor: GomokuTheme.ricePaper,
      body: SafeArea(
        child: Stack(
          children: [
            // faint ink-wash brush strokes in the background
            Positioned(
              left: -40,
              top: 120,
              child: Opacity(
                opacity: 0.06,
                child: CustomPaint(
                  size: const Size(300, 120),
                  painter: _WashPainter(),
                ),
              ),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _iconBtn(Icons.settings_outlined, () {
                      widget.sound.playTap();
                      widget.onOpenSettings();
                    }),
                  ],
                ),
                // title block
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('Gomoku',
                              style: GomokuTheme.display(48,
                                  weight: FontWeight.w700)),
                          const SizedBox(width: 10),
                          const SealStamp(size: 46),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('five stones in a row',
                          style: GomokuTheme.body(15,
                              color: GomokuTheme.warmGray)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // hero: a quiet corner of the goban, a game already in play
                Center(
                  child: Container(
                    constraints:
                        const BoxConstraints(maxWidth: 300),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: KayaBoard(
                        board: _demoBoard(),
                        lastMove: -1,
                        invalidAt: -1,
                        hintAt: -1,
                        winLine: const [80, 91, 112, 128, 144],
                        showCoordinates: false,
                        showLastMoveMarker: false,
                        interactive: false,
                        onTap: (_) {},
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                      'black to move · the scholar\'s duel',
                      style: GomokuTheme.label(12)),
                ),
                const SizedBox(height: 16),
                if (widget.hasSave) ...[
                  ScholarButton(
                      label: 'Resume last game',
                      primary: false,
                      width: double.infinity,
                      onTap: () {
                        widget.sound.playTap();
                        widget.onResume();
                      }),
                  const SizedBox(height: 12),
                ],
                const SectionHead(title: 'Begin a match'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ScholarButton(
                          label: 'Play vs Bot',
                          onTap: () => _start(GameMode.vsBot)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ScholarButton(
                          label: 'Two Players',
                          primary: false,
                          onTap: () =>
                              _start(GameMode.twoPlayer)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ScholarButton(
                          label: 'How to Play',
                          primary: false,
                          onTap: () {
                            widget.sound.playTap();
                            widget.onHowTo();
                          }),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ScholarButton(
                          label: 'Settings',
                          primary: false,
                          onTap: () {
                            widget.sound.playTap();
                            widget.onOpenSettings();
                          }),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const SectionHead(title: 'Bot strength'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _diffDisc(BotDifficulty.beginner, 'Beginner',
                        Icons.spa_outlined),
                    _diffDisc(BotDifficulty.skilled, 'Skilled',
                        Icons.self_improvement),
                    _diffDisc(BotDifficulty.master, 'Master',
                        Icons.workspace_premium_outlined),
                  ],
                ),
                const SizedBox(height: 16),
                const SectionHead(title: 'Your stones (vs bot)'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _stoneChoice(1, 'Black · first'),
                    const SizedBox(width: 16),
                    _stoneChoice(2, 'White'),
                  ],
                ),
                const SizedBox(height: 16),
                const BrushDivider(),
                const SizedBox(height: 10),
                // match record
                AnimatedBuilder(
                  animation: st,
                  builder: (_, _) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _stat('Black', '${st.wins}'),
                      _statSep(),
                      _stat('White', '${st.losses}'),
                      _statSep(),
                      _stat('Draws', '${st.draws}'),
                      if (st.streak > 0) ...[
                        _statSep(),
                        _stat(
                            'Streak',
                            '×${st.streak} '
                            '${st.streakSide == 1 ? 'black' : 'white'}'),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _diffDisc(BotDifficulty d, String label, IconData icon) {
    final st = widget.settings;
    return AnimatedBuilder(
      animation: st,
      builder: (_, _) => ScholarDisc(
        icon: icon,
        label: label,
        selected: st.difficulty == d,
        tint: st.difficulty == d ? GomokuTheme.cinnabar : null,
        onTap: () {
          widget.sound.playTap();
          st.update(() => st.difficulty = d);
        },
      ),
    );
  }

  Widget _stoneChoice(int color, String label) {
    final st = widget.settings;
    return AnimatedBuilder(
      animation: st,
      builder: (_, _) {
        final selected = st.humanColor == color;
        return GestureDetector(
          onTap: () {
            widget.sound.playTap();
            st.update(() => st.humanColor = color);
          },
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? GomokuTheme.kayaAmber.withValues(alpha: 0.35)
                      : Colors.transparent,
                  border: Border.all(
                      color: selected
                          ? GomokuTheme.cinnabar
                          : GomokuTheme.warmGray
                              .withValues(alpha: 0.4),
                      width: selected ? 2.2 : 1.2),
                ),
                child: MiniStone(
                    black: color == 1, size: 40),
              ),
              const SizedBox(height: 4),
              Text(label, style: GomokuTheme.label(11)),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String label, String value) => Column(
        children: [
          Text(value, style: GomokuTheme.counter(18)),
          Text(label, style: GomokuTheme.label(11)),
        ],
      );

  Widget _statSep() => Container(
        width: 1,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 14),
        color: GomokuTheme.warmGray.withValues(alpha: 0.4),
      );

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: GomokuTheme.touch,
        height: GomokuTheme.touch,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: GomokuTheme.washi,
          border: Border.all(
              color: GomokuTheme.warmGray.withValues(alpha: 0.4)),
          boxShadow: const [
            BoxShadow(
                color: GomokuTheme.woodShadow,
                blurRadius: 6,
                offset: Offset(0, 3)),
          ],
        ),
        child: Icon(icon, color: GomokuTheme.kayaDeep, size: 22),
      ),
    );
  }

  /// A quiet mid-game position for the menu hero.
  List<int> _demoBoard() {
    final b = List<int>.filled(
        GomokuEngine.n * GomokuEngine.n, 0);
    int sq(int r, int c) => r * GomokuEngine.n + c;
    for (final p in [
      [5, 5],
      [6, 6],
      [7, 7],
      [8, 8],
      [9, 9]
    ]) {
      b[sq(p[0], p[1])] = 1;
    }
    for (final p in [
      [5, 9],
      [6, 8],
      [8, 6],
      [10, 5],
      [4, 6],
      [9, 4]
    ]) {
      b[sq(p[0], p[1])] = 2;
    }
    return b;
  }
}

class _WashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = GomokuTheme.ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 5; k++) {
      final y = 20.0 + k * 20;
      p.strokeWidth = 10 - k * 1.6;
      final path = Path()
        ..moveTo(10, y)
        ..quadraticBezierTo(
            s.width * 0.4, y - 14, s.width * 0.8, y + 6)
        ..quadraticBezierTo(
            s.width * 0.95, y + 10, s.width - 8, y - 4);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
