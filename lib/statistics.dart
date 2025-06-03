import 'package:flutter/material.dart';

class StatisticsPage extends StatelessWidget {
  final String qualification;
  final bool isDarkMode;

  const StatisticsPage({
    super.key,
    required this.qualification,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Statystyki - $qualification'),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.blue,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchStatistics(qualification),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Błąd: ${snapshot.error}'),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Brak danych statystycznych.'));
          }

          final stats = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Text(
                'Statystyki dla kwalifikacji $qualification',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              ...stats.entries.map((entry) {
                return ListTile(
                  title: Text(entry.key),
                  trailing: Text(entry.value.toString()),
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> fetchStatistics(String qualification) async {
    // Symulacja pobierania danych statystycznych z API
    await Future.delayed(const Duration(seconds: 2)); // Symulacja opóźnienia
    return {
      'Liczba pytań': 120,
      'Średni wynik': '75%',
      'Najlepszy wynik': '100%',
      'Najgorszy wynik': '50%',
    };
  }
}