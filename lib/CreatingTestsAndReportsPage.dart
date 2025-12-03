import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:universal_html/js_util.dart' as js_util;
import 'package:web/web.dart' as web;
import 'package:html_unescape/html_unescape.dart';
import 'dart:js_interop' as js_interop;
import 'TestCreatorPage.dart';
import 'utils/video_player.dart';

const String publishedTestsUrl = 'https://egzaminy.zsel.edu.pl/egzaminy/publishedTests.php';
const String allTestsUrl = 'https://egzaminy.zsel.edu.pl/egzaminy/publishedTests_admin.php';
const String apiToken = 'zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^';
// =============================
// WIDGET Z OBRAZKAMI
// =============================
 class RichQuestionWidget extends StatelessWidget {
  final Map<String, dynamic> question;
  final int number;
  final bool showAnswers;
  final String qualification;

  const RichQuestionWidget({
    super.key,
    required this.question,
    required this.number,
    this.showAnswers = true,
    required this.qualification,
  });

  @override
  Widget build(BuildContext context) {
    final unescape = HtmlUnescape();
    final pytanieText = unescape.convert(question['pytanie_text'] ?? '');
    final pytanieImages = (question['pytanie_images'] as List?)?.cast<String>() ?? [];
    final pytanieVideos = (question['pytanie_videos'] as List?)?.cast<String>() ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$number. $pytanieText', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Obrazki pytania
            ...pytanieImages.map((url) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  height: 220,
                  loadingBuilder: (_, child, __) => child,
                  errorBuilder: (_, __, ___) => const Text('Błąd obrazka'),
                ),
              ),
            )),
          ...pytanieVideos.map((url) => InlineVideoPlayer(
            url: url,
            height: 240,
          )),


            if (showAnswers) ...[
              const SizedBox(height: 12),
              ...[1, 2, 3, 4].map((idx) {
                final text = unescape.convert(question['odp${idx}_text'] ?? '').trim();
                final images = (question['odp${idx}_images'] as List?)?.cast<String>() ?? [];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Teraz tylko sama treść – litera A/B/C/D jest już w tekście!
                      Text(text, style: const TextStyle(fontSize: 15)),
                      ...images.map((url) => Padding(
                        padding: const EdgeInsets.only(top: 8, left: 20),
                        child: Image.network(
                          url,
                          width: 300,
                          height: 150,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Text('Błąd obrazka'),
                        ),
                      )),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

bool isValidQualification(String? qual) {
  if (qual == null) return false;
  final trimmed = qual.trim().toLowerCase();
  return RegExp(r'^[a-z]{3}\d{2}$').hasMatch(trimmed);
}

class CreatingTestsAndReportsPage extends StatefulWidget {
  const CreatingTestsAndReportsPage({super.key});

  @override
  State<CreatingTestsAndReportsPage> createState() => _CreatingTestsAndReportsPageState();
}

class _CreatingTestsAndReportsPageState extends State<CreatingTestsAndReportsPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final createdTestsTab = context.findAncestorStateOfType<_CreatedTestsTabState>();
    createdTestsTab?._loadTests();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tworzenie i zarządzanie testami')),
      body: Column(
        children: [
          Material(
            color: colorScheme.surface,
            elevation: 4,
            child: TabBar(
              controller: _tabController,
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
              indicatorColor: colorScheme.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              tabs: const [
                Tab(icon: Icon(Icons.list_alt), text: 'Utworzone testy', iconMargin: EdgeInsets.only(bottom: 4)),
                Tab(icon: Icon(Icons.add_circle_outline), text: 'Stwórz nowy test', iconMargin: EdgeInsets.only(bottom: 4)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                CreatedTestsTab(),
                CreateNewTestTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== PODGLĄD TESTU ====================
class TestPreviewPage extends StatelessWidget {
  final Map<String, dynamic> test;
  final VoidCallback onPublish;
  const TestPreviewPage({super.key, required this.test, required this.onPublish});

  @override Widget build(BuildContext context) {
    final questions = List<Map<String, dynamic>>.from(test['questions']);
    final qual = test['qualification'] as String;

    return Scaffold(
      appBar: AppBar(title: Text(test['name']), actions: [
        IconButton(icon: const Icon(Icons.publish, color: Colors.green), tooltip: 'Publikuj', onPressed: () { onPublish(); Navigator.pop(context); }),
      ]),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        itemBuilder: (context, i) => RichQuestionWidget(
          question: questions[i],
          number: i + 1,
          qualification: qual,
        ),
      ),
    );
  }
}
// ==================== ZAKŁADKA: UTWORZONE TESTY ====================
class CreatedTestsTab extends StatefulWidget { const CreatedTestsTab({super.key}); @override State<CreatedTestsTab> createState() => _CreatedTestsTabState(); }

class _CreatedTestsTabState extends State<CreatedTestsTab> {
  List<Map<String, dynamic>> savedTests = [];
  bool isLoadingResults = false; 
  bool isLoadingTests = true; 
  bool isSuperAdmin = false;
    String currentUser = "";
    final String _apiBaseUrl = 'https://egzaminy.zsel.edu.pl/egzaminy';

@override
void initState() {
  super.initState();
  _loadCurrentUser();
  _loadTests();
  _loadUserRole();
}

Future<void> _loadCurrentUser() async {
  final prefs = await SharedPreferences.getInstance();
  currentUser = prefs.getString("userName") ?? ""; 
  setState(() {});
}

Future<void> _loadUserRole() async {
  final prefs = await SharedPreferences.getInstance();
  final email = prefs.getString('userEmail');

  if (email == null || email.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brak danych logowania')),
      );
    }
    return;
  }

  try {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/is_super_admin.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        isSuperAdmin = data['isSuperAdmin'] == true;
      });

      prefs.setBool("isSuperAdmin", isSuperAdmin);
    }
  } catch (e) {
    if (kDebugMode) print('Błąd sprawdzania uprawnień: $e');
  }
}

Future<void> _loadTests() async {
  final prefs = await SharedPreferences.getInstance();

  setState(() => isLoadingTests = true); // 🔥 start ładowania

  try {
    // 1. Pobierz z serwera
    final response = await http.get(
      Uri.parse(allTestsUrl),
      headers: {
        'Authorization': 'Bearer $apiToken',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> serverTests = json.decode(response.body);
      final serverMaps = serverTests.cast<Map<String, dynamic>>();

      // Upewniamy się, że published jest bool
      for (final t in serverMaps) {
        final publishedVal = t['published'];
        bool published = false;
        if (publishedVal is bool) {
          published = publishedVal;
        } else if (publishedVal is num) {
          published = publishedVal == 1;
        } else if (publishedVal is String) {
          published = publishedVal == '1' || publishedVal.toLowerCase() == 'true';
        }
        t['published'] = published;

        t['results'] ??= [];
      }

      setState(() {
        savedTests = serverMaps; // 🚫 tylko z serwera
      });

      await prefs.setString('saved_tests', json.encode(savedTests));
      _loadAllResults();
    } else {
      // błąd serwera → fallback na cache
      final localData = prefs.getString('saved_tests');
      if (localData != null) {
        final localTests = List<Map<String, dynamic>>.from(json.decode(localData));
        setState(() => savedTests = localTests);
      } else {
        setState(() => savedTests = []);
      }
    }
  } catch (e) {
    // brak internetu → cache
    final localData = prefs.getString('saved_tests');
    if (localData != null) {
      final localTests = List<Map<String, dynamic>>.from(json.decode(localData));
      setState(() => savedTests = localTests);
    } else {
      setState(() => savedTests = []);
    }
  } finally {
    if (mounted) {
      setState(() => isLoadingTests = false); 
    }
  }
}




  Future<void> _loadAllResults() async {
    if (isLoadingResults) return;
    setState(() => isLoadingResults = true);

    for (int i = 0; i < savedTests.length; i++) {
      final test = savedTests[i];
      final testKey = '${test['name']}||${test['author']}||${test['qualification']}';

      try {
        final response = await http.post(
          Uri.parse('https://egzaminy.zsel.edu.pl/egzaminy/getPublishedResults.php'),
          headers: {
            'Authorization': 'Bearer $apiToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({'test_key': testKey}),
        );

        if (response.statusCode == 200) {
          final List<dynamic> results = json.decode(response.body);
          setState(() {
            savedTests[i]['results'] = results;
          });
        }
      } catch (e) {
        // cicho – brak wyników lub błąd połączenia
      }
    }

    setState(() => isLoadingResults = false);
  }

Future<void> _deleteTest(int index) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Usunąć test?'),
      content: Text('Czy na pewno chcesz usunąć "${savedTests[index]['name']}"?\n\nTest zostanie usunięty także z serwera (jeśli jest opublikowany).'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Usuń', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  final testToDelete = savedTests[index];

  // 1. Usuń z serwera (jeśli jest opublikowany)
  await _deleteTestFromServer(testToDelete);

  // 2. Usuń lokalnie
  setState(() => savedTests.removeAt(index));

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('saved_tests', json.encode(savedTests));

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test usunięty'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
Future<void> _deleteTestFromServer(Map<String, dynamic> test) async {
  try {
    final response = await http.post(
      Uri.parse(publishedTestsUrl), // https://egzaminy.zsel.edu.pl/egzaminy/publishedTests.php
      headers: {
        'Authorization': 'Bearer $apiToken',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'action': 'delete',           // nowa akcja
        'test': test,                 // cały test (name, qualification, author, itd.)
      }),
    );

    // Jeśli serwer zwróci 200 – sukces, nic nie robimy
    if (response.statusCode == 200) {
      debugPrint('Test usunięty z serwera');
      return;
    } else {
      debugPrint('Serwer zwrócił błąd: ${response.statusCode} ${response.body}');
    }
  } catch (e) {
    debugPrint('Błąd połączenia przy usuwaniu z serwera: $e');
    // Nie rzucamy wyjątku – i tak usuwamy lokalnie
  }
}
void _publishTest(int index) async {
  final test = savedTests[index];
  final bool willPublish = !(test['published'] ?? false);

  setState(() {
    test['published'] = willPublish;
  });

  // Zapis lokalny (cache)
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('saved_tests', json.encode(savedTests));

  // Wysyłka na serwer
  try {
      await http.post(
        Uri.parse(publishedTestsUrl),
        headers: {
          'Authorization': 'Bearer $apiToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'action': willPublish ? 'publish' : 'unpublish',
          'test': test,
        }),
      );
  } catch (e) {
    // Jeśli nie udało się wysłać – przywróć stan
    setState(() {
      test['published'] = !willPublish;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Brak internetu – publikacja zostanie zsynchronizowana później')),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(willPublish ? 'Test opublikowany dla wszystkich!' : 'Test wycofany z publikacji'),
      backgroundColor: willPublish ? Colors.green : Colors.orange,
    ),
  );
}

  web.Blob _createBlob(Uint8List bytes) => web.Blob([bytes.buffer.toJS].toJS, web.BlobPropertyBag(type: 'application/pdf'));

bool _testContainsVideo(Map<String, dynamic> test) {
  final questions = test['questions'] as List<dynamic>;
  for (var q in questions) {
    // film przy pytaniu
    final pytanieVideos = (q['pytanie_videos'] as List?)?.cast<String>() ?? [];
    if (pytanieVideos.isNotEmpty) return true;

    // filmy przy odpowiedziach
    for (int i = 1; i <= 4; i++) {
      final odpVideos = (q['odp${i}_videos'] as List?)?.cast<String>() ?? [];
      if (odpVideos.isNotEmpty) return true;
    }
  }
  return false;
}

  Future<void> _printTest(Map<String, dynamic> test) async {
    if (_testContainsVideo(test)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ten test zawiera filmy – nie można wygenerować PDF'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );
    return;
  }
  final questions = List<Map<String, dynamic>>.from(test['questions']);
  final pdf = pw.Document();
  final fontData = await rootBundle.load("assets/fonts/DejaVuSans.ttf");
  final ttf = pw.Font.ttf(fontData);
  final qual = test['qualification'] as String;

  // Pomocnicza funkcja do pobierania obrazków
List<String> getImages(Map<String, dynamic> q, String prefix) {
  if (prefix.isEmpty) {
    return (q['pytanie_images'] as List?)?.cast<String>() ?? [];
  }
  return (q['odp${prefix}_images'] as List?)?.cast<String>() ?? [];
}

  final header = pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 20),
    child: pw.Column(
      children: [        
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(children: [
              pw.Text('Imię i nazwisko:', style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: 10),
              pw.Container(width: 250, child: pw.Text('__________________________________', style: pw.TextStyle(font: ttf, fontSize: 14))),
              pw.SizedBox(width: 40),
              pw.Text('Klasa:', style: pw.TextStyle(font: ttf, fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: 10),
              pw.Container(width: 80, child: pw.Text('______', style: pw.TextStyle(font: ttf, fontSize: 14))),
            ]),
          ],
        ),

        pw.SizedBox(height: 12),

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(children: [
              pw.Text('Nr w dzienniku:', style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: 10),
              pw.Container(width: 60, child: pw.Text('________', style: pw.TextStyle(font: ttf, fontSize: 11))),
            ]),
            pw.Row(children: [
              pw.Text('Punkty:', style: pw.TextStyle(font: ttf, fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: 12),
              pw.Text('____', style: pw.TextStyle(font: ttf, fontSize: 11)),
              pw.Text(' / 40', style: pw.TextStyle(font: ttf, fontSize: 11)),
            ]),
          ],
        ),

        pw.SizedBox(height: 10),
        pw.Divider(thickness: 1.5),
        pw.SizedBox(height: 10),
      ],
    ),
  );

  final List<pw.Widget> pages = [];

  for (var e in questions.asMap().entries) {
    final i = e.key + 1;
    final q = e.value;
    final pytanieText = (q['pytanie_text'] ?? '').toString().trim();
    final pytanieImages = getImages(q, '');

    final List<pw.Widget> children = [
      pw.Text('$i. $pytanieText', style: pw.TextStyle(font: ttf, fontSize: 10, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 5),
    ];

    // Dodaj obrazki pytania
for (final url in pytanieImages) {
  try {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode == 200) {
      children.add(
        pw.Center(
          child: pw.SizedBox(
            width: 460,
            height: 300,
            child: pw.Image(
              pw.MemoryImage(resp.bodyBytes),
              fit: pw.BoxFit.contain,
            ),
          ),
        ),
      );
      children.add(pw.SizedBox(height: 11));
    }
  } catch (_) {}
}

    // Odpowiedzi A B C D
for (int idx = 1; idx <= 4; idx++) {
  final text = (q['odp${idx}_text'] ?? '').toString().trim();
  final images = (q['odp${idx}_images'] as List?)?.cast<String>() ?? [];

  children.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 20, top: 8, bottom: 4),
          child: pw.Text(
            text,
            style: pw.TextStyle(font: ttf, fontSize: 11),
          ),
        ),
      );

      for (final url in images) {
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        children.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 34, top: 8),
            child: pw.SizedBox(
              width: 380,
              height: 220,
              child: pw.Image(
                pw.MemoryImage(resp.bodyBytes),
                fit: pw.BoxFit.contain,
              ),
            ),
          ),
        );
      }
    } catch (_) {}
  }
  children.add(pw.SizedBox(height: 7));
}

    pages.add(pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children),
    ));
  }

  pdf.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.only(left: 50, right: 50, top: 40, bottom: 60),
    header: (ctx) => ctx.pageNumber == 1 ? header : pw.SizedBox(),
    footer: (ctx) => pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text('Strona ${ctx.pageNumber} / ${ctx.pagesCount}', style: pw.TextStyle(font: ttf, fontSize: 11, color: PdfColors.grey700)),
    ),
    build: (_) => pages,
  ));

  final bytes = await pdf.save();
  final filename = 'test_${test['name'].replaceAll(' ', '_')}.pdf';

  if (kIsWeb) {
    final blob = _createBlob(bytes);
    final url = web.URL.createObjectURL(blob);
    web.window.open(url, '_blank');
    Future.delayed(const Duration(seconds: 10), () => web.URL.revokeObjectURL(url));
  } else {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}

  @override
