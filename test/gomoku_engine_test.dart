import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku/engine/bot.dart';
import 'package:gomoku/engine/gomoku_engine.dart';
import 'package:gomoku/engine/gomoku_session.dart';
import 'package:gomoku/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const n = GomokuEngine.n;
int sq(int r, int c) => r * n + c;

int skilled(List<int> bd, int color, Random rand) => GomokuBot.chooseMove(
    board: bd, color: color, difficulty: BotDifficulty.skilled, rng: rand);

void main() {
  test('horizontal five wins', () {
    final e = GomokuEngine()..reset();
    // black places 5 in a row on row 7 (alternating with white elsewhere)
    for (int k = 0; k < 5; k++) {
      e.place(sq(7, k)); // black
      if (k < 4) e.place(sq(0, k)); // white far away
    }
    expect(e.winLine, isNotNull);
    expect(e.winLine!.length, 5);
  });

  test('vertical five wins', () {
    final e = GomokuEngine()..reset();
    for (int k = 0; k < 5; k++) {
      e.place(sq(k, 3));
      if (k < 4) e.place(sq(k, 10));
    }
    expect(e.winLine, isNotNull);
  });

  test('diagonal five wins', () {
    final e = GomokuEngine()..reset();
    for (int k = 0; k < 5; k++) {
      e.place(sq(k, k));
      if (k < 4) e.place(sq(k, 14 - k));
    }
    expect(e.winLine, isNotNull);
  });

  test('four in a row does not win', () {
    final e = GomokuEngine()..reset();
    for (int k = 0; k < 4; k++) {
      e.place(sq(5, k));
      e.place(sq(6, k));
    }
    expect(e.winLine, isNull);
  });

  test('overline (six) also wins in freestyle', () {
    final e = GomokuEngine()..reset();
    for (int k = 0; k < 5; k++) {
      e.place(sq(7, k));
      if (k < 4) e.place(sq(0, k));
    }
    expect(e.winLine, isNotNull);
    // blackTurn is now white; force black again and extend
    e.blackTurn = true;
    e.place(sq(7, 5));
    expect(e.winLine, isNotNull);
    expect(e.winLine!.length, 6);
  });

  test('skilled bot takes an immediate win', () {
    final rand = Random(42);
    final bd = List<int>.filled(n * n, 0);
    for (int k = 0; k < 4; k++) {
      bd[sq(7, k)] = 1; // black open four
    }
    bd[sq(0, 0)] = 2;
    expect(skilled(bd, 1, rand), sq(7, 4));
  });

  test('skilled bot blocks an immediate loss', () {
    final rand = Random(7);
    final bd = List<int>.filled(n * n, 0);
    for (int k = 0; k < 4; k++) {
      bd[sq(3, k)] = 2; // white open four
    }
    bd[sq(10, 10)] = 1;
    // black must block at (3,4)
    expect(skilled(bd, 1, rand), sq(3, 4));
  });

  test('occupied cell rejected', () {
    final e = GomokuEngine()..reset();
    expect(e.place(sq(7, 7)), true);
    expect(e.place(sq(7, 7)), false);
  });

  test('beginner bot always plays legal moves', () {
    final rand = Random(123);
    for (var g = 0; g < 30; g++) {
      final bd = List<int>.filled(n * n, 0);
      var color = 1;
      for (var m = 0; m < 40; m++) {
        final pick = GomokuBot.chooseMove(
            board: bd,
            color: color,
            difficulty: BotDifficulty.beginner,
            rng: rand);
        expect(pick >= 0 && pick < n * n, true);
        expect(bd[pick], 0, reason: 'beginner must not play occupied');
        bd[pick] = color;
        color = 3 - color;
      }
    }
  });

  test('master bot plays legally and blocks open fours', () {
    final rand = Random(99);
    final bd = List<int>.filled(n * n, 0);
    for (int k = 0; k < 4; k++) {
      bd[sq(3, k)] = 2; // white open four
    }
    bd[sq(10, 10)] = 1;
    final pick = GomokuBot.chooseMove(
        board: bd,
        color: 1,
        difficulty: BotDifficulty.master,
        rng: rand);
    expect(bd[pick], 0);
    expect(pick, sq(3, 4));
  });

  test('master bot takes its own immediate win', () {
    final rand = Random(5);
    final bd = List<int>.filled(n * n, 0);
    for (int k = 0; k < 4; k++) {
      bd[sq(11, 4 + k)] = 1; // black four
    }
    bd[sq(0, 0)] = 2;
    final pick = GomokuBot.chooseMove(
        board: bd,
        color: 1,
        difficulty: BotDifficulty.master,
        rng: rand);
    // open four at (11,4-7): both ends complete five
    expect([sq(11, 3), sq(11, 8)], contains(pick));
  });

  test('static winOn does not mutate the board', () {
    final bd = List<int>.filled(n * n, 0);
    for (int k = 0; k < 5; k++) {
      bd[sq(2, k)] = 1;
    }
    final before = List<int>.from(bd);
    final line = GomokuEngine.winOn(bd, sq(2, 4), 1);
    expect(line, isNotNull);
    expect(bd, before);
  });

  // ---------------- bot-vs-bot full-game simulations ----------------
  // These prove the rules engine can never strand a game: every simulated
  // game terminates with a legal win or a full-board draw, all moves are
  // on empty intersections, and colors strictly alternate.
  int playBotGame(BotDifficulty dBlack, BotDifficulty dWhite, Random rng) {
    final e = GomokuEngine()..reset();
    var color = 1;
    var moves = 0;
    while (true) {
      final diff = color == 1 ? dBlack : dWhite;
      // The bot computes on a copy, exactly like the session does.
      final pick = GomokuBot.chooseMove(
          board: List<int>.from(e.board),
          color: color,
          difficulty: diff,
          rng: rng);
      expect(pick >= 0 && pick < n * n, true,
          reason: 'bot must return a cell');
      expect(e.board[pick], 0,
          reason: 'bot must play on an empty intersection');
      final ok = e.place(pick);
      expect(ok, true);
      moves++;
      expect(moves <= n * n, true, reason: 'game must terminate');
      if (e.winLine != null) {
        // The winning line must really be the mover's stones.
        for (final i in e.winLine!) {
          expect(e.board[i], color);
        }
        return color;
      }
      if (e.full) return 0; // draw
      color = 3 - color;
    }
  }

  test('bot-vs-bot: beginner finishes legally', () {
    final rng = Random(20261009);
    for (var g = 0; g < 5; g++) {
      final result =
          playBotGame(BotDifficulty.beginner, BotDifficulty.beginner, rng);
      expect([0, 1, 2], contains(result));
    }
  });

  test('bot-vs-bot: skilled finishes legally', () {
    final rng = Random(777);
    for (var g = 0; g < 2; g++) {
      final result =
          playBotGame(BotDifficulty.skilled, BotDifficulty.skilled, rng);
      expect([0, 1, 2], contains(result));
    }
  });

  test('bot-vs-bot: mixed difficulties finish legally', () {
    final rng = Random(31337);
    final r1 =
        playBotGame(BotDifficulty.beginner, BotDifficulty.skilled, rng);
    final r2 =
        playBotGame(BotDifficulty.skilled, BotDifficulty.beginner, rng);
    expect([0, 1, 2], contains(r1));
    expect([0, 1, 2], contains(r2));
  });

  test('master bot: extended legality run', () {
    // A full master-vs-master game is slow (time-boxed search per move),
    // so we prove legality over a long mid-game stretch instead.
    final rng = Random(4242);
    final bd = List<int>.filled(n * n, 0);
    var color = 1;
    for (var m = 0; m < 40; m++) {
      final pick = GomokuBot.chooseMove(
          board: List<int>.from(bd),
          color: color,
          difficulty: BotDifficulty.master,
          rng: rng);
      expect(pick >= 0 && pick < n * n, true);
      expect(bd[pick], 0, reason: 'master must not play occupied');
      bd[pick] = color;
      color = 3 - color;
    }
  });

  // ---------------- session-level proofs ----------------

  test('watchdog recovers a stranded bot turn', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = GomokuSettings();
    final session = GomokuSession(settings: settings);
    // Human plays White: the bot (Black) moves first.
    session.newGame(
      mode: GameMode.vsBot,
      difficulty: BotDifficulty.beginner,
      humanColor: 2,
      swapOpening: false,
    );
    await Future.delayed(const Duration(milliseconds: 150));
    expect(session.phase, Phase.botThinking);
    // Simulate the phase timer dying: the watchdog must re-arm the bot.
    session.killTimerForTest();
    session.watchdogTickForTest();
    await Future.delayed(const Duration(seconds: 4));
    expect(session.moves, greaterThanOrEqualTo(1),
        reason: 'watchdog must recover the stranded bot turn');
    expect(session.over, false);
    session.dispose();
  });

  test('swap opening: bot places 3, human chooses, black moves', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = GomokuSettings();
    final session = GomokuSession(settings: settings);
    session.newGame(
      mode: GameMode.vsBot,
      difficulty: BotDifficulty.beginner,
      humanColor: 1,
      swapOpening: true,
    );
    // The bot (first player) visibly places 2 black + 1 white.
    await Future.delayed(const Duration(seconds: 5));
    expect(session.phase, Phase.swapChoice,
        reason: 'after 3 swap stones the chooser must pick a color');
    final stones = session.eng.board.where((c) => c != 0).length;
    expect(stones, 3);
    expect(session.eng.board.where((c) => c == 1).length, 2);
    expect(session.eng.board.where((c) => c == 2).length, 1);
    // The human (second player) chooses White: bot is Black and moves first.
    session.chooseSwapColor(2);
    expect(session.seatColor, [2, 1]);
    expect(session.eng.blackTurn, true);
    await Future.delayed(const Duration(milliseconds: 150));
    expect(session.phase, Phase.botThinking,
        reason: 'black (bot) to move after the swap');
    session.dispose();
  });

  test('undo takes back a full round in two-player', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = GomokuSettings();
    final session = GomokuSession(settings: settings);
    session.newGame(
      mode: GameMode.twoPlayer,
      difficulty: BotDifficulty.beginner,
      swapOpening: false,
    );
    session.tapPoint(sq(7, 7));
    await Future.delayed(const Duration(milliseconds: 600));
    session.tapPoint(sq(7, 8));
    await Future.delayed(const Duration(milliseconds: 600));
    expect(session.moves, 2);
    expect(session.canUndo, true);
    session.undo();
    expect(session.moves, 0);
    expect(session.eng.board[sq(7, 7)], 0);
    expect(session.eng.board[sq(7, 8)], 0);
    expect(session.phase, Phase.awaitingHuman);
    session.dispose();
  });

  test('resign hands the win to the other side', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = GomokuSettings();
    final session = GomokuSession(settings: settings);
    session.newGame(
      mode: GameMode.vsBot,
      difficulty: BotDifficulty.beginner,
      humanColor: 1,
      swapOpening: false,
    );
    session.tapPoint(sq(7, 7));
    await Future.delayed(const Duration(milliseconds: 600));
    session.resign();
    expect(session.over, true);
    expect(session.wonByResign, true);
    expect(session.winnerColor, 2); // bot (white) wins
    session.dispose();
  });
}
