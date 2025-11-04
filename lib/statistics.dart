import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('📊 Statystyki'), elevation: 2),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchStatistics(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('❌ Błąd: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Brak danych statystycznych.'));
          }

          final stats = snapshot.data!;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final cardWidth =
                  isWide
                      ? (constraints.maxWidth / 2) - 24
                      : constraints.maxWidth;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children:
                          stats.entries.map((qualificationEntry) {
                            final statEntries =
                                qualificationEntry.value.entries.toList();

                            return SizedBox(
                              width: cardWidth,
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(16),
                                            ),
                                        gradient: LinearGradient(
                                          colors: [
                                            colorScheme.primary.withValues(
                                              alpha: 0.85,
                                            ),
                                            colorScheme.primary.withValues(
                                              alpha: 0.5,
                                            ),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.school_rounded,
                                            color: colorScheme.onPrimary,
                                            size: 30,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            qualificationEntry.key,
                                            style: theme.textTheme.titleLarge
                                                ?.copyWith(
                                                  color: colorScheme.onPrimary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: List.generate(
                                          statEntries.length,
                                          (i) {
                                            final entry = statEntries[i];
                                            return _StatRow(
                                              label: entry.key,
                                              value: entry.value.toString(),
                                              isLast:
                                                  i == statEntries.length - 1,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
              );
            },
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

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _StatRow({
    required this.label,
    required this.value,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        border:
            isLast
                ? null
                : Border(
                  bottom: BorderSide(
                    color: colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
                ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
