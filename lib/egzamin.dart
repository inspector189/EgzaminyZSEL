import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'wyniki.dart';
import 'dart:math';

import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

//import 'package:html/parser.dart' as html_parser;
// -- SEARCH (tylko dla TrybEgzaminu.wszystkie) --
class _InlineVideoPlayer extends StatefulWidget {
  const _InlineVideoPlayer({required this.url, this.height, super.key});

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
    // UWAGA: nie niszczymy kontrolerów globalnie, tylko oddajemy referencję
    _VideoPool().release(widget.url);
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_initError) {
      return Text(
        '❌ Nie udało się zainicjalizować wideo.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: player,
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
    // Video
    if (!_vp.containsKey(url)) {
      final v = VideoPlayerController.networkUrl(Uri.parse(url));
      await v.initialize();
      _vp[url] = v;
    }
    // Chewie
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
  @override
  void dispose() {
    _textSearchCtrl.dispose();
    super.dispose();
  }

  final TextEditingController _textSearchCtrl = TextEditingController();
  String searchText = '';
  String get _kvalSan => widget.kwalifikacja.replaceAll(' ', '').toLowerCase();

  List<dynamic> get _filteredQuestions {
    if (widget.tryb != TrybEgzaminu.wszystkie) return questions;
    final q = searchText.trim().toLowerCase();
    if (q.isEmpty) return questions;

    return questions.where((e) {
      final txt = (e['pytanie']?.toString() ?? '').toLowerCase();
      final a = (e['odp1']?.toString() ?? '').toLowerCase();
      final b = (e['odp2']?.toString() ?? '').toLowerCase();
      final c = (e['odp3']?.toString() ?? '').toLowerCase();
      final d = (e['odp4']?.toString() ?? '').toLowerCase();
      final idStr = (e['id']?.toString() ?? '').toLowerCase();
      return txt.contains(q) ||
          a.contains(q) ||
          b.contains(q) ||
          c.contains(q) ||
          d.contains(q) ||
          idStr.contains(q);
    }).toList();
  }

  bool _isButtonDisabled = false;
  List<dynamic> questions = [];
  int current = 0;
  String? selectedAnswer;
  bool isLoading = true;
  List<String?> selectedAnswers = [];
  List<bool> zapisanoOdpowiedz = [];
  late DateTime startTime;
  bool odpowiedzZatwierdzona = false;

  @override
  void initState() {
    super.initState();
    fetchQuestions();
    startTime = DateTime.now();
  }

  Future<Map<String, double>> fetchTrudnosciZdalnie() async {
    final url = Uri.parse(
      'https://interpage.pl/egzaminy/wyswietl_trudnosci.php',
    );
    if (mounted) {
      try {
        final response = await http.get(
          url,
          headers: {
            'Authorization': 'Bearer zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^',
          },
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final Map<String, double> map = {};

          for (var entry in data) {
            final key =
                '${entry['pytanie_id']}_${entry['kwalifikacja'].toString().toLowerCase()}';

            final trudnosc =
                (entry['trudnosc'] is num)
                    ? (entry['trudnosc'] as num).toDouble()
                    : double.tryParse(entry['trudnosc'].toString()) ?? 0.0;
            map[key] = trudnosc;
          }
          return map;
        } else {
          if (kDebugMode) {
            debugPrint(
              '❌ Błąd HTTP przy pobieraniu trudności: ${response.statusCode}',
            );
          }
          return {};
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Błąd połączenia: $e');
        }
        return {};
      }
    } else {
      return {};
    }
  }

  int calculateCorrectAnswers() {
    int correct = 0;
    for (int i = 0; i < questions.length; i++) {
      if (selectedAnswers[i] == questions[i]['poprawna']) {
        correct++;
      }
    }
    return correct;
  }

  Widget _buildBadge(dynamic q) {
    final trudnosc = q['trudnosc'];
    final iloscOdp = int.tryParse(q['ilosc_odpowiedzi']?.toString() ?? '') ?? 0;

    if (trudnosc == null || iloscOdp < 5) return const SizedBox.shrink();

    final difficulty =
        (trudnosc is num ? trudnosc : int.tryParse(trudnosc.toString()) ?? 0)
            .toInt();
    final isTrudne = difficulty > 50;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isTrudne ? Colors.red : Colors.green,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isTrudne ? 'TRUDNE' : 'ŁATWE',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> fetchQuestions() async {
    final kwalifikacja = widget.kwalifikacja.replaceAll(' ', '');
    final url = Uri.parse('https://interpage.pl/egzaminy/$kwalifikacja.php');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          final decoded = json.decode(response.body);
          if (decoded is List && decoded.isNotEmpty) {
            List<dynamic> allQuestions = decoded;
            List<dynamic> selected;

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

            final trudnosci = await fetchTrudnosciZdalnie();
            for (var q in selected) {
              final key = '${q['id']}_$_kvalSan';
              q['trudnosc'] = trudnosci[key] ?? 0.0;
            }

            if (mounted) {
              setState(() {
                questions = selected;
                selectedAnswers = List.filled(selected.length, null);
                zapisanoOdpowiedz = List.filled(selected.length, false);
                isLoading = false;
                if (kDebugMode) {
                  debugPrint(
                    '✅ Załadowano ${questions.length} pytań z domyślną trudnością',
                  );
                }
              });

              final trudnosciMap = await fetchAllTrudnosci(
                _kvalSan,
              ); // ← znormalizowana

              for (var q in questions) {
                final id = int.tryParse('${q['id']}');
                if (id != null && trudnosciMap.containsKey(id)) {
                  q['trudnosc'] =
                      trudnosciMap[id]?['trudnosc'] ?? (q['trudnosc'] ?? 0.0);
                  q['ilosc_odpowiedzi'] =
                      trudnosciMap[id]?['ilosc_odpowiedzi'] ?? 0;
                }
              }
              setState(() {}); // odśwież
            }
          }
        } else {
          if (kDebugMode) {
            debugPrint('❌ Brak danych z API!');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ Kod błędu HTTP: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("❌ Błąd przy pobieraniu pytań: $e");
      }
    }
  }

  Future<void> sendResultToServer({
    required String kwalifikacja,
    required double wynik,
    required String dataCzas,
    required int czasTrwania,
  }) async {
    String userName =
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

    if (response.statusCode != 200) {
      if (kDebugMode) {
        debugPrint('❌ Błąd przy zapisywaniu wyniku: ${response.body}');
      }
    } else {
      if (kDebugMode) {
        debugPrint('✅ Wynik zapisany dla userName: $userName');
      }
    }
  }

  Future<Map<int, Map<String, dynamic>>> fetchAllTrudnosci(
    String kwalifikacjaSan, // ← przekaż już znormalizowaną nazwę
  ) async {
    final url = Uri.parse(
      'https://interpage.pl/egzaminy/wyswietl_trudnosci.php',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return {};

      final List<dynamic> jsonList = json.decode(response.body);
      final Map<int, Map<String, dynamic>> result = {};

      for (final item in jsonList) {
        final String itemKwal =
            (item['kwalifikacja'] ?? '')
                .toString()
                .replaceAll(' ', '')
                .toLowerCase();

        if (itemKwal != kwalifikacjaSan) continue; // ← KLUCZOWE filtrowanie

        final int? id = int.tryParse('${item['pytanie_id']}');
        if (id == null) continue;

        final double trud =
            (item['trudnosc'] is num)
                ? (item['trudnosc'] as num).toDouble()
                : double.tryParse('${item['trudnosc']}') ?? 0.0;

        final int ilosc = int.tryParse('${item['ilosc_odpowiedzi']}') ?? 0;

        result[id] = {'trudnosc': trud, 'ilosc_odpowiedzi': ilosc};
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> zapiszTrudnoscDoBazy(
    int pytanieId,
    String kwalifikacja,
    bool poprawna,
  ) async {
    if (pytanieId <= 0) {
      if (kDebugMode) {
        debugPrint(
          '❌ Pominięto zapis - wartość pytanie_id jest niepoprawna: $pytanieId',
        );
      }
      return;
    }

    final url = Uri.parse('https://interpage.pl/egzaminy/zapis_trudnosci.php');
    final body = {
      'pytanie_id': pytanieId.toString(),
      'kwalifikacja': kwalifikacja.replaceAll(' ', ''),
      'poprawna': poprawna ? '1' : '0',
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Bearer zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        if (kDebugMode) {
          debugPrint('✅ Trudność zapisana: $data');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Błąd parsowania odpowiedzi: $e');
        }
      }
    } else {
      if (kDebugMode) {
        debugPrint(
          '❌ Błąd zapisu trudności: ${response.statusCode} ${response.body}',
        );
      }
    }
  }

  Future<double> fetchTrudnosc(int pytanieId, String kwalifikacja) async {
    final url = Uri.parse(
      'https://interpage.pl/egzaminy/zapis_trudnosci.php?pytanie_id=$pytanieId&kwalifikacja=$kwalifikacja',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        // Jeśli błąd bazy, zwróć 0
        return 0.0; // Tymczasowo, bo endpoint nie działa
      }
      return 0.0;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Błąd pobierania trudności: $e');
      }
      return 0.0;
    }
  }

  void checkAnswer(String answer) {
    if (odpowiedzZatwierdzona && widget.tryb == TrybEgzaminu.jednoPytanie) {
      return;
    }

    setState(() {
      selectedAnswer = answer;
      selectedAnswers[current] = answer;

      if (widget.tryb == TrybEgzaminu.jednoPytanie) {
        odpowiedzZatwierdzona = true;

        final pytanie = questions[current];
        final poprawna = answer == pytanie['poprawna'];

        zapiszTrudnoscDoBazy(
          int.parse(pytanie['id']),
          widget.kwalifikacja,
          poprawna,
        ).then((_) {
          fetchTrudnosc(int.parse(pytanie['id']), widget.kwalifikacja).then((
            trudnosc,
          ) {
            setState(() {
              questions[current]['trudnosc'] = trudnosc;
            });
          });
        });
      } else if (widget.tryb == TrybEgzaminu.czterdziesciPytan) {
        selectedAnswers[current] = answer;
      }
    });

    // ⛔ W trybie "wszystkie" nie zapisujemy niczego
    if (widget.tryb == TrybEgzaminu.wszystkie) return;
  }

  void nextQuestion() {
    if (current < questions.length - 1) {
      setState(() {
        current++;
        selectedAnswer = selectedAnswers[current];
      });
    }
  }

  void prevQuestion() {
    if (current > 0) {
      setState(() {
        current--;
        selectedAnswer = selectedAnswers[current];
      });
    }
  }

  void jumpToQuestion(String value) {
    final number = int.tryParse(value);
    if (number != null && number >= 1 && number <= questions.length) {
      setState(() {
        current = number - 1;
        selectedAnswer = selectedAnswers[current];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Egzamin'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context, {'returnToHome': widget.returnToHome});
            },
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Egzamin'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context, {'returnToHome': widget.returnToHome});
            },
          ),
        ),
        body: const Center(child: Text('Brak pytań do wyświetlenia.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Egzamin"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, {'returnToHome': widget.returnToHome});
          },
        ),
      ),
      body:
          widget.tryb == TrybEgzaminu.jednoPytanie
              ? _buildSingleQuestion(questions[current])
              : _buildScrollableList(),
      bottomNavigationBar:
          widget.tryb == TrybEgzaminu.czterdziesciPytan
              ? Padding(
                padding: const EdgeInsets.all(12.0),
                child: ElevatedButton(
                  onPressed:
                      _isButtonDisabled
                          ? null
                          : () async {
                            setState(() => _isButtonDisabled = true);

                            final correct = calculateCorrectAnswers();
                            final total = questions.length;
                            final percent = (correct / total) * 100;
                            final endTime = DateTime.now();
                            final duration =
                                endTime.difference(startTime).inSeconds;

                            if (widget.tryb == TrybEgzaminu.czterdziesciPytan) {
                              final futures = <Future>[];

                              for (int i = 0; i < questions.length; i++) {
                                final pytanie = questions[i];
                                final pytanieId = int.tryParse(
                                  pytanie['id'].toString(),
                                );
                                final odpowiedz = selectedAnswers[i];

                                if (pytanieId != null && odpowiedz != null) {
                                  final poprawna =
                                      odpowiedz == pytanie['poprawna'];
                                  futures.add(
                                    zapiszTrudnoscDoBazy(
                                      pytanieId,
                                      widget.kwalifikacja,
                                      poprawna,
                                    ),
                                  );
                                }
                              }

                              try {
                                await Future.wait(futures);
                                if (kDebugMode) {
                                  debugPrint(
                                    '✅ Trudność pytań została zapisana!',
                                  );
                                }
                              } catch (e) {
                                if (kDebugMode) {
                                  debugPrint(
                                    '❌ Błąd przy zapisie trudności: $e',
                                  );
                                }
                              }
                            }

                            await sendResultToServer(
                              kwalifikacja: widget.kwalifikacja,
                              wynik: percent,
                              dataCzas: endTime.toIso8601String(),
                              czasTrwania: duration,
                            );

                            setState(() => _isButtonDisabled = false);
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => EgzaminWynikView(
                                        correctAnswers: correct,
                                        totalQuestions: total,
                                        questions: questions,
                                        selectedAnswers: selectedAnswers,
                                        returnToHome: true,
                                      ),
                                  settings: const RouteSettings(
                                    name: 'EgzaminWynikView',
                                  ),
                                ),
                              );
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  child: Text(
                    _isButtonDisabled
                        ? "Wysyłanie egzaminu ..."
                        : "Zakończ egzamin",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              )
              : null,
    );
  }

  Html _html(String html) {
    html = html.replaceAll('<img', '<br><img');
    html = html.replaceAll('<video', '<br><video');

    return Html(
      data: html,
      style: {
        'div.questionHeader': Style(
          color: Theme.of(context).colorScheme.primary,
          fontSize: FontSize(18),
          verticalAlign: VerticalAlign.middle,
        ),
        'div.question': Style(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: FontSize(16),
          verticalAlign: VerticalAlign.middle,
        ),
        'div.answer': Style(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: FontSize(14),
          verticalAlign: VerticalAlign.middle,
        ),
        'div.description.correct': Style(
          color: Colors.green,
          fontSize: FontSize(14),
          fontStyle: FontStyle.italic,
        ),
        'div.description.incorrect': Style(
          color: Colors.red,
          fontSize: FontSize(14),
          fontStyle: FontStyle.italic,
        ),
        'b': Style(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          verticalAlign: VerticalAlign.middle,
        ),
        'div.media': Style(
          margin: Margins.symmetric(vertical: 12),
          textAlign: TextAlign.center,
        ),
      },
      extensions: [
        TagExtension(
          tagsToExtend: {'img'},
          builder: (ctx) {
            final src = ctx.attributes['src'];
            double? forcedHeight;
            final styleAttr = ctx.attributes['style'] ?? '';
            final m = RegExp(
              r'height\s*:\s*(\d+)\s*px',
              caseSensitive: false,
            ).firstMatch(styleAttr);
            if (m != null) {
              forcedHeight = double.tryParse(m.group(1)!);
            } else {
              final hAttr = ctx.attributes['height'];
              if (hAttr != null) forcedHeight = double.tryParse(hAttr);
            }

            if (src == null || src.isEmpty) {
              return Text(
                '⚠️ Brak obrazka',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: GestureDetector(
                    onTap: () => _showImageDialog(context, src),
                    child: Image.network(
                      src,
                      height: forcedHeight,
                      fit: BoxFit.contain,
                      errorBuilder:
                          (context, error, stackTrace) => Text(
                            '❌ Nie udało się załadować obrazka',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        TagExtension(
          tagsToExtend: {'video'},
          builder: (ctx) {
            final src = ctx.attributes['src'] ?? ctx.attributes['data-src'];
            double? forcedHeight;
            final styleAttr = ctx.attributes['style'] ?? '';
            final m = RegExp(
              r'height\s*:\s*(\d+)\s*px',
              caseSensitive: false,
            ).firstMatch(styleAttr);
            if (m != null) {
              forcedHeight = double.tryParse(m.group(1)!);
            } else {
              final hAttr = ctx.attributes['height'];
              if (hAttr != null) forcedHeight = double.tryParse(hAttr);
            }

            if (src == null || src.isEmpty) {
              return Text(
                '⚠️ Brak źródła wideo',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Focus(
                    canRequestFocus: false,
                    descendantsAreFocusable: false,
                    skipTraversal: true,
                    child: _InlineVideoPlayer(
                      key: GlobalObjectKey('video:$src'),
                      url: src,
                      height: forcedHeight,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Zamknij',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        final screenSize = MediaQuery.of(context).size;
        bool isPressed = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return GestureDetector(
              onTap: () => Navigator.of(context, rootNavigator: true).pop(),
              child: Scaffold(
                backgroundColor: Colors.black.withValues(alpha: 0.9),
                body: Stack(
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: () {},
                        child: Listener(
                          onPointerDown:
                              (_) => setState(() => isPressed = true),
                          onPointerUp: (_) => setState(() => isPressed = false),
                          child: MouseRegion(
                            cursor:
                                isPressed
                                    ? SystemMouseCursors.grabbing
                                    : SystemMouseCursors.grab,
                            child: InteractiveViewer(
                              panEnabled: true,
                              minScale: 0.5,
                              maxScale: 4,
                              child: Image.network(
                                imageUrl,
                                width: screenSize.width * 0.8,
                                fit: BoxFit.contain,
                                errorBuilder:
                                    (context, error, stackTrace) => Text(
                                      '❌ Nie udało się załadować obrazka',
                                      style: TextStyle(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.surface,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 30,
                          color: Theme.of(context).colorScheme.surface,
                        ),
                        tooltip: 'Zamknij',
                        onPressed:
                            () =>
                                Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSingleQuestion(dynamic q) {
    final questionHtml =
        '<div class="questionHeader"><b>Pytanie 1${q['id'] != null ? ' (ID ${q['id']})' : ''}:</b></div><br><div class="question">${q['pytanie']}</div>';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _html(questionHtml)),
                  _buildBadge(q),
                ],
              ),
              const SizedBox(height: 10),
              ...['A', 'B', 'C', 'D'].map((litera) {
                final odp = q['odp${'ABCD'.indexOf(litera) + 1}'];
                final isCorrect = litera == q['poprawna'];
                final isWrong = selectedAnswer == litera && !isCorrect;
                final isSelected = selectedAnswer == litera;

                Color? buttonColor;
                if (odpowiedzZatwierdzona) {
                  if (isCorrect) {
                    buttonColor = Colors.green;
                  } else if (isWrong) {
                    buttonColor = Colors.red;
                  } else if (isSelected) {
                    buttonColor = Theme.of(context).colorScheme.primary;
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          buttonColor ?? Theme.of(context).colorScheme.surface,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                    onPressed:
                        (odpowiedzZatwierdzona && !isSelected)
                            ? null
                            : () => checkAnswer(litera),
                    child: _html('<div class="answer">${odp ?? ""}</div>'),
                  ),
                );
              }),
              if (odpowiedzZatwierdzona && selectedAnswer != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _html(
                    selectedAnswer == q['poprawna']
                        ? '<div class="description correct">✅ Odpowiedź $selectedAnswer jest poprawna.<br>${q['opisPoprawne']}</div>'
                        : '<div class="description incorrect">❌ Odpowiedź $selectedAnswer jest niepoprawna.<br>${q['opisNiepoprawne']}<br><div class="description correct">✅ Odpowiedź poprawna to: ${q['poprawna']}</div></div>',
                  ),
                ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _losujNowePytanie,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Losuj kolejne"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _losujNowePytanie() {
    setState(() {
      if (questions.length <= 1) return;

      final rand = Random();
      int newIndex = current;
      while (newIndex == current) {
        newIndex = rand.nextInt(questions.length);
      }

      current = newIndex;
      selectedAnswer = null;
      odpowiedzZatwierdzona = false;
    });
  }

  Widget _buildScrollableList() {
    final isAll = widget.tryb == TrybEgzaminu.wszystkie;
    final items = isAll ? _filteredQuestions : questions;

    return CustomScrollView(
      slivers: [
        if (isAll)
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedSearchHeader(
              height: 98,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _textSearchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Szukaj w treści / odpowiedziach / ID',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => searchText = v),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Znalezione: ${items.length} / ${questions.length}',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(top: 8)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final q = items[index] as Map<String, dynamic>;
              final originalIndex = questions.indexOf(q);
              final selected = selectedAnswers[originalIndex];

              final questionHtml =
                  '<div class="questionHeader"><b>Pytanie ${originalIndex + 1}${q['id'] != null ? ' (ID ${q['id']})' : ''}:</b></div><br><div class="question">${q['pytanie']}</div>';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: _html(questionHtml)),
                          _buildBadge(q),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...['A', 'B', 'C', 'D'].map((litera) {
                        final odp = q['odp${'ABCD'.indexOf(litera) + 1}'];
                        final isSelected = selected == litera;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isSelected
                                      ? Theme.of(context).colorScheme.primary
                                          .withValues(alpha: 0.8)
                                      : Theme.of(context).colorScheme.surface,
                              foregroundColor:
                                  Theme.of(context).colorScheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                selectedAnswers[originalIndex] = litera;
                              });
                            },
                            child: _html(
                              '<div class="answer">${odp ?? ""}</div>',
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PinnedSearchHeader extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _PinnedSearchHeader({required this.child, this.height = 98});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: overlapsContent ? 2 : 0, // delikatny cień gdy treść pod spodem
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedSearchHeader oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

class _InteractiveImage extends StatefulWidget {
  final String imageUrl;
  const _InteractiveImage({required this.imageUrl});

  @override
  State<_InteractiveImage> createState() => _InteractiveImageState();
}

class _InteractiveImageState extends State<_InteractiveImage> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Listener(
      onPointerDown: (_) => setState(() => _isPressed = true),
      onPointerUp: (_) => setState(() => _isPressed = false),
      child: MouseRegion(
        cursor:
            _isPressed ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            widget.imageUrl,
            fit: BoxFit.contain,
            width: screenSize.width * 0.9,
            errorBuilder:
                (context, error, stackTrace) => Text(
                  '❌ Nie udało się załadować obrazka',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
