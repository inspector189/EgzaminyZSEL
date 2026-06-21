import 'package:flutter/material.dart';
import 'package:flutter_app/services/api_service.dart';
import 'package:flutter_app/utils/async_state_view.dart';
import 'package:flutter_app/utils/helpers.dart';
import 'exam_solving.dart';

final _fakeTests = [
  {
    'name': 'Test próbny nr 1',
    'qualification': 'inf03',
    'author': 'jan.kowalski@szkola.pl',
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
  },
  {
    'name': 'Sprawdzian końcowy',
    'qualification': 'inf04',
    'author': 'anna.nowak@szkola.pl',
    'questions': List.generate(
      20,
      (i) => {
        'id': '${100 + i}',
        'pytanie_text': 'Pytanie sprawdzianu nr ${i + 1}',
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
  },
  {
    'name': 'Pusty test (błąd serwera)',
    'qualification': 'ee08',
    'author': 'system',
    'questions': <dynamic>[],
  },
];

class PublishedTestsPage extends StatefulWidget {
  final String qualification;
  const PublishedTestsPage({super.key, required this.qualification});

  @override
  State<PublishedTestsPage> createState() => _PublishedTestsPageState();
}

class _PublishedTestsPageState extends State<PublishedTestsPage> {
  List<Map<String, dynamic>> publishedTests = [];
  bool isLoading = true;
  String? errorMessage;

  // Hoisted normalisation so it isn't called redundantly in the loop
  late final String _normalizedQual = _normalize(widget.qualification);

  static String _normalize(String q) =>
      q.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();

  @override
  void initState() {
    super.initState();
    _loadPublishedTests();
  }

  Future<void> _loadPublishedTests() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      publishedTests = [];
    });

    if (kUseFakeData) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() {
        publishedTests = _fakeTests
            .where(
              (t) =>
                  _normalize(t['qualification'] as String) == _normalizedQual,
            )
            .map((t) => Map<String, dynamic>.from(t))
            .toList();
        isLoading = false;
      });
      return;
    }

    try {
      final result = await ApiService.instance.fetchUserTestsMetadata(
        _normalizedQual,
      );
      if (!mounted) return;

      if (result.isSuccess) {
        setState(() {
          publishedTests = result.data!;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Błąd serwera: ${result.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _startTest(Map<String, dynamic> testMeta) async {
    final id = testMeta['id'] as int;

    Map<String, dynamic>? full;
    if (kUseFakeData) {
      full = _fakeTests.firstWhere(
        (t) => t['name'] == testMeta['name'],
        orElse: () => {},
      );
    } else {
      setState(() => isLoading = true);
      final result = await ApiService.instance.fetchUserTestQuestions(id);
      if (mounted) setState(() => isLoading = false);
      if (result.isSuccess) full = result.data;
    }

    if (!mounted) return;

    if (full == null || full.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się wczytać testu')),
      );
      return;
    }

    final questions = List<Map<String, dynamic>>.from(full['questions'] as List)
      ..shuffle();
    final shuffledTest = Map<String, dynamic>.from(full);
    shuffledTest['questions'] = questions;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EgzaminView(
          tryb: TrybEgzaminu.zTestu,
          kwalifikacja: widget.qualification,
          returnToHome: false,
          userName: null,
          testData: shuffledTest,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final qual = widget.qualification.toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: Text('Testy — $qual'),
        iconTheme: IconThemeData(color: cs.onPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Odśwież',
            onPressed: _loadPublishedTests,
          ),
        ],
      ),
      body: _buildBody(cs, tt),
    );
  }

  Widget _buildBody(ColorScheme cs, TextTheme tt) {
    if (isLoading) {
      return Center(child: AsyncStateView.loading());
    }

    if (errorMessage != null) {
      return Center(
        child: AsyncStateView.error(
          message: 'Błąd ładowania',
          subtitle: errorMessage,
          icon: Icons.cloud_off_rounded,
        ),
      );
    }

    if (publishedTests.isEmpty) {
      return Center(
        child: AsyncStateView.empty(
          message: 'Brak opublikowanych testów',
          subtitle:
              'Brak testów od nauczycieli dla kwalifikacji ${widget.qualification.toUpperCase()}.',
          icon: Icons.assignment_outlined,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPublishedTests,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: publishedTests.length,
        itemBuilder: (context, i) => _TestCard(
          test: publishedTests[i],
          cs: cs,
          tt: tt,
          onTap: () => _startTest(publishedTests[i]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Test card
// ─────────────────────────────────────────────

class _TestCard extends StatelessWidget {
  const _TestCard({
    required this.test,
    required this.cs,
    required this.tt,
    required this.onTap,
  });

  final Map<String, dynamic> test;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = test['name'] as String;
    final author = (test['author'] as String? ?? '').replaceAll(
      RegExp(r'@.*'),
      '',
    );
    final questionCount = test['question_count'] as int? ?? 0;
    final isEmpty = questionCount == 0;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: isEmpty ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isEmpty
                ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
                : cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isEmpty
                  ? cs.outlineVariant.withValues(alpha: 0.2)
                  : cs.outlineVariant.withValues(alpha: 0.4),
            ),
            boxShadow: isEmpty
                ? null
                : [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isEmpty
                        ? cs.surfaceContainerHighest
                        : cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: isEmpty
                      ? Icon(
                          Icons.warning_amber_rounded,
                          size: 20,
                          color: cs.error,
                        )
                      : Text(
                          initial,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isEmpty ? cs.onSurfaceVariant : cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 13,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            author,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.quiz_rounded,
                            size: 13,
                            color: isEmpty ? cs.error : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isEmpty ? 'Brak pytań' : '$questionCount pytań',
                            style: tt.bodySmall?.copyWith(
                              color: isEmpty ? cs.error : cs.onSurfaceVariant,
                              fontWeight: isEmpty
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Chevron / disabled indicator
                if (!isEmpty)
                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
