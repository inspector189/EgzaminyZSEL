import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/app_themes.dart';
import 'dart:convert';
import 'wyniki.dart';
import 'dart:math';
import 'package:shimmer/shimmer.dart';
import 'package:html_unescape/html_unescape.dart';
import 'dart:async';
import 'utils/exam_timer.dart';
import 'utils/video_player.dart';
import 'utils/zoomable_image.dart';

const _apiKey = 'zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^';

const double _minImageHeight = 100;
const double _maxImageHeight = 500;


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
  final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
  final testData = args?['testData'] as Map<String, dynamic>?;

    if (testData != null) {
    // ==========================
    // TEST NAUCZYCIELA – pobierz pytania z published_tests
    // ==========================
    final uri = Uri.parse('https://egzaminy.zsel.edu.pl/egzaminy/published_tests.php');
    try {
      final response = await http.get(uri); // GET, bo uczeń nie potrzebuje tokena
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final List<dynamic> allPublished = json.decode(response.body);

        // Znajdź test o dokładnie tych parametrach
        final matching = allPublished.firstWhere(
          (t) =>
              t['name'] == testData['name'] &&
              t['author'] == testData['author'] &&
              t['qualification'] == testData['qualification'],
          orElse: () => null,
        );

        if (matching != null) {
          final List<dynamic> fetchedQuestions = List.from(matching['test_json'] ?? []);

          for (var q in fetchedQuestions) {
            q['pytanie_text'] = _clean(q['pytanie']);
            q['pytanie_images'] = (q['images'] as List?)?.cast<String>() ?? [];
            q['pytanie_videos'] = (q['videos'] as List?)?.cast<String>() ?? [];

            for (int i = 1; i <= 4; i++) {
              final key = 'odp$i';
              q['${key}_text'] = _clean(q[key]);
              q['${key}_images'] = (q['${key}_images'] as List?)?.cast<String>() ?? [];
              q['${key}_videos'] = (q['${key}_videos'] as List?)?.cast<String>() ?? [];
            }
          }

          if (mounted) {
            setState(() {
              questions = fetchedQuestions;
              selectedAnswers = List.filled(fetchedQuestions.length, null);
              isLoading = false;
              _visibleCount = 30.clamp(0, fetchedQuestions.length);
            });
          }
          _endTime = DateTime.now().add(Duration(minutes: minutesToEndExam));
          startTime = DateTime.now();
          _startTimer();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Pobranie pytań nauczyciela nie powiodło się: $e");
    }
  } else {
    // ==========================
    // Normalny egzamin – losuj pytania
    // ==========================
    final kwalifikacja = widget.kwalifikacja.replaceAll(' ', '');
    final url = Uri.parse('https://egzaminy.zsel.edu.pl/egzaminy/$kwalifikacja.php');
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
            q['${key}_images'] = (q['${key}_images'] as List?)?.cast<String>() ?? [];
            q['${key}_videos'] = (q['${key}_videos'] as List?)?.cast<String>() ?? [];
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
      if (kDebugMode) debugPrint("Pobranie pytań nie powiodło się: $e");
    }
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
    final url = Uri.parse('https://egzaminy.zsel.edu.pl/egzaminy/zapisz_wynik.php');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Bearer $_apiKey',
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
    final url = Uri.parse('https://egzaminy.zsel.edu.pl/egzaminy/zapis_trudnosci.php');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Bearer $_apiKey',
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

  Widget _buildDifficultyBadge(
    BuildContext context,
    double? trudnosc,
    int? ilosc,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<ExtraColors>()!;
    if (trudnosc == null || ilosc == null || ilosc < 5) {
      return const SizedBox.shrink();
    }
    final isHard = trudnosc > 50;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHard ? extras.incorrect : extras.correct,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${isHard ? 'TRUDNE' : 'ŁATWE'} (${trudnosc.toStringAsFixed(1)}%)',
        style: TextStyle(
          color: colorScheme.surface,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<ExtraColors>()!;
    Color? disabledBg;

    if (showResult) {
      if (isCorrect) {
        disabledBg = extras.correct;
      } else if (isSelected && !isCorrect) {
        disabledBg = extras.incorrect;
      } else {
        disabledBg = colorScheme.surface;
      }
    }

    final bool isResultOption =
        showResult && (isCorrect || (!isCorrect && isSelected));
    final Color textColor =
        isResultOption ? Colors.black : colorScheme.onSurface;

    final Color? bgColor =
        !showResult && isSelected
            ? colorScheme.primary.withValues(alpha: 0.8)
            : null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          disabledBackgroundColor: disabledBg,
          foregroundColor: colorScheme.onSurface,
          disabledForegroundColor: textColor,
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
                child: Center(
                  child: SizedBox(
                    height: 400,
                    child: InlineVideoPlayer(
                      url: url,
                      height: 400,
                    ),
                  ),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(
    BuildContext context,
    dynamic q, {
    required int index,
    required bool showResult,
  }) {
    final pytanieText = q['pytanie_text'] ?? '';
    final pytanieImages = List<String>.from(q['pytanie_images'] ?? []);
    final pytanieVideos = List<String>.from(q['pytanie_videos'] ?? []);
    final poprawna = q['poprawna']?.toString() ?? '';
    final selected = selectedAnswers[index];

    final colorScheme = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<ExtraColors>()!;

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
                      color: colorScheme.primary,
                    ),
                  ),
                if (widget.tryb == TrybEgzaminu.czterdziesciPytan)
                  Text(
                    'Pytanie ${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                if (widget.tryb == TrybEgzaminu.jednoPytanie)
                  Text(
                    'Pytanie',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                  if (widget.tryb == TrybEgzaminu.zTestu)
                  Text(
                    'Pytanie ${index + 1}${q['id'] != null ? ' (ID: ${q['id']})' : ''}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                _buildDifficultyBadge(
                  context,
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


            ...pytanieVideos.map(
            (url) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  height: 400,
                  child: InlineVideoPlayer(
                    url: url,
                    height: 400,
                  ),
                ),
              ),
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
                            color: extras.correct,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                        : Text(
                          'Wybrano niepoprawną odpowiedź: $selected.\nPoprawna odpowiedź: $poprawna.',
                          style: TextStyle(
                            color: extras.incorrect,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer(BuildContext context) {
    final extras = Theme.of(context).extension<ExtraColors>()!;
    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: extras.shimmerBase,
        highlightColor: extras.shimmerHighlight,
        period: const Duration(milliseconds: 1000),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          height: 180,
          decoration: BoxDecoration(
            color: extras.shimmerHighlight,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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

        iconTheme: IconThemeData(color: colorScheme.onPrimary),
        titleTextStyle: TextStyle(color: colorScheme.onPrimary, fontSize: 22),
      ),
      body:
          widget.tryb == TrybEgzaminu.jednoPytanie
              ? _buildSingleQuestion(questions[current])
              : _buildLazyList(),
      bottomNavigationBar:
          (widget.tryb == TrybEgzaminu.czterdziesciPytan ||
                      widget.tryb == TrybEgzaminu.zTestu)
              ? _buildFinishButton(context)
              : null,
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
                if (i >= items.length) return _buildShimmer(context);

                final q = items[i];
                final originalIndex = questions.indexOf(q);

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
  final colorScheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.all(12),
    child: ElevatedButton(
      onPressed: _isButtonDisabled ? null : _confirmFinishExam,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        foregroundColor: colorScheme.onPrimary,
        backgroundColor: colorScheme.primary,
      ),
      child: Text(
        _isButtonDisabled ? "Wysyłanie..." : "Zakończ egzamin",
        style: const TextStyle(fontSize: 16),
      ),
    ),
  );
}

  Future<void> _confirmFinishExam() async {
  if (_isButtonDisabled) return;

  final shouldFinish = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // kliknięcie obok nie zamknie okna
    builder: (ctx) {
      return AlertDialog(
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
      );
    },
  );

  if (shouldFinish == true) {
    await _finishExam();
  }
}


 Future<void> _finishExam() async {
  setState(() => _isButtonDisabled = true);

  int correct = 0;
  for (int i = 0; i < questions.length; i++) {
    if (selectedAnswers[i] == questions[i]['poprawna']) {
      correct++;
    }
  }

  final percent = (correct / questions.length) * 100;
  final endTime = DateTime.now();
  final duration = endTime.difference(startTime).inSeconds;
  final prefs = await SharedPreferences.getInstance();
  final userName = prefs.getString("userName") ?? "anonymous";

  // ==============================
  // Część wspólna – pytania do payload
  // ==============================
  final List<Map<String, dynamic>> pytaniaDoBazy = [];
  for (var q in questions) {
    pytaniaDoBazy.add({
      'id': q['id'],
      'pytanie': q['pytanie'],
      'poprawna': q['poprawna'],
    });
  }

  // ==============================
  // Sprawdzenie, czy to test nauczyciela
  // ==============================

  final testData = widget.testData;

  if (testData != null) {
    final testKey = '${testData['name']}||${testData['author']}||${testData['qualification']}';

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

    final uri = Uri.parse('https://egzaminy.zsel.edu.pl/egzaminy/savePublishedResult.php');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
      
    );
      print("STATUS: ${response.statusCode}");
      print("BODY: ${response.body}");
    if (response.statusCode != 200 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd zapisu wyniku testu nauczyciela: ${response.body}')),
      );
    }
  } else {
    // ==============================
    // EGZAMIN 40 PYTAŃ – wysyłka na serwer
    // ==============================
    final Map<String, dynamic> payload = {
      'kwalifikacja': widget.kwalifikacja,
      'wynik': percent,
      'data_czas': endTime.toIso8601String(),
      'czas_trwania': duration,
      'userName': userName,
      'pytania': pytaniaDoBazy,
      'wybrane_odpowiedzi': selectedAnswers,
    };

    final uri = Uri.parse('https://egzaminy.zsel.edu.pl/egzaminy/save_exam.php');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd zapisu egzaminu: ${response.body}')),
      );
    }
  }

  // ==============================
  // Widok wyniku końcowego
  // ==============================
  if (mounted) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EgzaminWynikView(
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