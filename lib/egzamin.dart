import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'wyniki.dart';
//import 'package:html/parser.dart' as html_parser;

enum TrybEgzaminu { jednoPytanie, czterdziesciPytan, wszystkie }

class EgzaminView extends StatefulWidget {
  final TrybEgzaminu tryb;
  final String kwalifikacja;
  final bool returnToHome;
  final String? userName;
  const EgzaminView({
    super.key,
    required this.tryb,
    required this.kwalifikacja,
    required this.returnToHome,
    this.userName,
  });

  @override
  State<EgzaminView> createState() => _EgzaminViewState();
}

class _EgzaminViewState extends State<EgzaminView> {
  bool _isButtonDisabled = false;
  List<dynamic> questions = [];
  int current = 0;
  String? selectedAnswer;
  bool isLoading = true;
  List<String?> selectedAnswers = [];
  List<bool> zapisanoOdpowiedz = [];
  late DateTime startTime;
  bool odpowiedzZatwierdzona = false;

  @override
  void initState() {
    super.initState();
    fetchQuestions();
    startTime = DateTime.now();
  }

  Future<Map<String, double>> fetchTrudnosciZdalnie() async {
    final url = Uri.parse(
      'https://interpage.pl/egzaminy/wyswietl_trudnosci.php',
    );
    if (mounted) {
      try {
        final response = await http.get(
          url,
          headers: {
            'Authorization': 'Bearer zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^',
          },
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final Map<String, double> map = {};

          for (var entry in data) {
            final key =
                '${entry['pytanie_id']}_${entry['kwalifikacja'].toString().toLowerCase()}';

            final trudnosc =
                (entry['trudnosc'] is num)
                    ? (entry['trudnosc'] as num).toDouble()
                    : double.tryParse(entry['trudnosc'].toString()) ?? 0.0;
            map[key] = trudnosc;
          }
          return map;
        } else {
          if (kDebugMode) {
            debugPrint(
              '❌ Błąd HTTP przy pobieraniu trudności: ${response.statusCode}',
            );
          }
          return {};
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Błąd połączenia: $e');
        }
        return {};
      }
    } else {
      return {};
    }
  }

  int calculateCorrectAnswers() {
    int correct = 0;
    for (int i = 0; i < questions.length; i++) {
      if (selectedAnswers[i] == questions[i]['poprawna']) {
        correct++;
      }
    }
    return correct;
  }

  Widget _buildBadge(dynamic q) {
    final trudnosc = q['trudnosc'];
    final iloscOdp = int.tryParse(q['ilosc_odpowiedzi']?.toString() ?? '') ?? 0;

    if (trudnosc == null || iloscOdp < 5) return const SizedBox.shrink();

    final difficulty =
        (trudnosc is num ? trudnosc : int.tryParse(trudnosc.toString()) ?? 0)
            .toInt();
    final isTrudne = difficulty > 50;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isTrudne ? Colors.red : Colors.green,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isTrudne ? 'TRUDNE' : 'ŁATWE',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> fetchQuestions() async {
    final kwalifikacja = widget.kwalifikacja.replaceAll(' ', '');
    final url = Uri.parse('https://interpage.pl/egzaminy/$kwalifikacja.php');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final decoded = json.decode(response.body);
          if (decoded is List && decoded.isNotEmpty) {
            List<dynamic> allQuestions = decoded;
            List<dynamic> selected;

            switch (widget.tryb) {
              case TrybEgzaminu.jednoPytanie:
                selected = [allQuestions..shuffle()].first;
                break;
              case TrybEgzaminu.czterdziesciPytan:
                selected = List.from(allQuestions)..shuffle();
                selected = selected.take(40).toList();
                break;
              case TrybEgzaminu.wszystkie:
                selected = allQuestions;
                break;
            }

            final trudnosci = await fetchTrudnosciZdalnie();
            final kwalifikacja = widget.kwalifikacja.toLowerCase();

            for (var q in selected) {
              final key = '${q['id']}_$kwalifikacja';
              q['trudnosc'] = trudnosci[key] ?? 0.0;
            }

            if (mounted) {
              setState(() {
                questions = selected;
                selectedAnswers = List.filled(selected.length, null);
                zapisanoOdpowiedz = List.filled(selected.length, false);
                isLoading = false;
                if (kDebugMode) {
                  debugPrint(
                    '✅ Załadowano ${questions.length} pytań z domyślną trudnością',
                  );
                }
              });

              final trudnosciMap = await fetchAllTrudnosci(
                widget.kwalifikacja.replaceAll(' ', ''),
              );

              for (var q in questions) {
                final id = int.tryParse(q['id'].toString());
                if (id != null && trudnosciMap.containsKey(id)) {
                  q['trudnosc'] = trudnosciMap[id]?['trudnosc'] ?? 0.0;
                  q['ilosc_odpowiedzi'] =
                      trudnosciMap[id]?['ilosc_odpowiedzi'] ?? 0;
                }
              }
              setState(() {}); // <- odświeża widok z uzupełnionymi danymi
            }
          }
        } else {
          if (kDebugMode) {
            debugPrint('❌ Brak danych z API!');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ Kod błędu HTTP: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("❌ Błąd przy pobieraniu pytań: $e");
      }
    }
  }

