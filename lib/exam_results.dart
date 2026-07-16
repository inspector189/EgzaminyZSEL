import 'package:flutter/material.dart';

import 'exam_preview.dart';

import '/utils/app_themes.dart';

class ExamResultsPage extends StatelessWidget {
  final int correctAnswers;
  final int totalQuestions;
  final List<dynamic> questions;
  final List<String?> selectedAnswers;
  final bool returnToHome;

  const ExamResultsPage({
    super.key,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.questions,
    required this.selectedAnswers,
    required this.returnToHome,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<ExtraColors>()!;
    final percentage = (correctAnswers / totalQuestions) * 100;
    final bool passingGrade = percentage >= 50;

    final resultText = "$correctAnswers / $totalQuestions";
    final message = passingGrade
        ? "Gratulacje! Zdałeś egzamin!"
        : "Niestety, nie udało się zdać egzaminu";

    final color = passingGrade ? extras.correct : extras.incorrect;

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
          child: IntrinsicWidth(
            stepWidth: 56,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 280, maxWidth: 400),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 32,
                    horizontal: 32,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: correctAnswers / totalQuestions,
                              strokeWidth: 10,
                              backgroundColor: extras.incorrect.withValues(
                                alpha: 0.3,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                            Center(
                              child: Icon(
                                passingGrade
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color: color,
                                size: 56,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Column(
                        children: [
                          Text(
                            resultText,
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 16,
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      if (questions.isNotEmpty && selectedAnswers.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExamPreviewPage(
                                  questions: questions,
                                  selectedAnswers: selectedAnswers,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.visibility),
                          label: const Text("Podgląd egzaminu"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                          ),
                        ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst),
                        child: const Text("Wróć do strony głównej"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
