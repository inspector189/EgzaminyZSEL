import 'package:flutter/material.dart';
import 'package:flutter_app/app_themes.dart';
import 'egzamin_podglad.dart';

class EgzaminWynikView extends StatelessWidget {
  final int correctAnswers;
  final int totalQuestions;
  final List<dynamic> questions;
  final List<String?> selectedAnswers;
  final bool returnToHome;

  const EgzaminWynikView({
    super.key,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.questions,
    required this.selectedAnswers,
    required this.returnToHome,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final extras = theme.extension<ExtraColors>()!;
    final percentage = (correctAnswers / totalQuestions) * 100;
    final bool zdane = percentage >= 50;

    final resultText = "$correctAnswers / $totalQuestions";
    final message =
        zdane
            ? "Gratulacje! Zdałeś egzamin!"
            : "Niestety, nie udało się zdać egzaminu";

    final color = zdane ? extras.correct : extras.incorrect;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Wynik egzaminu"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (returnToHome) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Divider(thickness: 4, color: color),
              const SizedBox(height: 16),
              Text("Twój wynik:", style: TextStyle(fontSize: 20)),
              Text(
                resultText,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 16),
              Divider(thickness: 4, color: color),
              const SizedBox(height: 24),
              if (questions.isNotEmpty && selectedAnswers.isNotEmpty)
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => EgzaminPodgladView(
                              questions: questions,
                              selectedAnswers: selectedAnswers,
                            ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    backgroundColor: colorScheme.primary,
                  ),
                  child: Text(
                    "Podgląd egzaminu",
                    style: TextStyle(color: colorScheme.onPrimary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
