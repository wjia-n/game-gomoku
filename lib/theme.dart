import 'package:flutter/material.dart';

/// Stitch "Scholar's Hearth" design tokens for Gomoku —
/// ink-wash East Asian scholar's desk: rice paper, ink stone, kaya wood,
/// cinnabar seal accents, warm courtyard lamp light.
abstract final class GomokuTheme {
  // --- palette ---------------------------------------------------------------
  static const ricePaper = Color(0xFFF3EAD3); // app background base
  static const washi = Color(0xFFFEF9EF); // paper panels, cards, surfaces
  static const warmWood = Color(0xFF8B5A2B); // primary plaques, buttons
  static const kayaAmber = Color(0xFFC89B5A); // board slab, button faces
  static const kayaDeep = Color(0xFF6F4315); // board edge bevel, pressed state
  static const lacquer = Color(0xFF32302A); // top player plaques, headers
  static const ink = Color(0xFF24211D); // primary text on cream
  static const warmGray = Color(0xFF837469); // secondary text, outlines
  static const cinnabar = Color(0xFFC23B22); // seal stamps, last-move marker
  static const sealDeep = Color(0xFFB02E16); // selection rings, emphasis
  static const emberGold = Color(0xFFB8860B); // highlights, top-edge light
  static const error = Color(0xFFB02E16); // illegal-move flash

  static const slateTop = Color(0xFF3A3735); // black stone highlight side
  static const slateDeep = Color(0xFF151412); // black stone deep side

  static const stoneShadow = Color(0x59000000); // rgba(0,0,0,0.35)
  static const woodShadow = Color(0x2E6F4315); // rgba(111,67,21,~0.18)

  // --- typography ------------------------------------------------------------
  // Noto Serif ships on Android; elsewhere Flutter falls back gracefully.
  // Brush-calligraphy display feel comes from scale + weight + ink color.
  static const serif = 'Noto Serif';

  static TextStyle display(double size, {FontWeight weight = FontWeight.w600}) =>
      TextStyle(
          fontFamily: serif,
          fontSize: size,
          fontWeight: weight,
          color: ink,
          height: 1.2);

  static TextStyle body(double size,
          {Color color = ink, FontWeight weight = FontWeight.w400}) =>
      TextStyle(
          fontFamily: serif,
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: 1.5);

  static TextStyle counter(double size, {Color color = ink}) => TextStyle(
      fontFamily: serif,
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
      height: 1.2);

  static TextStyle label(double size, {Color color = warmGray}) => TextStyle(
      fontFamily: serif,
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: color,
      height: 1.35);

  // --- layout ----------------------------------------------------------------
  static const radius = Radius.circular(14);
  static const cardRadius = BorderRadius.all(Radius.circular(14));
  static const double touch = 44.0; // minimum touch target
}
