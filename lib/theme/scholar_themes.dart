import 'package:flutter/material.dart';

/// Theme, stone-style and last-move-marker catalogs for Gomoku.
///
/// Every theme stays inside the "Scholar's Hearth" material world from the
/// Stitch design system: rice paper, washi panels, kaya/rosewood/bamboo
/// woods, ink text, cinnabar seal accents. Variety comes from different
/// woods, paper tones and seal colors — never neon, never synthetic.
class ScholarThemeDef {
  final String id;
  final String name;
  final Color paper; // app background base
  final Color paperCard; // washi panels, cards
  final Color inkText; // primary text
  final Color inkSoft; // secondary text
  final Color woodLight; // board face
  final Color woodMid; // board edge / buttons
  final Color woodDeep; // pressed states, dark plaques
  final Color gridLine; // board grid ink
  final Color accent; // cinnabar seal red etc.
  final Color accentDeep;

  const ScholarThemeDef({
    required this.id,
    required this.name,
    required this.paper,
    required this.paperCard,
    required this.inkText,
    required this.inkSoft,
    required this.woodLight,
    required this.woodMid,
    required this.woodDeep,
    required this.gridLine,
    required this.accent,
    required this.accentDeep,
  });
}

class ScholarThemes {
  /// First 4 are the FREE starter themes. The rest are PRO.
  static const List<String> freeThemeIds = [
    'hearth',
    'kaya',
    'bamboo',
    'inkwash',
  ];

