import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Gomoku: 15x15, alternate stones, first to 5 in a row wins.
/// Threat-based bot: win > block > build.
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
    if (board[i] != 0) return false;
    final color = blackTurn ? 1 : 2;
    board[i] = color;
    last = i;
    winLine = _findWin(i, color);
    blackTurn = !blackTurn;
    return true;
  }

  List<int>? _findWin(int i, int color) {
    final r = i ~/ n, c = i % n;
    const dirs = [[0, 1], [1, 0], [1, 1], [1, -1]];
    for (final d in dirs) {
      final line = [i];
      for (final s in [1, -1]) {
        int nr = r + d[0] * s, nc = c + d[1] * s;
        while (nr >= 0 && nr < n && nc >= 0 && nc < n && board[nr * n + nc] == color) {
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

// ---------- threat-based bot ----------
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
  const dirs = [[0, 1], [1, 0], [1, 1], [1, -1]];
  int total = 0;
  for (final d in dirs) {
    int count = 1, open = 0;
    for (final s in [1, -1]) {
      int nr = r + d[0] * s, nc = c + d[1] * s;
      while (nr >= 0 && nr < n && nc >= 0 && nc < n && bd[nr * n + nc] == color) {
        count++;
        nr += d[0] * s;
        nc += d[1] * s;
      }
      if (nr >= 0 && nr < n && nc >= 0 && nc < n && bd[nr * n + nc] == 0) open++;
    }
    total += _patVal(count, open);
  }
  return total;
}

bool _wouldWin(List<int> bd, int i, int color) {
  bd[i] = color;
  final e = GomokuEngine();
  e.board = bd;
  final w = e._findWin(i, color);
  bd[i] = 0;
  return w != null;
}

/// Returns the bot's chosen cell index.
int gomokuBotMove(List<int> board, int color, Random rand) {
  const n = GomokuEngine.n;
  final foe = color == 1 ? 2 : 1;
  final cands = <int>[];
  for (int i = 0; i < n * n; i++) {
    if (board[i] == 0) cands.add(i);
  }
  // 1. take the win
  for (final i in cands) {
    if (_wouldWin(board, i, color)) return i;
  }
  // 2. block the loss
  for (final i in cands) {
    if (_wouldWin(board, i, foe)) return i;
  }
  // 3. build threats (near existing stones only, for speed + sanity)
  final near = cands.where((i) {
    final r = i ~/ n, c = i % n;
    for (int dr = -2; dr <= 2; dr++) {
      for (int dc = -2; dc <= 2; dc++) {
        final nr = r + dr, nc = c + dc;
        if (nr >= 0 && nr < n && nc >= 0 && nc < n && board[nr * n + nc] != 0) return true;
      }
    }
    return false;
  }).toList();
  final pool = near.isEmpty ? cands : near;
  if (rand.nextDouble() < 0.18) return pool[rand.nextInt(pool.length)];
  int best = pool.first, bestScore = -1;
  for (final i in pool) {
    final s = _cellScore(board, i, color) + (_cellScore(board, i, foe) * 0.9).round() + rand.nextInt(30);
    if (s > bestScore) {
      bestScore = s;
      best = i;
    }
  }
  return best;
}

// ---------- UI ----------
class GomokuScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;

  const GomokuScreen({super.key, required this.players, required this.callbacks});

  @override
  State<GomokuScreen> createState() => _GomokuScreenState();
}

class _GomokuScreenState extends State<GomokuScreen> {
  final _rand = Random();
  final eng = GomokuEngine();
  bool over = false;

  @override
  void initState() {
    super.initState();
    eng.reset();
    widget.callbacks.setActivePlayer(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBot());
  }

  bool get _botTurn => widget.players[eng.blackTurn ? 0 : 1].isBot;

  void _tap(int i) {
    if (over || _botTurn || eng.board[i] != 0) return;
    _place(i);
    Sfx.tap();
  }

  void _place(int i) {
    final moverIdx = eng.blackTurn ? 0 : 1;
    setState(() => eng.place(i));
    if (eng.winLine != null) {
      final w = widget.players[moverIdx];
      w.score += 1;
      widget.callbacks.refreshHud();
      setState(() => over = true);
      Sfx.win();
      widget.callbacks.finish(
          winner: w,
          headline: '${w.name} lands FIVE in a row! ⭕',
          subline: 'Absolute galaxy-brain move! 🧠✨');
      return;
    }
    if (eng.full) {
      setState(() => over = true);
      Sfx.lose();
      widget.callbacks.finish(
          headline: "Board's full — it's a draw! 🤝", subline: 'Nobody blinked. Rematch?');
      return;
    }
    widget.callbacks.setActivePlayer(eng.blackTurn ? 0 : 1);
    _maybeBot();
  }

  void _maybeBot() {
    if (over || !_botTurn) return;
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || over) return;
      final color = eng.blackTurn ? 1 : 2;
      _place(gomokuBotMove(eng.board, color, _rand));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    final cur = widget.players[eng.blackTurn ? 0 : 1];
    final winSet = eng.winLine?.toSet() ?? {};
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          if (!over)
            TurnBanner(
                player: cur,
                action: cur.isBot ? ' is plotting… 🤖' : ', place your stone! ⭕'),
          const SizedBox(height: 10),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: t.radius,
                    boxShadow: [
                      BoxShadow(
                          color: t.primary.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 10))
                    ],
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: GomokuEngine.n),
                    itemCount: GomokuEngine.n * GomokuEngine.n,
                    itemBuilder: (_, i) => _cell(i, t, winSet),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(widget.players[0], '⚫', t),
              const SizedBox(width: 20),
              _legend(widget.players[1], '⚪', t),
            ],
          ),
          const SizedBox(height: 6),
          Text('Five in a row — any direction — takes the crown 👑',
              style: TextStyle(color: t.muted, fontSize: 12)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _legend(Player p, String dot, GameTheme t) {
    return Row(
      children: [
        Text(dot, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 4),
        Text(p.name, style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _cell(int i, GameTheme t, Set<int> winSet) {
    final v = eng.board[i];
    final isWin = winSet.contains(i);
    final isLast = eng.last == i;
    return GestureDetector(
      onTap: () => _tap(i),
      child: CustomPaint(
        painter: _GridPainter(color: t.primary.withValues(alpha: 0.35)),
        child: Center(
          child: v == 0
              ? const SizedBox.expand()
              : TweenAnimationBuilder<double>(
                  key: ValueKey('s$i$v'),
                  tween: Tween(begin: 0.4, end: 1.0),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.elasticOut,
                  builder: (_, sc, child) => Transform.scale(
                    scale: sc,
                    child: Container(
                      margin: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (v == 1 ? widget.players[0] : widget.players[1]).color,
                        border: Border.all(
                            color: isWin ? t.accent : Colors.black26,
                            width: isWin ? 3 : 1),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 2))
                        ],
                      ),
                      child: isLast
                          ? Center(
                              child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle, color: t.background)))
                          : null,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    final cx = size.width / 2, cy = size.height / 2;
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), p);
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), p);
    // star points sparkle ✨
    final dot = Paint()..color = color;
    canvas.drawCircle(Offset(cx, cy), 1.6, dot);
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.color != color;
}
