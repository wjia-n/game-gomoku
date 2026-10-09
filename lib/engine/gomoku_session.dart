import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../services/settings_service.dart';
import 'bot.dart';
import 'gomoku_engine.dart';

/// Game mode: vs the bot, or two humans sharing the device.
enum GameMode { vsBot, twoPlayer }

/// Turn phases owned entirely by the session (the engine layer). The UI only
/// renders; it never advances the game on its own timers.
///
/// - [awaitingHuman]: a human may tap. The only forward action is input.
/// - [botThinking]: the bot is "thinking" — narration shows on its tray,
///   input is locked, and a session timer will trigger the move.
/// - [placing]: a stone's visible placement animation is in flight; input is
///   locked and a session timer settles the move (win/draw/next turn).
/// - [swapPlacing]: the 3 swap-opening stones are being placed.
/// - [swapChoice]: the chooser must pick a color.
/// - [over]: terminal; only rematch/menu are legal.
enum Phase {
  awaitingHuman,
  botThinking,
  placing,
  swapPlacing,
  swapChoice,
  over,
}

/// UI/sound hook events emitted by the session.
enum GomokuEvent {
  stonePlaced,
  swapStonePlaced,
  invalid,
  undo,
  hint,
  win,
  lose,
  draw,
  resign,
  swapReady,
}

/// Undo snapshot.
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

/// Full game session: rules state, turn state machine, swap opening, bot
/// scheduling, watchdog, undo, resign/draw, clock, save/resume.
///
/// The session owns ALL turn state (RULES.md is enforced here, not in the
/// UI). A watchdog timer recovers any phase found without a live timer, so
/// stuck states are impossible by construction.
class GomokuSession extends ChangeNotifier {
  final GomokuSettings settings;

  GomokuSession({required this.settings});

  // ---- config ----
  GameMode mode = GameMode.vsBot;
  BotDifficulty difficulty = BotDifficulty.skilled;
  int humanColor = 1; // vsBot setup: human's stone color (1 black, 2 white)
  List<int> seatColor = [1, 2]; // seat -> stone color
  bool swapOpening = false;

  // ---- live state ----
  final GomokuEngine eng = GomokuEngine();
  Phase phase = Phase.awaitingHuman;
  int moves = 0;
  int invalidAt = -1;
  int hintAt = -1;
  int placingCell = -1; // stone currently animating its placement
  int placingColor = 0;
  int placingId = 0; // bumped so the UI re-keys the placement animation
  bool paused = false;
  bool over = false;
  int winnerColor = 0; // 1 black, 2 white, 0 draw
  bool wonByResign = false;
  List<int>? winLine;

  // swap opening (RULES §7)
  bool swapPlacing = false;
  int swapPlaced = 0;
  bool _swapBotPlacer = false;

  // draw offer (two player only, RULES §10)
  int drawOfferedBy = -1;

  // clock
  Duration elapsed = Duration.zero;
  Timer? _clock;

  final List<_Snap> _undos = [];
  final Random _rng = Random();
  int _gen = 0; // invalidates delayed UI-only callbacks
  int _lastSeat = 0; // seat that placed the most recent stone
  int _lastPlacedColor = 0;

  Timer? _timer; // the single phase-transition timer
  Timer? _watchdog; // stuck-state recovery
  bool _disposed = false;

  /// UI hook for sounds / haptics. Set by the screen.
  void Function(GomokuEvent event)? onEvent;

  // ---- derived ----

  int get botColor => 3 - humanColor;
  int get turnColor => eng.blackTurn ? 1 : 2;
  int get turnSeat => seatColor.indexOf(turnColor);
  bool get isBotTurn => mode == GameMode.vsBot && turnSeat == 1;

  /// A human may act right now (tap / undo / hint / resign).
  bool get isHumanTurn {
    if (over || paused) return false;
    if (mode == GameMode.twoPlayer) {
      return phase == Phase.awaitingHuman || phase == Phase.swapPlacing;
    }
    if (phase == Phase.swapPlacing) return !_swapBotPlacer;
    if (phase == Phase.swapChoice) return true;
    return phase == Phase.awaitingHuman && turnSeat == 0;
  }

  bool get botThinking => phase == Phase.botThinking;
  bool get canAct =>
      !over && !paused && (phase == Phase.awaitingHuman);

