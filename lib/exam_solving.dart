import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'exam_results.dart';
import 'dart:math';
import 'package:shimmer/shimmer.dart';
import 'package:html_unescape/html_unescape.dart';
import 'dart:async';
import 'utils/app_themes.dart';
import 'widgets/exam_timer.dart';
import 'widgets/video_player.dart';
import 'widgets/zoomable_image.dart';
import 'widgets/shim_box.dart';

const double _minImageHeight = 100;
const double _maxImageHeight = 500;

// ──────────────
// Design tokens
// ──────────────

const double _kCardRadius = 12.0;
const double _kAccentWidth = 4.0;
const double _kHardTreshold = 50.0;

String _stripAnswerPrefix(String text) {
  return text.replaceFirst(RegExp(r'^\s*[A-Da-d][.)]\s*'), '').trimLeft();
}

enum TrybEgzaminu { jednoPytanie, czterdziesciPytan, wszystkie, zTestu }

class EgzaminView extends StatefulWidget {
  final TrybEgzaminu tryb;
  final String kwalifikacja;
  final bool returnToHome;
  final String? userName;
  final Map<String, dynamic>? testData;

  const EgzaminView({
    super.key,
    required this.tryb,
    required this.kwalifikacja,
    required this.returnToHome,
    this.userName,
    this.testData,
  }) : assert(
         tryb != TrybEgzaminu.zTestu || testData != null,
         'testData must be provided for TrybEgzaminu.zTestu',
       );

  @override
  State<EgzaminView> createState() => _EgzaminViewState();
}