  static const List<ScholarThemeDef> all = [
    ScholarThemeDef(
      id: 'hearth',
      name: "Scholar's Hearth",
      paper: Color(0xFFF3EAD3),
      paperCard: Color(0xFFFEF9EF),
      inkText: Color(0xFF24211D),
      inkSoft: Color(0xFF837469),
      woodLight: Color(0xFFC89B5A),
      woodMid: Color(0xFF8B5A2B),
      woodDeep: Color(0xFF6F4315),
      gridLine: Color(0xFF4A3A28),
      accent: Color(0xFFC23B22),
      accentDeep: Color(0xFFB02E16),
    ),
    ScholarThemeDef(
      id: 'kaya',
      name: 'Kaya Classic',
      paper: Color(0xFFF6EFDD),
      paperCard: Color(0xFFFFFBF2),
      inkText: Color(0xFF2A241C),
      inkSoft: Color(0xFF8A7A64),
      woodLight: Color(0xFFD9B06E),
      woodMid: Color(0xFFA4763A),
      woodDeep: Color(0xFF7A541F),
      gridLine: Color(0xFF54401F),
      accent: Color(0xFFB8860B),
      accentDeep: Color(0xFF8F6A08),
    ),
    ScholarThemeDef(
      id: 'bamboo',
      name: 'Bamboo Grove',
      paper: Color(0xFFF1EDD8),
      paperCard: Color(0xFFFBF8EC),
      inkText: Color(0xFF232A1E),
      inkSoft: Color(0xFF7A7F6A),
      woodLight: Color(0xFFCBB26A),
      woodMid: Color(0xFF8F7A3E),
      woodDeep: Color(0xFF655626),
      gridLine: Color(0xFF4C4430),
      accent: Color(0xFF3E6B3A),
      accentDeep: Color(0xFF2D4F2A),
    ),
    ScholarThemeDef(
      id: 'inkwash',
      name: 'Ink Wash',
      paper: Color(0xFFEDEAE2),
      paperCard: Color(0xFFF8F6F1),
      inkText: Color(0xFF1E1C18),
      inkSoft: Color(0xFF7C766C),
      woodLight: Color(0xFFB9A37E),
      woodMid: Color(0xFF7E6B4C),
      woodDeep: Color(0xFF57493A),
      gridLine: Color(0xFF3A352C),
      accent: Color(0xFF4A4A4A),
      accentDeep: Color(0xFF2E2E2E),
    ),
    ScholarThemeDef(
      id: 'rosewood',
      name: 'Rosewood Night',
      paper: Color(0xFF2E2620),
      paperCard: Color(0xFF3B3129),
      inkText: Color(0xFFF3EAD3),
      inkSoft: Color(0xFFB9A88F),
      woodLight: Color(0xFF7C3F24),
      woodMid: Color(0xFF5A2A1A),
      woodDeep: Color(0xFF381408),
      gridLine: Color(0xFFD8C49A),
      accent: Color(0xFFD4573B),
      accentDeep: Color(0xFFA83A24),
    ),
    ScholarThemeDef(
      id: 'cinnabar',
      name: 'Cinnabar Seal',
      paper: Color(0xFFF5E4D4),
      paperCard: Color(0xFFFFF3E6),
      inkText: Color(0xFF331D14),
      inkSoft: Color(0xFF93705E),
      woodLight: Color(0xFFC98A5A),
      woodMid: Color(0xFF96522E),
      woodDeep: Color(0xFF6B3418),
      gridLine: Color(0xFF5A3220),
      accent: Color(0xFFC23B22),
      accentDeep: Color(0xFF8E2413),
    ),
    ScholarThemeDef(
      id: 'moonlit',
      name: 'Moonlit Courtyard',
      paper: Color(0xFF232B3A),
      paperCard: Color(0xFF2E3850),
      inkText: Color(0xFFF0EAD8),
      inkSoft: Color(0xFF9AA3B5),
      woodLight: Color(0xFF8A6F4D),
      woodMid: Color(0xFF5F4B32),
      woodDeep: Color(0xFF3E3120),
      gridLine: Color(0xFFD9CFB4),
      accent: Color(0xFFC9A86A),
      accentDeep: Color(0xFF9A7B45),
    ),
    ScholarThemeDef(
      id: 'teahouse',
      name: 'Tea House',
      paper: Color(0xFFF0E6CE),
      paperCard: Color(0xFFFAF4E2),
      inkText: Color(0xFF2E2A1E),
      inkSoft: Color(0xFF8A7D63),
      woodLight: Color(0xFFB98D55),
      woodMid: Color(0xFF7E5A30),
      woodDeep: Color(0xFF573D1E),
      gridLine: Color(0xFF4A3A24),
      accent: Color(0xFF5E7A3A),
      accentDeep: Color(0xFF425626),
    ),
    ScholarThemeDef(
      id: 'porcelain',
      name: 'Porcelain Study',
      paper: Color(0xFFE9EDF0),
      paperCard: Color(0xFFF7FAFB),
      inkText: Color(0xFF22303A),
      inkSoft: Color(0xFF75828C),
      woodLight: Color(0xFFD9C9A8),
      woodMid: Color(0xFF9A7F56),
      woodDeep: Color(0xFF6B5638),
      gridLine: Color(0xFF2E4A5E),
      accent: Color(0xFF2E5A88),
      accentDeep: Color(0xFF1E3A5C),
    ),
    ScholarThemeDef(
      id: 'library',
      name: 'Old Library',
      paper: Color(0xFFEAD9B8),
      paperCard: Color(0xFFF6E9CC),
      inkText: Color(0xFF3A2A18),
      inkSoft: Color(0xFF8F7A5C),
      woodLight: Color(0xFFA5713D),
      woodMid: Color(0xFF74491F),
      woodDeep: Color(0xFF4E2F10),
      gridLine: Color(0xFF4A3418),
      accent: Color(0xFF8E3B2F),
      accentDeep: Color(0xFF652820),
    ),
    ScholarThemeDef(
      id: 'maple',
      name: 'Autumn Maple',
      paper: Color(0xFFF3DFC2),
      paperCard: Color(0xFFFBEEDC),
      inkText: Color(0xFF3A2415),
      inkSoft: Color(0xFF9A7A58),
      woodLight: Color(0xFFC07A3E),
      woodMid: Color(0xFF8A4E22),
      woodDeep: Color(0xFF5E3212),
      gridLine: Color(0xFF542E16),
      accent: Color(0xFFB3402A),
      accentDeep: Color(0xFF822916),
    ),
    ScholarThemeDef(
      id: 'plum',
      name: 'Winter Plum',
      paper: Color(0xFFF0E4E4),
      paperCard: Color(0xFFFAF1F1),
      inkText: Color(0xFF33222A),
      inkSoft: Color(0xFF907078),
      woodLight: Color(0xFF9A7A5E),
      woodMid: Color(0xFF6B4E3C),
      woodDeep: Color(0xFF483326),
      gridLine: Color(0xFF443028),
      accent: Color(0xFF8E3B52),
      accentDeep: Color(0xFF652737),
    ),
    ScholarThemeDef(
      id: 'lacquer',
      name: 'Lacquer Black',
      paper: Color(0xFF1E1B18),
      paperCard: Color(0xFF2A2521),
      inkText: Color(0xFFF3EAD3),
      inkSoft: Color(0xFFA89A80),
      woodLight: Color(0xFF4A3A2A),
      woodMid: Color(0xFF33271C),
      woodDeep: Color(0xFF1F1812),
      gridLine: Color(0xFFD8C49A),
      accent: Color(0xFFC23B22),
      accentDeep: Color(0xFF8E2413),
    ),
    ScholarThemeDef(
      id: 'sandalwood',
      name: 'Sandalwood',
      paper: Color(0xFFF5ECD8),
      paperCard: Color(0xFFFFF8E8),
      inkText: Color(0xFF3A2E1E),
      inkSoft: Color(0xFF9A8A6E),
      woodLight: Color(0xFFD4AC72),
      woodMid: Color(0xFF9A7440),
      woodDeep: Color(0xFF6B4E26),
      gridLine: Color(0xFF5A4426),
      accent: Color(0xFF7A5A2E),
      accentDeep: Color(0xFF54401E),
    ),
  ];

