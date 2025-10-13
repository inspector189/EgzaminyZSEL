import 'package:flutter/material.dart';
import 'egzamin.dart';

class QualificationPage extends StatelessWidget {
  const QualificationPage({super.key, required this.qualification});

  final String qualification;

  Widget _buildQuestionsBox(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(Icons.assignment, size: 50, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final returnToHome = args?['returnToHome'] ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(qualification),
        backgroundColor: Theme.of(context).colorScheme.primary,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
        child: Center(
          child: Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              _buildQuestionsBox(
                context,
                title: 'Losuj 1 pytanie',
                subtitle: 'Sprawdź swoją wiedzę',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => EgzaminView(
                            tryb: TrybEgzaminu.jednoPytanie,
                            kwalifikacja: qualification
                                .toLowerCase()
                                .replaceAll('.', ''),
                            returnToHome: false,
                          ),
                    ),
                  );
                },
              ),
              _buildQuestionsBox(
                context,
                title: 'Test 40 losowych pytań',
                subtitle: 'Pełny egzamin próbny',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => EgzaminView(
                            tryb: TrybEgzaminu.czterdziesciPytan,
                            kwalifikacja: qualification
                                .toLowerCase()
                                .replaceAll('.', ''),
                            returnToHome: false,
                          ),
                    ),
                  );
                },
              ),
              _buildQuestionsBox(
                context,
                title: 'Baza wszystkich odpowiedzi',
                subtitle: 'Przeglądaj wszystkie pytania',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => EgzaminView(
                            tryb: TrybEgzaminu.wszystkie,
                            kwalifikacja: qualification
                                .toLowerCase()
                                .replaceAll('.', ''),
                            returnToHome: false,
                          ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
