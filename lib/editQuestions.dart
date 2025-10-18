import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
/// UŻYJ universal_html, żeby nie psuć buildu poza web:
import 'package:universal_html/html.dart' as html;
import 'dart:async';

enum MediaKind { none, image, video }

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  const VideoPlayerWidget({super.key, required this.url});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() => _initialized = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        VideoPlayer(_controller),
        VideoProgressIndicator(_controller, allowScrubbing: true),
      ],
    );
  }
}

class EditQuestionsPage extends StatefulWidget {
  const EditQuestionsPage({super.key, required this.qualification});
  final String qualification;

  @override
  State<EditQuestionsPage> createState() => _EditQuestionsPageState();
}
class _InlineVideoPlayer extends StatefulWidget {
  const _InlineVideoPlayer({this.url, this.filePath, this.blobUrl, this.height, super.key})
      : assert(url != null || filePath != null || blobUrl != null,
            'Podaj url, filePath albo blobUrl (co najmniej jedno)');

  final String? url;       // https://...
  final String? filePath;  // ścieżka lokalna (mobile/desktop)
  final String? blobUrl;   // blob:... (web)
  final double? height;

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  VideoPlayerController? _vp;
  ChewieController? _chewie;
  bool _initError = false;

  @override
  void initState() {
    super.initState();
    try {
      if (widget.filePath != null) {
        _vp = VideoPlayerController.file(File(widget.filePath!));
      } else {
        final src = widget.blobUrl ?? widget.url!;
        _vp = VideoPlayerController.networkUrl(Uri.parse(src));
      }

      _vp!.initialize().then((_) {
        if (!mounted) return;
        _chewie = ChewieController(
          videoPlayerController: _vp!,
          autoInitialize: true,
          autoPlay: false,
          looping: false,
          showControls: true,
          allowMuting: true,
          allowFullScreen: true,
          allowPlaybackSpeedChanging: true,
        );
        setState(() {});
      }).catchError((_) {
        if (mounted) setState(() => _initError = true);
      });
    } catch (_) {
      _initError = true;
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _vp?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initError || _vp == null) {
      return Text('❌ Nie udało się zainicjalizować wideo.',
          style: TextStyle(color: Theme.of(context).colorScheme.surface));
    }
    if (_chewie == null || !_vp!.value.isInitialized) {
      return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }

    final h = widget.height;
    final aspect = _vp!.value.aspectRatio == 0 ? 16 / 9 : _vp!.value.aspectRatio;
    Widget player = Chewie(controller: _chewie!);
    if (h != null) {
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
    return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: player);
  }
}

class _EditQuestionsPageState extends State<EditQuestionsPage> {

String _lastPreviewSignature = '';

String _currentMediaSignature() {
  // Co wpływa na wygląd podglądu mediów:
  // - rodzaj media (none/image/video)
  // - źródło obrazka (URL / dataURI) lub nazwa+rozmiar w bajtach
  // - źródło filmu (URL) lub nazwa+rozmiar w bajtach
  // - aktualna wysokość (px)
  final kind = _mediaKind.name;

  final imgUrl = (_uploadedImageUrl ?? _imageCtrl.text.trim());
  final imgBytesSig = (_imageBytes != null && _imageBytes!.isNotEmpty)
      ? '${_imageName ?? ''}|${_imageBytes!.length}'
      : '';

  final vidUrl = _uploadedVideoUrl ?? '';
  final vidBytesSig = (_videoBytes != null && _videoBytes!.isNotEmpty)
      ? '${_videoName ?? ''}|${_videoBytes!.length}'
      : '';

  final height = _imageHeightPx?.toString() ?? '';

  // To wystarczy, by wychwycić: zamianę typu, podmianę pliku/URL, usunięcie,
  // i zmianę wysokości.
  return [kind, imgUrl, imgBytesSig, vidUrl, vidBytesSig, height].join('::');
}

  // ====== WEB/MOBILE helpers dla lokalnego wideo ======
  String? _tempVideoPath;   // ścieżka pliku tymczasowego (mobile/desktop)
  String? _webBlobUrl;      // blob:... (web)
  Timer? _previewDebounce;

    void _refreshTextPreview() {
  if (_showPreview && mounted) setState(() {});
}
void _refreshIfPreview({bool immediate = false}) {

  if (!_showPreview) return;

  final newSig = _currentMediaSignature();
  if (newSig == _lastPreviewSignature) {
    // Nic się nie zmieniło w mediach — nie przeładowuj podglądu.
    return;
  }
  _lastPreviewSignature = newSig;

  if (immediate) {
    if (mounted) setState(() {});
    return;
  }
  _previewDebounce?.cancel();
  _previewDebounce = Timer(const Duration(milliseconds: 300), () {
    if (!mounted) return;
    // Utrzymaj spójność, jeśli w międzyczasie zaszła kolejna zmiana.
    if (_currentMediaSignature() != _lastPreviewSignature) return;
    setState(() {});
  });
}


  void _revokeWebBlobUrl() {
    if (kIsWeb && _webBlobUrl != null) {
      try { html.Url.revokeObjectUrl(_webBlobUrl!); } catch (_) {}
      _webBlobUrl = null;
    }
  }

  Future<String?> _ensureLocalTempVideo() async {
    if (_videoBytes == null || _videoBytes!.isEmpty) return null;

    if (kIsWeb) {
      _revokeWebBlobUrl();
      final ext = (_videoName?.split('.').last.toLowerCase() ?? 'mp4');
      final mime = switch (ext) {
        'webm' => 'video/webm',
        'ogg'  => 'video/ogg',
        _      => 'video/mp4',
      };
      final blob = html.Blob([_videoBytes!], mime);
      _webBlobUrl = html.Url.createObjectUrlFromBlob(blob);
      return _webBlobUrl; // blob:...
    } else {
      final dir = await getTemporaryDirectory();
      final ext = (_videoName?.split('.').last.toLowerCase() ?? 'mp4')
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
      final file = File('${dir.path}/editq_local_preview.${ext.isEmpty ? 'mp4' : ext}');
      await file.writeAsBytes(_videoBytes!, flush: true);
      _tempVideoPath = file.path;
      return _tempVideoPath;
    }
  }

