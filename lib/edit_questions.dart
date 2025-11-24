import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/app_themes.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'dart:async';
import 'package:shimmer/shimmer.dart';
import 'utils/admin_video_player.dart';

const _apiKey = 'zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^';

enum MediaKind { none, image, video }

class EditQuestionsPage extends StatefulWidget {
  const EditQuestionsPage({super.key, required this.qualification});
  final String qualification;

  @override
  State<EditQuestionsPage> createState() => _EditQuestionsPageState();
}

class _EditQuestionsPageState extends State<EditQuestionsPage> {
  String _lastPreviewSignature = '';

  String _currentMediaSignature() {
    final kind = _mediaKind.name;
    final imgUrl = (_uploadedImageUrl ?? _imageCtrl.text.trim());
    final imgBytesSig =
        (_imageBytes != null && _imageBytes!.isNotEmpty)
            ? '${_imageName ?? ''}|${_imageBytes!.length}'
            : '';
    final vidUrl = _uploadedVideoUrl ?? '';
    final vidBytesSig =
        (_videoBytes != null && _videoBytes!.isNotEmpty)
            ? '${_videoName ?? ''}|${_videoBytes!.length}'
            : '';
    final height = _imageHeightPx?.toString() ?? '';
    return [kind, imgUrl, imgBytesSig, vidUrl, vidBytesSig, height].join('::');
  }

  String? _tempVideoPath;
  String? _webBlobUrl;
  Timer? _previewDebounce;
  String? _firstMatch(RegExp re, String s, [int group = 1]) {
    final m = re.firstMatch(s);
    return m?.group(group);
  }

  String? _extractFirstImageSrcSmart(String html) {
    // surowy <img ... src="...">
    final raw = _firstMatch(
      RegExp('<img[^>]+src=["\']([^"\']+)["\']', caseSensitive: false),
      html,
    );
    if (raw != null) return raw;

    // escaped: &lt;img ... src=&quot;...&quot;&gt;
    final esc = _firstMatch(
      RegExp('&lt;img[^&]+src=&quot;([^&]+)&quot;', caseSensitive: false),
      html,
    );
    if (esc != null) return esc;

    return null;
  }

  String? _extractFirstVideoSrcSmart(String html) {
    // <video src="...">
    final rawVideo = _firstMatch(
      RegExp('<video[^>]+src=["\']([^"\']+)["\']', caseSensitive: false),
      html,
    );
    if (rawVideo != null) return rawVideo;

    // <video><source src="..."></video>
    final rawSource = _firstMatch(
      RegExp('<source[^>]+src=["\']([^"\']+)["\']', caseSensitive: false),
      html,
    );
    if (rawSource != null) return rawSource;

    // escaped &lt;video ... src=&quot;...&quot;&gt;
    final escVideo = _firstMatch(
      RegExp('&lt;video[^&]+src=&quot;([^&]+)&quot;', caseSensitive: false),
      html,
    );
    if (escVideo != null) return escVideo;

    // escaped &lt;source src=&quot;...&quot;&gt;
    final escSource = _firstMatch(
      RegExp('&lt;source[^&]+src=&quot;([^&]+)&quot;', caseSensitive: false),
      html,
    );
    if (escSource != null) return escSource;

    return null;
  }

  void _refreshTextPreview() {
    if (_showPreview && mounted) setState(() {});
  }

