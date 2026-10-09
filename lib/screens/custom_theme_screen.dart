import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/scholar.dart';
import '../theme/scholar_themes.dart';

/// PRO: custom theme creator — pick paper, wood, ink and seal colors.
/// Live preview, persisted per color.
class CustomThemeScreen extends StatefulWidget {
  final ScholarAudio audio;
  final GomokuSettings settings;

  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  ScholarThemeDef get _t => ScholarThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  // Curated scholar-friendly palette choices.
  static const List<Color> palette = [
    Color(0xFFF3EAD3), Color(0xFFFEF9EF), Color(0xFFF6EFDD),
    Color(0xFFEDEAE2), Color(0xFFF1EDD8), Color(0xFFF0E6CE),
    Color(0xFF24211D), Color(0xFF837469), Color(0xFF2E2620),
    Color(0xFF232B3A), Color(0xFF1E1B18), Color(0xFF33222A),
    Color(0xFFC89B5A), Color(0xFF8B5A2B), Color(0xFF6F4315),
    Color(0xFF7C3F24), Color(0xFF5A2A1A), Color(0xFF9A7440),
    Color(0xFFD4AC72), Color(0xFFA5713D), Color(0xFF4A3A28),
    Color(0xFFC23B22), Color(0xFFB02E16), Color(0xFFB8860B),
    Color(0xFF3E6B3A), Color(0xFF2E5A88), Color(0xFF8E3B52),
    Color(0xFF4A4A4A), Color(0xFF7A5A2E), Color(0xFFC9A86A),
    Color(0xFFD9B06E), Color(0xFFB98D55), Color(0xFF9A7A5E),
    Color(0xFF2E3850), Color(0xFF1A2E5E), Color(0xFF1F4A3A),
  ];

  static const rows = [
    ('Rice paper', 'paper'),
    ('Washi card', 'paperCard'),
    ('Ink text', 'inkText'),
    ('Soft ink', 'inkSoft'),
    ('Wood light', 'woodLight'),
    ('Wood mid', 'woodMid'),
    ('Wood deep', 'woodDeep'),
    ('Grid ink', 'gridLine'),
    ('Seal accent', 'accent'),
    ('Seal deep', 'accentDeep'),
  ];

  Future<void> _pick(String key, String label) async {
    final s = widget.settings;
    final current = Color(s.customColors[key]!);
    final chosen = await showDialog<Color>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _t.paperCard,
            border: Border.all(color: _t.accent, width: 2.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pick $label', style: Scholar.display(20, theme: _t)),
              const SizedBox(height: 14),
              SizedBox(
                width: 300,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: palette.length,
                  itemBuilder: (_, i) {
                    final c = palette[i];
                    final selected =
                        c.toARGB32() == current.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        widget.audio.click();
                        Navigator.of(context).pop(c);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c,
                          border: Border.all(
                            color: selected
                                ? _t.accent
                                : Colors.black.withValues(alpha: 0.3),
                            width: selected ? 3 : 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              WoodButton(
                label: 'Cancel',
                width: 160,
                fontSize: 15,
                theme: _t,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null && mounted) {
      widget.audio.click();
      await s.setCustomColor(key, chosen.toARGB32());
      // Selecting a custom color auto-applies the custom theme.
      await s.setTheme('custom');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final preview = s.customTheme;
    return PaperBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.inkText),
            onPressed: () {
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
          title:
              Text('Theme Creator', style: Scholar.display(22, theme: t)),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: () async {
                widget.audio.click();
                await s.resetCustomColors();
                if (mounted) setState(() {});
              },
              child:
                  Text('Reset', style: Scholar.label(13, theme: t)),
            ),
          ],
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: Column(
                children: [
                  // Live preview strip.
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: preview.paperCard,
                      border: Border.all(
                          color: preview.accent, width: 2),
                    ),
                    child: Column(
                      children: [
                        Text('Live preview',
                            style: Scholar.label(13, theme: preview)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceEvenly,
                          children: [
                            _previewStone(preview, 1),
                            _previewStone(preview, 2),
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: LinearGradient(colors: [
                                  preview.woodLight,
                                  preview.woodDeep,
                                ]),
                                border: Border.all(
                                    color: preview.accent,
                                    width: 2),
                              ),
                              child: Center(
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: preview.accent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('The quick brown fox',
                            style: Scholar.body(14, theme: preview)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final r in rows)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 5),
                      child: GestureDetector(
                        onTap: () => _pick(r.$2, r.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: t.paperCard,
                            border: Border.all(
                                color: t.woodMid.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(
                                      s.customColors[r.$2]!),
                                  border: Border.all(
                                      color: t.accent,
                                      width: 1.5),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(r.$1,
                                    style:
                                        Scholar.body(15, theme: t)),
                              ),
                              Icon(Icons.palette,
                                  color: t.accent, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  WoodButton(
                    label: 'Use This Theme',
                    width: 260,
                    theme: t,
                    primary: true,
                    onTap: () async {
                      widget.audio.click();
                      await s.setTheme('custom');
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewStone(ScholarThemeDef p, int color) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.35),
          colors: color == 1
              ? [const Color(0xFF5A564E), const Color(0xFF23211E)]
              : [Colors.white, const Color(0xFFF2EAD6)],
        ),
        border:
            Border.all(color: Colors.black.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            offset: const Offset(0, 3),
            blurRadius: 5,
          ),
        ],
      ),
    );
  }
}
