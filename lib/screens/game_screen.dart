import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/gomoku_engine.dart';
import '../engine/gomoku_session.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/scholar.dart';
import '../theme/scholar_themes.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

/// The scholar's match screen: lacquer top tray, kaya board, bottom player
/// tray, wooden action deck. Every side has its OWN tray; the active side
/// highlights and the bot's tray narrates "thinking…" — no turn is ever
/// silently auto-played.
class GameScreen extends StatefulWidget {
  final ScholarAudio audio;
  final GomokuSettings settings;
  final StoreService store;
  final GameMode mode;
  final Map<String, dynamic>? savedGame;

  const GameScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.store,
    required this.mode,
    this.savedGame,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final GomokuSession session;
  late final AnimationController _placeAnim; // stone placement animation
  late final AnimationController _thinkAnim; // thinking dots
  bool _reviewing = false;

  ScholarThemeDef get _t => ScholarThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    session = GomokuSession(settings: widget.settings);
    session.onEvent = _onEvent;
    _placeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _thinkAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    session.addListener(_onSession);
    WidgetsBinding.instance.addObserver(this);
    if (widget.savedGame != null) {
      session.restore(widget.savedGame!);
    } else {
      session.newGame(
        mode: widget.mode,
        difficulty: widget.settings.difficulty,
        humanColor: widget.settings.humanColor,
        swapOpening: widget.settings.swapOpening,
      );
    }
    if (session.placingId > 0) _placeAnim.forward(from: 0);
  }

  int _lastPlacingId = 0;

  void _onSession() {
    // (Re)start the placement animation whenever a new stone is placed.
    if (session.placingId != _lastPlacingId) {
      _lastPlacingId = session.placingId;
      _placeAnim.forward(from: 0);
    }
    if (mounted) setState(() {});
  }

  void _onEvent(GomokuEvent e) {
    final a = widget.audio;
    switch (e) {
      case GomokuEvent.stonePlaced:
      case GomokuEvent.swapStonePlaced:
        a.playStone(session.placingColor == 1);
        break;
      case GomokuEvent.invalid:
        a.invalid();
        break;
      case GomokuEvent.undo:
        a.undo();
        break;
      case GomokuEvent.hint:
        a.brush();
        break;
      case GomokuEvent.swapReady:
        a.brush();
        break;
      case GomokuEvent.win:
        a.win();
        break;
      case GomokuEvent.lose:
        a.lose();
        break;
      case GomokuEvent.draw:
        a.draw();
        break;
      case GomokuEvent.resign:
        a.resign();
        break;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Freeze the engine on interruption; the pause overlay lets the player
    // resume deliberately. Music is paused/resumed app-wide by main.dart.
    if (state == AppLifecycleState.paused) {
      session.setPaused(true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    session.removeListener(_onSession);
    session.dispose();
    _placeAnim.dispose();
    _thinkAnim.dispose();
    super.dispose();
  }

  void _quitToMenu() {
    widget.audio.click();
    session.setPaused(true);
    Navigator.of(context).pop();
  }

  void _openSettings() {
    widget.audio.click();
    session.setPaused(true);
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          audio: widget.audio,
          settings: widget.settings,
          store: widget.store,
        ),
      ),
    )
        .then((_) {
      if (mounted && !session.over) {
        // Stay paused: the player resumes deliberately.
        setState(() {});
      }
    });
  }

  void _openPro() {
    widget.audio.click();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProScreen(
          audio: widget.audio,
          settings: widget.settings,
          store: widget.store,
        ),
      ),
    );
  }

  Future<void> _confirmResign() async {
    widget.audio.click();
    if (session.over || session.paused) return;
    final doIt = !widget.settings.confirmResign ||
        await showDialog<bool>(
          context: context,
          builder: (_) => _ConfirmDialog(
            theme: _t,
            title: 'Resign?',
            body: 'The other side wins the game.',
            confirm: 'Resign',
          ),
        ) ==
            true;
    if (doIt) session.resign();
  }

  void _offerDraw() {
    widget.audio.click();
    session.offerDraw();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    return PaperBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.inkText),
            onPressed: _quitToMenu,
          ),
          title: Text(
            session.mode == GameMode.vsBot ? 'Vs Bot' : 'Two Players',
            style: Scholar.display(20, theme: t),
          ),
          centerTitle: true,
          actions: [
            if (!s.isPro)
              IconButton(
                icon: Icon(Icons.workspace_premium, color: t.accent),
                tooltip: 'Gomoku PRO',
                onPressed: _openPro,
              ),
            IconButton(
              icon: Icon(Icons.settings, color: t.inkText),
              onPressed: _openSettings,
            ),
          ],
        ),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: session,
            builder: (_, _) => Stack(
              children: [
                Column(
                  children: [
                    // Top tray: seat 1 (bot / player two).
                    _PlayerTray(
                      theme: t,
                      session: session,
                      seat: 1,
                      thinkAnim: _thinkAnim,
                    ),
                    const SizedBox(height: 6),
                    // Narration line.
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        session.narration,
                        style: Scholar.label(13, theme: t),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // The board.
                    Expanded(
                      child: Center(
                        child: _BoardView(
                          theme: t,
                          session: session,
                          settings: s,
                          placeAnim: _placeAnim,
                          onTapPoint: (i) => session.tapPoint(i),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Bottom tray: seat 0 (human / player one).
                    _PlayerTray(
                      theme: t,
                      session: session,
                      seat: 0,
                      thinkAnim: _thinkAnim,
                    ),
                    const SizedBox(height: 8),
                    _ActionDeck(
                      theme: t,
                      session: session,
                      settings: s,
                      audio: widget.audio,
                      onUndo: () => session.undo(),
                      onHint: () => session.hint(),
                      onResign: _confirmResign,
                      onDraw: _offerDraw,
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
                if (session.paused && !session.over) _PauseOverlay(
                  theme: t,
                  onResume: () {
                    widget.audio.click();
                    session.setPaused(false);
                  },
                  onQuit: _quitToMenu,
                ),
                if (session.over && !_reviewing)
                  _GameOverOverlay(
                    theme: t,
                    session: session,
                    settings: s,
                    audio: widget.audio,
                    onRematch: () {
                      widget.audio.gameStart();
                      _reviewing = false;
                      session.newGame(
                        mode: session.mode,
                        difficulty: widget.settings.difficulty,
                        humanColor: widget.settings.humanColor,
                        swapOpening: widget.settings.swapOpening,
                      );
                    },
                    onReview: () {
                      widget.audio.click();
                      setState(() => _reviewing = true);
                    },
                    onMenu: _quitToMenu,
                  ),
                if (session.over && _reviewing)
                  Positioned(
                    bottom: 18,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: WoodButton(
                        label: 'Done Reviewing',
                        width: 240,
                        theme: t,
                        onTap: () {
                          widget.audio.click();
                          setState(() => _reviewing = false);
                        },
                      ),
                    ),
                  ),
                if (session.phase == Phase.swapChoice)
                  _SwapChoiceDialog(
                    theme: t,
                    session: session,
                    audio: widget.audio,
                  ),
                if (session.drawOfferedBy >= 0)
                  _DrawOfferDialog(
                    theme: t,
                    session: session,
                    audio: widget.audio,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// One side's tray: stone bowl, renameable name, move count, and the active
/// highlight. The bot's tray narrates "thinking…" with animated dots while
/// its turn resolves — nothing is ever silently auto-played.
class _PlayerTray extends StatelessWidget {
  final ScholarThemeDef theme;
  final GomokuSession session;
  final int seat;
  final AnimationController thinkAnim;

  const _PlayerTray({
    required this.theme,
    required this.session,
    required this.seat,
    required this.thinkAnim,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final color = session.seatColor[seat];
    final isActive = !session.over &&
        !session.paused &&
        ((session.phase == Phase.awaitingHuman &&
                session.turnSeat == seat) ||
            (session.phase == Phase.botThinking &&
                session.turnSeat == seat) ||
            (session.phase == Phase.placing &&
                session.placingColor == color) ||
            (session.phase == Phase.swapPlacing &&
                ((session.mode == GameMode.vsBot && seat == 1) ||
                    (session.mode == GameMode.twoPlayer &&
                        seat == 0))));
    final thinking =
        session.phase == Phase.botThinking && session.turnSeat == seat;
    final stones = session.eng.board.where((c) => c == color).length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isActive
              ? [t.woodMid, t.woodDeep]
              : [t.paperCard, t.paperCard],
        ),
        border: Border.all(
          color: isActive ? t.accent : t.woodMid.withValues(alpha: 0.4),
          width: isActive ? 2.5 : 1.5,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: t.accent.withValues(alpha: 0.35),
                  blurRadius: 12,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  offset: const Offset(0, 3),
                  blurRadius: 6,
                ),
              ],
      ),
      child: Row(
        children: [
          // Stone bowl.
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.35),
                colors: color == 1
                    ? [const Color(0xFF5A564E), const Color(0xFF23211E)]
                    : [Colors.white, const Color(0xFFF2EAD6)],
              ),
              border: Border.all(
                  color: Colors.black.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  offset: const Offset(0, 3),
                  blurRadius: 5,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  session.seatName(seat),
                  style: Scholar.label(15,
                      theme: t,
                      color: isActive
                          ? const Color(0xFFFFF6E6)
                          : t.inkText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                thinking
                    ? AnimatedBuilder(
                        animation: thinkAnim,
                        builder: (_, _) {
                          final dots =
                              '.' * (1 + (thinkAnim.value * 3).floor());
                          return Text(
                            'thinking$dots',
                            style: Scholar.body(12,
                                theme: t,
                                color: isActive
                                    ? const Color(0xFFFFF6E6)
                                        .withValues(alpha: 0.85)
                                    : t.inkSoft),
                          );
                        },
                      )
                    : Text(
                        isActive
                            ? 'to move · $stones stones'
                            : '$stones stones',
                        style: Scholar.body(12,
                            theme: t,
                            color: isActive
                                ? const Color(0xFFFFF6E6)
                                    .withValues(alpha: 0.85)
                                : t.inkSoft),
                      ),
              ],
            ),
          ),
          if (session.mode == GameMode.vsBot && seat == 1)
            Text(session.botTitle,
                style: Scholar.label(11, theme: t)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// The 15×15 kaya board: wood slab, ink grid, pseudo-3D stones, last-move
/// seal marker, hint glow, win-line ring, and the visible placement pop.
class _BoardView extends StatelessWidget {
  final ScholarThemeDef theme;
  final GomokuSession session;
  final GomokuSettings settings;
  final AnimationController placeAnim;
  final void Function(int i) onTapPoint;

  const _BoardView({
    required this.theme,
    required this.session,
    required this.settings,
    required this.placeAnim,
    required this.onTapPoint,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final size =
            math.min(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTapDown: (d) {
            final box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(d.globalPosition);
            final cell = size / (GomokuEngine.n + 1);
            final c = ((local.dx - cell / 2) / cell).round();
            final r = ((local.dy - cell / 2) / cell).round();
            if (r < 0 ||
                r >= GomokuEngine.n ||
                c < 0 ||
                c >= GomokuEngine.n) {
              return;
            }
            // Only accept taps near an intersection (not mid-cell).
            final px = cell / 2 + c * cell;
            final py = cell / 2 + r * cell;
            if ((local.dx - px).abs() > cell * 0.45 ||
                (local.dy - py).abs() > cell * 0.45) {
              return;
            }
            onTapPoint(r * GomokuEngine.n + c);
          },
          child: AnimatedBuilder(
            animation:
                Listenable.merge([session, placeAnim]),
            builder: (_, _) => CustomPaint(
              size: Size(size, size),
              painter: _BoardPainter(
                t: theme,
                session: session,
                settings: settings,
                placeT: placeAnim.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BoardPainter extends CustomPainter {
  final ScholarThemeDef t;
  final GomokuSession session;
  final GomokuSettings settings;
  final double placeT; // 0..1 placement pop progress

  _BoardPainter({
    required this.t,
    required this.session,
    required this.settings,
    required this.placeT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const n = GomokuEngine.n;
    final cell = size.width / (n + 1);
    final boardPad = cell * 0.5;

    // Wood slab with bevel.
    final slab = RRect.fromLTRBR(0, 0, size.width, size.height,
        const Radius.circular(10));
    canvas.drawRRect(
        slab,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [t.woodDeep, t.woodMid],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    final face = RRect.fromLTRBR(boardPad * 0.35, boardPad * 0.35,
        size.width - boardPad * 0.35, size.height - boardPad * 0.35,
        const Radius.circular(6));
    canvas.drawRRect(
        face,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [t.woodLight, t.woodMid.withValues(alpha: 0.75)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    // Soft inner shadow.
    canvas.drawRRect(
        face,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.black.withValues(alpha: 0.22));

    // Grid lines.
    final gridPaint = Paint()
      ..color = t.gridLine.withValues(alpha: 0.85)
      ..strokeWidth = math.max(1, cell * 0.028);
    for (int k = 0; k < n; k++) {
      final p = boardPad + k * cell;
      canvas.drawLine(Offset(boardPad, p),
          Offset(size.width - boardPad, p), gridPaint);
      canvas.drawLine(Offset(p, boardPad),
          Offset(p, size.height - boardPad), gridPaint);
    }
    // Star points (hoshi).
    const hoshi = [3, 7, 11];
    final hoshiPaint = Paint()..color = t.gridLine;
    for (final r in hoshi) {
      for (final c in hoshi) {
        canvas.drawCircle(
            Offset(boardPad + c * cell, boardPad + r * cell),
            cell * 0.09,
            hoshiPaint);
      }
    }

    Offset pt(int i) => Offset(
        boardPad + (i % n) * cell, boardPad + (i ~/ n) * cell);

    final styleIdx = settings.stoneStyle
        .clamp(0, StoneStyles.pairs.length - 1);
    final pair = StoneStyles.pairs[styleIdx];

    // Stones.
    for (int i = 0; i < n * n; i++) {
      final v = session.eng.board[i];
      if (v == 0) continue;
      final isPlacing = i == session.placingCell;
      final scale = isPlacing
          ? (0.4 + 0.6 * Curves.easeOutBack.transform(placeT.clamp(0.0, 1.0)))
          : 1.0;
      _drawStone(canvas, pt(i), cell * 0.46 * scale, v, pair);
    }

    // Last-move marker (per chosen board accent).
    if (settings.lastMoveMarker && session.eng.last >= 0) {
      final v = session.eng.board[session.eng.last];
      if (v != 0) {
        _drawMarker(canvas, pt(session.eng.last), cell * 0.46,
            settings.markerStyle, t);
      }
    }

    // Hint glow.
    if (session.hintAt >= 0) {
      final p = pt(session.hintAt);
      canvas.drawCircle(
          p,
          cell * 0.46,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = t.accent.withValues(alpha: 0.85));
      canvas.drawCircle(
          p,
          cell * 0.34,
          Paint()..color = t.accent.withValues(alpha: 0.25));
    }

    // Invalid-tap flash.
    if (session.invalidAt >= 0) {
      final p = pt(session.invalidAt);
      canvas.drawCircle(
          p,
          cell * 0.46,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFFC23B22).withValues(alpha: 0.9));
    }

    // Winning five ringed in cinnabar (DESIGN.md).
    final wl = session.winLine;
    if (wl != null && wl.isNotEmpty) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.5, cell * 0.07)
        ..color = t.accent;
      for (final i in wl) {
        canvas.drawCircle(pt(i), cell * 0.52, ring);
      }
      if (wl.length >= 2) {
        canvas.drawLine(pt(wl.first), pt(wl.last),
            ring..strokeWidth = math.max(2, cell * 0.05));
      }
    }

    // Coordinates.
    if (settings.showCoordinates) {
      final tp = TextPainter(textDirection: TextDirection.ltr);
      for (int k = 0; k < n; k++) {
        final label = String.fromCharCode(65 + k); // A..O
        tp.text = TextSpan(
            text: label,
            style: TextStyle(
                fontSize: cell * 0.32,
                color: t.gridLine.withValues(alpha: 0.8)));
        tp.layout();
        tp.paint(
            canvas,
            Offset(boardPad + k * cell - tp.width / 2,
                size.height - boardPad * 0.42 - tp.height / 2));
        final num = TextSpan(
            text: '${k + 1}',
            style: TextStyle(
                fontSize: cell * 0.30,
                color: t.gridLine.withValues(alpha: 0.8)));
        tp.text = num;
        tp.layout();
        tp.paint(
            canvas,
            Offset(boardPad * 0.42 - tp.width / 2,
                boardPad + k * cell - tp.height / 2));
      }
    }
  }

  void _drawStone(Canvas canvas, Offset p, double r, int color,
      List<List<Color>> pair) {
    // Contact shadow.
    canvas.drawOval(
        Rect.fromCenter(
            center: p + Offset(r * 0.12, r * 0.22),
            width: r * 2.05,
            height: r * 1.7),
        Paint()..color = Colors.black.withValues(alpha: 0.32));
    // Body: pseudo-3D biconvex stone.
    final base = pair[color == 1 ? 0 : 1];
    canvas.drawCircle(
        p,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.38, -0.42),
            radius: 1.05,
            colors: [base[1], base[0]],
            stops: const [0.0, 1.0],
          ).createShader(Rect.fromCircle(center: p, radius: r)));
    // Rim.
    canvas.drawCircle(
        p,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, r * 0.06)
          ..color = Colors.black.withValues(alpha: 0.35));
    // Specular highlight.
    canvas.drawOval(
        Rect.fromCenter(
            center: p + Offset(-r * 0.32, -r * 0.38),
            width: r * 0.72,
            height: r * 0.44),
        Paint()..color = Colors.white.withValues(alpha: color == 1 ? 0.28 : 0.55));
  }

  void _drawMarker(
      Canvas canvas, Offset p, double r, int style, ScholarThemeDef t) {
    switch (style) {
      case 0: // Seal Dot: small vermilion dot.
        canvas.drawCircle(
            p + Offset(r * 0.42, -r * 0.42), r * 0.22, Paint()..color = t.accent);
        break;
      case 1: // Brush Ring.
        canvas.drawCircle(
            p,
            r * 0.62,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2, r * 0.12)
              ..color = t.accent.withValues(alpha: 0.9));
        break;
      case 2: // Corner Ticks.
        final tick = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2, r * 0.12)
          ..strokeCap = StrokeCap.round
          ..color = t.accent.withValues(alpha: 0.95);
        final o = r * 0.78, l = r * 0.34;
        for (final sx in [-1, 1]) {
          for (final sy in [-1, 1]) {
            final cx = p.dx + sx * o, cy = p.dy + sy * o;
            canvas.drawLine(Offset(cx - sx * l, cy), Offset(cx, cy), tick);
            canvas.drawLine(Offset(cx, cy - sy * l), Offset(cx, cy), tick);
          }
        }
        break;
      case 3: // Gold Ring.
        canvas.drawCircle(
            p,
            r * 0.7,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.5, r * 0.08)
              ..color = const Color(0xFFB8860B));
        break;
      case 4: // Ink Cross.
        final cross = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2, r * 0.14)
          ..strokeCap = StrokeCap.round
          ..color = t.inkText.withValues(alpha: 0.85);
        final l = r * 0.4;
        canvas.drawLine(p + Offset(-l, -l), p + Offset(l, l), cross);
        canvas.drawLine(p + Offset(-l, l), p + Offset(l, -l), cross);
        break;
      case 5: // Jade Dot.
        canvas.drawCircle(p + Offset(r * 0.42, -r * 0.42), r * 0.22,
            Paint()..color = const Color(0xFF4E8A6E));
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}

// ---------------------------------------------------------------------------
/// Wooden-plaque action deck: Undo, Hint, Resign, Draw (2P), Menu handled
/// by the app bar.
class _ActionDeck extends StatelessWidget {
  final ScholarThemeDef theme;
  final GomokuSession session;
  final GomokuSettings settings;
  final ScholarAudio audio;
  final VoidCallback onUndo;
  final VoidCallback onHint;
  final VoidCallback onResign;
  final VoidCallback onDraw;

  const _ActionDeck({
    required this.theme,
    required this.session,
    required this.settings,
    required this.audio,
    required this.onUndo,
    required this.onHint,
    required this.onResign,
    required this.onDraw,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final actions = <_DeckAction>[
      _DeckAction(
          icon: Icons.undo,
          label: 'Undo',
          enabled: session.canUndo,
          onTap: () {
            audio.click();
            onUndo();
          }),
      _DeckAction(
          icon: Icons.lightbulb_outline,
          label: 'Hint',
          enabled: session.canHint,
          onTap: () {
            onHint();
          }),
      _DeckAction(
          icon: Icons.flag_outlined,
          label: 'Resign',
          enabled: !session.over && !session.paused,
          onTap: onResign),
      if (session.mode == GameMode.twoPlayer)
        _DeckAction(
            icon: Icons.handshake_outlined,
            label: 'Draw',
            enabled: !session.over &&
                !session.paused &&
                session.phase == Phase.awaitingHuman &&
                session.drawOfferedBy < 0,
            onTap: onDraw),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [for (final a in actions) _deckButton(t, a)],
      ),
    );
  }

  Widget _deckButton(ScholarThemeDef t, _DeckAction a) {
    return Opacity(
      opacity: a.enabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: a.enabled ? a.onTap : null,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [t.woodMid, t.woodDeep],
            ),
            border: Border.all(
                color: t.woodLight.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                offset: const Offset(0, 3),
                blurRadius: 6,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(a.icon,
                  color: const Color(0xFFFFF6E6), size: 22),
              const SizedBox(height: 3),
              Text(a.label,
                  style: Scholar.label(10,
                      theme: t,
                      color: const Color(0xFFFFF6E6))),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckAction {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  _DeckAction(
      {required this.icon,
      required this.label,
      required this.enabled,
      required this.onTap});
}

// ---------------------------------------------------------------------------
class _PauseOverlay extends StatelessWidget {
  final ScholarThemeDef theme;
  final VoidCallback onResume;
  final VoidCallback onQuit;
  const _PauseOverlay(
      {required this.theme, required this.onResume, required this.onQuit});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: PaperCard(
          theme: t,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paused', style: Scholar.display(28, theme: t)),
              const SizedBox(height: 6),
              Text('The board waits patiently.',
                  style:
                      Scholar.body(14, theme: t, color: t.inkSoft)),
              const SizedBox(height: 18),
              WoodButton(
                  label: 'Resume',
                  width: 220,
                  theme: t,
                  primary: true,
                  onTap: onResume),
              const SizedBox(height: 10),
              WoodButton(
                  label: 'Quit to Menu',
                  width: 220,
                  theme: t,
                  onTap: onQuit),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Victory / draw card over the dimmed board (DESIGN.md): seal stamp,
/// result line, wooden stat plaques, Rematch + Main Menu, review link.
class _GameOverOverlay extends StatelessWidget {
  final ScholarThemeDef theme;
  final GomokuSession session;
  final GomokuSettings settings;
  final ScholarAudio audio;
  final VoidCallback onRematch;
  final VoidCallback onReview;
  final VoidCallback onMenu;

  const _GameOverOverlay({
    required this.theme,
    required this.session,
    required this.settings,
    required this.audio,
    required this.onRematch,
    required this.onReview,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final draw = session.winnerColor == 0;
    final winnerSeat = draw ? -1 : session.seatColor.indexOf(session.winnerColor);
    final humanWon = session.mode == GameMode.twoPlayer
        ? winnerSeat == 0
        : session.seatColor[0] == session.winnerColor;
    final title = draw
        ? 'DRAW'
        : session.wonByResign
            ? 'VICTORY'
            : (humanWon ? 'VICTORY' : 'DEFEAT');
    final subtitle = draw
        ? 'The board is full — no five in a row.'
        : session.wonByResign
            ? '${session.seatName(winnerSeat)} wins by resignation.'
            : '${session.seatName(winnerSeat)} completes five in a row!';
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: PaperCard(
            theme: t,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SealStamp(size: 44, theme: t),
                const SizedBox(height: 10),
                Text(title, style: Scholar.display(34, theme: t)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style:
                        Scholar.body(14, theme: t, color: t.inkSoft),
                    textAlign: TextAlign.center),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StatPlaque(
                        label: 'MOVES',
                        value: '${session.moves}',
                        theme: t),
                    const SizedBox(width: 10),
                    StatPlaque(
                        label: 'TIME',
                        value: session.clockLabel,
                        theme: t),
                    const SizedBox(width: 10),
                    StatPlaque(
                        label: 'WINS',
                        value: '${settings.wins}',
                        theme: t),
                  ],
                ),
                const SizedBox(height: 18),
                WoodButton(
                    label: 'Rematch',
                    width: 240,
                    theme: t,
                    primary: true,
                    onTap: onRematch),
                const SizedBox(height: 10),
                WoodButton(
                    label: 'Main Menu',
                    width: 240,
                    theme: t,
                    onTap: onMenu),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onReview,
                  child: Text('Review board',
                      style: Scholar.label(13, theme: t)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Swap-opening color choice (RULES §7): the chooser picks Black or White
/// after the three opening stones are placed.
class _SwapChoiceDialog extends StatelessWidget {
  final ScholarThemeDef theme;
  final GomokuSession session;
  final ScholarAudio audio;
  const _SwapChoiceDialog(
      {required this.theme, required this.session, required this.audio});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: PaperCard(
          theme: t,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('The Swap', style: Scholar.display(26, theme: t)),
              const SizedBox(height: 6),
              Text(
                'Three stones rest on the board.\nChoose the color you will play — Black moves first.',
                style: Scholar.body(14,
                    theme: t, color: t.inkSoft),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _swapStone(t, 1, 'Black'),
                  const SizedBox(width: 24),
                  _swapStone(t, 2, 'White'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _swapStone(ScholarThemeDef t, int color, String label) {
    return GestureDetector(
      onTap: () {
        audio.click();
        session.chooseSwapColor(color);
      },
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.35),
                colors: color == 1
                    ? [const Color(0xFF5A564E), const Color(0xFF23211E)]
                    : [Colors.white, const Color(0xFFF2EAD6)],
              ),
              border: Border.all(color: t.accent, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  offset: const Offset(0, 5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: Scholar.label(14, theme: t)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Two-player draw offer (RULES §10).
class _DrawOfferDialog extends StatelessWidget {
  final ScholarThemeDef theme;
  final GomokuSession session;
  final ScholarAudio audio;
  const _DrawOfferDialog(
      {required this.theme, required this.session, required this.audio});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: PaperCard(
          theme: t,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Draw Offered',
                  style: Scholar.display(24, theme: t)),
              const SizedBox(height: 6),
              Text(
                '${session.seatName(session.drawOfferedBy)} offers a draw.\nDoes the other side accept?',
                style: Scholar.body(14,
                    theme: t, color: t.inkSoft),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WoodButton(
                    label: 'Accept',
                    width: 130,
                    theme: t,
                    primary: true,
                    onTap: () {
                      audio.click();
                      session.acceptDraw();
                    },
                  ),
                  const SizedBox(width: 12),
                  WoodButton(
                    label: 'Decline',
                    width: 130,
                    theme: t,
                    onTap: () {
                      audio.click();
                      session.declineDraw();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _ConfirmDialog extends StatelessWidget {
  final ScholarThemeDef theme;
  final String title;
  final String body;
  final String confirm;
  const _ConfirmDialog(
      {required this.theme,
      required this.title,
      required this.body,
      required this.confirm});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: PaperCard(
        theme: t,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Scholar.display(24, theme: t)),
            const SizedBox(height: 8),
            Text(body,
                style: Scholar.body(14, theme: t, color: t.inkSoft),
                textAlign: TextAlign.center),
            const SizedBox(height: 18),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                WoodButton(
                  label: confirm,
                  width: 130,
                  theme: t,
                  primary: true,
                  onTap: () => Navigator.of(context).pop(true),
                ),
                const SizedBox(width: 12),
                WoodButton(
                  label: 'Cancel',
                  width: 130,
                  theme: t,
                  onTap: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
