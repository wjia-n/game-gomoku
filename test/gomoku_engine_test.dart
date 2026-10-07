import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku/game_screen.dart';

const n = GomokuEngine.n;
int sq(int r, int c) => r * n + c;

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

  test('bot takes an immediate win', () {
    final rand = Random(42);
    final bd = List<int>.filled(n * n, 0);
    for (int k = 0; k < 4; k++) {
      bd[sq(7, k)] = 1; // black open four
    }
    bd[sq(0, 0)] = 2;
    expect(gomokuBotMove(bd, 1, rand), sq(7, 4));
  });

  test('bot blocks an immediate loss', () {
    final rand = Random(7);
    final bd = List<int>.filled(n * n, 0);
    for (int k = 0; k < 4; k++) {
      bd[sq(3, k)] = 2; // white open four
    }
    bd[sq(10, 10)] = 1;
    // black must block at (3,4)
    expect(gomokuBotMove(bd, 1, rand), sq(3, 4));
  });

  test('occupied cell rejected', () {
    final e = GomokuEngine()..reset();
    expect(e.place(sq(7, 7)), true);
    expect(e.place(sq(7, 7)), false);
  });
}
