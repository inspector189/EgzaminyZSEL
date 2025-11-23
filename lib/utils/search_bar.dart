import 'package:flutter/material.dart'
    show
        StatelessWidget,
        ValueChanged,
        BuildContext,
        Widget,
        Icon,
        Theme,
        Icons,
        BorderRadius,
        BorderSide,
        OutlineInputBorder,
        InputDecoration,
        TextField;

class SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const SearchBar({super.key, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fill =
        theme.inputDecorationTheme.fillColor ??
        colorScheme.surfaceContainerHighest;
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: 'Wyszukaj użytkownika..',
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
