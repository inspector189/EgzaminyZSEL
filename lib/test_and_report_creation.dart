import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter_app/services/api_service.dart';

import 'exam_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:web/web.dart' as web;
import 'package:html_unescape/html_unescape.dart';
import 'test_creator.dart';
import 'widgets/video_player.dart';

const bool _kUseFakeData = kDebugMode;

final _fakeTests = [
  {
    'name': 'Test próbny EE.08',
    'qualification': 'ee08',
    'author': 'jan.kowalski@szkola.pl',
    'createdAt': '2025-03-01T10:00:00',
    'published': true,
    'questions': List.generate(
      40,
      (i) => {
        'id': '$i',
        'pytanie_text': 'Pytanie testowe nr ${i + 1}',
        'pytanie_images': <String>[],
        'pytanie_videos': <String>[],
        'odp1_text': 'Odpowiedź A',
        'odp1_images': <String>[],
        'odp2_text': 'Odpowiedź B',
        'odp2_images': <String>[],
        'odp3_text': 'Odpowiedź C',
        'odp3_images': <String>[],
        'odp4_text': 'Odpowiedź D',
        'odp4_images': <String>[],
      },
    ),
    'results': [
      {
        'userName': 'Anna Nowak',
        'uid': 'uid-001',
        'score': 82.5,
        'date': '2025-03-10T09:15:00',
        'duration_sec': 1820,
        'exam_id': 101,
      },
      {
        'userName': 'Anna Nowak',
        'uid': 'uid-001',
        'score': 75.0,
        'date': '2025-03-08T14:30:00',
        'duration_sec': 2100,
        'exam_id': 98,
      },
      {
        'userName': 'Piotr Wiśniewski',
        'uid': 'uid-002',
        'score': 47.5,
        'date': '2025-03-11T11:00:00',
        'duration_sec': 2450,
        'exam_id': 105,
      },
      {
        'userName': 'Maria Zając',
        'uid': 'uid-003',
        'score': 92.5,
        'date': '2025-03-12T08:45:00',
        'duration_sec': 1540,
        'exam_id': 110,
      },
    ],
  },
  {
    'name': 'Sprawdzian EE.09 – moduł 2',
    'qualification': 'ee09',
    'author': 'anna.nowak@szkola.pl',
    'createdAt': '2025-02-20T14:22:00',
    'published': false,
    'questions': List.generate(
      20,
      (i) => {
        'id': '${100 + i}',
        'pytanie_text': 'Pytanie EE09 nr ${i + 1}',
        'pytanie_images': <String>[],
        'pytanie_videos': <String>[],
        'odp1_text': 'Odp A',
        'odp1_images': <String>[],
        'odp2_text': 'Odp B',
        'odp2_images': <String>[],
        'odp3_text': 'Odp C',
        'odp3_images': <String>[],
        'odp4_text': 'Odp D',
        'odp4_images': <String>[],
      },
    ),
    'results': [],
  },
];

const String _fakeCurrentUser = 'jan.kowalski@szkola.pl';
const bool _fakeIsSuperAdmin = true;

bool isValidQualification(String? qual) {
  if (qual == null) return false;
  final trimmed = qual.trim().toLowerCase();
  return RegExp(r'^[a-z]{3}\d{2}$').hasMatch(trimmed);
}

