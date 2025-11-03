import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'wyniki.dart';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:shimmer/shimmer.dart';
import 'package:html_unescape/html_unescape.dart';
import 'dart:async';

class ExamTimer extends StatelessWidget {
  final DateTime endTime;
  const ExamTimer({super.key, required this.endTime});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final remaining = endTime.difference(DateTime.now());
        final total = remaining.isNegative ? Duration.zero : remaining;

        final minutes = total.inMinutes.toString().padLeft(2, '0');
        final seconds = (total.inSeconds % 60).toString().padLeft(2, '0');

        return Text(
          '$minutes:$seconds',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color:
                total.inMinutes < 5
                    ? Colors.red
                    : Theme.of(context).colorScheme.onPrimary,
          ),
        );
      },
    );
  }
}

class _InlineVideoPlayer extends StatefulWidget {
  const _InlineVideoPlayer({required this.url, this.height});
  final String url;
  final double? height;

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer>
    with AutomaticKeepAliveClientMixin {
  ChewieController? _chewie;
  bool _initError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _chewie = await _VideoPool().getChewie(widget.url);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _initError = true);
    }
  }

  @override
  void dispose() {
    _VideoPool().release(widget.url);
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_initError) {
      return const Text(
        'Failed to load video.',
        style: TextStyle(color: Colors.red),
      );
    }
    if (_chewie == null) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final vp = _chewie!.videoPlayerController;
    final aspect =
        vp.value.isInitialized && vp.value.aspectRatio != 0
            ? vp.value.aspectRatio
            : 16 / 9;

    Widget player = Chewie(controller: _chewie!);
    if (widget.height != null) {
      final h = widget.height!;
      player = SizedBox(
        height: h,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(width: h * aspect, height: h, child: player),
        ),
      );
    } else {
      player = AspectRatio(aspectRatio: aspect, child: player);
    }

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: player,
      ),
    );
  }
}

class _VideoPool {
  static final _VideoPool _i = _VideoPool._();
  _VideoPool._();
  factory _VideoPool() => _i;

  final Map<String, VideoPlayerController> _vp = {};
  final Map<String, ChewieController> _chewie = {};
  final Map<String, int> _refs = {};

  Future<ChewieController> getChewie(String url) async {
    if (!_vp.containsKey(url)) {
      final v = VideoPlayerController.networkUrl(Uri.parse(url));
      await v.initialize();
      _vp[url] = v;
    }
    if (!_chewie.containsKey(url)) {
      _chewie[url] = ChewieController(
        videoPlayerController: _vp[url]!,
        autoInitialize: true,
        autoPlay: false,
        looping: false,
        showControls: true,
        allowMuting: true,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
      );
    }
    _refs[url] = (_refs[url] ?? 0) + 1;
    return _chewie[url]!;
  }

  void release(String url) {
    final r = (_refs[url] ?? 0) - 1;
    if (r > 0) {
      _refs[url] = r;
      return;
    }
    _refs.remove(url);
    _chewie.remove(url)?.dispose();
    _vp.remove(url)?.dispose();
  }
}

enum TrybEgzaminu { jednoPytanie, czterdziesciPytan, wszystkie }

Widget buildZoomableImage(BuildContext context, String url) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final maxWidth = constraints.maxWidth - 300;
      return GestureDetector(
        onTap: () => _showZoomedImage(context, url),
        child: Center(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (_, _) => _buildImagePlaceholder(maxWidth),
            errorWidget:
                (_, _, _) => _buildImagePlaceholder(maxWidth, error: true),
          ),
        ),
      );
    },
  );
}

Widget _buildImagePlaceholder(double width, {bool error = false}) {
  return Container(
    width: width,
    decoration: BoxDecoration(
      color: error ? Colors.grey[850] : Colors.grey[700],
      borderRadius: BorderRadius.circular(8),
    ),
    child:
        error
            ? const Icon(Icons.broken_image, color: Colors.grey)
            : Shimmer.fromColors(
              baseColor: Colors.grey[600]!,
              highlightColor: Colors.grey[400]!,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
  );
}

void _showZoomedImage(BuildContext context, String url) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    pageBuilder:
        (c, a1, a2) => Center(
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 1.0,
            maxScale: 5.0,
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
    transitionBuilder:
        (c, a1, a2, child) => FadeTransition(opacity: a1, child: child),
    transitionDuration: const Duration(milliseconds: 300),
  );
}

class EgzaminView extends StatefulWidget {
  final TrybEgzaminu tryb;
  final String kwalifikacja;
  final bool returnToHome;
  final String? userName;

  const EgzaminView({
    super.key,
    required this.tryb,
    required this.kwalifikacja,
    required this.returnToHome,
    this.userName,
  });

  @override
  State<EgzaminView> createState() => _EgzaminViewState();
}

