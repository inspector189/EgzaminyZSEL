import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/services/api_service.dart';
import 'package:flutter_app/utils/app_themes.dart';
import 'package:flutter_app/utils/async_state_view.dart';
import 'package:video_player/video_player.dart';
import 'package:shimmer/shimmer.dart';
import 'widgets/zoomable_image.dart';
import 'widgets/shim_box.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────

const double _kHardThreshold = 50.0;
const int _kPageSize = 30;
const double _kCardRadius = 12.0;
const double _kAccentWidth = 4.0;
const double _kGridBreakpoint = 680.0;

String _stripAnswerPrefix(String text) =>
    text.replaceFirst(RegExp(r'^\s*[A-Da-d][.)]\s*'), '').trimLeft();

// ─────────────────────────────────────────────────────────────────────────────
// Per-qualification state
// ─────────────────────────────────────────────────────────────────────────────

class _QualState {
  List<dynamic> questions = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  bool loaded = false;
  int visibleCount = _kPageSize;
  ScrollController? controller;

  void dispose() {
    controller?.dispose();
    controller = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VideoPlayerWidget
// ─────────────────────────────────────────────────────────────────────────────

class _VideoPlayerWidget extends StatefulWidget {
  const _VideoPlayerWidget({required this.url});
  final String url;

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late final VideoPlayerController _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(widget.url as Uri)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _ctrl
          ..setLooping(false)
          ..play();
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: _ctrl.value.aspectRatio,
        child: VideoPlayer(_ctrl),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QuestionStatsPage
// ─────────────────────────────────────────────────────────────────────────────

class QuestionStatsPage extends StatefulWidget {
  const QuestionStatsPage({super.key});

  @override
  QuestionStatsPageState createState() => QuestionStatsPageState();
}

class QuestionStatsPageState extends State<QuestionStatsPage>
    with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> _stats = [];
  Map<String, List<dynamic>> _grouped = {};
  final Map<String, _QualState> _qualState = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  @override
  void dispose() {
    for (final s in _qualState.values) {
      s.dispose();
    }
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _fetchStats() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final result = await ApiService.instance.fetchDifficultyStats();
      if (!result.isSuccess) throw Exception('HTTP ${result.statusCode}');
      if (mounted) {
        setState(() {
          _stats = result.data!;
          _grouped = _group();
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

  Map<String, List<dynamic>> _group() {
    final out = <String, List<dynamic>>{};
    for (final r in _stats) {
      final k = (r['kwalifikacja'] ?? 'Nieznana').toString();
      out.putIfAbsent(k, () => []).add(r);
    }
    return out;
  }

  Future<void> _loadQualification(String kwal) async {
    final s = _qualState.putIfAbsent(kwal, () => _QualState());
    if (s.loaded || s.isLoading) return;
    setState(() => s.isLoading = true);

    try {
      final norm = kwal.replaceAll(' ', '');
      final result = await ApiService.instance.fetchQuestions(norm);
      if (!result.isSuccess) throw Exception('HTTP ${result.statusCode}');

      final parsed = result.data!;
      final stats = _stats
          .where(
            (item) =>
                (item['kwalifikacja'] ?? '').toString().replaceAll(' ', '') ==
                norm,
          )
          .toList();

      final enriched = <Map<String, dynamic>>[];
      for (final st in stats) {
        final match = parsed.where(
          (p) => p['id'].toString() == st['pytanie_id'].toString(),
        );
        if (match.isNotEmpty) {
          enriched.add({...st as Map, ...match.first as Map});
        }
      }

      enriched.sort(
        (a, b) => (int.tryParse(a['pytanie_id'].toString()) ?? 0).compareTo(
          int.tryParse(b['pytanie_id'].toString()) ?? 0,
        ),
      );

      if (mounted) {
        setState(() {
          s.questions = enriched;
          s.visibleCount = enriched.length.clamp(0, _kPageSize);
          s.loaded = true;
          s.isLoading = false;
          final sc = ScrollController()..addListener(() => _onScroll(kwal));
          s.controller = sc;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Błąd podczas ładowania kwalifikacji $kwal: $e');
      }
      if (mounted) setState(() => s.isLoading = false);
    }
  }

  void _onScroll(String kwal) {
    final s = _qualState[kwal];
    final sc = s?.controller;
    if (s == null || sc == null || s.isLoadingMore) return;
    if (sc.position.pixels < sc.position.maxScrollExtent - 200) return;
    if (s.visibleCount >= s.questions.length) return;

    setState(() => s.isLoadingMore = true);
    Future.microtask(() {
      if (!mounted) return;
      setState(() {
        s.visibleCount = (s.visibleCount + _kPageSize).clamp(
          0,
          s.questions.length,
        );
        s.isLoadingMore = false;
      });
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  double _trud(dynamic stat) => stat['trudnosc'] is num
      ? (stat['trudnosc'] as num).toDouble()
      : double.tryParse(stat['trudnosc'].toString()) ?? 0.0;

  ({int hard, int easy}) _agg(List<dynamic> stats) {
    final hard = stats.where((s) => _trud(s) > _kHardThreshold).length;
    return (hard: hard, easy: stats.length - hard);
  }

  // ── Qualification panel header ─────────────────────────────────────────────

  Widget _buildQualHeader(
    BuildContext context,
    String kwal,
    List<dynamic> stats,
  ) {
    final cs = Theme.of(context).colorScheme;
    final extra = Theme.of(context).extension<ExtraColors>()!;
    final a = _agg(stats);
    final total = stats.length;
    final hardFrac = total > 0 ? a.hard / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  kwal,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _Chip(label: '${a.hard} trudnych', color: extra.incorrect),
              const SizedBox(width: 6),
              _Chip(label: '${a.easy} łatwych', color: extra.correct),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: hardFrac,
              minHeight: 6,
              backgroundColor: extra.correct.withValues(alpha: 0.28),
              valueColor: AlwaysStoppedAnimation<Color>(
                extra.incorrect.withValues(alpha: 0.72),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$total pytań łącznie',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ── Question card ─────────────────────────────────────────────────────────

  Widget _buildCard(BuildContext context, dynamic q) {
    final cs = Theme.of(context).colorScheme;
    final extra = Theme.of(context).extension<ExtraColors>()!;

    final id = q['pytanie_id'] ?? '-';
    final total = int.tryParse(q['ilosc_odpowiedzi'].toString()) ?? 0;
    final correct =
        int.tryParse(q['ilosc_poprawnych_odpowiedzi'].toString()) ?? 0;
    final rate = total > 0 ? correct / total : 0.0;
    final ratePct = (rate * 100).toStringAsFixed(1);

    final pytanie = q['pytanie']?.toString() ?? '';
    // Strip leading letter prefix (e.g. "A. ") — the circle badge shows it.
    final answers = {
      'A': _stripAnswerPrefix(q['odp1']?.toString() ?? ''),
      'B': _stripAnswerPrefix(q['odp2']?.toString() ?? ''),
      'C': _stripAnswerPrefix(q['odp3']?.toString() ?? ''),
      'D': _stripAnswerPrefix(q['odp4']?.toString() ?? ''),
    };
    final poprawna = q['poprawna']?.toString() ?? '';
    final images = List<String>.from(q['images'] ?? []);
    final videos = List<String>.from(q['videos'] ?? []);

    final trud = _trud(q);
    final isHard = trud > _kHardThreshold;
    final accent = isHard ? extra.incorrect : extra.correct;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(_kCardRadius),
          //border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
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
              padding: const EdgeInsets.fromLTRB(
                _kAccentWidth + 14,
                12,
                14,
                14,
              ),
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
                          '#$id',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: cs.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _DiffBadge(trud: trud, isHard: isHard, color: accent),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Text(
                    pytanie,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: cs.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  if (images.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...images.map(
                      (url) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: buildZoomableImage(context, url),
                        ),
                      ),
                    ),
                  ],

                  if (videos.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...videos.map(
                      (url) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _VideoPlayerWidget(url: url),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  ...answers.entries.map(
                    (e) => _AnswerTile(
                      letter: e.key,
                      text: e.value,
                      isCorrect: e.key == poprawna,
                      correctColor: extra.correct,
                      cs: cs,
                    ),
                  ),

                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 10),

                  _RateBar(
                    rate: rate,
                    total: total,
                    correct: correct,
                    pct: ratePct,
                    cs: cs,
                    extra: extra,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shimmer card ──────────────────────────────────────────────────────────

  Widget _buildShimmer(BuildContext context) {
    final extra = Theme.of(context).extension<ExtraColors>()!;
    final cs = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: extra.shimmerBase,
        highlightColor: extra.shimmerHighlight,
        period: const Duration(milliseconds: 900),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
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
                  child: ColoredBox(color: extra.shimmerHighlight),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kAccentWidth + 14,
                  12,
                  14,
                  14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ShimBox(w: 48, h: 20, cs: cs, radius: 6),
                        const Spacer(),
                        ShimBox(w: 90, h: 20, cs: cs, radius: 20),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ShimBox(w: double.infinity, h: 14, cs: cs),
                    const SizedBox(height: 6),
                    ShimBox(w: double.infinity, h: 14, cs: cs),
                    const SizedBox(height: 6),
                    ShimBox(w: 160, h: 14, cs: cs),
                    const SizedBox(height: 14),
                    for (int i = 0; i < 4; i++) ...[
                      ShimBox(w: double.infinity, h: 36, cs: cs, radius: 8),
                      const SizedBox(height: 5),
                    ],
                    const SizedBox(height: 8),
                    ShimBox(w: double.infinity, h: 7, cs: cs, radius: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Qualification content ─────────────────────────────────────────────────

  Widget _buildQualContent(BuildContext context, String kwal) {
    final s = _qualState[kwal];

    if (s == null || s.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(child: AsyncStateView.loading()),
      );
    }

    if (s.loaded && s.questions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: AsyncStateView.empty(
            message: 'Brak pytań',
            subtitle: 'Ta kwalifikacja nie zawiera żadnych pytań.',
            icon: Icons.quiz_outlined,
          ),
        ),
      );
    }

    if (!s.loaded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: AsyncStateView.empty(
            message: 'Pytania nie zostały załadowane',
            subtitle: 'Kliknij, aby załadować pytania.',
            icon: Icons.touch_app_outlined,
          ),
        ),
      );
    }

    final visible = s.visibleCount;
    final shimmers = s.isLoadingMore ? 3 : 0;
    final total = visible + shimmers;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _kGridBreakpoint;
        final listH = (MediaQuery.of(context).size.height * 0.72).clamp(
          300.0,
          720.0,
        );

        if (isWide) {
          final rowCount = (total / 2).ceil();
          return SizedBox(
            height: listH,
            child: ListView.builder(
              controller: s.controller,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              addRepaintBoundaries: true,
              itemCount: rowCount,
              itemBuilder: (ctx, row) {
                final l = row * 2;
                final r = l + 1;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: l < visible
                          ? _buildCard(ctx, s.questions[l])
                          : l < total
                          ? _buildShimmer(ctx)
                          : const SizedBox(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: r < visible
                          ? _buildCard(ctx, s.questions[r])
                          : r < total
                          ? _buildShimmer(ctx)
                          : const SizedBox(),
                    ),
                  ],
                );
              },
            ),
          );
        }

        return SizedBox(
          height: listH,
          child: ListView.builder(
            controller: s.controller,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            itemCount: total,
            itemBuilder: (ctx, i) => i < visible
                ? _buildCard(ctx, s.questions[i])
                : _buildShimmer(ctx),
          ),
        );
      },
    );
  }

  // ── AppBar summary chip ───────────────────────────────────────────────────

  Widget _buildSummaryChip(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = _stats.length;
    final hard = _stats.where((s) => _trud(s) > _kHardThreshold).length;

    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.onPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.onPrimary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics_outlined, size: 15, color: cs.onPrimary),
          const SizedBox(width: 5),
          Text(
            '$total pytań',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onPrimary,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 1,
            height: 12,
            color: cs.onPrimary.withValues(alpha: 0.4),
          ),
          Icon(Icons.trending_up_rounded, size: 18, color: cs.onPrimary),
          const SizedBox(width: 3),
          Text(
            '$hard trudnych',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── build() ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        title: Text('Statystyki Trudności Pytań'),
        iconTheme: IconThemeData(color: cs.onPrimary),
        actionsIconTheme: IconThemeData(color: cs.onPrimary),
        actions: [
          if (!isLoading && errorMessage == null && _stats.isNotEmpty)
            _buildSummaryChip(context),
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
          : RefreshIndicator(
              color: cs.primary,
              onRefresh: _fetchStats,
              child: _grouped.isEmpty
                  ? Center(
                      child: AsyncStateView.empty(
                        message: 'Brak danych',
                        subtitle: 'Nie znaleziono żadnych wyników.',
                        icon: Icons.inbox_outlined,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      itemCount: _grouped.length,
                      itemBuilder: (context, index) {
                        final entry = _grouped.entries.elementAt(index);
                        final kwal = entry.key;
                        final stats = entry.value;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: cs.shadow.withValues(alpha: 0.6),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Theme(
                              data: Theme.of(
                                context,
                              ).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  4,
                                ),
                                childrenPadding: EdgeInsets.zero,
                                expandedCrossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                iconColor: cs.primary,
                                collapsedIconColor: cs.primary,
                                title: _buildQualHeader(context, kwal, stats),
                                onExpansionChanged: (expanded) {
                                  if (expanded) _loadQualification(kwal);
                                },
                                children: [
                                  Divider(
                                    height: 1,
                                    color: cs.primary.withValues(alpha: 0.15),
                                  ),
                                  _buildQualContent(context, kwal),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.45)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class _DiffBadge extends StatelessWidget {
  const _DiffBadge({
    required this.trud,
    required this.isHard,
    required this.color,
  });
  final double trud;
  final bool isHard;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
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
          '${isHard ? "TRUDNE" : "ŁATWE"} ${trud.toStringAsFixed(0)}%',
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

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.letter,
    required this.text,
    required this.isCorrect,
    required this.correctColor,
    required this.cs,
  });
  final String letter;
  final String text;
  final bool isCorrect;
  final Color correctColor;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 5),
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: isCorrect
          ? correctColor.withValues(alpha: 0.10)
          : cs.surfaceContainerHighest.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: isCorrect
            ? correctColor.withValues(alpha: 0.50)
            : cs.outlineVariant.withValues(alpha: 0.28),
        width: isCorrect ? 1.5 : 1.0,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isCorrect
                ? correctColor
                : cs.outlineVariant.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isCorrect ? cs.surface : cs.onPrimary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: isCorrect ? cs.onSurface : cs.onSurfaceVariant,
              fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        if (isCorrect)
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 2),
            child: Icon(
              Icons.check_circle_rounded,
              size: 15,
              color: correctColor,
            ),
          ),
      ],
    ),
  );
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
          valueColor: AlwaysStoppedAnimation<Color>(
            extra.correct.withValues(alpha: 0.75),
          ),
        ),
      ),
    ],
  );
}
