import 'package:flutter/material.dart';
import '../engine/bot.dart';
import '../engine/gomoku_session.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/scholar.dart';
import '../theme/scholar_themes.dart';
import 'game_screen.dart';
import 'howto_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

/// Scholar's desk main menu: logo + calligraphy title, wooden plaques for
/// Play vs Bot / Two Players / How to Play / Settings / PRO, difficulty
/// discs, play-as color choice, and the swap-opening toggle.
class MenuScreen extends StatefulWidget {
  final ScholarAudio audio;
  final GomokuSettings settings;
  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _hasSave = false;
  late final StoreService _store;

  ScholarThemeDef get _t => ScholarThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    _store = StoreService();
    _store.init(); // fire-and-forget; the PRO screen reads the result
    _refreshSave();
  }

  Future<void> _refreshSave() async {
    final j = await widget.settings.loadSavedGame();
    if (mounted) setState(() => _hasSave = j != null);
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  void _startVsBot() {
    widget.audio.gameStart();
    widget.audio.startGameMusic();
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: widget.audio,
          settings: widget.settings,
          store: _store,
          mode: GameMode.vsBot,
        ),
      ),
    )
        .then((_) {
      widget.audio.startMenuMusic();
      _refreshSave();
    });
  }

  void _startTwoPlayer() {
    widget.audio.gameStart();
    widget.audio.startGameMusic();
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: widget.audio,
          settings: widget.settings,
          store: _store,
          mode: GameMode.twoPlayer,
        ),
      ),
    )
        .then((_) {
      widget.audio.startMenuMusic();
      _refreshSave();
    });
  }

  void _resume() async {
    final j = await widget.settings.loadSavedGame();
    if (j == null || !mounted) return;
    widget.audio.click();
    widget.audio.startGameMusic();
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: widget.audio,
          settings: widget.settings,
          store: _store,
          mode: GameMode.values[j['mode'] as int],
          savedGame: j,
        ),
      ),
    )
        .then((_) {
      widget.audio.startMenuMusic();
      _refreshSave();
    });
  }

  void _openSettings() {
    widget.audio.click();
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          audio: widget.audio,
          settings: widget.settings,
          store: _store,
        ),
      ),
    )
        .then((_) => setState(() {}));
  }

  void _openPro() {
    widget.audio.click();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProScreen(
          audio: widget.audio,
          settings: widget.settings,
          store: _store,
        ),
      ),
    );
  }

  void _openHowTo() {
    widget.audio.click();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HowToScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    return PaperBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SealStamp(size: 30, theme: t),
                      const SizedBox(width: 12),
                      Text('Gomoku', style: Scholar.display(44, theme: t)),
                      const SizedBox(width: 12),
                      SealStamp(size: 30, theme: t),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'FIVE IN A ROW · SCHOLAR\'S EDITION',
                    style: Scholar.label(12, theme: t),
                  ),
                  const SizedBox(height: 18),
                  // Hero: the game logo in a wooden frame.
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: t.woodMid, width: 5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          offset: const Offset(0, 8),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/gomoku_logo.png',
                        fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 22),
                  if (_hasSave) ...[
                    WoodButton(
                      label: 'Resume Game',
                      width: double.infinity,
                      theme: t,
                      primary: true,
                      onTap: () {
                        widget.audio.click();
                        _resume();
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  WoodButton(
                    label: 'Play vs Bot',
                    width: double.infinity,
                    theme: t,
                    primary: true,
                    onTap: _startVsBot,
                  ),
                  const SizedBox(height: 12),
                  WoodButton(
                    label: 'Two Players',
                    width: double.infinity,
                    theme: t,
                    onTap: _startTwoPlayer,
                  ),
                  const SizedBox(height: 18),
                  _DifficultyRow(
                      theme: t, settings: s, audio: widget.audio),
                  const SizedBox(height: 14),
                  if (!s.swapOpening)
                    _ColorChoice(
                        theme: t, settings: s, audio: widget.audio),
                  if (!s.swapOpening) const SizedBox(height: 14),
                  _SwapToggle(
                      theme: t, settings: s, audio: widget.audio),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _MenuChip(
                          icon: Icons.menu_book,
                          label: 'How to Play',
                          theme: t,
                          onTap: _openHowTo),
                      _MenuChip(
                          icon: Icons.settings,
                          label: 'Settings',
                          theme: t,
                          onTap: _openSettings),
                      _MenuChip(
                          icon: Icons.workspace_premium,
                          label: s.isPro ? 'PRO ✓' : 'PRO',
                          theme: t,
                          onTap: _openPro),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _StatsStrip(theme: t, settings: s),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Difficulty discs: Beginner / Skilled / Master (Master is PRO).
class _DifficultyRow extends StatelessWidget {
  final ScholarThemeDef theme;
  final GomokuSettings settings;
  final ScholarAudio audio;
  const _DifficultyRow(
      {required this.theme, required this.settings, required this.audio});

  @override
  Widget build(BuildContext context) {
    const diffs = [
      (BotDifficulty.beginner, 'Beginner'),
      (BotDifficulty.skilled, 'Skilled'),
      (BotDifficulty.master, 'Master'),
    ];
    return Column(
      children: [
        Text('BOT STRENGTH', style: Scholar.label(12, theme: theme)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final (d, label) in diffs)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GestureDetector(
                  onTap: () {
                    final locked =
                        d == BotDifficulty.master && !settings.isPro;
                    if (locked) {
                      audio.invalid();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Master is a PRO feature',
                              style: Scholar.body(14, theme: theme)),
                          backgroundColor: theme.woodDeep,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    audio.click();
                    settings.setDifficulty(d);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: settings.difficulty == d
                                ? [theme.accent, theme.accentDeep]
                                : [theme.woodMid, theme.woodDeep],
                          ),
                          border: Border.all(
                            color: settings.difficulty == d
                                ? theme.accentDeep
                                : theme.woodLight.withValues(alpha: 0.6),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withValues(alpha: 0.3),
                              offset: const Offset(0, 3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: d == BotDifficulty.master &&
                                !settings.isPro
                            ? const Icon(Icons.lock,
                                color: Color(0xFFFFF6E6), size: 24)
                            : _MiniStone(
                                black: d != BotDifficulty.beginner,
                                count: d.index + 1),
                      ),
                      const SizedBox(height: 6),
                      Text(label,
                          style: Scholar.label(11, theme: theme)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MiniStone extends StatelessWidget {
  final bool black;
  final int count;
  const _MiniStone({required this.black, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < count; i++)
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.35),
                colors: black
                    ? [const Color(0xFF5A564E), const Color(0xFF23211E)]
                    : [Colors.white, const Color(0xFFF2EAD6)],
              ),
              border: Border.all(
                  color: Colors.black.withValues(alpha: 0.4)),
            ),
          ),
      ],
    );
  }
}

/// Play-as Black / White stone choice (hidden when swap opening is on —
/// the color choice happens after the swap instead).
class _ColorChoice extends StatelessWidget {
  final ScholarThemeDef theme;
  final GomokuSettings settings;
  final ScholarAudio audio;
  const _ColorChoice(
      {required this.theme, required this.settings, required this.audio});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('PLAY AS', style: Scholar.label(12, theme: theme)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _colorDisc(1, 'Black\n(first)'),
            const SizedBox(width: 18),
            _colorDisc(2, 'White\n(second)'),
          ],
        ),
      ],
    );
  }

  Widget _colorDisc(int color, String label) {
    final selected = settings.humanColor == color;
    return GestureDetector(
      onTap: () {
        audio.click();
        settings.setHumanColor(color);
      },
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.35),
                colors: color == 1
                    ? [const Color(0xFF5A564E), const Color(0xFF23211E)]
                    : [Colors.white, const Color(0xFFF2EAD6)],
              ),
              border: Border.all(
                color: selected ? theme.accent : Colors.black26,
                width: selected ? 3.5 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: Scholar.label(11, theme: theme),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Swap-opening toggle (RULES §7).
class _SwapToggle extends StatelessWidget {
  final ScholarThemeDef theme;
  final GomokuSettings settings;
  final ScholarAudio audio;
  const _SwapToggle(
      {required this.theme, required this.settings, required this.audio});

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      theme: theme,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Swap opening',
                    style: Scholar.label(14, theme: theme)),
                const SizedBox(height: 2),
                Text(
                  'Bot places 3 stones, you choose a color. Fairer first move.',
                  style: Scholar.body(12,
                      theme: theme, color: theme.inkSoft),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              audio.click();
              settings.setSwapOpening(!settings.swapOpening);
            },
            child: Container(
              width: 58,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: settings.swapOpening
                    ? theme.accent
                    : theme.inkSoft.withValues(alpha: 0.4),
                border: Border.all(color: theme.woodDeep, width: 1.5),
              ),
              alignment: settings.swapOpening
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.35, -0.35),
                    colors: [Color(0xFFFFFFFF), Color(0xFFF2EAD6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      offset: const Offset(0, 2),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ScholarThemeDef theme;
  final VoidCallback onTap;
  const _MenuChip(
      {required this.icon,
      required this.label,
      required this.theme,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: theme.paperCard,
          border:
              Border.all(color: theme.woodMid.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              offset: const Offset(0, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: theme.accent, size: 24),
            const SizedBox(height: 4),
            Text(label, style: Scholar.label(11, theme: theme)),
          ],
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  final ScholarThemeDef theme;
  final GomokuSettings settings;
  const _StatsStrip({required this.theme, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        StatPlaque(
            label: 'WINS', value: '${settings.wins}', theme: theme),
        const SizedBox(width: 10),
        StatPlaque(
            label: 'DRAWS', value: '${settings.draws}', theme: theme),
        const SizedBox(width: 10),
        StatPlaque(
            label: 'BEST STREAK',
            value: '${settings.bestStreak}',
            theme: theme),
      ],
    );
  }
}
