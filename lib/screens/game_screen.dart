import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../state/game.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/board.dart';
import '../widgets/wood.dart';

/// The scholar's match screen: lacquer top plaque, kaya board, rosewood
/// player panel and a wooden action deck (Undo, Hint, Resign, Menu).
class GameScreen extends StatelessWidget {
  final GameState game;
  final GomokuSettings settings;
  final SoundService sound;
  final bool reviewMode;
  final VoidCallback onReviewDone;
  final VoidCallback onPauseSettings;
  final VoidCallback onQuitToMenu;

  const GameScreen({
    super.key,
    required this.game,
    required this.settings,
    required this.sound,
    required this.reviewMode,
    required this.onReviewDone,
    required this.onPauseSettings,
    required this.onQuitToMenu,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([game, settings]),
      builder: (_, _) => Scaffold(
        backgroundColor: GomokuTheme.ricePaper,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _topPlaque(),
                  if (game.swapPlacing) _swapBanner(),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: KayaBoard(
                            board: game.eng.board,
                            lastMove: game.eng.last,
                            invalidAt: game.invalidAt,
                            hintAt: game.hintAt,
                            winLine: game.winLine,
                            showCoordinates:
                                settings.showCoordinates,
                            showLastMoveMarker:
                                settings.lastMoveMarker,
                            interactive: !reviewMode &&
                                !game.paused &&
                                !game.swapChoicePending,
                            onTap: game.tapPoint,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _bottomPanel(context),
                ],
              ),
              if (reviewMode) _reviewBar(),
              if (game.paused && !reviewMode) _pauseOverlay(context),
              if (game.swapChoicePending) _swapChoiceOverlay(),
              if (game.drawOfferedBy >= 0) _drawOfferOverlay(context),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- top lacquer plaque ----------------

  Widget _topPlaque() {
    final turnSeat = game.turnSeat;
    final turnColor = game.turnColor;
    final name = game.mode == GameMode.vsBot && turnSeat == 1
        ? game.botTitle
        : game.seatName(turnSeat);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: GomokuTheme.lacquer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: GomokuTheme.emberGold.withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(
              color: GomokuTheme.woodShadow,
              blurRadius: 10,
              offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          MiniStone(black: turnColor == 1, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GomokuTheme.body(15,
                        color: GomokuTheme.washi,
                        weight: FontWeight.w600)),
                Text(
                    game.botThinking
                        ? 'placing a stone…'
                        : game.swapPlacing
                            ? 'opening placement'
                            : 'to move',
                    style: GomokuTheme.label(12,
                        color: GomokuTheme.washi
                            .withValues(alpha: 0.6))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('move ${game.moves}',
                  style: GomokuTheme.counter(14,
                      color: GomokuTheme.washi)),
              Text(game.clockLabel,
                  style: GomokuTheme.counter(14,
                      color: GomokuTheme.washi
                          .withValues(alpha: 0.75))),
            ],
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: reviewMode
                ? null
                : () {
                    sound.playTap();
                    game.pause();
                  },
            child: Opacity(
              opacity: reviewMode ? 0.35 : 1,
              child: Container(
                width: GomokuTheme.touch,
                height: GomokuTheme.touch,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: GomokuTheme.kayaAmber,
                  border: Border.all(
                      color: GomokuTheme.kayaDeep),
                ),
                child: Icon(
                    game.paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    color: GomokuTheme.lacquer),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _swapBanner() {
    final labels = [
      'Place the first black stone — anywhere',
      'Place the second black stone — anywhere',
      'Place the white stone — anywhere',
    ];
    return Container(
      margin:
          const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: GomokuTheme.washi,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GomokuTheme.cinnabar, width: 1.4),
      ),
      child: Row(
        children: [
          const SealStamp(size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Swap opening · stone ${game.swapPlaced + 1} of 3',
                    style: GomokuTheme.body(13,
                        weight: FontWeight.w600)),
                Text(labels[game.swapPlaced.clamp(0, 2)],
                    style: GomokuTheme.label(12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- bottom panel + action deck ----------------

  Widget _bottomPanel(BuildContext context) {
    final mySeat = game.mode == GameMode.vsBot ? 0 : game.turnSeat;
    final myColor = game.seatColor[mySeat];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF4A3220),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: GomokuTheme.kayaDeep.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(
              color: GomokuTheme.woodShadow,
              blurRadius: 10,
              offset: Offset(0, -2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              MiniStone(black: myColor == 1, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    game.mode == GameMode.vsBot
                        ? 'You play ${myColor == 1 ? 'black' : 'white'}'
                        : '${game.seatName(0)} · ${game.seatName(1)}',
                    style: GomokuTheme.body(13,
                        color: GomokuTheme.washi)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ScholarDisc(
                  icon: Icons.undo_rounded,
                  label: 'Undo',
                  onTap:
                      game.canUndo && !reviewMode ? game.undo : null),
              ScholarDisc(
                  icon: Icons.lightbulb_outline_rounded,
                  label: 'Hint',
                  onTap:
                      game.canHint && !reviewMode ? game.hint : null),
              ScholarDisc(
                  icon: Icons.flag_outlined,
                  label: 'Resign',
                  tint: GomokuTheme.sealDeep,
                  onTap: !reviewMode && !game.over
                      ? () => _confirmResign(context)
                      : null),
              if (game.mode == GameMode.twoPlayer)
                ScholarDisc(
                    icon: Icons.handshake_outlined,
                    label: 'Draw',
                    onTap: !reviewMode &&
                            !game.over &&
                            game.drawOfferedBy < 0
                        ? game.offerDraw
                        : null),
              ScholarDisc(
                  icon: Icons.home_outlined,
                  label: 'Menu',
                  onTap: () {
                    sound.playTap();
                    onQuitToMenu();
                  }),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmResign(BuildContext context) {
    void doIt() {
      Navigator.of(context).maybePop();
      final seat = game.mode == GameMode.vsBot
          ? 0
          : game.turnSeat;
      game.resign(seat);
    }
    if (!settings.confirmResign) {
      doIt();
      return;
    }
    sound.playTap();
    showDialog(
      context: context,
      builder: (_) => _ScholarDialog(
        title: 'Resign this game?',
        body: 'Your opponent will take the win.',
        actions: [
          ('Keep playing', false),
          ('Resign', true),
        ],
        onPick: (resign) {
          if (resign) {
            doIt();
          } else {
            sound.playTap();
          }
        },
      ),
    );
  }

  // ---------------- overlays ----------------

  Widget _reviewBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: GomokuTheme.lacquer.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text('Reviewing the final board',
                  style: GomokuTheme.body(14,
                      color: GomokuTheme.washi)),
            ),
            GestureDetector(
              onTap: () {
                sound.playTap();
                onReviewDone();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: GomokuTheme.kayaAmber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Back',
                    style: GomokuTheme.body(14,
                        weight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pauseOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: PaperCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Paused',
                    style: GomokuTheme.display(28)),
                const SizedBox(height: 4),
                Text('the stones wait for you',
                    style: GomokuTheme.label(13)),
                const SizedBox(height: 18),
                ScholarButton(
                    label: 'Resume',
                    width: 220,
                    onTap: () {
                      sound.playTap();
                      game.resume();
                    }),
                const SizedBox(height: 10),
                ScholarButton(
                    label: 'Settings',
                    primary: false,
                    width: 220,
                    onTap: () {
                      sound.playTap();
                      onPauseSettings();
                    }),
                const SizedBox(height: 10),
                ScholarButton(
                    label: 'Quit to menu',
                    primary: false,
                    width: 220,
                    onTap: () {
                      sound.playTap();
                      onQuitToMenu();
                    }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _swapChoiceOverlay() {
    final chooser = game.mode == GameMode.vsBot
        ? 'Choose your stones'
        : '${game.seatName(1)}, choose your stones';
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: PaperCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(chooser,
                    style: GomokuTheme.display(22)),
                const SizedBox(height: 4),
                Text('the opening is placed — pick a color',
                    style: GomokuTheme.label(13)),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _swapColorBtn(1, 'Black'),
                    const SizedBox(width: 18),
                    _swapColorBtn(2, 'White'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _swapColorBtn(int color, String label) {
    return GestureDetector(
      onTap: () => game.chooseSwapColor(color),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: GomokuTheme.kayaAmber
                  .withValues(alpha: 0.25),
              border: Border.all(
                  color: GomokuTheme.cinnabar, width: 1.6),
            ),
            child:
                MiniStone(black: color == 1, size: 52),
          ),
          const SizedBox(height: 6),
          Text(label, style: GomokuTheme.body(14,
              weight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _drawOfferOverlay(BuildContext context) {
    final offeredBy = game.drawOfferedBy;
    final other = 1 - offeredBy;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: PaperCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Draw offered',
                    style: GomokuTheme.display(22)),
                const SizedBox(height: 4),
                Text(
                    '${game.seatName(offeredBy)} offers a draw.\n${game.seatName(other)}, do you accept?',
                    textAlign: TextAlign.center,
                    style: GomokuTheme.label(13)),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScholarButton(
                        label: 'Decline',
                        primary: false,
                        onTap: game.declineDraw),
                    const SizedBox(width: 12),
                    ScholarButton(
                        label: 'Accept',
                        onTap: game.acceptDraw),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small styled dialog used for confirmations.
class _ScholarDialog extends StatelessWidget {
  final String title;
  final String body;
  final List<(String, bool)> actions;
  final ValueChanged<bool> onPick;
  const _ScholarDialog(
      {required this.title,
      required this.body,
      required this.actions,
      required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: PaperCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: GomokuTheme.display(20)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: GomokuTheme.label(13)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0;
                    i < actions.length;
                    i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  ScholarButton(
                    label: actions[i].$1,
                    primary: actions[i].$2,
                    onTap: () {
                      Navigator.of(context).maybePop();
                      onPick(actions[i].$2);
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
