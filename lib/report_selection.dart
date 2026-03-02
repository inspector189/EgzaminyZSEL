import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show Printing;
import 'package:web/web.dart' as web;

String normalizeQualification(String? input) {
  if (input == null || input.trim().isEmpty) return '';
  final cleaned = input.trim().toLowerCase().replaceAll('.', '');
  if (cleaned.length != 5) return '';
  final letters = cleaned.substring(0, 3).toUpperCase();
  final numbers = cleaned.substring(3);
  if (!RegExp(r'^[a-zA-Z]{3}\d{2}$').hasMatch('$letters$numbers')) return '';
  return '$letters.$numbers';
}

bool isValidQualification(String? qual) {
  return normalizeQualification(qual).isNotEmpty;
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
    final Set<String> uniqueQuals = {};
    for (final e in widget.data) {
      final normalized = normalizeQualification(e['kwalifikacja']?.toString());
      if (normalized.isNotEmpty) {
        uniqueQuals.add(normalized);
      }
    }
    final qualifications = uniqueQuals.toList()..sort();

    final Map<String, Map<String, List<dynamic>>> usersByQual = {};
    for (final qual in qualifications) {
      final qualExams = widget.data.where((e) {
        return normalizeQualification(e['kwalifikacja']?.toString()) == qual;
      }).toList();

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

   final currentUsers = selectedQualification != null
        ? usersByQual[selectedQualification] ?? {}
        : <String, List<dynamic>>{};

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

  // Filtro­wanie po kwalifikacji
final qualData = allData.where((e) {
      return normalizeQualification(e['kwalifikacja']?.toString()) == qualification;
    }).toList();

  // Zbieramy dane do tabeli: name, uid, lastScore, lastDate
  final List<Map<String, String>> rows = [];

  for (final userKey in selectedUsers) {
    final userExams = qualData.where((exam) {
      final examUser = (exam['userID'] ?? '').toString().trim();
      final examUserKey = examUser.isEmpty || examUser.toLowerCase() == 'anonymous'
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

    // wynik -> zaokrąglony do 2 miejsc
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

        // 🔹 Własna tabela z imię + UID
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2), // osoba
            1: pw.FlexColumnWidth(1), // wynik
            2: pw.FlexColumnWidth(2), // data
          },
          children: [
            // nagłówki
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

            // wiersze z danymi
            ...rows.map((row) {
              final name = row['name'] ?? '-';
              final uid = row['uid'] ?? '';
              final score = row['score'] ?? '-';
              final date = row['date'] ?? '-';

              return pw.TableRow(
                children: [
                  // kolumna: osoba + UID mniejszą czcionką
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
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 9, // mniejsza czcionka
                            ),
                          ),
                      ],
                    ),
                  ),
                  // kolumna: wynik
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      '$score%',
                      style: pw.TextStyle(font: ttf, fontSize: 11),
                    ),
                  ),
                  // kolumna: data
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

}

