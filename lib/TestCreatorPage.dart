// test_creator_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html_unescape/html_unescape.dart';
import 'CreatingTestsAndReportsPage.dart';

// Ważne: RichQuestionWidget musi być dostępny w tym pliku lub zaimportowany z innego pliku
// Jeśli masz go w creating_tests_and_reports_page.dart – zaimportuj go tak:
// import 'creating_tests_and_reports_page.dart' show RichQuestionWidget;

enum TestCreationMode { random, manual }

class TestCreatorPage extends StatefulWidget {
  final String qualification;
  final TestCreationMode mode;

  const TestCreatorPage({
    super.key,
    required this.qualification,
    required this.mode,
  });

  @override
  State<TestCreatorPage> createState() => _TestCreatorPageState();
}

class _TestCreatorPageState extends State<TestCreatorPage> {
  final TextEditingController _nameController = TextEditingController();

  List<dynamic> allQuestions = [];
  List<dynamic> selectedQuestions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    final url = Uri.parse(
        'https://egzaminy.zsel.edu.pl/egzaminy/${widget.qualification}.php');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final List<dynamic> data = json.decode(response.body);
        final unescape = HtmlUnescape();

        for (var q in data) {
          // Teksty
          q['pytanie_text'] = unescape.convert(q['pytanie'] ?? '');
          for (int i = 1; i <= 4; i++) {
            q['odp${i}_text'] = unescape.convert(q['odp$i'] ?? '');
          }

          // Obrazki – dokładnie jak w Twoim działającym egzamin.dart
          q['pytanie_images'] = (q['images'] as List?)?.cast<String>() ?? [];
          for (int i = 1; i <= 4; i++) {
            q['odp${i}_images'] = (q['odp${i}_images'] as List?)?.cast<String>() ?? [];
          }

          // Filmy (opcjonalnie)
          q['pytanie_videos'] = (q['videos'] as List?)?.cast<String>() ?? [];
          for (int i = 1; i <= 4; i++) {
            q['odp${i}_videos'] = (q['odp${i}_videos'] as List?)?.cast<String>() ?? [];
          }
        }

        setState(() {
          allQuestions = data;
          isLoading = false;

          if (widget.mode == TestCreationMode.random) {
            final shuffled = List.of(data)..shuffle();
            selectedQuestions = shuffled.take(40).toList();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd ładowania pytań: $e')),
        );
      }
      setState(() => isLoading = false);
    }
  }

  void _toggleQuestion(dynamic question) {
    setState(() {
      if (selectedQuestions.contains(question)) {
        selectedQuestions.remove(question);
      } else if (selectedQuestions.length < 40) {
        selectedQuestions.add(question);
      }
    });
  }

  Future<void> _saveTest() async {
  final name = _nameController.text.trim();
  if (name.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Podaj nazwę testu!')),
    );
    return;
  }

  if (selectedQuestions.length != 40) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wybierz dokładnie 40 pytań!')),
    );
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final userName = prefs.getString('userName') ?? 'Nauczyciel';

  // KLUCZOWE POPRAWKI:
  final cleanQual = widget.qualification
      .replaceAll('.', '')
      .replaceAll(' ', '')
      .toLowerCase(); // np. "inf02"

  final newTest = {
    'name': name,
    'qualification': cleanQual,        // ← bez kropek, małe litery
    'author': userName,
    'createdAt': DateTime.now().toIso8601String(),
    'published': false,                // ← domyślnie nieopublikowany
    'results': <Map<String, dynamic>>[], // ← pusta lista wyników
    'questions': selectedQuestions,   // ← już z _text, _images itd.
  };

  // Pobieramy istniejące testy
  final String? existingJson = prefs.getString('saved_tests');
  List<dynamic> allTests = [];
  if (existingJson != null && existingJson.isNotEmpty) {
    try {
      allTests = json.decode(existingJson) as List<dynamic>;
    } catch (e) {
      allTests = [];
    }
  }

  // Dodajemy nowy
  allTests.add(newTest);

  // Zapisujemy
  await prefs.setString('saved_tests', json.encode(allTests));

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test zapisany! Przejdź do „Utworzone testy” → opublikuj'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
    Navigator.pop(context); // wracamy do listy testów
  }
}

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mode == TestCreationMode.random
              ? 'Losowy test – ${widget.qualification.toUpperCase()}'
              : 'Ręczny dobór pytań',
        ),
      ),
      body: Column(
        children: [
          // Górny panel z nazwą i przyciskiem zapisu
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nazwa testu',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        'Wybrano: ${selectedQuestions.length}/40',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: selectedQuestions.length == 40 ? Colors.green : Colors.red,
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: selectedQuestions.length == 40 ? _saveTest : null,
                      icon: const Icon(Icons.save),
                      label: const Text('Zapisz test'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista pytań
          Expanded(
            child: widget.mode == TestCreationMode.random
                // Tryb losowy – tylko podgląd wybranych
                ? ListView.builder(
                    itemCount: selectedQuestions.length,
                    itemBuilder: (context, i) {
                      final q = selectedQuestions[i];
                      return RichQuestionWidget(
                        question: q,
                        number: i + 1,
                        qualification: widget.qualification,
                      );
                    },
                  )
                // Tryb ręczny – wybór pytań
                : ListView.builder(
                    itemCount: allQuestions.length,
                    itemBuilder: (context, i) {
                      final q = allQuestions[i];
                      final isSelected = selectedQuestions.contains(q);
                      return CheckboxListTile(
                        controlAffinity: ListTileControlAffinity.leading,
                        secondary: CircleAvatar(
                          child: Text('${i + 1}'),
                        ),
                        title: Text(
                          q['pytanie_text'],
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15),
                        ),
                        subtitle: q['pytanie_images'].isNotEmpty
                            ? const Text('Z obrazkiem', style: TextStyle(color: Colors.blue))
                            : null,
                        value: isSelected,
                        onChanged: (_) => _toggleQuestion(q),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}