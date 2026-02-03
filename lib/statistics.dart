import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
//import 'package:flutter_app/widgets/question_tile.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'egzamin_podglad.dart';
//import 'admin_stats.dart';

import 'utils/helpers.dart';

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

              List<Widget> mainStatsWidgets = [];
              for (int rowIndex = 0; rowIndex < rowCount; rowIndex++) {
                final startIndex = rowIndex * crossAxisCount;
                final endIndex = (startIndex + crossAxisCount).clamp(
                  0,
                  entries.length,
                );
                final rowEntries = entries.sublist(startIndex, endIndex);

                mainStatsWidgets.add(
                  Padding(
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
                  ),
                );
              }

              Widget lastExamsWidget = FutureBuilder<List<dynamic>>(
                future: fetchUserExams(),
                builder: (context, snapshot2) {
                  if (snapshot2.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot2.hasData || snapshot2.data!.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text('Brak zapisanych egzaminów użytkownika.'),
                    );
                  }

                  final exams = snapshot2.data!;
                  final Map<String, List<dynamic>> examsByQual = {};
                  for (final exam in exams) {
                    final qual = exam['kwalifikacja'] ?? 'Nieznana';
                    examsByQual.putIfAbsent(qual, () => []).add(exam);
                  }

                  return Column(
                    children:
                        examsByQual.entries.map((entry) {
                          return LastExamCard(
                            title: entry.key,
                            exams: entry.value.cast(),
                          );
                        }).toList(),
                  );
                },
              );

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...mainStatsWidgets,
                  const SizedBox(height: 30),
                  const Text(
                    '📘 Ostatnie egzaminy',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  lastExamsWidget,
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<List<dynamic>> fetchUserExams() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('userName') ?? 'anonymous';
    if (userName == 'anonymous') return [];

    final response = await http.post(
      Uri.parse('$apiBaseUrl/stats_all.php'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200) return [];

    final jsonData = jsonDecode(response.body);
    if (jsonData is! List) return [];

    final exams =
        jsonData.where((e) => (e['userID'] ?? '') == userName).toList();

    exams.sort((a, b) {
      final da = DateTime.tryParse(a['data_czas'] ?? '') ?? DateTime(2000);
      final db = DateTime.tryParse(b['data_czas'] ?? '') ?? DateTime(2000);
      return db.compareTo(da);
    });

    return exams;
  }

  Future<Map<String, dynamic>> fetchStatistics() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('userName') ?? 'anonymous';

    if (userName == 'anonymous') {
      throw Exception('ℹ️ Funkcja statystyk wymaga zalogowania.');
    }

    final url = Uri.parse('$apiBaseUrl/stats.php');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Bearer $apiKey',
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

class LastExamCard extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> exams;

  const LastExamCard({super.key, required this.title, required this.exams});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withValues(alpha: 0.85),
                colorScheme.primary.withValues(alpha: 0.5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              collapsedBackgroundColor: Colors.transparent,
              title: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      Icons.school_rounded,
                      color: colorScheme.onPrimary,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    children:
                        exams.asMap().entries.map((e) {
                          final index = e.key;
                          final exam = e.value;

                          return LastExamRow(
                            exam: exam,
                            showBorder: index != exams.length - 1,
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LastExamRow extends StatelessWidget {
  final Map<String, dynamic> exam;
  final bool showBorder;

  const LastExamRow({super.key, required this.exam, required this.showBorder});
  String _fmtDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '-';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // pełna data+czas z bazy (np. "2025-12-04 08:15:45")
    final fullDateTime = (exam['data_czas'] ?? '') as String;

    // tylko data do wyświetlenia
    final date = fullDateTime.split(' ').first;

    final wynikRaw = exam['wynik']?.toString() ?? '';
    final wynikDouble = double.tryParse(wynikRaw);

    String wynik;
    if (wynikDouble == null) {
      wynik = '-';
    } else {
      wynik =
          (wynikDouble % 1 == 0)
              ? wynikDouble.toInt().toString()
              : wynikDouble.toStringAsFixed(1);
    }

    // surowe sekundy z bazy
    final int durationSec =
        (exam['czas_trwania_sec'] is int)
            ? exam['czas_trwania_sec'] as int
            : int.tryParse('${exam['czas_trwania_sec'] ?? '0'}') ?? 0;

    // ładny tekst do wyświetlenia
    final czas = _fmtDuration(durationSec);

    final examId = int.tryParse(exam['id']?.toString() ?? '') ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border:
            showBorder
                ? Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
                )
                : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$date — wynik: $wynik%",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Czas trwania: $czas',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),

          ElevatedButton(
            onPressed:
                examId == 0
                    ? null
                    : () async {
                      final data = await fetchExamDetailsFull(
                        examId,
                        fullDateTime,
                        durationSec,
                      );
                      if (!context.mounted) return;

                      if (data != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => EgzaminPodgladView(
                                  questions: data['questions'],
                                  selectedAnswers:
                                      (data['selectedAnswers']).cast<String?>(),
                                ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Nie udało się wczytać podglądu."),
                          ),
                        );
                      }
                    },
            child: const Text("Podgląd"),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> fetchExamDetailsFull(
    int examId,
    String examDateTime,
    int durationSec,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/podgladEgzaminu_user.php'),
        body: {
          'api_token': apiKey,
          'exam_id': examId.toString(),
          'exam_date': examDateTime,
          'duration_sec': durationSec.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'questions': List<dynamic>.from(data['questions']),
            'selectedAnswers':
                (data['selectedAnswers'] as List).cast<String?>(),
          };
        }
      }
      if (kDebugMode) {
        debugPrint('Błąd PHP: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Błąd podczas pobierania danych egzaminu: $e');
      }
    }
    return null;
  }
}