  bool get canUndo =>
      settings.undoAllowed &&
      !over &&
      !paused &&
      _undos.isNotEmpty &&
      (phase == Phase.awaitingHuman ||
          (phase == Phase.swapPlacing && !_swapBotPlacer));

  bool get canHint =>
      !over &&
      !paused &&
      phase == Phase.awaitingHuman &&
      isHumanTurn &&
      !swapPlacing;

  String seatName(int seat) {
    final names = settings.playerNames;
    if (seat < 0 || seat >= names.length) return 'Player ${seat + 1}';
    return names[seat];
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

  /// Narration line for the trays ("X is thinking…", etc.).
  String get narration {
    switch (phase) {
      case Phase.botThinking:
        return '${seatName(turnSeat)} is thinking…';
      case Phase.placing:
        return '${seatName(_lastSeat)} places a stone…';
      case Phase.swapPlacing:
        if (_swapBotPlacer) {
          return '${seatName(1)} places the opening stones…';
        }
        return 'Place 3 stones: 2 black, 1 white';
      case Phase.swapChoice:
        return mode == GameMode.vsBot
            ? 'Choose your color, ${seatName(0)}'
            : '${seatName(1)}, choose a color';
      case Phase.awaitingHuman:
        return isHumanTurn
            ? '${seatName(turnSeat)}, your move'
            : '${seatName(turnSeat)} to move';
      case Phase.over:
        if (winnerColor == 0) return 'A scholarly draw.';
        return '${seatName(seatColor.indexOf(winnerColor))} wins!';
    }
  }

  // ================= setup =================

  void newGame({
    required GameMode mode,
    BotDifficulty? difficulty,
    int? humanColor,
    bool? swapOpening,
  }) {
    _gen++;
    _timer?.cancel();
    _timer = null;
    _clock?.cancel();
    this.mode = mode;
    this.difficulty = difficulty ?? settings.difficulty;
    this.humanColor = humanColor ?? settings.humanColor;
    this.swapOpening = swapOpening ?? settings.swapOpening;
    seatColor = [this.humanColor, 3 - this.humanColor];

    eng.reset();
    phase = Phase.awaitingHuman;
    moves = 0;
    invalidAt = -1;
    hintAt = -1;
    placingCell = -1;
    placingColor = 0;
    paused = false;
    over = false;
    winnerColor = 0;
    wonByResign = false;
    winLine = null;
    swapPlaced = 0;
    swapPlacing = this.swapOpening;
    drawOfferedBy = -1;
    _undos.clear();
    _lastSeat = 0;
    _lastPlacedColor = 0;
    elapsed = Duration.zero;

    _watchdog ??=
        Timer.periodic(const Duration(seconds: 2), (_) => _recover());

    if (swapPlacing) {
      _beginSwap();
    }
    _startClock();
    notifyListeners();
    _persist();
    if (!swapPlacing) _beginTurn();
  }

  /// Restores a mid-game save. Returns false if the data is unusable.
  bool restore(Map<String, dynamic> j) {
    try {
      _gen++;
      _timer?.cancel();
      _timer = null;
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
      _swapBotPlacer = j['swapBotPlacer'] as bool? ?? false;
      elapsed = Duration(seconds: j['elapsedSec'] as int? ?? 0);
      invalidAt = -1;
      hintAt = -1;
      placingCell = -1;
      paused = false;
      over = false;
      winnerColor = 0;
      wonByResign = false;
      winLine = null;
      drawOfferedBy = -1;
      _undos.clear();
      _watchdog ??=
          Timer.periodic(const Duration(seconds: 2), (_) => _recover());
      _startClock();
      notifyListeners();
      final swapChoice = j['swapChoice'] as bool? ?? false;
      if (swapPlacing) {
        if (_swapBotPlacer && mode == GameMode.vsBot) {
          phase = Phase.swapPlacing;
          _arm(const Duration(milliseconds: 700), _botSwapStep);
        } else {
          phase = Phase.swapPlacing;
        }
      } else if (swapChoice) {
        phase = Phase.swapChoice;
      } else {
        _beginTurn();
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ================= turn state machine =================

  /// Arms the single phase-transition timer. Cancelled by pause/dispose.
  void _arm(Duration d, void Function() fn) {
    if (_disposed || paused) return;
    _timer?.cancel();
    _timer = Timer(d, () {
      _timer = null;
      if (!_disposed && !paused) fn();
    });
  }

  /// Watchdog: if the single phase timer ever dies without progress,
  /// recover the phase. Input-waiting phases need no timer (a legal forward
  /// action always exists there). This makes stuck states impossible by
  /// construction. Respects [paused].
  void _recover() {
    if (_disposed || over || paused || _timer != null) return;
    switch (phase) {
      case Phase.botThinking:
        _scheduleBotThink();
        break;
      case Phase.placing:
        _finishPlacement();
        break;
      case Phase.swapPlacing:
        if (_swapBotPlacer) {
          _arm(const Duration(milliseconds: 400), _botSwapStep);
        }
        break;
      case Phase.awaitingHuman:
      case Phase.swapChoice:
      case Phase.over:
        break; // waiting on input (or terminal): a legal action exists
    }
  }

  /// Test hook: kills the phase timer so the watchdog path can be exercised.
  @visibleForTesting
  void killTimerForTest() {
    _timer?.cancel();
    _timer = null;
  }

  /// Test hook: runs one watchdog pass immediately.
  @visibleForTesting
  void watchdogTickForTest() => _recover();

  /// Starts the current side's turn. Bots schedule themselves; humans wait.
  void _beginTurn() {
    if (over || _disposed || paused) return;
    if (isBotTurn) {
      phase = Phase.botThinking;
      notifyListeners();
      _scheduleBotThink();
    } else {
      phase = Phase.awaitingHuman;
      notifyListeners();
    }
  }

  void _scheduleBotThink() {
    if (over || paused || phase != Phase.botThinking) return;
    _arm(
      Duration(milliseconds: 750 + _rng.nextInt(500)),
      _botMove,
    );
  }

  /// The bot's visible turn: "thinking" was already narrated on its tray;
  /// now it picks a move and the stone animates onto the board.
  void _botMove() {
    if (over ||
        paused ||
        phase != Phase.botThinking ||
        !isBotTurn ||
        _disposed) {
      return;
    }
    final color = turnColor;
    // Compute on a copy: the bot's search mutates the board it is given.
    final pick = GomokuBot.chooseMove(
      board: List<int>.from(eng.board),
      color: color,
      difficulty: difficulty,
      rng: _rng,
    );
    if (pick < 0 || eng.board[pick] != 0) {
      // No legal move: the board must be full (RULES §10).
      if (eng.full) {
        _finishDraw();
      } else {
        _beginTurn(); // unreachable, but never strand the turn
      }
      return;
    }
    _pushUndo();
    _lastSeat = turnSeat;
    _lastPlacedColor = color;
    eng.place(pick);
    moves++;
    invalidAt = -1;
    hintAt = -1;
    placingCell = pick;
    placingColor = color;
    placingId++;
    phase = Phase.placing;
    onEvent?.call(GomokuEvent.stonePlaced);
    notifyListeners();
    _persist();
    _arm(const Duration(milliseconds: 620), _finishPlacement);
  }

  /// Settles a placed stone after its visible animation: win, draw, or next
  /// turn. Win is checked BEFORE the full-board draw (RULES §10, test 10).
  void _finishPlacement() {
    if (over || _disposed || paused) return;
    if (phase != Phase.placing) return;
    placingCell = -1;
    final wl = eng.winLine;
    if (wl != null) {
      _finishWin(_lastPlacedColor, wl, byResign: false);
      return;
    }
    if (eng.full) {
      _finishDraw();
      return;
    }
    _beginTurn();
  }

  // ================= human input =================

  /// Tap on intersection [i]. Illegal taps shake + soft wood-tick; the turn
  /// does not pass (RULES §12).
  void tapPoint(int i) {
    if (over || paused) return;
    if (i < 0 || i >= GomokuEngine.n * GomokuEngine.n) return;

    if (phase == Phase.swapPlacing && !_swapBotPlacer) {
      _tapSwap(i);
      return;
    }
    if (phase != Phase.awaitingHuman || !isHumanTurn) return;
    if (eng.board[i] != 0) {
      _illegal(i);
      return;
    }
    _pushUndo();
    final color = turnColor;
    _lastSeat = turnSeat;
    _lastPlacedColor = color;
    eng.place(i);
    moves++;
    invalidAt = -1;
    hintAt = -1;
    placingCell = i;
    placingColor = color;
    placingId++;
    phase = Phase.placing;
    onEvent?.call(GomokuEvent.stonePlaced);
    notifyListeners();
    _persist();
    _arm(const Duration(milliseconds: 420), _finishPlacement);
  }

  // ================= swap opening (RULES §7) =================

  /// The first player places 3 stones (2 black, 1 white); the second player
  /// then chooses which color to play. In vsBot the BOT is the first player
  /// (it places) and the HUMAN is the second player (it chooses) — the only
  /// faithful reading of "the second player chooses which color to play".
  /// In two-player, seat 0 places and seat 1 chooses.
  void _beginSwap() {
    swapPlacing = true;
    swapPlaced = 0;
    _swapBotPlacer = mode == GameMode.vsBot;
    if (_swapBotPlacer) {
      phase = Phase.swapPlacing;
      notifyListeners();
      _arm(const Duration(milliseconds: 800), _botSwapStep);
    } else {
      phase = Phase.swapPlacing;
      notifyListeners();
    }
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
    placingCell = i;
    placingColor = color;
    placingId++;
    onEvent?.call(GomokuEvent.swapStonePlaced);
    if (swapPlaced >= 3) {
      _finishSwapPlacement();
      return;
    }
    notifyListeners();
    _persist();
  }

  /// One bot-placed swap stone, visibly animated like a normal placement.
  void _botSwapStep() {
    if (_disposed || over || paused || phase != Phase.swapPlacing) return;
    final color = swapPlaced < 2 ? 1 : 2;
    final i = _pickSwapCell();
    eng.board[i] = color;
    eng.blackTurn = true;
    eng.last = i;
    swapPlaced++;
    placingCell = i;
    placingColor = color;
    placingId++;
    onEvent?.call(GomokuEvent.swapStonePlaced);
    notifyListeners();
    _persist();
    if (swapPlaced >= 3) {
      _arm(const Duration(milliseconds: 750), _finishSwapPlacement);
    } else {
      _arm(const Duration(milliseconds: 680), _botSwapStep);
    }
  }

  /// Scattered near-center cells, never adjacent to each other, so the
  /// human's color choice stays meaningful.
  int _pickSwapCell() {
    final mid = GomokuEngine.n ~/ 2;
    for (var attempt = 0; attempt < 300; attempt++) {
      final r = mid - 3 + _rng.nextInt(7);
      final c = mid - 3 + _rng.nextInt(7);
      if (r < 0 || r >= GomokuEngine.n || c < 0 || c >= GomokuEngine.n) {
        continue;
      }
      final i = r * GomokuEngine.n + c;
      if (eng.board[i] != 0) continue;
      var ok = true;
      for (var k = 0; k < eng.board.length; k++) {
        if (eng.board[k] != 0) {
          final kr = k ~/ GomokuEngine.n, kc = k % GomokuEngine.n;
          if ((kr - r).abs() < 2 && (kc - c).abs() < 2) {
            ok = false;
            break;
          }
        }
      }
      if (ok) return i;
    }
    return eng.board.indexOf(0); // unreachable fallback
  }

  void _finishSwapPlacement() {
    if (_disposed || over || paused) return;
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
    phase = Phase.swapChoice;
    onEvent?.call(GomokuEvent.swapReady);
    notifyListeners();
    _persist();
  }

  /// The chooser picks a color after the swap placement. Black moves first
  /// afterwards (RULES §7, test 15).
  void chooseSwapColor(int color) {
    if (phase != Phase.swapChoice || over || paused) return;
    if (color != 1 && color != 2) return;
    _gen++;
    if (mode == GameMode.vsBot) {
      humanColor = color;
      seatColor = [color, 3 - color];
    } else {
      // Seat 0 placed; seat 1 chose [color].
      seatColor = color == 1 ? [2, 1] : [1, 2];
    }
    eng.blackTurn = true; // black to move after the swap
    moves = 0;
    _undos.clear();
    onEvent?.call(GomokuEvent.stonePlaced);
    notifyListeners();
    _persist();
    _beginTurn();
  }

  // ================= undo =================

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
    placingCell = -1;
  }

  /// Undo: one stone back during swap placement; a full round (both sides)
  /// in normal play (RULES §7). Disabled once the game is over.
  void undo() {
    if (!canUndo) return;
    _gen++;
    _timer?.cancel();
    _timer = null;
    invalidAt = -1;
    hintAt = -1;
    if (phase == Phase.swapPlacing) {
      if (_undos.isNotEmpty) _restore(_undos.removeLast());
      // stay in swapPlacing; the placer (human) continues
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
    onEvent?.call(GomokuEvent.undo);
    notifyListeners();
    _persist();
    _beginTurn();
  }

  // ================= resign / draw =================

  /// Resigns the active human side; the other side wins (RULES §7, §9).
  void resign() {
    if (over || paused) return;
    if (phase != Phase.awaitingHuman &&
        phase != Phase.botThinking &&
        phase != Phase.swapPlacing &&
        phase != Phase.swapChoice) {
      return;
    }
    _gen++;
    _timer?.cancel();
    _timer = null;
    final seat = mode == GameMode.vsBot ? 0 : turnSeat;
    final winner = seatColor[1 - seat];
    onEvent?.call(GomokuEvent.resign);
    _finishWin(winner, const [], byResign: true);
  }

  /// Two-player draw offer (RULES §10). The bot never offers or accepts.
  void offerDraw() {
    if (over || paused || mode != GameMode.twoPlayer) return;
    if (phase != Phase.awaitingHuman) return;
    drawOfferedBy = turnSeat;
    notifyListeners();
  }

  void acceptDraw() {
    if (drawOfferedBy < 0 || over) return;
    drawOfferedBy = -1;
    _finishDraw();
  }

  void declineDraw() {
    drawOfferedBy = -1;
    notifyListeners();
  }

  // ================= hint =================

  /// Suggests a move for the current human player (Skilled one-ply).
  void hint() {
    if (!canHint) return;
    final pick = GomokuBot.chooseMove(
      board: List<int>.from(eng.board),
      color: turnColor,
      difficulty: BotDifficulty.skilled,
      rng: Random(),
    );
    if (pick < 0) return;
    hintAt = pick;
    onEvent?.call(GomokuEvent.hint);
    notifyListeners();
    final g = _gen;
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (g == _gen && hintAt == pick) {
        hintAt = -1;
        notifyListeners();
      }
    });
  }

  // ================= finishing =================

  void _finishWin(int color, List<int> line, {required bool byResign}) {
    _gen++;
    _timer?.cancel();
    _timer = null;
    _clock?.cancel();
    over = true;
    phase = Phase.over;
    winnerColor = color;
    wonByResign = byResign;
    winLine = line.isEmpty ? null : List<int>.from(line);
    placingCell = -1;
    final humanWon = mode == GameMode.twoPlayer
        ? seatColor.indexOf(color) == 0
        : seatColor[0] == color;
    settings.recordResult(winnerColor: color, humanWon: humanWon);
    settings.clearSavedGame();
    onEvent?.call(humanWon ? GomokuEvent.win : GomokuEvent.lose);
    notifyListeners();
  }

  void _finishDraw() {
    _gen++;
    _timer?.cancel();
    _timer = null;
    _clock?.cancel();
    over = true;
    phase = Phase.over;
    winnerColor = 0;
    wonByResign = false;
    winLine = null;
    placingCell = -1;
    settings.recordResult(winnerColor: 0, humanWon: false);
    settings.clearSavedGame();
    onEvent?.call(GomokuEvent.draw);
    notifyListeners();
  }

  // ================= pause =================

  /// Pause: freeze the phase timer. Resume re-arms the current phase via
  /// the watchdog path, so a pause can never strand a turn.
  void setPaused(bool v) {
    if (paused == v || _disposed) return;
    paused = v;
    if (v) {
      _timer?.cancel();
      _timer = null;
      _clock?.cancel();
    } else {
      _startClock();
      _recover();
    }
    notifyListeners();
  }

  // ================= helpers =================

  void _illegal(int i) {
    invalidAt = i;
    onEvent?.call(GomokuEvent.invalid);
    notifyListeners();
    final g = _gen;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (g == _gen && invalidAt == i) {
        invalidAt = -1;
        notifyListeners();
      }
    });
  }

  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (paused || over || _disposed) return;
      elapsed += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  void _persist() {
    if (over) return;
    settings.saveGame({
      'mode': mode.index,
      'difficulty': difficulty.index,
      'humanColor': humanColor,
      'seatColor': seatColor,
      'swapOpening': swapOpening,
      'swapChoice': phase == Phase.swapChoice,
      'swapBotPlacer': _swapBotPlacer,
      'board': eng.board,
      'blackTurn': eng.blackTurn,
      'last': eng.last,
      'moves': moves,
      'elapsedSec': elapsed.inSeconds,
      'swapPlaced': swapPlaced,
      'swapPlacing': swapPlacing,
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _watchdog?.cancel();
    _clock?.cancel();
    super.dispose();
  }
}
