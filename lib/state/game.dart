import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../audio/sound.dart';
import '../engine/bot.dart';
import '../engine/gomoku_engine.dart';
import 'settings.dart';

enum GameMode { vsBot, twoPlayer }

class _Snap {
  final List<int> board;
  final bool blackTurn;
  final int last;
  final int moves;
  final List<int> seatColor;
  final bool swapPlacing;
  final int swapPlaced;
  _Snap(this.board, this.blackTurn, this.last, this.moves, this.seatColor,
      this.swapPlacing, this.swapPlaced);
}

/// Full game session: rules state, swap opening, bot scheduling, undo,
/// resign/draw, clock, save/resume. Screens only read; mutation goes here.
class GameState extends ChangeNotifier {
  final GomokuSettings settings;
  final SoundService sound;

  GameState({required this.settings, required this.sound});

  // ---- config ----
  GameMode mode = GameMode.vsBot;
  BotDifficulty difficulty = BotDifficulty.skilled;
  int humanColor = 1; // vsBot: human's stone color (1 black, 2 white)
  List<int> seatColor = [1, 2]; // seat 0 / seat 1 -> stone color
  bool swapOpening = false;

  // ---- live state ----
  final GomokuEngine eng = GomokuEngine();
  int moves = 0;
  int invalidAt = -1; // cell flashing after an illegal tap
  int hintAt = -1; // hinted cell
  bool botThinking = false;
  bool paused = false;
  bool over = false;
  int winnerColor = 0; // 1 black, 2 white, 0 draw
  bool wonByResign = false;
  List<int>? winLine;

  // swap opening (RULES §7)
  bool swapPlacing = false; // placing the 3 opening stones
  int swapPlaced = 0;
  bool swapChoicePending = false;

  // draw offer (two player)
  int drawOfferedBy = -1;

  // clock
  Duration elapsed = Duration.zero;
  Timer? _clock;

  final List<_Snap> _undos = [];
  int _gen = 0;
  late Random _botRng;

  // ---- derived ----

  int get botColor => 3 - humanColor;
  int get turnColor => eng.blackTurn ? 1 : 2;
  int get turnSeat => seatColor.indexOf(turnColor);

  bool get isHumanTurn =>
      mode == GameMode.twoPlayer || swapPlacing || turnSeat == 0;

  bool get canUndo =>
      settings.undoAllowed &&
      !over &&
      !paused &&
      !swapChoicePending &&
      _undos.isNotEmpty;

  bool get canHint =>
      !over &&
      !paused &&
      !swapPlacing &&
      !swapChoicePending &&
      isHumanTurn &&
      !botThinking;

  String seatName(int seat) {
    if (mode == GameMode.vsBot) {
      return seat == 0 ? 'You' : 'Bot';
    }
    return seat == 0 ? 'Player One' : 'Player Two';
  }

  String get botTitle {
    const names = {
      BotDifficulty.beginner: 'Beginner',
      BotDifficulty.skilled: 'Skilled',
      BotDifficulty.master: 'Master',
    };
    return 'Bot · ${names[difficulty]}';
  }

