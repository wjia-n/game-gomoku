import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/gomoku_engine.dart';
import '../theme.dart';

/// Kaya-wood goban with pseudo-3D slate & clamshell stones.
/// Single warm light source, upper-left, like courtyard lamplight.
/// Stones drop with weight; invalid taps shake the board gently.
class KayaBoard extends StatefulWidget {
  final List<int> board;
  final int lastMove;
  final int invalidAt;
  final int hintAt;
  final List<int>? winLine;
  final bool showCoordinates;
  final bool showLastMoveMarker;
  final bool interactive;
  final ValueChanged<int> onTap;

  const KayaBoard({
    super.key,
    required this.board,
    required this.lastMove,
    required this.invalidAt,
    required this.hintAt,
    required this.winLine,
    required this.showCoordinates,
    required this.showLastMoveMarker,
    required this.onTap,
    this.interactive = true,
  });

  @override
  State<KayaBoard> createState() => _KayaBoardState();
}

class _KayaBoardState extends State<KayaBoard>
    with TickerProviderStateMixin {
  late final AnimationController _place;
  late final Animation<double> _placeScale;
  late final AnimationController _shake;
  late final Animation<double> _shakeX;
  late final AnimationController _hint;
  int _placedFor = -2;
  int _shookFor = -2;

  @override
  void initState() {
    super.initState();
    // stone drop: heavy fall, tiny settle bounce
    _place = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _placeScale = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 1.34, end: 0.94)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 50),
      TweenSequenceItem(
          tween: Tween(begin: 0.94, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 50),
    ]).animate(_place);
    // invalid tap: gentle side-to-side shake
    _shake = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _shakeX = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 8),
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: -7.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 23),
      TweenSequenceItem(
          tween: Tween(begin: -7.0, end: 6.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 23),
      TweenSequenceItem(
          tween: Tween(begin: 6.0, end: -3.5)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 23),
      TweenSequenceItem(
          tween: Tween(begin: -3.5, end: 0.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 23),
    ]).animate(_shake);
    // hint: slow breathing ring
    _hint = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    for (final c in [_place, _shake]) {
      c.addListener(() => setState(() {}));
    }
    _hint.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant KayaBoard old) {
    super.didUpdateWidget(old);
    if (widget.lastMove != old.lastMove &&
        widget.lastMove >= 0 &&
        widget.lastMove != _placedFor) {
      _placedFor = widget.lastMove;
      _place.forward(from: 0);
    }
    if (widget.invalidAt != old.invalidAt &&
        widget.invalidAt >= 0 &&
        widget.invalidAt != _shookFor) {
      _shookFor = widget.invalidAt;
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _place.dispose();
    _shake.dispose();
    _hint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, cons) {
        final side = min(cons.maxWidth, cons.maxHeight);
        return GestureDetector(
          onTapUp: widget.interactive
              ? (d) {
                  final rb = ctx.findRenderObject() as RenderBox?;
                  if (rb == null) return;
                  final i = _hitTest(rb, d.globalPosition, side);
                  if (i != null) widget.onTap(i);
                }
              : null,
          child: SizedBox(
            width: side,
            height: side,
            child: CustomPaint(
              painter: _KayaPainter(
                board: widget.board,
                lastMove: widget.lastMove,
                invalidAt: widget.invalidAt,
                hintAt: widget.hintAt,
                winLine: widget.winLine,
                showCoordinates: widget.showCoordinates,
                showLastMoveMarker: widget.showLastMoveMarker,
                placeScale: _place.isAnimating ? _placeScale.value : 1.0,
                shakeDx: _shake.isAnimating ? _shakeX.value : 0.0,
                hintPulse: _hint.value,
              ),
            ),
          ),
        );
      },
    );
  }

  int? _hitTest(RenderBox rb, Offset global, double side) {
    final lp = rb.globalToLocal(global);
    final m =
        _KayaPainter.metrics(side, widget.showCoordinates);
    final cc = ((lp.dx - m.pad) / m.cell).round();
    final rr = ((lp.dy - m.pad) / m.cell).round();
    if (rr < 0 || rr >= GomokuEngine.n || cc < 0 || cc >= GomokuEngine.n) {
      return null;
    }
    final dx = (lp.dx - (m.pad + cc * m.cell)).abs();
    final dy = (lp.dy - (m.pad + rr * m.cell)).abs();
    if (dx > m.cell * 0.48 || dy > m.cell * 0.48) return null;
    return rr * GomokuEngine.n + cc;
  }
}

class _Metrics {
  final double pad, cell, edge;
  _Metrics(this.pad, this.cell, this.edge);
}

