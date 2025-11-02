import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:shimmer/shimmer.dart';

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
  factory _VideoPool() => _i;
  _VideoPool._();

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

class EgzaminPodgladView extends StatelessWidget {
  final List<dynamic> questions;
  final List<String?> selectedAnswers;
  final HtmlUnescape _unescape = HtmlUnescape();

  EgzaminPodgladView({
    super.key,
    required this.questions,
    required this.selectedAnswers,
  });

  Widget _buildQuestionCard(BuildContext context, int index) {
    final q = questions[index];
    final selected = selectedAnswers[index];
    final poprawna = q['poprawna']?.toString() ?? '';
    final isCorrect = selected == poprawna;

    final pytanieText = _unescape.convert(q['pytanie']?.toString() ?? '');

    final List<String> pytanieImages =
        (q['images'] as List?)?.cast<String>() ?? [];
    final List<String> pytanieVideos =
        (q['videos'] as List?)?.cast<String>() ?? [];

    final Map<String, String> odpText = {};
    final Map<String, List<String>> odpImages = {};
    final Map<String, List<String>> odpVideos = {};

    for (int i = 1; i <= 4; i++) {
      final key = 'odp$i';
      odpText[key] = _unescape.convert(q[key]?.toString() ?? '');
      odpImages[key] = (q['${key}_images'] as List?)?.cast<String>() ?? [];
      odpVideos[key] = (q['${key}_videos'] as List?)?.cast<String>() ?? [];
    }

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
                Text(
                  'Pytanie ${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              pytanieText,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.left,
            ),
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
              final text = odpText[key] ?? '';
              final images = odpImages[key] ?? [];
              final videos = odpVideos[key] ?? [];
              final isCorrectAnswer = litera == poprawna;
              final isSelected = selected == litera;
              final isWrong = isSelected && !isCorrectAnswer;

              Color? bg;
              if (isCorrectAnswer) {
                bg = Colors.green;
              } else if (isSelected && isWrong) {
                bg = Colors.red;
              } else {
                bg = Theme.of(context).colorScheme.surface;
              }

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: bg,
                    disabledForegroundColor:
                        Theme.of(context).colorScheme.onSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: const TextStyle(fontSize: 15),
                        textAlign: TextAlign.left,
                      ),
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
            }),

            if (selected != null) ...[
              const SizedBox(height: 8),
              Text(
                isCorrect
                    ? 'Correct answer $selected.'
                    : 'Incorrect answer $selected. Correct answer: $poprawna.',
                style: TextStyle(
                  color: isCorrect ? Colors.green : Colors.red,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (isCorrect &&
                  (q['opisPoprawne']?.toString().isNotEmpty ?? false))
                Text(
                  _unescape.convert(q['opisPoprawne'].toString()),
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              if (!isCorrect &&
                  (q['opisNiepoprawne']?.toString().isNotEmpty ?? false))
                Text(
                  _unescape.convert(q['opisNiepoprawne'].toString()),
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ] else ...[
              const SizedBox(height: 8),
              const Text(
                'Warning: No answer selected.',
                style: TextStyle(
                  color: Colors.amber,
                  fontStyle: FontStyle.italic,
                ),
              ),
              Text(
                'Correct answer: $poprawna.',
                style: const TextStyle(
                  color: Colors.green,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Podgląd egzaminu')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        itemBuilder: (c, i) => _buildQuestionCard(c, i),
      ),
    );
  }
}
