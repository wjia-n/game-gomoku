import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku/engine/bot.dart';
import 'package:gomoku/engine/gomoku_engine.dart';

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
}
