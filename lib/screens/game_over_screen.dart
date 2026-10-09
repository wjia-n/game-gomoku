import 'dart:ui';

import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../state/game.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/board.dart';
import '../widgets/wood.dart';

/// Victory screen: dimmed, blurred board with the winning five ringed in
/// cinnabar, and a washi victory card with seal stamp, result, stats.
class GameOverScreen extends StatelessWidget {
  final GameState game;
  final GomokuSettings settings;
  final SoundService sound;
  final VoidCallback onRematch;
  final VoidCallback onReview;
  final VoidCallback onMenu;

  const GameOverScreen({
    super.key,
    required this.game,
    required this.settings,
    required this.sound,
    required this.onRematch,
    required this.onReview,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final winnerColor = game.winnerColor;
    final vsBot = game.mode == GameMode.vsBot;
    final humanWon = vsBot && game.seatColor[0] == winnerColor;
    final humanLost = vsBot && winnerColor != 0 && !humanWon;

    final heading = winnerColor == 0
        ? 'DRAW'
        : humanWon
            ? 'VICTORY'
            : humanLost
                ? 'DEFEAT'
                : winnerColor == 1
                    ? 'BLACK WINS'
                    : 'WHITE WINS';

    final resultLine = winnerColor == 0
        ? 'The board is full — an honorable draw.'
        : game.wonByResign
            ? '${_loserName()} resigned. ${_winnerName()} takes the win.'
            : '${_winnerName()} lined up five in a row.';

    return AnimatedBuilder(
      animation: settings,
      builder: (_, _) => Scaffold(
        backgroundColor: GomokuTheme.ricePaper,
        body: SafeArea(
          child: Stack(
            children: [
              // dimmed, blurred board behind
              Positioned.fill(
                child: IgnorePointer(
                  child: ImageFiltered(
                    imageFilter:
                        ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Opacity(
                      opacity: 0.55,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: KayaBoard(
                              board: game.eng.board,
                              lastMove: game.eng.last,
                              invalidAt: -1,
                              hintAt: -1,
                              winLine: game.winLine,
                              showCoordinates: false,
                              showLastMoveMarker: true,
                              interactive: false,
                              onTap: (_) {},
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                    color: Colors.black.withValues(alpha: 0.35)),
              ),
              // victory card
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: PaperCard(
                    padding: const EdgeInsets.fromLTRB(
                        24, 22, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SealStamp(size: 52),
                        const SizedBox(height: 10),
                        Text(heading,
                            style: GomokuTheme.display(34,
                                weight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(resultLine,
                            textAlign: TextAlign.center,
                            style: GomokuTheme.body(14,
                                color: GomokuTheme.warmGray)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceEvenly,
                          children: [
                            _statPlaque(
                                'Moves', '${game.moves}'),
                            _statPlaque('Time',
                                game.clockLabel),
                            _statPlaque(
                                'Streak',
                                settings.streak > 0
                                    ? '×${settings.streak}'
                                    : '—'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ScholarButton(
                            label: 'Rematch',
                            width: double.infinity,
                            onTap: () {
                              sound.playTap();
                              onRematch();
                            }),
                        const SizedBox(height: 10),
                        ScholarButton(
                            label: 'Main Menu',
                            primary: false,
                            width: double.infinity,
                            onTap: () {
                              sound.playTap();
                              onMenu();
                            }),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () {
                            sound.playTap();
                            onReview();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8),
                            child: Text('Review board',
                                style: GomokuTheme.body(14,
                                    color: GomokuTheme
                                        .sealDeep,
                                    weight:
                                        FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _winnerName() {
    if (game.winnerColor == 0) return '';
    final seat =
        game.seatColor.indexOf(game.winnerColor);
    if (game.mode == GameMode.vsBot) {
      return seat == 0 ? 'You' : game.botTitle;
    }
    return game.seatName(seat);
  }

  String _loserName() {
    if (game.winnerColor == 0) return '';
    final seat =
        game.seatColor.indexOf(3 - game.winnerColor);
    if (game.mode == GameMode.vsBot) {
      return seat == 0 ? 'You' : game.botTitle;
    }
    return game.seatName(seat);
  }

  Widget _statPlaque(String label, String value) {
    return Container(
      width: 84,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: GomokuTheme.kayaAmber
            .withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: GomokuTheme.kayaDeep
                .withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(value, style: GomokuTheme.counter(17)),
          const SizedBox(height: 2),
          Text(label, style: GomokuTheme.label(11)),
        ],
      ),
    );
  }
}