  void _refreshIfPreview({bool immediate = false}) {
    if (!_showPreview) return;
    final newSig = _currentMediaSignature();
    if (newSig == _lastPreviewSignature) return;
    _lastPreviewSignature = newSig;
    if (immediate) {
      if (mounted) setState(() {});
      return;
    }
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (_currentMediaSignature() != _lastPreviewSignature) return;
      setState(() {});
    });
  }

  void _revokeWebBlobUrl() {
    if (kIsWeb && _webBlobUrl != null) {
      try {
        html.Url.revokeObjectUrl(_webBlobUrl!);
      } catch (_) {}
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
        'ogg' => 'video/ogg',
        _ => 'video/mp4',
      };
      final blob = html.Blob([_videoBytes!], mime);
      _webBlobUrl = html.Url.createObjectUrlFromBlob(blob);
      return _webBlobUrl;
    } else {
      final dir = await getTemporaryDirectory();
      final ext = (_videoName?.split('.').last.toLowerCase() ?? 'mp4')
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
      final file = File(
        '${dir.path}/editq_local_preview.${ext.isEmpty ? 'mp4' : ext}',
      );
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

  int? get _nextId {
    final ids =
        questions
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

  int? editingId;
  final TextEditingController _imageCtrl = TextEditingController();
  final TextEditingController _contentCtrl = TextEditingController();
  final TextEditingController _odp1Ctrl = TextEditingController();
  final TextEditingController _odp2Ctrl = TextEditingController();
  final TextEditingController _odp3Ctrl = TextEditingController();
  final TextEditingController _odp4Ctrl = TextEditingController();
  final TextEditingController _imageHeightCtrl = TextEditingController();
  int? _imageHeightPx;
  final TextEditingController _opisPoprawneCtrl = TextEditingController();
  final TextEditingController _opisNiepoprawneCtrl = TextEditingController();
  String _correct = 'A';

  MediaKind _mediaKind = MediaKind.none;
  Uint8List? _imageBytes;
  String? _imageName;
  String? _uploadedImageUrl;
  String? _uploadedImageFilename;
  Uint8List? _videoBytes;
  String? _videoName;
  String? _uploadedVideoUrl;
  String? _uploadedVideoFilename;

  bool _isUploading = false;
  bool _showPreview = false;

  late final VoidCallback _scrollListener;

  @override
  void initState() {
    super.initState();
    _loadAll();

    _scrollListener = () {
      if (_listController.position.pixels >=
              _listController.position.maxScrollExtent - 300 &&
          !_isLoadingMore &&
          _displayCount < questions.length) {
        setState(() {
          _isLoadingMore = true;
        });

        if (mounted) {
          setState(() {
            _displayCount = (_displayCount + 20).clamp(0, questions.length);
            _isLoadingMore = false;
          });
        }
      }
    };

    _listController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _listController.removeListener(_scrollListener);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Błąd ładowania: $e')));
      }
    }
  }

  String _sanitizedTable() =>
      widget.qualification
          .replaceAll('.', '')
          .replaceAll(' ', '')
          .toLowerCase();

  Future<List<dynamic>> _fetchQuestions(String kval) async {
    final url = Uri.parse('https://egzaminy.zsel.edu.pl/egzaminy/$kval.php');
    final res = await http.get(url);
    if (res.statusCode == 200 && res.body.isNotEmpty) {
      final decoded = json.decode(res.body);
      if (decoded is List) return decoded;
      throw 'Nieprawidłowy format danych pytań';
    }
    throw 'HTTP ${res.statusCode} przy pobieraniu pytań';
  }

  Future<Map<int, Map<String, dynamic>>> _fetchAllTrudnosci() async {
    final url = Uri.parse(
      'https://egzaminy.zsel.edu.pl/egzaminy/wyswietl_trudnosci.php',
    );

    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode != 200) return {};
    final String kval = _sanitizedTable();
    final List<dynamic> jsonList = json.decode(res.body);
    final Map<int, Map<String, dynamic>> result = {};

    for (final item in jsonList) {
      final String itemKval =
          (item['kwalifikacja'] ?? '')
              .toString()
              .replaceAll(' ', '')
              .toLowerCase();
      if (itemKval != kval) continue;
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
  }

  void _applyTextFilter(String value) {
    setState(() => searchText = value.trim());
  }

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
      _imageBytes = null;
      _imageName = null;
      _uploadedImageUrl = null;
      _uploadedImageFilename = null;
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

  void _openForEdit(Map<String, dynamic> q) {
    setState(() {
      editingId = int.tryParse(q['id']?.toString() ?? '');

      final rawHtml = q['pytanie']?.toString() ?? '';
      final unescapedHtml = _unescapeLtGt(rawHtml);

      // 1) Spróbuj z tablic w JSON (jeśli są)
      String? vidUrl =
          (q['videos'] is List && (q['videos'] as List).isNotEmpty)
              ? q['videos'][0]?.toString()
              : null;
      String? imgUrl =
          (q['images'] is List && (q['images'] as List).isNotEmpty)
              ? q['images'][0]?.toString()
              : null;

      // 2) Jeśli brak w tablicach – spróbuj z HTML
      vidUrl ??= _extractFirstVideoSrcSmart(unescapedHtml);
      imgUrl ??= _extractFirstImageSrcSmart(unescapedHtml);

      // 3) Ustaw multimedia i wyczyść przeciwne bufory
      if (vidUrl != null && vidUrl.isNotEmpty) {
        _mediaKind = MediaKind.video;

        _uploadedVideoUrl = vidUrl;
        _uploadedVideoFilename = _filenameFromUrl(vidUrl);

        // wyczyść obraz
        _imageBytes = null;
        _imageName = null;
        _uploadedImageUrl = null;
        _uploadedImageFilename = null;
        _imageCtrl.clear();
      } else if (imgUrl != null && imgUrl.isNotEmpty) {
        _mediaKind = MediaKind.image;

        _uploadedImageUrl = imgUrl;
        _uploadedImageFilename = _filenameFromUrl(imgUrl);
        _imageCtrl.text = imgUrl;

        // wyczyść wideo
        _videoBytes = null;
        _videoName = null;
        _uploadedVideoUrl = null;
        _uploadedVideoFilename = null;
        _disposeLocalTempVideo();
      } else {
        _mediaKind = MediaKind.none;

        // wyczyść oba
        _imageBytes = null;
        _imageName = null;
        _uploadedImageUrl = null;
        _uploadedImageFilename = null;
        _imageCtrl.clear();

        _videoBytes = null;
        _videoName = null;
        _uploadedVideoUrl = null;
        _uploadedVideoFilename = null;
        _disposeLocalTempVideo();
      }

      // 4) Wysokość (parsujemy na unescapowanym HTML)
      _imageHeightPx = null;
      _imageHeightCtrl.clear();

      // 5) Reszta pól
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
    final styleRe = RegExp(
      r'''style\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    );
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

  /*String? _extractFirstTagSrc(String html, String tagName) {
    final idx = html.toLowerCase().indexOf('<$tagName');
    if (idx == -1) return null;
    final srcIdx = html.indexOf('src=', idx);
    if (srcIdx == -1) return null;
    final quote =
        html.contains('src="') ? '"' : (html.contains("src='") ? "'" : '"');
    final qIdx = html.indexOf('src=$quote', idx);
    if (qIdx == -1) return null;
    final start = qIdx + 5;
    final end = html.indexOf(quote, start);
    if (end == -1) return null;
    return html.substring(start, end);
  }*/

  String _stripStyleAndImage(String html) {
    var out = html;
    out = out.replaceAll(
      RegExp(r'<style\b[^>]*>.*?</style>', caseSensitive: false, dotAll: true),
      '',
    );
    out = out.replaceAll(
      RegExp(
        r'&lt;style\b[^&]*&gt;.*?&lt;/style&gt;',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );
    out = out.replaceAll(
      RegExp(
        r'<img[^>]+src="https://interpage\.pl/egzaminy/[^/]+/obrazy/image\d+\.jpg"[^>]*\/?>',
        caseSensitive: false,
      ),
      '',
    );
    out = out.replaceAll(
      RegExp(
        r'&lt;img[^&]+src=&quot;https://interpage\.pl/egzaminy/[^/]+/obrazy/image\d+\.jpg&quot;[^&]*&gt;',
        caseSensitive: false,
      ),
      '',
    );
    out = out.replaceAll(
      RegExp(
        r'<video[^>]+src="https://interpage\.pl/egzaminy/[^/]+/filmy/video\d+\.mp4"[^>]*>.*?</video>',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );
    out = out.replaceAll(
      RegExp(
        r'&lt;video[^&]+src=&quot;https://interpage\.pl/egzaminy/[^/]+/filmy/video\d+\.mp4&quot;[^&]*&gt;.*?&lt;/video&gt;',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );
    out = out.replaceAll(
      RegExp(r'(<br\s*\/?>|\s|&nbsp;)+$', caseSensitive: false),
      '',
    );
    out = out.replaceAll(
      RegExp(r'^(<br\s*\/?>|\s|&nbsp;)+', caseSensitive: false),
      '',
    );
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    return out;
  }

  String _unescapeLtGt(String s) =>
      s.replaceAll('&lt;', '<').replaceAll('&gt;', '>');
  String _answerToUi(String? raw) =>
      (raw ?? '').replaceFirst(RegExp(r'^[A-D]\.\s*'), '');
  String? _filenameFromUrl(String url) {
    try {
      final segs = Uri.parse(url).pathSegments;
      return segs.isNotEmpty ? segs.last : null;
    } catch (_) {
      return null;
    }
  }

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nie udało się otworzyć selektora plików: $e'),
          ),
        );
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_imageBytes == null || _imageName == null) return;
    setState(() => _isUploading = true);
    _refreshIfPreview(immediate: true);
    try {
      final uri = Uri.parse(
        'https://egzaminy.zsel.edu.pl/egzaminy/upload_image_next.php',
      );
      String ext = (_imageName ?? 'jpg').split('.').last.toLowerCase();
      if (ext.isEmpty) ext = 'jpg';
      final mediaType = http_parser.MediaType(
        'image',
        ext == 'jpg' ? 'jpeg' : ext,
      );
      final req =
          http.MultipartRequest('POST', uri)
            ..headers['Authorization'] = 'Bearer $_apiKey'
            ..headers['X-API-Key'] = _apiKey
            ..headers['Accept'] = 'application/json'
            ..fields['kwalifikacja'] = _sanitizedTable()
            ..fields['egzamin'] = _sanitizedTable()
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                _imageBytes!,
                filename: _imageName ?? 'upload.$ext',
                contentType: mediaType,
              ),
            );
      final res = await http.Response.fromStream(await req.send());
      if (res.statusCode != 200) {
        throw 'Upload HTTP ${res.statusCode}: ${res.body}';
      }
      final data = jsonDecode(res.body);
      if (data['ok'] != true || data['url'] == null) {
        throw 'Upload error: ${data['error'] ?? 'brak szczegółów'}';
      }
      setState(() {
        _uploadedImageUrl = data['url'] as String;
        _uploadedImageFilename =
            (data['filename'] as String?) ??
            _filenameFromUrl(_uploadedImageUrl!);
        _mediaKind = MediaKind.image;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd podczas wysyłania obrazka: $e')),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Brak obrazka do podglądu.')));
  }

  void _showImageDialogUrl(String imageUrl) {
    _showImageDialogBody(
      context,
      builder:
          (screen) => Image.network(
            imageUrl,
            height: _imageHeightPx?.toDouble(),
            fit: BoxFit.contain,
          ),
    );
  }

  void _showImageDialogBytes(Uint8List bytes) {
    _showImageDialogBody(
      context,
      builder:
          (screen) => Image.memory(
            bytes,
            height: _imageHeightPx?.toDouble(),
            fit: BoxFit.contain,
          ),
    );
  }

  void _showImageDialogBody(
    BuildContext context, {
    required Widget Function(Size screen) builder,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
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
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.9),
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
                        icon: Icon(
                          Icons.close,
                          size: 30,
                          color: colorScheme.surface,
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
        SnackBar(content: Text('Nie udało się otworzyć pliku wideo: $e')),
      );
    }
  }

  Future<void> _uploadVideo() async {
    if (_videoBytes == null || _videoName == null) return;
    setState(() => _isUploading = true);
    try {
      final uri = Uri.parse('https://egzaminy.zsel.edu.pl/egzaminy/upload_video.php');
      final ext = _videoName!.split('.').last.toLowerCase();
      final mt = switch (ext) {
        'webm' => http_parser.MediaType('video', 'webm'),
        'ogg' => http_parser.MediaType('video', 'ogg'),
        _ => http_parser.MediaType('video', 'mp4'),
      };
      final req =
          http.MultipartRequest('POST', uri)
            ..headers['Authorization'] = 'Bearer $_apiKey'
            ..headers['X-API-Key'] = _apiKey
            ..headers['Accept'] = 'application/json'
            ..fields['kwalifikacja'] = _sanitizedTable()
            ..fields['egzamin'] = _sanitizedTable()
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                _videoBytes!,
                filename: _videoName!,
                contentType: mt,
              ),
            );
      final res = await http.Response.fromStream(await req.send());
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}: ${res.body}';
      final data = jsonDecode(res.body);
      if (data['ok'] != true || data['url'] == null) {
        throw 'Upload error: ${data['error'] ?? 'brak szczegółów'}';
      }
      setState(() {
        _uploadedVideoUrl = data['url'] as String;
        _uploadedVideoFilename =
            (data['filename'] as String?) ??
            _filenameFromUrl(_uploadedVideoUrl!);
        _mediaKind = MediaKind.video;
      });
      _refreshIfPreview(immediate: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd podczas wysyłania filmu: $e')),
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
    const double h = 400;
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
                  Text(
                    'URL: ${_uploadedVideoUrl!}',
                    style: const TextStyle(fontSize: 12),
                  ),
                const SizedBox(height: 8),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: InlineVideoPlayer(
                    url: _uploadedVideoUrl,
                    filePath: kIsWeb ? null : localPathOrBlob,
                    blobUrl: kIsWeb ? localPathOrBlob : null,
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
      _imageBytes = null;
      _imageName = null;
      _uploadedImageUrl = null;
      _uploadedImageFilename = null;
      _imageCtrl.clear();
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

  Future<void> _saveQuestion() async {
    final pyt = _contentCtrl.text.trim();
    final a = _odp1Ctrl.text.trim();
    final b = _odp2Ctrl.text.trim();
    final c = _odp3Ctrl.text.trim();
    final d = _odp4Ctrl.text.trim();
    if (pyt.isEmpty || a.isEmpty || b.isEmpty || c.isEmpty || d.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uzupełnij treść i wszystkie odpowiedzi.'),
        ),
      );
      return;
    }
    if (_mediaKind == MediaKind.image &&
        _uploadedImageUrl == null &&
        _imageBytes != null &&
        _imageBytes!.isNotEmpty) {
      await _uploadImage();
      if (_uploadedImageUrl == null) return;
    }
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
        payload['video_height'] = _imageHeightPx;
      }
    }
    try {
      final res = await http.post(
        Uri.parse('https://egzaminy.zsel.edu.pl/egzaminy/add_question.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $_apiKey',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}: ${res.body}';
      final body = jsonDecode(res.body);
      if (body is! Map || body['ok'] != true) {
        throw body['error'] ?? 'Nieznany błąd serwera';
      }
      final isEdit = editingId != null;
      final int? savedId =
          (body['id'] is int)
              ? body['id'] as int
              : int.tryParse('${body['id']}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Pytanie zaktualizowane (ID ${savedId ?? editingId})'
                : 'Pytanie dodane (ID ${savedId ?? '—'})',
          ),
        ),
      );
      setState(() => _showPreview = false);
      _startNewQuestion();
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd zapisu: $e')));
    }
  }

  Future<void> _deleteQuestion(int id) async {
    try {
      final res = await http.post(
        Uri.parse('https://egzaminy.zsel.edu.pl/egzaminy/delete_question.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          'X-API-Key': _apiKey,
        },
        body: jsonEncode({'egzamin': _sanitizedTable(), 'id': id}),
      );
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}: ${res.body}';
      final body = jsonDecode(res.body);
      if (body['ok'] != true) throw body['error'] ?? 'Błąd usuwania';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pytanie zostało usunięte.')),
        );
      }
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd podczas usuwania pytania: $e')),
        );
      }
    }
  }

  bool _busyResetAll = false;

  Future<void> _resetTrudnoscAll() async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Resetować trudności wszystkich pytań?'),
                content: const Text(
                  'Ta operacja wyczyści statystyki trudności dla całej kwalifikacji.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Anuluj'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Resetuj'),
                  ),
                ],
              ),
        ) ??
        false;
    if (!ok) return;
    setState(() => _busyResetAll = true);
    try {
      final res = await http.post(
        Uri.parse('https://egzaminy.zsel.edu.pl/egzaminy/reset_trudnosc.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
          'Authorization': 'Bearer $_apiKey',
        },
        body: {'kwalifikacja': _sanitizedTable()},
      );
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}: ${res.body}';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Zresetowano trudności dla wszystkich pytań'),
          ),
        );
      }
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Błąd resetu: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyResetAll = false);
    }
  }

  Future<void> _resetTrudnoscOne(int id) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: Text('Resetować trudność pytania ID $id?'),
                content: const Text(
                  'Wyzeruje statystyki dla tego jednego pytania.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Anuluj'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Resetuj'),
                  ),
                ],
              ),
        ) ??
        false;
    if (!ok) return;
    try {
      final res = await http.post(
        Uri.parse('https://egzaminy.zsel.edu.pl/egzaminy/reset_trudnosc.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
          'Authorization': 'Bearer $_apiKey',
        },
        body: {'kwalifikacja': _sanitizedTable(), 'pytanie_id': '$id'},
      );
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}: ${res.body}';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Zresetowano trudność pytania ID $id')),
        );
      }
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Błąd resetu pytania $id: $e')));
      }
    }
  }

  Widget _buildRightToolbar(BuildContext context) {
    final found = _filteredQuestions.length;
    final total = questions.length;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.surface,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Icon(Icons.filter_alt, size: 20, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Wyniki: $found / $total',
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (searchText.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  _textSearchCtrl.clear();
                  _applyTextFilter('');
                },
                icon: const Icon(Icons.clear),
                label: const Text('Wyczyść filtr'),
              ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _busyResetAll ? null : _resetTrudnoscAll,
              icon:
                  _busyResetAll
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.refresh),
              label: const Text('Resetuj trudności (wszystkie)'),
            ),
          ],
        ),
      ),
    );
  }

  int _displayCount = 20;
  bool _isLoadingMore = false;

    Widget _renderHtml(
    String text, {
    List<String>? images,
    List<String>? videos,
  }) {
    const double minImageHeight = 100;
    const double maxImageHeight = 500;
    const double videoHeight = 400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: const TextStyle(fontSize: 16)),
        ...?images?.map(
          (url) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: minImageHeight,
                  maxHeight: maxImageHeight,
                ),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        ...?videos?.map(
          (url) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: InlineVideoPlayer(
                url: url,
                height: videoHeight,
              ),
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildBadge(BuildContext context, dynamic q) {
    final theme = Theme.of(context);
    final extras = theme.extension<ExtraColors>()!;
    final colorScheme = theme.colorScheme;
    final trudnosc = q['trudnosc'];
    final iloscOdp = int.tryParse(q['ilosc_odpowiedzi']?.toString() ?? '') ?? 0;
    if (trudnosc == null || iloscOdp < 5) return const SizedBox.shrink();
    final diff =
        (trudnosc is num ? trudnosc : int.tryParse(trudnosc.toString()) ?? 0)
            .toInt();
    final isTrudne = diff > 50;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isTrudne ? extras.incorrect : extras.correct,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isTrudne ? 'TRUDNE' : 'ŁATWE',
        style: TextStyle(
          color: colorScheme.onPrimary,
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
      return idStr.contains(q) ||
          txt.contains(q) ||
          a.contains(q) ||
          b.contains(q) ||
          c.contains(q) ||
          d.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final leftPanel = _buildLeftPanel(context);
    final rightList =
        isLoading
            ? const Center(child: CircularProgressIndicator())
            : (_showPreview
                ? _buildLivePreview(context)
                : Column(
                  children: [
                    _buildRightToolbar(context),
                    const Divider(height: 1),
                    Expanded(child: _buildList()),
                  ],
                ));
    return Scaffold(
      appBar: AppBar(
        title: Text('Edytor pytań — ${widget.qualification.toUpperCase()}'),
        backgroundColor: colorScheme.primary,
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
          Container(width: 1, color: theme.dividerColor),
          Expanded(child: rightList),
        ],
      ),
    );
  }

  Widget _buildLeftPanel(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = TextStyle(
      fontWeight: FontWeight.w600,
      color: colorScheme.onPrimary,
    );
    return Container(
      color: colorScheme.surface,
      child: Scrollbar(
        controller: _leftPanelScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _leftPanelScroll,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Wyszukaj', style: labelStyle),
              const SizedBox(height: 8),
              TextField(
                controller: _textSearchCtrl,
                decoration: InputDecoration(
                  labelText: 'Szukaj w treści/odpowiedziach/ID',
                  prefixIcon: Icon(Icons.search, color: colorScheme.onPrimary),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: colorScheme.primary),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: colorScheme.secondary,
                      width: 2.0,
                    ),
                  ),
                  isDense: true,
                ),
                onChanged: _applyTextFilter,
              ),
              const SizedBox(height: 16),
              Divider(color: theme.dividerColor, height: 1),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    editingId == null
                        ? 'Dodaj nowe pytanie${_nextId != null ? ' (ID $_nextId)' : ''}'
                        : 'Edytujesz ID $editingId',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimary,
                    ),
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
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.secondary),
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
                          selectedColor: colorScheme.primary,
                          side: BorderSide(
                            color: colorScheme.onPrimary,
                            width: 1,
                          ),
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
                          selectedColor: colorScheme.primary,
                          label: const Text('Obrazek'),
                          selected: _mediaKind == MediaKind.image,
                          side: BorderSide(
                            color: colorScheme.onPrimary,
                            width: 1,
                          ),
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
                          selectedColor: colorScheme.primary,
                          label: const Text('Film'),
                          selected: _mediaKind == MediaKind.video,
                          side: BorderSide(
                            color: colorScheme.onPrimary,
                            width: 1,
                          ),
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
                      //const SizedBox(height: 8),
                      //_heightFieldRow(),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
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
                      ),
                    ] else if (_mediaKind == MediaKind.video) ...[
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
                        spacing: 8,
                        runSpacing: 8,
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
                      ),
                    ] else
                      const Text('Nie dodajesz multimediów do pytania.'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contentCtrl,
                onChanged: (_) => _refreshTextPreview(),
                decoration: InputDecoration(
                  labelText: 'Treść pytania',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: colorScheme.primary),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: colorScheme.secondary,
                      width: 2.0,
                    ),
                  ),
                ),
                maxLines: 8,
                minLines: 8,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _opisPoprawneCtrl,
                onChanged: (_) => _refreshTextPreview(),
                decoration: InputDecoration(
                  labelText: 'Opis (dla poprawnej odpowiedzi) - opcjonalnie',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: colorScheme.primary),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: colorScheme.secondary,
                      width: 2.0,
                    ),
                  ),
                ),
                maxLines: 4,
                minLines: 3,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _opisNiepoprawneCtrl,
                onChanged: (_) => _refreshTextPreview(),
                decoration: InputDecoration(
                  labelText: 'Opis (dla niepoprawnej odpowiedzi) - opcjonalnie',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: colorScheme.primary),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: colorScheme.secondary,
                      width: 2.0,
                    ),
                  ),
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
                    decoration: InputDecoration(
                      labelText: 'Odpowiedź A',
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: colorScheme.primary),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: colorScheme.secondary,
                          width: 2.0,
                        ),
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _odp2Ctrl,
                    onChanged: (_) => _refreshTextPreview(),
                    decoration: InputDecoration(
                      labelText: 'Odpowiedź B',
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: colorScheme.primary),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: colorScheme.secondary,
                          width: 2.0,
                        ),
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _odp3Ctrl,
                    onChanged: (_) => _refreshTextPreview(),
                    decoration: InputDecoration(
                      labelText: 'Odpowiedź C',
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: colorScheme.primary),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: colorScheme.secondary,
                          width: 2.0,
                        ),
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _odp4Ctrl,
                    onChanged: (_) => _refreshTextPreview(),
                    decoration: InputDecoration(
                      labelText: 'Odpowiedź D',
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: colorScheme.primary),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: colorScheme.secondary,
                          width: 2.0,
                        ),
                      ),
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
                    focusColor: colorScheme.primary,
                    dropdownColor: colorScheme.surface,
                    underline: Container(height: 1, color: colorScheme.primary),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _showPreview = true),
                        icon: const Icon(Icons.visibility),
                        label: const Text('Zobacz podgląd'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _saveQuestion,
                        icon: const Icon(Icons.save),
                        label: const Text('Zapisz'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /*Widget _heightFieldRow() {
    if (_uploadedImageUrl != null || _imageBytes != null) {
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
                setState(
                  () => _imageHeightPx = (n == null || n <= 0) ? null : n,
                );
                _refreshIfPreview(immediate: true);
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      );
    } else {
      return Row();
    }
  }
*/
  Widget _buildList() {
    final items = _filteredQuestions;
    final int displayCount = _displayCount.clamp(0, items.length);

    return ListView.builder(
      controller: _listController,
      padding: const EdgeInsets.all(16),
      itemCount: displayCount + (_isLoadingMore ? 3 : 0),
      itemBuilder: (context, index) {
        if (index >= displayCount) {
          return _buildShimmerCard(context);
        }
        final q = items[index] as Map<String, dynamic>;
        return _buildQuestionCard(context, q);
      },
    );
  }

Widget _buildQuestionCard(BuildContext context, Map<String, dynamic> q) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final extras = theme.extension<ExtraColors>()!;
  final id = int.tryParse(q['id']?.toString() ?? '');
  final poprawna = (q['poprawna']?.toString().toUpperCase() ?? 'A');

  // domyślny kolor czcionki dla niepoprawnych odpowiedzi
  final defaultTextColor =
      theme.brightness == Brightness.light ? Colors.black : Colors.white;

  final answers = ['A', 'B', 'C', 'D'].asMap().entries.map((e) {
    final letter = e.value; // A/B/C/D
    final isCorrect = letter == poprawna;

    final odp = q['odp${e.key + 1}']?.toString() ?? '';
    final body = _unescapeLtGt(
      odp.replaceFirst(RegExp(r'^[A-D]\.\s*'), ''),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: IgnorePointer(
        ignoring: true, // wygląd przycisku, ale bez klikalności
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            // tło
            backgroundColor:
                isCorrect ? extras.correct : colorScheme.surface,
            // kolor czcionki
            foregroundColor:
                isCorrect ? Colors.black : defaultTextColor,
            // bez obramowania
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
            padding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
            alignment: Alignment.centerLeft,
            minimumSize: const Size(double.infinity, 48),
          ),
          child: _renderHtml('$letter. $body'),
        ),
      ),
    );
  }).toList();

  return Card(
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Pytanie (ID: $id)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const Spacer(),
              _buildBadge(context, q),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _renderHtml(
                  q['pytanie']?.toString() ?? '',
                  images: (q['images'] as List?)?.cast<String>(),
                  videos: (q['videos'] as List?)?.cast<String>(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...answers,
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _openForEdit(q),
                icon: Icon(Icons.edit, color: colorScheme.primary),
                label: const Text('Edytuj'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: id == null ? null : () => _resetTrudnoscOne(id),
                icon: Icon(Icons.restart_alt, color: colorScheme.primary),
                label: const Text('Restartuj trudność'),
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
                                  'Na pewno chcesz usunąć pytanie ID $id?',
                                ),
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
                        if (ok) await _deleteQuestion(id);
                      },
                icon: Icon(Icons.delete_outline, color: colorScheme.primary),
                label: const Text('Usuń'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildLivePreview(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final extras = theme.extension<ExtraColors>()!;

  // domyślny kolor czcionki dla niepoprawnych odpowiedzi
  final defaultTextColor =
      theme.brightness == Brightness.light ? Colors.black : Colors.white;

    Widget? mediaWidget;
  if (_mediaKind == MediaKind.image) {
    String? imgSrc;
    if (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty) {
      imgSrc = _uploadedImageUrl!;
    } else if (_imageCtrl.text.trim().isNotEmpty) {
      imgSrc = _imageCtrl.text.trim();
    } else if (_imageBytes != null && _imageBytes!.isNotEmpty) {
      final ext = (_imageName ?? 'png').split('.').last.toLowerCase();
      final mime = ext == 'jpg' ? 'jpeg' : ext;
      imgSrc = 'data:image/$mime;base64,${base64Encode(_imageBytes!)}';
    }

    if (imgSrc != null) {
      mediaWidget = Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 100,
              maxHeight: 500,
            ),
            child: Image.network(
              imgSrc,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }
  } else if (_mediaKind == MediaKind.video && _uploadedVideoUrl != null) {
    mediaWidget = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: InlineVideoPlayer(
        url: _uploadedVideoUrl!,
        height: 400,
      ),
    );
  }


  final answers = ['A', 'B', 'C', 'D'].asMap().entries.map((e) {
    final letter = e.value;
    final isCorrect = letter == _correct;

    final textCtrl = [_odp1Ctrl, _odp2Ctrl, _odp3Ctrl, _odp4Ctrl][e.key];
    final body = textCtrl.text.trim();

    return Container(
      margin: const EdgeInsets.only(top: 6),
      child: IgnorePointer(
        ignoring: true,
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isCorrect ? extras.correct : colorScheme.surface,
            foregroundColor:
                isCorrect ? Colors.black : defaultTextColor,
            alignment: Alignment.centerLeft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 2,
            padding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
          ),
          child: _renderHtml('$letter. $body'),
        ),
      ),
    );
  }).toList();

  return Stack(
    children: [
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Podgląd pytania', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _renderHtml(_contentCtrl.text.trim()),
                  if (mediaWidget != null) mediaWidget,
                  ...answers,
                  if (_opisPoprawneCtrl.text.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _renderHtml(_opisPoprawneCtrl.text.trim()),
                    ),
                  if (_opisNiepoprawneCtrl.text.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _renderHtml(_opisNiepoprawneCtrl.text.trim()),
                    ),
                ],
              ),
            ),
          ),
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

Widget _buildShimmerCard(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  final extras = Theme.of(context).extension<ExtraColors>()!;
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Shimmer.fromColors(
        baseColor: extras.shimmerBase,
        highlightColor: extras.shimmerHighlight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 24, width: 180, color: colorScheme.surface),
            const SizedBox(height: 12),
            Container(height: 60, color: colorScheme.surface),
            const SizedBox(height: 16),
            Container(height: 200, color: colorScheme.surface),
            const SizedBox(height: 16),
            ...List.generate(
              4,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(height: 48, color: extras.shimmerHighlight),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
