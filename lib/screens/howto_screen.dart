import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/scholar.dart';
import '../theme/scholar_themes.dart';

/// How to play — a scholar's scroll of the freestyle Gomoku rules.
class HowToScreen extends StatelessWidget {
  final ScholarAudio audio;
  final GomokuSettings settings;
  const HowToScreen(
      {super.key, required this.audio, required this.settings});

  ScholarThemeDef get _t => ScholarThemes.byId(
        settings.themeId,
        custom: settings.customTheme,
      );

  @override
  Widget build(BuildContext context) {
    final t = _t;
    const sections = [
      ('Objective',
          'Be the first to place five of your stones in an unbroken row — horizontally, vertically, or diagonally — on the 15×15 board.'),
      ('Setup',
          'The board starts empty. Black always moves first. Against the bot you may play Black or White; in Two Players, seat one is Black.'),
      ('Your Turn',
          'Tap any empty intersection to place one stone. Stones are never moved or removed. There are no captures in Gomoku.'),
      ('Winning',
          'Five or MORE in a row wins immediately — an overline of six still counts in freestyle rules. Double-threes and double-fours are all legal; there are no forbidden moves.'),
      ('Draws',
          'If the whole board fills with no five-in-a-row, the game is a draw. In Two Players either side may offer a draw.'),
      ('Swap Opening (optional)',
          'The first player places three stones (two Black, one White); the second player then chooses which color to play. This balances Black\'s strong first-move advantage.'),
      ('Undo & Resign',
          'Undo takes back the last full round. Either player may resign at any time — the other side wins.'),
      ('Bot Strength',
          'Beginner plays loose and playful. Skilled blocks your threats and builds its own. Master thinks two moves deep — a true scholar\'s duel.'),
    ];
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
              audio.click();
              Navigator.of(context).pop();
            },
          ),
          title:
              Text('How to Play', style: Scholar.display(22, theme: t)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: PaperCard(
              theme: t,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SealStamp(size: 30, theme: t),
                      const SizedBox(width: 10),
                      Text('The Scholar\'s Rules',
                          style: Scholar.display(20, theme: t)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final (title, body) in sections) ...[
                    Text(title, style: Scholar.label(14, theme: t)),
                    const SizedBox(height: 4),
                    Text(body,
                        style: Scholar.body(14,
                            theme: t, color: t.inkText)),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