class _EgzaminViewState extends State<EgzaminView> {
  final _unescape = HtmlUnescape();
  Timer? _timer;
  final int minutesToEndExam = 60;
  DateTime _endTime = DateTime.now();
  String _clean(String? s) => _unescape.convert(s?.toString() ?? '');

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final elapsed = DateTime.now().difference(startTime);
      final remaining = Duration(minutes: minutesToEndExam) - elapsed;
      if (remaining.isNegative) {
        timer.cancel();
        _finishExam();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollDebounce?.cancel();
    _textSearchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  final TextEditingController _textSearchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String searchText = '';

  int _visibleCount = 30;
  final bool _isLoadingMore = false;
  int get _totalQuestions => questions.length;

  List<dynamic> get _filteredQuestions {
    if (widget.tryb != TrybEgzaminu.wszystkie) return questions;
    final q = searchText.trim().toLowerCase();
    if (q.isEmpty) return questions;
    return questions.where((e) {
      final txt = (e['pytanie_text']?.toString() ?? '').toLowerCase();
      final a = (e['odp1_text']?.toString() ?? '').toLowerCase();
      final b = (e['odp2_text']?.toString() ?? '').toLowerCase();
      final c = (e['odp3_text']?.toString() ?? '').toLowerCase();
      final d = (e['odp4_text']?.toString() ?? '').toLowerCase();
      final id = (e['id']?.toString() ?? '').toLowerCase();
      return txt.contains(q) ||
          a.contains(q) ||
          b.contains(q) ||
          c.contains(q) ||
          d.contains(q) ||
          id.contains(q);
    }).toList();
  }

  List<dynamic> get _displayedQuestions {
    final list =
        widget.tryb == TrybEgzaminu.wszystkie ? _filteredQuestions : questions;
    return list.take(_visibleCount).toList();
  }

  bool _isButtonDisabled = false;
  List<dynamic> questions = [];
  int current = 0;
  bool isLoading = true;
  List<String?> selectedAnswers = [];
  late DateTime startTime;
  bool odpowiedzZatwierdzona = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  bool _fetched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fetched) {
      fetchQuestions();
      _fetched = true;
    }
  }

  Timer? _scrollDebounce;

  void _onScroll() {
    if (_scrollDebounce?.isActive ?? false) return;
    if (_visibleCount >= _totalQuestions) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _scrollDebounce = Timer(const Duration(milliseconds: 200), () {
        setState(() {
          _visibleCount = (_visibleCount + 30).clamp(0, _totalQuestions);
        });
      });
    }
  }

  Future<void> fetchQuestions() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final testData = args?['testData'] as Map<String, dynamic>?;

    if (testData != null) {
      try {
        final result = await ApiService.instance.fetchPublishedTests();
        if (result.isSuccess && result.data != null) {
          final List<dynamic> allPublished = result.data ?? [];
          final matching = allPublished.firstWhere(
            (t) =>
                t['name'] == testData['name'] &&
                t['author'] == testData['author'] &&
                t['qualification'] == testData['qualification'],
            orElse: () => null,
          );
          if (matching != null) {
            final List<dynamic> fetched = List.from(
              matching['test_json'] ?? [],
            );
            for (var q in fetched) {
              q['pytanie_text'] = _clean(q['pytanie']);
              q['pytanie_images'] =
                  (q['images'] as List?)?.cast<String>() ?? [];
              q['pytanie_videos'] =
                  (q['videos'] as List?)?.cast<String>() ?? [];
              for (int i = 1; i <= 4; i++) {
                final key = 'odp$i';
                q['${key}_text'] = _clean(q[key]);
                q['${key}_images'] =
                    (q['${key}_images'] as List?)?.cast<String>() ?? [];
                q['${key}_videos'] =
                    (q['${key}_videos'] as List?)?.cast<String>() ?? [];
              }
            }
            for (int i = 0; i < fetched.length; i++) {
              fetched[i]['_originalIndex'] = i;
            }
            if (mounted) {
              setState(() {
                questions = fetched;
                selectedAnswers = List.filled(fetched.length, null);
                isLoading = false;
                _visibleCount = 30.clamp(0, fetched.length);
              });
            }
            if (widget.tryb == TrybEgzaminu.czterdziesciPytan) {
              _endTime = DateTime.now().add(
                Duration(minutes: minutesToEndExam),
              );
              startTime = DateTime.now();
              _startTimer();
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Pobranie pytań nauczyciela nie powiodło się: $e');
        }
      }
    } else {
      final kwalifikacja = widget.kwalifikacja.replaceAll(' ', '');
      try {
        final result = await ApiService.instance.fetchQuestions(kwalifikacja);
        if (result.isSuccess && result.data != null) {
          final List<dynamic> all = result.data!;
          List<dynamic> selected = [];
          switch (widget.tryb) {
            case TrybEgzaminu.jednoPytanie:
              selected = List.from(all)..shuffle();
              break;
            case TrybEgzaminu.czterdziesciPytan:
              selected = (List.from(all)..shuffle()).take(40).toList();
              break;
            case TrybEgzaminu.wszystkie:
              selected = all;
              break;
            case TrybEgzaminu.zTestu:
              if (widget.testData == null) {
                throw Exception('Brak testData w trybie zTestu!');
              }
              selected = List.from(widget.testData!['questions'] ?? []);
              break;
          }
          for (var q in selected) {
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
          for (int i = 0; i < selected.length; i++) {
            selected[i]['_originalIndex'] = i;
          }
          if (mounted) {
            setState(() {
              questions = selected;
              selectedAnswers = List.filled(selected.length, null);
              isLoading = false;
              _visibleCount = 30.clamp(0, selected.length);
            });
          }
          if (widget.tryb == TrybEgzaminu.czterdziesciPytan) {
            _endTime = DateTime.now().add(Duration(minutes: minutesToEndExam));
            startTime = DateTime.now();
            _startTimer();
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Pobranie pytań nie powiodło się: $e');
      }
    }
  }

  Future<void> zapiszTrudnoscDoBazy(
    int pytanieId,
    String kwalifikacja,
    bool poprawna,
  ) async {
    if (pytanieId <= 0) return;
    final result = await ApiService.instance.recordDifficulty(
      pytanieId,
      kwalifikacja,
      poprawna,
    );
    if (!result.isSuccess && mounted) {
      debugPrint('Zapis trudności nie powiódł się: ${result.errorMessage}');
    }
  }

  Widget _buildDifficultyBadge(BuildContext context, dynamic q) {
    final extras = Theme.of(context).extension<ExtraColors>()!;

    final ilosc = int.tryParse(q['ilosc_odpowiedzi']?.toString() ?? '') ?? 0;
    final trudnosc =
        q['trudnosc'] is num
            ? (q['trudnosc'] as num).toDouble()
            : double.tryParse(q['trudnosc']?.toString() ?? '') ?? 0.0;

    if (ilosc < 5) return const SizedBox.shrink();

    final isHard = trudnosc > _kHardTreshold;
    final color = isHard ? extras.incorrect : extras.correct;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHard ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${isHard ? "TRUDNE" : "ŁATWE"} ${trudnosc.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerButton(
    BuildContext context,
    String litera,
    String text,
    List<String> images,
    List<String> videos, {
    required bool isSelected,
    required bool isCorrect,
    required bool showResult,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<ExtraColors>()!;

    final Color borderColor;
    final Color bgColor;
    final Color circleColor;
    final Color textColor;
    Widget? trailingIcon;

    if (showResult) {
      if (isCorrect) {
        borderColor = extras.correct.withValues(alpha: 0.6);
        bgColor = extras.correct.withValues(alpha: 0.12);
        circleColor = extras.correct;
        textColor = cs.onSurface;
        trailingIcon = Icon(
          Icons.check_circle_rounded,
          size: 16,
          color: extras.correct,
        );
      } else if (isSelected) {
        borderColor = extras.incorrect.withValues(alpha: 0.6);
        bgColor = extras.incorrect.withValues(alpha: 0.10);
        circleColor = extras.incorrect;
        textColor = cs.onSurface;
        trailingIcon = Icon(
          Icons.cancel_rounded,
          size: 16,
          color: extras.incorrect,
        );
      } else {
        borderColor = cs.outlineVariant.withValues(alpha: 0.28);
        bgColor = cs.surfaceContainerHighest.withValues(alpha: 0.35);
        circleColor = cs.outlineVariant.withValues(alpha: 0.3);
        textColor = cs.onSurfaceVariant;
      }
    } else if (isSelected) {
      borderColor = cs.primary.withValues(alpha: 0.6);
      bgColor = cs.primary.withValues(alpha: 0.10);
      circleColor = cs.primary;
      textColor = cs.onSurface;
    } else {
      borderColor = cs.outlineVariant.withValues(alpha: 0.28);
      bgColor = cs.surfaceContainerHighest.withValues(alpha: 0.42);
      circleColor = cs.outlineVariant.withValues(alpha: 0.3);
      textColor = cs.onSurfaceVariant;
    }

    return GestureDetector(
      onTap: showResult ? null : onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: (isSelected || (showResult && isCorrect)) ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                litera,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? cs.surface : cs.onPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: textColor,
                      fontWeight:
                          isSelected || (showResult && isCorrect)
                              ? FontWeight.w600
                              : FontWeight.normal,
                    ),
                  ),
                  ...images.map(
                    (url) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: _minImageHeight,
                            maxHeight: _maxImageHeight,
                          ),
                          child: buildZoomableImage(context, url),
                        ),
                      ),
                    ),
                  ),
                  ...videos.map(
                    (url) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        height: 400,
                        child: InlineVideoPlayer(url: url, height: 400),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (trailingIcon != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 3),
                child: trailingIcon,
              ),
          ],
        ),
      ),
    );
  }

  String _questionLabel(int index, dynamic q) {
    final id = q['id'] != null ? ' (ID ${q['id']})' : '';
    switch (widget.tryb) {
      case TrybEgzaminu.jednoPytanie:
        return 'Pytanie';
      case TrybEgzaminu.wszystkie:
        return 'Pytanie ${index + 1}$id';
      case TrybEgzaminu.czterdziesciPytan:
        return 'Pytanie ${index + 1}';
      case TrybEgzaminu.zTestu:
        return 'Pytanie ${index + 1}$id';
    }
  }

  Widget _buildQuestionCard(
    BuildContext context,
    dynamic q, {
    required int index,
    required bool showResult,
  }) {
    final cs = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<ExtraColors>()!;

    final pytanieText = q['pytanie_text'] as String? ?? '';
    final pytanieImages = List<String>.from(q['pytanie_images'] ?? []);
    final pytanieVideos = List<String>.from(q['pytanie_videos'] ?? []);
    final poprawna = q['poprawna']?.toString() ?? '';
    final selected = selectedAnswers[index];

    final Color accent;
    if (!showResult || selected == null) {
      accent = cs.primary;
    } else {
      accent = selected == poprawna ? extras.correct : extras.incorrect;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(_kCardRadius),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
              child: ColoredBox(color: accent),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(_kAccentWidth + 12, 12, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _questionLabel(index, q),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _buildDifficultyBadge(context, q),
                  ],
                ),

                const SizedBox(height: 10),

                Text(
                  pytanieText,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: cs.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                ...pytanieImages.map(
                  (url) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: _minImageHeight,
                          maxHeight: _maxImageHeight,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: buildZoomableImage(context, url),
                        ),
                      ),
                    ),
                  ),
                ),

                ...pytanieVideos.map(
                  (url) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      height: 400,
                      child: InlineVideoPlayer(url: url, height: 400),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                ...['A', 'B', 'C', 'D'].map((litera) {
                  final key = 'odp${'ABCD'.indexOf(litera) + 1}';
                  final text = _stripAnswerPrefix(
                    q['${key}_text'] as String? ?? '',
                  );
                  final images = List<String>.from(q['${key}_images'] ?? []);
                  final videos = List<String>.from(q['${key}_videos'] ?? []);
                  final isCorrect = litera == poprawna;
                  final isSelected = selected == litera;

                  return _buildAnswerButton(
                    context,
                    litera,
                    text,
                    images,
                    videos,
                    isSelected: isSelected,
                    isCorrect: isCorrect,
                    showResult: showResult,
                    onTap: () {
                      setState(() {
                        selectedAnswers[index] = litera;
                        if (widget.tryb == TrybEgzaminu.jednoPytanie) {
                          odpowiedzZatwierdzona = true;
                          final id =
                              int.tryParse(q['id']?.toString() ?? '') ?? 0;
                          zapiszTrudnoscDoBazy(
                            id,
                            widget.kwalifikacja,
                            litera == poprawna,
                          );
                        }
                      });
                    },
                  );
                }),

                if (showResult && selected != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          selected == poprawna
                              ? extras.correct.withValues(alpha: 0.10)
                              : extras.incorrect.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            selected == poprawna
                                ? extras.correct.withValues(alpha: 0.4)
                                : extras.incorrect.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected == poprawna
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          size: 16,
                          color:
                              selected == poprawna
                                  ? extras.correct
                                  : extras.incorrect,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selected == poprawna
                                ? 'Wybrano poprawną odpowiedź: $selected.'
                                : 'Niepoprawna: $selected.  Poprawna: $poprawna.',
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color:
                                  selected == poprawna
                                      ? extras.correct
                                      : extras.incorrect,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Egzamin'),
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
        ),
        body: Center(child: CircularProgressIndicator(color: cs.primary)),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Egzamin'),
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
        ),
        body: const Center(child: Text('Brak pytań.')),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (widget.tryb != TrybEgzaminu.czterdziesciPytan) {
          Navigator.of(context).pop();
          return;
        }
        final shouldLeave = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder:
              (ctx) => AlertDialog(
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
        if (shouldLeave == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          iconTheme: IconThemeData(color: cs.onPrimary),
          actionsIconTheme: IconThemeData(color: cs.onPrimary),
          title: Row(
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
                  child:
                      widget.tryb == TrybEgzaminu.czterdziesciPytan
                          ? ExamTimer(endTime: _endTime)
                          : const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        backgroundColor: cs.surfaceContainerLowest,
        body:
            widget.tryb == TrybEgzaminu.jednoPytanie
                ? _buildSingleQuestion(questions[current])
                : _buildLazyList(),
        bottomNavigationBar:
            (widget.tryb == TrybEgzaminu.czterdziesciPytan ||
                    widget.tryb == TrybEgzaminu.zTestu)
                ? _buildFinishButton(context)
                : null,
      ),
    );
  }

  Widget _buildSingleQuestion(dynamic q) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildQuestionCard(
          context,
          q,
          index: current,
          showResult: odpowiedzZatwierdzona,
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            onPressed: _losujNowePytanie,
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

  Widget _buildLazyList() {
    final items = _displayedQuestions;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        if (widget.tryb == TrybEgzaminu.wszystkie)
          SliverPersistentHeader(
            pinned: true,
            delegate: _SearchHeader(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _textSearchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Szukaj...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        setState(() {
                          searchText = v;
                          _visibleCount = 30.clamp(
                            0,
                            _filteredQuestions.length,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Znalezione: ${_filteredQuestions.length}'
                      ' / ${questions.length}',
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
                    showResult: false,
                  ),
                );
              },
              childCount: items.length + (_isLoadingMore ? 3 : 0),
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
              addSemanticIndexes: false,
            ),
          ),
        ),
      ],
    );
  }

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

  Future<void> _confirmFinishExam() async {
    if (_isButtonDisabled) return;
    final shouldFinish = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
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

    final List<Map<String, dynamic>> pytaniaDoBazy =
        questions
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
      final testKey =
          '${testData['name']}||${testData['author']}||${testData['qualification']}';
      final payload = {
        'userName': userName,
        'test_key': testKey,
        'score': percent,
        'kwalifikacja': widget.kwalifikacja.replaceAll(' ', '').toLowerCase(),
        'date': endTime.toIso8601String(),
        'duration_sec': duration,
        'selectedAnswers': selectedAnswers,
        'questions': pytaniaDoBazy,
      };
      final result = await ApiService.instance.savePublishedTestResult(payload);
      if (!result.isSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Błąd zapisu wyniku testu nauczyciela: ${result.errorMessage}',
            ),
          ),
        );
      }
    } else {
      final payload = {
        'kwalifikacja': widget.kwalifikacja,
        'wynik': percent,
        'data_czas': endTime.toIso8601String(),
        'czas_trwania': duration,
        'userName': userName,
        'pytania': pytaniaDoBazy,
        'wybrane_odpowiedzi': selectedAnswers,
      };
      final result = await ApiService.instance.saveExam(payload);
      if (!result.isSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd zapisu egzaminu: ${result.errorMessage}'),
          ),
        );
      }
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => EgzaminWynikView(
                correctAnswers: correct,
                totalQuestions: questions.length,
                questions: questions,
                selectedAnswers: selectedAnswers,
                returnToHome: true,
              ),
        ),
      );
    }
    setState(() => _isButtonDisabled = false);
  }

  void _losujNowePytanie() {
    if (questions.length <= 1) return;
    final rand = Random();
    int newIndex = current;
    while (newIndex == current) {
      newIndex = rand.nextInt(questions.length);
    }
    setState(() {
      current = newIndex;
      odpowiedzZatwierdzona = false;
    });
  }
}

// ───────────────
// _SearchHeader
// ───────────────

class _SearchHeader extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SearchHeader({required this.child});

  @override
  double get minExtent => 98;
  @override
  double get maxExtent => 98;

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
