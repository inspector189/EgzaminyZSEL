import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:html_unescape_xx/html_unescape.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:universal_html/html.dart' as html;

import '/services/api_service.dart';
import '/utils/async_state_view.dart';
import '/utils/app_themes.dart';
import '/utils/helpers.dart';
import '/widgets/difficulty_badge.dart';
import '/widgets/exam_question_card.dart';
import '/widgets/shim_box.dart';

// ─────────────────────────────────────────────
//                    Enums
// ─────────────────────────────────────────────

enum MediaKind { none, image, video }

enum AnswerKind { text, image }

// ─────────────────────────────────────────────
//               AnswerState model
// ─────────────────────────────────────────────

class AnswerState {
  AnswerKind kind;
  final TextEditingController ctrl;

  Uint8List? imageBytes;
  String? imageName;
  String? uploadedImageUrl;
  String? uploadedImageFilename;

  AnswerState({this.kind = AnswerKind.text}) : ctrl = TextEditingController();

  bool get hasImage => imageBytes != null || uploadedImageUrl != null;
  String get fileLabel => uploadedImageUrl ?? imageName ?? '';

  void clearImage() {
    imageBytes = null;
    imageName = null;
    uploadedImageUrl = null;
    uploadedImageFilename = null;
  }

  void reset() {
    kind = AnswerKind.text;
    ctrl.clear();
    clearImage();
  }

  void dispose() => ctrl.dispose();
}

// ─────────────────────────────────────────────
//                    Widget
// ─────────────────────────────────────────────

class EditQuestionsPage extends StatefulWidget {
  const EditQuestionsPage({super.key, required this.qualification});
  final String qualification;

  @override
  State<EditQuestionsPage> createState() => _EditQuestionsPageState();
}

class _EditQuestionsPageState extends State<EditQuestionsPage> {
  late final String _kval = widget.qualification
      .replaceAll('.', '')
      .replaceAll(' ', '')
      .toLowerCase();

  final _unescape = HtmlUnescapeSmall();
  String _clean(String? s) => _unescape.convert(s?.toString() ?? '');
  String _unescapeLtGt(String s) =>
      s.replaceAll('&lt;', '<').replaceAll('&gt;', '>');
  String _answerToUi(String? raw) =>
      (raw ?? '').replaceFirst(RegExp(r'^[A-D]\.\s*'), '');

  String? _filenameFromUrl(String url) {
    try {
      final segs = Uri.parse(url).pathSegments;
      if (segs.isEmpty) return null;
      final filename = segs.last;
      if (filename.isEmpty) {
        if (kDebugMode) print('_filenameFromUrl: empty filename for $url');
        return null;
      }
      return filename;
    } catch (e) {
      if (kDebugMode) print('_filenameFromUrl error for "$url": $e');
      return null;
    }
  }

  String? _firstMatch(RegExp re, String s, [int group = 1]) =>
      re.firstMatch(s)?.group(group);

  String? _extractFirstImageSrcSmart(String rawHtml) =>
      _firstMatch(
        RegExp('<img[^>]+src=["\']([^"\']+)["\']', caseSensitive: false),
        rawHtml,
      ) ??
      _firstMatch(
        RegExp('&lt;img[^&]+src=&quot;([^&]+)&quot;', caseSensitive: false),
        rawHtml,
      );

  String? _extractFirstVideoSrcSmart(String rawHtml) =>
      _firstMatch(
        RegExp('<video[^>]+src=["\']([^"\']+)["\']', caseSensitive: false),
        rawHtml,
      ) ??
      _firstMatch(
        RegExp('<source[^>]+src=["\']([^"\']+)["\']', caseSensitive: false),
        rawHtml,
      ) ??
      _firstMatch(
        RegExp('&lt;video[^&]+src=&quot;([^&]+)&quot;', caseSensitive: false),
        rawHtml,
      ) ??
      _firstMatch(
        RegExp('&lt;source[^&]+src=&quot;([^&]+)&quot;', caseSensitive: false),
        rawHtml,
      );

  String _stripAnswerPrefix(String text) =>
      text.replaceFirst(RegExp(r'^\s*[A-Da-d][.)]\s*'), '').trimLeft();

  bool isLoading = true;
  List<dynamic> questions = [];
  int _displayCount = 20;
  String searchText = '';

  int? editingId;
  String _correct = 'A';
  bool _isUploading = false;
  bool _showPreview = false;

  MediaKind _mediaKind = MediaKind.none;
  final List<String> _questionImageFilenames = [];

  Uint8List? _imageBytes;
  String? _imageName;
  String? _uploadedImageUrl;
  String? _uploadedImageFilename;

  Uint8List? _videoBytes;
  String? _videoName;
  String? _uploadedVideoUrl;
  String? _uploadedVideoFilename;

  int? _imageHeightPx;

  late final List<AnswerState> _answers = List.generate(
    4,
    (_) => AnswerState(),
  );

  final TextEditingController _contentCtrl = TextEditingController();
  final TextEditingController _opisPoprawneCtrl = TextEditingController();
  final TextEditingController _opisNiepoprawneCtrl = TextEditingController();
  final TextEditingController _textSearchCtrl = TextEditingController();
  final ScrollController _listController = ScrollController();
  final ScrollController _leftPanelScroll = ScrollController();

  String _lastPreviewSignature = '';
  Timer? _previewDebounce;

