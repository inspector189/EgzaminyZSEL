import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' show pi;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:web/web.dart' as web;
import 'package:html_unescape_xx/html_unescape.dart';

import 'test_creator.dart';
import 'exam_preview.dart';

import '/services/api_service.dart';
import '/utils/app_themes.dart';
import '/utils/async_state_view.dart';
import '/utils/helpers.dart';
import '/widgets/exam_question_card.dart';

final _fakeTests = [
  {
    'id': 1,
    'name': 'Test próbny EE.08',
    'qualification': 'ee08',
    'author': 'Jan Kowalski',
    'createdAt': '2025-03-01T10:00:00',
    'published': true,
    'question_count': 40,
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
    'id': 2,
    'name': 'Sprawdzian EE.09 – moduł 2',
    'qualification': 'ee09',
    'author': 'Anna Nowak',
    'createdAt': '2025-02-20T14:22:00',
    'published': false,
    'question_count': 40,
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

// ─────────────────────────────────────────────
//              RichQuestionWidget
// ─────────────────────────────────────────────

class RichQuestionWidget extends StatelessWidget {
  final Map<String, dynamic> question;
  final int number;
  final bool showAnswers;
  final String qualification;
  final Color? accentColorOverride;

  const RichQuestionWidget({
    super.key,
    required this.question,
    required this.number,
    this.showAnswers = true,
    required this.qualification,
    this.accentColorOverride,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unescape = HtmlUnescapeSmall();
    final poprawna = question['poprawna']?.toString() ?? '';

    final answers = List.generate(4, (i) {
      final letter = 'ABCD'[i];
      final key = 'odp${i + 1}';
      return ExamAnswerState(
        letter: letter,
        text: unescape
            .convert(question['${key}_text']?.toString() ?? '')
            .trim(),
        images: (question['${key}_images'] as List?)?.cast<String>() ?? [],
        videos: (question['${key}_videos'] as List?)?.cast<String>() ?? [],
        isCorrect: letter == poprawna,
        isSelected: false,
      );
    });

    return ExamQuestionCard(
      label: 'Pytanie $number',
      questionText: unescape.convert(
        question['pytanie_text']?.toString() ?? '',
      ),
      questionImages:
          (question['pytanie_images'] as List?)?.cast<String>() ?? [],
      questionVideos:
          (question['pytanie_videos'] as List?)?.cast<String>() ?? [],
      answers: showAnswers ? answers : const [],
      accentColor: accentColorOverride ?? cs.primary,
      showResult: showAnswers,
    );
  }
}

// ─────────────────────────────────────────────
//                  Page root
// ─────────────────────────────────────────────

class CreatingTestsAndReportsPage extends StatefulWidget {
  final bool isSuperAdmin;
  final String currentUserEmail;
  final String currentUserName;

  const CreatingTestsAndReportsPage({
    super.key,
    required this.isSuperAdmin,
    required this.currentUserName,
    required this.currentUserEmail,
  });

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
            elevation: 2,
            child: TabBar(
              controller: _tabController,
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurface.withValues(alpha: 0.5),
              indicatorColor: cs.primary,
              indicatorWeight: 3,
              dividerColor: cs.outlineVariant.withValues(alpha: 0.4),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.view_list_rounded),
                  text: 'Istniejące testy',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  icon: Icon(Icons.add_box_rounded),
                  text: 'Stwórz nowy test',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                CreatedTestsTab(
                  isSuperAdmin: widget.isSuperAdmin,
                  //currentUserEmail: widget.currentUserEmail,
                  currentUserName: widget.currentUserName,
                ),
                const CreateNewTestTab(),
              ],
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
        itemBuilder: (context, i) => RichQuestionWidget(
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
  final bool isSuperAdmin;
  //final String currentUserEmail;
  final String currentUserName;

  const CreatedTestsTab({
    super.key,
    required this.isSuperAdmin,
    //required this.currentUserEmail,
    required this.currentUserName,
  });
  @override
  State<CreatedTestsTab> createState() => _CreatedTestsTabState();
}

class _CreatedTestsTabState extends State<CreatedTestsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _innerTab;

  List<Map<String, dynamic>> savedTests = [];
  bool isLoadingTests = true;
  final Set<int> _loadedResultsForIds = {};
  final Set<int> _loadingResultsForIds = {};

  @override
  void initState() {
    super.initState();
    _innerTab = TabController(length: 2, vsync: this);
    _loadTests();
  }

  @override
  void dispose() {
    _innerTab.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────

  Future<void> _loadTests() async {
    if (kUseFakeData) {
      if (mounted) {
        setState(() {
          savedTests = _fakeTests
              .map((t) => Map<String, dynamic>.from(t))
              .toList();
          isLoadingTests = false;
        });
      }
      return;
    }

    setState(() => isLoadingTests = true);

    try {
      final result = await ApiService.instance.fetchAdminTestsMetadata();

      if (result.isSuccess) {
        final serverMaps = result.data!;
        for (final t in serverMaps) {
          t['results'] ??= <dynamic>[];
        }
        if (mounted) setState(() => savedTests = serverMaps);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_tests', json.encode(savedTests));
      } else {
        await _loadTestsFromCache();
      }
    } catch (_) {
      await _loadTestsFromCache();
    } finally {
      if (mounted) setState(() => isLoadingTests = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchFullTest(int id) async {
    if (kUseFakeData) {
      return savedTests.firstWhere((t) => t['id'] == id, orElse: () => {});
    }
    try {
      final result = await ApiService.instance.fetchAdminTestQuestions(id);
      if (result.isSuccess) return result.data;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Wystąpił błąd podczas pobierania pytań z testu: $e');
      }
    }
    return null;
  }

  Future<void> _loadTestsFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final localData = prefs.getString('saved_tests');
    if (localData != null) {
      final list = List<Map<String, dynamic>>.from(json.decode(localData));
      if (mounted) setState(() => savedTests = list);
    }
  }

  Future<void> _loadResultsForTest(int index) async {
    final test = savedTests[index];
    final id = test['id'] as int;

    if (_loadedResultsForIds.contains(id) ||
        _loadingResultsForIds.contains(id)) {
      return;
    }

    if (kUseFakeData) {
      setState(() => _loadedResultsForIds.add(id));
      return;
    }

    setState(() => _loadingResultsForIds.add(id));

    final testKey =
        '${test['name']}||${test['author']}||${test['qualification']}';
    try {
      final result = await ApiService.instance.fetchTestResults(testKey);
      if (result.isSuccess && mounted) {
        setState(() {
          savedTests[index]['results'] = result.data!;
          _loadedResultsForIds.add(id);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Wystąpił błąd podczas pobierania wyników testu o [$id]: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingResultsForIds.remove(id));
    }
  }

  // ── Actions ───────────────────────────────────────────────────

  Future<void> _deleteTest(int index) async {
    final test = savedTests[index];
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (kUseFakeData) {
      setState(() => savedTests.removeAt(index));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('[DEBUG] Test usunięty'),
            backgroundColor: cs.error,
          ),
        );
      }
      return;
    }

    try {
      await ApiService.instance.deleteTest(test['id'] as int);
    } catch (e) {
      if (kDebugMode) debugPrint('Wystąpił błąd podczas usuwania testu: $e');
    }

    setState(() => savedTests.removeAt(index));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_tests', json.encode(savedTests));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Test został usunięty'),
          backgroundColor: cs.error,
        ),
      );
    }
  }

  Future<void> _togglePublish(int index) async {
    final test = savedTests[index];
    final willPublish = !(test['published'] == true);
    final cs = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<ExtraColors>()!;

    final publishBackground = willPublish ? extras.correct : cs.secondary;

    if (kUseFakeData) {
      setState(() => savedTests[index]['published'] = willPublish);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '[DEBUG] ${willPublish ? 'Opublikowano' : 'Wycofano'}',
            ),
            backgroundColor: publishBackground,
          ),
        );
      }
      return;
    }

    setState(() => savedTests[index]['published'] = willPublish);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_tests', json.encode(savedTests));

    try {
      await ApiService.instance.setTestPublished(
        test['id'] as int,
        willPublish,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              willPublish
                  ? 'Test opublikowany dla wszystkich!'
                  : 'Test wycofany z publikacji',
            ),
            backgroundColor: publishBackground,
          ),
        );
      }
    } catch (_) {
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

  Future<void> _printTest(int index) async {
    final id = savedTests[index]['id'] as int;
    final test = await _fetchFullTest(id);
    if (test == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Nie udało się wczytać testu'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (_testContainsVideo(test)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ten test zawiera filmy — nie można wygenerować testu w pliku PDF'),
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
        footer: (ctx) => pw.Container(
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
    try {
      final result = await ApiService.instance.fetchExamPreviewForTest(examId);
      if (result.isSuccess && result.data?['success'] == true) {
        return {
          'questions': List<dynamic>.from(result.data!['questions']),
          'selectedAnswers': (result.data!['selectedAnswers'] as List)
              .cast<String?>(),
        };
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Wystąpił błąd podczas pobierania szczegółów testu: $e');
    }
    return null;
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<ExtraColors>()!;
    final tt = Theme.of(context).textTheme;

    if (isLoadingTests) {
      return Center(child: AsyncStateView.loading());
    }

    if (savedTests.isEmpty) {
      return Center(
        child: AsyncStateView.empty(
          message: 'Brak utworzonych testów',
          icon: Icons.folder_open_rounded,
        ),
      );
    }

    final myTests = savedTests
        .where((t) => t['author'] == widget.currentUserName)
        .toList();

    return Column(
      children: [
        // Inner tab bar
        Container(
          color: cs.surface,
          child: TabBar.secondary(
            controller: _innerTab,
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurface.withValues(alpha: 0.5),
            indicatorColor: cs.primary,
            dividerColor: cs.outlineVariant.withValues(alpha: 0.4),
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Moje testy'),
                    const SizedBox(width: 6),
                    _CountBadge(count: myTests.length),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Wszystkie testy'),
                    const SizedBox(width: 6),
                    _CountBadge(count: savedTests.length),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _innerTab,
            children: [
              _buildTestList(myTests, cs, extras, tt),
              _buildTestList(savedTests, cs, extras, tt),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTestList(
    List<Map<String, dynamic>> tests,
    ColorScheme cs,
    ExtraColors extras,
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
          final results =
              List<dynamic>.from((t['results'] as List<dynamic>?) ?? [])..sort(
                (a, b) => (b['date'] as String).compareTo(a['date'] as String),
              );
          final isPublished = t['published'] == true;
          final canEdit =
              widget.isSuperAdmin || t['author'] == widget.currentUserName;

          return _TestCard(
            test: t,
            results: results,
            isPublished: isPublished,
            canEdit: canEdit,
            cs: cs,
            extras: extras,
            tt: tt,
            isLoadingResults: _loadingResultsForIds.contains(t['id'] as int),
            onExpand: () => _loadResultsForTest(realIndex),
            onPreview: () async {
              final id = t['id'] as int;
              final full = await _fetchFullTest(id);
              if (!context.mounted) return;
              if (full == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Nie udało się wczytać testu'),
                    backgroundColor: cs.error,
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TestPreviewPage(
                    test: full,
                    onPublish: () => _togglePublish(realIndex),
                  ),
                ),
              );
            },
            onPrint: () => _printTest(realIndex),
            onDelete: canEdit ? () => _deleteTest(realIndex) : null,
            onTogglePublish: canEdit ? () => _togglePublish(realIndex) : null,
            onReport: () => _generateReportPdf(realIndex),
            onAnswerKey: () => _generateAnswerKeyPdf(realIndex),
            onExamPreview: (examId) async {
              final data = kUseFakeData
                  ? null
                  : await _fetchExamDetailsFull(examId);
              if (!context.mounted) return;
              if (data != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExamPreviewPage(
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

  // ── PDF generation ────────────────────────────────────────────

  Future<void> _generateAnswerKeyPdf(int index) async {
    final id = savedTests[index]['id'] as int;
    final fullTest = await _fetchFullTest(id);
    if (fullTest == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Nie udało się wczytać testu do klucza'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final String qual = fullTest['qualification'] as String;
    final questions = List<Map<String, dynamic>>.from(
      fullTest['questions'] as List,
    );

    List<dynamic> fullDb = [];

    if (kUseFakeData) {
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
        q['id'].toString(): (q['poprawna'] ?? '?')
            .toString()
            .trim()
            .toUpperCase(),
    };

    final answerRows = questions.asMap().entries.map((e) {
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
        build: (ctx) => [
          pw.Text(
            'Klucz Odpowiedzi — ${fullTest['name']}',
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
      'klucz_${(fullTest['name'] as String).replaceAll(' ', '_')}.pdf',
    );
  }

  Future<void> _generateReportPdf(int index) async {
    if (kUseFakeData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generowanie raportu niedostępne.')),
      );
      return;
    }
    final id = savedTests[index]['id'] as int;

    if (!_loadedResultsForIds.contains(id) &&
        !_loadingResultsForIds.contains(id)) {
      await _loadResultsForTest(index);
    }

    if (!mounted) return;

    final test = savedTests[index];
    final results = (test['results'] as List<dynamic>?) ?? [];

    if (results.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brak wyników do raportu')),
        );
      }
      return;
    }

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

    final rows = lastResults.values.map((r) {
      final name = (r['userName'] ?? 'Nieznany').toString();
      final uid = (r['uid'] ?? r['UID'] ?? '').toString();
      final rawScore = r['score'];
      final scoreNum = rawScore is num
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
        build: (ctx) => [
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

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: cs.primary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//               Test card widget
// ─────────────────────────────────────────────

class _TestCard extends StatelessWidget {
  const _TestCard({
    required this.test,
    required this.results,
    required this.isPublished,
    required this.canEdit,
    required this.cs,
    required this.extras,
    required this.tt,
    required this.isLoadingResults,
    required this.onExpand,
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
  final ExtraColors extras;
  final TextTheme tt;
  final bool isLoadingResults;
  final VoidCallback onExpand;
  final VoidCallback onPreview;
  final VoidCallback onPrint;
  final VoidCallback? onDelete;
  final VoidCallback? onTogglePublish;
  final VoidCallback onReport;
  final VoidCallback onAnswerKey;
  final void Function(int examId) onExamPreview;

  @override
  Widget build(BuildContext context) {
    final avg = results.isEmpty
        ? null
        : results
                  .map((r) => (r['score'] as num?)?.toDouble() ?? 0.0)
                  .reduce((a, b) => a + b) /
              results.length;
    final questionCount = test["question_count"];
    final isEmpty = questionCount == 0;
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
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: cs.surface,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final trailingMaxWidth = (constraints.maxWidth * 0.365).clamp(
                80.0,
                260.0,
              );
              return ExpansionTile(
                onExpansionChanged: (expanded) {
                  if (expanded) onExpand();
                },
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),

                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isPublished
                        ? extras.correct.withValues(alpha: 0.15)
                        : cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Tooltip(
                    padding: EdgeInsets.all(8),
                    message: isPublished
                        ? "Ten test jest dostępny do rozwiązywania przez uczniów."
                        : "Test został zamknięty i nie można go już rozwiązywać.",
                    child: Icon(
                      isPublished
                          ? Icons.public_outlined
                          : Icons.lock_outline_rounded,
                      size: 20,
                      color: isPublished ? extras.correct : cs.onSurfaceVariant,
                    ),
                  ),
                ),

                // ── Title ─────────────────────────────────────────────
                title: Row(
                  children: [
                    Container(
                      margin: EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.school_rounded,
                            size: 14,
                            color: cs.onPrimaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (test['qualification'] as String).toUpperCase(),
                            style: tt.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        test['name'] as String,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
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
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _SubtitleChip(
                        icon: Icons.person_rounded,
                        label: test['author'] as String,
                        cs: cs,
                        tt: tt,
                      ),
                      _SubtitleChip(
                        icon: Icons.library_books_rounded,
                        label: isEmpty ? 'Brak pytań' : '$questionCount pytań',
                        cs: cs,
                        tt: tt,
                      ),
                      if (avg != null)
                        _SubtitleChip(
                          icon: Icons.bar_chart_rounded,
                          label:
                              'Śr. ${avg.toStringAsFixed(1)}% (${results.length})',
                          cs: cs,
                          tt: tt,
                          highlight: true,
                        ),
                    ],
                  ),
                ),

                trailing: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: trailingMaxWidth),
                  child: _ActionMenu(
                    canEdit: canEdit,
                    isPublished: isPublished,
                    cs: cs,
                    extras: extras,
                    onPreview: onPreview,
                    onPrint: onPrint,
                    onDelete: onDelete,
                    onTogglePublish: onTogglePublish,
                    onReport: onReport,
                    onAnswerKey: onAnswerKey,
                  ),
                ),

                children: isLoadingResults
                    ? [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ]
                    : results.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_rounded,
                                size: 20,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.4,
                                ),
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
              );
            },
          ),
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
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: cs.surfaceContainerLowest,
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              leading: _ScoreBadge(score: latestScore, extras: extras),
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

              children: userResults.map((r) {
                final score = (r['score'] as num?)?.toDouble() ?? 0.0;
                final date = _fmtDate((r['date'] as String?) ?? '');
                final durSec = r['duration_sec'] is int
                    ? r['duration_sec'] as int
                    : int.tryParse('${r['duration_sec'] ?? ''}');
                final czas = _fmtDur(durSec);
                final examId =
                    int.tryParse((r['exam_id'] ?? r['id'] ?? '').toString()) ??
                    0;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  child: Row(
                    children: [
                      _ScoreBadge(score: score, extras: extras, small: true),
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
                          icon: const Icon(Icons.visibility_rounded, size: 14),
                          label: const Text('Podgląd'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            side: BorderSide(color: cs.primary),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
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
//                Action menu
// ─────────────────────────────────────────────

class _ActionMenu extends StatelessWidget {
  const _ActionMenu({
    required this.canEdit,
    required this.isPublished,
    required this.cs,
    required this.extras,
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
  final ExtraColors extras;
  final VoidCallback onPreview;
  final VoidCallback onPrint;
  final VoidCallback? onDelete;
  final VoidCallback? onTogglePublish;
  final VoidCallback onReport;
  final VoidCallback onAnswerKey;

  static const double _kButtonWidth = 40;

  List<_ActionItem> get _overflowItems => [
    _ActionItem(
      value: 'print',
      icon: Icons.local_print_shop_rounded,
      label: 'Drukuj PDF',
      onTap: onPrint,
    ),
    _ActionItem(
      value: 'report',
      icon: Icons.analytics_rounded,
      label: 'Raport wyników',
      color: Colors.deepPurple,
      onTap: onReport,
    ),
    _ActionItem(
      value: 'key',
      icon: Icons.key_rounded,
      label: 'Klucz odpowiedzi',
      color: Colors.teal,
      onTap: onAnswerKey,
    ),
    if (canEdit) ...[
      _ActionItem(
        value: 'publish',
        icon: isPublished ? Icons.public_off_rounded : Icons.public_rounded,
        label: isPublished ? 'Wycofaj' : 'Opublikuj',
        color: isPublished ? Colors.orange : extras.correct,
        onTap: onTogglePublish,
      ),
      _ActionItem(
        value: 'delete',
        icon: Icons.delete_forever_rounded,
        label: 'Usuń',
        color: extras.incorrect,
        onTap: onDelete,
      ),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final items = _overflowItems;
    final totalButtons = items.length + 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final everythingFits =
            constraints.maxWidth >= totalButtons * _kButtonWidth;

        if (everythingFits) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.visibility_rounded, color: cs.primary),
                tooltip: 'Podgląd testu',
                visualDensity: VisualDensity.compact,
                onPressed: onPreview,
              ),
              for (final item in items)
                IconButton(
                  icon: Icon(
                    item.icon,
                    color: item.color ?? cs.onSurfaceVariant,
                  ),
                  tooltip: item.label,
                  visualDensity: VisualDensity.compact,
                  onPressed: item.onTap,
                ),
            ],
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.visibility_rounded, color: cs.primary),
              tooltip: 'Podgląd testu',
              visualDensity: VisualDensity.compact,
              onPressed: onPreview,
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant),
              tooltip: 'Więcej opcji',
              onSelected: (value) {
                final item = items.firstWhere((e) => e.value == value);
                item.onTap?.call();
              },
              itemBuilder: (ctx) => [
                for (final item in items)
                  PopupMenuItem(
                    value: item.value,
                    child: ListTile(
                      leading: Icon(item.icon, color: item.color),
                      title: Text(
                        item.label,
                        style: item.color == cs.error
                            ? TextStyle(color: cs.error)
                            : null,
                      ),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ActionItem {
  const _ActionItem({
    required this.value,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final String value;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
}

// ─────────────────────────────────────────────
//             Shared small widgets
// ─────────────────────────────────────────────

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({
    required this.score,
    required this.extras,
    this.small = false,
  });
  final double score;
  final ExtraColors extras;
  final bool small;

  Color get _color => score >= 50 ? extras.correct : extras.incorrect;

  @override
  Widget build(BuildContext context) {
    final size = small ? 32.0 : 40.0;
    final strokeWidth = small ? 2.5 : 3.0;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ArcPainter(
          progress: score / 100,
          color: _color,
          trackColor: _color.withValues(alpha: 0.12),
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: Text(
            '${score.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: small ? 10 : 12,
              fontWeight: FontWeight.w800,
              color: _color,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2 - strokeWidth / 2,
    );

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -pi / 2, 2 * pi, false, trackPaint);
    canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, arcPaint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
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
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
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
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//             Create new test tab
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
    if (kUseFakeData) {
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
          final q = (exam['kwalifikacja'] ?? '')
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
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: selectedQualification,
            isExpanded: true,
            dropdownColor: cs.surfaceContainerLowest,
            menuMaxHeight: 400,
            decoration: InputDecoration(
              labelText: 'Wybierz kwalifikację',
              border: const OutlineInputBorder(),
              prefixIcon: Icon(Icons.school_rounded, color: cs.primary),
            ),
            items: qualifications
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
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TestCreatorPage(
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
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TestCreatorPage(
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
