import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Physical scholar's-desk UI components — pressed = inset shadow + 0.98
/// scale (weight, not glow). No neon, no decorative gradients, no flat
/// Material look.

/// Wooden plaque button with a carved serif label.
/// Primary actions get a cinnabar-red edge (per the Stitch design).
class ScholarButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final double fontSize;
  final double? width;
  const ScholarButton(
      {super.key,
      required this.label,
      this.onTap,
      this.primary = true,
      this.fontSize = 16,
      this.width});

  @override
  State<ScholarButton> createState() => _ScholarButtonState();
}

class _ScholarButtonState extends State<ScholarButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Container(
            width: widget.width,
            constraints: const BoxConstraints(
                minHeight: GomokuTheme.touch, minWidth: 88),
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.primary
                    ? [GomokuTheme.warmWood, GomokuTheme.kayaDeep]
                    : [GomokuTheme.washi, const Color(0xFFF0E4CC)],
              ),
              border: Border.all(
                  color: widget.primary
                      ? GomokuTheme.cinnabar
                      : GomokuTheme.warmGray.withValues(alpha: 0.5),
                  width: widget.primary ? 1.6 : 1.2),
              boxShadow: _down
                  ? [
                      const BoxShadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                          spreadRadius: -1),
                    ]
                  : [
                      const BoxShadow(
                          color: GomokuTheme.woodShadow,
                          blurRadius: 10,
                          offset: Offset(0, 5)),
                      const BoxShadow(
                          color: Colors.white70,
                          blurRadius: 1,
                          offset: Offset(0, 1),
                          spreadRadius: -1),
                    ],
            ),
            alignment: Alignment.center,
            child: Text(widget.label,
                textAlign: TextAlign.center,
                style: GomokuTheme.body(widget.fontSize,
                    color: widget.primary
                        ? GomokuTheme.washi
                        : GomokuTheme.ink,
                    weight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

/// Round wooden disc button (difficulty, undo, resign, hint, pause).
class ScholarDisc extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? tint;
  final bool selected;
  const ScholarDisc(
      {super.key,
      required this.icon,
      required this.label,
      this.onTap,
      this.tint,
      this.selected = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: tint != null
                      ? [tint!.withValues(alpha: 0.9), tint!]
                      : [
                          GomokuTheme.kayaAmber,
                          GomokuTheme.kayaDeep
                        ],
                ),
                border: Border.all(
                    color: selected
                        ? GomokuTheme.cinnabar
                        : GomokuTheme.kayaDeep,
                    width: selected ? 2.4 : 1.4),
                boxShadow: const [
                  BoxShadow(
                      color: GomokuTheme.woodShadow,
                      blurRadius: 8,
                      offset: Offset(0, 4)),
                  BoxShadow(
                      color: Colors.white54,
                      blurRadius: 1,
                      offset: Offset(0, 1),
                      spreadRadius: -1),
                ],
              ),
              child: Icon(icon,
                  color: GomokuTheme.washi, size: 24),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 72,
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: GomokuTheme.label(11)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Washi paper card with a subtle fibre edge.
class PaperCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const PaperCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: GomokuTheme.washi,
        borderRadius: GomokuTheme.cardRadius,
        border: Border.all(
            color: GomokuTheme.warmGray.withValues(alpha: 0.4),
            width: 1.2),
        boxShadow: const [
          BoxShadow(
              color: GomokuTheme.woodShadow,
              blurRadius: 14,
              offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

class SectionHead extends StatelessWidget {
  final String title;
  const SectionHead({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 18, color: GomokuTheme.sealDeep),
        const SizedBox(width: 8),
        Text(title,
            style: GomokuTheme.body(15,
                weight: FontWeight.w600, color: GomokuTheme.ink)),
      ],
    );
  }
}

/// Polished-stone switch sliding in a carved wooden groove.
class StoneToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const StoneToggle(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 58,
        height: 32,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color:
              value ? GomokuTheme.kayaDeep : const Color(0xFFDCCFB8),
          border: Border.all(
              color: GomokuTheme.kayaDeep.withValues(alpha: 0.6)),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26,
                blurRadius: 2,
                offset: Offset(0, 1),
                spreadRadius: -1),
          ],
        ),
        alignment:
            value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: Alignment(-0.35, -0.4),
              colors: [Color(0xFFF6F1E4), Color(0xFFD9CDAF)],
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black38,
                  blurRadius: 3,
                  offset: Offset(0, 2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bamboo-rod slider with a wooden bead thumb.
class BambooSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const BambooSlider(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 8,
        activeTrackColor: GomokuTheme.kayaAmber,
        inactiveTrackColor: const Color(0xFFE4D3B4),
        thumbShape: const _BeadThumb(),
        overlayShape: SliderComponentShape.noOverlay,
      ),
      child: Slider(value: value, min: 0, max: 1, onChanged: onChanged),
    );
  }
}

