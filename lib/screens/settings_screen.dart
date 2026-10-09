import 'package:flutter/material.dart';
import '../engine/bot.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/scholar.dart';
import '../theme/scholar_themes.dart';
import 'custom_theme_screen.dart';
import 'pro_screen.dart';

/// Scholar's settings: grouped washi panels — Sound, Players, Board &
/// Stones, Game, and Pro.
class SettingsScreen extends StatefulWidget {
  final ScholarAudio audio;
  final GomokuSettings settings;
  final StoreService store;
  const SettingsScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.store});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ScholarThemeDef get _t => ScholarThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  void _click() => widget.audio.click();

  void _openPro() {
    _click();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProScreen(
          audio: widget.audio,
          settings: widget.settings,
          store: widget.store,
        ),
      ),
    );
  }

  void _openCustomTheme() {
    _click();
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => CustomThemeScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    )
        .then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    return PaperBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.inkText),
            onPressed: () {
              _click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Settings', style: Scholar.display(22, theme: t)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Group(
                      theme: t,
                      title: 'Sound',
                      children: [
                        _ToggleRow(
                          theme: t,
                          label: 'Music',
                          value: s.musicOn,
                          onTap: () async {
                            _click();
                            await s.setMusic(!s.musicOn);
                            widget.audio.configure(
                                musicOn: s.musicOn,
                                sfxOn: s.sfxOn,
                                volume: s.volume);
                            if (s.musicOn) {
                              widget.audio.startMenuMusic();
                            }
                          },
                        ),
                        _ToggleRow(
                          theme: t,
                          label: 'Sound effects',
                          value: s.sfxOn,
                          onTap: () async {
                            _click();
                            await s.setSfx(!s.sfxOn);
                            widget.audio.configure(
                                musicOn: s.musicOn,
                                sfxOn: s.sfxOn,
                                volume: s.volume);
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 6),
                          child: Row(
                            children: [
                              Icon(Icons.volume_up,
                                  color: t.accent, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Slider(
                                  value: s.volume,
                                  activeColor: t.accent,
                                  inactiveColor: t.inkSoft
                                      .withValues(alpha: 0.4),
                                  onChanged: (v) {
                                    s.setVolume(v);
                                    widget.audio.configure(
                                        musicOn: s.musicOn,
                                        sfxOn: s.sfxOn,
                                        volume: v);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]),
                  const SizedBox(height: 14),
                  _Group(
                      theme: t,
                      title: 'Players — tap a name to rename',
                      children: [
                        for (int i = 0; i < 2; i++)
                          _NameRow(
                            theme: t,
                            label: i == 0 ? 'Seat 1' : 'Seat 2',
                            name: s.playerNames[i],
                            onRename: () =>
                                _renamePlayer(context, i),
                          ),
                      ]),
                  const SizedBox(height: 14),
                  _Group(
                      theme: t,
                      title: 'Board & Stones',
                      children: [
                        _SectionLabel(
                            theme: t, text: 'THEME — ${ScholarThemes.all.length} SCHOLAR THEMES'),
                        _ThemeGrid(
                            theme: t,
                            settings: s,
                            audio: widget.audio,
                            onCustom: _openCustomTheme),
                        const SizedBox(height: 10),
                        _SectionLabel(theme: t, text: 'STONE STYLE'),
                        _StoneGrid(
                            theme: t,
                            settings: s,
                            audio: widget.audio),
                        const SizedBox(height: 10),
                        _SectionLabel(
                            theme: t, text: 'LAST-MOVE MARKER'),
                        _MarkerGrid(
                            theme: t,
                            settings: s,
                            audio: widget.audio),
                        const SizedBox(height: 6),
                        _ToggleRow(
                          theme: t,
                          label: 'Board coordinates',
                          value: s.showCoordinates,
                          onTap: () {
                            _click();
                            s.setShowCoordinates(!s.showCoordinates);
                          },
                        ),
                        _ToggleRow(
                          theme: t,
                          label: 'Last-move marker',
                          value: s.lastMoveMarker,
                          onTap: () {
                            _click();
                            s.setLastMoveMarker(!s.lastMoveMarker);
                          },
                        ),
                      ]),
                  const SizedBox(height: 14),
                  _Group(theme: t, title: 'Game', children: [
                    _SectionLabel(theme: t, text: 'BOT STRENGTH'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final d in BotDifficulty.values)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6),
                            child: ChoiceChip(
                              label: Text(
                                  const {
                                    BotDifficulty.beginner: 'Beginner',
                                    BotDifficulty.skilled: 'Skilled',
                                    BotDifficulty.master: 'Master ＊',
                                  }[d]!,
                                  style: Scholar.label(12, theme: t)),
                              selected: s.difficulty == d,
                              selectedColor:
                                  t.accent.withValues(alpha: 0.35),
                              backgroundColor: t.paper,
                              side: BorderSide(
                                  color: s.difficulty == d
                                      ? t.accent
                                      : t.woodMid),
                              onSelected: (_) {
                                if (d == BotDifficulty.master &&
                                    !s.isPro) {
                                  widget.audio.invalid();
                                  _openPro();
                                  return;
                                }
                                _click();
                                s.setDifficulty(d);
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('＊ Master is a PRO feature',
                        style: Scholar.body(11,
                            theme: t, color: t.inkSoft),
                        textAlign: TextAlign.center),
                    _ToggleRow(
                      theme: t,
                      label: 'Swap opening',
                      value: s.swapOpening,
                      onTap: () {
                        _click();
                        s.setSwapOpening(!s.swapOpening);
                      },
                    ),
                    _ToggleRow(
                      theme: t,
                      label: 'Confirm before resign',
                      value: s.confirmResign,
                      onTap: () {
                        _click();
                        s.setConfirmResign(!s.confirmResign);
                      },
                    ),
                    _ToggleRow(
                      theme: t,
                      label: 'Allow undo',
                      value: s.undoAllowed,
                      onTap: () {
                        _click();
                        s.setUndoAllowed(!s.undoAllowed);
                      },
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _Group(theme: t, title: 'Gomoku PRO', children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.workspace_premium,
                          color: t.accent, size: 28),
                      title: Text(
                          s.isPro
                              ? 'PRO active — thank you!'
                              : 'Unlock PRO',
                          style: Scholar.label(15, theme: t)),
                      subtitle: Text(
                          s.isPro
                              ? 'All themes, stones, markers & Master bot.'
                              : 'All themes, stones, markers & Master bot.',
                          style: Scholar.body(12,
                              theme: t, color: t.inkSoft)),
                      trailing: Icon(Icons.arrow_forward_ios,
                          color: t.inkSoft, size: 18),
                      onTap: _openPro,
                    ),
                  ]),
                  const SizedBox(height: 18),
                  Center(
                    child: WoodButton(
                      label: 'Reset to Defaults',
                      width: 260,
                      theme: t,
                      onTap: () async {
                        _click();
                        s.resetDefaults();
                        widget.audio.configure(
                            musicOn: s.musicOn,
                            sfxOn: s.sfxOn,
                            volume: s.volume);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _renamePlayer(BuildContext context, int index) async {
    final t = _t;
    final ctrl =
        TextEditingController(text: widget.settings.playerNames[index]);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: PaperCard(
          theme: t,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Rename player', style: Scholar.display(22, theme: t)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: 16,
                textAlign: TextAlign.center,
                style: Scholar.body(18, theme: t),
                decoration: InputDecoration(
                  counterText: '',
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: t.accent)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: t.accent, width: 2)),
                ),
                onSubmitted: (_) =>
                    Navigator.of(context).pop(ctrl.text),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  WoodButton(
                    label: 'Save',
                    width: 120,
                    theme: t,
                    primary: true,
                    onTap: () =>
                        Navigator.of(context).pop(ctrl.text),
                  ),
                  const SizedBox(width: 10),
                  WoodButton(
                    label: 'Cancel',
                    width: 120,
                    theme: t,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      _click();
      await widget.settings.setPlayerName(index, result);
      setState(() {});
    }
  }
}

// ---------------------------------------------------------------------------
class _Group extends StatelessWidget {
  final ScholarThemeDef theme;
  final String title;
  final List<Widget> children;
  const _Group(
      {required this.theme, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title.toUpperCase(),
              style: Scholar.label(13, theme: theme)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final ScholarThemeDef theme;
  final String text;
  const _SectionLabel({required this.theme, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(text, style: Scholar.label(11, theme: theme)),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final ScholarThemeDef theme;
  final String label;
  final bool value;
  final VoidCallback onTap;
  const _ToggleRow(
      {required this.theme,
      required this.label,
      required this.value,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
                child: Text(label, style: Scholar.body(15, theme: t))),
            Container(
              width: 52,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: value
                    ? t.accent
                    : t.inkSoft.withValues(alpha: 0.4),
                border: Border.all(color: t.woodDeep, width: 1.5),
              ),
              alignment:
                  value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.35, -0.35),
                    colors: [Color(0xFFFFFFFF), Color(0xFFF2EAD6)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NameRow extends StatelessWidget {
  final ScholarThemeDef theme;
  final String label;
  final String name;
  final VoidCallback onRename;
  const _NameRow(
      {required this.theme,
      required this.label,
      required this.name,
      required this.onRename});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return InkWell(
      onTap: onRename,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text(label, style: Scholar.body(14, theme: t)),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: t.paper,
                  border:
                      Border.all(color: t.woodMid.withValues(alpha: 0.5)),
                ),
                child: Text(name,
                    style: Scholar.body(15, theme: t),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit, color: t.accent, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Theme swatch grid: all themes + the custom-creator tile.
class _ThemeGrid extends StatelessWidget {
  final ScholarThemeDef theme;
  final GomokuSettings settings;
  final ScholarAudio audio;
  final VoidCallback onCustom;
  const _ThemeGrid(
      {required this.theme,
      required this.settings,
      required this.audio,
      required this.onCustom});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final items = [...ScholarThemes.all];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: items.length + 1,
      itemBuilder: (_, i) {
        if (i == items.length) {
          final selected = settings.themeId == 'custom';
          return GestureDetector(
            onTap: () {
              if (!settings.isPro) {
                audio.invalid();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Theme creator is a PRO feature',
                        style: Scholar.body(14, theme: t)),
                    backgroundColor: t.woodDeep,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              onCustom();
            },
            child: _swatchTile(
              t: t,
              selected: selected,
              locked: !settings.isPro,
              label: 'Custom',
              swatch: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(colors: [
                    Color(0xFFC23B22),
                    Color(0xFFC9A227),
                    Color(0xFF3E6B3A),
                    Color(0xFF2E5A88),
                    Color(0xFFC23B22),
                  ]),
                ),
              ),
            ),
          );
        }
        final def = items[i];
        final locked =
            ScholarThemes.isProTheme(def.id) && !settings.isPro;
        final selected = settings.themeId == def.id;
        return GestureDetector(
          onTap: () {
            if (locked) {
              audio.invalid();
              return;
            }
            audio.click();
            settings.setTheme(def.id);
          },
          child: _swatchTile(
            t: t,
            selected: selected,
            locked: locked,
            label: def.name,
            swatch: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.3),
                  colors: [def.woodLight, def.woodDeep],
                ),
                border: Border.all(
                    color: def.accent.withValues(alpha: 0.7), width: 3),
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: def.accent,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _swatchTile({
    required ScholarThemeDef t,
    required bool selected,
    required bool locked,
    required String label,
    required Widget swatch,
  }) {
    return Opacity(
      opacity: locked ? 0.55 : 1.0,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? t.accent : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: swatch,
              ),
              if (locked)
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: Icon(Icons.lock, size: 16, color: Colors.black54),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label,
              style: Scholar.label(9, theme: t),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Stone style swatches.
class _StoneGrid extends StatelessWidget {
  final ScholarThemeDef theme;
  final GomokuSettings settings;
  final ScholarAudio audio;
  const _StoneGrid(
      {required this.theme, required this.settings, required this.audio});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 8,
        childAspectRatio: 0.72,
      ),
      itemCount: StoneStyles.names.length,
      itemBuilder: (_, i) {
        final locked = StoneStyles.isPro(i) && !settings.isPro;
        final selected = settings.stoneStyle == i;
        final pair = StoneStyles.pairs[i];
        return Opacity(
          opacity: locked ? 0.55 : 1.0,
          child: GestureDetector(
            onTap: () {
              if (locked) {
                audio.invalid();
                return;
              }
              audio.click();
              settings.setStoneStyle(i);
            },
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? t.accent : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _stoneDot(pair[0]),
                          const SizedBox(width: 2),
                          _stoneDot(pair[1]),
                        ],
                      ),
                    ),
                    if (locked)
                      const Positioned(
                        right: 2,
                        bottom: 2,
                        child: Icon(Icons.lock,
                            size: 14, color: Colors.black54),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(StoneStyles.names[i],
                    style: Scholar.label(8, theme: t),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _stoneDot(List<Color> base) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.35),
          colors: [base[1], base[0]],
        ),
        border:
            Border.all(color: Colors.black.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: const Offset(0, 2),
            blurRadius: 3,
          ),
        ],
      ),
    );
  }
}

/// Last-move marker styles (board accents).
class _MarkerGrid extends StatelessWidget {
  final ScholarThemeDef theme;
  final GomokuSettings settings;
  final ScholarAudio audio;
  const _MarkerGrid(
      {required this.theme, required this.settings, required this.audio});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (int i = 0; i < MarkerStyles.names.length; i++)
          _markerChip(t, i),
      ],
    );
  }

  Widget _markerChip(ScholarThemeDef t, int i) {
    final locked = MarkerStyles.isPro(i) && !settings.isPro;
    final selected = settings.markerStyle == i;
    return Opacity(
      opacity: locked ? 0.55 : 1.0,
      child: GestureDetector(
        onTap: () {
          if (locked) {
            audio.invalid();
            return;
          }
          audio.click();
          settings.setMarkerStyle(i);
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? t.accent.withValues(alpha: 0.25)
                : t.paper,
            border: Border.all(
              color: selected ? t.accent : t.woodMid.withValues(alpha: 0.5),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (locked)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child:
                      Icon(Icons.lock, size: 13, color: Colors.black54),
                ),
              Text(MarkerStyles.names[i],
                  style: Scholar.label(11, theme: t)),
            ],
          ),
        ),
      ),
    );
  }
}