class _EgzaminViewState extends State<EgzaminView> {
  final _unescape = HtmlUnescape();
  Timer? _timer;
  final int minutesToEndExam = 60;
  late DateTime _endTime;
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
    _textSearchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  final TextEditingController _textSearchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String searchText = '';

  int _visibleCount = 30;
  bool _isLoadingMore = false;
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
      final idStr = (e['id']?.toString() ?? '').toLowerCase();
      return txt.contains(q) ||
          a.contains(q) ||
          b.contains(q) ||
          c.contains(q) ||
          d.contains(q) ||
          idStr.contains(q);
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
  String? selectedAnswer;
  bool isLoading = true;
  List<String?> selectedAnswers = [];
  late DateTime startTime;
  bool odpowiedzZatwierdzona = false;

  @override
  void initState() {
    super.initState();
    fetchQuestions();
    _scrollController.addListener(_onScroll);
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
    final kwalifikacja = widget.kwalifikacja.replaceAll(' ', '');
    final url = Uri.parse('https://interpage.pl/egzaminy/$kwalifikacja.php');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final List<dynamic> allQuestions = json.decode(response.body);
        List<dynamic> selected = [];

        switch (widget.tryb) {
          case TrybEgzaminu.jednoPytanie:
            selected = List.from(allQuestions)..shuffle();
            break;
          case TrybEgzaminu.czterdziesciPytan:
            selected = List.from(allQuestions)..shuffle();
            selected = selected.take(40).toList();
            break;
          case TrybEgzaminu.wszystkie:
            selected = allQuestions;
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

        if (mounted) {
          setState(() {
            questions = selected;
            selectedAnswers = List.filled(selected.length, null);
            isLoading = false;
            _visibleCount = 30.clamp(0, selected.length);
          });
        }
        _endTime = DateTime.now().add(Duration(minutes: minutesToEndExam));
        startTime = DateTime.now();
        _startTimer();
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Pobranie nie powiodło się: $e");
    }
  }

