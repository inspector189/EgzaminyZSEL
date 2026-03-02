import 'dart:async' show Timer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/exam_preview.dart';
import 'package:flutter_app/services/api_service.dart';
import 'report_selection.dart';
import 'widgets/search_bar.dart' as search_bar;

class AdminStatsPage extends StatefulWidget {
  const AdminStatsPage({super.key});

  @override
  State<AdminStatsPage> createState() => _AdminStatsPageState();
}

class _AdminStatsPageState extends State<AdminStatsPage> {
  List<dynamic> allResults = [];
  bool isLoading = true;
  String? errorMessage;
  String searchQuery = '';
  DateTime? startDate;
  DateTime? endDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String? selectedQualification;
  bool _studentsExpanded = false;
  Timer? _searchDebounce;
  List<dynamic> _filteredResults = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  Map<String, List<dynamic>> _qualifications = {};
  List<String> _allQualificationKeys = [];

  @override
  void initState() {
    super.initState();
    fetchAllStats();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> fetchAllStats() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final result = await ApiService.instance.fetchAllStats();
      if (result.isSuccess) {
        final data = result.data!;
        allResults = data;
        isLoading = false;
        errorMessage = null;
        _recompute();
      } else {
        throw Exception('❌ Kod błędu HTTP: ${result.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _recompute() {
    final filteredResults =
        allResults.where((exam) {
          final examDate = DateTime.tryParse(exam['data_czas'] ?? '');
          if (examDate == null) return false;

          final afterStartDate =
              startDate == null ||
              examDate.isAfter(startDate!.subtract(const Duration(days: 1)));
          final beforeEndDate =
              endDate == null ||
              examDate.isBefore(endDate!.add(const Duration(days: 1)));
          final afterStartTime =
              startTime == null ||
              (examDate.hour > startTime!.hour ||
                  (examDate.hour == startTime!.hour &&
                      examDate.minute >= startTime!.minute));
          final beforeEndTime =
              endTime == null ||
              (examDate.hour < endTime!.hour ||
                  (examDate.hour == endTime!.hour &&
                      examDate.minute <= endTime!.minute));
          final matchesQualification =
              selectedQualification == null ||
              (exam['kwalifikacja'] ?? '').toString() == selectedQualification;

          return afterStartDate &&
              beforeEndDate &&
              afterStartTime &&
              beforeEndTime &&
              matchesQualification;
        }).toList();

    final Map<String, List<dynamic>> usersByUid = {};
    for (final exam in filteredResults) {
      String uid = (exam['UID'] ?? '').toString().trim();
      String name = (exam['userID'] ?? '').toString().trim();
      if (name.isEmpty || name.toLowerCase() == 'anonymous') {
        name = 'Użytkownik anonimowy';
      }
      final key = uid.isNotEmpty ? uid : name;
      usersByUid.putIfAbsent(key, () => []).add(exam);
    }

    final filteredUsers =
        usersByUid.entries
            .map((entry) {
              final exams = entry.value;
              final first = exams.first;
              String name = (first['userID'] ?? '').toString().trim();
              if (name.isEmpty || name.toLowerCase() == 'anonymous') {
                name = 'Użytkownik anonimowy';
              }
              final uid = (first['UID'] ?? '').toString().trim();
              return {'name': name, 'uid': uid, 'exams': exams};
            })
            .where((u) {
              final q = searchQuery.toLowerCase();
              return u['name'].toString().toLowerCase().contains(q) ||
                  u['uid'].toString().toLowerCase().contains(q);
            })
            .toList()
          ..sort((a, b) {
            if (a['name'] == 'Użytkownik anonimowy') return 1;
            if (b['name'] == 'Użytkownik anonimowy') return -1;
            return a['name'].toString().compareTo(b['name'].toString());
          });

    final qualifications = <String, List<dynamic>>{};
    for (final r in filteredResults) {
      final q = (r['kwalifikacja'] ?? '').toString().trim();
      if (isValidQualification(q)) {
        qualifications.putIfAbsent(q, () => []).add(r);
      }
    }

    setState(() {
      _filteredResults = filteredResults;
      _filteredUsers = filteredUsers;
      _qualifications = qualifications;
      _allQualificationKeys =
          allResults
              .map((r) => (r['kwalifikacja'] ?? 'Nieznana').toString())
              .toSet()
              .toList();
    });
  }

  String _fmtDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '-';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }

  Map<String, dynamic> calculateStats(List<dynamic> results) {
    if (results.isEmpty) return {'count': 0, 'avg': 0.0, 'best': 0, 'worst': 0};
    final scores =
        results.map<double>((e) {
          final raw = e['wynik'];
          if (raw is num) return raw.toDouble();
          return double.tryParse('$raw') ?? 0.0;
        }).toList();
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    final best = scores.reduce((a, b) => a > b ? a : b);
    final worst = scores.reduce((a, b) => a < b ? a : b);
    return {'count': scores.length, 'avg': avg, 'best': best, 'worst': worst};
  }

  String formatTimeOfDay24(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('📊 Statystyki Egzaminów')),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : RefreshIndicator(
                onRefresh: fetchAllStats,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    search_bar.SearchBar(
                      onChanged: (value) {
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 200),
                          () {
                            searchQuery = value;
                            if (value.isNotEmpty) _studentsExpanded = true;
                            _recompute();
                          },
                        );
                      },
                      onTap: () {
                        setState(() {
                          _studentsExpanded = true;
                        });
                      },
                    ),

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(
                          Icons.person_2,
                          color: colorScheme.primary,
                          size: 32,
                        ),
                        const SizedBox(width: 8),
                        const _SectionTitle('Statystyki według użytkownika'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            hoverColor: colorScheme.secondary.withValues(
                              alpha: 0.05,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: startDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                startDate = picked;
                                _studentsExpanded = true;
                                _recompute();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: colorScheme.secondary,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.date_range,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    startDate == null
                                        ? 'Data od'
                                        : 'Od: ${startDate!.toLocal().toString().split(' ')[0]}',
                                    style: theme.textTheme.bodyMedium!.copyWith(
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            hoverColor: colorScheme.secondary.withValues(
                              alpha: 0.05,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: endDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                endDate = picked;
                                _studentsExpanded = true;
                                _recompute();
                              }
                            },

                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: colorScheme.secondary,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.date_range,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    endDate == null
                                        ? 'Data do'
                                        : 'Do: ${endDate!.toLocal().toString().split(' ')[0]}',
                                    style: theme.textTheme.bodyMedium!.copyWith(
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime:
                                    startTime ??
                                    const TimeOfDay(hour: 0, minute: 0),
                                builder: (BuildContext context, Widget? child) {
                                  return MediaQuery(
                                    data: MediaQuery.of(
                                      context,
                                    ).copyWith(alwaysUse24HourFormat: true),
                                    child: child!,
                                  );
                                },
                                initialEntryMode: TimePickerEntryMode.input,
                              );
                              if (picked != null) {
                                startTime = picked;
                                _studentsExpanded = true;
                                _recompute();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: colorScheme.secondary,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                startTime == null
                                    ? 'Godzina od'
                                    : 'Od: ${formatTimeOfDay24(startTime!)}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime:
                                    endTime ??
                                    const TimeOfDay(hour: 23, minute: 59),
                                builder: (BuildContext context, Widget? child) {
                                  return MediaQuery(
                                    data: MediaQuery.of(
                                      context,
                                    ).copyWith(alwaysUse24HourFormat: true),
                                    child: child!,
                                  );
                                },
                                initialEntryMode: TimePickerEntryMode.input,
                              );
                              if (picked != null) {
                                endTime = picked;
                                _studentsExpanded = true;
                                _recompute();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: colorScheme.secondary,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                endTime == null
                                    ? 'Godzina do'
                                    : 'Do: ${formatTimeOfDay24(endTime!)}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    DropdownButton<String>(
                      value: selectedQualification,
                      hint: const Text('Wybierz kwalifikację'),
                      items:
                          _allQualificationKeys.map((q) {
                            return DropdownMenuItem(value: q, child: Text(q));
                          }).toList(),
                      onChanged: (value) {
                        selectedQualification = value;
                        _studentsExpanded = true;
                        _recompute();
                      },
                    ),
                    const SizedBox(height: 8),
                    if (startDate != null || endDate != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Zakres: ${startDate != null ? startDate!.toLocal().toString().split(' ')[0] : '—'} '
                          '→ ${endDate != null ? endDate!.toLocal().toString().split(' ')[0] : '—'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ExpansionTile(
                      title: Text(
                        'Uczniowie (${_filteredUsers.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      initiallyExpanded: _studentsExpanded,
                      onExpansionChanged: (val) {
                        setState(() => _studentsExpanded = val);
                      },
                      children: [
                        if (_filteredUsers.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'Brak wyników dla tego użytkownika.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          )
                        else
                          ..._filteredUsers.map((userData) {
                            final String user = userData['name'] as String;
                            final String uid =
                                (userData['uid'] ?? '').toString();

                            final exams = List<dynamic>.from(
                              userData['exams'] as List,
                            )..sort((a, b) {
                              final da =
                                  DateTime.tryParse(a['data_czas'] ?? '') ??
                                  DateTime(2000);
                              final db =
                                  DateTime.tryParse(b['data_czas'] ?? '') ??
                                  DateTime(2000);
                              return db.compareTo(da);
                            });

                            final userStats = calculateStats(exams);

                            final Map<String, List<dynamic>> examsByQual = {};
                            for (final exam in exams) {
                              final qualRaw =
                                  (exam['kwalifikacja'] ?? '')
                                      .toString()
                                      .trim();
                              if (isValidQualification(qualRaw)) {
                                examsByQual
                                    .putIfAbsent(qualRaw, () => [])
                                    .add(exam);
                              }
                            }

                            final visibleQualifications =
                                examsByQual.entries
                                    .where((e) => e.value.isNotEmpty)
                                    .toList();

                            final isAnonymous =
                                user == 'Użytkownik anonimowy' ||
                                user == 'anonymous';

                            if (isAnonymous) {
                              return _AnonymousUserCard(
                                user: user,
                                userStats: userStats,
                              );
                            }

                            final lastExam =
                                exams.isNotEmpty ? exams.first : null;
                            final dynamic lastRaw = lastExam?['wynik'];

                            String lastExamScore;
                            if (lastRaw is num) {
                              lastExamScore = lastRaw.toStringAsFixed(2);
                            } else {
                              final parsed = double.tryParse(
                                lastRaw?.toString() ?? '',
                              );
                              lastExamScore =
                                  parsed != null
                                      ? parsed.toStringAsFixed(2)
                                      : '-';
                            }

                            final lastExamDate =
                                lastExam?['data_czas']?.toString() ?? '-';

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: _UserExpansionTile(
                                user: user,
                                uid: uid,
                                userStats: userStats,
                                lastExamScore: lastExamScore,
                                lastExamDate: lastExamDate,
                                qualifications: visibleQualifications,
                                calculateStats: calculateStats,
                                fmtDuration: _fmtDuration,
                                startDate: startDate,
                                endDate: endDate,
                              ),
                            );
                          }),
                      ],
                    ),

                    const SizedBox(height: 4),
                    Card(
                      elevation: 3,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Raport statystyk użytkowników',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleSmall!.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Material(
                                color: colorScheme.primaryContainer.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  hoverColor: colorScheme.secondary.withValues(
                                    alpha: 0.25,
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => ReportSelectionPage(
                                              data: _filteredResults,
                                            ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.description,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Wykonaj raport PDF',
                                          style: theme.textTheme.titleMedium!
                                              .copyWith(
                                                color: colorScheme.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.school,
                          color: colorScheme.primary,
                          size: 32,
                        ),
                        const SizedBox(width: 8),
                        const _SectionTitle('Statystyki według kwalifikacji'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._qualifications.entries.map((entry) {
                      final q = entry.key.toUpperCase();
                      final qStats = calculateStats(entry.value);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: _QualificationCard(
                          qualification: q,
                          qStats: qStats,
                        ),
                      );
                    }),
                  ],
                ),
              ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _AnonymousUserCard extends StatelessWidget {
  final String user;
  final Map<String, dynamic> userStats;
  const _AnonymousUserCard({required this.user, required this.userStats});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Liczba egzaminów: ${userStats['count']}'),
                Text(
                  'Śr. wynik: ${userStats['avg'].toStringAsFixed(2)}%',
                  style: TextStyle(color: colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Najlepszy: ${userStats['best']}%'),
                Text('Najgorszy: ${userStats['worst']}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UserExpansionTile extends StatelessWidget {
  final String user;
  final String uid;
  final Map<String, dynamic> userStats;
  final String lastExamScore;
  final String lastExamDate;
  final List<MapEntry<String, List<dynamic>>> qualifications;
  final Map<String, dynamic> Function(List<dynamic>) calculateStats;
  final String Function(int?) fmtDuration;
  final DateTime? startDate;
  final DateTime? endDate;

  const _UserExpansionTile({
    required this.user,
    required this.uid,
    required this.userStats,
    required this.lastExamScore,
    required this.lastExamDate,
    required this.qualifications,
    required this.calculateStats,
    required this.fmtDuration,
    this.startDate,
    this.endDate,
  });

  String _scoreStr(dynamic v) {
    if (v is num) {
      return v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    }
    return v?.toString() ?? '-';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (uid.isNotEmpty)
              Text(
                'UID: $uid',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        subtitle: Text(
          'Śr. wynik: ${userStats['avg'].toStringAsFixed(2)}% • Egzaminów: ${userStats['count']} • Ostatni: $lastExamScore% ($lastExamDate)',
          style: TextStyle(color: colorScheme.primary),
        ),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        children:
            qualifications.map((qualEntry) {
              final qual = qualEntry.key;
              final qualExams = List<dynamic>.from(qualEntry.value)
                ..sort((a, b) {
                  final da =
                      DateTime.tryParse(a['data_czas'] ?? '') ?? DateTime(2000);
                  final db =
                      DateTime.tryParse(b['data_czas'] ?? '') ?? DateTime(2000);
                  return db.compareTo(da);
                });
              final recent =
                  (startDate == null && endDate == null)
                      ? qualExams.take(5).toList()
                      : qualExams;
              final qualStats = calculateStats(qualEntry.value);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _QualificationTile(
                  qualification: qual,
                  recentExams: recent,
                  qualStats: qualStats,
                  scoreFormatter: _scoreStr,
                  fmtDuration: fmtDuration,
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _QualificationTile extends StatelessWidget {
  final String qualification;
  final List<dynamic> recentExams;
  final Map<String, dynamic> qualStats;
  final String Function(dynamic) scoreFormatter;
  final String Function(int?) fmtDuration;
  const _QualificationTile({
    required this.qualification,
    required this.recentExams,
    required this.qualStats,
    required this.scoreFormatter,
    required this.fmtDuration,
  });
  Future<Map<String, dynamic>?> fetchExamDetailsFull(
    int examId,
    String userName,
    String examDateTime,
    int durationSec,
  ) async {
    try {
      final result = await ApiService.instance.fetchExamPreviewAdmin(
        examId: examId,
        userName: userName,
        examDateTime: examDateTime,
        durationSec: durationSec,
      );

      if (result.isSuccess) {
        final data = result.data!;
        if (data['success'] == true) {
          return {
            'questions': List<dynamic>.from(data['questions']),
            'selectedAnswers':
                (data['selectedAnswers'] as List).cast<String?>(),
          };
        }
      }
      if (kDebugMode) {
        debugPrint('PHP error: ${result.errorMessage ?? result.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Błąd: $e');
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 8, right: 0, bottom: 8),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(Icons.book, color: colorScheme.primary, size: 24),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              qualification,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Egzaminów: ${qualStats['count']}'),
            Text(
              'Śr. wynik: ${qualStats['avg'].toStringAsFixed(2)}%',
              style: TextStyle(color: colorScheme.primary),
            ),
          ],
        ),
      ),
      children: [
        Divider(thickness: 1, height: 8, color: colorScheme.primary),
        if (recentExams.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
            child: Text('❌ Brak egzaminów dla tej kwalifikacji.'),
          )
        else
          ...recentExams.map((exam) {
            final String dateTimeStr = (exam['data_czas'] ?? '-') as String;
            final wynik = scoreFormatter(exam['wynik']);

            final int durationSec =
                (exam['czas_trwania_sec'] is int)
                    ? exam['czas_trwania_sec'] as int
                    : int.tryParse('${exam['czas_trwania_sec'] ?? '0'}') ?? 0;

            final czas = fmtDuration(durationSec);
            final tryb = (exam['tryb'] ?? exam['mode'] ?? '') as String;
            final int examId = int.tryParse('${exam['id'] ?? '0'}') ?? 0;

            final String userName = (exam['userID'] ?? '').toString();

            return _ExamTile(
              date: dateTimeStr.split(' ').first,
              wynik: wynik,
              czas: czas,
              tryb: tryb,
              examId: examId,
              onPreview:
                  examId <= 0
                      ? null
                      : () async {
                        final details = await fetchExamDetailsFull(
                          examId,
                          userName,
                          dateTimeStr,
                          durationSec,
                        );
                        if (!context.mounted) return;

                        if (details != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => EgzaminPodgladView(
                                    questions: details['questions'],
                                    selectedAnswers: details['selectedAnswers'],
                                  ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nie udało się wczytać podglądu'),
                            ),
                          );
                        }
                      },
            );
          }),

        Divider(thickness: 1, height: 8, color: colorScheme.primary),
      ],
    );
  }
}

class _ExamTile extends StatelessWidget {
  final String date;
  final String wynik;
  final String czas;
  final String tryb;
  final int examId;
  final VoidCallback? onPreview;

  const _ExamTile({
    required this.date,
    required this.wynik,
    required this.czas,
    required this.tryb,
    required this.examId,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 8),
      leading: Icon(
        Icons.history,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(date, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        'Wynik: $wynik% • Czas: $czas${tryb.isNotEmpty ? ' • $tryb' : ''}',
      ),
      trailing: ElevatedButton.icon(
        icon: const Icon(Icons.visibility, size: 16),
        label: const Text('Podgląd', style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          visualDensity: VisualDensity.compact,
        ),
        onPressed: onPreview,
      ),
      dense: true,
    );
  }
}

class _QualificationCard extends StatelessWidget {
  final String qualification;
  final Map<String, dynamic> qStats;
  const _QualificationCard({required this.qualification, required this.qStats});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final gradientColors = [
      colorScheme.primary.withValues(alpha: 0.30),
      colorScheme.primary.withValues(alpha: 0.12),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.school_outlined,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    qualification,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Egzaminów: ${qStats['count']}'),
                Text(
                  'Śr: ${qStats['avg'].toStringAsFixed(2)}%',
                  style: TextStyle(color: colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Najlepszy: ${qStats['best'].toStringAsFixed(2)}%'),
                Text('Najgorszy: ${qStats['worst'].toStringAsFixed(2)}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
