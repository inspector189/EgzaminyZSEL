import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statystyki'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchStatistics(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Błąd: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('❌ Brak danych statystycznych.'));
          }

          final stats = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const Text(
                'Statystyki użytkownika',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ...stats.entries.map((qualificationEntry) {
                final entries = qualificationEntry.value.entries.toList();
                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kwalifikacja: ${qualificationEntry.key}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(entries.length, (index) {
                          final statEntry = entries[index];
                          final isEven = index % 2 == 0;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isEven
                                      ? Theme.of(context).colorScheme.surface
                                          .withValues(alpha: 0.05)
                                      : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  statEntry.key,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                Text(
                                  statEntry.value.toString(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> fetchStatistics() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('userName') ?? 'anonymous';

    if (userName == 'anonymous') {
      throw Exception('ℹ️ Funkcja statystyk wymaga zalogowania.');
    }

    final url = Uri.parse('https://interpage.pl/egzaminy/stats.php');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Bearer zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^',
      },
      body: {'userName': userName},
    );

    if (kDebugMode) {
      debugPrint('📥 Otrzymano odpowiedź od serwera: ${response.statusCode}');
      debugPrint('Treść odpowiedzi: ${response.body}');
    }

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data.containsKey('error')) {
        throw Exception(data['error']);
      }
      return data;
    } else if (response.statusCode == 404) {
      throw Exception('⚠️ Nie zrobiłeś jeszcze żadnego egzaminu!');
    } else {
      throw Exception(
        '❌ Nie udało się pobrać statystyk: ${response.statusCode} - ${response.body}',
      );
    }
  }
}