Widget build(BuildContext context) {
  if (isLoadingTests) {
    // 🔄 PHP jeszcze nie odpowiedział – pokazujemy loader
    return const Center(child: CircularProgressIndicator());
  }

  if (savedTests.isEmpty) {
    // dopiero po zakończeniu ładowania i braku danych
    return const Center(
      child: Text('Brak utworzonych testów', style: TextStyle(fontSize: 18)),
    );
  }

  return DefaultTabController(
    length: 2,
    child: Column(
      children: [
        const TabBar(
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: "Moje testy"),
            Tab(text: "Wszystkie testy"),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              _buildTestList(
                savedTests.where((t) => t['author'] == currentUser).toList(),
              ),
              _buildTestList(savedTests),
            ],
          ),
        ),
      ],
    ),
  );
}


Widget _buildTestList(List<Map<String, dynamic>> tests) {
  if (tests.isEmpty) {
    return const Center(
      child: Text('Brak testów', style: TextStyle(fontSize: 18)),
    );
  }

  return RefreshIndicator(
    onRefresh: () async {
      await _loadTests();
    },
    child: ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tests.length,
      itemBuilder: (context, i) {
        final t = tests[i];

        // znajdź indeks w głównej liście savedTests
        final realIndex = savedTests.indexOf(t);

        final results = (t['results'] as List<dynamic>?) ?? [];
        final isPublished = t['published'] == true;
        final canEdit = isSuperAdmin || t['author'] == currentUser;
        final sortedResults = results
          ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

        return Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: ExpansionTile(
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: isPublished ? Colors.green.shade600 : Colors.grey.shade600,
              child: Icon(isPublished ? Icons.public : Icons.lock_outline, color: Colors.white),
            ),
            title: Text(
              t['name'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kwalifikacja: ${t['qualification'].toUpperCase()} • Autor: ${t['author']}'),
                Text('${t['questions'].length} pytań • Utworzono: ${_formatDate(t['createdAt'])}'),
                if (results.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Wyników: ${results.length} • Średnia: ${(results.map((r) => r['score'] as num).reduce((a, b) => a + b) / results.length).toStringAsFixed(1)}%',
                    style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.visibility, color: Colors.blue), tooltip: 'Podgląd', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TestPreviewPage(test: t, onPublish: () => _publishTest(realIndex))))),
                IconButton(icon: const Icon(Icons.print), tooltip: 'Drukuj', onPressed: () => _printTest(t)),
               if (canEdit)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Usuń',
                    onPressed: () => _deleteTest(realIndex),
                  ),

                if (canEdit)
                  IconButton(
                    icon: Icon(
                      isPublished ? Icons.public : Icons.public_off,
                      color: isPublished ? Colors.green : Colors.grey[700],
                    ),
                    tooltip: isPublished ? 'Wycofaj' : 'Opublikuj',
                    onPressed: () => _publishTest(realIndex),
                  ),
                IconButton(
                  icon: const Icon(Icons.file_download, color: Colors.purple),
                  tooltip: 'Zrób raport z wyników',
                  onPressed: () => _generateReportPdf(t),
                ),
                IconButton(
                  icon: const Icon(Icons.key, color: Colors.teal),
                  tooltip: 'Klucz odpowiedzi',
                  onPressed: () => _generateAnswerKeyPdf(t),
                ),
              ],
            ),
            children: [
              if (results.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Brak wyników', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                )
              else
                ..._buildGroupedResults(sortedResults),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ),
  );
}