  Future<void> sendResultToServer({
    required String kwalifikacja,
    required double wynik,
    required String dataCzas,
    required int czasTrwania,
  }) async {
    String userName =
        widget.userName ??
        (await SharedPreferences.getInstance()).getString('userName') ??
        'anonymous';

    final url = Uri.parse('https://interpage.pl/egzaminy/zapisz_wynik.php');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Bearer zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^',
      },
      body: {
        'kwalifikacja': kwalifikacja.replaceAll(' ', ''),
        'wynik': wynik.toStringAsFixed(2),
        'data_czas': dataCzas,
        'czas_trwania': czasTrwania.toString(),
        'userName': userName,
      },
    );

    if (response.statusCode != 200) {
      if (kDebugMode) {
        debugPrint('❌ Błąd przy zapisywaniu wyniku: ${response.body}');
      }
    } else {
      if (kDebugMode) {
        debugPrint('✅ Wynik zapisany dla userName: $userName');
      }
    }
  }

  Future<Map<int, Map<String, dynamic>>> fetchAllTrudnosci(
    String kwalifikacja,
  ) async {
    final url = Uri.parse(
      'https://interpage.pl/egzaminy/wyswietl_trudnosci.php',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final Map<int, Map<String, dynamic>> result = {};

        for (final item in jsonList) {
          final int? id = int.tryParse(item['pytanie_id'].toString());
          if (id != null) {
            result[id] = {
              'trudnosc': item['trudnosc'] ?? 0.0,
              'ilosc_odpowiedzi': item['ilosc_odpowiedzi'] ?? 0,
            };
          }
        }

        return result;
      } else {
        if (kDebugMode) {
          debugPrint('❌ Kod błędu HTTP: ${response.statusCode}');
        }
        return {};
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Błąd fetchAllTrudnosci: $e');
      }
      return {};
    }
  }

  Future<void> zapiszTrudnoscDoBazy(
    int pytanieId,
    String kwalifikacja,
    bool poprawna,
  ) async {
    if (pytanieId <= 0) {
      if (kDebugMode) {
        debugPrint(
          '❌ Pominięto zapis - wartość pytanie_id jest niepoprawna: $pytanieId',
        );
      }
      return;
    }

    final url = Uri.parse('https://interpage.pl/egzaminy/zapis_trudnosci.php');
    final body = {
      'pytanie_id': pytanieId.toString(),
      'kwalifikacja': kwalifikacja.replaceAll(' ', ''),
      'poprawna': poprawna ? '1' : '0',
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization':
            'Bearer zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        if (kDebugMode) {
          debugPrint('✅ Trudność zapisana: $data');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Błąd parsowania odpowiedzi: $e');
        }
      }
    } else {
      if (kDebugMode) {
        debugPrint(
          '❌ Błąd zapisu trudności: ${response.statusCode} ${response.body}',
        );
      }
    }
  }

  Future<double> fetchTrudnosc(int pytanieId, String kwalifikacja) async {
    final url = Uri.parse(
      'https://interpage.pl/egzaminy/zapis_trudnosci.php?pytanie_id=$pytanieId&kwalifikacja=$kwalifikacja',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        // Jeśli błąd bazy, zwróć 0
        return 0.0; // Tymczasowo, bo endpoint nie działa
      }
      return 0.0;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Błąd pobierania trudności: $e');
      }
      return 0.0;
    }
  }

  void checkAnswer(String answer) {
    if (odpowiedzZatwierdzona && widget.tryb == TrybEgzaminu.jednoPytanie) {
      return;
    }

    setState(() {
      selectedAnswer = answer;
      selectedAnswers[current] = answer;

      if (widget.tryb == TrybEgzaminu.jednoPytanie) {
        odpowiedzZatwierdzona = true;

        final pytanie = questions[current];
        final poprawna = answer == pytanie['poprawna'];

        zapiszTrudnoscDoBazy(
          int.parse(pytanie['id']),
          widget.kwalifikacja,
          poprawna,
        ).then((_) {
          fetchTrudnosc(int.parse(pytanie['id']), widget.kwalifikacja).then((
            trudnosc,
          ) {
            setState(() {
              questions[current]['trudnosc'] = trudnosc;
            });
          });
        });
      } else if (widget.tryb == TrybEgzaminu.czterdziesciPytan) {
        selectedAnswers[current] = answer;
      }
    });

    // ⛔ W trybie "wszystkie" nie zapisujemy niczego
    if (widget.tryb == TrybEgzaminu.wszystkie) return;
  }

  void nextQuestion() {
    if (current < questions.length - 1) {
      setState(() {
        current++;
        selectedAnswer = selectedAnswers[current];
      });
    }
  }

  void prevQuestion() {
    if (current > 0) {
      setState(() {
        current--;
        selectedAnswer = selectedAnswers[current];
      });
    }
  }

  void jumpToQuestion(String value) {
    final number = int.tryParse(value);
    if (number != null && number >= 1 && number <= questions.length) {
      setState(() {
        current = number - 1;
        selectedAnswer = selectedAnswers[current];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Egzamin'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context, {'returnToHome': widget.returnToHome});
            },
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Egzamin'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context, {'returnToHome': widget.returnToHome});
            },
          ),
        ),
        body: const Center(child: Text('Brak pytań do wyświetlenia.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Egzamin"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, {'returnToHome': widget.returnToHome});
          },
        ),
      ),
      body:
          widget.tryb == TrybEgzaminu.jednoPytanie
              ? _buildSingleQuestion(questions.first)
              : _buildScrollableList(),
      bottomNavigationBar:
          widget.tryb == TrybEgzaminu.czterdziesciPytan
              ? Padding(
                padding: const EdgeInsets.all(12.0),
                child: ElevatedButton(
                  onPressed:
                      _isButtonDisabled
                          ? null
                          : () async {
                            setState(() => _isButtonDisabled = true);

                            final correct = calculateCorrectAnswers();
                            final total = questions.length;
                            final percent = (correct / total) * 100;
                            final endTime = DateTime.now();
                            final duration =
                                endTime.difference(startTime).inSeconds;

                            if (widget.tryb == TrybEgzaminu.czterdziesciPytan) {
                              final futures = <Future>[];

                              for (int i = 0; i < questions.length; i++) {
                                final pytanie = questions[i];
                                final pytanieId = int.tryParse(
                                  pytanie['id'].toString(),
                                );
                                final odpowiedz = selectedAnswers[i];

                                if (pytanieId != null && odpowiedz != null) {
                                  final poprawna =
                                      odpowiedz == pytanie['poprawna'];
                                  futures.add(
                                    zapiszTrudnoscDoBazy(
                                      pytanieId,
                                      widget.kwalifikacja,
                                      poprawna,
                                    ),
                                  );
                                }
                              }

                              try {
                                await Future.wait(futures);
                                if (kDebugMode) {
                                  debugPrint(
                                    '✅ Trudność pytań została zapisana!',
                                  );
                                }
                              } catch (e) {
                                if (kDebugMode) {
                                  debugPrint(
                                    '❌ Błąd przy zapisie trudności: $e',
                                  );
                                }
                              }
                            }

                            await sendResultToServer(
                              kwalifikacja: widget.kwalifikacja,
                              wynik: percent,
                              dataCzas: endTime.toIso8601String(),
                              czasTrwania: duration,
                            );

                            setState(() => _isButtonDisabled = false);
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => EgzaminWynikView(
                                        correctAnswers: correct,
                                        totalQuestions: total,
                                        questions: questions,
                                        selectedAnswers: selectedAnswers,
                                        returnToHome: true,
                                      ),
                                  settings: const RouteSettings(
                                    name: 'EgzaminWynikView',
                                  ),
                                ),
                              );
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  child: Text(
                    _isButtonDisabled
                        ? "Wysyłanie egzaminu ..."
                        : "Zakończ egzamin",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              )
              : null,
    );
  }

  Html _html(String html) {
    html = html.replaceAll('<img', '<br><img');

    return Html(
      data: html,
      style: {
        "body": Style(color: Theme.of(context).colorScheme.onSurface),
        "b": Style(color: Theme.of(context).colorScheme.onSurface),
        "span": Style(
          color:
              html.contains("style='color:green;'")
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
                child: Builder(
                  builder:
                      (context) => Center(
                        child: Tooltip(
                          message: 'Kliknij, aby powiększyć',
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => _showImageDialog(context, src),
                              child: Image.network(
                                src,
                                fit: BoxFit.contain,
                                errorBuilder:
                                    (context, error, stackTrace) => Text(
                                      '❌ Nie udało się załadować obrazka',
                                      style: TextStyle(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.surface,
                                      ),
                                    ),
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
              style: TextStyle(color: Theme.of(context).colorScheme.surface),
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
                          onPointerDown:
                              (_) => setState(() => isPressed = true),
                          onPointerUp: (_) => setState(() => isPressed = false),
                          child: MouseRegion(
                            cursor:
                                isPressed
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
                                errorBuilder:
                                    (context, error, stackTrace) => Text(
                                      '❌ Nie udało się załadować obrazka',
                                      style: TextStyle(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.surface,
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
                          color: Theme.of(context).colorScheme.surface,
                        ),
                        tooltip: 'Zamknij',
                        onPressed:
                            () =>
                                Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).pop(),
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

  Widget _buildSingleQuestion(dynamic q) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _html("<h3>Pytanie:</h3>${q['pytanie']}")),
              _buildBadge(q),
            ],
          ),
          const SizedBox(height: 16),
          ...['A', 'B', 'C', 'D'].map((litera) {
            final odp = q['odp${'ABCD'.indexOf(litera) + 1}'];
            final isCorrect = litera == q['poprawna'];
            final isWrong = selectedAnswer == litera && !isCorrect;

            Color? buttonColor;
            if (selectedAnswer != null) {
              if (isCorrect) {
                buttonColor = Colors.green;
              } else if (isWrong) {
                buttonColor = Colors.red;
              } else if (selectedAnswer == litera) {
                buttonColor = Colors.orangeAccent;
              }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed:
                    (odpowiedzZatwierdzona && selectedAnswer != litera)
                        ? null
                        : () => checkAnswer(litera),
                child: _html(odp ?? ""),
              ),
            );
          }),
          const SizedBox(height: 10),
          if (selectedAnswer != null)
            _html(
              selectedAnswer == q['poprawna']
                  ? "<b>✅ Odpowiedź $selectedAnswer jest poprawna.<br>${q['opisPoprawne']}</b>"
                  : "<b>❌ Odpowiedź $selectedAnswer jest niepoprawna.<br>${q['opisNiepoprawne']}<br><br><span style='color:green;'>✅ Odpowiedź poprawna to: ${q['poprawna']}</span></b>",
            ),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              onPressed: _losujNowePytanie,
              icon: const Icon(Icons.refresh),
              label: const Text("Losuj kolejne"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _losujNowePytanie() {
    setState(() {
      questions.shuffle();
      selectedAnswer = null;
      odpowiedzZatwierdzona = false;
    });
  }

  Widget _buildScrollableList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: questions.length,
      addAutomaticKeepAlives: false,
      itemBuilder: (context, index) {
        final q = questions[index];
        final selected = selectedAnswers[index];

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
                      child: _html(
                        "<b>Pytanie ${index + 1}:</b><br>${q['pytanie']}",
                      ),
                    ),
                    _buildBadge(q),
                  ],
                ),
                const SizedBox(height: 10),
                ...['A', 'B', 'C', 'D'].map((litera) {
                  final odp = q['odp${'ABCD'.indexOf(litera) + 1}'];

                  Color? buttonColor;
                  if (selected == litera) {
                    buttonColor = const Color.fromARGB(255, 150, 150, 150);
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                      ),
                      onPressed: () {
                        setState(() {
                          selectedAnswers[index] = litera;
                        });
                      },
                      child: _html(odp ?? ""),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InteractiveImage extends StatefulWidget {
  final String imageUrl;
  const _InteractiveImage({required this.imageUrl});

  @override
  State<_InteractiveImage> createState() => _InteractiveImageState();
}

class _InteractiveImageState extends State<_InteractiveImage> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Listener(
      onPointerDown: (_) => setState(() => _isPressed = true),
      onPointerUp: (_) => setState(() => _isPressed = false),
      child: MouseRegion(
        cursor:
            _isPressed ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            widget.imageUrl,
            fit: BoxFit.contain,
            width: screenSize.width * 0.9,
            errorBuilder:
                (context, error, stackTrace) => Text(
                  '❌ Nie udało się załadować obrazka',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}