class _BeadThumb extends SliderComponentShape {
  const _BeadThumb();
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(28, 28);

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final c = context.canvas;
    c.drawCircle(
        center + const Offset(1, 2), 14, Paint()..color = Colors.black26);
    c.drawCircle(
        center,
        14,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.35, -0.4),
            colors: [Color(0xFFD9A85E), Color(0xFF7A4A12)],
          ).createShader(Rect.fromCircle(center: center, radius: 14)));
    // bamboo ring groove
    c.drawCircle(
        center,
        8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF4A2C08).withValues(alpha: 0.55));
    c.drawCircle(center + const Offset(-4, -4), 4,
        Paint()..color = Colors.white.withValues(alpha: 0.35));
  }
}

/// Segmented control carved in light wood.
class WoodSegmented<T> extends StatelessWidget {
  final List<T> values;
  final List<String> labels;
  final T current;
  final ValueChanged<T> onChanged;
  const WoodSegmented(
      {super.key,
      required this.values,
      required this.labels,
      required this.current,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFE2C9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: GomokuTheme.warmGray.withValues(alpha: 0.4)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: Offset(0, 1),
              spreadRadius: -1),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(values[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    gradient: values[i] == current
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                                GomokuTheme.warmWood,
                                GomokuTheme.kayaDeep
                              ])
                        : null,
                    boxShadow: values[i] == current
                        ? const [
                            BoxShadow(
                                color: GomokuTheme.woodShadow,
                                blurRadius: 6,
                                offset: Offset(0, 3))
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(labels[i],
                      style: GomokuTheme.label(13,
                          color: values[i] == current
                              ? GomokuTheme.washi
                              : GomokuTheme.ink)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Cinnabar seal stamp — a decorative red square seal (non-linguistic).
class SealStamp extends StatelessWidget {
  final double size;
  const SealStamp({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.06,
      child: CustomPaint(
        size: Size(size, size),
        painter: _SealPainter(),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final r = s.width / 2;
    // rough-edged red square
    final path = Path()
      ..moveTo(2, 6)
      ..lineTo(s.width - 4, 2)
      ..lineTo(s.width - 2, s.height - 5)
      ..lineTo(5, s.height - 2)
      ..close();
    canvas.drawPath(
        path,
        Paint()
          ..color =
              GomokuTheme.cinnabar.withValues(alpha: 0.92));
    // carved inner square (seal face)
    canvas.drawRect(
        Rect.fromCircle(center: Offset(r, r), radius: r * 0.52),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = GomokuTheme.washi.withValues(alpha: 0.85));
    // abstract brush notches inside the seal
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..color = GomokuTheme.washi.withValues(alpha: 0.85);
    canvas.drawLine(Offset(r - 8, r - 9), Offset(r + 8, r - 9), inner);
    canvas.drawLine(Offset(r, r - 9), Offset(r, r + 9), inner);
    canvas.drawLine(Offset(r - 8, r + 9), Offset(r + 8, r + 9), inner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Miniature physical stone for plaques and indicators.
class MiniStone extends StatelessWidget {
  final bool black;
  final double size;
  const MiniStone({super.key, required this.black, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: black
              ? [GomokuTheme.slateTop, GomokuTheme.slateDeep]
              : [Colors.white, const Color(0xFFE7DDC6)],
        ),
        boxShadow: const [
          BoxShadow(
              color: GomokuTheme.stoneShadow,
              blurRadius: 3,
              offset: Offset(0, 2)),
        ],
      ),
    );
  }
}

/// Ink-wash brush divider.
class BrushDivider extends StatelessWidget {
  const BrushDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 14),
      painter: _BrushPainter(),
    );
  }
}

class _BrushPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final mid = s.height / 2;
    final path = Path()..moveTo(0, mid);
    // tapered brush stroke: thick in the middle, dry at the ends
    for (var x = 0.0; x <= s.width; x += 8) {
      final t = x / s.width;
      final w = 2.2 * sin(pi * t.clamp(0.0, 1.0)) + 0.4;
      path.lineTo(x, mid - w);
    }
    for (var x = s.width; x >= 0; x -= 8) {
      final t = x / s.width;
      final w = 2.2 * sin(pi * t.clamp(0.0, 1.0)) + 0.4;
      path.lineTo(x, mid + w);
    }
    path.close();
    canvas.drawPath(
        path,
        Paint()
          ..color = GomokuTheme.ink.withValues(alpha: 0.28));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
