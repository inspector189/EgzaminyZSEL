// published_tests_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../egzamin.dart'; // bo używasz EgzaminView
import 'CreatingTestsAndReportsPage.dart' hide publishedTestsUrl, apiToken; // bo używasz RichQuestionWidget
import 'utils/helpers.dart';

class PublishedTestsPage extends StatefulWidget {
  final String qualification;
  const PublishedTestsPage({super.key, required this.qualification});

  @override
  State<PublishedTestsPage> createState() => _PublishedTestsPageState();
}

class _PublishedTestsPageState extends State<PublishedTestsPage> {
  List<Map<String, dynamic>> publishedTests = [];
  bool isLoading = true;
  @override
  void initState() {
    super.initState();
    _loadPublishedTests();
  }
String normalizeQualification(String q) {
  return q
      .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '') // usuwa wszystko poza literami i cyframi
      .toLowerCase();
}
void _loadPublishedTests() async {
  setState(() {
    isLoading = true;
    publishedTests = [];
  }); // reset i pokazanie loading

  final prefs = await SharedPreferences.getInstance();
  List<Map<String, dynamic>> localPublished = [];

  // 1. Pobierz lokalnie zapisane testy
  final savedTestsJson = prefs.getString('saved_tests');
  if (savedTestsJson != null) {
    final allTests = (json.decode(savedTestsJson) as List)
        .cast<Map<String, dynamic>>();
    localPublished = allTests.where((t) => t['published'] == true).toList();
  }
  
  try {
    // 2. Pobierz testy z serwera
    final response = await http.get(
      Uri.parse(publishedTestsUrl),
      headers: {'Authorization': 'Bearer $apiToken'},
    );

    if (response.statusCode == 200) {
      final serverTests = (json.decode(response.body) as List)
          .cast<Map<String, dynamic>>();

      // 3. Usuń duplikaty po 'name' + 'qualification'
      final Map<String, Map<String, dynamic>> merged = {};
      for (final t in [...localPublished, ...serverTests]) {
        final key = '${t['name']}||${t['qualification']}';
        if (t['questions'] != null && (t['questions'] as List).isNotEmpty) {
          if (normalizeQualification(t['qualification']) != normalizeQualification(widget.qualification)) {
            continue; 
          }
          merged[key] = t;
        }
      }

      setState(() {
        publishedTests = merged.values.toList();
        isLoading = false;
      });
    } else {
        setState(() {
          publishedTests = localPublished;
          isLoading = false;
        });
      }

    } catch (_) {
      setState(() {
        publishedTests = localPublished;
        isLoading = false;
      });
    }
}



 @override
Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Testy z zestawu')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }


    if (publishedTests.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Testy z zestawu')),
        body: const Center(
          child: Text(
            'Brak testów w tej kwalifikacji',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

  return Scaffold(
    appBar: AppBar(title: const Text('Testy z zestawu')),
    body: ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: publishedTests.length,
      itemBuilder: (context, i) {
        final test = publishedTests[i];
        final questionCount = (test['questions'] as List?)?.length ?? 0;

        return Card(
          child: ListTile(
            leading: const Icon(Icons.quiz, size: 40, color: Colors.blue),
            title: Text(test['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Autor: ${test['author']} • $questionCount pytań'),
            onTap: () {
              if (questionCount == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test nie zawiera pytań'))
                );
                return;
              }
              final shuffledTest = Map<String, dynamic>.from(test);
                shuffledTest['questions'] = List<Map<String, dynamic>>.from(test['questions']).toList()..shuffle();

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EgzaminView(
                      tryb: TrybEgzaminu.zTestu,
                      kwalifikacja: test['qualification'],
                      returnToHome: false,
                      userName: null,
                      testData: shuffledTest, // przekazujemy pytania w losowej kolejności
                    ),
                  ),
                );
              },
          ),
        );
      },
    ),
  );
}
}
