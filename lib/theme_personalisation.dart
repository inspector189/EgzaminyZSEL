import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'utils/theme_manager.dart';

const _kSwatches = [
  _Swatch('Czerwony', Color(0xFFE53935), Color(0xFFFF5252)),
  _Swatch('Niebieski', Color(0xFF1E88E5), Color(0xFF448AFF)),
  _Swatch('Zielony', Color(0xFF43A047), Color(0xFF69F0AE)),
  _Swatch('Pomarańcz', Color(0xFFFB8C00), Color(0xFFFFAB40)),
  _Swatch('Fioletowy', Color(0xFF8E24AA), Color(0xFFE040FB)),
  _Swatch('Morski', Color(0xFF00897B), Color(0xFF64FFDA)),
  _Swatch('Różowy', Color(0xFFD81B60), Color(0xFFFF80AB)),
  _Swatch('Indygo', Color(0xFF3949AB), Color(0xFF536DFE)),
  _Swatch('Brązowy', Color(0xFF6D4C41), Color(0xFFFF8A65)),
];

class _Swatch {
  final String name;
  final Color primary;
  final Color secondary;
  const _Swatch(this.name, this.primary, this.secondary);
}

class PersonalisationPage extends StatelessWidget {
  const PersonalisationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = Provider.of<ThemeProvider>(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final width = MediaQuery.of(context).size.width;
    final hPad = width < 600 ? 20.0 : 32.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalizacja'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        iconTheme: IconThemeData(color: cs.onPrimary),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _SectionLabel(label: 'Kolor akcentu', cs: cs, tt: tt),
            const SizedBox(height: 16),

            Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children:
                  _kSwatches.map((swatch) {
                    final isSelected =
                        tp.primaryColor.toARGB32() == swatch.primary.toARGB32();
                    return _SwatchTile(
                      swatch: swatch,
                      isSelected: isSelected,
                      onTap:
                          () => tp.setAccentColor(
                            swatch.primary,
                            swatch.secondary,
                          ),
                    );
                  }).toList(),
            ),

            const SizedBox(height: 36),

            _SectionLabel(label: 'Motyw', cs: cs, tt: tt),
            const SizedBox(height: 14),

            _ThemeModePicker(tp: tp, cs: cs, tt: tt),

            const SizedBox(height: 36),

            _SectionLabel(label: 'Podgląd', cs: cs, tt: tt),
            const SizedBox(height: 14),

            _PreviewCard(cs: cs, tt: tt),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//                 Section label
// ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.cs,
    required this.tt,
  });
  final String label;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: tt.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//            Colour swatch tile
// ─────────────────────────────────────────────

class _SwatchTile extends StatelessWidget {
  const _SwatchTile({
    required this.swatch,
    required this.isSelected,
    required this.onTap,
  });
  final _Swatch swatch;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      label: swatch.name,
      selected: isSelected,
      button: true,
      child: Tooltip(
        message: swatch.name,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          tween: Tween<double>(begin: 1.0, end: isSelected ? 1.15 : 1.0),
          builder:
              (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
          child: GestureDetector(
            onTap: onTap,
            child: SizedBox(
              width: 140,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      color: swatch.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: swatch.primary.withValues(
                            alpha: isSelected ? 0.60 : 0.22,
                          ),
                          blurRadius: isSelected ? 22 : 8,
                          spreadRadius: isSelected ? 3 : 0,
                        ),
                      ],
                    ),
                    child:
                        isSelected
                            ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 26,
                            )
                            : null,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    swatch.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelSmall?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? cs.primary : cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//            Theme mode picker
// ─────────────────────────────────────────────

class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker({
    required this.tp,
    required this.cs,
    required this.tt,
  });
  final ThemeProvider tp;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ModeOption(
          icon: Icons.wb_sunny_rounded,
          label: 'Jasny',
          selected: tp.themeMode == ThemeMode.light,
          cs: cs,
          tt: tt,
          onTap: () => tp.setTheme(ThemeMode.light),
        ),
        const SizedBox(width: 12),
        _ModeOption(
          icon: Icons.nightlight_round,
          label: 'Ciemny',
          selected: tp.themeMode == ThemeMode.dark,
          cs: cs,
          tt: tt,
          onTap: () => tp.setTheme(ThemeMode.dark),
        ),
        const SizedBox(width: 12),
        _ModeOption(
          icon: Icons.brightness_auto_rounded,
          label: 'Systemowy',
          selected: tp.themeMode == ThemeMode.system,
          cs: cs,
          tt: tt,
          onTap: () => tp.setTheme(ThemeMode.system),
        ),
      ],
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.cs,
    required this.tt,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color:
                selected
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  selected
                      ? cs.primary.withValues(alpha: 0.5)
                      : cs.outlineVariant.withValues(alpha: 0.4),
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: tt.labelSmall?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Preview card
// ─────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 72,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.school_rounded,
                  size: 20,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Przykładowa karta',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Opis w kolorze pomocniczym',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Łatwe',
                    style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Przyciski i oznaczenia',
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Wypełniony'),
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Obrysowany'),
                  ),
                  TextButton(onPressed: () {}, child: const Text('Tekstowy')),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  _Pill('Główny', cs.primaryContainer, cs.onPrimaryContainer),
                  _Pill(
                    'Drugorzędny',
                    cs.secondaryContainer,
                    cs.onSecondaryContainer,
                  ),
                  _Pill(
                    'Trzeciorzędny',
                    cs.tertiaryContainer,
                    cs.onTertiaryContainer,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
