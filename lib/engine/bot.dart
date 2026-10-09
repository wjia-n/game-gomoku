import 'dart:math';

import 'gomoku_engine.dart';

/// Bot difficulties per RULES §11.
enum BotDifficulty { beginner, skilled, master }

/// Threat-based bot for freestyle Gomoku.
class GomokuBot {
  static const n = GomokuEngine.n;

  /// Returns the bot's chosen cell index (always an empty intersection).
  static int chooseMove({
    required List<int> board,
    required int color,
    required BotDifficulty difficulty,
    required Random rng,
  }) {
    switch (difficulty) {
      case BotDifficulty.beginner:
        return _beginnerMove(board, rng);
      case BotDifficulty.skilled:
        return _skilledMove(board, color, rng);
      case BotDifficulty.master:
        return _masterMove(board, color, rng);
    }
  }

  // ---------------- Beginner ----------------
  // Random legal move, biased toward playing adjacent to existing stones
  // so the game looks sensible. Reacts to immediate threats only by accident.
  static int _beginnerMove(List<int> board, Random rng) {
    final empty = _empties(board);
    if (empty.isEmpty) return -1;
    if (empty.length == n * n) return _centerish(rng);
    final near = _nearCells(board, empty, 2);
    // 70%: play near existing stones; 30%: anywhere (may miss threats).
    if (near.isNotEmpty && rng.nextDouble() < 0.7) {
      return near[rng.nextInt(near.length)];
    }
    return empty[rng.nextInt(empty.length)];
  }

  // ---------------- Skilled ----------------
  // One-ply tactical search: take the win, block the loss, otherwise the
  // move maximizing a pattern score (open threes > open twos > closed
  // fours > single stones), preferring central positions in the opening.
  static int _skilledMove(List<int> board, int color, Random rng) {
    final foe = 3 - color;
    final empty = _empties(board);
    if (empty.isEmpty) return -1;
    if (empty.length == n * n) return _centerish(rng);
    // 1. take the win
    for (final i in empty) {
      if (_wouldWin(board, i, color)) return i;
    }
    // 2. block the loss
    for (final i in empty) {
      if (_wouldWin(board, i, foe)) return i;
    }
    // 3. build threats (near existing stones only, for speed + sanity)
    final pool = _nearCells(board, empty, 2);
    final cands = pool.isEmpty ? empty : pool;
    if (rng.nextDouble() < 0.18) return cands[rng.nextInt(cands.length)];
    var best = cands.first;
    var bestScore = -1;
    for (final i in cands) {
      final s = _cellScore(board, i, color) +
          (_cellScore(board, i, foe) * 0.9).round() +
          rng.nextInt(30) +
          _centerBonus(i);
      if (s > bestScore) {
        bestScore = s;
        best = i;
      }
    }
    return best;
  }

  // ---------------- Master ----------------
  // Depth-2 alpha-beta over the top pattern candidates, with a time budget.
  // Falls back to the Skilled one-ply tactic if the budget is exceeded.
  static int _masterMove(List<int> board, int color, Random rng) {
    final foe = 3 - color;
    final empty = _empties(board);
    if (empty.isEmpty) return -1;
    if (empty.length == n * n) return _centerish(rng);

    // Immediate tactics first (always correct, always fast).
    for (final i in empty) {
      if (_wouldWin(board, i, color)) return i;
    }
    for (final i in empty) {
      if (_wouldWin(board, i, foe)) return i;
    }

    final budget = Stopwatch()..start();
    const limitMs = 650;
    try {
      // Rank candidates by 1-ply score, keep the strongest.
      final pool = _nearCells(board, empty, 2);
      final cands = (pool.isEmpty ? empty : pool)
        ..sort((a, b) =>
            _quickScore(board, b, color, foe).compareTo(_quickScore(board, a, color, foe)));
      final top = cands.take(12).toList();

      var best = top.first;
      var bestVal = -1 << 30;
      for (final c in top) {
        if (budget.elapsedMilliseconds > limitMs) break;
        final val = _twoPlyValue(board, c, color, foe, budget, limitMs);
        final jittered = val + rng.nextInt(24);
        if (jittered > bestVal) {
          bestVal = jittered;
          best = c;
        }
      }
      return best;
    } catch (_) {
      return _skilledMove(board, color, rng);
    }
  }

