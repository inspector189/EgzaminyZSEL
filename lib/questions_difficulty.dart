import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '/services/api_service.dart';
import '/utils/app_themes.dart';
import '/utils/async_state_view.dart';
import '/widgets/exam_question_card.dart';
import '/widgets/difficulty_badge.dart';

const double _kHardThreshold = 50.0;
const int _kPageSize = 30;
const double _kWideBreakpoint = 900.0;

String _stripAnswerPrefix(String text) =>
    text.replaceFirst(RegExp(r'^\s*[A-Da-d][.)]\s*'), '').trimLeft();

double _trud(dynamic stat) => stat['trudnosc'] is num
    ? (stat['trudnosc'] as num).toDouble()
    : double.tryParse(stat['trudnosc'].toString()) ?? 0.0;

enum _DifficultyFilter { all, hard, easy }

class _QualState {
  List<dynamic> questions = [];
  bool isLoading = false;
  bool loaded = false;
  int visibleCount = _kPageSize;
}

class QuestionsDifficultyPage extends StatefulWidget {
  const QuestionsDifficultyPage({super.key});

  @override
  QuestionsDifficultyPageState createState() => QuestionsDifficultyPageState();
}

class QuestionsDifficultyPageState extends State<QuestionsDifficultyPage> {
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> _qualSummaries = [];
  final Map<String, _QualState> _qualState = {};
  String? _selectedKwal;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final result = await ApiService.instance.fetchDifficultyStats();
      if (!result.isSuccess) throw Exception('HTTP ${result.statusCode}');
      final rows = result.data!.cast<Map<String, dynamic>>();
      rows.sort((a, b) {
        final aTotal = a['total'] as int;
        final bTotal = b['total'] as int;
        final aRatio = aTotal > 0 ? (a['hard'] as int) / aTotal : 0.0;
        final bRatio = bTotal > 0 ? (b['hard'] as int) / bTotal : 0.0;
        return bRatio.compareTo(aRatio);
      });
      if (mounted) {
        setState(() {
          _qualSummaries = rows;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Błąd: $e';
        });
      }
    }
  }

  Future<void> _ensureLoaded(String kwal) async {
    final s = _qualState.putIfAbsent(kwal, () => _QualState());
    if (s.loaded || s.isLoading) return;
    setState(() => s.isLoading = true);

    try {
      final norm = kwal.replaceAll(' ', '');
      final result = await ApiService.instance.fetchQualificationDifficulty(
        norm,
      );
      if (!result.isSuccess) throw Exception('HTTP ${result.statusCode}');
      final enriched = result.data!.cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          s.questions = enriched;
          s.visibleCount = enriched.length.clamp(0, _kPageSize);
          s.loaded = true;
          s.isLoading = false;
        });
      }
    } catch (e) {
      errorMessage = '$e';
      if (kDebugMode) {
        debugPrint('Wystąpił błąd podczas ładowania kwalifikacji $kwal: $e');
      }
      if (mounted) setState(() => s.isLoading = false);
    }
  }

  void _openQualification(BuildContext context, String kwal, bool isWide) {
    if (isWide) {
      setState(() => _selectedKwal = kwal);
      _ensureLoaded(kwal);
      return;
    }
    _ensureLoaded(kwal);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _QualificationDetailPage(
          kwal: kwal,
          stateFor: _qualState,
          ensureLoaded: _ensureLoaded,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        title: const Text('Statystyki Trudności Pytań'),
        iconTheme: IconThemeData(color: cs.onPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Odśwież',
            onPressed: isLoading ? null : _fetchStats,
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: AsyncStateView.loading(subtitle: 'Pobieranie danych...'),
            )
          : errorMessage != null
          ? Center(
              child: AsyncStateView.error(
                message: 'Błąd ładowania',
                subtitle: errorMessage,
                icon: Icons.cloud_off_rounded,
              ),
            )
          : _qualSummaries.isEmpty
          ? Center(
              child: AsyncStateView.empty(
                message: 'Brak danych',
                subtitle: 'Nie znaleziono żadnych wyników.',
                icon: Icons.inbox_outlined,
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= _kWideBreakpoint;
                final list = _buildQualList(context, isWide);

                if (!isWide) return list;

                return Row(
                  children: [
                    SizedBox(width: 400, child: list),
                    VerticalDivider(
                      width: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                    Expanded(
                      child: _selectedKwal == null
                          ? Center(
                              child: AsyncStateView.empty(
                                message: 'Wybierz kwalifikację',
                                subtitle: 'Kliknij pozycję z listy po lewej.',
                                icon: Icons.touch_app_outlined,
                              ),
                            )
                          : _QualificationDetail(
                              kwal: _selectedKwal!,
                              state: _qualState[_selectedKwal!]!,
                              onLoadMore: () => setState(() {
                                final s = _qualState[_selectedKwal!]!;
                                s.visibleCount = (s.visibleCount + _kPageSize)
                                    .clamp(0, s.questions.length);
                              }),
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildQualList(BuildContext context, bool isWide) {
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      color: cs.primary,
      onRefresh: _fetchStats,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _qualSummaries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final summary = _qualSummaries[i];
          final kwal = summary['kwalifikacja'] as String;
          return _QualificationListTile(
            summary: summary,
            isSelected: isWide && kwal == _selectedKwal,
            onTap: () => _openQualification(context, kwal, isWide),
          );
        },
      ),
    );
  }
}

class _QualificationListTile extends StatelessWidget {
  const _QualificationListTile({
    required this.summary,
    required this.isSelected,
    required this.onTap,
  });

  final Map<String, dynamic> summary;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<ExtraColors>()!;
    final kwal = summary['kwalifikacja'] as String;
    final total = summary['total'] as int;
    final hard = summary['hard'] as int;
    final easy = summary['easy'] as int;
    final easyPercent = total > 0 ? easy / total : 0.0;

    return Material(
      color: isSelected
          ? cs.primaryContainer.withValues(alpha: 0.2)
          : cs.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? cs.primary
                  : cs.outlineVariant.withValues(alpha: 0.35),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kwal.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isSelected ? cs.primary : cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: easyPercent,
                        minHeight: 10,
                        backgroundColor: extras.incorrect.withValues(
                          alpha: 0.4,
                        ),
                        valueColor: AlwaysStoppedAnimation(
                          extras.correct.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: extras.correct.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.trending_down_rounded,
                                  size: 11,
                                  color: cs.onPrimaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$easy łatwych',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: extras.incorrect.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.trending_up_rounded,
                                  size: 11,
                                  color: cs.onPrimaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$hard trudnych',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.article_rounded,
                                  size: 11,
                                  color: cs.onPrimaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$total razem',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _QualificationDetailPage extends StatefulWidget {
  const _QualificationDetailPage({
    required this.kwal,
    required this.stateFor,
    required this.ensureLoaded,
  });

  final String kwal;
  final Map<String, _QualState> stateFor;
  final Future<void> Function(String) ensureLoaded;

  @override
  State<_QualificationDetailPage> createState() =>
      _QualificationDetailPageState();
}

class _QualificationDetailPageState extends State<_QualificationDetailPage> {
  @override
  Widget build(BuildContext context) {
    final s = widget.stateFor.putIfAbsent(widget.kwal, () => _QualState());
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kwal.toUpperCase()),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: _QualificationDetail(
        kwal: widget.kwal,
        state: s,
        onLoadMore: () => setState(() {
          s.visibleCount = (s.visibleCount + _kPageSize).clamp(
            0,
            s.questions.length,
          );
        }),
      ),
    );
  }
}

class _QualificationDetail extends StatefulWidget {
  const _QualificationDetail({
    required this.kwal,
    required this.state,
    required this.onLoadMore,
  });

  final String kwal;
  final _QualState state;
  final VoidCallback onLoadMore;

  @override
  State<_QualificationDetail> createState() => _QualificationDetailState();
}

class _QualificationDetailState extends State<_QualificationDetail> {
  String _searchText = '';
  _DifficultyFilter _filter = _DifficultyFilter.all;

  List<dynamic> _filtered() {
    var list = widget.state.questions;
    if (_filter == _DifficultyFilter.hard) {
      list = list.where((q) => _trud(q) > _kHardThreshold).toList();
    } else if (_filter == _DifficultyFilter.easy) {
      list = list.where((q) => _trud(q) <= _kHardThreshold).toList();
    }
    if (_searchText.trim().isNotEmpty) {
      final needle = _searchText.trim().toLowerCase();
      list = list.where((q) {
        final text = (q['pytanie']?.toString() ?? '').toLowerCase();
        final id = (q['pytanie_id']?.toString() ?? '').toLowerCase();
        return text.contains(needle) || id.contains(needle);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final cs = Theme.of(context).colorScheme;

    if (s.isLoading) return Center(child: AsyncStateView.loading());

    if (s.loaded && s.questions.isEmpty) {
      return Center(
        child: AsyncStateView.empty(
          message: 'Brak pytań',
          subtitle: 'Ta kwalifikacja nie zawiera żadnych pytań.',
          icon: Icons.quiz_outlined,
        ),
      );
    }

    if (!s.loaded) return Center(child: AsyncStateView.loading());

    final filtered = _filtered();
    final visible = filtered.take(s.visibleCount).toList();
    final hasMore = s.visibleCount < filtered.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Szukaj pytania lub ID...',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (v) => setState(() => _searchText = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              _FilterChip(
                label: 'Wszystkie (${s.questions.length})',
                selected: _filter == _DifficultyFilter.all,
                onTap: () => setState(() => _filter = _DifficultyFilter.all),
              ),
              _FilterChip(
                label: 'Trudne',
                selected: _filter == _DifficultyFilter.hard,
                onTap: () => setState(() => _filter = _DifficultyFilter.hard),
              ),
              _FilterChip(
                label: 'Łatwe',
                selected: _filter == _DifficultyFilter.easy,
                onTap: () => setState(() => _filter = _DifficultyFilter.easy),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'Brak wyników',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  children: [
                    for (final q in visible) _QuestionDifficultyCard(q: q),
                    if (hasMore)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: OutlinedButton.icon(
                          onPressed: widget.onLoadMore,
                          icon: const Icon(Icons.expand_more_rounded),
                          label: Text(
                            'Pokaż więcej (${filtered.length - s.visibleCount})',
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _QuestionDifficultyCard extends StatelessWidget {
  const _QuestionDifficultyCard({required this.q});
  final dynamic q;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<ExtraColors>()!;

    final id = q['pytanie_id'] ?? '-';
    final total = int.tryParse(q['ilosc_odpowiedzi'].toString()) ?? 0;
    final correct =
        int.tryParse(q['ilosc_poprawnych_odpowiedzi'].toString()) ?? 0;
    final rate = total > 0 ? correct / total : 0.0;
    final ratePct = (rate * 100).toStringAsFixed(1);

    final poprawna = q['poprawna']?.toString() ?? '';
    final trud = _trud(q);
    final isHard = trud > _kHardThreshold;
    final accent = isHard ? extras.incorrect : extras.correct;

    final answers = List.generate(4, (i) {
      final letter = 'ABCD'[i];
      final key = 'odp${i + 1}';
      return ExamAnswerState(
        letter: letter,
        text: _stripAnswerPrefix(q[key]?.toString() ?? ''),
        images: const [],
        videos: const [],
        isCorrect: letter == poprawna,
        isSelected: false,
      );
    });

    return RepaintBoundary(
      child: ExamQuestionCard(
        label: 'ID #$id',
        questionText: q['pytanie']?.toString() ?? '',
        questionImages: List<String>.from(q['images'] ?? []),
        questionVideos: List<String>.from(q['videos'] ?? []),
        answers: answers,
        accentColor: accent,
        showResult: true,
        headerTrailing: DifficultyBadge(trudnosc: trud, ilosc: total),
        bottomRow: _RateBar(
          rate: rate,
          total: total,
          correct: correct,
          pct: ratePct,
          cs: cs,
          extra: extras,
        ),
      ),
    );
  }
}

class _RateBar extends StatelessWidget {
  const _RateBar({
    required this.rate,
    required this.total,
    required this.correct,
    required this.pct,
    required this.cs,
    required this.extra,
  });
  final double rate;
  final int total;
  final int correct;
  final String pct;
  final ColorScheme cs;
  final ExtraColors extra;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            'Poprawność odpowiedzi',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: cs.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            '$correct / $total  ($pct%)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: rate,
          minHeight: 7,
          backgroundColor: extra.incorrect.withValues(alpha: 0.17),
          valueColor: AlwaysStoppedAnimation(
            extra.correct.withValues(alpha: 0.75),
          ),
        ),
      ),
    ],
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: cs.primaryContainer,
      side: BorderSide(
        color: selected ? Colors.transparent : cs.onSurfaceVariant,
      ),
      labelStyle: TextStyle(
        color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}
