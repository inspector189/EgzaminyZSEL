import 'dart:convert' show json;
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http show post;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show Printing;
import 'package:web/web.dart' as web;

const _apiKey = 'zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^';

bool isValidQualification(String? qual) {
  if (qual == null) return false;
  final trimmed = qual.trim();
  return RegExp(r'^[a-z]{3}\d{2}$').hasMatch(trimmed);
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
    final qualifications =
        widget.data
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
              value: selectedQualification,
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
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
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
    final qualData =
        allData.where((e) {
          final q = (e['kwalifikacja'] ?? '').toString().trim();
          return isValidQualification(q) && q == qualification;
        }).toList();

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
                headerStyle: pw.TextStyle(
                  font: ttf,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
                cellStyle: pw.TextStyle(font: ttf, fontSize: 11),
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
}

