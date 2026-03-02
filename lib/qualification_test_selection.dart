import 'package:flutter/material.dart';
import 'exam_solving.dart';
import 'question_editing.dart';
import 'widgets/question_tile.dart';
import 'published_test_view.dart';

class QualificationPage extends StatelessWidget {
  const QualificationPage({
    super.key,
    required this.qualification,
    required this.isAdmin,
    required this.isLoggedIn,
  });

  final String qualification;
  final bool isAdmin;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final args = route?.settings.arguments;
    final returnToHome =
        args is Map<String, dynamic> && args['returnToHome'] == true;

    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = screenWidth < 600 ? screenWidth - 40 : 300.0;

    final sanitizedQualification = qualification.toLowerCase().replaceAll(
      '.',
      '',
    );

    final tiles = [
      QuestionTile(
        icon: Icons.filter_1,
        code: 'Losuj 1 pytanie',
        label: 'Sprawdź swoją wiedzę',
        showCount: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => EgzaminView(
                    tryb: TrybEgzaminu.jednoPytanie,
                    kwalifikacja: sanitizedQualification,
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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => EgzaminView(
                    tryb: TrybEgzaminu.czterdziesciPytan,
                    kwalifikacja: sanitizedQualification,
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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => EgzaminView(
                    tryb: TrybEgzaminu.wszystkie,
                    kwalifikacja: sanitizedQualification,
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
        onTap: () {
          if (isLoggedIn) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => PublishedTestsPage(qualification: qualification),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.login, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Aby rozwiązać test od nauczyciela musisz się zalogować!',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    ];
    if (isAdmin) {
      tiles.add(
        QuestionTile(
          icon: Icons.edit_note,
          code: 'Edytuj pytania',
          label: 'Zarządzaj bazą egzaminów',
          showCount: false,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => EditQuestionsPage(
                      qualification: sanitizedQualification,
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
