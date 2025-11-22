import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
//import 'package:flutter_html/flutter_html.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_app/egzamin_podglad.dart';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

const _apiKey = 'zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^';
  bool isValidQualification(String? qual) {
  if (qual == null) return false;
  final trimmed = qual.trim();
  return RegExp(r'^[a-z]{3}\d{2}$').hasMatch(trimmed);
}

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

  @override
  void initState() {
    super.initState();
    fetchAllStats();
  }

  Future<void> fetchAllStats() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final url = Uri.parse('https://interpage.pl/egzaminy/stats_all.php');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $_apiKey',
        },
      );
      if (kDebugMode) {
        debugPrint('📥 Otrzymano odpowiedź od serwera: ${response.statusCode}');
        debugPrint('Treść odpowiedzi: ${response.body}');
      }
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          setState(() {
            allResults = data;
            isLoading = false;
            errorMessage = null;
          });
        } else {
          throw Exception(
            '❌ Nieprawidłowy format - dane nie są listą, a: ${data.runtimeType}',
          );
        }
      } else {
        throw Exception('❌ Kod błędu HTTP: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Map<String, List<dynamic>> groupByUser() {
    final Map<String, List<dynamic>> grouped = {};
    for (var r in allResults) {
      String user = (r['userID'] ?? '').toString().trim();
      if (user.isEmpty || user.toLowerCase() == 'anonymous') {
        user = 'Użytkownik anonimowy';
      }
      grouped.putIfAbsent(user, () => []).add(r);
    }
    return grouped;
  }

  Map<String, List<dynamic>> groupByQualification() {
    final Map<String, List<dynamic>> grouped = {};
    for (var r in allResults) {
      final q = (r['kwalifikacja'] ?? 'Nieznana').toString();
      grouped.putIfAbsent(q, () => []).add(r);
    }
    return grouped;
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
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filteredResults =
        allResults.where((exam) {
          final examDate = DateTime.tryParse(exam['data_czas'] ?? '');
          if (examDate == null) return false;
          final afterStart =
              startDate == null ||
              examDate.isAfter(startDate!.subtract(const Duration(days: 1)));
          final beforeEnd =
              endDate == null ||
              examDate.isBefore(endDate!.add(const Duration(days: 1)));
          return afterStart && beforeEnd;
        }).toList();
    final users = _groupBy(
      filteredResults,
      (r) => (r['userID'] ?? '').toString().trim(),
    );
   final qualifications = <String, List<dynamic>>{};
      for (final r in filteredResults) {
        final q = (r['kwalifikacja'] ?? '').toString().trim();
        if (isValidQualification(q)) {
          qualifications.putIfAbsent(q, () => []).add(r);
        }
      }
    final filteredUsers =
        users.entries
            .where(
              (e) => e.key.toLowerCase().contains(searchQuery.toLowerCase()),
            )
            .toList()
          ..sort((a, b) {
            if (a.key == 'Użytkownik anonimowy') return 1;
            if (b.key == 'Użytkownik anonimowy') return -1;
            return a.key.compareTo(b.key);
          });
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
                    _SearchBar(
                      onChanged: (value) => setState(() => searchQuery = value),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              startDate == null
                                  ? 'Data od'
                                  : 'Od: ${startDate!.toLocal().toString().split(' ')[0]}',
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: startDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() => startDate = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton.icon(
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              endDate == null
                                  ? 'Data do'
                                  : 'Do: ${endDate!.toLocal().toString().split(' ')[0]}',
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: endDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() => endDate = picked);
                              }
                            },
                          ),
                        ),
                      ],
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
                    if (filteredUsers.isEmpty)
                      Center(
                        child: Text(
                          'Brak wyników dla tego użytkownika.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ...filteredUsers.map((entry) {
                      final user = entry.key;
                      final exams =
                          List<dynamic>.from(entry.value).where((exam) {
                            final examDate = DateTime.tryParse(
                              exam['data_czas'] ?? '',
                            );
                            if (examDate == null) return false;
                            final afterStart =
                                startDate == null ||
                                examDate.isAfter(
                                  startDate!.subtract(const Duration(days: 1)),
                                );
                            final beforeEnd =
                                endDate == null ||
                                examDate.isBefore(
                                  endDate!.add(const Duration(days: 1)),
                                );
                            return afterStart && beforeEnd;
                          }).toList();
                      exams.sort((a, b) {
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
                        final qualRaw = (exam['kwalifikacja'] ?? '').toString().trim();
                        if (isValidQualification(qualRaw)) {
                          examsByQual.putIfAbsent(qualRaw, () => []).add(exam);
                        }
                      }
                      final visibleQualifications =
                          examsByQual.entries
                              .where((e) => e.value.isNotEmpty)
                              .toList();
                      final isAnonymous = user == 'Użytkownik anonimowy';
                      if (isAnonymous) {
                        return _AnonymousUserCard(
                          user: user,
                          userStats: userStats,
                        );
                      }
                      final lastExam = exams.isNotEmpty ? exams.first : null;
                      final lastExamScore =
                          lastExam?['wynik']?.toString() ?? '-';
                      final lastExamDate =
                          lastExam?['data_czas']?.toString() ?? '-';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: _UserExpansionTile(
                          user: user,
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
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.description),
                        label: const Text('Zrób raport'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => ReportSelectionPage(
                                    data: filteredResults,
                                  ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
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
                    const SizedBox(height: 12),
                    ...qualifications.entries.map((entry) {
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

  Map<String, List<dynamic>> _groupBy(
    List<dynamic> list,
    String Function(dynamic) keySelector,
  ) {
    final Map<String, List<dynamic>> grouped = {};
    for (final item in list) {
      final key =
          keySelector(item).isEmpty
              ? 'Użytkownik anonimowy'
              : keySelector(item);
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }
}

class ReportSelectionPage extends StatefulWidget {
  final List<dynamic> data;

  const ReportSelectionPage({super.key, required this.data});

  @override
  State<ReportSelectionPage> createState() => _ReportSelectionPageState();
}

class _ReportSelectionPageState extends State<ReportSelectionPage> {
  String? selectedQualification;
  final Set<String> selectedUsers = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final qualifications = widget.data
        .map((e) => (e['kwalifikacja'] ?? '').toString().trim())
        .where(isValidQualification)
        .toSet()
        .toList()
      ..sort();
    final Map<String, Map<String, List<dynamic>>> usersByQual = {};
    for (final qual in qualifications) {
      final qualExams =
          widget.data
              .where((e) => e['kwalifikacja'].toString() == qual)
              .toList();
      final users = <String, List<dynamic>>{};
      for (final exam in qualExams) {
        final user = (exam['userID'] ?? '').toString().trim();
        final userKey =
            user.isEmpty || user.toLowerCase() == 'anonymous'
                ? 'Użytkownik anonimowy'
                : user;
        users.putIfAbsent(userKey, () => []).add(exam);
      }
      usersByQual[qual] = users;
    }

    final currentUsers =
        selectedQualification != null
            ? usersByQual[selectedQualification] ?? {}
            : {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wybierz do raportu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Wybierz kwalifikację:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedQualification,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Wybierz kwalifikację',
              ),
              items:
                  qualifications.map((qual) {
                    return DropdownMenuItem(value: qual, child: Text(qual));
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedQualification = value;
                  selectedUsers.clear();
                });
              },
            ),
            const SizedBox(height: 24),
            if (selectedQualification != null) ...[
              const Text(
                'Wybierz uczniów:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: currentUsers.length,
                  itemBuilder: (context, index) {
                    final userEntry = currentUsers.entries.elementAt(index);
                    final user = userEntry.key;
                    final userExams = userEntry.value;
                    final userStats = _calculateStats(userExams);
                    final isSelected = selectedUsers.contains(user);

                    return CheckboxListTile(
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Egzaminów: ${userStats['count']} • Śr. wynik: ${userStats['avg'].toStringAsFixed(2)}%',
                            style: TextStyle(color: colorScheme.primary),
                          ),
                        ],
                      ),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            selectedUsers.add(user);
                          } else {
                            selectedUsers.remove(user);
                          }
                        });
                      },
                      secondary: CircleAvatar(
                        child: Text('${userStats['count']}'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.file_download),
                  label: Text(
                    'Generuj raport dla ${selectedUsers.length} uczniów',
                  ),
                  onPressed:
                      selectedUsers.isEmpty
                          ? null
                          : () async {
                            await generateReportPdf(
                              context,
                              selectedQualification!,
                              selectedUsers.toList(),
                              widget.data,
                            );
                            Navigator.pop(context);
                          },
                ),
              ),
            ] else
              const Expanded(
                child: Center(
                  child: Text(
                    'Wybierz kwalifikację, aby zobaczyć listę uczniów.',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _calculateStats(List<dynamic> results) {
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

Future<void> generateReportPdf(
    BuildContext context,
    String qualification,
    List<String> selectedUsers,
    List<dynamic> allData,
  ) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/DejaVuSans.ttf");
    final ttf = pw.Font.ttf(fontData);
    final qualData = allData
        .where((e) {
          final q = (e['kwalifikacja'] ?? '').toString().trim();
          return isValidQualification(q) && q == qualification;
        })
        .toList();

    final tableData = <List<String>>[];
    for (final userKey in selectedUsers) {
      final userExams =
          qualData.where((exam) {
            final examUser = (exam['userID'] ?? '').toString().trim();
            final examUserKey =
                examUser.isEmpty || examUser.toLowerCase() == 'anonymous'
                    ? 'Użytkownik anonimowy'
                    : examUser;
            return examUserKey == userKey;
          }).toList();

      if (userExams.isEmpty) continue;

      userExams.sort((a, b) {
        final da = DateTime.tryParse(a['data_czas'] ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['data_czas'] ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });

      final lastExam = userExams.first;
      final lastScore = lastExam['wynik']?.toStringAsFixed(2) ?? '-';
      final lastDate = lastExam['data_czas']?.toString() ?? '-';

      tableData.add([userKey, lastScore + '%', lastDate]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build:
            (pw.Context context) => [
              pw.Header(
                level: 0,
                child: pw.Center(
                  child: pw.Text(
                    'Raport Egzaminów - Kwalifikacja: $qualification',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      font: ttf,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Data generowania: ${DateTime.now().toLocal().toString().split(' ')[0]}',
                style: pw.TextStyle(font: ttf, fontSize: 12),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Wybrani uczniowie: ${selectedUsers.length}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  font: ttf, 
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Podsumowanie ostatnich egzaminów:',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  font: ttf, 
                ),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: [
                  'Osoba',
                  'Wynik ostatniego egzaminu (%)',
                  'Data ostatniego egzaminu',
                ],
                data: tableData,
                headerStyle: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold, fontSize: 12),
                cellStyle: pw.TextStyle(font: ttf, fontSize: 11),
              ),
            ],
      ),
    );
    final bytes = await pdf.save();
    final filename = 'raport_${qualification.replaceAll(' ', '_')}.pdf';
    if (kIsWeb) {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none'
      ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      await Printing.sharePdf(
        bytes: bytes,
        filename: filename,
      );
    }
  }
}

Future<Map<String, dynamic>?> fetchExamDetailsFull(int examId) async {
  try {
    final response = await http.post(
      Uri.parse('https://interpage.pl/egzaminy/get_exam_full.php'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'api_token': 'zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^',
        'exam_id': examId.toString(),
      },
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return {
        'questions': jsonData['questions'],
        'selectedAnswers': (jsonData['selectedAnswers'] as List).cast<String?>(),
      };
    }
  } catch (e) {
    print("Błąd fetchExamDetailsFull: $e");
  }
  return null;
}
class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});
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
        title: Text(
          user,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
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
            final date = (exam['data_czas'] ?? '-') as String;
            final wynik = scoreFormatter(exam['wynik']);
            final czas = fmtDuration(
              (exam['czas_trwania_sec'] is int)
                  ? exam['czas_trwania_sec'] as int
                  : int.tryParse('${exam['czas_trwania_sec'] ?? ''}'),
            );
          final tryb = (exam['tryb'] ?? exam['mode'] ?? '') as String;
          final int examId = exam['id'] is int 
              ? exam['id'] as int 
              : int.tryParse(exam['id']?.toString() ?? '') ?? 0;

          return _ExamTile(
            date: date.split(' ').first,
            wynik: wynik,
            czas: czas,
            tryb: tryb,
            examId: examId,
            onPreview: examId == 0
                ? null
                : () async {
                    final details = await fetchExamDetailsFull(examId);
                    if (!context.mounted) return;

                    if (details != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EgzaminPodgladView(
                            questions: details['questions'] as List<dynamic>,
                            selectedAnswers: (details['selectedAnswers'] as List<dynamic>).cast<String?>(),
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nie udało się wczytać podglądu egzaminu')),
                      );
                    }
                  },
          );
        }).toList(),
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
      leading: Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
      title: Text(date, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text('Wynik: $wynik% • Czas: $czas${tryb.isNotEmpty ? ' • $tryb' : ''}'),
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
                TextButton(
                  onPressed: () {},
                  child: const Text('Wykonaj Raport'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
                Text('Najlepszy: ${qStats['best']}%'),
                Text('Najgorszy: ${qStats['worst']}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