  String _currentMediaSignature() => [
    _mediaKind.name,
    _questionImageFilenames.join('|'),
    (_imageBytes?.isNotEmpty ?? false)
        ? '${_imageName ?? ''}|${_imageBytes!.length}'
        : '',
    _uploadedVideoUrl ?? '',
    (_videoBytes?.isNotEmpty ?? false)
        ? '${_videoName ?? ''}|${_videoBytes!.length}'
        : '',
    _imageHeightPx?.toString() ?? '',
  ].join('::');

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
      if (mounted) setState(() {});
    });
  }

  String? _tempVideoPath;
  String? _webBlobUrl;

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
      final ext = _videoName?.split('.').last.toLowerCase() ?? 'mp4';
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
            .whereType<int>()
            .toList()
          ..sort();
    return ids.isEmpty ? 1 : ids.last + 1;
  }

  List<dynamic>? _cachedFiltered;
  String? _cachedSearchText;

  List<dynamic> get _filteredQuestions {
    if (_cachedSearchText == searchText && _cachedFiltered != null) {
      return _cachedFiltered!;
    }
    _cachedSearchText = searchText;
    if (searchText.isEmpty) return _cachedFiltered = questions;
    final q = searchText.toLowerCase();
    return _cachedFiltered = questions.where((e) {
      return (e['id']?.toString() ?? '').toLowerCase().contains(q) ||
          (e['pytanie']?.toString() ?? '').toLowerCase().contains(q) ||
          (e['odp1']?.toString() ?? '').toLowerCase().contains(q) ||
          (e['odp2']?.toString() ?? '').toLowerCase().contains(q) ||
          (e['odp3']?.toString() ?? '').toLowerCase().contains(q) ||
          (e['odp4']?.toString() ?? '').toLowerCase().contains(q);
    }).toList();
  }

  // ─────────────────────────────────────────
  //                Lifecycle
  // ─────────────────────────────────────────

  late final VoidCallback _scrollListener;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _scrollListener = () {
      final pos = _listController.position;
      if (pos.pixels >= pos.maxScrollExtent - 300 &&
          _displayCount < questions.length) {
        setState(() {
          _displayCount = (_displayCount + 20).clamp(0, questions.length);
        });
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
    _contentCtrl.dispose();
    _opisPoprawneCtrl.dispose();
    _opisNiepoprawneCtrl.dispose();
    for (final a in _answers) {
      a.dispose();
    }
    _disposeLocalTempVideo();
    super.dispose();
  }

  // ─────────────────────────────────────────
  //               Data loading
  // ─────────────────────────────────────────

  Future<void> _loadAll() async {
    setState(() => isLoading = true);
    try {
      final qs = await _fetchQuestions();
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
      if (mounted) {
        setState(() {
          questions = qs;
          _displayCount = 20;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Błąd ładowania: $e')));
      }
    }
  }

  Future<List<dynamic>> _fetchQuestions() async {
    final result = await ApiService.instance.fetchQuestions(_kval);
    if (result.isSuccess) {
      final decoded = result.data!;
      for (final q in decoded) {
        if (q['pytanie'] is String) {
          q['pytanie'] = q['pytanie'].toString().replaceAll(
            RegExp('<img[^>]*>', caseSensitive: false),
            '',
          );
        }
      }
      return decoded;
    }
    throw 'HTTP ${result.statusCode} przy pobieraniu pytań';
  }

  Future<Map<int, Map<String, dynamic>>> _fetchAllTrudnosci() async {
    final res = await ApiService.instance.fetchDifficultyStats();
    if (!res.isSuccess) return {};
    final Map<int, Map<String, dynamic>> result = {};
    for (final item in res.data!) {
      final String itemKval = (item['kwalifikacja'] ?? '')
          .toString()
          .replaceAll(' ', '')
          .toLowerCase();
      if (itemKval != _kval) continue;
      final int? id = int.tryParse('${item['pytanie_id']}');
      if (id == null) continue;
      final double trud = (item['trudnosc'] is num)
          ? (item['trudnosc'] as num).toDouble()
          : double.tryParse('${item['trudnosc']}') ?? 0.0;
      final int ilosc = int.tryParse('${item['ilosc_odpowiedzi']}') ?? 0;
      result[id] = {'trudnosc': trud, 'ilosc_odpowiedzi': ilosc};
    }
    return result;
  }

  // ─────────────────────────────────────────
  //           Editor reset / open
  // ─────────────────────────────────────────

  void _resetEditorState() {
    editingId = null;
    _correct = 'A';
    _isUploading = false;
    _showPreview = false;
    _contentCtrl.clear();
    _opisPoprawneCtrl.clear();
    _opisNiepoprawneCtrl.clear();
    _imageHeightPx = null;
    _questionImageFilenames.clear();
    _imageBytes = null;
    _imageName = null;
    _uploadedImageUrl = null;
    _uploadedImageFilename = null;
    _videoBytes = null;
    _videoName = null;
    _uploadedVideoUrl = null;
    _uploadedVideoFilename = null;
    _mediaKind = MediaKind.none;
    for (final a in _answers) {
      a.reset();
    }
  }

  void _startNewQuestion() => setState(_resetEditorState);

  void _setupAnswerFromRaw(int index, String? raw) {
    final unescaped = _unescapeLtGt(raw ?? '');
    final hasImg = unescaped.toLowerCase().contains('<img');
    final imgUrl = _extractFirstImageSrcSmart(unescaped);
    final a = _answers[index];
    a.kind = hasImg ? AnswerKind.image : AnswerKind.text;
    a.uploadedImageUrl = imgUrl;
    a.uploadedImageFilename = imgUrl != null ? _filenameFromUrl(imgUrl) : null;
    a.imageBytes = null;
    a.imageName = null;
  }

  void _openForEdit(Map<String, dynamic> q) async {
    await _disposeLocalTempVideo();
    if (!mounted) return;
    setState(() {
      _resetEditorState();
      editingId = int.tryParse(q['id']?.toString() ?? '');

      final rawHtml = q['pytanie']?.toString() ?? '';
      final unescapedHtml = _unescapeLtGt(rawHtml);

      final rawImages = (q['images'] is List)
          ? (q['images'] as List).cast<String>()
          : <String>[];
      final rawVideos = (q['videos'] is List)
          ? (q['videos'] as List).cast<String>()
          : <String>[];

      final vidUrl = rawVideos.isNotEmpty
          ? rawVideos.first
          : _extractFirstVideoSrcSmart(unescapedHtml);

      final questionImages = List<String>.from(rawImages.take(5));
      _questionImageFilenames.addAll(
        questionImages.map((u) => _filenameFromUrl(u)).whereType<String>(),
      );

      if (vidUrl != null && vidUrl.isNotEmpty) {
        _mediaKind = MediaKind.video;
        _uploadedVideoUrl = vidUrl;
        _uploadedVideoFilename = _filenameFromUrl(vidUrl);
      } else if (_questionImageFilenames.isNotEmpty) {
        _mediaKind = MediaKind.image;
        _uploadedImageUrl = questionImages.isNotEmpty
            ? questionImages.first
            : null;
        _uploadedImageFilename = _uploadedImageUrl != null
            ? _filenameFromUrl(_uploadedImageUrl!)
            : _questionImageFilenames.first;
      }

      final cleaned = _stripStyleAndImage(rawHtml);
      _contentCtrl.text = _unescapeLtGt(cleaned);

      for (int i = 0; i < 4; i++) {
        _answers[i].ctrl.text = _answerToUi(q['odp${i + 1}']?.toString());
        _setupAnswerFromRaw(i, q['odp${i + 1}']?.toString());
      }

      _opisPoprawneCtrl.text = q['opisPoprawne']?.toString() ?? '';
      _opisNiepoprawneCtrl.text = q['opisNiepoprawne']?.toString() ?? '';

      final poprawna = q['poprawna']?.toString().toUpperCase() ?? 'A';
      _correct = ['A', 'B', 'C', 'D'].contains(poprawna) ? poprawna : 'A';
    });
  }

  String _stripStyleAndImage(String rawHtml) {
    //String escapedDomain = "https://egzaminy\.zsel\.edu\.pl";
    var out = rawHtml;
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
        r'<img[^>]+src="https://egzaminy\.zsel\.edu\.pl/egzaminy/[^/]+/obrazy/image\d+\.jpg"[^>]*\/?>',
        caseSensitive: false,
      ),
      '',
    );
    out = out.replaceAll(
      RegExp(
        r'&lt;img[^&]+src=&quot;https://egzaminy\.zsel\.edu\.pl/egzaminy/[^/]+/obrazy/image\d+\.jpg&quot;[^&]*&gt;',
        caseSensitive: false,
      ),
      '',
    );
    out = out.replaceAll(
      RegExp(
        r'<video[^>]+src="https://egzaminy\.zsel\.edu\.pl/egzaminy/[^/]+/filmy/video\d+\.mp4"[^>]*>.*?</video>',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );
    out = out.replaceAll(
      RegExp(
        r'&lt;video[^&]+src=&quot;https://egzaminy\.zsel\.edu\.pl/egzaminy/[^/]+/filmy/video\d+\.mp4&quot;[^&]*&gt;.*?&lt;/video&gt;',
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
    return out.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // ─────────────────────────────────────────
  //               Media actions
  // ─────────────────────────────────────────

  Future<void> _pickAndUploadQuestionImage() async {
    if (_questionImageFilenames.length >= 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Możesz dodać maksymalnie 5 obrazków do treści pytania.',
            ),
          ),
        );
      }
      return;
    }
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'images',
            extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'],
          ),
        ],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _mediaKind = MediaKind.image;
        _imageBytes = bytes;
        _imageName = file.name;
        _uploadedImageUrl = null;
        _uploadedImageFilename = null;
      });
      await _uploadImage(addToQuestionList: true);
      _refreshIfPreview(immediate: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie udało się otworzyć/wysłać obrazka: $e')),
        );
      }
    }
  }

  Future<void> _uploadImage({bool addToQuestionList = false}) async {
    if (_imageBytes == null || _imageName == null) return;
    if (mounted) setState(() => _isUploading = true);
    _refreshIfPreview(immediate: true);
    try {
      final result = await ApiService.instance.uploadImage(
        _kval,
        _imageBytes!,
        _imageName!,
      );
      if (!result.isSuccess) {
        throw result.errorMessage ?? 'Błąd HTTP ${result.statusCode}';
      }
      setState(() {
        _uploadedImageUrl = result.data!['url'];
        _uploadedImageFilename = result.data!['filename'];
        _mediaKind = MediaKind.image;
        if (addToQuestionList &&
            _questionImageFilenames.length < 5 &&
            _uploadedImageFilename != null &&
            _uploadedImageFilename!.isNotEmpty) {
          _questionImageFilenames.add(_uploadedImageFilename!);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Wystąpił błąd podczas wysyłania obrazka: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickVideo() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'video', extensions: ['mp4', 'webm', 'ogg']),
        ],
      );
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie udało się otworzyć pliku wideo: $e')),
        );
      }
    }
  }

  Future<void> _uploadVideo() async {
    if (_videoBytes == null || _videoName == null) return;
    if (mounted) setState(() => _isUploading = true);
    try {
      final result = await ApiService.instance.uploadVideo(
        _kval,
        _videoBytes!,
        _videoName!,
      );
      if (!result.isSuccess) {
        throw result.errorMessage ?? 'Błąd HTTP ${result.statusCode}';
      }
      setState(() {
        _uploadedVideoUrl = result.data!['url'];
        _uploadedVideoFilename = result.data!['filename'];
        _mediaKind = MediaKind.video;
      });
      _refreshIfPreview(immediate: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wystąpił błąd podczas wysyłania filmu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _removeMedia() {
    setState(() {
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
      _questionImageFilenames.clear();
      _disposeLocalTempVideo();
    });
    _refreshIfPreview(immediate: true);
  }

  // ─────────────────────────────────────────
  //          Answer image actions
  // ─────────────────────────────────────────

  Future<void> _pickAnswerImage(int index) async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'images',
            extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'],
          ),
        ],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        final a = _answers[index];
        a.kind = AnswerKind.image;
        a.imageBytes = bytes;
        a.imageName = file.name;
        a.uploadedImageUrl = null;
        a.uploadedImageFilename = null;
      });
      _refreshIfPreview(immediate: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nie udało się otworzyć obrazka odpowiedzi: $e'),
          ),
        );
      }
    }
  }

  Future<bool> _uploadAnswerImage(int index) async {
    final a = _answers[index];
    if (a.imageBytes == null || a.imageName == null) return false;
    if (mounted) setState(() => _isUploading = true);
    try {
      final result = await ApiService.instance.uploadImage(
        _kval,
        a.imageBytes!,
        a.imageName!,
      );
      if (!result.isSuccess) {
        throw result.errorMessage ?? 'Błąd HTTP ${result.statusCode}';
      }
      setState(() {
        a.uploadedImageUrl = result.data!['url']!;
        a.uploadedImageFilename = result.data!['filename'];
      });
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Wystąpił błąd podczas wysyłania obrazka odpowiedzi ${index + 1}: $e',
            ),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ─────────────────────────────────────────
  //               Save / Delete
  // ─────────────────────────────────────────

  Future<void> _saveQuestion() async {
    final pyt = _contentCtrl.text.trim();
    if (pyt.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Uzupełnij treść pytania.')));
      return;
    }

    final letters = ['A', 'B', 'C', 'D'];
    for (int i = 0; i < 4; i++) {
      final a = _answers[i];
      if (a.kind == AnswerKind.text) {
        if (a.ctrl.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Uzupełnij tekst odpowiedzi ${letters[i]}.'),
            ),
          );
          return;
        }
      } else {
        if (!a.hasImage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Wybierz obrazek dla odpowiedzi ${letters[i]} lub przełącz na tekst.',
              ),
            ),
          );
          return;
        }
      }
    }

    if (_mediaKind == MediaKind.image &&
        _questionImageFilenames.isEmpty &&
        (_imageBytes?.isNotEmpty ?? false)) {
      await _uploadImage(addToQuestionList: true);
      if (_questionImageFilenames.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Nie udało się wysłać obrazka pytania. Zapis anulowany.',
              ),
            ),
          );
        }
        return;
      }
    }

    if (_mediaKind == MediaKind.video &&
        _uploadedVideoUrl == null &&
        (_videoBytes?.isNotEmpty ?? false)) {
      await _uploadVideo();
      if (_uploadedVideoUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nie udało się wysłać filmu. Zapis anulowany.'),
            ),
          );
        }
        return;
      }
    }

    for (int i = 0; i < 4; i++) {
      final a = _answers[i];
      if (a.kind == AnswerKind.image &&
          a.uploadedImageUrl == null &&
          (a.imageBytes?.isNotEmpty ?? false)) {
        final ok = await _uploadAnswerImage(i);
        if (!ok) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Wysyłanie odpowiedzi ${letters[i]} nie powiodło się. Zapis anulowany.',
                ),
              ),
            );
          }
          return;
        }
      }
    }

    final payload = <String, dynamic>{
      'egzamin': _kval,
      'pytanie': pyt,
      'poprawna': _correct,
      'opisPoprawne': _opisPoprawneCtrl.text.trim(),
      'opisNiepoprawne': _opisNiepoprawneCtrl.text.trim(),
      if (editingId != null) 'id': editingId,
    };

    for (int i = 0; i < 4; i++) {
      final a = _answers[i];
      payload['odp${i + 1}'] = a.ctrl.text.trim();
      if (a.kind == AnswerKind.image &&
          (a.uploadedImageFilename?.isNotEmpty ?? false)) {
        payload['odp${i + 1}_img_filename'] = a.uploadedImageFilename;
      }
    }

    if (_mediaKind == MediaKind.image && _questionImageFilenames.isNotEmpty) {
      payload['question_images'] = _questionImageFilenames;
      payload['img_filename'] = _questionImageFilenames.first;
      if ((_imageHeightPx ?? 0) > 0) payload['img_height'] = _imageHeightPx;
    } else if (_mediaKind == MediaKind.video) {
      payload['video_filename'] = _uploadedVideoFilename;
      if ((_imageHeightPx ?? 0) > 0) payload['video_height'] = _imageHeightPx;
    }

    try {
      final result = await ApiService.instance.saveQuestion(payload);
      if (!result.isSuccess || result.data?['ok'] != true) {
        throw result.data?['error'] ?? 'Nieznany błąd serwera';
      }
      final isEdit = editingId != null;
      final int? savedId = (result.data!['id'] is int)
          ? result.data!['id'] as int
          : int.tryParse('${result.data!['id']}');
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
      final result = await ApiService.instance.deleteQuestion(_kval, id);
      if (!result.isSuccess) {
        throw result.errorMessage ?? 'HTTP ${result.statusCode}';
      }
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

  // ─────────────────────────────────────────
  //            Difficulty reset
  // ─────────────────────────────────────────

  bool _busyResetAll = false;

  Future<void> _resetTrudnoscAll() async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
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
      final result = await ApiService.instance.resetDifficulty(_kval);
      if (!result.isSuccess) throw 'HTTP ${result.statusCode}';
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
          builder: (ctx) => AlertDialog(
            title: Text('Resetować trudność pytania ID $id?'),
            content: const Text('Wyzeruje trudność dla tego pytania.'),
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
      final result = await ApiService.instance.resetDifficulty(
        _kval,
        questionId: id,
      );
      if (!result.isSuccess) throw 'HTTP ${result.statusCode}';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Zresetowano trudność pytania ID $id')),
        );
      }
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Wystąpił błąd podczas resetu trudności pytania $id: $e',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = editingId != null;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edytor pytań — ${widget.qualification.toUpperCase()}'),
              if (isEditing)
                Text(
                  'Edytujesz ID $editingId',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.onPrimary.withValues(alpha: 0.75),
                  ),
                ),
            ],
          ),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          actions: [
            if (isEditing)
              TextButton.icon(
                onPressed: _startNewQuestion,
                icon: Icon(Icons.close, color: colorScheme.onPrimary, size: 18),
                label: Text(
                  'Anuluj edycję',
                  style: TextStyle(color: colorScheme.onPrimary),
                ),
              ),
            IconButton(
              tooltip: 'Odśwież',
              onPressed: isLoading ? null : _loadAll,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 720) {
              return _buildMobileLayout(context);
            }
            final theme = Theme.of(context);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 440, child: _buildLeftPanel(context)),
                Container(width: 1, color: theme.dividerColor),
                Expanded(child: _buildRightPanel(context)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        TabBar(
          tabs: const [
            Tab(text: 'Edytor'),
            Tab(text: 'Lista'),
          ],
          labelColor: theme.colorScheme.primary,
        ),
        Expanded(
          child: TabBarView(
            children: [_buildLeftPanel(context), _buildRightPanel(context)],
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel(BuildContext context) {
    if (isLoading) return Center(child: AsyncStateView.loading());
    if (_showPreview) return _buildLivePreview(context);
    return Column(
      children: [
        _buildRightToolbar(context),
        const Divider(height: 1),
        Expanded(child: _buildList()),
      ],
    );
  }

  // ─────────────────────────────────────────
  //        Right panel: toolbar + list
  // ─────────────────────────────────────────

  Widget _buildRightToolbar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final found = _filteredQuestions.length;
    final total = questions.length;

    return Material(
      color: colorScheme.surface,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 500;
            final countWidget = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_alt, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Wyniki: $found / $total',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!narrow && searchText.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      _textSearchCtrl.clear();
                      setState(() => searchText = '');
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Wyczyść filtr'),
                  ),
                ],
              ],
            );

            final buttonWidget = FilledButton.icon(
              onPressed: _busyResetAll ? null : _resetTrudnoscAll,
              icon: _busyResetAll
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.rotate_90_degrees_cw_outlined),
              label: const Text('Resetuj trudności'),
            );

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  countWidget,
                  if (searchText.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () {
                        _textSearchCtrl.clear();
                        setState(() => searchText = '');
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Wyczyść filtr'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: buttonWidget),
                ],
              );
            }

            return Row(
              children: [
                countWidget,
                const Spacer(),
                if (searchText.isNotEmpty) ...[
                  TextButton.icon(
                    onPressed: () {
                      _textSearchCtrl.clear();
                      setState(() => searchText = '');
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Wyczyść filtr'),
                  ),
                  const SizedBox(width: 8),
                ],
                buttonWidget,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList() {
    final items = _filteredQuestions;
    final int count = _displayCount.clamp(0, items.length);

    return ListView.builder(
      controller: _listController,
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (context, index) {
        if (index >= count) return _buildShimmerCard(context);
        return _buildQuestionCard(
          context,
          items[index] as Map<String, dynamic>,
        );
      },
    );
  }

  // ─────────────────────────────────────────
  //        Left panel — editor form
  // ─────────────────────────────────────────

  Widget _buildLeftPanel(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = editingId != null;

    OutlineInputBorder enabledBorder() => OutlineInputBorder(
      borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
    );
    OutlineInputBorder focusedBorder() => OutlineInputBorder(
      borderSide: BorderSide(color: colorScheme.primary, width: 2.0),
    );

    return Scrollbar(
      controller: _leftPanelScroll,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _leftPanelScroll,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionCard(
              icon: Icons.search,
              title: 'Szukaj',
              colorScheme: colorScheme,
              child: TextField(
                controller: _textSearchCtrl,
                decoration: InputDecoration(
                  hintText: 'Treść, odpowiedzi lub ID…',
                  prefixIcon: Icon(
                    Icons.search,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  border: const OutlineInputBorder(),
                  enabledBorder: enabledBorder(),
                  focusedBorder: focusedBorder(),
                  isDense: true,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                ),
                onChanged: (v) => setState(() => searchText = v.trim()),
              ),
            ),
            const SizedBox(height: 12),

            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isEditing
                    ? colorScheme.primaryContainer.withValues(alpha: 0.35)
                    : colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.25,
                      ),
                border: Border.all(
                  color: isEditing
                      ? colorScheme.primary.withValues(alpha: 0.5)
                      : colorScheme.outline.withValues(alpha: 0.2),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_note : Icons.add_circle_outline,
                    size: 20,
                    color: isEditing
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'Edytujesz pytanie ID $editingId'
                          : 'Nowe pytanie${_nextId != null ? ' (szac. ID ~$_nextId)' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isEditing
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _startNewQuestion,
                    icon: Icon(isEditing ? Icons.close : Icons.add, size: 16),
                    label: Text(isEditing ? 'Anuluj' : 'Nowe'),
                    style: TextButton.styleFrom(
                      foregroundColor: isEditing
                          ? colorScheme.error
                          : colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _SectionCard(
              icon: Icons.perm_media_outlined,
              title: 'Multimedia',
              colorScheme: colorScheme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      _mediaChip(
                        'Brak',
                        MediaKind.none,
                        colorScheme,
                        onSelected: _removeMedia,
                      ),
                      _mediaChip(
                        'Obrazek',
                        MediaKind.image,
                        colorScheme,
                        onSelected: () => setState(() {
                          _mediaKind = MediaKind.image;
                          _videoBytes = null;
                          _videoName = null;
                          _uploadedVideoUrl = null;
                          _uploadedVideoFilename = null;
                          _disposeLocalTempVideo();
                        }),
                      ),
                      _mediaChip(
                        'Film',
                        MediaKind.video,
                        colorScheme,
                        onSelected: () => setState(() {
                          _mediaKind = MediaKind.video;
                          _imageBytes = null;
                          _imageName = null;
                          _uploadedImageUrl = null;
                          _uploadedImageFilename = null;
                        }),
                      ),
                    ],
                  ),
                  if (_mediaKind != MediaKind.none) ...[
                    const SizedBox(height: 12),
                    _buildMediaBody(colorScheme),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            _SectionCard(
              icon: Icons.help_outline,
              title: 'Treść pytania',
              colorScheme: colorScheme,
              child: TextField(
                controller: _contentCtrl,
                onChanged: (_) => _refreshTextPreview(),
                decoration: InputDecoration(
                  hintText: 'Wpisz treść pytania…',
                  border: const OutlineInputBorder(),
                  enabledBorder: enabledBorder(),
                  focusedBorder: focusedBorder(),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                ),
                maxLines: 7,
                minLines: 5,
              ),
            ),
            const SizedBox(height: 12),

            _SectionCard(
              icon: Icons.checklist_rtl,
              title: 'Odpowiedzi',
              colorScheme: colorScheme,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Poprawna: ',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  DropdownButton<String>(
                    value: _correct,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    onChanged: (v) => setState(() => _correct = v ?? 'A'),
                    items: const [
                      DropdownMenuItem(value: 'A', child: Text('A')),
                      DropdownMenuItem(value: 'B', child: Text('B')),
                      DropdownMenuItem(value: 'C', child: Text('C')),
                      DropdownMenuItem(value: 'D', child: Text('D')),
                    ],
                  ),
                ],
              ),
              child: Column(
                children: [
                  for (int i = 0; i < 4; i++) ...[
                    _buildAnswerEditor(i, colorScheme),
                    if (i < 3) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            _SectionCard(
              icon: Icons.info_outline,
              title: 'Wyjaśnienia (opcjonalne)',
              colorScheme: colorScheme,
              child: Column(
                children: [
                  TextField(
                    controller: _opisPoprawneCtrl,
                    onChanged: (_) => _refreshTextPreview(),
                    decoration: InputDecoration(
                      labelText: 'Po poprawnej odpowiedzi',
                      border: const OutlineInputBorder(),
                      enabledBorder: enabledBorder(),
                      focusedBorder: focusedBorder(),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    maxLines: 3,
                    minLines: 2,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _opisNiepoprawneCtrl,
                    onChanged: (_) => _refreshTextPreview(),
                    decoration: InputDecoration(
                      labelText: 'Po niepoprawnej odpowiedzi',
                      border: const OutlineInputBorder(),
                      enabledBorder: enabledBorder(),
                      focusedBorder: focusedBorder(),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    maxLines: 3,
                    minLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _showPreview = true),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Podgląd'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _saveQuestion,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(isEditing ? 'Zaktualizuj' : 'Zapisz pytanie'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaChip(
    String label,
    MediaKind kind,
    ColorScheme colorScheme, {
    required VoidCallback onSelected,
  }) {
    final selected = _mediaKind == kind;
    Icon selectedIcon;
    switch (kind) {
      case MediaKind.none:
        selectedIcon = Icon(Icons.not_interested_rounded);
      case MediaKind.image:
        selectedIcon = Icon(Icons.image_rounded);
      case MediaKind.video:
        selectedIcon = Icon(Icons.video_file_rounded);
    }
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      avatar: selected ? Icon(Icons.check_rounded) : selectedIcon,
      showCheckmark: false,
      selectedColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: selected
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: selected
            ? colorScheme.primary
            : colorScheme.outline.withValues(alpha: 0.4),
      ),
      onSelected: (_) => onSelected(),
    );
  }

  Widget _buildMediaBody(ColorScheme colorScheme) {
    if (_mediaKind == MediaKind.image) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _pickAndUploadQuestionImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Dodaj obrazek'),
              ),
              const SizedBox(width: 8),
              Text(
                '${_questionImageFilenames.length}/5',
                style: TextStyle(
                  fontSize: 12,
                  color: _questionImageFilenames.length >= 5
                      ? colorScheme.error
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              if (_isUploading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (_questionImageFilenames.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  for (int i = 0; i < _questionImageFilenames.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _questionImageFilenames[i],
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () {
                              setState(() {
                                _questionImageFilenames.removeAt(i);
                                if (_questionImageFilenames.isEmpty) {
                                  _uploadedImageUrl = null;
                                  _uploadedImageFilename = null;
                                }
                              });
                              _refreshIfPreview(immediate: true);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: _removeMedia,
              icon: Icon(
                Icons.delete_outline,
                size: 16,
                color: colorScheme.error,
              ),
              label: Text(
                'Usuń wszystkie',
                style: TextStyle(color: colorScheme.error),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      );
    }

    if (_mediaKind == MediaKind.video) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.video_file_outlined),
                label: const Text('Wybierz film'),
              ),
              const SizedBox(width: 8),
              if (_isUploading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (_uploadedVideoUrl != null || _videoName != null) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.movie_outlined,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _uploadedVideoUrl ?? _videoName ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: _removeMedia,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // ─────────────────────────────────────────
  //            Answer editor row
  // ─────────────────────────────────────────

  Widget _buildAnswerEditor(int index, ColorScheme colorScheme) {
    final a = _answers[index];
    final letter = 'ABCD'[index];
    final isCorrect = letter == _correct;
    final cs = Theme.of(context).colorScheme;
    bool textSelected = a.kind == AnswerKind.text;
    bool imageSelected = a.kind == AnswerKind.image;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isCorrect
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.25),
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _correct = letter),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _correct = letter),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        letter,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isCorrect
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Tekst'),
                avatar: Icon(
                  textSelected
                      ? Icons.check_rounded
                      : Icons.text_fields_rounded,
                ),
                showCheckmark: false,
                selectedColor: cs.primaryContainer,
                selected: textSelected,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => a.kind = AnswerKind.text),
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('Obraz'),
                avatar: Icon(
                  imageSelected ? Icons.check_rounded : Icons.image_rounded,
                ),
                showCheckmark: false,
                selectedColor: cs.primaryContainer,
                selected: imageSelected,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => a.kind = AnswerKind.image),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (textSelected)
            TextField(
              controller: a.ctrl,
              onChanged: (_) => _refreshTextPreview(),
              decoration: InputDecoration(
                hintText: 'Treść odpowiedzi $letter…',
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 2.0,
                  ),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                isDense: true,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _pickAnswerImage(index),
                      icon: const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 16,
                      ),
                      label: const Text('Wybierz obrazek'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (a.hasImage)
                      Expanded(
                        child: Text(
                          a.fileLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: a.ctrl,
                  onChanged: (_) => _refreshTextPreview(),
                  decoration: InputDecoration(
                    hintText: 'Opis / tekst alt (opcjonalnie)',
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.5),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2.0,
                      ),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    isDense: true,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //         Question card (right list)
  // ─────────────────────────────────────────

  Widget _buildQuestionCard(BuildContext context, Map<String, dynamic> q) {
    final cs = Theme.of(context).colorScheme;

    final id = int.tryParse(q['id']?.toString() ?? '');
    final poprawna = q['poprawna']?.toString().toUpperCase() ?? 'A';
    final isActiveEdit = id != null && id == editingId;

    final rawImages = (q['images'] is List)
        ? (q['images'] as List).cast<String>()
        : <String>[];
    final answerImageUrls = <String>{};
    for (int i = 1; i <= 4; i++) {
      final src = _extractFirstImageSrcSmart(
        _unescapeLtGt(q['odp$i']?.toString() ?? ''),
      );
      if (src != null) answerImageUrls.add(src);
    }
    final questionImages = rawImages
        .where((u) => !answerImageUrls.contains(u))
        .toList();
    final questionVideos = (q['videos'] is List)
        ? (q['videos'] as List).cast<String>()
        : <String>[];

    final answers = List.generate(4, (i) {
      final letter = 'ABCD'[i];
      final odpHtml = _unescapeLtGt(
        (q['odp${i + 1}']?.toString() ?? '').replaceFirst(
          RegExp(r'^[A-D]\.\s*'),
          '',
        ),
      );
      final imgUrl = _extractFirstImageSrcSmart(odpHtml);
      final odpText = _stripAnswerPrefix(
        imgUrl != null
            ? odpHtml
                  .replaceAll(RegExp('<img[^>]*>', caseSensitive: false), '')
                  .trim()
            : odpHtml.trim(),
      );
      return ExamAnswerState(
        letter: letter,
        text: odpText,
        images: imgUrl != null ? [imgUrl] : [],
        videos: [],
        isCorrect: letter == poprawna,
        isSelected: false,
      );
    });

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: isActiveEdit ? 0.05 : 0.2),
            blurRadius: isActiveEdit ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExamQuestionCard(
        label: id != null ? 'ID #$id' : 'ID —',
        questionText: _clean(q['pytanie']?.toString() ?? ''),
        questionImages: questionImages,
        questionVideos: questionVideos,
        answers: answers,
        accentColor: isActiveEdit ? cs.primary : cs.outlineVariant,
        showResult: true,
        backgroundColor: isActiveEdit
            ? cs.primaryContainer.withValues(alpha: 0.10)
            : cs.surface,
        shadowAlpha: 0, // shadow handled by AnimatedContainer above
        headerTrailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActiveEdit) ...[
              Icon(Icons.edit_rounded, size: 13, color: cs.primary),
              const SizedBox(width: 4),
            ],
            DifficultyBadge(
              trudnosc: q['trudnosc'] is num
                  ? (q['trudnosc'] as num).toDouble()
                  : double.tryParse(q['trudnosc']?.toString() ?? '') ?? 0.0,
              ilosc: int.tryParse(q['ilosc_odpowiedzi']?.toString() ?? '') ?? 0,
            ),
          ],
        ),
        bottomRow: Wrap(
          spacing: 0,
          children: [
            _cardAction(
              context,
              icon: Icons.edit_outlined,
              label: 'Edytuj',
              onTap: () => _openForEdit(q),
              color: cs.primary,
            ),
            _cardAction(
              context,
              icon: Icons.restart_alt,
              label: 'Zresetuj trudność',
              onTap: id == null ? null : () => _resetTrudnoscOne(id),
              color: cs.secondary,
            ),
            _cardAction(
              context,
              icon: Icons.delete_outline,
              label: 'Usuń',
              onTap: id == null
                  ? null
                  : () async {
                      final ok =
                          await showDialog<bool>(
                            context: context,
                            builder: (dlgCtx) => AlertDialog(
                              title: const Text('Usuń pytanie'),
                              content: Text(
                                'Na pewno chcesz usunąć pytanie ID $id?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dlgCtx, false),
                                  child: const Text('Anuluj'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(dlgCtx, true),
                                  child: const Text('Usuń'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (!context.mounted) return;
                      if (ok) await _deleteQuestion(id);
                    },
              color: cs.error,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15, color: onTap == null ? null : color),
      label: Text(
        label,
        style: TextStyle(fontSize: 12, color: onTap == null ? null : color),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  // ────────
  //  Shimmer
  // ────────

  Widget _buildShimmerCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<ExtraColors>()!;

    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: extras.shimmerBase,
        highlightColor: extras.shimmerHighlight,
        period: const Duration(milliseconds: 900),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ShimBox(w: 55, h: 20, cs: cs, radius: 6),
                  const Spacer(),
                  ShimBox(w: 80, h: 20, cs: cs, radius: 20),
                ],
              ),
              const SizedBox(height: 10),
              ShimBox(w: double.infinity, h: 14, cs: cs),
              const SizedBox(height: 5),
              ShimBox(w: double.infinity, h: 14, cs: cs),
              const SizedBox(height: 5),
              ShimBox(w: 180, h: 14, cs: cs),
              const SizedBox(height: 12),
              for (int i = 0; i < 4; i++) ...[
                ShimBox(w: double.infinity, h: 38, cs: cs, radius: 7),
                const SizedBox(height: 5),
              ],
              const SizedBox(height: 4),
              ShimBox(w: 200, h: 12, cs: cs),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //               Live preview
  // ─────────────────────────────────────────

  Widget _buildLivePreview(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final url = '$apiBaseUrl/$_kval/obrazy/';

    final questionImageUrls = _mediaKind == MediaKind.image
        ? _questionImageFilenames.map((f) => "$url$f").toList()
        : <String>[];

    final questionVideoUrls =
        (_mediaKind == MediaKind.video && _uploadedVideoUrl != null)
        ? [_uploadedVideoUrl!]
        : <String>[];

    final answers = List.generate(4, (i) {
      final letter = 'ABCD'[i];
      final a = _answers[i];
      final hasUploadedImage =
          a.kind == AnswerKind.image && a.uploadedImageUrl != null;
      final hasLocalImage =
          a.kind == AnswerKind.image &&
          !hasUploadedImage &&
          a.imageBytes != null;

      return ExamAnswerState(
        letter: letter,
        text: a.ctrl.text.trim(),
        images: hasUploadedImage ? [a.uploadedImageUrl!] : const [],
        videos: const [],
        isCorrect: letter == _correct,
        isSelected: false,
        localImageBytes: hasLocalImage ? a.imageBytes : null,
      );
    });

    final label = editingId != null ? 'Pytanie ID $editingId' : 'Nowe pytanie';
    final questionText = _clean(_contentCtrl.text.trim());

    // Local video not yet uploaded needs async temp-file resolution first.
    if (_mediaKind == MediaKind.video &&
        _uploadedVideoUrl == null &&
        (_videoBytes?.isNotEmpty ?? false)) {
      return _previewShell(
        context,
        child: FutureBuilder<String?>(
          future: _ensureLocalTempVideo(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ExamQuestionCard(
                label: label,
                questionText: questionText,
                questionImages: questionImageUrls,
                questionVideos: [snapshot.data!],
                answers: answers,
                accentColor: colorScheme.primary,
                showResult: true,
                resultBanner: _buildExplanationBanner(colorScheme),
              ),
            );
          },
        ),
      );
    }

    return _previewShell(
      context,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ExamQuestionCard(
          label: label,
          questionText: questionText,
          questionImages: questionImageUrls,
          questionVideos: questionVideoUrls,
          answers: answers,
          accentColor: colorScheme.primary,
          showResult: true,
          resultBanner: _buildExplanationBanner(colorScheme),
        ),
      ),
    );
  }

  Widget? _buildExplanationBanner(ColorScheme colorScheme) {
    final correct = _opisPoprawneCtrl.text.trim();
    final incorrect = _opisNiepoprawneCtrl.text.trim();
    if (correct.isEmpty && incorrect.isEmpty) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (correct.isNotEmpty)
          Text(
            'Po poprawnej: ${_clean(correct)}',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        if (correct.isNotEmpty && incorrect.isNotEmpty)
          const SizedBox(height: 6),
        if (incorrect.isNotEmpty)
          Text(
            'Po niepoprawnej: ${_clean(incorrect)}',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _previewShell(BuildContext context, {required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Material(
          color: colorScheme.tertiaryContainer,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.preview_rounded,
                  size: 22,
                  color: colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PODGLĄD — zmiany nie są jeszcze zapisane!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onTertiaryContainer,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _showPreview = false),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Zamknij'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: colorScheme.errorContainer.withValues(
                      alpha: 0.85,
                    ),
                    foregroundColor: colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: SingleChildScrollView(child: child)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//               _SectionCard
// ─────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.colorScheme,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final ColorScheme colorScheme;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 15, color: colorScheme.primary),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    letterSpacing: 0.4,
                  ),
                ),
                if (trailing != null) ...[const Spacer(), trailing!],
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }
}
