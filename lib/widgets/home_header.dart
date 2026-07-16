import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  final String selectedQuote;

  const HomeHeader({super.key, required this.selectedQuote});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        Text(
          'Witamy w aplikacji Egzaminy!',
          style: tt.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Przygotuj się do egzaminu zawodowego z najlepszą bazą pytań!'
          ' Poniżej znajdziesz kwalifikacje, które możesz przeglądać:',
          style: tt.bodyLarge?.copyWith(color: cs.onSurface),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.format_quote_rounded, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              selectedQuote,
              style: tt.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }
}