  Future<void> sendResultToServer({
    required String kwalifikacja,
    required double wynik,
    required String dataCzas,
    required int czasTrwania,
  }) async {
    final userName =
        widget.userName ??
        (await SharedPreferences.getInstance()).getString('userName') ??
        'anonymous';
    final url = Uri.parse('https://interpage.pl/egzaminy/zapisz_wynik.php');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Bearer zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^',
      },
      body: {
        'kwalifikacja': kwalifikacja.replaceAll(' ', ''),
        'wynik': wynik.toStringAsFixed(2),
        'data_czas': dataCzas,
        'czas_trwania': czasTrwania.toString(),
        'userName': userName,
      },
    );
    if (response.statusCode != 200 && kDebugMode) {
      debugPrint('Zapis wyniku nie powiódł się: ${response.body}');
    }
  }

  Future<void> zapiszTrudnoscDoBazy(
    int pytanieId,
    String kwalifikacja,
    bool poprawna,
  ) async {
    if (pytanieId <= 0) return;
    final url = Uri.parse('https://interpage.pl/egzaminy/zapis_trudnosci.php');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Bearer zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^',
      },
      body: {
        'pytanie_id': pytanieId.toString(),
        'kwalifikacja': kwalifikacja.replaceAll(' ', ''),
        'poprawna': poprawna ? '1' : '0',
      },
    );
    if (response.statusCode != 200 && kDebugMode) {
      debugPrint('Zapis trudności nie powiódł się: ${response.body}');
    }
  }

  Widget _buildDifficultyBadge(double? trudnosc, int? ilosc) {
    if (trudnosc == null || ilosc == null || ilosc < 5) {
      return const SizedBox.shrink();
    }
    final isHard = trudnosc > 50;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHard ? Colors.red : Colors.green,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${isHard ? 'TRUDNE' : 'ŁATWE'} (${trudnosc.toStringAsFixed(1)}%)',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAnswerButton(
    String litera,
    String text,
    List<String> images,
    List<String> videos, {
    required bool isSelected,
    required bool isCorrect,
    required bool showResult,
    required VoidCallback onTap,
  }) {
    Color? disabledBg;

    if (showResult) {
      if (isCorrect) {
        disabledBg = Colors.green;
      } else if (isSelected && !isCorrect) {
        disabledBg = Colors.red;
      } else {
        disabledBg = Theme.of(context).colorScheme.surface;
      }
    }

    final Color? bgColor =
        !showResult && isSelected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)
            : null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          disabledBackgroundColor: disabledBg,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          disabledForegroundColor: Theme.of(context).colorScheme.onSurface,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: showResult ? null : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: const TextStyle(fontSize: 15)),
            ...images.map(
              (url) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: buildZoomableImage(context, url),
              ),
            ),
            ...videos.map(
              (url) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _InlineVideoPlayer(url: url),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(
    dynamic q, {
    required int index,
    required bool showResult,
  }) {
    final pytanieText = q['pytanie_text'] ?? '';
    final pytanieImages = List<String>.from(q['pytanie_images'] ?? []);
    final pytanieVideos = List<String>.from(q['pytanie_videos'] ?? []);
    final poprawna = q['poprawna']?.toString() ?? '';
    final selected = selectedAnswers[index];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.tryb == TrybEgzaminu.wszystkie)
                  Text(
                    'Pytanie ${index + 1}${q['id'] != null ? ' (ID ${q['id']})' : ''}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                if (widget.tryb == TrybEgzaminu.czterdziesciPytan)
                  Text(
                    'Pytanie ${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                if (widget.tryb == TrybEgzaminu.jednoPytanie)
                  Text(
                    'Pytanie',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                _buildDifficultyBadge(
                  q['trudnosc']?.toDouble(),
                  int.tryParse(q['ilosc_odpowiedzi'].toString()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(pytanieText, style: const TextStyle(fontSize: 16)),
            ...pytanieImages.map(
              (url) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: buildZoomableImage(context, url),
              ),
            ),
            ...pytanieVideos.map(
              (url) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _InlineVideoPlayer(url: url),
              ),
            ),
            const SizedBox(height: 12),
            ...['A', 'B', 'C', 'D'].map((litera) {
              final key = 'odp${'ABCD'.indexOf(litera) + 1}';
              final text = q['${key}_text'] ?? '';
              final images = List<String>.from(q['${key}_images'] ?? []);
              final videos = List<String>.from(q['${key}_videos'] ?? []);
              final isCorrect = litera == poprawna;
              final isSelected = selected == litera;

              return _buildAnswerButton(
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
                      zapiszTrudnoscDoBazy(
                        int.parse(q['id']),
                        widget.kwalifikacja,
                        litera == poprawna,
                      );
                    }
                  });
                },
              );
            }),
            if (showResult && selected != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child:
                    selected == poprawna
                        ? Text(
                          'Wybrano poprawną odpowiedź: $selected.',
                          style: TextStyle(
                            color: Colors.green,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                        : Text(
                          'Wybrano niepoprawną odpowiedź: $selected.\nPoprawna odpowiedź: $poprawna.',
                          style: TextStyle(
                            color: Colors.red,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: Colors.grey[850]!,
        highlightColor: Colors.grey[700]!,
        period: const Duration(milliseconds: 1000),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          height: 180,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Egzamin')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Egzamin')),
        body: const Center(child: Text('Brak pytań.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text("Egzamin"),

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

        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        titleTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 22,
        ),
      ),
      body:
          widget.tryb == TrybEgzaminu.jednoPytanie
              ? _buildSingleQuestion(questions[current])
              : _buildLazyList(),
      bottomNavigationBar:
          widget.tryb == TrybEgzaminu.czterdziesciPytan
              ? _buildFinishButton()
              : null,
    );
  }

  Widget _buildSingleQuestion(dynamic q) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildQuestionCard(
          q,
          index: current,
          showResult: odpowiedzZatwierdzona,
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton.icon(
            onPressed: _losujNowePytanie,
            icon: const Icon(Icons.refresh),
            label: const Text("Losuj kolejne"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                      'Znalezione: ${_filteredQuestions.length} / ${questions.length}',
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
                if (i >= items.length) return _buildShimmer();

                final q = items[i];
                final originalIndex = questions.indexOf(q);

                return RepaintBoundary(
                  child: _buildQuestionCard(
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

  Widget _buildFinishButton() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ElevatedButton(
        onPressed: _isButtonDisabled ? null : _finishExam,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
        child: Text(
          _isButtonDisabled ? "Wysyłanie..." : "Zakończ egzamin",
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Future<void> _finishExam() async {
    setState(() => _isButtonDisabled = true);
    final correct =
        selectedAnswers
            .where(
              (a) => a == questions[selectedAnswers.indexOf(a)]['poprawna'],
            )
            .length;
    final percent = (correct / questions.length) * 100;
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime).inSeconds;

    final futures = <Future>[];
    for (int i = 0; i < questions.length; i++) {
      final pid = int.tryParse(questions[i]['id'].toString());
      final odp = selectedAnswers[i];
      if (pid != null && odp != null) {
        futures.add(
          zapiszTrudnoscDoBazy(
            pid,
            widget.kwalifikacja,
            odp == questions[i]['poprawna'],
          ),
        );
      }
    }

    await sendResultToServer(
      kwalifikacja: widget.kwalifikacja,
      wynik: percent,
      dataCzas: endTime.toIso8601String(),
      czasTrwania: duration,
    );

    setState(() => _isButtonDisabled = false);
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
      selectedAnswer = null;
      odpowiedzZatwierdzona = false;
    });
  }
}

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
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: overlapsContent ? 2 : 0,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _SearchHeader old) => old.child != child;
}
