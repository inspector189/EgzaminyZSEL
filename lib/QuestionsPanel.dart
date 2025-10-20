// question_stats_page.dart
// Refactored QuestionStatsPage moved to a separate file with immediate data load (no initial loading indicator)

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_html/flutter_html.dart';

class QuestionStatsPage extends StatefulWidget {
  const QuestionStatsPage({super.key});

  @override
  _QuestionStatsPageState createState() => _QuestionStatsPageState();
}

class _QuestionStatsPageState extends State<QuestionStatsPage> {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> questionStats = [];

  @override
  void initState() {
    super.initState();
    fetchQuestionStats(); 
  }

Future<void> fetchQuestionStats() async {
  try {
    final response = await http.get(
      Uri.parse('https://interpage.pl/egzaminy/wyswietl_trudnosci.php'),
    );

    if (response.statusCode != 200) throw Exception('Błąd serwera: ${response.statusCode}');
    final data = json.decode(response.body);
    if (data is! List) throw Exception('Nieprawidłowy format danych');

    // 1️⃣ Zbierz listę kwalifikacji, żeby pobrać wszystkie tylko raz
    final kwalifikacje = data
        .map((item) => (item['kwalifikacja'] ?? '').replaceAll(' ', ''))
        .where((k) => k.isNotEmpty)
        .toSet()
        .toList();

    // 2️⃣ Pobierz dane dla każdej kwalifikacji równolegle
    final Map<String, List<dynamic>> pytaniaDlaKwalifikacji = {};
    await Future.wait(kwalifikacje.map((kwal) async {
      final url = Uri.parse('https://interpage.pl/egzaminy/$kwal.php');
      try {
        final res = await http.get(url);
        if (res.statusCode == 200) {
          final parsed = json.decode(res.body);
          if (parsed is List) pytaniaDlaKwalifikacji[kwal] = parsed;
        }
      } catch (e) {
        debugPrint('⚠️ Błąd pobierania kwalifikacji $kwal: $e');
      }
    }));

    // 3️⃣ Połącz trudności z pytaniami z pamięci
    final List<Map<String, dynamic>> enriched = [];
    for (final item in data) {
      final pytanieId = item['pytanie_id'];
      final kwalifikacja = (item['kwalifikacja'] ?? '').replaceAll(' ', '');
      final pytania = pytaniaDlaKwalifikacji[kwalifikacja];
      final question = pytania?.firstWhere(
        (q) => q['id'].toString() == pytanieId.toString(),
        orElse: () => null,
      );

      if (question != null) {
        enriched.add({
          'pytanie_id': pytanieId,
          'kwalifikacja': item['kwalifikacja'],
          'ilosc_odpowiedzi': item['ilosc_odpowiedzi'],
          'ilosc_poprawnych_odpowiedzi': item['ilosc_poprawnych_odpowiedzi'],
          'trudnosc': (item['trudnosc'] is num)
              ? (item['trudnosc'] as num).toDouble()
              : double.tryParse(item['trudnosc'].toString()) ?? 0.0,
          'pytanie': question['pytanie'] ?? '',
          'odp1': question['odp1'] ?? '',
          'odp2': question['odp2'] ?? '',
          'odp3': question['odp3'] ?? '',
          'odp4': question['odp4'] ?? '',
          'poprawna': question['poprawna'] ?? '',
        });
      }
    }

    // 4️⃣ Zaktualizuj UI natychmiast po zbudowaniu listy
    setState(() {
      questionStats = enriched;
      isLoading = false;
      errorMessage = null;
    });
  } catch (e) {
    debugPrint('❌ Błąd fetchQuestionStats: $e');
    setState(() {
      isLoading = false;
      errorMessage = 'Błąd: $e';
    });
  }
}
  Future<Map<String, dynamic>> fetchQuestionDetails(String? pytanieId, String kwalifikacja) async {
    try {
      final url = Uri.parse('https://interpage.pl/egzaminy/$kwalifikacja.php');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          final question = data.firstWhere(
            (q) => q['id'].toString() == pytanieId,
            orElse: () => null,
          );
          if (question != null) {
            return {
              'pytanie': question['pytanie'] ?? 'Brak treści pytania',
              'odp1': question['odp1'] ?? 'Brak odpowiedzi 1',
              'odp2': question['odp2'] ?? 'Brak odpowiedzi 2',
              'odp3': question['odp3'] ?? 'Brak odpowiedzi 3',
              'odp4': question['odp4'] ?? 'Brak odpowiedzi 4',
              'poprawna': question['poprawna'] ?? 'Brak poprawnej odpowiedzi',
            };
          }
        }
      }
      return {
        'pytanie': 'Brak treści pytania',
        'odp1': 'Brak odpowiedzi 1',
        'odp2': 'Brak odpowiedzi 2',
        'odp3': 'Brak odpowiedzi 3',
        'odp4': 'Brak odpowiedzi 4',
        'poprawna': 'Brak poprawnej odpowiedzi',
      };
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Błąd pobierania szczegółów pytania: $e');
      return {
        'pytanie': 'Błąd pobierania treści',
        'odp1': 'Błąd pobierania odpowiedzi',
        'odp2': 'Błąd pobierania odpowiedzi',
        'odp3': 'Błąd pobierania odpowiedzi',
        'odp4': 'Błąd pobierania odpowiedzi',
        'poprawna': 'Błąd pobierania odpowiedzi',
      };
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Map<String, List<dynamic>> groupByQualification() {
    final Map<String, List<dynamic>> grouped = {};
    for (var r in questionStats) {
      final q = (r['kwalifikacja'] ?? 'Nieznana').toString();
      final iloscOdp = int.tryParse(r['ilosc_odpowiedzi']?.toString() ?? '0') ?? 0;
      final trudnosc = (r['trudnosc'] is num ? r['trudnosc'] : double.tryParse(r['trudnosc'].toString()) ?? 0.0) as double;
      if (iloscOdp >= 2 && trudnosc > 0) { // Filtruj tylko pytania z badge'ami
        grouped.putIfAbsent(q, () => []);
        grouped[q]!.add(r);
      }
    }
    return Map.fromEntries(grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  Html _html(BuildContext context, String html) {
    html = html.replaceAll('<img', '<br><img');
    return Html(
      data: html,
      style: {
        "body": Style(color: Theme.of(context).colorScheme.onSurface),
        "b": Style(color: Theme.of(context).colorScheme.onSurface),
        "span": Style(
          color: html.contains("style='color:green;'")
              ? Colors.green
              : Theme.of(context).colorScheme.onSurface,
        ),
      },
      extensions: [
        TagExtension(
          tagsToExtend: {'img'},
          builder: (extensionContext) {
            final src = extensionContext.attributes['src'];
            if (src != null) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Tooltip(
                    message: 'Kliknij, aby powiększyć',
                    child: GestureDetector(
                      onTap: () => _showImageDialog(context, src),
                      child: Image.network(
                        src,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Text(
                          '❌ Nie udało się załadować obrazka',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return Text(
              '⚠️ Brak obrazka',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            );
          },
        ),
      ],
    );
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Zamknij',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        final screenSize = MediaQuery.of(context).size;
        bool isPressed = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return GestureDetector(
              onTap: () => Navigator.of(context, rootNavigator: true).pop(),
              child: Scaffold(
                backgroundColor: Colors.black.withValues(alpha: 0.9),
                body: Stack(
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: () {},
                        child: Listener(
                          onPointerDown: (_) => setState(() => isPressed = true),
                          onPointerUp: (_) => setState(() => isPressed = false),
                          child: MouseRegion(
                            cursor: isPressed
                                ? SystemMouseCursors.grabbing
                                : SystemMouseCursors.grab,
                            child: InteractiveViewer(
                              panEnabled: true,
                              minScale: 0.5,
                              maxScale: 4,
                              child: Image.network(
                                imageUrl,
                                width: screenSize.width * 0.8,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Text(
                                  '❌ Nie udało się załadować obrazka',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 30,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        tooltip: 'Zamknij',
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDifficultyBadge(dynamic stat) {
    final trudnoscRaw = stat['trudnosc'];
    final iloscOdp = int.tryParse(stat['ilosc_odpowiedzi']?.toString() ?? '0') ?? 0;
    if (trudnoscRaw == null || iloscOdp < 2) return const SizedBox.shrink();

    final trudnosc = (trudnoscRaw is num ? trudnoscRaw : trudnoscRaw.toInt()) as int;
    final isTrudne = trudnosc > 50;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isTrudne ? Colors.red : Colors.green,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${isTrudne ? 'TRUDNE' : 'ŁATWE'} ($trudnosc%)',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildQuestionCard(dynamic q) {
    final questionId = q['pytanie_id'] ?? '-';
    final qualification = q['kwalifikacja'] ?? '-';
    final totalAnswers = q['ilosc_odpowiedzi'] ?? '0';
    final correctAnswers = q['ilosc_poprawnych_odpowiedzi'] ?? '0';
    final difficulty = q['trudnosc']?.toStringAsFixed(1) ?? '0';
    final successRate = totalAnswers != '0' ? ((int.parse(correctAnswers) / int.parse(totalAnswers)) * 100).toStringAsFixed(1) : '0';
    final pytanie = q['pytanie'] ?? 'Brak treści pytania';
    final odp1 = q['odp1'] ?? 'Brak odpowiedzi 1';
    final odp2 = q['odp2'] ?? 'Brak odpowiedzi 2';
    final odp3 = q['odp3'] ?? 'Brak odpowiedzi 3';
    final odp4 = q['odp4'] ?? 'Brak odpowiedzi 4';
    final poprawna = q['poprawna'] ?? 'Brak poprawnej odpowiedzi';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _html(context, "<b>Pytanie #$questionId</b>"),
                ),
                _buildDifficultyBadge(q),
              ],
            ),
            const SizedBox(height: 10),
            _html(context, "<b>Pytanie:</b><br>$pytanie"),
            const SizedBox(height: 10),
            ...['A', 'B', 'C', 'D'].map((litera) {
              final odp = {
                'A': odp1,
                'B': odp2,
                'C': odp3,
                'D': odp4,
              }[litera] ?? 'Brak odpowiedzi';
              final isCorrectAnswer = litera == poprawna;

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCorrectAnswer ? Colors.green : null,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: () {},
                  child: _html(context, odp),
                ),
              );
            }),
            const SizedBox(height: 6),
            _html(
              context,
              "<b>✅ Odpowiedź poprawna to: <span style='color:green;'>$poprawna</span></b>",
            ),
            const SizedBox(height: 4),
            Text('Kwalifikacja: $qualification', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text('Odpowiedzi: $totalAnswers')),
                Expanded(child: Text('Poprawne: $correctAnswers ($successRate%)')),
              ],
            ),
          ],
        ),
      ),
    );
  }

@override
  Widget build(BuildContext context) {
    final grouped = groupByQualification();

    return Scaffold(
      appBar: AppBar(
        title: const Text('📉 Statystyki Trudności Pytań'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchQuestionStats,
          ),
        ],
      ),
      body: errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: fetchQuestionStats,
                      child: const Text('Spróbuj ponownie'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchQuestionStats,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: grouped.length,
                itemBuilder: (context, index) {
                  final entry = grouped.entries.elementAt(index);
                  final kwal = entry.key;
                  final questions = entry.value;
                  
                  // Sortowanie od najtrudniejszych
                  questions.sort((a, b) {
                    final trudnoscA = (a['trudnosc'] is num
                        ? a['trudnosc']
                        : double.tryParse(a['trudnosc'].toString()) ?? 0.0) as double;
                    final trudnoscB = (b['trudnosc'] is num
                        ? b['trudnosc']
                        : double.tryParse(b['trudnosc'].toString()) ?? 0.0) as double;
                    return trudnoscB.compareTo(trudnoscA);
                  });

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ExpansionTile(
                      title: Row(
                        children: [
                          Icon(Icons.school, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$kwal (${questions.length} pytań)',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      children: questions.map<Widget>(_buildQuestionCard).toList(),
                    ),
                  );
                },
              ),
            ),
    );
  }
}