  String get clockLabel {
    final m = elapsed.inMinutes;
    final s = elapsed.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ================= setup =================

  void newGame(
      {required GameMode mode,
      BotDifficulty? difficulty,
      int? humanColor,
      bool? swapOpening}) {
    _gen++;
    _clock?.cancel();
    this.mode = mode;
    this.difficulty = difficulty ?? settings.difficulty;
    this.humanColor = humanColor ?? settings.humanColor;
    this.swapOpening = swapOpening ?? settings.swapOpening;
    seatColor = [this.humanColor, 3 - this.humanColor];

    eng.reset();
    moves = 0;
    invalidAt = -1;
    hintAt = -1;
    botThinking = false;
    paused = false;
    over = false;
    winnerColor = 0;
    wonByResign = false;
    winLine = null;
    swapPlaced = 0;
    swapChoicePending = false;
    drawOfferedBy = -1;
    _undos.clear();
    elapsed = Duration.zero;
    _botRng = Random();

    // Swap opening: the first player places 2 black + 1 white anywhere,
    // then the chooser picks a color (RULES §7).
    swapPlacing = this.swapOpening;

    sound.playStart();
    _startClock();
    notifyListeners();
    _persist();
    _maybeBot();
  }

  /// Restores a mid-game save. Returns false if the data is unusable.
  bool restore(Map<String, dynamic> j) {
    try {
      _gen++;
      _clock?.cancel();
      mode = GameMode.values[j['mode'] as int];
      difficulty = BotDifficulty.values[j['difficulty'] as int];
      humanColor = j['humanColor'] as int;
      seatColor = (j['seatColor'] as List).cast<int>().toList();
      swapOpening = j['swapOpening'] as bool;
      final bd = (j['board'] as List).cast<int>().toList();
      if (bd.length != GomokuEngine.n * GomokuEngine.n) return false;
      eng.board = bd;
      eng.blackTurn = j['blackTurn'] as bool;
      eng.last = j['last'] as int;
      eng.winLine = null;
      moves = j['moves'] as int;
      swapPlaced = j['swapPlaced'] as int? ?? 0;
      swapPlacing = j['swapPlacing'] as bool? ?? false;
      elapsed = Duration(seconds: j['elapsedSec'] as int? ?? 0);
      invalidAt = -1;
      hintAt = -1;
      botThinking = false;
      paused = false;
      over = false;
      winnerColor = 0;
      wonByResign = false;
      winLine = null;
      swapChoicePending = false;
      drawOfferedBy = -1;
      _undos.clear();
      _botRng = Random();
      _startClock();
      notifyListeners();
      _maybeBot();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ================= moves =================

  void _pushUndo() {
    _undos.add(_Snap(
        List<int>.from(eng.board),
        eng.blackTurn,
        eng.last,
        moves,
        List<int>.from(seatColor),
        swapPlacing,
        swapPlaced));
    if (_undos.length > 200) _undos.removeAt(0);
  }

  void _restore(_Snap s) {
    eng.board = s.board;
    eng.blackTurn = s.blackTurn;
    eng.last = s.last;
    eng.winLine = null;
    moves = s.moves;
    seatColor = s.seatColor;
    swapPlacing = s.swapPlacing;
    swapPlaced = s.swapPlaced;
    winLine = null;
  }

  void undo() {
    if (!canUndo) return;
    _gen++;
    botThinking = false;
    if (swapPlacing) {
      // take back a single placement stone
      if (_undos.isNotEmpty) _restore(_undos.removeLast());
    } else if (mode == GameMode.twoPlayer) {
      // one full round = both players' last moves (RULES §7)
      for (var k = 0; k < 2 && _undos.isNotEmpty; k++) {
        _restore(_undos.removeLast());
      }
    } else {
      // vs bot: take back the player's and the bot's last moves
      _restore(_undos.removeLast());
      while (_undos.isNotEmpty && !isHumanTurn) {
        _restore(_undos.removeLast());
      }
    }
    invalidAt = -1;
    hintAt = -1;
    sound.playUndo();
    notifyListeners();
    _persist();
    _maybeBot();
  }

  /// Tap on intersection [i]. Illegal taps shake + soft wood-tick (RULES §12).
  void tapPoint(int i) {
    if (over || paused) return;
    if (swapChoicePending || !isHumanTurn || botThinking) return;
    if (i < 0 || i >= GomokuEngine.n * GomokuEngine.n) return;

    if (swapPlacing) {
      _tapSwap(i);
      return;
    }
    if (eng.board[i] != 0) {
      _illegal(i);
      return;
    }
    _pushUndo();
    final color = turnColor;
    eng.place(i);
    moves++;
    invalidAt = -1;
    hintAt = -1;
    sound.playStone(color == 1);
    final wl = eng.winLine;
    if (wl != null) {
      _finishWin(color, wl, byResign: false);
      return;
    }
    if (eng.full) {
      _finishDraw();
      return;
    }
    notifyListeners();
    _persist();
    _maybeBot();
  }

  void _tapSwap(int i) {
    if (eng.board[i] != 0) {
      _illegal(i);
      return;
    }
    _pushUndo();
    final color = swapPlaced < 2 ? 1 : 2; // two black, then one white
    eng.board[i] = color;
    eng.blackTurn = true;
    eng.last = i;
    swapPlaced++;
    sound.playStone(color == 1);
    if (swapPlaced >= 3) {
      // RULES §12: three stones can never make five — but void if they do.
      var voided = false;
      for (var k = 0; k < eng.board.length; k++) {
        if (eng.board[k] != 0 &&
            GomokuEngine.winOn(eng.board, k, eng.board[k]) != null) {
          voided = true;
          break;
        }
      }
      if (voided) {
        newGame(
            mode: mode,
            difficulty: difficulty,
            humanColor: humanColor,
            swapOpening: swapOpening);
        return;
      }
      swapPlacing = false;
      swapChoicePending = true;
      sound.playBrush();
    }
    notifyListeners();
    _persist();
  }

  /// The chooser picks which color to play after the swap placement.
  /// vsBot: the human chooses. Two players: player two chooses (RULES §7).
  void chooseSwapColor(int color) {
    if (!swapChoicePending) return;
    _gen++;
    swapChoicePending = false;
    if (mode == GameMode.vsBot) {
      humanColor = color;
      seatColor = [color, 3 - color];
    } else {
      // seat 0 placed; seat 1 chose [color] -> seat of color:
      seatColor = color == 1 ? [2, 1] : [1, 2];
    }
    eng.blackTurn = true; // black to move after the swap
    moves = 0;
    _undos.clear();
    sound.playTap();
    notifyListeners();
    _persist();
    _maybeBot();
  }

  void _illegal(int i) {
    invalidAt = i;
    sound.playInvalid();
    notifyListeners();
    final g = _gen;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (g == _gen && invalidAt == i) {
        invalidAt = -1;
        notifyListeners();
      }
    });
  }

  /// Suggests a move for the current human player (Skilled one-ply).
  void hint() {
    if (!canHint) return;
    final pick = GomokuBot.chooseMove(
        board: eng.board,
        color: turnColor,
        difficulty: BotDifficulty.skilled,
        rng: Random());
    if (pick < 0) return;
    hintAt = pick;
    sound.playBrush();
    notifyListeners();
    final g = _gen;
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (g == _gen && hintAt == pick) {
        hintAt = -1;
        notifyListeners();
      }
    });
  }

  // ================= resign / draw =================

  /// Resigns [seat]; the other seat wins (RULES §7, §9).
  void resign(int seat) {
    if (over || paused) return;
    _gen++;
    botThinking = false;
    final winner = seatColor[1 - seat];
    wonByResign = true;
    sound.playResign();
    _finishWin(winner, const [], byResign: true);
  }

  /// Two-player draw offer (RULES §10).
  void offerDraw() {
    if (over || paused || mode != GameMode.twoPlayer) return;
    drawOfferedBy = turnSeat;
    sound.playTap();
    notifyListeners();
  }

  void acceptDraw() {
    if (drawOfferedBy < 0) return;
    drawOfferedBy = -1;
    _finishDraw();
  }

  void declineDraw() {
    drawOfferedBy = -1;
    sound.playTap();
    notifyListeners();
  }

  // ================= finishing =================

  void _finishWin(int color, List<int> line, {required bool byResign}) {
    _gen++;
    _clock?.cancel();
    botThinking = false;
    over = true;
    winnerColor = color;
    wonByResign = byResign;
    winLine = line.isEmpty ? null : List<int>.from(line);
    final humanWon = mode == GameMode.twoPlayer || seatColor[0] == color;
    if (humanWon) {
      sound.playWin();
    } else {
      sound.playLose();
    }
    settings.recordResult(color);
    settings.clearSavedGame();
    notifyListeners();
  }

  void _finishDraw() {
    _gen++;
    _clock?.cancel();
    botThinking = false;
    over = true;
    winnerColor = 0;
    wonByResign = false;
    winLine = null;
    sound.playBrush();
    settings.recordResult(0);
    settings.clearSavedGame();
    notifyListeners();
  }

  // ================= pause =================

  void pause() {
    if (over || paused) return;
    paused = true;
    cancelBot();
    _clock?.cancel();
    notifyListeners();
  }

  void resume() {
    if (!paused || over) return;
    paused = false;
    _startClock();
    notifyListeners();
    _maybeBot();
  }

  // ================= bot =================

  void _maybeBot() {
    if (over ||
        paused ||
        swapPlacing ||
        swapChoicePending ||
        mode != GameMode.vsBot ||
        turnColor == humanColor) {
      return;
    }
    botThinking = true;
    notifyListeners();
    final g = _gen;
    Future.delayed(Duration(milliseconds: 550 + _botRng.nextInt(450)), () {
      if (_gen != g || over || paused) return;
      if (mode != GameMode.vsBot || turnColor == humanColor) return;
      if (swapPlacing || swapChoicePending) return;
      botThinking = false;
      final pick = GomokuBot.chooseMove(
          board: eng.board,
          color: turnColor,
          difficulty: difficulty,
          rng: _botRng);
      if (pick < 0 || eng.board[pick] != 0) {
        // no legal move — board must be full
        if (eng.full) {
          _finishDraw();
        }
        return;
      }
      _pushUndo();
      final color = turnColor;
      eng.place(pick);
      moves++;
      invalidAt = -1;
      sound.playStone(color == 1);
      final wl = eng.winLine;
      if (wl != null) {
        _finishWin(color, wl, byResign: false);
        return;
      }
      if (eng.full) {
        _finishDraw();
        return;
      }
      notifyListeners();
      _persist();
    });
  }

  /// Cancels any scheduled bot move (used by pause / lifecycle).
  void cancelBot() {
    _gen++;
    botThinking = false;
    notifyListeners();
  }

  /// Re-arms the bot after a pause (no-op unless it is the bot's turn).
  void nudgeBot() => _maybeBot();

  // ================= clock =================

  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (paused || over) return;
      elapsed += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  // ================= persistence =================

  void _persist() {
    if (over) return;
    settings.saveGame({
      'mode': mode.index,
      'difficulty': difficulty.index,
      'humanColor': humanColor,
      'seatColor': seatColor,
      'swapOpening': swapOpening,
      'board': eng.board,
      'blackTurn': eng.blackTurn,
      'last': eng.last,
      'moves': moves,
      'elapsedSec': elapsed.inSeconds,
      'swapPlaced': swapPlaced,
      'swapPlacing': swapPlacing,
    });
  }

  void disposeState() {
    _clock?.cancel();
  }
}