List<Widget> _buildGroupedResults(List<dynamic> results) {
  // Grupuj po userName
  final Map<String, List<dynamic>> grouped = {};
  for (var r in results) {
    final user = r['userName'] as String? ?? 'Nieznany';
    grouped[user] = grouped[user] ?? [];
    grouped[user]!.add(r);
  }

  final List<Widget> widgets = [];
  grouped.forEach((user, userResults) {
    // Posortuj wyniki użytkownika od najnowszego
    userResults.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    final latest = userResults.first;
    final latestScore = (latest['score'] as num?)?.toDouble() ?? 0.0;
    final latestDate = _formatDate(latest['date'] as String? ?? '');
    widgets.add(
      ExpansionTile(
        title: Text('$user - $latestDate - ${latestScore.toStringAsFixed(0)}%'),
        children: userResults.map((r) {
          final score = (r['score'] as num?)?.toDouble() ?? 0.0;
          final date = _formatDate(r['date'] as String? ?? '');
          final durationSec = (r['duration_sec'] as num?)?.toInt() ?? 0;
          final duration = Duration(seconds: durationSec);
          String twoDigits(int n) => n.toString().padLeft(2, '0');
          final hours = twoDigits(duration.inHours);
          final minutes = twoDigits(duration.inMinutes.remainder(60));
          final seconds = twoDigits(duration.inSeconds.remainder(60));
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: score >= 75
                  ? Colors.green
                  : score >= 50
                      ? Colors.orange
                      : Colors.red,
              child: Text(
                '${score.toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            title: Text(user, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Data: $date', style: TextStyle(color: Colors.grey[700])),
                Text('Czas trwania: $hours:$minutes:$seconds', style: TextStyle(color: Colors.grey[700])),
              ],
            ),
            
            trailing: Text('${score.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
          );
        }).toList(),
      ),
    );
  });

  return widgets;
}
Future<void> _generateAnswerKeyPdf(Map<String, dynamic> test) async {
  final String qual = test['qualification'];
  final questions = List<Map<String, dynamic>>.from(test['questions']);

  // Pobierz poprawne odpowiedzi z kwalifikacji.php
  final url = "https://egzaminy.zsel.edu.pl/egzaminy/$qual.php";

  List<dynamic> fullDb = [];
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      fullDb = json.decode(response.body);
    } else {
      throw Exception("Błąd połączenia: ${response.statusCode}");
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Nie można pobrać klucza odpowiedzi ($qual.php)")),
    );
    return;
  }

  // Tworzymy mapę ID → poprawna odpowiedź
  final Map<String, String> answerMap = {};
  for (final q in fullDb) {
    answerMap[q['id'].toString()] = q['poprawna'].toString().trim().toUpperCase();
  }

  // Generujemy dane klucza
  final List<List<String>> answerRows = [];
  for (int i = 0; i < questions.length; i++) {
    final q = questions[i];
    final id = q['id'].toString();

    final correct = answerMap[id] ?? "?";

    answerRows.add([
      (i + 1).toString(),
      correct,
    ]);
  }

  // --- PDF ---
  final pdf = pw.Document();
  final fontData = await rootBundle.load("assets/fonts/DejaVuSans.ttf");
  final ttf = pw.Font.ttf(fontData);

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        pw.Text(
          "Klucz Odpowiedzi — ${test['name']}",
          style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold, fontSize: 24),
        ),
        pw.SizedBox(height: 20),
        pw.Text("Kwalifikacja: ${qual.toUpperCase()}", style: pw.TextStyle(font: ttf, fontSize: 14)),
        pw.SizedBox(height: 20),

        pw.TableHelper.fromTextArray(
          headers: ["Nr pytania", "Poprawna"],
          data: answerRows,
          headerStyle: pw.TextStyle(font: ttf, fontSize: 12, fontWeight: pw.FontWeight.bold),
          cellStyle: pw.TextStyle(font: ttf, fontSize: 11),
          columnWidths: {
            0: const pw.FlexColumnWidth(0.5),
            1: const pw.FlexColumnWidth(1),
          },
        )
      ],
    ),
  );

  final bytes = await pdf.save();
  final filename = "klucz_${test['name'].replaceAll(' ', '_')}.pdf";

  if (kIsWeb) {
    final blob = _createBlob(bytes);
    final url = web.URL.createObjectURL(blob);
    web.window.open(url, '_blank');
    Future.delayed(const Duration(seconds: 5), () => web.URL.revokeObjectURL(url));
  } else {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
  
  Future<void> _generateReportPdf(Map<String, dynamic> test) async {
  final results = (test['results'] as List<dynamic>?) ?? [];
  if (results.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Brak wyników do raportu')),
    );
    return;
  }

  final pdf = pw.Document();
  final fontData = await rootBundle.load("assets/fonts/DejaVuSans.ttf");
  final ttf = pw.Font.ttf(fontData);

  // 🔹 Grupowanie: najpierw po UID (jeśli jest), inaczej po nazwie.
  // Dla każdej grupy bierzemy TYLKO najnowszy wynik.
  final Map<String, Map<String, dynamic>> lastResults = {};

  for (var r in results) {
    final name = (r['userName'] ?? 'Nieznany').toString();
    final uid = (r['uid'] ?? r['UID'] ?? '').toString();
    final key = uid.isNotEmpty ? uid : name;

    final dateStr = (r['date'] ?? '').toString();

    if (!lastResults.containsKey(key)) {
      lastResults[key] = Map<String, dynamic>.from(r);
    } else {
      final existingDate = (lastResults[key]!['date'] ?? '').toString();
      if (dateStr.compareTo(existingDate) > 0) {
        lastResults[key] = Map<String, dynamic>.from(r);
      }
    }
  }

  // 🔹 Przygotuj wiersze: name, uid, score, date
  final rows = lastResults.values.map((raw) {
    final r = raw as Map<String, dynamic>;
    final name = (r['userName'] ?? 'Nieznany').toString();
    final uid = (r['uid'] ?? r['UID'] ?? '').toString();

    final rawScore = r['score'];
    num? scoreNum;
    if (rawScore is num) {
      scoreNum = rawScore;
    } else {
      scoreNum = num.tryParse(rawScore?.toString() ?? '');
    }
    final score = scoreNum != null ? scoreNum.toStringAsFixed(2) : '-';

    final date = _formatDate((r['date'] ?? '').toString());

    return {
      'name': name,
      'uid': uid,
      'score': score,
      'date': date,
    };
  }).toList();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Center(
            child: pw.Text(
              'Raport wyników - ${test['name']}',
              style: pw.TextStyle(
                font: ttf,
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Data generowania: ${DateTime.now().toLocal().toString().split(' ')[0]}',
          style: pw.TextStyle(font: ttf, fontSize: 12),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Kwalifikacja: ${test['qualification'].toString().toUpperCase()}',
          style: pw.TextStyle(
            font: ttf,
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 20),

        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(2),
          },
          children: [
            // nagłówki
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'Użytkownik',
                    style: pw.TextStyle(
                      font: ttf,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'Wynik ostatniego egzaminu (%)',
                    style: pw.TextStyle(
                      font: ttf,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'Data',
                    style: pw.TextStyle(
                      font: ttf,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            // dane
            ...rows.map((row) {
              final name = row['name'] ?? '-';
              final uid = row['uid'] ?? '';
              final score = row['score'] ?? '-';
              final date = row['date'] ?? '-';

              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          name,
                          style: pw.TextStyle(
                            font: ttf,
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (uid.isNotEmpty)
                          pw.Text(
                            'UID: $uid',
                            style: pw.TextStyle(
                              font: ttf,
                              fontSize: 9, // mniejsza czcionka
                            ),
                          ),
                      ],
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      '$score%',
                      style: pw.TextStyle(font: ttf, fontSize: 11),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      date,
                      style: pw.TextStyle(font: ttf, fontSize: 11),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    ),
  );

  final bytes = await pdf.save();
  final filename = 'raport_${test['name'].replaceAll(' ', '_')}.pdf';

  if (kIsWeb) {
    final blob = _createBlob(bytes);
    final url = web.URL.createObjectURL(blob);
    web.window.open(url, '_blank');
    Future.delayed(
      const Duration(seconds: 5),
      () => web.URL.revokeObjectURL(url),
    );
  } else {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}



}

// ==================== ZAKŁADKA: STWÓRZ NOWY TEST ====================
class CreateNewTestTab extends StatefulWidget {
  const CreateNewTestTab({super.key});
  @override
  State<CreateNewTestTab> createState() => _CreateNewTestTabState();
}

class _CreateNewTestTabState extends State<CreateNewTestTab> {
  String? selectedQualification;
  List<String> qualifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQualificationsFromServer();
  }

  Future<void> _loadQualificationsFromServer() async {
    try {
      final response = await http.post(
        Uri.parse('https://egzaminy.zsel.edu.pl/egzaminy/egzaminy_wyniki_post.php'),
        headers: {'Authorization': 'Bearer $apiToken', 'Content-Type': 'application/json'},
        body: json.encode({}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> allData = json.decode(response.body);
        final Set<String> quals = {};
        for (final exam in allData) {
          final q = (exam['kwalifikacja'] ?? '').toString().trim().replaceAll(' ', '').toLowerCase();
          if (isValidQualification(q)) quals.add(q);
        }
        setState(() {
          qualifications = quals.toList()..sort();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (qualifications.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Brak dostępnych kwalifikacji.\nUpewnij się, że ktoś już zdawał egzaminy.', textAlign: TextAlign.center)));
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: selectedQualification,
            isExpanded: true,
            dropdownColor: Theme.of(context).colorScheme.surface,
            menuMaxHeight: 400,
            decoration: const InputDecoration(labelText: 'Wybierz kwalifikację', border: OutlineInputBorder()),
            items: qualifications.map((q) => DropdownMenuItem(value: q, child: Text(q.toUpperCase(), style: const TextStyle(fontSize: 16)))).toList(),
            onChanged: (v) => setState(() => selectedQualification = v),
          ),
          const SizedBox(height: 40),
          if (selectedQualification != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.shuffle),
                  label: const Text('Losowe 40 pytań'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TestCreatorPage(qualification: selectedQualification!, mode: TestCreationMode.random))),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.handyman),
                  label: const Text('Ręczny dobór pytań'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TestCreatorPage(qualification: selectedQualification!, mode: TestCreationMode.manual))),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