class _KayaPainter extends CustomPainter {
  final List<int> board;
  final int lastMove, invalidAt, hintAt;
  final List<int>? winLine;
  final bool showCoordinates, showLastMoveMarker;
  final double placeScale, shakeDx, hintPulse;

  _KayaPainter({
    required this.board,
    required this.lastMove,
    required this.invalidAt,
    required this.hintAt,
    required this.winLine,
    required this.showCoordinates,
    required this.showLastMoveMarker,
    required this.placeScale,
    required this.shakeDx,
    required this.hintPulse,
  });

  static const n = GomokuEngine.n;

  static _Metrics metrics(double side, bool coords) {
    final coordRoom = coords ? side * 0.055 : 0.0;
    final pad = side * 0.085 + coordRoom;
    final cell = (side - pad * 2) / (n - 1);
    return _Metrics(pad, cell, pad + (n - 1) * cell);
  }

  static const _cols = 'ABCDEFGHIJKLMNO';

  @override
  void paint(Canvas canvas, Size s) {
    canvas.save();
    canvas.translate(shakeDx, 0);
    final side = s.width;
    final m = metrics(side, showCoordinates);
    Offset pt(int i) =>
        Offset(m.pad + (i % n) * m.cell, m.pad + (i ~/ n) * m.cell);

    _paintSlab(canvas, s);
    _paintGrid(canvas, m, pt);
    if (showCoordinates) _paintCoordinates(canvas, m);
    _paintStones(canvas, m, pt);
    if (winLine != null) _paintWinLine(canvas, pt);
    if (hintAt >= 0) _paintHint(canvas, pt(hintAt), m);
    if (invalidAt >= 0) _paintInvalid(canvas, pt(invalidAt), m);
    canvas.restore();
  }

