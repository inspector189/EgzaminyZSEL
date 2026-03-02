import 'dart:io' show File;

import 'package:chewie/chewie.dart' show ChewieController, Chewie;
import 'package:flutter/material.dart' show StatefulWidget, State, AutomaticKeepAliveClientMixin, BuildContext, Widget, SizedBox, EdgeInsets, Theme, TextStyle, Text, CircularProgressIndicator, Center, BoxFit, FittedBox, AspectRatio, Padding, RepaintBoundary;
import 'package:video_player/video_player.dart' show VideoPlayerController;

class InlineVideoPlayer extends StatefulWidget {
  const InlineVideoPlayer({
    super.key,
    this.url,
    this.filePath,
    this.blobUrl,
    this.height,
  }) : assert(
         url != null || filePath != null || blobUrl != null,
         'Podaj url, filePath albo blobUrl (co najmniej jedno)',
       );

  final String? url;
  final String? filePath;
  final String? blobUrl;
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
      _chewie = await _VideoPool().getChewie(
        widget.url ?? widget.blobUrl ?? widget.filePath!,
        filePath: widget.filePath,
        blobUrl: widget.blobUrl,
      );
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _initError = true);
    }
  }

  @override
  void dispose() {
    _VideoPool().release(widget.url ?? widget.blobUrl ?? widget.filePath!);
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
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
  factory _VideoPool() => _i;
  _VideoPool._();

  final Map<String, VideoPlayerController> _vp = {};
  final Map<String, ChewieController> _chewie = {};
  final Map<String, int> _refs = {};

  Future<ChewieController> getChewie(
    String key, {
    String? filePath,
    String? blobUrl,
  }) async {
    if (!_vp.containsKey(key)) {
      final v =
          filePath != null
              ? VideoPlayerController.file(File(filePath))
              : VideoPlayerController.networkUrl(Uri.parse(blobUrl ?? key));
      await v.initialize();
      _vp[key] = v;
    }
    if (!_chewie.containsKey(key)) {
      _chewie[key] = ChewieController(
        videoPlayerController: _vp[key]!,
        autoInitialize: true,
        autoPlay: false,
        looping: false,
        showControls: true,
        allowMuting: true,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
      );
    }
    _refs[key] = (_refs[key] ?? 0) + 1;
    return _chewie[key]!;
  }

  void release(String key) {
    final r = (_refs[key] ?? 0) - 1;
    if (r > 0) {
      _refs[key] = r;
      return;
    }
    _refs.remove(key);
    _chewie.remove(key)?.dispose();
    _vp.remove(key)?.dispose();
  }
}