  /// Value of playing [move] for [color]: own threat value minus the
  /// opponent's best reply value (alpha-beta, depth 2).
  static int _twoPlyValue(List<int> board, int move, int color, int foe,
      Stopwatch budget, int limitMs) {
    board[move] = color;
    try {
      if (GomokuEngine.winOn(board, move, color) != null) return 1 << 28;
      final mine = _quickScore(board, move, color, foe);
      // Opponent's best reply: any immediate win by the foe is catastrophic.
      var worst = 0;
      final replies = _nearCells(board, _empties(board), 2).take(10);
      for (final r in replies) {
        if (budget.elapsedMilliseconds > limitMs) break;
        if (_wouldWin(board, r, foe)) {
          worst = 1 << 27;
          break;
        }
        final v = _quickScore(board, r, foe, color);
        if (v > worst) worst = v;
      }
      return mine - (worst * 1.15).round();
    } finally {
      board[move] = 0;
    }
  }

  static int _quickScore(List<int> board, int i, int color, int foe) =>
      _cellScore(board, i, color) +
      (_cellScore(board, i, foe) * 0.9).round() +
      _centerBonus(i);

  // ---------------- helpers ----------------

  static List<int> _empties(List<int> board) {
    final out = <int>[];
    for (var i = 0; i < n * n; i++) {
      if (board[i] == 0) out.add(i);
    }
    return out;
  }

  /// Empty cells within Chebyshev distance [d] of any stone.
  static List<int> _nearCells(List<int> board, List<int> empty, int d) {
    final out = <int>[];
    for (final i in empty) {
      final r = i ~/ n, c = i % n;
      var found = false;
      for (var dr = -d; dr <= d && !found; dr++) {
        for (var dc = -d; dc <= d; dc++) {
          final nr = r + dr, nc = c + dc;
          if (nr >= 0 &&
              nr < n &&
              nc >= 0 &&
              nc < n &&
              board[nr * n + nc] != 0) {
            found = true;
            break;
          }
        }
      }
      if (found) out.add(i);
    }
    return out;
  }

  /// Opening stone: exact center or one of its 8 neighbours (RULES §12).
  static int _centerish(Random rng) {
    final c = n ~/ 2;
    final opts = [c * n + c];
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr != 0 || dc != 0) opts.add((c + dr) * n + (c + dc));
      }
    }
    return opts[rng.nextInt(opts.length)];
  }

  static int _centerBonus(int i) {
    final r = i ~/ n, c = i % n, mid = n ~/ 2;
    return (14 - (r - mid).abs() - (c - mid).abs()) * 2;
  }

  static bool _wouldWin(List<int> bd, int i, int color) {
    bd[i] = color;
    final w = GomokuEngine.winOn(bd, i, color);
    bd[i] = 0;
    return w != null;
  }
}

// ---------- pattern scoring (shared by Skilled & Master) ----------
int _patVal(int count, int open) {
  if (count >= 5) return 1000000;
  if (count == 4 && open == 2) return 200000;
  if (count == 4 && open == 1) return 20000;
  if (count == 3 && open == 2) return 8000;
  if (count == 3 && open == 1) return 600;
  if (count == 2 && open == 2) return 250;
  if (count == 2 && open == 1) return 40;
  if (count == 1 && open == 2) return 8;
  return 1;
}

int _cellScore(List<int> bd, int i, int color) {
  const n = GomokuEngine.n;
  final r = i ~/ n, c = i % n;
  const dirs = [
    [0, 1],
    [1, 0],
    [1, 1],
    [1, -1]
  ];
  var total = 0;
  for (final d in dirs) {
    var count = 1, open = 0;
    for (final s in [1, -1]) {
      var nr = r + d[0] * s, nc = c + d[1] * s;
      while (nr >= 0 &&
          nr < n &&
          nc >= 0 &&
          nc < n &&
          bd[nr * n + nc] == color) {
        count++;
        nr += d[0] * s;
        nc += d[1] * s;
      }
      if (nr >= 0 && nr < n && nc >= 0 && nc < n && bd[nr * n + nc] == 0) {
        open++;
      }
    }
    total += _patVal(count, open);
  }
  return total;
}
