import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/services/api_service.dart';
import 'exam_preview.dart';
import 'utils/async_state_view.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  late final Future<Map<String, dynamic>> _statsFuture = ApiService.instance
      .fetchUserStats()
      .then((result) {
        if (result.isSuccess) return result.data!;
        if (result.isNotFound) {
          throw Exception('⚠️ Nie zrobiłeś(aś) jeszcze żadnego egzaminu!');
        } else {
          throw Exception('Wystąpił wewnętrzny błąd: ${result.errorMessage}');
        }
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('📊 Statystyki'), elevation: 2),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return AsyncStateView.loading(subtitle: 'Pobieranie statystyk...');
          }
          if (snapshot.hasError) {
            return AsyncStateView.error(
              message: 'Błąd ładowania',
              subtitle: snapshot.error.toString(),
            );
          }

          final data = snapshot.data!;
          final stats = data['stats'] as Map<String, dynamic>? ?? {};
          final exams = data['exams'] as List<dynamic>? ?? [];

          if (stats.isEmpty && exams.isEmpty) {
            return AsyncStateView.empty(
              message: 'Brak danych statystycznych',
              icon: Icons.bar_chart_outlined,
            );
          }

          // Group exams by qualification
          final Map<String, List<dynamic>> examsByQual = {};
          for (final exam in exams) {
            final qual = (exam['kwalifikacja'] ?? 'Nieznana') as String;
            examsByQual.putIfAbsent(qual, () => []).add(exam);
          }

          final entries = stats.entries.toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              const maxCardWidth = 350;
              final crossAxisCount = entries.isEmpty
                  ? 1
                  : (constraints.maxWidth / maxCardWidth).floor().clamp(
                      1,
                      entries.length,
                    );
              final rowCount = entries.isEmpty
                  ? 0
                  : (entries.length / crossAxisCount).ceil();

              final mainStatsWidgets = <Widget>[
                for (int rowIndex = 0; rowIndex < rowCount; rowIndex++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Builder(
                      builder: (context) {
                        final startIndex = rowIndex * crossAxisCount;
                        final endIndex = (startIndex + crossAxisCount).clamp(
                          0,
                          entries.length,
                        );
                        final rowEntries = entries.sublist(
                          startIndex,
                          endIndex,
                        );

                        return Row(
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
                        );
                      },
                    ),
                  ),
              ];

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
                  if (exams.isEmpty)
                    AsyncStateView.empty(
                      message: 'Brak zapisanych egzaminów',
                      subtitle: 'Nie zrobiłeś(aś) jeszcze żadnego egzaminu.',
                      icon: Icons.assignment_outlined,
                    )
                  else
                    ...examsByQual.entries.map(
                      (entry) => LastExamCard(
                        title: entry.key,
                        exams: entry.value.cast(),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
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
        border: isLast
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
                    children: exams.asMap().entries.map((e) {
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

    // (np. "2025-12-04 08:15:45")
    final fullDateTime = (exam['data_czas'] ?? '') as String;

    final date = fullDateTime.split(' ').first;

    final wynikRaw = exam['wynik']?.toString() ?? '';
    final wynikDouble = double.tryParse(wynikRaw);

    String wynik;
    if (wynikDouble == null) {
      wynik = '-';
    } else {
      wynik = (wynikDouble % 1 == 0)
          ? wynikDouble.toInt().toString()
          : wynikDouble.toStringAsFixed(1);
    }

    final int durationSec = (exam['czas_trwania_sec'] is int)
        ? exam['czas_trwania_sec'] as int
        : int.tryParse('${exam['czas_trwania_sec'] ?? '0'}') ?? 0;

    final czas = _fmtDuration(durationSec);

    final examId = int.tryParse(exam['id']?.toString() ?? '') ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: showBorder
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
            onPressed: examId == 0
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
                          builder: (_) => EgzaminPodgladView(
                            questions: data['questions'],
                            selectedAnswers: (data['selectedAnswers'])
                                .cast<String?>(),
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
      final result = await ApiService.instance.fetchExamPreviewUser(
        examId: examId,
        examDateTime: examDateTime,
        durationSec: durationSec,
      );

      if (result.isSuccess) {
        return {
          'questions': List<dynamic>.from(result.data!['questions']),
          'selectedAnswers': (result.data!['selectedAnswers'] as List)
              .cast<String?>(),
        };
      }
      if (kDebugMode) {
        debugPrint(
          'Wystąpił błąd podczas pobierania danych egzaminu: ${result.statusCode}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Wystąpił wewnętrzny błąd: $e');
      }
    }
    return null;
  }
}
