import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'wyniki.dart';

enum TrybEgzaminu { jednoPytanie, czterdziesciPytan, wszystkie }

class EgzaminView extends StatefulWidget {
  final TrybEgzaminu tryb;
  final String kwalifikacja; 

  const EgzaminView({
    super.key,
    required this.tryb,
    required this.kwalifikacja, 
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
  List<String> pytania = [];
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
  print("📌 Kwalifikacja: ${widget.kwalifikacja}");
  print("🌐 URL: $url");
  try {
    final response = await http.get(url);
    print("✅ Status code: ${response.statusCode}");
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
        });
      }
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
  final url = Uri.parse('https://interpage.pl/egzaminy/zapisz_wynik.php');
  final response = await http.post(
  url,
  headers: {
    'Content-Type': 'application/x-www-form-urlencoded',
    'Authorization': 'Bearer zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^', // TOKEN
  },
  body: {
    'kwalifikacja': kwalifikacja.replaceAll(' ', ''),
    'wynik': wynik.toStringAsFixed(2),
    'data_czas': dataCzas,
    'czas_trwania': czasTrwania.toString(),
  },
  );

  if (response.statusCode != 200) {
    print('❌ Błąd przy zapisywaniu wyniku: ${response.body}');
  } else {
    print('✅ Wynik zapisany');
  }
}
  void checkAnswer(String answer) {
    setState(() {
      selectedAnswer = answer;
    });
  }

  void nextQuestion() {
    if (current < questions.length - 1) {
      setState(() {
        current++;
        selectedAnswer = null;
      });
    }
  }

  void prevQuestion() {
    if (current > 0) {
      setState(() {
        current--;
        selectedAnswer = null;
      });
    }
  }

  void jumpToQuestion(String value) {
    final number = int.tryParse(value);
    if (number != null && number >= 1 && number <= questions.length) {
      setState(() {
        current = number - 1;
        selectedAnswer = null;
      });
    }
  }

@override
Widget build(BuildContext context) {
  if (isLoading) {
    return Scaffold(
      appBar: AppBar(title: Text('Egzamin')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  if (questions.isEmpty) {
    return Scaffold(
      appBar: AppBar(title: Text('Egzamin')),
      body: const Center(child: Text('Brak pytań do wyświetlenia.')),
    );
  }

return Scaffold(
  appBar: AppBar(title: const Text("Egzamin")),
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

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EgzaminWynikView(
                    correctAnswers: correct,
                    totalQuestions: total,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
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
                          errorBuilder: (context, error, stackTrace) =>
                              const Text('❌ Nie udało się załadować obrazka'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          return const Text('⚠️ Brak obrazka');
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
            // Zamykanie po kliknięciu w dowolne tło
            onTap: () => Navigator.of(context, rootNavigator: true).pop(),
            child: Scaffold(
              backgroundColor: Colors.black.withOpacity(0.9),
              body: Stack(
                children: [
                  // interaktywne zdjęcie – blokuje tylko środek
                  Center(
                    child: GestureDetector(
                      // Blokujemy kliknięcia na sam obrazek (żeby go nie zamykać)
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
                              errorBuilder: (context, error, stackTrace) =>
                                  const Text(
                                '❌ Nie udało się załadować obrazka',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Przycisk X
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 30, color: Colors.white),
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



  Widget _buildSingleQuestion(dynamic q) {
  return Padding(
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
                  foregroundColor: Colors.white,
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
              foregroundColor: Colors.white,
            ),
          ),
        )
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
                final isCorrect = litera == q['poprawna'];
                final isWrong = selected == litera && !isCorrect;

                Color? buttonColor;
                if (selected != null) {
                  if (isCorrect) buttonColor = Colors.green;
                  if (isWrong) buttonColor = Colors.red;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        selectedAnswers[index] = litera;
                      });
                    },
                    child: _html(odp ?? "")
                  ),
                );
              }).toList(),
              const SizedBox(height: 6),
              if (selected != null)
              _html(
                selected == q['poprawna']
                    ? "<b>✅ Odpowiedź $selected jest poprawna.<br>${q['opisPoprawne']}</b>"
                    : "<b>❌ Odpowiedź $selected jest niepoprawna.<br>${q['opisNiepoprawne']}</b>",
              ),
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
            width: screenSize.width * 0.9,   // 🔥 WYMUSZAMY większy rozmiar
            errorBuilder: (context, error, stackTrace) => const Text(
              '❌ Nie udało się załadować obrazka',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }


}
