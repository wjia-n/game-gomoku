import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const GomokuApp());

class GomokuApp extends StatelessWidget {
  const GomokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: 'Gomoku',
      tagline: 'Five in a row takes the crown! Simple to learn, sneaky to master! 🧠',
      emoji: '⭕',
      slug: 'gomoku',
      howToPlay:
          '• Tap any intersection to place your stone. Black moves first.\n• First to line up FIVE stones in a row — horizontal, vertical or diagonal — wins!\n• Watch for open threes and fours… and block your rival\'s! 😈\n• Solo vs the bot, or duel a friend on one phone!',
      playerOptions: const [1, 2],
      supportsBots: true,
      gameBuilder: (ctx, players, cb) => GomokuScreen(players: players, callbacks: cb),
    );
  }
}
