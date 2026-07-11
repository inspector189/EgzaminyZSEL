import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:html_unescape_xx/html_unescape.dart';

import '/exam_results.dart';
import '/services/api_service.dart';
import '/utils/async_state_view.dart';
import '/utils/app_themes.dart';
import '/widgets/difficulty_badge.dart';
import '/widgets/exam_question_card.dart';
import '/widgets/exam_timer.dart';
import '/widgets/shim_box.dart';

// ──────────────
// Design tokens
// ──────────────

const double _kCardRadius = 12.0;
const double _kAccentWidth = 4.0;

String _stripAnswerPrefix(String text) =>
    text.replaceFirst(RegExp(r'^\s*[A-Da-d][.)]\s*'), '').trimLeft();

// ──────────────
// Mode helpers
// ──────────────

enum TrybEgzaminu { singleQuestion, normalTest, allQuestions, publishedTest }

extension _TrybX on TrybEgzaminu {
  bool get isTimed =>
      this == TrybEgzaminu.normalTest || this == TrybEgzaminu.publishedTest;
  bool get hasFinishButton => isTimed;
  bool get isAllQuestions => this == TrybEgzaminu.allQuestions;
  bool get isSingleQuestion => this == TrybEgzaminu.singleQuestion;
  bool get showResultImmediately =>
      this == TrybEgzaminu.allQuestions || this == TrybEgzaminu.singleQuestion;
}

// ──────────────
// Widget
// ──────────────

class EgzaminView extends StatefulWidget {
  const EgzaminView({
    super.key,
    required this.tryb,
    required this.kwalifikacja,
    required this.returnToHome,
    this.userName,
    this.testData,
  }) : assert(
         tryb != TrybEgzaminu.publishedTest || testData != null,
         'testData musi być obecne dla testów nauczyciela!',
       );

  final TrybEgzaminu tryb;
  final String kwalifikacja;
  final bool returnToHome;
  final String? userName;
  final Map<String, dynamic>? testData;

  @override
  State<EgzaminView> createState() => _EgzaminViewState();
}

class _EgzaminViewState extends State<EgzaminView> {
  // ── Helpers ──────
  final _unescape = HtmlUnescapeSmall();
  String _clean(String? s) => _unescape.convert(s?.toString() ?? '');
  TrybEgzaminu get _tryb => widget.tryb;

  // ── Timer ────────
  Timer? _examTimer;
  final int minutesToEndExam = 60;
  DateTime _endTime = DateTime.now();
  late DateTime startTime;