  void _paintSlab(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    // kaya amber base, faint diagonal sheen (lamp light, upper-left)
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFD9A85E),
            Color(0xFFC89B5A),
            Color(0xFFB37E35)
          ],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );
    // straight kaya grain — deterministic so it never shimmers
    final rnd = Random(20261009);
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (var k = 0; k < 30; k++) {
      final x = rnd.nextDouble() * s.width;
      final wob = 2 + rnd.nextDouble() * 5;
      final path = Path()..moveTo(x, 0);
      for (var y = 0.0; y <= s.height; y += 24) {
        path.lineTo(x + sin(y / 90 + k) * wob, y);
      }
      grain.color = const Color(0xFF6F4315)
          .withValues(alpha: 0.05 + rnd.nextDouble() * 0.05);
      canvas.drawPath(path, grain);
    }
    // beveled light-catching edge: top-left light, bottom-right dark
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = GomokuTheme.emberGold.withValues(alpha: 0.5),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          rect.deflate(3), const Radius.circular(10)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = GomokuTheme.kayaDeep.withValues(alpha: 0.75),
    );
    // soft ambient occlusion inside the rim
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          rect.deflate(7), const Radius.circular(8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = Colors.black.withValues(alpha: 0.10),
    );
  }

  void _paintGrid(Canvas canvas, _Metrics m, Offset Function(int) pt) {
    final grid = Paint()
      ..color = const Color(0xFF4A2F0E).withValues(alpha: 0.85)
      ..strokeWidth = (m.cell * 0.045).clamp(1.0, 1.8);
    for (var k = 0; k < n; k++) {
      final p = m.pad + k * m.cell;
      canvas.drawLine(Offset(m.pad, p), Offset(m.edge, p), grid);
      canvas.drawLine(Offset(p, m.pad), Offset(p, m.edge), grid);
    }
    // star points
    const stars = [
      [3, 3],
      [3, 11],
      [11, 3],
      [11, 11],
      [7, 7]
    ];
    final star = Paint()..color = const Color(0xFF4A2F0E);
    for (final sp in stars) {
      canvas.drawCircle(pt(sp[0] * n + sp[1]),
          (m.cell * 0.09).clamp(1.6, 3.6), star);
    }
  }

  void _paintCoordinates(Canvas canvas, _Metrics m) {
    final style = GomokuTheme.label((m.cell * 0.34).clamp(7.0, 10.0));
    for (var k = 0; k < n; k++) {
      _text(canvas, _cols[k],
          Offset(m.pad + k * m.cell, m.pad - m.cell * 0.62), style);
      _text(canvas, '${n - k}',
          Offset(m.pad - m.cell * 0.62, m.pad + k * m.cell), style);
    }
  }

  void _text(Canvas canvas, String t, Offset at, TextStyle style) {
    final tp = TextPainter(
        text: TextSpan(text: t, style: style),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center)
      ..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  void _paintStones(Canvas canvas, _Metrics m, Offset Function(int) pt) {
    final r = m.cell * 0.47;
    final winSet = winLine?.toSet() ?? {};
    for (var i = 0; i < board.length; i++) {
      final v = board[i];
      if (v == 0) continue;
      var rr = r;
      var lift = 0.0;
      if (i == lastMove) {
        rr *= placeScale;
        // while dropping, the stone hovers: shadow stays, stone lifts
        lift = (placeScale - 1.0).clamp(0.0, 1.0) * -r * 0.55;
      }
      final p = pt(i) + Offset(0, lift);

      // contact shadow — firm, offset down-right (light from upper-left)
      canvas.drawOval(
        Rect.fromCenter(
            center: pt(i) + Offset(rr * 0.14, rr * 0.20),
            width: rr * 1.9,
            height: rr * 1.75),
        Paint()..color = GomokuTheme.stoneShadow,
      );

      final rect = Rect.fromCircle(center: p, radius: rr);
      if (v == 1) {
        // slate black: near-black, soft top-left specular
        canvas.drawCircle(
            p,
            rr,
            Paint()
              ..shader = const RadialGradient(
                center: Alignment(-0.35, -0.4),
                radius: 1.1,
                colors: [
                  GomokuTheme.slateTop,
                  GomokuTheme.slateDeep
                ],
              ).createShader(rect));
        canvas.drawOval(
            Rect.fromCenter(
                center: p + Offset(-rr * 0.32, -rr * 0.36),
                width: rr * 0.55,
                height: rr * 0.38),
            Paint()..color = Colors.white.withValues(alpha: 0.17));
      } else {
        // clamshell white: milky, marbled banding, warm rim translucency
        canvas.drawCircle(
            p,
            rr,
            Paint()
              ..shader = const RadialGradient(
                center: Alignment(-0.3, -0.35),
                radius: 1.15,
                colors: [
                  Colors.white,
                  Color(0xFFF4EDDC),
                  Color(0xFFDCD2BC)
                ],
              ).createShader(rect));
        final band = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rr * 0.06
          ..color =
              const Color(0xFFB8A888).withValues(alpha: 0.15);
        canvas.drawArc(rect.deflate(rr * 0.35), 0.4, 1.8, false, band);
        canvas.drawArc(rect.deflate(rr * 0.6), 3.4, 1.4, false, band);
        canvas.drawCircle(
            p,
            rr,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = rr * 0.10
              ..color = const Color(0xFFF0C87E)
                  .withValues(alpha: 0.22));
      }

      if (winSet.contains(i)) {
        // winning stones keep their body; the cinnabar ring goes on top
      } else if (i == lastMove && showLastMoveMarker) {
        // vermilion seal dot on the last move
        canvas.drawCircle(
            p, rr * 0.20, Paint()..color = GomokuTheme.cinnabar);
        canvas.drawCircle(
            p,
            rr * 0.20,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = Colors.white.withValues(alpha: 0.5));
      }
    }
  }

  void _paintWinLine(Canvas canvas, Offset Function(int) pt) {
    final r = (pt(1).dx - pt(0).dx) * 0.47;
    for (final i in winLine!) {
      final p = pt(i);
      // cinnabar ring around each winning stone
      canvas.drawCircle(
          p,
          r * 1.12,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = (r * 0.16).clamp(2.0, 4.0)
            ..color = GomokuTheme.cinnabar);
      canvas.drawCircle(
          p,
          r * 1.12,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Colors.white.withValues(alpha: 0.55));
    }
  }

  void _paintHint(Canvas canvas, Offset p, _Metrics m) {
    final r = m.cell * 0.47;
    final pulse = 0.5 + hintPulse * 0.5;
    canvas.drawCircle(
        p,
        r * (1.0 + pulse * 0.22),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = GomokuTheme.emberGold
              .withValues(alpha: 0.55 + pulse * 0.4));
  }

  void _paintInvalid(Canvas canvas, Offset p, _Metrics m) {
    final r = m.cell * 0.47;
    canvas.drawCircle(
        p,
        r * 1.05,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = GomokuTheme.error.withValues(alpha: 0.85));
    canvas.drawCircle(p, r * 0.9,
        Paint()..color = GomokuTheme.error.withValues(alpha: 0.18));
  }

  @override
  bool shouldRepaint(covariant _KayaPainter o) =>
      o.board != board ||
      o.lastMove != lastMove ||
      o.invalidAt != invalidAt ||
      o.hintAt != hintAt ||
      o.winLine != winLine ||
      o.showCoordinates != showCoordinates ||
      o.showLastMoveMarker != showLastMoveMarker ||
      o.placeScale != placeScale ||
      o.shakeDx != shakeDx ||
      o.hintPulse != hintPulse;
}
