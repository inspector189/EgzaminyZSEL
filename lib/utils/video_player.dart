import 'package:chewie/chewie.dart' show ChewieController, Chewie;
import 'package:flutter/material.dart'
    show
        StatefulWidget,
        State,
        AutomaticKeepAliveClientMixin,
        BuildContext,
        Widget,
        SizedBox,
        EdgeInsets,
        Theme,
        TextStyle,
        Text,
        CircularProgressIndicator,
        Center,
        BoxFit,
        FittedBox,
        AspectRatio,
        Padding,
        RepaintBoundary;
import 'package:video_player/video_player.dart' show VideoPlayerController;

class InlineVideoPlayer extends StatefulWidget {
  const InlineVideoPlayer({super.key, required this.url, this.height});
  final String url;
  final double? height;

  @override
  State<InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<InlineVideoPlayer>
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
    final colorScheme = Theme.of(context).colorScheme;
    super.build(context);
    if (_initError) {
      return Text(
        'Nie udało się wczytać wideo',
        style: TextStyle(color: colorScheme.error),
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
