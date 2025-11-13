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
          final entries = stats.entries.toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              const maxCardWidth = 350;
              final crossAxisCount = (constraints.maxWidth / maxCardWidth)
                  .floor()
                  .clamp(1, entries.length);

              final rowCount = (entries.length / crossAxisCount).ceil();

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: rowCount,
                itemBuilder: (context, rowIndex) {
                  final startIndex = rowIndex * crossAxisCount;
                  final endIndex = (startIndex + crossAxisCount).clamp(
                    0,
                    entries.length,
                  );
                  final rowEntries = entries.sublist(startIndex, endIndex);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < rowEntries.length; i++) ...[
                          Expanded(
                            child: StatCard(
                              entry: rowEntries[i],
                              colorScheme: colorScheme,
                              theme: theme,
                            ),
                          ),
                          if (i != rowEntries.length - 1)
                            const SizedBox(width: 16),
                        ],
                      ],
                    ),
                  );
                },
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
    try {
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (data is Map<String, dynamic>) {
          if (data.containsKey('error')) throw Exception(data['error']);
          return data;
        } else {
          throw Exception('❌ Format odpowiedzi jest niepoprawny!');
        }
      } else if (response.statusCode == 404) {
        throw Exception('⚠️ Nie zrobiłeś(aś) jeszcze żadnego egzaminu!');
      } else {
        throw Exception('❌ ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('❌ Błąd pobierania statystyk: $e');
    }
  }
}

class StatCard extends StatelessWidget {
  final MapEntry<String, dynamic> entry;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const StatCard({
    required this.entry,
    required this.colorScheme,
    required this.theme,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final statEntries = (entry.value as Map<String, dynamic>).entries.toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withValues(alpha: 0.85),
                  colorScheme.primary.withValues(alpha: 0.5),
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
                Flexible(
                  child: Text(
                    entry.key,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(statEntries.length, (i) {
                final stat = statEntries[i];
                return _StatRow(
                  label: stat.key,
                  value: stat.value.toString(),
                  isLast: i == statEntries.length - 1,
                );
              }),
            ),
          ),
        ],
      ),
    );
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
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
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
