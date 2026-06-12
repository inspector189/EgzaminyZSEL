import 'package:flutter/material.dart';

class SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final VoidCallback? onTap;

  const SearchBar({super.key, required this.onChanged, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fill =
        theme.inputDecorationTheme.fillColor ??
        colorScheme.surfaceContainerHighest;

    return TextField(
      onChanged: onChanged,
      onTap: onTap,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: 'Wyszukaj użytkownika...',
        filled: true,
        fillColor: fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
