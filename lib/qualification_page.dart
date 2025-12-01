import 'package:flutter/material.dart';
import 'egzamin.dart';
import 'edit_questions.dart';
import 'widgets/question_tile.dart';
import 'published_test_page.dart';

class QualificationPage extends StatelessWidget {
  const QualificationPage({
    super.key,
    required this.qualification,
    required this.isAdmin,
  });

  final String qualification;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final returnToHome = args?['returnToHome'] ?? false;

    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = screenWidth < 600 ? screenWidth - 40 : 300.0;

    final tiles = [
      QuestionTile(
        icon: Icons.filter_1,
        code: 'Losuj 1 pytanie',
        label: 'Sprawdź swoją wiedzę',
        showCount: false,
        onTap: (_) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => EgzaminView(
                    tryb: TrybEgzaminu.jednoPytanie,
                    kwalifikacja: qualification.toLowerCase().replaceAll(
                      '.',
                      '',
                    ),
                    returnToHome: false,
                  ),
            ),
          );
        },
      ),
      QuestionTile(
        icon: Icons.list_alt,
        code: 'Test 40 losowych pytań',
        label: 'Pełny egzamin próbny',
        showCount: false,
        onTap: (_) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => EgzaminView(
                    tryb: TrybEgzaminu.czterdziesciPytan,
                    kwalifikacja: qualification.toLowerCase().replaceAll(
                      '.',
                      '',
                    ),
                    returnToHome: false,
                  ),
            ),
          );
        },
      ),
      QuestionTile(
        icon: Icons.library_books,
        code: 'Baza wszystkich pytań',
        label: 'Przeglądaj wszystkie pytania',
        showCount: false,
        onTap: (_) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => EgzaminView(
                    tryb: TrybEgzaminu.wszystkie,
                    kwalifikacja: qualification.toLowerCase().replaceAll(
                      '.',
                      '',
                    ),
                    returnToHome: false,
                  ),
            ),
          );
        },
      ),
      QuestionTile(
        icon: Icons.assignment_turned_in,
        code: 'Testy z zestawu nauczyciela',
        label: 'Opublikowane zestawy pytań przez nauczycieli',
        showCount: false,
        onTap: (_) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PublishedTestsPage(qualification: qualification),
            ),
          );
        },
      )
    ];
    if (isAdmin) {
      tiles.add(
        QuestionTile(
          icon: Icons.edit_note,
          code: 'Edytuj pytania',
          label: 'Zarządzaj bazą egzaminów',
          showCount: false,
          onTap: (_) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => EditQuestionsPage(
                      qualification: qualification.toLowerCase().replaceAll(
                        '.',
                        '',
                      ),
                    ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(qualification),
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
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 20,
            children:
                tiles.map((tile) {
                  return SizedBox(width: itemWidth, child: tile);
                }).toList(),
          ),
        ),
      ),
    );
  }
}