  Future<void> _disposeLocalTempVideo() async {
    if (!kIsWeb && _tempVideoPath != null) {
      try {
        final f = File(_tempVideoPath!);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      _tempVideoPath = null;
    }
    _revokeWebBlobUrl();
  }

  // ====== stałe i pomocniki dla trybu edycji ======
  static const _kStyleTag =
      '<style>img,video{display:block;max-width:100%;height:auto;margin:12px auto;}</style>';
  static final _kStyleTagEsc = const HtmlEscape().convert(_kStyleTag);

  static final _imgTagRawRe = RegExp(
    r'<img[^>]+src="https://interpage\.pl/egzaminy/[^/]+/obrazy/image\d+\.jpg"[^>]*\/?>',
    caseSensitive: false,
  );
  static final _imgTagEscRe = RegExp(
    r'&lt;img[^&]+src=&quot;https://interpage\.pl/egzaminy/[^/]+/obrazy/image\d+\.jpg&quot;[^&]*&gt;',
    caseSensitive: false,
  );

  static final _videoTagRawRe = RegExp(
    r'<video[^>]+src="https://interpage\.pl/egzaminy/[^/]+/filmy/video\d+\.mp4"[^>]*>.*?<\/video>',
    caseSensitive: false,
    dotAll: true,
  );
  static final _videoTagEscRe = RegExp(
    r'&lt;video[^&]+src=&quot;https://interpage\.pl/egzaminy/[^/]+/filmy/video\d+\.mp4&quot;[^&]*&gt;.*?&lt;\/video&gt;',
    caseSensitive: false,
    dotAll: true,
  );

String _stripStyleAndImage(String html) {
  var out = html;

  // 1) usuń DOWOLNY <style>…</style> (także z atrybutami) + wersję escaped
  out = out.replaceAll(
    RegExp(r'<style\b[^>]*>.*?<\/style>', caseSensitive: false, dotAll: true),
    '',
  );
  out = out.replaceAll(
    RegExp(r'&lt;style\b[^&]*&gt;.*?&lt;\/style&gt;', caseSensitive: false, dotAll: true),
    '',
  );

  // 2) usuń nasze media (raw i escaped)
  out = out.replaceAll(_imgTagRawRe, '');
  out = out.replaceAll(_imgTagEscRe, '');
  out = out.replaceAll(_videoTagRawRe, '');
  out = out.replaceAll(_videoTagEscRe, '');

  // 3) oczyść nadmiarowe <br> / &nbsp; na krawędziach
  out = out.replaceAll(RegExp(r'(<br\s*\/?>|\s|&nbsp;)+$', caseSensitive: false), '');
  out = out.replaceAll(RegExp(r'^(<br\s*\/?>|\s|&nbsp;)+', caseSensitive: false), '');

  // 4) skompresuj białe znaki
  out = out.replaceAll(RegExp(r'\s+'), ' ').trim();

  return out;
}


  String _unescapeLtGt(String s) =>
      s.replaceAll('&lt;', '<').replaceAll('&gt;', '>');
  String _escapeLtGt(String s) =>
      s.replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  String _answerToUi(String? raw) {
    var t = (raw ?? '');
    t = t.replaceFirst(RegExp(r'^[A-D]\.\s*'), '');
    t = _unescapeLtGt(t);
    return t;
  }

  String? _filenameFromUrl(String url) {
    try {
      final segs = Uri.parse(url).pathSegments;
      return segs.isNotEmpty ? segs.last : null;
    } catch (_) {
      return null;
    }
  }

  int? get _nextId {
    final ids = questions
        .map((q) => int.tryParse(q['id']?.toString() ?? ''))
        .where((v) => v != null)
        .cast<int>()
        .toList();
    if (ids.isEmpty) return 1;
    ids.sort();
    return ids.last + 1;
  }

  bool isLoading = true;
  List<dynamic> questions = [];
  String searchText = '';
  final ScrollController _listController = ScrollController();

  final TextEditingController _textSearchCtrl = TextEditingController();
  final ScrollController _leftPanelScroll = ScrollController();

  // ====== Formularz dodawania/edycji ======
  int? editingId;
  final TextEditingController _imageCtrl = TextEditingController();
  final TextEditingController _contentCtrl = TextEditingController();
  final TextEditingController _odp1Ctrl = TextEditingController();
  final TextEditingController _odp2Ctrl = TextEditingController();
  final TextEditingController _odp3Ctrl = TextEditingController();
  final TextEditingController _odp4Ctrl = TextEditingController();

  final TextEditingController _imageHeightCtrl = TextEditingController();
  int? _imageHeightPx; // wspólna wysokość (img + video)

  final TextEditingController _opisPoprawneCtrl = TextEditingController();
  final TextEditingController _opisNiepoprawneCtrl = TextEditingController();
  String _correct = 'A';

  // ====== MULTIMEDIA ======
  MediaKind _mediaKind = MediaKind.none;

  // obraz
  Uint8List? _imageBytes;
  String? _imageName;
  String? _uploadedImageUrl;
  String? _uploadedImageFilename;

  // wideo
  Uint8List? _videoBytes;
  String? _videoName;
  String? _uploadedVideoUrl;
  String? _uploadedVideoFilename;

  bool _isUploading = false;
  bool _showPreview = false;

  // ====== lifecycle ======
  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();

    _listController.dispose();
    _textSearchCtrl.dispose();
    _leftPanelScroll.dispose();
    _imageHeightCtrl.dispose();
    _imageCtrl.dispose();
    _contentCtrl.dispose();
    _odp1Ctrl.dispose();
    _odp2Ctrl.dispose();
    _odp3Ctrl.dispose();
    _odp4Ctrl.dispose();
    _opisPoprawneCtrl.dispose();
    _opisNiepoprawneCtrl.dispose();
    _disposeLocalTempVideo();
    super.dispose();
  }

