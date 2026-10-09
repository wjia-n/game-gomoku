import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../engine/bot.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/wood.dart';

/// Scholar's settings: grouped washi panels — Sound, Board & Stones, Game.
class SettingsScreen extends StatelessWidget {
  final GomokuSettings settings;
  final SoundService sound;
  final VoidCallback onBack;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.sound,
    required this.onBack,
  });

  void _applyAudio() {
    sound.applySettings(
        sfxOn: settings.sfxOn,
        musicOn: settings.musicOn,
        sfxVolume: settings.sfxVolume,
        musicVolume: settings.musicVolume);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (_, _) => Scaffold(
        backgroundColor: GomokuTheme.ricePaper,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Row(
                children: [
                  _iconBtn(Icons.arrow_back_rounded, () {
                    sound.playTap();
                    onBack();
                  }),
                  const SizedBox(width: 12),
                  Text('Settings',
                      style: GomokuTheme.display(26)),
                ],
              ),
              const SizedBox(height: 16),
              // ---- sound ----
              const SectionHead(title: 'Sound'),
              const SizedBox(height: 8),
              PaperCard(
                child: Column(
                  children: [
                    _row('Music', StoneToggle(
                      value: settings.musicOn,
                      onChanged: (v) {
                        settings.update(
                            () => settings.musicOn = v);
                        _applyAudio();
                      },
                    )),
                    BambooSlider(
                      value: settings.musicVolume,
                      onChanged: (v) {
                        settings.update(
                            () => settings.musicVolume = v);
                        _applyAudio();
                      },
                    ),
                    const BrushDivider(),
                    _row('Sound effects', StoneToggle(
                      value: settings.sfxOn,
                      onChanged: (v) {
                        settings.update(
                            () => settings.sfxOn = v);
                        _applyAudio();
                        sound.playTap();
                      },
                    )),
                    BambooSlider(
                      value: settings.sfxVolume,
                      onChanged: (v) {
                        settings.update(
                            () => settings.sfxVolume = v);
                        _applyAudio();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // ---- board & stones ----
              const SectionHead(title: 'Board & Stones'),
              const SizedBox(height: 8),
              PaperCard(
                child: Column(
                  children: [
                    _row('Last-move seal marker',
                        StoneToggle(
                      value: settings.lastMoveMarker,
                      onChanged: (v) {
                        sound.playTap();
                        settings.update(() =>
                            settings.lastMoveMarker = v);
                      },
                    )),
                    const SizedBox(height: 10),
                    _row('Board coordinates',
                        StoneToggle(
                      value: settings.showCoordinates,
                      onChanged: (v) {
                        sound.playTap();
                        settings.update(() =>
                            settings.showCoordinates = v);
                      },
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // ---- game ----
              const SectionHead(title: 'Game'),
              const SizedBox(height: 8),
              PaperCard(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _row('Swap opening', StoneToggle(
                      value: settings.swapOpening,
                      onChanged: (v) {
                        sound.playTap();
                        settings.update(
                            () => settings.swapOpening = v);
                      },
                    )),
                    Padding(
                      padding: const EdgeInsets.only(
                          top: 4, bottom: 10),
                      child: Text(
                          'first player places 3 stones (2 black, 1 white), then the other chooses a color',
                          style:
                              GomokuTheme.label(12)),
                    ),
                    _row('Confirm before resign',
                        StoneToggle(
                      value: settings.confirmResign,
                      onChanged: (v) {
                        sound.playTap();
                        settings.update(() =>
                            settings.confirmResign = v);
                      },
                    )),
                    const SizedBox(height: 10),
                    _row('Allow undo', StoneToggle(
                      value: settings.undoAllowed,
                      onChanged: (v) {
                        sound.playTap();
                        settings.update(
                            () => settings.undoAllowed = v);
                      },
                    )),
                    const SizedBox(height: 14),
                    Text('Bot strength',
                        style: GomokuTheme.body(14,
                            weight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    WoodSegmented<BotDifficulty>(
                      values: BotDifficulty.values,
                      labels: const [
                        'Beginner',
                        'Skilled',
                        'Master'
                      ],
                      current: settings.difficulty,
                      onChanged: (v) {
                        sound.playTap();
                        settings.update(
                            () => settings.difficulty = v);
                      },
                    ),
                    const SizedBox(height: 14),
                    Text('Your stones (vs bot)',
                        style: GomokuTheme.body(14,
                            weight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    WoodSegmented<int>(
                      values: const [1, 2],
                      labels: const [
                        'Black · first',
                        'White'
                      ],
                      current: settings.humanColor,
                      onChanged: (v) {
                        sound.playTap();
                        settings.update(
                            () => settings.humanColor = v);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionHead(title: 'Match record'),
              const SizedBox(height: 8),
              PaperCard(
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly,
                  children: [
                    _stat('Black wins', '${settings.wins}'),
                    _stat('White wins',
                        '${settings.losses}'),
                    _stat(
                        'Draws', '${settings.draws}'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ScholarButton(
                  label: 'Reset to defaults',
                  primary: false,
                  width: double.infinity,
                  onTap: () {
                    sound.playTap();
                    settings.resetDefaults();
                    _applyAudio();
                  }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, Widget control) => Row(
        children: [
          Expanded(
              child: Text(label,
                  style: GomokuTheme.body(15,
                      weight: FontWeight.w500))),
          control,
        ],
      );

  Widget _stat(String label, String value) => Column(
        children: [
          Text(value, style: GomokuTheme.counter(20)),
          Text(label, style: GomokuTheme.label(11)),
        ],
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
              color: GomokuTheme.warmGray
                  .withValues(alpha: 0.4)),
          boxShadow: const [
            BoxShadow(
                color: GomokuTheme.woodShadow,
                blurRadius: 6,
                offset: Offset(0, 3)),
          ],
        ),
        child: Icon(icon,
            color: GomokuTheme.kayaDeep, size: 22),
      ),
    );
  }
}