  void _startTimer() {
    _examTimer?.cancel();
    _endTime = DateTime.now().add(Duration(minutes: minutesToEndExam));
    startTime = DateTime.now();
    _examTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (DateTime.now().difference(startTime) >=
          Duration(minutes: minutesToEndExam)) {
        t.cancel();
        _finishExam();
      }
    });
  }

  // ── Scroll / lazy loading ───
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollDebounce;
  int _visibleCount = 30;

  void _onScroll() {
    if (_scrollDebounce?.isActive ?? false) return;
    if (_visibleCount >= questions.length) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _scrollDebounce = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _visibleCount = (_visibleCount + 30).clamp(0, questions.length);
          });
        }
      });
    }
  }

  // ── Search ─────────
  final TextEditingController _textSearchCtrl = TextEditingController();
  String searchText = '';

  List<dynamic> get _filteredQuestions {
    if (!_tryb.isAllQuestions || searchText.trim().isEmpty) return questions;
    final q = searchText.trim().toLowerCase();
    return questions.where((e) {
      return (e['pytanie_text']?.toString() ?? '').toLowerCase().contains(q) ||
          (e['odp1_text']?.toString() ?? '').toLowerCase().contains(q) ||
          (e['odp2_text']?.toString() ?? '').toLowerCase().contains(q) ||
          (e['odp3_text']?.toString() ?? '').toLowerCase().contains(q) ||
          (e['odp4_text']?.toString() ?? '').toLowerCase().contains(q) ||
          (e['id']?.toString() ?? '').toLowerCase().contains(q);
    }).toList();
  }

  List<dynamic> questions = [];
  List<String?> selectedAnswers = [];
  bool isLoading = true;
  bool _isButtonDisabled = false;

  int current = 0;
  bool odpowiedzZatwierdzona = false;
  bool _isLoadingNext = false;

  bool _fetched = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fetched) {
      _fetched = true;
      fetchQuestions();
    }
  }

  @override
  void dispose() {
    _examTimer?.cancel();
    _scrollDebounce?.cancel();
    _scrollController.dispose();
    _textSearchCtrl.dispose();
    super.dispose();
  }

  // ── Data fetching ─────────────────────────

  Future<void> fetchQuestions() async {
    try {
      final selected = await _fetchFromApi();

      _applyQuestionMetadata(selected);

      if (mounted) {
        setState(() {
          questions = selected;
          selectedAnswers = List.filled(selected.length, null);
          isLoading = false;
          _visibleCount = 30.clamp(0, selected.length);
        });
      }

      if (_tryb.isTimed) _startTimer();
    } catch (e) {
      if (kDebugMode) debugPrint('Pobranie pytań nie powiodło się: $e');
    }
  }

  Future<List<dynamic>> _fetchFromApi() async {
    if (_tryb == TrybEgzaminu.publishedTest) {
      if (widget.testData == null) {
        throw Exception('Brak testData w trybie zTestu!');
      }
      return List.from(widget.testData!['questions'] ?? []);
    }

    final int? limit = switch (_tryb) {
      TrybEgzaminu.singleQuestion => 1,
      TrybEgzaminu.normalTest => 40,
      _ => null,
    };

    final result = await ApiService.instance.fetchQuestions(
      widget.kwalifikacja.replaceAll(' ', ''),
      limit: limit,
    );
    if (!result.isSuccess || result.data == null) return [];
    return result.data!;
  }

  void _applyQuestionMetadata(List<dynamic> questions) {
    for (var q in questions) {
      q['pytanie_text'] = _clean(q['pytanie']);
      q['pytanie_images'] = (q['images'] as List?)?.cast<String>() ?? [];
      q['pytanie_videos'] = (q['videos'] as List?)?.cast<String>() ?? [];
      for (int i = 1; i <= 4; i++) {
        final key = 'odp$i';
        q['${key}_text'] = _clean(q[key]);
        q['${key}_images'] =
            (q['${key}_images'] as List?)?.cast<String>() ?? [];
        q['${key}_videos'] =
            (q['${key}_videos'] as List?)?.cast<String>() ?? [];
      }
    }
    for (int i = 0; i < questions.length; i++) {
      questions[i]['_originalIndex'] = i;
    }
  }

  // ── Difficulty ────────────────────────────

  Future<void> _recordDifficulty(int id, bool correct) async {
    if (id <= 0) return;
    final result = await ApiService.instance.recordDifficulty(
      id,
      widget.kwalifikacja,
      correct,
    );
    if (!result.isSuccess && mounted && kDebugMode) {
      debugPrint('Zapis trudności nie powiódł się: ${result.errorMessage}');
    }
  }

  // ── Single question actions ───────────────

  Future<void> _losujNowePytanie() async {
    if (_isLoadingNext) return;
    setState(() => _isLoadingNext = true);
    try {
      final result = await ApiService.instance.fetchQuestions(
        widget.kwalifikacja.replaceAll(' ', ''),
        limit: 1,
      );
      if (!result.isSuccess || result.data == null || result.data!.isEmpty) {
        return;
      }
      final fetched = result.data!;
      _applyQuestionMetadata(fetched);
      if (mounted) {
        setState(() {
          questions = fetched;
          current = 0;
          selectedAnswers = List.filled(fetched.length, null);
          odpowiedzZatwierdzona = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingNext = false);
    }
  }

  // ── Exam finish ───────────────────────────

  Future<void> _confirmFinishExam() async {
    if (_isButtonDisabled) return;
    final shouldFinish = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Zakończyć egzamin?'),
        content: const Text(
          'Czy na pewno chcesz zakończyć egzamin?\n'
          'Po zakończeniu nie będzie można zmienić odpowiedzi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Zakończ'),
          ),
        ],
      ),
    );
    if (shouldFinish == true) await _finishExam();
  }

  Future<void> _finishExam() async {
    setState(() => _isButtonDisabled = true);

    int correct = 0;
    for (int i = 0; i < questions.length; i++) {
      if (selectedAnswers[i] == questions[i]['poprawna']) correct++;
    }

    final percent = (correct / questions.length) * 100;
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime).inSeconds;
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('userName') ?? 'anonymous';

    final pytaniaDoBazy = questions
        .map(
          (q) => {
            'id': q['id'],
            'pytanie': q['pytanie'],
            'poprawna': q['poprawna'],
          },
        )
        .toList();

    final testData = widget.testData;
    if (testData != null) {
      final result = await ApiService.instance.savePublishedTestResult({
        'userName': userName,
        'test_key':
            '${testData['name']}||${testData['author']}||${testData['qualification']}',
        'score': percent,
        'kwalifikacja': widget.kwalifikacja.replaceAll(' ', '').toLowerCase(),
        'date': endTime.toIso8601String(),
        'duration_sec': duration,
        'selectedAnswers': selectedAnswers,
        'questions': pytaniaDoBazy,
      });
      if (!result.isSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd zapisu wyniku testu: ${result.errorMessage}'),
          ),
        );
      }
    } else {
      final result = await ApiService.instance.saveExam({
        'kwalifikacja': widget.kwalifikacja,
        'wynik': percent,
        'data_czas': endTime.toIso8601String(),
        'czas_trwania': duration,
        'userName': userName,
        'pytania': pytaniaDoBazy,
        'wybrane_odpowiedzi': selectedAnswers,
      });
      if (!result.isSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd zapisu egzaminu: ${result.errorMessage}'),
          ),
        );
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamResultsPage(
          correctAnswers: correct,
          totalQuestions: questions.length,
          questions: questions,
          selectedAnswers: selectedAnswers,
          returnToHome: true,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    AppBar buildAppBar({bool simple = false}) => AppBar(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      iconTheme: IconThemeData(color: cs.onPrimary),
      actionsIconTheme: IconThemeData(color: cs.onPrimary),
      title: simple
          ? const Text('Egzamin')
          : Row(
              children: [
                Text(
                  'Egzamin',
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _tryb.isTimed
                        ? ExamTimer(endTime: _endTime)
                        : const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
    );

    if (isLoading) {
      return Scaffold(
        appBar: buildAppBar(simple: true),
        body: Center(child: AsyncStateView.loading()),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        appBar: buildAppBar(simple: true),
        body: Center(
          child: AsyncStateView.empty(
            message: 'Brak pytań',
            subtitle: 'Ten egzamin nie zawiera żadnych pytań.',
            icon: Icons.quiz_outlined,
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!_tryb.isTimed) {
          Navigator.of(context).pop();
          return;
        }
        final leave = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Opuścić egzamin?'),
            content: const Text(
              'Czy na pewno chcesz opuścić egzamin?\n'
              'Twój postęp zostanie utracony.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Zostań'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Opuść'),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: buildAppBar(),
        body: switch (_tryb) {
          TrybEgzaminu.singleQuestion => _buildSingleQuestion(),
          _ => _buildLazyList(),
        },
        bottomNavigationBar: _tryb.hasFinishButton
            ? _buildFinishButton(context)
            : null,
      ),
    );
  }

  // ── Single question layout ────────────────

  Widget _buildSingleQuestion() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildQuestionCard(
          context,
          questions[current],
          index: current,
          showResult: odpowiedzZatwierdzona,
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            onPressed: _isLoadingNext ? null : _losujNowePytanie,
            icon: const Icon(Icons.shuffle_rounded),
            label: const Text('Losuj kolejne'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  // ── List layout

  Widget _buildLazyList() {
    final items = _filteredQuestions.take(_visibleCount).toList();
    final showResult = _tryb.showResultImmediately;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        if (_tryb.isAllQuestions)
          SliverPersistentHeader(
            pinned: true,
            delegate: _SearchHeader(
              child: Container(
                color: cs.surface,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _textSearchCtrl,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Szukaj pytania lub ID...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: searchText.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 20),
                                onPressed: () {
                                  _textSearchCtrl.clear();
                                  setState(() {
                                    searchText = '';
                                    _visibleCount = 30.clamp(
                                      0,
                                      _filteredQuestions.length,
                                    );
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.primary, width: 2),
                        ),
                        filled: true,
                        fillColor: cs.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                      onChanged: (v) => setState(() {
                        searchText = v;
                        _visibleCount = 30.clamp(0, _filteredQuestions.length);
                      }),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 9,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.saved_search_rounded,
                            size: 17,
                            color: cs.onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Znalezione: ${_filteredQuestions.length} / ${questions.length}',
                              style: tt.bodyMedium?.copyWith(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (_filteredQuestions.length != questions.length)
                            Text(
                              '(${questions.length - _filteredQuestions.length} ukrytych)',
                              style: tt.labelSmall?.copyWith(
                                color: cs.onPrimaryContainer.withValues(
                                  alpha: 0.75,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (i >= items.length) return _buildShimmer(context);
                final q = items[i];
                final originalIndex = q['_originalIndex'] as int? ?? i;
                return RepaintBoundary(
                  child: _buildQuestionCard(
                    context,
                    q,
                    index: originalIndex,
                    showResult: showResult,
                  ),
                );
              },
              childCount: items.length,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
              addSemanticIndexes: false,
            ),
          ),
        ),
      ],
    );
  }

  // ── Question card ─────────────────────────

  String _questionLabel(int index, dynamic q) {
    if (_tryb.isAllQuestions) {
      final id = q['id'] != null ? 'ID #${q['id']}' : '';
      return id;
    }
    return 'Pytanie';
  }

  List<ExamAnswerState> _buildAnswers(dynamic q, int index) =>
      ['A', 'B', 'C', 'D'].map((letter) {
        final key = 'odp${'ABCD'.indexOf(letter) + 1}';
        return ExamAnswerState(
          letter: letter,
          text: _stripAnswerPrefix(q['${key}_text'] as String? ?? ''),
          images: List<String>.from(q['${key}_images'] ?? []),
          videos: List<String>.from(q['${key}_videos'] ?? []),
          isCorrect: letter == q['poprawna'],
          isSelected: selectedAnswers[index] == letter,
        );
      }).toList();

  Widget _buildQuestionCard(
    BuildContext context,
    dynamic q, {
    required int index,
    required bool showResult,
  }) {
    final cs = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<ExtraColors>()!;
    final poprawna = q['poprawna']?.toString() ?? '';
    final selected = selectedAnswers[index];

    final Color accent = !showResult || selected == null
        ? cs.primary
        : selected == poprawna
        ? extras.correct
        : extras.incorrect;

    Widget? resultBanner;
    if (showResult && selected != null) {
      final isCorrect = selected == poprawna;
      final color = isCorrect ? extras.correct : extras.incorrect;
      resultBanner = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(
              isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isCorrect
                    ? 'Wybrano poprawną odpowiedź: $selected.'
                    : 'Niepoprawna: $selected.  Poprawna: $poprawna.',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ExamQuestionCard(
      label: _questionLabel(index, q),
      questionText: q['pytanie_text'] as String? ?? '',
      questionImages: List<String>.from(q['pytanie_images'] ?? []),
      questionVideos: List<String>.from(q['pytanie_videos'] ?? []),
      answers: _buildAnswers(q, index),
      accentColor: accent,
      showResult: showResult,
      headerTrailing: DifficultyBadge(
        trudnosc: q['trudnosc'] is num
            ? (q['trudnosc'] as num).toDouble()
            : double.tryParse(q['trudnosc']?.toString() ?? '') ?? 0.0,
        ilosc: int.tryParse(q['ilosc_odpowiedzi']?.toString() ?? '') ?? 0,
      ),
      onAnswerTap: showResult
          ? null
          : (letter) {
              setState(() {
                selectedAnswers[index] = letter;
                if (_tryb.isSingleQuestion) {
                  odpowiedzZatwierdzona = true;
                  final id = int.tryParse(q['id']?.toString() ?? '') ?? 0;
                  _recordDifficulty(id, letter == poprawna);
                }
              });
            },
      resultBanner: resultBanner,
    );
  }

  // ── Finish button ─────────────────────────

  Widget _buildFinishButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: FilledButton(
        onPressed: _isButtonDisabled ? null : _confirmFinishExam,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
        ),
        child: Text(
          _isButtonDisabled ? 'Wysyłanie...' : 'Zakończ egzamin',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ── Shimmer ───────────────────────────────

  Widget _buildShimmer(BuildContext context) {
    final extras = Theme.of(context).extension<ExtraColors>()!;
    final cs = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: extras.shimmerBase,
        highlightColor: extras.shimmerHighlight,
        period: const Duration(milliseconds: 900),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(_kCardRadius),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                width: _kAccentWidth,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(_kCardRadius),
                    bottomLeft: Radius.circular(_kCardRadius),
                  ),
                  child: ColoredBox(color: extras.shimmerHighlight),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kAccentWidth + 12,
                  12,
                  12,
                  14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ShimBox(w: 100, h: 20, cs: cs, radius: 6),
                        const Spacer(),
                        ShimBox(w: 80, h: 20, cs: cs, radius: 20),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ShimBox(w: double.infinity, h: 15, cs: cs),
                    const SizedBox(height: 6),
                    ShimBox(w: double.infinity, h: 15, cs: cs),
                    const SizedBox(height: 6),
                    ShimBox(w: 200, h: 15, cs: cs),
                    const SizedBox(height: 14),
                    for (int i = 0; i < 4; i++) ...[
                      ShimBox(w: double.infinity, h: 44, cs: cs, radius: 8),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Search header ─────────────────────────────

class _SearchHeader extends SliverPersistentHeaderDelegate {
  const _SearchHeader({required this.child});
  final Widget child;

  @override
  double get minExtent => 120;
  @override
  double get maxExtent => 120;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      elevation: overlapsContent ? 2 : 0,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _SearchHeader old) => old.child != child;
}