  // ====== data ======
  Future<void> _loadAll() async {
    setState(() => isLoading = true);
    try {
      final qs = await _fetchQuestions(_sanitizedTable());
      final trud = await _fetchAllTrudnosci();

      for (final q in qs) {
        final id = int.tryParse(q['id'].toString());
        if (id != null && trud.containsKey(id)) {
          q['trudnosc'] = trud[id]?['trudnosc'] ?? 0.0;
          q['ilosc_odpowiedzi'] = trud[id]?['ilosc_odpowiedzi'] ?? 0;
        } else {
          q['trudnosc'] = 0.0;
          q['ilosc_odpowiedzi'] = 0;
        }
      }

      setState(() {
        questions = qs;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Błąd ładowania: $e')));
      }
    }
  }

  String _sanitizedTable() =>
      widget.qualification.replaceAll('.', '').replaceAll(' ', '').toLowerCase();

  Future<List<dynamic>> _fetchQuestions(String kval) async {
    final url = Uri.parse('https://interpage.pl/egzaminy/$kval.php');
    final res = await http.get(url);
    if (res.statusCode == 200 && res.body.isNotEmpty) {
      final decoded = json.decode(res.body);
      if (decoded is List) return decoded;
      throw '❌ Nieprawidłowy format danych pytań';
    }
    throw 'ℹ️ HTTP ${res.statusCode} przy pobieraniu pytań';
  }

  Future<Map<int, Map<String, dynamic>>> _fetchAllTrudnosci() async {
    final url = Uri.parse('https://interpage.pl/egzaminy/wyswietl_trudnosci.php');
    final res = await http.get(url);
    if (res.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(res.body);
      final Map<int, Map<String, dynamic>> result = {};
      for (final item in jsonList) {
        final int? id = int.tryParse(item['pytanie_id'].toString());
        if (id != null) {
          result[id] = {
            'trudnosc': (item['trudnosc'] is num)
                ? (item['trudnosc'] as num).toDouble()
                : double.tryParse('${item['trudnosc']}') ?? 0.0,
            'ilosc_odpowiedzi': item['ilosc_odpowiedzi'] ?? 0,
          };
        }
      }
      return result;
    }
    return {};
  }

  // ====== wyszukiwarka ======
  void _applyTextFilter(String value) {
    setState(() {
      searchText = value.trim();
    });
  }

  // ====== nowy rekord ======
  void _startNewQuestion() {
    _showPreview = false;
    setState(() {
      editingId = null;
      _imageCtrl.clear();
      _contentCtrl.clear();
      _odp1Ctrl.clear();
      _odp2Ctrl.clear();
      _odp3Ctrl.clear();
      _odp4Ctrl.clear();
      _opisPoprawneCtrl.clear();
      _opisNiepoprawneCtrl.clear();
      _correct = 'A';

      // obraz
      _imageBytes = null;
      _imageName = null;
      _uploadedImageUrl = null;
      _uploadedImageFilename = null;

      // video
      _videoBytes = null;
      _videoName = null;
      _uploadedVideoUrl = null;
      _uploadedVideoFilename = null;

      _mediaKind = MediaKind.none;

      _isUploading = false;
      _imageHeightPx = null;
      _imageHeightCtrl.clear();
      _disposeLocalTempVideo();
    });
  }

  // ====== edycja ======
  void _openForEdit(Map<String, dynamic> q) {
    setState(() {
      editingId = int.tryParse(q['id']?.toString() ?? '');
      final rawHtml = q['pytanie']?.toString() ?? '';

      final imgUrl = _extractFirstTagSrc(rawHtml, 'img');
      final vidUrl = _extractFirstTagSrc(rawHtml, 'video');

      if (vidUrl != null) {
        _mediaKind = MediaKind.video;
        _uploadedVideoUrl = vidUrl;
        _uploadedVideoFilename = _filenameFromUrl(vidUrl);
      } else if (imgUrl != null) {
        _mediaKind = MediaKind.image;
        _imageCtrl.text = imgUrl;
        _uploadedImageUrl = imgUrl;
        _uploadedImageFilename = _filenameFromUrl(imgUrl);
      } else {
        _mediaKind = MediaKind.none;
      }

      _imageHeightPx = _parseTagHeightPx(rawHtml);
      _imageHeightCtrl.text = _imageHeightPx?.toString() ?? '';

      final cleaned = _stripStyleAndImage(rawHtml);
      _contentCtrl.text = _unescapeLtGt(cleaned);

      _odp1Ctrl.text = _answerToUi(q['odp1']?.toString());
      _odp2Ctrl.text = _answerToUi(q['odp2']?.toString());
      _odp3Ctrl.text = _answerToUi(q['odp3']?.toString());
      _odp4Ctrl.text = _answerToUi(q['odp4']?.toString());

      _opisPoprawneCtrl.text = q['opisPoprawne']?.toString() ?? '';
      _opisNiepoprawneCtrl.text = q['opisNiepoprawne']?.toString() ?? '';

      final poprawna = (q['poprawna']?.toString().toUpperCase() ?? 'A');
      _correct = ['A', 'B', 'C', 'D'].contains(poprawna) ? poprawna : 'A';

      _imageBytes = null;
      _imageName = null;
      _videoBytes = null;
      _videoName = null;
      _disposeLocalTempVideo();
    });
  }

  int? _parseTagHeightPx(String html) {
    final i1 = html.toLowerCase().indexOf('<img');
    final i2 = html.toLowerCase().indexOf('<video');
    int tagStart = -1;
    if (i1 != -1 && (i2 == -1 || i1 < i2)) tagStart = i1;
    if (i2 != -1 && (i1 == -1 || i2 < i1)) tagStart = i2;
    if (tagStart == -1) return null;
    final tagEnd = html.indexOf('>', tagStart);
    if (tagEnd == -1) return null;
    final tag = html.substring(tagStart, tagEnd + 1);

    final styleRe = RegExp(r'''style\s*=\s*["']([^"']+)["']''', caseSensitive: false);
    final styleMatch = styleRe.firstMatch(tag);
    if (styleMatch == null) return null;
    final style = styleMatch.group(1)!;

    final hRe = RegExp(r'height\s*:\s*(\d+)\s*px', caseSensitive: false);
    final hMatch = hRe.firstMatch(style);
    if (hMatch == null) return null;

    final v = int.tryParse(hMatch.group(1)!);
    if (v == null || v <= 0) return null;
    return v;
  }

  String? _extractFirstTagSrc(String html, String tagName) {
    final idx = html.toLowerCase().indexOf('<$tagName');
    if (idx == -1) return null;
    final srcIdx = html.indexOf('src=', idx);
    if (srcIdx == -1) return null;
    final quote = html.contains('src="') ? '"' : (html.contains("src='") ? "'" : '"');
    final qIdx = html.indexOf('src=$quote', idx);
    if (qIdx == -1) return null;
    final start = qIdx + 5;
    final end = html.indexOf(quote, start);
    if (end == -1) return null;
    return html.substring(start, end);
  }

  // ====== HTML podgląd ======
  String _buildPreviewHtml() {
    final escapedBody = _escapeLtGt(_contentCtrl.text.trim());
    String mediaPart = '';

    if (_mediaKind == MediaKind.image) {
      String? imgSrc;
      if ((_uploadedImageUrl ?? '').isNotEmpty) {
        imgSrc = _uploadedImageUrl!;
      } else if (_imageCtrl.text.trim().isNotEmpty) {
        imgSrc = _imageCtrl.text.trim();
      } else if (_imageBytes != null && _imageBytes!.isNotEmpty) {
        final ext = (_imageName ?? 'png').split('.').last.toLowerCase();
        final mime = (ext == 'jpg') ? 'jpeg' : ext;
        imgSrc = 'data:image/$mime;base64,${base64Encode(_imageBytes!)}';
      }
      final h = _imageHeightPx;
      mediaPart = (imgSrc == null)
          ? ''
          : '<img alt="" src="$imgSrc"${h != null ? ' style="height: ${h}px;"' : ''}/>';
    } else if (_mediaKind == MediaKind.video) {
      final h = _imageHeightPx;
      if (_uploadedVideoUrl != null) {
        mediaPart =
            '<video src="${_uploadedVideoUrl!}"${h != null ? ' style=""' : ''} controls preload="metadata"></video>';
      } else if (_videoBytes != null && _videoBytes!.isNotEmpty) {
        mediaPart =
            '<video${h != null ? ' style="height: ${h}px;"' : ''} controls preload="metadata"></video>';
      } else {
        mediaPart = '';
      }
    }
    if (_mediaKind == MediaKind.video && mediaPart.isNotEmpty) {
      mediaPart = '<br>' + mediaPart;
    }
    return _kStyleTag + escapedBody + mediaPart;
  }

  // ====== Obraz ======
  Future<void> _pickImage() async {
    try {
      final typeGroup = const XTypeGroup(
        label: 'images',
        extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _mediaKind = MediaKind.image;
        _imageBytes = bytes;
        _imageName = file.name;
        _uploadedImageUrl = null;
        _uploadedImageFilename = null;
        
      });
      _refreshIfPreview(immediate: true);
    }
     catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Nie udało się otworzyć selektora plików: $e')),
        );
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_imageBytes == null || _imageName == null) return;
    setState(() => _isUploading = true);
  _refreshIfPreview(immediate: true);
    try {
      final uri = Uri.parse('https://interpage.pl/egzaminy/upload_image_next.php');
      String ext = (_imageName ?? 'jpg').split('.').last.toLowerCase();
      if (ext.isEmpty) ext = 'jpg';
      final mediaType = http_parser.MediaType('image', ext == 'jpg' ? 'jpeg' : ext);

      final req = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^'
        ..headers['X-API-Key']     = 'zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^'
        ..headers['Accept']        = 'application/json'
        ..fields['kwalifikacja']   = _sanitizedTable()
        ..fields['egzamin']        = _sanitizedTable()
        ..files.add(http.MultipartFile.fromBytes(
          'file', _imageBytes!,
          filename: _imageName ?? 'upload.$ext',
          contentType: mediaType,
        ));

      final res = await http.Response.fromStream(await req.send());
      if (res.statusCode != 200) throw 'Upload HTTP ${res.statusCode}: ${res.body}';
      final data = jsonDecode(res.body);
      if (data['ok'] != true || data['url'] == null) {
        throw 'Upload error: ${data['error'] ?? 'brak szczegółów'}';
      }

      setState(() {
        _uploadedImageUrl = data['url'] as String;
        _uploadedImageFilename =
            (data['filename'] as String?) ?? _filenameFromUrl(_uploadedImageUrl!);
        _mediaKind = MediaKind.image;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Obrazek został wgrany.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Błąd podczas wysyłania obrazka: $e')),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _previewImage() {
    final url = _uploadedImageUrl ?? _imageCtrl.text.trim();
    if (url.isNotEmpty) {
      _showImageDialogUrl(url);
      return;
    }
    if (_imageBytes != null && _imageBytes!.isNotEmpty) {
      _showImageDialogBytes(_imageBytes!);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('❌ Brak obrazka do podglądu.')),
    );
  }

  void _showImageDialogUrl(String imageUrl) {
    _showImageDialogBody(
      builder: (screen) => Image.network(
        imageUrl,
        height: _imageHeightPx?.toDouble(),
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) => Text(
          '❌ Nie udało się załadować obrazka',
          style: TextStyle(color: Theme.of(context).colorScheme.surface),
        ),
      ),
    );
  }

  void _showImageDialogBytes(Uint8List bytes) {
    _showImageDialogBody(
      builder: (screen) => Image.memory(
        bytes,
        height: _imageHeightPx?.toDouble(),
        fit: BoxFit.contain,
      ),
    );
  }

  void _showImageDialogBody({required Widget Function(Size screen) builder}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Zamknij',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, a1, a2) {
        final screen = MediaQuery.of(context).size;
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
                          onPointerDown: (_) => setState(() => isPressed = true),
                          onPointerUp: (_) => setState(() => isPressed = false),
                          child: MouseRegion(
                            cursor: isPressed
                                ? SystemMouseCursors.grabbing
                                : SystemMouseCursors.grab,
                            child: InteractiveViewer(
                              panEnabled: true,
                              minScale: 0.5,
                              maxScale: 4,
                              child: builder(screen),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: IconButton(
                        icon: Icon(Icons.close,
                            size: 30,
                            color: Theme.of(context).colorScheme.surface),
                        tooltip: 'Zamknij',
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true).pop(),
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

  // ====== Wideo ======
  Future<void> _pickVideo() async {
    try {
      final typeGroup = const XTypeGroup(
        label: 'video',
        extensions: ['mp4', 'webm', 'ogg'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _mediaKind = MediaKind.video;
        _videoBytes = bytes;
        _videoName = file.name;
        _uploadedVideoUrl = null;
        _uploadedVideoFilename = null;
      });
      _refreshIfPreview(immediate: true);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Nie udało się otworzyć pliku wideo: $e')),
      );
    }
  }

  Future<void> _uploadVideo() async {
    if (_videoBytes == null || _videoName == null) return;

    setState(() => _isUploading = true);
    try {
      final uri = Uri.parse('https://interpage.pl/egzaminy/upload_video.php');

      final ext = _videoName!.split('.').last.toLowerCase();
      final http_parser.MediaType mt = switch (ext) {
        'webm' => http_parser.MediaType('video', 'webm'),
        'ogg'  => http_parser.MediaType('video', 'ogg'),
        _      => http_parser.MediaType('video', 'mp4'),
      };

      final req = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^'
        ..headers['X-API-Key']     = 'zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^'
        ..headers['Accept']        = 'application/json'
        ..fields['kwalifikacja']   = _sanitizedTable()
        ..fields['egzamin']        = _sanitizedTable()
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          _videoBytes!,
          filename: _videoName!,
          contentType: mt,
        ));

      final res = await http.Response.fromStream(await req.send());
      if (res.statusCode != 200) {
        throw 'HTTP ${res.statusCode}: ${res.body}';
      }

      final data = jsonDecode(res.body);
      if (data['ok'] != true || data['url'] == null) {
        throw 'Upload error: ${data['error'] ?? 'brak szczegółów'}';
      }

      setState(() {
        _uploadedVideoUrl = data['url'] as String;
        _uploadedVideoFilename =
            (data['filename'] as String?) ?? _filenameFromUrl(_uploadedVideoUrl!);
        _mediaKind = MediaKind.video;
      });
      _refreshIfPreview(immediate: true);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Błąd podczas wysyłania filmu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _previewVideo() async {
    String? localPathOrBlob;
    if (_uploadedVideoUrl == null && _videoBytes != null) {
      localPathOrBlob = await _ensureLocalTempVideo();
    }

    if (_uploadedVideoUrl == null && localPathOrBlob == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brak wideo do podglądu.')),
        );
      }
      return;
    }

    if (!mounted) return;
    final h = _imageHeightPx?.toDouble();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Podgląd wideo'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_uploadedVideoUrl != null)
                  Text('URL: ${_uploadedVideoUrl!}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _InlineVideoPlayer(
                    url: _uploadedVideoUrl,                             // może być null
                    filePath: kIsWeb ? null : localPathOrBlob,           // mobile/desktop
                    blobUrl: kIsWeb ? localPathOrBlob : null,            // web
                    height: h,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zamknij'),
            ),
          ],
        );
      },
    );
  }

  void _removeMedia() {
    setState(() {
      // obraz
      _imageBytes = null;
      _imageName = null;
      _uploadedImageUrl = null;
      _uploadedImageFilename = null;
      _imageCtrl.clear();

      // wideo
      _videoBytes = null;
      _videoName = null;
      _uploadedVideoUrl = null;
      _uploadedVideoFilename = null;

      _mediaKind = MediaKind.none;
      _isUploading = false;
      _disposeLocalTempVideo();
    });
    _refreshIfPreview(immediate: true);

  }

  // ====== Zapis pytania ======
  Future<void> _saveQuestion() async {
    final pyt = _contentCtrl.text.trim();
    final a = _odp1Ctrl.text.trim();
    final b = _odp2Ctrl.text.trim();
    final c = _odp3Ctrl.text.trim();
    final d = _odp4Ctrl.text.trim();

    if (pyt.isEmpty || a.isEmpty || b.isEmpty || c.isEmpty || d.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uzupełnij treść i wszystkie odpowiedzi.')),
      );
      return;
    }

    // auto-upload obrazka jeśli wybrany
    if (_mediaKind == MediaKind.image &&
        _uploadedImageUrl == null &&
        _imageBytes != null &&
        _imageBytes!.isNotEmpty) {
      try {
        setState(() => _isUploading = true);

        final uri = Uri.parse('https://interpage.pl/egzaminy/upload_image_next.php');
        String ext = (_imageName ?? 'jpg').split('.').last.toLowerCase();
        if (ext.isEmpty) ext = 'jpg';
        final mediaType =
            http_parser.MediaType('image', ext == 'jpg' ? 'jpeg' : ext);

        final req = http.MultipartRequest('POST', uri)
          ..headers['Authorization'] =
              'Bearer zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^'
          ..headers['X-API-Key'] =
              'zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^'
          ..headers['Accept'] = 'application/json'
          ..fields['kwalifikacja'] = _sanitizedTable()
          ..fields['egzamin'] = _sanitizedTable()
          ..files.add(http.MultipartFile.fromBytes(
            'file',
            _imageBytes!,
            filename: _imageName ?? 'upload.$ext',
            contentType: mediaType,
          ));

        final res = await http.Response.fromStream(await req.send());
        if (res.statusCode != 200) {
          throw 'Upload HTTP ${res.statusCode}: ${res.body}';
        }
        final data = jsonDecode(res.body);
        if (data['ok'] != true || data['url'] == null) {
          throw 'Upload error: ${data['error'] ?? 'brak szczegółów'}';
        }

        _uploadedImageUrl = data['url'] as String;
        _uploadedImageFilename =
            (data['filename'] as String?) ?? _filenameFromUrl(_uploadedImageUrl!);
      } catch (e) {
        if (!mounted) return;
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Błąd uploadu obrazka: $e')),
        );
        return;
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }

    // auto-upload wideo jeśli wybrane
    if (_mediaKind == MediaKind.video &&
        _uploadedVideoUrl == null &&
        _videoBytes != null &&
        _videoBytes!.isNotEmpty) {
      await _uploadVideo();
      if (_uploadedVideoUrl == null) return;
    }

    final payload = <String, dynamic>{
      'egzamin': _sanitizedTable(),
      'pytanie': pyt,
      'odp1': a,
      'odp2': b,
      'odp3': c,
      'odp4': d,
      'poprawna': _correct,
      'opisPoprawne': _opisPoprawneCtrl.text.trim(),
      'opisNiepoprawne': _opisNiepoprawneCtrl.text.trim(),
      if (editingId != null) 'id': editingId,
    };

    if (_mediaKind == MediaKind.image) {
      payload['img_filename'] =
          _uploadedImageFilename ?? _filenameFromUrl(_imageCtrl.text.trim());
      if (_imageHeightPx != null && _imageHeightPx! > 0) {
        payload['img_height'] = _imageHeightPx;
      }
    } else if (_mediaKind == MediaKind.video) {
      payload['video_filename'] = _uploadedVideoFilename;
      if (_imageHeightPx != null && _imageHeightPx! > 0) {
        payload['video_height'] = _imageHeightPx; // jeśli wspierasz w PHP
      }
    }

    try {
      final res = await http.post(
        Uri.parse('https://interpage.pl/egzaminy/add_question.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (res.statusCode != 200) {
        throw 'HTTP ${res.statusCode}: ${res.body}';
      }
      final body = jsonDecode(res.body);
      if (body is! Map || body['ok'] != true) {
        throw body['error'] ?? 'Nieznany błąd serwera';
      }

      final isEdit = editingId != null;
      final int? savedId = (body['id'] is int)
          ? body['id'] as int
          : int.tryParse('${body['id']}');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEdit
            ? '✅ Pytanie zaktualizowane (ID ${savedId ?? editingId})'
            : '✅ Pytanie dodane (ID ${savedId ?? '—'})'),
      ));

      setState(() => _showPreview = false);
      _startNewQuestion();
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Błąd zapisu: $e')),
      );
    }
  }

  Future<void> _deleteQuestion(int id) async {
    try {
      final res = await http.post(
        Uri.parse('https://interpage.pl/egzaminy/delete_question.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
          'Authorization': 'Bearer zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^',
          'X-API-Key': 'zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^',
        },
        body: jsonEncode({'egzamin': _sanitizedTable(), 'id': id}),
      );

      if (res.statusCode != 200) {
        throw 'HTTP ${res.statusCode}: ${res.body}';
      }

      final body = jsonDecode(res.body);
      if (body['ok'] != true) {
        throw body['error'] ?? 'Błąd usuwania';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Pytanie zostało usunięte.')),
        );
      }

      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Błąd podczas usuwania pytania: $e')),
        );
      }
    }
  }

  // ====== Render HTML (z obsługą <img> i <video>) ======
  Html _html(String html) {
    html = html.replaceAll('<img', '<br><img');

    return Html(
      data: html,
      style: {
        "body": Style(color: Theme.of(context).colorScheme.onSurface),
        "b": Style(color: Theme.of(context).colorScheme.onSurface),
        "span": Style(
          color: html.contains("style='color:green;'")
              ? Colors.green
              : Theme.of(context).colorScheme.onSurface,
        ),
      },
      extensions: [
        // IMG z uchwytem zmiany wysokości
        TagExtension(
          tagsToExtend: {'img'},
          builder: (ctx) {
            final src = ctx.attributes['src'];

            double? forcedHeight;
            final styleAttr = ctx.attributes['style'] ?? '';
            final m = RegExp(r'height\s*:\s*(\d+)\s*px', caseSensitive: false)
                .firstMatch(styleAttr);
            if (m != null) {
              forcedHeight = double.tryParse(m.group(1)!);
            } else {
              final hAttr = ctx.attributes['height'];
              if (hAttr != null) forcedHeight = double.tryParse(hAttr);
            }
            if (_showPreview && _imageHeightPx != null) {
              forcedHeight = _imageHeightPx!.toDouble();
            }

            Widget _wrapInteractive(Widget child) {
              const minH = 80;
              const maxH = 2000;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Listener(
                    onPointerSignal: (signal) {
                      if (!_showPreview) return;
                      if (signal is PointerScrollEvent) {
                        int cur = _imageHeightPx ?? (forcedHeight?.round() ?? 320);
                        final next = (cur - signal.scrollDelta.dy)
                            .clamp(minH, maxH)
                            .round();
                        setState(() {
                          _imageHeightPx = next;
                          _imageHeightCtrl.text = next.toString();
                        });
                      }
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanUpdate: (details) {
                            if (!_showPreview) return;
                            int cur =
                                _imageHeightPx ?? (forcedHeight?.round() ?? 320);
                            final next = (cur + details.delta.dy)
                                .clamp(minH, maxH)
                                .round();
                            setState(() {
                              _imageHeightPx = next;
                              _imageHeightCtrl.text = next.toString();
                            });
                          },
                          child: child,
                        ),
                        if (_showPreview)
                          Positioned(
                            bottom: 8,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.resizeUpDown,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.unfold_more,
                                        size: 16, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_imageHeightPx ?? forcedHeight?.round() ?? 320}px',
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (src == null || src.isEmpty) {
              return Text(
                '⚠️ Brak obrazka',
                style: TextStyle(color: Theme.of(context).colorScheme.surface),
              );
            }

            if (src.startsWith('data:image/')) {
              try {
                final base64Part = src.split(',').last;
                final bytes = base64Decode(base64Part);
                return _wrapInteractive(
                  Image.memory(bytes, height: forcedHeight, fit: BoxFit.contain),
                );
              } catch (_) {
                return const Text('❌ Nie udało się wyświetlić obrazka (data URI).');
              }
            }

            return _wrapInteractive(
              Tooltip(
                message: _showPreview
                    ? 'Przeciągnij / przewiń, aby zmienić wysokość'
                    : 'Kliknij, aby powiększyć',
                child: MouseRegion(
                  cursor: _showPreview
                      ? SystemMouseCursors.resizeUpDown
                      : SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _showPreview ? null : () => _showImageDialog(context, src),
                    child: Image.network(
                      src,
                      height: forcedHeight,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Text(
                        '❌ Nie udało się załadować obrazka',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.surface),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // VIDEO z kontrolkami (Chewie) + lokalne źródło
        TagExtension(
          tagsToExtend: {'video'},
          builder: (ctx) {
            final src = ctx.attributes['src'] ?? ctx.attributes['data-src'];

            double? forcedHeight;
            final styleAttr = ctx.attributes['style'] ?? '';
            final m = RegExp(r'height\s*:\s*(\d+)\s*px', caseSensitive: false)
                .firstMatch(styleAttr);
            if (m != null) {
              forcedHeight = double.tryParse(m.group(1)!);
            } else {
              final hAttr = ctx.attributes['height'];
              if (hAttr != null) forcedHeight = double.tryParse(hAttr);
            }
            if (_showPreview && _imageHeightPx != null) {
              forcedHeight = _imageHeightPx!.toDouble();
            }

            if (src != null && src.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Align(
                  alignment: Alignment.center, // wyśrodkuj w kolumnie HTML-a
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720), // ładna szerokość
                    child: _InlineVideoPlayer(url: src, height: forcedHeight),
                  ),
                ),
              );
            }

            if (_showPreview && _mediaKind == MediaKind.video && _videoBytes != null) {
              return FutureBuilder<String?>(
                future: _ensureLocalTempVideo(),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      height: 160,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }
                  final p = snap.data;
                  if (p == null) {
                    return Text(
                      '❌ Brak lokalnego źródła wideo.',
                      style: TextStyle(color: Theme.of(context).colorScheme.surface),
                    );
                  }
                  final Widget player = kIsWeb
                      ? _InlineVideoPlayer(blobUrl: p, height: forcedHeight)
                      : _InlineVideoPlayer(filePath: p, height: forcedHeight);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: player,
                      ),
                    ),
                  );

                },
              );
            }

            return Text('⚠️ Brak źródła wideo',
                style: TextStyle(color: Theme.of(context).colorScheme.surface));
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
      pageBuilder: (context, a1, a2) {
        final screen = MediaQuery.of(context).size;
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
                          onPointerDown: (_) => setState(() => isPressed = true),
                          onPointerUp: (_) => setState(() => isPressed = false),
                          child: MouseRegion(
                            cursor: isPressed
                                ? SystemMouseCursors.grabbing
                                : SystemMouseCursors.grab,
                            child: InteractiveViewer(
                              panEnabled: true,
                              minScale: 0.5,
                              maxScale: 4,
                              child: Image.network(
                                imageUrl,
                                width: screen.width * 0.8,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stack) => Text(
                                  '❌ Nie udało się załadować obrazka',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.surface,
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
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true).pop(),
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

  // ====== UI helpers ======
  Widget _buildBadge(dynamic q) {
    final trudnosc = q['trudnosc'];
    final iloscOdp =
        int.tryParse(q['ilosc_odpowiedzi']?.toString() ?? '') ?? 0;
    if (trudnosc == null || iloscOdp < 5) return const SizedBox.shrink();

    final diff =
        (trudnosc is num ? trudnosc : int.tryParse(trudnosc.toString()) ?? 0)
            .toInt();
    final isTrudne = diff > 50;

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

  List<dynamic> get _filteredQuestions {
    if (searchText.isEmpty) return questions;
    final q = searchText.toLowerCase();

    return questions.where((e) {
      final txt = (e['pytanie']?.toString() ?? '').toLowerCase();
      final a = (e['odp1']?.toString() ?? '').toLowerCase();
      final b = (e['odp2']?.toString() ?? '').toLowerCase();
      final c = (e['odp3']?.toString() ?? '').toLowerCase();
      final d = (e['odp4']?.toString() ?? '').toLowerCase();

      final idStr = (e['id']?.toString() ?? '').toLowerCase();
      final matchId = idStr.contains(q);

      return matchId ||
          txt.contains(q) ||
          a.contains(q) ||
          b.contains(q) ||
          c.contains(q) ||
          d.contains(q);
    }).toList();
  }

  // ====== build ======
  @override
  Widget build(BuildContext context) {
    final leftPanel = _buildLeftPanel(context);
    final rightList = isLoading
        ? const Center(child: CircularProgressIndicator())
        : (_showPreview ? _buildLivePreview() : _buildList());

    return Scaffold(
      appBar: AppBar(
        title: Text('Edytor pytań — ${widget.qualification.toUpperCase()}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            tooltip: 'Odśwież',
            onPressed: isLoading ? null : _loadAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 420, child: leftPanel),
          Container(width: 1, color: Theme.of(context).dividerColor),
          Expanded(child: rightList),
        ],
      ),
    );
  }

  Widget _buildLeftPanel(BuildContext context) {
    final labelStyle = TextStyle(
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurface,
    );

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Scrollbar(
        controller: _leftPanelScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _leftPanelScroll,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🔎 Wyszukaj', style: labelStyle),
              const SizedBox(height: 8),
              TextField(
                controller: _textSearchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Szukaj w treści/odpowiedziach/ID',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _applyTextFilter,
              ),
              const SizedBox(height: 16),
              Divider(color: Theme.of(context).dividerColor, height: 1),
              const SizedBox(height: 16),

              Row(
                children: [
                  Text(
                    editingId == null
                        ? '➕ Dodaj nowe pytanie${_nextId != null ? ' (ID $_nextId)' : ''}'
                        : '✏️ Edytujesz ID $editingId',
                    style: labelStyle,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _startNewQuestion,
                    icon: const Icon(Icons.add),
                    label: const Text('Nowe'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ======= MULTIMEDIA =======
              Container(
                 width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Multimedia (obrazek lub film)', style: labelStyle),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      children: [
                        ChoiceChip(
                          label: const Text('Brak'),
                          selected: _mediaKind == MediaKind.none,
                          onSelected: (_) {
                            setState(() {
                              _mediaKind = MediaKind.none;
                              _removeMedia();
                            });
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Obrazek'),
                          selected: _mediaKind == MediaKind.image,
                          onSelected: (_) {
                            setState(() {
                              _mediaKind = MediaKind.image;
                              _videoBytes = null;
                              _videoName = null;
                              _uploadedVideoUrl = null;
                              _uploadedVideoFilename = null;
                              _disposeLocalTempVideo();
                            });
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Film'),
                          selected: _mediaKind == MediaKind.video,
                          onSelected: (_) {
                            setState(() {
                              _mediaKind = MediaKind.video;
                              _imageBytes = null;
                              _imageName = null;
                              _uploadedImageUrl = null;
                              _uploadedImageFilename = null;
                              _imageCtrl.clear();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_mediaKind == MediaKind.image) ...[
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Wybierz obrazek'),
                          ),
                          const SizedBox(width: 8),
                          if (_isUploading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (_uploadedImageUrl != null || _imageName != null)
                        Row(
                          children: [
                            const Icon(Icons.image, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _uploadedImageUrl ?? _imageName ?? '',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      _heightFieldRow(),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, // odstęp poziomy
                        runSpacing: 8, // odstęp pionowy, jeśli się złamie linia
                        children: [
                          if (_uploadedImageUrl != null || _imageBytes != null)
                          TextButton.icon(
                            onPressed: _removeMedia,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Usuń'),
                          ),
                          if (_uploadedImageUrl != null || _imageBytes != null)
                            OutlinedButton.icon(
                              onPressed: _previewImage,
                              icon: const Icon(Icons.visibility),
                              label: const Text('Podgląd'),
                            ),
                        ],
                      )
                    ]
                    else if (_mediaKind == MediaKind.video) ...[
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickVideo,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Wybierz film (mp4/webm/ogg)'),
                          ),
                          const SizedBox(width: 8),
                          if (_isUploading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (_uploadedVideoUrl != null || _videoName != null)
                        Row(
                          children: [
                            const Icon(Icons.movie, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _uploadedVideoUrl ?? _videoName ?? '',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, // odstęp poziomy
                        runSpacing: 8, // odstęp pionowy, jeśli się złamie linia
                        children: [
                          if (_uploadedVideoUrl != null || _videoBytes != null)
                          TextButton.icon(
                            onPressed: _removeMedia,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Usuń'),
                          ), 
                          if (_uploadedVideoUrl != null || _videoBytes != null)
                            OutlinedButton.icon(
                              onPressed: _previewVideo,
                              icon: const Icon(Icons.visibility),
                              label: const Text('Podgląd'),
                            ),
                        ],
                      )
                    ]
                    else
                      const Text('Nie dodajesz multimediów do pytania.'),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _contentCtrl,
                onChanged: (_) => _refreshTextPreview(),
                decoration: const InputDecoration(
                  labelText: 'Treść pytania',
                  border: OutlineInputBorder(),
                ),
                maxLines: 8,
                minLines: 8,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _opisPoprawneCtrl,
                onChanged: (_) => _refreshTextPreview(),
                decoration: const InputDecoration(
                  labelText: 'Opis (dla poprawnej odpowiedzi) - opcjonalnie',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                minLines: 3,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _opisNiepoprawneCtrl,
                onChanged: (_) => _refreshTextPreview(),
                decoration: const InputDecoration(
                  labelText: 'Opis (dla niepoprawnej odpowiedzi) - opcjonalnie',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                minLines: 3,
              ),
              const SizedBox(height: 24),

              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _odp1Ctrl,
                    onChanged: (_) => _refreshTextPreview(),
                    decoration: const InputDecoration(
                      labelText: 'Odpowiedź A',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _odp2Ctrl,
                    onChanged: (_) => _refreshTextPreview(),
                    decoration: const InputDecoration(
                      labelText: 'Odpowiedź B',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _odp3Ctrl,
                    onChanged: (_) => _refreshTextPreview(),
                    decoration: const InputDecoration(
                      labelText: 'Odpowiedź C',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _odp4Ctrl,
                    onChanged: (_) => _refreshTextPreview(),
                    decoration: const InputDecoration(
                      labelText: 'Odpowiedź D',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Poprawna:'),
                  DropdownButton<String>(
                    value: _correct,
                    onChanged: (v) => setState(() => _correct = v ?? 'A'),
                    items: const [
                      DropdownMenuItem(value: 'A', child: Text('A')),
                      DropdownMenuItem(value: 'B', child: Text('B')),
                      DropdownMenuItem(value: 'C', child: Text('C')),
                      DropdownMenuItem(value: 'D', child: Text('D')),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end, // wyrównanie do prawej
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _showPreview = true),
                        icon: const Icon(Icons.visibility),
                        label: const Text('Zobacz podgląd'),
                      ),
                      const SizedBox(width: 8), // odstęp między przyciskami
                      ElevatedButton.icon(
                        onPressed: _saveQuestion,
                        icon: const Icon(Icons.save),
                        label: const Text('Zapisz'),
                      ),
                    ],
                  )

                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heightFieldRow() {
    if (_uploadedImageUrl != null || _imageBytes != null){
      return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _imageHeightCtrl,
                decoration: const InputDecoration(
                  labelText: 'Wysokość [px]',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final n = int.tryParse(v.trim());
                  setState(() {
                    _imageHeightPx = (n == null || n <= 0) ? null : n;
                  });
                  _refreshIfPreview(immediate: true); // ważne: natychmiast
                },
              ),
            ),
            const SizedBox(width: 8),
          ],
        );
    }
    else{
      return Row();
    }
    
  }

  Widget _buildList() {
    final items = _filteredQuestions;

    return ListView.builder(
      controller: _listController,
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final q = items[index] as Map<String, dynamic>;
        final id = int.tryParse(q['id']?.toString() ?? '');
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
                    Expanded(
                      child: _html(
                        "<b>Pytanie ${index + 1}${id != null ? ' (ID $id)' : ''}:</b><br>${q['pytanie']}",
                      ),
                    ),
                    _buildBadge(q),
                  ],
                ),
                const SizedBox(height: 10),

                ...['A', 'B', 'C', 'D'].map((litera) {
                  final odp = q['odp${'ABCD'.indexOf(litera) + 1}'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 240, 240, 240),
                        foregroundColor:
                            Theme.of(context).colorScheme.onSurface,
                      ),
                      onPressed: null,
                      child: _html(odp ?? ""),
                    ),
                  );
                }),

                const SizedBox(height: 8),

                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _openForEdit(q),
                      icon: const Icon(Icons.edit),
                      label: const Text('Edytuj'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: id == null
                          ? null
                          : () async {
                              final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogCtx) => AlertDialog(
                                      title: const Text('Usuń pytanie'),
                                      content: Text(
                                          'Na pewno chcesz usunąć pytanie ID $id?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialogCtx, false),
                                          child: const Text('Anuluj'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(dialogCtx, true),
                                          child: const Text('Usuń'),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;

                              if (!mounted) return;
                              if (ok) {
                                await _deleteQuestion(id);
                              }
                            },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Usuń'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLivePreview() {
  final escapedBody = _escapeLtGt(_contentCtrl.text.trim());
  final textHtml = _kStyleTag + escapedBody; // tylko treść pytania (bez mediów)

  // zbuduj sam fragment mediów do osobnego Html
  String mediaHtml = '';
  if (_mediaKind == MediaKind.image) {
    String? imgSrc;
    if ((_uploadedImageUrl ?? '').isNotEmpty) {
      imgSrc = _uploadedImageUrl!;
    } else if (_imageCtrl.text.trim().isNotEmpty) {
      imgSrc = _imageCtrl.text.trim();
    } else if (_imageBytes != null && _imageBytes!.isNotEmpty) {
      final ext = (_imageName ?? 'png').split('.').last.toLowerCase();
      final mime = (ext == 'jpg') ? 'jpeg' : ext;
      imgSrc = 'data:image/$mime;base64,${base64Encode(_imageBytes!)}';
    }
    final h = _imageHeightPx;
    if (imgSrc != null) {
      mediaHtml = '<img alt="" src="$imgSrc"${h != null ? ' style="height: ${h}px;"' : ''}/>';
    }
  } else if (_mediaKind == MediaKind.video) {
    final h = _imageHeightPx;
    if (_uploadedVideoUrl != null) {
      mediaHtml =
          '<video src="${_uploadedVideoUrl!}"${h != null ? ' style=""' : ''} controls preload="metadata"></video>';
    } else if (_videoBytes != null && _videoBytes!.isNotEmpty) {
      mediaHtml =
          '<video${h != null ? ' style="height: ${h}px;"' : ''} controls preload="metadata"></video>';
    }
    if (mediaHtml.isNotEmpty) mediaHtml = '<br>' + mediaHtml;
  }

  // KLUCZE: tekst odświeża się zawsze, media tylko gdy zmieni się sygnatura
  final mediaKey = ValueKey(_currentMediaSignature());

  return Stack(
    children: [
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Podgląd pytania', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Tekst pytania ---
                  _html(textHtml),
                  // --- Media (oddzielny subtree) ---
                  if (mediaHtml.isNotEmpty)
                    KeyedSubtree(key: mediaKey, child: _html(mediaHtml)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(4, (i) {
            final labels = ['A', 'B', 'C', 'D'];
            final texts = [_odp1Ctrl.text, _odp2Ctrl.text, _odp3Ctrl.text, _odp4Ctrl.text];
            final label = labels[i];
            final body = _escapeLtGt(texts[i]);
            final html = '<b>$label.</b> $body';
            return Container(
              margin: const EdgeInsets.only(top: 6),
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 240, 240, 240),
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
                child: _html(html),
              ),
            );
          }),
        ],
      ),
      Positioned(
        top: 8,
        right: 8,
        child: IconButton(
          tooltip: 'Zamknij podgląd',
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _showPreview = false),
        ),
      ),
    ],
  );
}

}

