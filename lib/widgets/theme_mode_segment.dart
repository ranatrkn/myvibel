// Koyu/açık tema seçim segmenti.
import 'package:flutter/material.dart';
import 'package:vibe_life/app_theme.dart';
import 'package:vibe_life/theme_controller.dart';

// Ayarlardaki görünüm (tema) seçici
class ThemeModeSegment extends StatelessWidget {
  const ThemeModeSegment({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final controller = ThemeScope.of(context);
    final selected = controller.appearance;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.palette_outlined,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                'Görünüm',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: vibe.isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: vibe.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SegmentOption(
                    label: 'Koyu',
                    icon: Icons.dark_mode_outlined,
                    selected: selected == VibeAppearance.dark,
                    onTap: () =>
                        controller.setAppearance(VibeAppearance.dark),
                  ),
                ),
                Expanded(
                  child: _SegmentOption(
                    label: 'Açık',
                    icon: Icons.light_mode_outlined,
                    selected: selected == VibeAppearance.light,
                    onTap: () =>
                        controller.setAppearance(VibeAppearance.light),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Tek segment butonu
class _SegmentOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;

    return Material(
      color: selected ? vibe.primaryButton : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : vibe.mutedText,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : vibe.mutedText,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
