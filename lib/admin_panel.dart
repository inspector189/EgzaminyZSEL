import 'package:flutter/material.dart';

class AdminPanelPage extends StatelessWidget {
  final bool isDarkMode;

  const AdminPanelPage({super.key, this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Administratora'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Witaj w panelu administratora',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tutaj możesz zarządzać aplikacją, np. dodawać pytania, '
            'przeglądać statystyki użytkowników albo sprawdzać logi.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 32),

          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.people),
            label: const Text('Zarządzaj użytkownikami'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Funkcja w przygotowaniu 🚧')),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.bar_chart),
            label: const Text('Raporty i statystyki'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Funkcja w przygotowaniu 🚧')),
              );
            },
          ),
        ],
      ),
    );
  }
}
