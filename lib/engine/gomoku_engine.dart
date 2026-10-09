/// Gomoku engine: freestyle rules (RULES.md).
/// 15x15 intersections, alternate stones, first to 5+ in a row wins.
/// No forbidden moves, no captures. Deterministic, UI-free.
class GomokuEngine {
  static const n = 15;
  List<int> board = List.filled(n * n, 0); // 0 empty, 1 black, 2 white
  bool blackTurn = true;
  int last = -1;
  List<int>? winLine;

  void reset() {
    board = List.filled(n * n, 0);
    blackTurn = true;
    last = -1;
    winLine = null;
  }

  /// Places a stone; returns false if occupied. Sets winLine on a win.
  bool place(int i) {
    if (i < 0 || i >= n * n || board[i] != 0) return false;
    final color = blackTurn ? 1 : 2;
    board[i] = color;
    last = i;
    winLine = winOn(board, i, color);
    blackTurn = !blackTurn;
    return true;
  }

  /// Win check for a hypothetical board (used by the bot without mutating
  /// engine state). Returns the winning line or null.
  static List<int>? winOn(List<int> bd, int i, int color) {
    final r = i ~/ n, c = i % n;
    const dirs = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1]
    ];
    for (final d in dirs) {
      final line = [i];
      for (final s in [1, -1]) {
        int nr = r + d[0] * s, nc = c + d[1] * s;
        while (nr >= 0 &&
            nr < n &&
            nc >= 0 &&
            nc < n &&
            bd[nr * n + nc] == color) {
          line.add(nr * n + nc);
          nr += d[0] * s;
          nc += d[1] * s;
        }
      }
      if (line.length >= 5) return line;
    }
    return null;
  }

  bool get full => !board.contains(0);
}