  static ScholarThemeDef byId(String id, {ScholarThemeDef? custom}) {
    if (id == 'custom') {
      return custom ?? all.first;
    }
    return all.firstWhere((t) => t.id == id, orElse: () => all.first);
  }

  static bool isProTheme(String id) =>
      !freeThemeIds.contains(id) && id != 'custom';
}

/// Go-stone material styles. 0-3 = FREE, 4+ = PRO.
/// Each style: black stone (base, sheen) + white stone (base, sheen).
class StoneStyles {
  static const names = [
    'Slate & Shell',
    'Inkstone',
    'Jade',
    'Rosewood',
    'Cinnabar',
    'Porcelain',
    'Bronze',
    'Obsidian',
    'Bamboo',
    'Lapis',
  ];
  static const descriptions = [
    'Glossy black slate, creamy clamshell white',
    'Matte carved inkstone, warm paper white',
    'Deep green jade, pale celadon',
    'Polished rosewood, light beech',
    'Cinnabar red-black, ivory white',
    'Blue-white porcelain, ink black',
    'Aged bronze, brushed bone',
    'Mirror obsidian, moonstone white',
    'Honey bamboo, dark smoked bamboo',
    'Midnight lapis, silvered white',
  ];

  /// [base, sheen] color pairs per style: index 0 = black stone, 1 = white.
  static const List<List<List<Color>>> pairs = [
    [
      [Color(0xFF23211E), Color(0xFF5A564E)], // Slate & Shell / black
      [Color(0xFFF2EAD6), Color(0xFFFFFFFF)], // white
    ],
    [
      [Color(0xFF2E2C28), Color(0xFF4E4A44)],
      [Color(0xFFEFE6D2), Color(0xFFFDF8EC)],
    ],
    [
      [Color(0xFF1F4A3A), Color(0xFF4E8A6E)],
      [Color(0xFFDCE8D8), Color(0xFFF4FAF2)],
    ],
    [
      [Color(0xFF4A2418), Color(0xFF8A4E38)],
      [Color(0xFFE8D2AC), Color(0xFFFFF0D2)],
    ],
    [
      [Color(0xFF6E1F14), Color(0xFFB05038)],
      [Color(0xFFF6F0E0), Color(0xFFFFFFFF)],
    ],
    [
      [Color(0xFF1E2E3E), Color(0xFF4E6E8A)],
      [Color(0xFFF0F2F0), Color(0xFFFFFFFF)],
    ],
    [
      [Color(0xFF5E4A24), Color(0xFFA88A52)],
      [Color(0xFFE4D6B8), Color(0xFFFAF0DC)],
    ],
    [
      [Color(0xFF101014), Color(0xFF3E3E4E)],
      [Color(0xFFD8DCE2), Color(0xFFF6F8FC)],
    ],
    [
      [Color(0xFF4E3A1E), Color(0xFF8A6E42)],
      [Color(0xFFD9B06E), Color(0xFFF2DCA8)],
    ],
    [
      [Color(0xFF1A2E5E), Color(0xFF3E5E9E)],
      [Color(0xFFE8E4D8), Color(0xFFFDFBF2)],
    ],
  ];

  /// Styles free players may use.
  static const freeCount = 4;
  static bool isPro(int index) => index >= freeCount;
}

/// Last-move marker styles (board accents). 0-2 = FREE, 3+ = PRO.
class MarkerStyles {
  static const names = [
    'Seal Dot',
    'Brush Ring',
    'Corner Ticks',
    'Gold Ring',
    'Ink Cross',
    'Jade Dot',
  ];
  static const descriptions = [
    'Small vermilion seal dot',
    'Hand-brushed ink ring',
    'Four corner ticks',
    'Thin gold ring',
    'Ink brush cross',
    'Pale jade dot',
  ];

  static const freeCount = 3;
  static bool isPro(int index) => index >= freeCount;
}
