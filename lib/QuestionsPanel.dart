import 'package:flutter/material.dart';
import 'package:flutter_app/app_themes.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'dart:convert';

class QuestionStatsPage extends StatefulWidget {
  const QuestionStatsPage({super.key});
  @override
  _QuestionStatsPageState createState() => _QuestionStatsPageState();
}

class _QuestionStatsPageState extends State<QuestionStatsPage>
    with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> questionStats = [];

  final Map<String, List<dynamic>> loadedQuestions = {};
  final Map<String, bool> isLoadingQual = {};
  final Map<String, ScrollController> controllers = {};
  final Map<String, int> visibleCounts = {};
  final Map<String, bool> isLoadingMore = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    fetchQuestionStats();
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> parseQuestionHtml(String html) {
    final List<String> images = [];
    final imgRegex = RegExp(
      r'<img[^>]+src="([^">]+)"',
      caseSensitive: false,
      multiLine: true,
    );

    for (final match in imgRegex.allMatches(html)) {
      final src = match.group(1);
      if (src != null && src.isNotEmpty) images.add(src);
    }

    final text =
        html
            .replaceAll(RegExp(r'<img[^>]*>', caseSensitive: false), '')
            .replaceAll(RegExp(r'<[^>]*>', caseSensitive: false), '')
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .trim();

    return {'text': text, 'images': images};
  }

  Future<void> fetchQuestionStats() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://interpage.pl/egzaminy/wyswietl_trudnosci.php'),
        headers: {
          'Authorization': 'Bearer zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final result = json.decode(response.body);
      if (result is! List) throw Exception('Invalid format');

      setState(() {
        questionStats = result;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Błąd: $e';
      });
    }
  }

  Map<String, List<dynamic>> groupByQualification() {
    final Map<String, List<dynamic>> grouped = {};
    for (var r in questionStats) {
      final q = (r['kwalifikacja'] ?? 'Nieznana').toString();
      grouped.putIfAbsent(q, () => []);
      grouped[q]!.add(r);
    }
    return grouped;
  }

  Future<void> loadQualification(String kwal) async {
    if (loadedQuestions.containsKey(kwal)) return;
    setState(() => isLoadingQual[kwal] = true);

    try {
      final res = await http.get(
        Uri.parse(
          'https://interpage.pl/egzaminy/${kwal.replaceAll(" ", "")}.php',
        ),
      );

      if (res.statusCode == 200) {
        final parsed = json.decode(res.body);
        if (parsed is List) {
          final stats =
              questionStats
                  .where(
                    (item) =>
                        (item['kwalifikacja'] ?? '').replaceAll(' ', '') ==
                        kwal,
                  )
                  .toList();

          final List<Map<String, dynamic>> enriched = [];
          for (final s in stats) {
            final q = parsed.firstWhere(
              (p) => p['id'].toString() == s['pytanie_id'].toString(),
              orElse: () => null,
            );
            if (q != null) enriched.add({...s, ...q});
          }

          enriched.sort(
            (a, b) => int.tryParse(
              a['pytanie_id'].toString(),
            )!.compareTo(int.tryParse(b['pytanie_id'].toString())!),
          );

          setState(() {
            loadedQuestions[kwal] = enriched;
            visibleCounts[kwal] = enriched.length < 30 ? enriched.length : 30;
            isLoadingMore[kwal] = false;

            final scroll = ScrollController();
            scroll.addListener(() => _onScroll(kwal));
            controllers[kwal] = scroll;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading $kwal: $e');
    } finally {
      setState(() => isLoadingQual[kwal] = false);
    }
  }

  void _onScroll(String kwal) {
    final controller = controllers[kwal];
    if (controller == null || isLoadingMore[kwal] == true) return;

    if (controller.position.pixels >=
        controller.position.maxScrollExtent - 200) {
      final currentCount = visibleCounts[kwal] ?? 30;
      final total = loadedQuestions[kwal]?.length ?? 0;
      if (currentCount >= total) return;

      setState(() => isLoadingMore[kwal] = true);
      {
        if (!mounted) return;
        setState(() {
          visibleCounts[kwal] = (currentCount + 30).clamp(0, total);
          isLoadingMore[kwal] = false;
        });
      }
    }
  }

  Widget _buildDifficultyBadge(BuildContext context, dynamic stat) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final extras = theme.extension<ExtraColors>()!;
    final trudnosc =
        (stat['trudnosc'] is num)
            ? (stat['trudnosc'] as num).toDouble()
            : double.tryParse(stat['trudnosc'].toString()) ?? 0.0;
    final color = trudnosc > 50 ? extras.incorrect : extras.correct;
    final label = trudnosc > 50 ? 'TRUDNE' : 'ŁATWE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label (${trudnosc.toStringAsFixed(1)}%)',
        style: TextStyle(color: colorScheme.surface, fontSize: 12),
      ),
    );
  }

  Widget buildZoomableImage(BuildContext context, String url) {
    final extras = Theme.of(context).extension<ExtraColors>()!;
    return GestureDetector(
      onTap: () {
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Close',
          pageBuilder: (context, anim1, anim2) {
            return Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 1.0,
                maxScale: 5.0,
                child: Image(image: NetworkImage(url), fit: BoxFit.contain),
              ),
            );
          },
          transitionBuilder: (context, anim1, anim2, child) {
            return FadeTransition(opacity: anim1, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
      },
      child: Image.network(
        url,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Shimmer.fromColors(
            baseColor: extras.shimmerBase,
            highlightColor: extras.shimmerHighlight,
            child: Container(
              width: double.infinity,
              height: 250,
              color: extras.shimmerBase,
            ),
          );
        },
        errorBuilder:
            (context, error, stack) => Container(
              color: extras.shimmerBase,
              height: 250,
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
      ),
    );
  }

  Widget _buildQuestionCard(dynamic q) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final extras = theme.extension<ExtraColors>()!;
    final questionId = q['pytanie_id'] ?? '-';
    final qualification = q['kwalifikacja'] ?? '-';
    final totalAnswers = int.tryParse(q['ilosc_odpowiedzi'].toString()) ?? 0;
    final correctAnswers =
        int.tryParse(q['ilosc_poprawnych_odpowiedzi'].toString()) ?? 0;
    final successRate =
        totalAnswers > 0
            ? ((correctAnswers / totalAnswers) * 100).toStringAsFixed(1)
            : '0.0';
    final pytanie = q['pytanie'] ?? '';
    final odp1 = q['odp1'] ?? '';
    final odp2 = q['odp2'] ?? '';
    final odp3 = q['odp3'] ?? '';
    final odp4 = q['odp4'] ?? '';
    final poprawna = q['poprawna']?.toString() ?? '';
    final List<String> images = List<String>.from(q['images'] ?? []);
    final List<String> videos = List<String>.from(q['videos'] ?? []);

    Widget buildVideoPlayer(String url) {
      final controller = VideoPlayerController.networkUrl(url as Uri);
      controller.initialize();
      controller.setLooping(false);
      controller.play();

      return AspectRatio(
        aspectRatio:
            controller.value.aspectRatio > 0
                ? controller.value.aspectRatio
                : 16 / 9,
        child: VideoPlayer(controller),
      );
    }

    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pytanie #$questionId',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                  _buildDifficultyBadge(context, q),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                pytanie,
                style: TextStyle(fontSize: 16, color: colorScheme.onPrimary),
              ),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 8),
                Column(
                  children:
                      images
                          .map(
                            (url) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: buildZoomableImage(context, url),
                            ),
                          )
                          .toList(),
                ),
              ],
              if (videos.isNotEmpty) ...[
                const SizedBox(height: 8),
                Column(
                  children:
                      videos
                          .map(
                            (url) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: buildVideoPlayer(url),
                            ),
                          )
                          .toList(),
                ),
              ],
              const SizedBox(height: 8),
              ...['A', 'B', 'C', 'D'].map((litera) {
                final odp =
                    {'A': odp1, 'B': odp2, 'C': odp3, 'D': odp4}[litera] ?? '';
                final isCorrect = litera == poprawna;
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCorrect ? extras.correct : null,
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: () {},
                    child: Text(
                      odp,
                      style: TextStyle(
                        fontSize: 15,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
              Text(
                '✅ Poprawna: $poprawna',
                style: TextStyle(
                  color: extras.correct,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kwalifikacja: $qualification',
                style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
              ),
              Text(
                'Odpowiedzi: $totalAnswers, Poprawne: $correctAnswers ($successRate%)',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedShimmer() {
    final extras = Theme.of(context).extension<ExtraColors>()!;
    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: extras.shimmerBase,
        highlightColor: extras.shimmerHighlight,
        period: const Duration(milliseconds: 1000),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          height: 110,
          decoration: BoxDecoration(
            color: extras.shimmerBase,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final grouped = groupByQualification();

    return Scaffold(
      appBar: AppBar(
        title: const Text('📉 Statystyki Trudności Pytań'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchQuestionStats,
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : RefreshIndicator(
                onRefresh: fetchQuestionStats,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final entry = grouped.entries.elementAt(index);
                    final kwal = entry.key;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        title: Text(
                          '$kwal (${entry.value.length} pytań)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onExpansionChanged: (expanded) {
                          if (expanded) loadQualification(kwal);
                        },
                        children: [
                          if (isLoadingQual[kwal] == true)
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (loadedQuestions[kwal] == null)
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('Kliknij, by załadować pytania...'),
                            )
                          else
                            SizedBox(
                              height: 400,
                              child: ListView.builder(
                                controller: controllers[kwal],
                                addAutomaticKeepAlives: false,
                                addRepaintBoundaries: true,
                                itemCount:
                                    (visibleCounts[kwal] ?? 0) +
                                    ((isLoadingMore[kwal] ?? false) ? 3 : 0),
                                itemBuilder: (context, i) {
                                  final questions = loadedQuestions[kwal]!;
                                  if (i < (visibleCounts[kwal] ?? 0)) {
                                    return _buildQuestionCard(questions[i]);
                                  } else {
                                    return _buildAnimatedShimmer();
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
