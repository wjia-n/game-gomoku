import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../theme.dart';
import '../widgets/wood.dart';

/// How to play — a scholar's scroll of the freestyle Gomoku rules.
class HowToScreen extends StatelessWidget {
  final SoundService sound;
  final VoidCallback onBack;

  const HowToScreen(
      {super.key, required this.sound, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GomokuTheme.ricePaper,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    sound.playTap();
                    onBack();
                  },
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
                    child: const Icon(
                        Icons.arrow_back_rounded,
                        color: GomokuTheme.kayaDeep,
                        size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Text('How to Play',
                    style: GomokuTheme.display(26)),
              ],
            ),
            const SizedBox(height: 14),
            PaperCard(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _rule('The goal',
                      'Line up five of your stones in a row — horizontally, vertically, or diagonally. Six or more in a row wins too.'),
                  _rule('The board',
                      'A 15 × 15 grid of intersections. Stones rest on the crossings, not inside the squares.'),
                  _rule('Turn order',
                      'Black always moves first. Players alternate, placing exactly one stone per turn.'),
                  _rule('Legal moves',
                      'Place one stone of your color on any empty intersection. Stones are never moved or removed.'),
                  _rule('Illegal moves',
                      'Tapping an occupied intersection just shakes the board with a soft wood-tick — your turn does not pass.'),
                  _rule('Freestyle rules',
                      'No forbidden patterns here: double-threes, double-fours, and long rows are all perfectly legal.'),
                  _rule('Swap opening (optional)',
                      'The first player places three stones anywhere (two black, one white). The other player then chooses which color to play — a fair answer to black\'s first-move advantage.'),
                  _rule('Undo',
                      'Take back the last move pair in two-player games, or the last full round against the bot.'),
                  _rule('Resign & draws',
                      'Resign any time — your opponent takes the win. A full board with no five-in-a-row is a draw; in two-player games a draw can also be agreed.'),
                  _rule('The bot',
                      'Beginner plays loose and lively. Skilled blocks your fours and builds its own threats. Master thinks two moves deep — bring your best.'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text('may your lines run long',
                  style: GomokuTheme.label(13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rule(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 3,
                  height: 16,
                  color: GomokuTheme.sealDeep),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: GomokuTheme.body(15,
                        weight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Text(body,
                style: GomokuTheme.body(14,
                    color: GomokuTheme.warmGray)),
          ),
        ],
      ),
    );
  }
}
