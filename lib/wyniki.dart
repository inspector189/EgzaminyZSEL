import 'package:flutter/material.dart';

class EgzaminWynikView extends StatelessWidget {
  final int correctAnswers;
  final int totalQuestions;


  const EgzaminWynikView({
    Key? key,
    required this.correctAnswers,
    required this.totalQuestions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentage = (correctAnswers / totalQuestions) * 100;
    final bool zdane = percentage >= 75;

    final resultText = "$correctAnswers / $totalQuestions";
    final message = zdane
        ? "Gratulacje!!! Zdajesz!"
        : "Niestety, nie udało się zdać";

    final color = zdane ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(title: const Text("Wynik egzaminu")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Divider(thickness: 4, color: color),
              const SizedBox(height: 16),
              Text(
                "Twój wynik:",
                style: TextStyle(fontSize: 20),
              ),
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
            ],
          ),
        ),
      ),
    );
  }
}
