import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'wyniki.dart';

enum TrybEgzaminu { jednoPytanie, czterdziesciPytan, wszystkie }

class EgzaminView extends StatefulWidget {
  final TrybEgzaminu tryb;
  final String kwalifikacja;
  final bool isDarkMode;
  final bool returnToHome;
  final String? userName; // Add userID parameter

  const EgzaminView({
    super.key,
    required this.tryb,
    required this.kwalifikacja,
    required this.isDarkMode,
    required this.returnToHome,
    this.userName, // Optional userID
  });

  @override
  State<EgzaminView> createState() => _EgzaminViewState();
}

class _EgzaminViewState extends State<EgzaminView> {
  List<dynamic> questions = [];
  int current = 0;
  String? selectedAnswer;
  bool isLoading = true;
  List<String?> selectedAnswers = [];
  late DateTime startTime;

  @override
  void initState() {
    super.initState();
    fetchQuestions();
    startTime = DateTime.now();
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

  Future<void> fetchQuestions() async {
    final kwalifikacja = widget.kwalifikacja.replaceAll(' ', '');
    final url = Uri.parse('https://interpage.pl/egzaminy/$kwalifikacja.php');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
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

          setState(() {
            questions = selected;
            selectedAnswers = List.filled(selected.length, null);
            isLoading = false;
            print('Załadowano ${questions.length} pytań');
            print('selectedAnswers: $selectedAnswers');
          });
        } else {
          print('Pusta lub niepoprawna odpowiedź z API');
        }
      } else {
        print('Błąd HTTP: ${response.statusCode}');
      }
    } catch (e) {
      print("Błąd przy pobieraniu pytań: $e");
    }
  }

  Future<void> sendResultToServer({
  required String kwalifikacja,
  required double wynik,
  required String dataCzas,
  required int czasTrwania,
}) async {
  // Use widget.userID if available, otherwise fall back to SharedPreferences
  String userName = widget.userName ?? (await SharedPreferences.getInstance()).getString('userName') ?? 'anonymous';

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
    print('❌ Błąd przy zapisywaniu wyniku: ${response.body}');
  } else {
    print('✅ Wynik zapisany dla userName: $userName');
  }
}

  void checkAnswer(String answer) {
    setState(() {
      selectedAnswer = answer;
      selectedAnswers[current] = answer;
    });
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
      body: widget.tryb == TrybEgzaminu.jednoPytanie
          ? _buildSingleQuestion(questions.first)
          : _buildScrollableList(),
      bottomNavigationBar: widget.tryb == TrybEgzaminu.czterdziesciPytan
          ? Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton(
                onPressed: () async {
                  final correct = calculateCorrectAnswers();
                  final total = questions.length;
                  final percent = (correct / total) * 100;
                  final endTime = DateTime.now();
                  final duration = endTime.difference(startTime).inSeconds;

                  await sendResultToServer(
                    kwalifikacja: widget.kwalifikacja,
                    wynik: percent,
                    dataCzas: endTime.toIso8601String(),
                    czasTrwania: duration,
                  );

                  print('Przekazywanie do EgzaminWynikView:');
                  print('questions: ${questions.length} pytań');
                  print('selectedAnswers: $selectedAnswers');

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EgzaminWynikView(
                        correctAnswers: correct,
                        totalQuestions: total,
                        questions: questions,
                        selectedAnswers: selectedAnswers,
                        isDarkMode: widget.isDarkMode,
                        returnToHome: true, // Set to true after completing exam
                      ),
                      settings: const RouteSettings(name: 'EgzaminWynikView'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: widget.isDarkMode ? Colors.white : Colors.black,
                ),
                child: const Text("Zakończ egzamin"),
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
        "body": Style(
          color: widget.isDarkMode ? Colors.white : Colors.grey[800],
        ),
        "b": Style(
          color: widget.isDarkMode ? Colors.white : Colors.grey[800],
        ),
        "span": Style(
          color: html.contains("style='color:green;'")
              ? Colors.green
              : widget.isDarkMode
                  ? Colors.white
                  : Colors.grey[800],
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
                  builder: (context) => Center(
                    child: Tooltip(
                      message: 'Kliknij, aby powiększyć',
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => _showImageDialog(context, src),
                          child: Image.network(
                            src,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Text(
                              '❌ Nie udało się załadować obrazka',
                              style: TextStyle(
                                color: widget.isDarkMode ? Colors.white : Colors.grey[800],
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
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white : Colors.grey[800],
              ),
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
                backgroundColor: Colors.black.withOpacity(0.9),
                body: Stack(
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: () {},
                        child: Listener(
                          onPointerDown: (_) => setState(() => isPressed = true),
                          onPointerUp: (_) => setState(() => isPressed = false),
                          child: MouseRegion(
                            cursor: isPressed ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
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
                                    color: widget.isDarkMode ? Colors.white : Colors.grey[800],
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
                          color: widget.isDarkMode ? Colors.white : Colors.black,
                        ),
                        tooltip: 'Zamknij',
                        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
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
          _html("<h3>Pytanie:</h3>${q['pytanie']}"),
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
                  foregroundColor: widget.isDarkMode ? Colors.white : Colors.black,
                ),
                onPressed: () => checkAnswer(litera),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: Colors.blue,
                foregroundColor: widget.isDarkMode ? Colors.white : Colors.black,
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
                _html("<b>Pytanie ${index + 1}:</b><br>${q['pytanie']}"),
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
                        foregroundColor: widget.isDarkMode ? Colors.white : Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          selectedAnswers[index] = litera;
                        });
                      },
                      child: _html(odp ?? ""),
                    ),
                  );
                }).toList(),
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
        cursor: _isPressed ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            widget.imageUrl,
            fit: BoxFit.contain,
            width: screenSize.width * 0.9,
            errorBuilder: (context, error, stackTrace) => Text(
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