// ─────────────────────────────────────────────
//  RichQuestionWidget
// ─────────────────────────────────────────────

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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final unescape = HtmlUnescape();
    final pytanieText = unescape.convert(question['pytanie_text'] ?? '');
    final pytanieImages =
        (question['pytanie_images'] as List?)?.cast<String>() ?? [];
    final pytanieVideos =
        (question['pytanie_videos'] as List?)?.cast<String>() ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$number. $pytanieText',
              style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...pytanieImages.map(
              (url) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    height: 220,
                    loadingBuilder: (ctx, child, progress) => child,
                    errorBuilder:
                        (ctx, error, stack) => Text(
                          'Błąd obrazka',
                          style: TextStyle(color: cs.error),
                        ),
                  ),
                ),
              ),
            ),
            ...pytanieVideos.map(
              (url) => InlineVideoPlayer(url: url, height: 240),
            ),
            if (showAnswers) ...[
              const SizedBox(height: 12),
              ...[1, 2, 3, 4].map((idx) {
                final text =
                    unescape.convert(question['odp${idx}_text'] ?? '').trim();
                final images =
                    (question['odp${idx}_images'] as List?)?.cast<String>() ??
                    [];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(text, style: tt.bodyMedium),
                      ...images.map(
                        (url) => Padding(
                          padding: const EdgeInsets.only(top: 8, left: 20),
                          child: Image.network(
                            url,
                            width: 300,
                            height: 150,
                            fit: BoxFit.contain,
                            errorBuilder:
                                (ctx, error, stack) => Text(
                                  'Błąd obrazka',
                                  style: TextStyle(color: cs.error),
                                ),
                          ),
                        ),
                      ),
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

// ─────────────────────────────────────────────
//  Page root
// ─────────────────────────────────────────────

class CreatingTestsAndReportsPage extends StatefulWidget {
  const CreatingTestsAndReportsPage({super.key});

  @override
  State<CreatingTestsAndReportsPage> createState() =>
      _CreatingTestsAndReportsPageState();
}

class _CreatingTestsAndReportsPageState
    extends State<CreatingTestsAndReportsPage>
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

  // FIX: removed didChangeDependencies double-load — initState in
  // CreatedTestsTab already calls _loadTests().

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Testy i raporty'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        iconTheme: IconThemeData(color: cs.onPrimary),
      ),
      body: Column(
        children: [
          Material(
            color: cs.surface,
            elevation: 2,
            child: TabBar(
              controller: _tabController,
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurface.withValues(alpha: 0.5),
              indicatorColor: cs.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.list_alt_rounded),
                  text: 'Utworzone testy',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  icon: Icon(Icons.add_circle_outline_rounded),
                  text: 'Stwórz test',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [CreatedTestsTab(), CreateNewTestTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Test preview page
// ─────────────────────────────────────────────

class TestPreviewPage extends StatelessWidget {
  final Map<String, dynamic> test;
  final VoidCallback onPublish;
  const TestPreviewPage({
    super.key,
    required this.test,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final questions = List<Map<String, dynamic>>.from(
      test['questions'] as List,
    );
    final qual = test['qualification'] as String;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(test['name'] as String),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        iconTheme: IconThemeData(color: cs.onPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.publish_rounded, color: cs.onPrimary),
            tooltip: 'Publikuj',
            onPressed: () {
              onPublish();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        itemBuilder:
            (context, i) => RichQuestionWidget(
              question: questions[i],
              number: i + 1,
              qualification: qual,
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Created tests tab
// ─────────────────────────────────────────────

class CreatedTestsTab extends StatefulWidget {
  const CreatedTestsTab({super.key});
  @override
  State<CreatedTestsTab> createState() => _CreatedTestsTabState();
}

class _CreatedTestsTabState extends State<CreatedTestsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _innerTab;

  List<Map<String, dynamic>> savedTests = [];
  bool isLoadingResults = false;
  bool isLoadingTests = true;
  bool isSuperAdmin = false;
  String currentUser = '';

  @override
  void initState() {
    super.initState();
    _innerTab = TabController(length: 2, vsync: this);
    _loadCurrentUser();
    _loadUserRole();
    _loadTests();
  }

  @override
  void dispose() {
    _innerTab.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────

  Future<void> _loadCurrentUser() async {
    if (_kUseFakeData) {
      if (mounted) setState(() => currentUser = _fakeCurrentUser);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => currentUser = prefs.getString('userName') ?? '');
    }
  }

  Future<void> _loadUserRole() async {
    if (_kUseFakeData) {
      if (mounted) setState(() => isSuperAdmin = _fakeIsSuperAdmin);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail');
    if (email == null || email.isEmpty) {
      return; // silent — not a SnackBar concern
    }

    try {
      final result = await ApiService.instance.checkSuperAdmin(email);
      if (result.isSuccess && mounted) {
        setState(() => isSuperAdmin = result.data ?? false);
        prefs.setBool('isSuperAdmin', isSuperAdmin);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Błąd sprawdzania uprawnień: $e');
    }
  }

  Future<void> _loadTests() async {
    if (_kUseFakeData) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() {
          savedTests =
              _fakeTests.map((t) => Map<String, dynamic>.from(t)).toList();
          isLoadingTests = false;
        });
      }
      return;
    }

    setState(() => isLoadingTests = true);

    try {
      final result = await ApiService.instance.fetchAllTests();

      if (result.isSuccess) {
        final serverMaps =
            (result.data! as List<dynamic>).cast<Map<String, dynamic>>();

        for (final t in serverMaps) {
          // Normalise 'published' to bool regardless of server type
          final publishedVal = t['published'];
          t['published'] =
              publishedVal == true ||
              publishedVal == 1 ||
              publishedVal.toString() == '1' ||
              publishedVal.toString().toLowerCase() == 'true';
          t['results'] ??= <dynamic>[];
        }

        if (mounted) setState(() => savedTests = serverMaps);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_tests', json.encode(savedTests));
        _loadAllResults();
      } else {
        await _loadTestsFromCache();
      }
    } catch (_) {
      await _loadTestsFromCache();
    } finally {
      if (mounted) setState(() => isLoadingTests = false);
    }
  }

  Future<void> _loadTestsFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final localData = prefs.getString('saved_tests');
    if (localData != null) {
      final list = List<Map<String, dynamic>>.from(json.decode(localData));
      if (mounted) setState(() => savedTests = list);
    }
  }

  Future<void> _loadAllResults() async {
    if (isLoadingResults) return;
    if (mounted) setState(() => isLoadingResults = true);

    // FIX: snapshot the length so mid-loop mutations don't shift indices
    final count = savedTests.length;
    for (int i = 0; i < count; i++) {
      if (!mounted) break;
      final test = savedTests[i];
      final testKey =
          '${test['name']}||${test['author']}||${test['qualification']}';

      try {
        final result = await ApiService.instance.fetchTestResults(testKey);
        if (result.isSuccess && mounted) {
          setState(() => savedTests[i]['results'] = result.data!);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Błąd pobierania wyników [$i]: $e');
      }
    }

    if (mounted) setState(() => isLoadingResults = false);
  }

  // ── Actions ───────────────────────────────────────────────────

  Future<void> _deleteTest(int index) async {
    final test = savedTests[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Usunąć test?'),
            content: Text(
              'Czy na pewno chcesz usunąć "${test['name']}"?\n\n'
              'Test zostanie usunięty także z serwera (jeśli jest opublikowany).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Anuluj'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.error,
                ),
                child: const Text('Usuń'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    if (_kUseFakeData) {
      setState(() => savedTests.removeAt(index));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('[FAKE] Test usunięty'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    try {
      await ApiService.instance.deleteTest(test);
    } catch (e) {
      if (kDebugMode) debugPrint('Błąd usuwania z serwera: $e');
    }

    setState(() => savedTests.removeAt(index));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_tests', json.encode(savedTests));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Test usunięty'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _togglePublish(int index) async {
    final test = savedTests[index];
    final willPublish = !(test['published'] == true);

    if (_kUseFakeData) {
      setState(() => savedTests[index]['published'] = willPublish);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '[FAKE] ${willPublish ? 'Opublikowano' : 'Wycofano'}',
            ),
            backgroundColor:
                willPublish
                    ? Colors.green
                    : Theme.of(context).colorScheme.secondary,
          ),
        );
      }
      return;
    }

    setState(() => savedTests[index]['published'] = willPublish);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_tests', json.encode(savedTests));

    try {
      await ApiService.instance.setTestPublished(test, willPublish);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              willPublish
                  ? 'Test opublikowany dla wszystkich!'
                  : 'Test wycofany z publikacji',
            ),
            backgroundColor:
                willPublish
                    ? Colors.green
                    : Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    } catch (_) {
      // Roll back on failure
      setState(() => savedTests[index]['published'] = !willPublish);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Brak internetu — zmiany zostaną zsynchronizowane później',
            ),
          ),
        );
      }
    }
  }

  // ── PDF helpers ───────────────────────────────────────────────

  web.Blob _createBlob(Uint8List bytes) => web.Blob(
    [bytes.buffer.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );

  void _openPdfBlob(Uint8List bytes, String filename) {
    if (kIsWeb) {
      final blob = _createBlob(bytes);
      final url = web.URL.createObjectURL(blob);
      web.window.open(url, '_blank');
      Future.delayed(
        const Duration(seconds: 10),
        () => web.URL.revokeObjectURL(url),
      );
    } else {
      Printing.sharePdf(bytes: bytes, filename: filename);
    }
  }

  bool _testContainsVideo(Map<String, dynamic> test) {
    final questions = test['questions'] as List<dynamic>;
    for (final q in questions) {
      if (((q['pytanie_videos'] as List?)?.isNotEmpty ?? false)) return true;
      for (int i = 1; i <= 4; i++) {
        if (((q['odp${i}_videos'] as List?)?.isNotEmpty ?? false)) return true;
      }
    }
    return false;
  }

  Future<void> _printTest(Map<String, dynamic> test) async {
    if (_testContainsVideo(test)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ten test zawiera filmy — nie można wygenerować PDF'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final questions = List<Map<String, dynamic>>.from(
      test['questions'] as List,
    );
    final pdf = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
    final ttf = pw.Font.ttf(fontData);

    List<String> getImages(Map<String, dynamic> q, String prefix) =>
        prefix.isEmpty
            ? (q['pytanie_images'] as List?)?.cast<String>() ?? []
            : (q['odp${prefix}_images'] as List?)?.cast<String>() ?? [];

    final header = pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  pw.Text(
                    'Imię i nazwisko:',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Container(
                    width: 250,
                    child: pw.Text(
                      '__________________________________',
                      style: pw.TextStyle(font: ttf, fontSize: 14),
                    ),
                  ),
                  pw.SizedBox(width: 40),
                  pw.Text(
                    'Klasa:',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Text(
                    '______',
                    style: pw.TextStyle(font: ttf, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  pw.Text(
                    'Nr w dzienniku:',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Text(
                    '________',
                    style: pw.TextStyle(font: ttf, fontSize: 11),
                  ),
                ],
              ),
              pw.Row(
                children: [
                  pw.Text(
                    'Punkty:',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Text('____', style: pw.TextStyle(font: ttf, fontSize: 11)),
                  pw.Text(
                    ' / ${questions.length}',
                    style: pw.TextStyle(font: ttf, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 1.5),
          pw.SizedBox(height: 10),
        ],
      ),
    );

    final List<pw.Widget> pages = [];
    for (final entry in questions.asMap().entries) {
      final i = entry.key + 1;
      final q = entry.value;
      final pytanieText = (q['pytanie_text'] ?? '').toString().trim();
      final pytanieImages = getImages(q, '');

      final List<pw.Widget> children = [
        pw.Text(
          '$i. $pytanieText',
          style: pw.TextStyle(
            font: ttf,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 5),
      ];

      for (final url in pytanieImages) {
        try {
          final result = await ApiService.instance.downloadImage(url);
          if (result.isSuccess) {
            children.add(
              pw.Center(
                child: pw.SizedBox(
                  width: 460,
                  height: 300,
                  child: pw.Image(
                    pw.MemoryImage(result.data!),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
            );
            children.add(pw.SizedBox(height: 11));
          }
        } catch (_) {}
      }

      for (int idx = 1; idx <= 4; idx++) {
        final text = (q['odp${idx}_text'] ?? '').toString().trim();
        final images = (q['odp${idx}_images'] as List?)?.cast<String>() ?? [];

        children.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 20, top: 8, bottom: 4),
            child: pw.Text(text, style: pw.TextStyle(font: ttf, fontSize: 11)),
          ),
        );

        for (final url in images) {
          try {
            final result = await ApiService.instance.downloadImage(url);
            if (result.isSuccess) {
              children.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 34, top: 8),
                  child: pw.SizedBox(
                    width: 380,
                    height: 220,
                    child: pw.Image(
                      pw.MemoryImage(result.data!),
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

      pages.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: children,
          ),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(
          left: 50,
          right: 50,
          top: 40,
          bottom: 60,
        ),
        header: (ctx) => ctx.pageNumber == 1 ? header : pw.SizedBox(),
        footer:
            (ctx) => pw.Container(
              alignment: pw.Alignment.center,
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Text(
                'Strona ${ctx.pageNumber} / ${ctx.pagesCount}',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 11,
                  color: PdfColors.grey700,
                ),
              ),
            ),
        build: (_) => pages,
      ),
    );

    final bytes = await pdf.save();
    _openPdfBlob(
      bytes,
      'test_${(test['name'] as String).replaceAll(' ', '_')}.pdf',
    );
  }

  Future<Map<String, dynamic>?> _fetchExamDetailsFull(int examId) async {
    if (_kUseFakeData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return null; // Preview not available in fake mode
    }
    try {
      final result = await ApiService.instance.fetchExamPreviewForTest(examId);
      if (result.isSuccess && result.data?['success'] == true) {
        return {
          'questions': List<dynamic>.from(result.data!['questions']),
          'selectedAnswers':
              (result.data!['selectedAnswers'] as List).cast<String?>(),
        };
      }
    } catch (e) {
      if (kDebugMode) debugPrint('fetchExamDetails error: $e');
    }
    return null;
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (isLoadingTests) {
      return const Center(child: CircularProgressIndicator());
    }

    if (savedTests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 48,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Brak utworzonych testów',
              style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final myTests =
        savedTests.where((t) => t['author'] == currentUser).toList();

    return Column(
      children: [
        // Inner tab bar (Moje / Wszystkie)
        Container(
          color: cs.surface,
          child: TabBar(
            controller: _innerTab,
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurface.withValues(alpha: 0.5),
            indicatorColor: cs.primary,
            dividerColor: cs.outlineVariant.withValues(alpha: 0.4),
            tabs: [
              Tab(text: 'Moje testy (${myTests.length})'),
              Tab(text: 'Wszystkie (${savedTests.length})'),
            ],
          ),
        ),
        if (isLoadingResults)
          LinearProgressIndicator(
            minHeight: 2,
            color: cs.primary,
            backgroundColor: cs.primaryContainer.withValues(alpha: 0.3),
          ),
        Expanded(
          child: TabBarView(
            controller: _innerTab,
            children: [
              _buildTestList(myTests, cs, tt),
              _buildTestList(savedTests, cs, tt),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTestList(
    List<Map<String, dynamic>> tests,
    ColorScheme cs,
    TextTheme tt,
  ) {
    if (tests.isEmpty) {
      return Center(
        child: Text(
          'Brak testów',
          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTests,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: tests.length,
        itemBuilder: (context, i) {
          final t = tests[i];
          final realIndex = savedTests.indexOf(t);
          // FIX: copy list before sorting to avoid mutating the original
          final results = List<dynamic>.from(
            (t['results'] as List<dynamic>?) ?? [],
          )..sort(
            (a, b) => (b['date'] as String).compareTo(a['date'] as String),
          );
          final isPublished = t['published'] == true;
          final canEdit = isSuperAdmin || t['author'] == currentUser;

          return _TestCard(
            test: t,
            results: results,
            isPublished: isPublished,
            canEdit: canEdit,
            cs: cs,
            tt: tt,
            onPreview:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => TestPreviewPage(
                          test: t,
                          onPublish: () => _togglePublish(realIndex),
                        ),
                  ),
                ),
            onPrint: () => _printTest(t),
            onDelete: canEdit ? () => _deleteTest(realIndex) : null,
            onTogglePublish: canEdit ? () => _togglePublish(realIndex) : null,
            onReport: () => _generateReportPdf(t),
            onAnswerKey: () => _generateAnswerKeyPdf(t),
            onExamPreview: (examId) async {
              final data = await _fetchExamDetailsFull(examId);
              if (!context.mounted) return;
              if (data != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => EgzaminPodgladView(
                          questions: data['questions'],
                          selectedAnswers: data['selectedAnswers'],
                        ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Nie udało się wczytać podglądu'),
                    backgroundColor: cs.error,
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  String _fmtDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '-';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }

  String _formatDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      final dd = d.day.toString().padLeft(2, '0');
      final mm = d.month.toString().padLeft(2, '0');
      final hh = d.hour.toString().padLeft(2, '0');
      final min = d.minute.toString().padLeft(2, '0');
      return '$dd.$mm.${d.year} $hh:$min';
    } catch (_) {
      return isoDate;
    }
  }

  // Build grouped result rows (extracted to keep _buildTestList clean)
  List<Widget> buildGroupedResults(
    BuildContext context,
    List<dynamic> results,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final Map<String, List<dynamic>> grouped = {};
    for (final r in results) {
      final user = (r['userName'] as String?) ?? 'Nieznany';
      (grouped[user] ??= []).add(r);
    }

    return grouped.entries.map((entry) {
      // FIX: copy before sorting — don't mutate grouped list
      final userResults = List<dynamic>.from(entry.value)
        ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

      final latest = userResults.first;
      final latestScore = (latest['score'] as num?)?.toDouble() ?? 0.0;

      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: _ScoreBadge(score: latestScore, cs: cs, tt: tt),
          title: Text(
            entry.key,
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          subtitle: Text(
            'Ostatni: ${latestScore.toStringAsFixed(0)}%  •  ${_formatDate(latest['date'] as String? ?? '')}',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          children:
              userResults.map((r) {
                final score = (r['score'] as num?)?.toDouble() ?? 0.0;
                final date = _formatDate((r['date'] as String?) ?? '');
                final czas = _fmtDuration(
                  r['duration_sec'] is int
                      ? r['duration_sec'] as int
                      : int.tryParse('${r['duration_sec'] ?? ''}'),
                );
                final examId =
                    int.tryParse((r['exam_id'] ?? r['id'] ?? '').toString()) ??
                    0;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      _ScoreBadge(score: score, cs: cs, tt: tt, small: true),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              date,
                              style: tt.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            Text(
                              'Czas: $czas',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (examId > 0)
                        OutlinedButton.icon(
                          onPressed: () async {
                            final data = await _fetchExamDetailsFull(examId);
                            if (!context.mounted) return;
                            if (data != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => EgzaminPodgladView(
                                        questions: data['questions'],
                                        selectedAnswers:
                                            data['selectedAnswers'],
                                      ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Nie udało się wczytać podglądu',
                                  ),
                                  backgroundColor: cs.error,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.visibility_rounded, size: 14),
                          label: const Text('Podgląd'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
        ),
      );
    }).toList();
  }

  // ── PDF generation ────────────────────────────────────────────

  Future<void> _generateAnswerKeyPdf(Map<String, dynamic> test) async {
    final String qual = test['qualification'] as String;
    final questions = List<Map<String, dynamic>>.from(
      test['questions'] as List,
    );

    List<dynamic> fullDb = [];

    if (_kUseFakeData) {
      // Fake answer key — A for all
      fullDb = questions.map((q) => {'id': q['id'], 'poprawna': 'A'}).toList();
    } else {
      try {
        final result = await ApiService.instance.fetchQuestions(qual);
        if (result.isSuccess) {
          fullDb = result.data!;
        } else {
          throw Exception('${result.statusCode}');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Nie można pobrać klucza odpowiedzi ($qual.php): $e',
              ),
            ),
          );
        }
        return;
      }
    }

    final Map<String, String> answerMap = {
      for (final q in fullDb)
        q['id'].toString():
            (q['poprawna'] ?? '?').toString().trim().toUpperCase(),
    };

    final answerRows =
        questions.asMap().entries.map((e) {
          return [
            (e.key + 1).toString(),
            answerMap[e.value['id'].toString()] ?? '?',
          ];
        }).toList();

    final pdf = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
    final ttf = pw.Font.ttf(fontData);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build:
            (ctx) => [
              pw.Text(
                'Klucz Odpowiedzi — ${test['name']}',
                style: pw.TextStyle(
                  font: ttf,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Kwalifikacja: ${qual.toUpperCase()}',
                style: pw.TextStyle(font: ttf, fontSize: 14),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Nr pytania', 'Poprawna'],
                data: answerRows,
                headerStyle: pw.TextStyle(
                  font: ttf,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: pw.TextStyle(font: ttf, fontSize: 11),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.5),
                  1: const pw.FlexColumnWidth(1),
                },
              ),
            ],
      ),
    );

    final bytes = await pdf.save();
    _openPdfBlob(
      bytes,
      'klucz_${(test['name'] as String).replaceAll(' ', '_')}.pdf',
    );
  }

  Future<void> _generateReportPdf(Map<String, dynamic> test) async {
    final results = (test['results'] as List<dynamic>?) ?? [];
    if (results.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brak wyników do raportu')),
        );
      }
      return;
    }

    // Keep only the most recent attempt per user
    final Map<String, Map<String, dynamic>> lastResults = {};
    for (final r in results) {
      final uid = (r['uid'] ?? r['UID'] ?? '').toString();
      final name = (r['userName'] ?? 'Nieznany').toString();
      final key = uid.isNotEmpty ? uid : name;
      final dateStr = (r['date'] ?? '').toString();
      if (!lastResults.containsKey(key) ||
          dateStr.compareTo(lastResults[key]!['date'].toString()) > 0) {
        lastResults[key] = Map<String, dynamic>.from(r);
      }
    }

    final rows =
        lastResults.values.map((r) {
          final name = (r['userName'] ?? 'Nieznany').toString();
          final uid = (r['uid'] ?? r['UID'] ?? '').toString();
          final rawScore = r['score'];
          final scoreNum =
              rawScore is num
                  ? rawScore
                  : num.tryParse(rawScore?.toString() ?? '');
          return {
            'name': name,
            'uid': uid,
            'score': scoreNum != null ? scoreNum.toStringAsFixed(2) : '-',
            'date': _formatDate((r['date'] ?? '').toString()),
          };
        }).toList();

    final pdf = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
    final ttf = pw.Font.ttf(fontData);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build:
            (ctx) => [
              pw.Center(
                child: pw.Text(
                  'Raport wyników — ${test['name']}',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Data generowania: ${_formatDate(DateTime.now().toIso8601String())}',
                style: pw.TextStyle(font: ttf, fontSize: 12),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Kwalifikacja: ${(test['qualification'] as String).toUpperCase()}  •  Uwzględniono ostatnie podejście na ucznia.',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 12,
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
                  pw.TableRow(
                    children: [
                      _pdfCell('Użytkownik', ttf, bold: true),
                      _pdfCell('Wynik (%)', ttf, bold: true),
                      _pdfCell('Data', ttf, bold: true),
                    ],
                  ),
                  ...rows.map(
                    (row) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                row['name']!,
                                style: pw.TextStyle(
                                  font: ttf,
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              if (row['uid']!.isNotEmpty)
                                pw.Text(
                                  'UID: ${row['uid']}',
                                  style: pw.TextStyle(font: ttf, fontSize: 9),
                                ),
                            ],
                          ),
                        ),
                        _pdfCell('${row['score']}%', ttf),
                        _pdfCell(row['date']!, ttf),
                      ],
                    ),
                  ),
                ],
              ),
            ],
      ),
    );

    final bytes = await pdf.save();
    _openPdfBlob(
      bytes,
      'raport_${(test['name'] as String).replaceAll(' ', '_')}.pdf',
    );
  }

  pw.Widget _pdfCell(String text, pw.Font ttf, {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font: ttf,
            fontSize: bold ? 12 : 11,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
}

// ─────────────────────────────────────────────
//  Test card widget
// ─────────────────────────────────────────────

class _TestCard extends StatelessWidget {
  const _TestCard({
    required this.test,
    required this.results,
    required this.isPublished,
    required this.canEdit,
    required this.cs,
    required this.tt,
    required this.onPreview,
    required this.onPrint,
    required this.onDelete,
    required this.onTogglePublish,
    required this.onReport,
    required this.onAnswerKey,
    required this.onExamPreview,
  });

  final Map<String, dynamic> test;
  final List<dynamic> results;
  final bool isPublished;
  final bool canEdit;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onPreview;
  final VoidCallback onPrint;
  final VoidCallback? onDelete;
  final VoidCallback? onTogglePublish;
  final VoidCallback onReport;
  final VoidCallback onAnswerKey;
  final void Function(int examId) onExamPreview;

  @override
  Widget build(BuildContext context) {
    final avg =
        results.isEmpty
            ? null
            : results
                    .map((r) => (r['score'] as num?)?.toDouble() ?? 0.0)
                    .reduce((a, b) => a + b) /
                results.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),

          // ── Leading status badge ──────────────────────────────
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  isPublished
                      ? Colors.green.withValues(alpha: 0.15)
                      : cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPublished ? Icons.public_rounded : Icons.lock_outline_rounded,
              size: 20,
              color: isPublished ? Colors.green : cs.onSurfaceVariant,
            ),
          ),

          // ── Title ─────────────────────────────────────────────
          title: Row(
            children: [
              Expanded(
                child: Text(
                  test['name'] as String,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  (test['qualification'] as String).toUpperCase(),
                  style: tt.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),

          // ── Subtitle ──────────────────────────────────────────
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _SubtitleChip(
                  icon: Icons.person_outline_rounded,
                  label: test['author'] as String,
                  cs: cs,
                  tt: tt,
                ),
                _SubtitleChip(
                  icon: Icons.quiz_rounded,
                  label: '${(test['questions'] as List).length} pytań',
                  cs: cs,
                  tt: tt,
                ),
                if (avg != null)
                  _SubtitleChip(
                    icon: Icons.bar_chart_rounded,
                    label: 'Śr. ${avg.toStringAsFixed(1)}% (${results.length})',
                    cs: cs,
                    tt: tt,
                    highlight: true,
                  ),
              ],
            ),
          ),

          // ── Action buttons (replaced overflow Row with Wrap) ──
          trailing: _ActionMenu(
            canEdit: canEdit,
            isPublished: isPublished,
            cs: cs,
            onPreview: onPreview,
            onPrint: onPrint,
            onDelete: onDelete,
            onTogglePublish: onTogglePublish,
            onReport: onReport,
            onAnswerKey: onAnswerKey,
          ),

          children:
              results.isEmpty
                  ? [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_rounded,
                            size: 20,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Brak wyników',
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]
                  : _buildGroupedResultsInline(context, results),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedResultsInline(
    BuildContext context,
    List<dynamic> results,
  ) {
    final Map<String, List<dynamic>> grouped = {};
    for (final r in results) {
      final user = (r['userName'] as String?) ?? 'Nieznany';
      (grouped[user] ??= []).add(r);
    }

    return grouped.entries.map((entry) {
      final userResults = List<dynamic>.from(entry.value)
        ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

      final latest = userResults.first;
      final latestScore = (latest['score'] as num?)?.toDouble() ?? 0.0;
      final latestDate = _fmtDate(latest['date'] as String? ?? '');

      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            leading: _ScoreBadge(score: latestScore, cs: cs, tt: tt),
            title: Text(
              entry.key,
              style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            subtitle: Text(
              'Ostatni: ${latestScore.toStringAsFixed(0)}%  •  $latestDate',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            children:
                userResults.map((r) {
                  final score = (r['score'] as num?)?.toDouble() ?? 0.0;
                  final date = _fmtDate((r['date'] as String?) ?? '');
                  final durSec =
                      r['duration_sec'] is int
                          ? r['duration_sec'] as int
                          : int.tryParse('${r['duration_sec'] ?? ''}');
                  final czas = _fmtDur(durSec);
                  final examId =
                      int.tryParse(
                        (r['exam_id'] ?? r['id'] ?? '').toString(),
                      ) ??
                      0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    child: Row(
                      children: [
                        _ScoreBadge(score: score, cs: cs, tt: tt, small: true),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                date,
                                style: tt.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                              ),
                              Text(
                                'Czas: $czas',
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (examId > 0)
                          OutlinedButton.icon(
                            onPressed: () => onExamPreview(examId),
                            icon: const Icon(
                              Icons.visibility_rounded,
                              size: 14,
                            ),
                            label: const Text('Podgląd'),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
          ),
        ),
      );
    }).toList();
  }

  static String _fmtDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  static String _fmtDur(int? seconds) {
    if (seconds == null || seconds <= 0) return '-';
    return '${seconds ~/ 60}m ${seconds % 60}s';
  }
}

// ─────────────────────────────────────────────
//  Action menu (replaces 6-button overflow row)
// ─────────────────────────────────────────────

class _ActionMenu extends StatelessWidget {
  const _ActionMenu({
    required this.canEdit,
    required this.isPublished,
    required this.cs,
    required this.onPreview,
    required this.onPrint,
    required this.onDelete,
    required this.onTogglePublish,
    required this.onReport,
    required this.onAnswerKey,
  });

  final bool canEdit;
  final bool isPublished;
  final ColorScheme cs;
  final VoidCallback onPreview;
  final VoidCallback onPrint;
  final VoidCallback? onDelete;
  final VoidCallback? onTogglePublish;
  final VoidCallback onReport;
  final VoidCallback onAnswerKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Always-visible quick actions
        IconButton(
          icon: Icon(Icons.visibility_rounded, color: cs.primary),
          tooltip: 'Podgląd testu',
          visualDensity: VisualDensity.compact,
          onPressed: onPreview,
        ),
        // Overflow menu for the rest
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant),
          tooltip: 'Więcej opcji',
          onSelected: (value) {
            switch (value) {
              case 'print':
                onPrint();
              case 'report':
                onReport();
              case 'key':
                onAnswerKey();
              case 'publish':
                onTogglePublish?.call();
              case 'delete':
                onDelete?.call();
            }
          },
          itemBuilder:
              (ctx) => [
                const PopupMenuItem(
                  value: 'print',
                  child: ListTile(
                    leading: Icon(Icons.print_rounded),
                    title: Text('Drukuj PDF'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'report',
                  child: ListTile(
                    leading: Icon(
                      Icons.file_download_rounded,
                      color: Colors.deepPurple,
                    ),
                    title: Text('Raport wyników'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'key',
                  child: ListTile(
                    leading: Icon(Icons.key_rounded, color: Colors.teal),
                    title: Text('Klucz odpowiedzi'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                if (canEdit) ...[
                  PopupMenuItem(
                    value: 'publish',
                    child: ListTile(
                      leading: Icon(
                        isPublished
                            ? Icons.public_off_rounded
                            : Icons.public_rounded,
                        color: isPublished ? Colors.orange : Colors.green,
                      ),
                      title: Text(isPublished ? 'Wycofaj' : 'Opublikuj'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_rounded,
                        color: Theme.of(ctx).colorScheme.error,
                      ),
                      title: Text(
                        'Usuń',
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ],
              ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Shared small widgets
// ─────────────────────────────────────────────

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({
    required this.score,
    required this.cs,
    required this.tt,
    this.small = false,
  });
  final double score;
  final ColorScheme cs;
  final TextTheme tt;
  final bool small;

  Color get _color =>
      score >= 75
          ? const Color(0xFF2E7D32)
          : score >= 50
          ? cs.primary
          : cs.error;
  Color get _bg => _color.withValues(alpha: 0.12);

  @override
  Widget build(BuildContext context) {
    final size = small ? 32.0 : 40.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _bg),
      alignment: Alignment.center,
      child: Text(
        '${score.toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: small ? 10 : 12,
          fontWeight: FontWeight.w800,
          color: _color,
        ),
      ),
    );
  }
}

class _SubtitleChip extends StatelessWidget {
  const _SubtitleChip({
    required this.icon,
    required this.label,
    required this.cs,
    required this.tt,
    this.highlight = false,
  });
  final IconData icon;
  final String label;
  final ColorScheme cs;
  final TextTheme tt;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: highlight ? cs.primary : cs.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: tt.bodySmall?.copyWith(
            color: highlight ? cs.primary : cs.onSurfaceVariant,
            fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Create new test tab
// ─────────────────────────────────────────────

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
    _loadQualifications();
  }

  Future<void> _loadQualifications() async {
    if (_kUseFakeData) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          qualifications = ['ee08', 'ee09', 'ee10', 'inf02', 'inf03'];
          isLoading = false;
        });
      }
      return;
    }

    try {
      final result = await ApiService.instance.fetchQualifications();
      if (result.isSuccess) {
        final Set<String> quals = {};
        for (final exam in result.data!) {
          final q =
              (exam['kwalifikacja'] ?? '')
                  .toString()
                  .trim()
                  .replaceAll(' ', '')
                  .toLowerCase();
          if (isValidQualification(q)) quals.add(q);
        }
        if (mounted) {
          setState(() {
            qualifications = quals.toList()..sort();
            isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (isLoading) return const Center(child: CircularProgressIndicator());

    if (qualifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 48,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'Brak dostępnych kwalifikacji',
                style: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Upewnij się, że ktoś już zdawał egzaminy.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: selectedQualification,
            isExpanded: true,
            dropdownColor: cs.surface,
            menuMaxHeight: 400,
            decoration: InputDecoration(
              labelText: 'Wybierz kwalifikację',
              border: const OutlineInputBorder(),
              prefixIcon: Icon(Icons.school_rounded, color: cs.primary),
            ),
            items:
                qualifications
                    .map(
                      (q) => DropdownMenuItem(
                        value: q,
                        child: Text(
                          q.toUpperCase(),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (v) => setState(() => selectedQualification = v),
          ),
          if (selectedQualification != null) ...[
            const SizedBox(height: 32),
            Text(
              'Tryb tworzenia',
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ModeCard(
                    icon: Icons.shuffle_rounded,
                    title: 'Losowe 40 pytań',
                    subtitle: 'Automatyczny dobór z puli',
                    cs: cs,
                    tt: tt,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => TestCreatorPage(
                                  qualification: selectedQualification!,
                                  mode: TestCreationMode.random,
                                ),
                          ),
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModeCard(
                    icon: Icons.handyman_rounded,
                    title: 'Ręczny dobór',
                    subtitle: 'Wybierz pytania samodzielnie',
                    cs: cs,
                    tt: tt,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => TestCreatorPage(
                                  qualification: selectedQualification!,
                                  mode: TestCreationMode.manual,
                                ),
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cs,
    required this.tt,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: cs.onPrimaryContainer),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
