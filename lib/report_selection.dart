import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show Printing;
import 'package:web/web.dart' as web;

import '/utils/async_state_view.dart';

String normalizeQualification(String? input) {
  if (input == null || input.trim().isEmpty) return '';
  final cleaned = input.trim().toLowerCase().replaceAll('.', '');
  if (cleaned.length != 5) return '';
  final letters = cleaned.substring(0, 3).toUpperCase();
  final numbers = cleaned.substring(3);
  if (!RegExp(r'^[a-zA-Z]{3}\d{2}$').hasMatch('$letters$numbers')) return '';
  return '$letters.$numbers';
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
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final Set<String> uniqueQuals = {};
    for (final e in widget.data) {
      final normalized = normalizeQualification(e['kwalifikacja']?.toString());
      if (normalized.isNotEmpty) uniqueQuals.add(normalized);
    }
    final qualifications = uniqueQuals.toList()..sort();

    final Map<String, Map<String, List<dynamic>>> usersByQual = {};
    for (final qual in qualifications) {
      final qualExams = widget.data
          .where(
            (e) =>
                normalizeQualification(e['kwalifikacja']?.toString()) == qual,
          )
          .toList();

      final users = <String, List<dynamic>>{};
      for (final exam in qualExams) {
        final userRaw = (exam['userID'] ?? '').toString().trim();
        final userKey = userRaw.isEmpty || userRaw.toLowerCase() == 'anonymous'
            ? 'Użytkownik anonimowy'
            : userRaw;
        users.putIfAbsent(userKey, () => []).add(exam);
      }
      usersByQual[qual] = users;
    }

    final currentUsersMap = selectedQualification != null
        ? (usersByQual[selectedQualification] ?? {})
        : <String, List<dynamic>>{};

    final filteredUsers = currentUsersMap.entries.where((entry) {
      if (_searchQuery.isEmpty) return true;
      return entry.key.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generuj Raport'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _QualificationSelector(
              qualifications: qualifications,
              selected: selectedQualification,
              onChanged: (value) {
                setState(() {
                  selectedQualification = value;
                  selectedUsers.clear();
                  _searchQuery = '';
                });
              },
              cs: cs,
              tt: tt,
            ),
          ),

          if (selectedQualification != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Szukaj ucznia...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: cs.surface,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            Expanded(
              child: filteredUsers.isEmpty
                  ? Center(
                      child: AsyncStateView.empty(
                        message: 'Brak wyników',
                        subtitle: _searchQuery.isEmpty
                            ? 'Brak uczniów w tej kwalifikacji'
                            : 'Nie znaleziono pasujących uczniów',
                        icon: Icons.person_search_rounded,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final entry = filteredUsers[index];
                        final userName = entry.key;
                        final exams = entry.value;
                        final stats = _calculateStats(exams);
                        final isSelected = selectedUsers.contains(userName);

                        return _UserReportCard(
                          userName: userName,
                          stats: stats,
                          isSelected: isSelected,
                          onChanged: (selected) {
                            setState(() {
                              if (selected) {
                                selectedUsers.add(userName);
                              } else {
                                selectedUsers.remove(userName);
                              }
                            });
                          },
                          cs: cs,
                          tt: tt,
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: selectedUsers.isEmpty
                    ? null
                    : () async {
                        await generateReportPdf(
                          context,
                          selectedQualification!,
                          selectedUsers.toList(),
                          widget.data,
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                icon: const Icon(Icons.file_download_rounded),
                label: Text('Generuj raport (${selectedUsers.length} uczniów)'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
            ),
          ] else
            Expanded(
              child: Center(
                child: AsyncStateView.empty(
                  message: 'Wybierz kwalifikację',
                  subtitle: 'Aby zobaczyć listę uczniów',
                  icon: Icons.school_rounded,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateStats(List<dynamic> results) {
    if (results.isEmpty) return {'count': 0, 'avg': 0.0};
    final scores = results.map<double>((e) {
      final raw = e['wynik'];
      if (raw is num) return raw.toDouble();
      return double.tryParse('$raw') ?? 0.0;
    }).toList();
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    return {'count': scores.length, 'avg': avg};
  }
}

class _QualificationSelector extends StatelessWidget {
  const _QualificationSelector({
    required this.qualifications,
    required this.selected,
    required this.onChanged,
    required this.cs,
    required this.tt,
  });

  final List<String> qualifications;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<String>(
      width: double.infinity,
      initialSelection: selected,
      leadingIcon: const Icon(Icons.school_rounded),
      label: const Text('Kwalifikacja'),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: cs.surface,
      ),
      dropdownMenuEntries: qualifications.map((q) {
        return DropdownMenuEntry(value: q, label: q);
      }).toList(),
      onSelected: onChanged,
    );
  }
}

class _UserReportCard extends StatelessWidget {
  const _UserReportCard({
    required this.userName,
    required this.stats,
    required this.isSelected,
    required this.onChanged,
    required this.cs,
    required this.tt,
  });

  final String userName;
  final Map<String, dynamic> stats;
  final bool isSelected;
  final ValueChanged<bool> onChanged;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final count = stats['count'] as int;
    final avg = stats['avg'] as double;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (v) => onChanged(v == true),
        title: Text(
          userName,
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$count egzaminów • Średnia: ${avg.toStringAsFixed(1)}%',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        secondary: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Text(
            count.toString(),
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
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

  final qualData = allData.where((e) {
    return normalizeQualification(e['kwalifikacja']?.toString()) ==
        qualification;
  }).toList();

  final List<Map<String, String>> rows = [];

  for (final userKey in selectedUsers) {
    final userExams = qualData.where((exam) {
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

    final raw = lastExam['wynik'];
    num? rawNum;
    if (raw is num) {
      rawNum = raw;
    } else {
      rawNum = num.tryParse(raw?.toString() ?? '');
    }
    final lastScore = rawNum != null ? rawNum.toStringAsFixed(2) : '-';

    final lastDate = lastExam['data_czas']?.toString() ?? '-';
    final uid = (lastExam['UID'] ?? '').toString();

    rows.add({
      'name': userKey,
      'uid': uid,
      'score': lastScore,
      'date': lastDate,
    });
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) => [
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

        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'Osoba',
                    style: pw.TextStyle(
                      font: ttf,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'Wynik ostatniego egzaminu (%)',
                    style: pw.TextStyle(
                      font: ttf,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'Data ostatniego egzaminu',
                    style: pw.TextStyle(
                      font: ttf,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            ...rows.map((row) {
              final name = row['name'] ?? '-';
              final uid = row['uid'] ?? '';
              final score = row['score'] ?? '-';
              final date = row['date'] ?? '-';

              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          name,
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (uid.isNotEmpty)
                          pw.Text(
                            'UID: $uid',
                            style: pw.TextStyle(font: ttf, fontSize: 9),
                          ),
                      ],
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      '$score%',
                      style: pw.TextStyle(font: ttf, fontSize: 11),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      date,
                      style: pw.TextStyle(font: ttf, fontSize: 11),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    ),
  );

  web.Blob createBlob(List<int> bytes, String type) {
    final data = Uint8List.fromList(bytes).buffer.toJS;
    return web.Blob([data].toJS, web.BlobPropertyBag(type: type));
  }

  final bytes = await pdf.save();
  final filename = 'raport_${qualification.replaceAll(' ', '_')}.pdf';

  if (kIsWeb) {
    final blob = createBlob(bytes, 'application/pdf');
    final url = web.URL.createObjectURL(blob);
    web.window.open(url, '_blank');
    Future.delayed(
      const Duration(seconds: 5),
      () => web.URL.revokeObjectURL(url),
    );
  } else {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
