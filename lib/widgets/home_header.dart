import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  final String selectedQuote;

  const HomeHeader({super.key, required this.selectedQuote});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Witamy w aplikacji Egzaminy! 👋',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Przygotuj się do egzaminu zawodowego z najlepszą bazą pytań! Poniżej znajdziesz kwalifikacje, które możesz przeglądać:',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Text(
          '💬 $selectedQuote',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            fontSize: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
