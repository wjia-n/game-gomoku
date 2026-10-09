import 'package:flutter/material.dart';
import 'scholar_themes.dart';

/// Scholar's Hearth — the Stitch-derived design system for Gomoku.
/// Ink-wash East Asian scholar's desk: rice paper, washi panels, kaya wood,
/// ink text, cinnabar seal accents. No neon, no cyberpunk, no generic
/// Material look.
///
/// All widgets accept an optional [ScholarThemeDef]; they default to the
/// Scholar's Hearth theme so existing call sites keep working.
class Scholar {
  static const displayFont = 'serif';

  static TextStyle display(double size,
          {Color? color, ScholarThemeDef? theme}) =>
      TextStyle(
        fontFamily: displayFont,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme?.inkText ?? const Color(0xFF24211D),
        letterSpacing: 1.2,
        shadows: [
          Shadow(
              color: Colors.black.withValues(alpha: 0.18),
              offset: const Offset(0, 2),
              blurRadius: 4),
        ],
      );

  static TextStyle body(double size,
          {Color? color, ScholarThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? theme?.inkText ?? const Color(0xFF24211D),
        height: 1.35,
      );

  static TextStyle label(double size,
          {Color? color, ScholarThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme?.accent ?? const Color(0xFFC23B22),
        letterSpacing: 0.8,
      );

  static ThemeData theme([ScholarThemeDef? t]) {
    t ??= ScholarThemes.byId('hearth');
    // Light paper themes use light brightness; dark ones use dark.
    final dark = t.id == 'rosewood' ||
        t.id == 'moonlit' ||
        t.id == 'lacquer' ||
        t.id == 'custom' && _isDark(t.paper);
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: t.paper,
      colorScheme: ColorScheme(
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: t.accent,
        onPrimary: t.paperCard,
        secondary: t.woodMid,
        onSecondary: t.paperCard,
        surface: t.paperCard,
        onSurface: t.inkText,
        error: t.accentDeep,
        onError: t.paperCard,
      ),
      textTheme: TextTheme(
        displayLarge: display(34, theme: t),
        displayMedium: display(26, theme: t),
        titleLarge: display(22, theme: t),
        bodyLarge: body(16, theme: t),
        bodyMedium: body(14, theme: t),
        labelLarge: label(14, theme: t),
      ),
      dialogTheme: DialogThemeData(backgroundColor: t.paperCard),
    );
  }

  static bool _isDark(Color c) {
    final lum = (0.299 * c.r + 0.587 * c.g + 0.114 * c.b);
    return lum < 0.45;
  }
}

/// Rice-paper background with a warm vignette and faint fiber texture,
/// theme-aware.
class PaperBackdrop extends StatelessWidget {
  final Widget child;
  final ScholarThemeDef? theme;
  const PaperBackdrop({super.key, required this.child, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ScholarThemes.byId('hearth');
    return Container(
      decoration: BoxDecoration(color: t.paper),
      child: CustomPaint(
        painter: _PaperPainter(t),
        child: child,
      ),
    );
  }
}

class _PaperPainter extends CustomPainter {
  final ScholarThemeDef t;
  _PaperPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Warm lamp glow from the top corner.
    final glow = RadialGradient(
      center: const Alignment(0.6, -0.7),
      radius: 1.2,
      colors: [
        t.woodLight.withValues(alpha: 0.22),
        t.paper.withValues(alpha: 0.0),
      ],
    );
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..shader = glow.createShader(
            Rect.fromLTWH(0, 0, size.width, size.height)));
    // Soft vignette at the edges to focus the center.
    final vignette = RadialGradient(
      center: Alignment.center,
      radius: 1.05,
      colors: [
        t.woodDeep.withValues(alpha: 0.0),
        t.woodDeep.withValues(alpha: 0.16),
      ],
    );
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..shader = vignette.createShader(
            Rect.fromLTWH(0, 0, size.width, size.height)));
  }

  @override
  bool shouldRepaint(covariant _PaperPainter old) => old.t.id != t.id;
}

/// Thick wooden plaque button with carved label, top highlight + bottom
/// shadow for physical weight.
class WoodButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double width;
  final double fontSize;
  final ScholarThemeDef? theme;
  final bool primary; // cinnabar edge for primary actions

  const WoodButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width = 240,
    this.fontSize = 17,
    this.theme,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ScholarThemes.byId('hearth');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.woodMid, t.woodDeep],
          ),
          border: Border.all(
            color: primary ? t.accent : t.woodLight.withValues(alpha: 0.7),
            width: primary ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
            BoxShadow(
              color: t.woodLight.withValues(alpha: 0.35),
              offset: const Offset(0, -1),
              blurRadius: 2,
            ),
          ],
        ),
        child: Text(
          label,
          style: Scholar.label(fontSize,
              theme: t, color: const Color(0xFFFFF6E6)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Washi-paper card with deckled-edge feel and soft shadow.
class PaperCard extends StatelessWidget {
  final Widget child;
  final ScholarThemeDef? theme;
  final EdgeInsetsGeometry padding;

  const PaperCard({
    super.key,
    required this.child,
    this.theme,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ScholarThemes.byId('hearth');
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: t.paperCard,
        border: Border.all(color: t.woodMid.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            offset: const Offset(0, 5),
            blurRadius: 14,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Small lacquer plaque for stats (moves / time / streak).
class StatPlaque extends StatelessWidget {
  final String label;
  final String value;
  final ScholarThemeDef? theme;

  const StatPlaque(
      {super.key,
      required this.label,
      required this.value,
      this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ScholarThemes.byId('hearth');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.woodDeep, t.woodMid.withValues(alpha: 0.85)],
        ),
        border: Border.all(color: t.accent.withValues(alpha: 0.55)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: Scholar.display(17,
                  theme: t, color: const Color(0xFFFFF6E6))),
          Text(label,
              style: Scholar.label(10,
                  theme: t,
                  color:
                      const Color(0xFFFFF6E6).withValues(alpha: 0.75))),
        ],
      ),
    );
  }
}

/// Red square ink-seal stamp (non-linguistic decorative mark).
class SealStamp extends StatelessWidget {
  final double size;
  final ScholarThemeDef? theme;
  const SealStamp({super.key, this.size = 34, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ScholarThemes.byId('hearth');
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.18),
        color: t.accent,
        border: Border.all(color: t.accentDeep, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: CustomPaint(painter: _SealGlyphPainter(t)),
    );
  }
}

class _SealGlyphPainter extends CustomPainter {
  final ScholarThemeDef t;
  _SealGlyphPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = t.paperCard.withValues(alpha: 0.9)
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round;
    // Abstract seal strokes (not real characters).
    final w = size.width, h = size.height;
    canvas.drawLine(Offset(w * 0.28, h * 0.24), Offset(w * 0.72, h * 0.24), p);
    canvas.drawLine(Offset(w * 0.5, h * 0.24), Offset(w * 0.5, h * 0.76), p);
    canvas.drawLine(Offset(w * 0.28, h * 0.76), Offset(w * 0.72, h * 0.76), p);
    canvas.drawLine(Offset(w * 0.28, h * 0.5), Offset(w * 0.72, h * 0.5), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
