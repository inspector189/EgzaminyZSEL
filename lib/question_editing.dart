import 'package:flutter_app/services/api_service.dart';
import 'package:html_unescape/html_unescape.dart';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/utils/app_themes.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'dart:async';
import 'package:shimmer/shimmer.dart';
import 'widgets/admin_video_player.dart';
import 'utils/helpers.dart';

enum MediaKind { none, image, video }

enum AnswerKind { text, image }

class EditQuestionsPage extends StatefulWidget {
  const EditQuestionsPage({super.key, required this.qualification});
  final String qualification;

  @override
  State<EditQuestionsPage> createState() => _EditQuestionsPageState();
}

class _EditQuestionsPageState extends State<EditQuestionsPage> {
  final List<String> _questionImageFilenames = [];

  final _unescape = HtmlUnescape();
  String _clean(String? s) => _unescape.convert(s?.toString() ?? '');
  String _lastPreviewSignature = '';

  String _currentMediaSignature() {
    final kind = _mediaKind.name;

    final imgListSig = _questionImageFilenames.join('|');

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

    return [
      kind,
      imgListSig,
      imgBytesSig,
      vidUrl,
      vidBytesSig,
      height,
    ].join('::');
  }

  String? _tempVideoPath;
  String? _webBlobUrl;
  Timer? _previewDebounce;
  String? _firstMatch(RegExp re, String s, [int group = 1]) {
    final m = re.firstMatch(s);
    return m?.group(group);
  }

  String? _extractFirstImageSrcSmart(String html) {
    final raw = _firstMatch(
      RegExp('<img[^>]+src=["\']([^"\']+)["\']', caseSensitive: false),
      html,
    );
    if (raw != null) return raw;

    final esc = _firstMatch(
      RegExp('&lt;img[^&]+src=&quot;([^&]+)&quot;', caseSensitive: false),
      html,
    );
    if (esc != null) return esc;

    return null;
  }

  String? _extractFirstVideoSrcSmart(String html) {
    final rawVideo = _firstMatch(
      RegExp('<video[^>]+src=["\']([^"\']+)["\']', caseSensitive: false),
      html,
    );
    if (rawVideo != null) return rawVideo;

    final rawSource = _firstMatch(
      RegExp('<source[^>]+src=["\']([^"\']+)["\']', caseSensitive: false),
      html,
    );
    if (rawSource != null) return rawSource;

    final escVideo = _firstMatch(
      RegExp('&lt;video[^&]+src=&quot;([^&]+)&quot;', caseSensitive: false),
      html,
    );
    if (escVideo != null) return escVideo;

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

  AnswerKind _odp1Kind = AnswerKind.text;
  AnswerKind _odp2Kind = AnswerKind.text;
  AnswerKind _odp3Kind = AnswerKind.text;
  AnswerKind _odp4Kind = AnswerKind.text;

  Uint8List? _odp1ImageBytes;
  String? _odp1ImageName;
  String? _odp1UploadedImageUrl;
  String? _odp1UploadedImageFilename;

  Uint8List? _odp2ImageBytes;
  String? _odp2ImageName;
  String? _odp2UploadedImageUrl;
  String? _odp2UploadedImageFilename;

  Uint8List? _odp3ImageBytes;
  String? _odp3ImageName;
  String? _odp3UploadedImageUrl;
  String? _odp3UploadedImageFilename;

  Uint8List? _odp4ImageBytes;
  String? _odp4ImageName;
  String? _odp4UploadedImageUrl;
  String? _odp4UploadedImageFilename;

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
    final result = await ApiService.instance.fetchQuestions(kval);
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
    final String kval = _sanitizedTable();
    final List<dynamic> jsonList = res.data!;
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
      _questionImageFilenames.clear();
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

      _odp1Kind = AnswerKind.text;
      _odp2Kind = AnswerKind.text;
      _odp3Kind = AnswerKind.text;
      _odp4Kind = AnswerKind.text;

      _odp1ImageBytes = null;
      _odp1ImageName = null;
      _odp1UploadedImageUrl = null;
      _odp1UploadedImageFilename = null;

      _odp2ImageBytes = null;
      _odp2ImageName = null;
      _odp2UploadedImageUrl = null;
      _odp2UploadedImageFilename = null;

      _odp3ImageBytes = null;
      _odp3ImageName = null;
      _odp3UploadedImageUrl = null;
      _odp3UploadedImageFilename = null;

      _odp4ImageBytes = null;
      _odp4ImageName = null;
      _odp4UploadedImageUrl = null;
      _odp4UploadedImageFilename = null;

      _disposeLocalTempVideo();
    });
  }

  void _setupAnswerKindFromRaw(String? raw, int index) {
    final html = _unescapeLtGt(raw ?? '');
    final hasImg = html.toLowerCase().contains('<img');
    final imgUrl = _extractFirstImageSrcSmart(html);

    switch (index) {
      case 1:
        _odp1Kind = hasImg ? AnswerKind.image : AnswerKind.text;
        _odp1UploadedImageUrl = imgUrl;
        _odp1UploadedImageFilename =
            imgUrl != null ? _filenameFromUrl(imgUrl) : null;
        _odp1ImageBytes = null;
        _odp1ImageName = null;
        break;
      case 2:
        _odp2Kind = hasImg ? AnswerKind.image : AnswerKind.text;
        _odp2UploadedImageUrl = imgUrl;
        _odp2UploadedImageFilename =
            imgUrl != null ? _filenameFromUrl(imgUrl) : null;
        _odp2ImageBytes = null;
        _odp2ImageName = null;
        break;
      case 3:
        _odp3Kind = hasImg ? AnswerKind.image : AnswerKind.text;
        _odp3UploadedImageUrl = imgUrl;
        _odp3UploadedImageFilename =
            imgUrl != null ? _filenameFromUrl(imgUrl) : null;
        _odp3ImageBytes = null;
        _odp3ImageName = null;
        break;
      case 4:
        _odp4Kind = hasImg ? AnswerKind.image : AnswerKind.text;
        _odp4UploadedImageUrl = imgUrl;
        _odp4UploadedImageFilename =
            imgUrl != null ? _filenameFromUrl(imgUrl) : null;
        _odp4ImageBytes = null;
        _odp4ImageName = null;
        break;
    }
  }

  void _openForEdit(Map<String, dynamic> q) {
    setState(() {
      editingId = int.tryParse(q['id']?.toString() ?? '');

      final rawHtml = q['pytanie']?.toString() ?? '';
      final unescapedHtml = _unescapeLtGt(rawHtml);

      final rawImages =
          (q['images'] is List)
              ? (q['images'] as List).cast<String>()
              : <String>[];
      final rawVideos =
          (q['videos'] is List)
              ? (q['videos'] as List).cast<String>()
              : <String>[];

      String? vidUrl =
          rawVideos.isNotEmpty
              ? rawVideos.first
              : _extractFirstVideoSrcSmart(unescapedHtml);

      final List<String> questionImages = List<String>.from(rawImages.take(5));

      _questionImageFilenames
        ..clear()
        ..addAll(
          questionImages.map((u) => _filenameFromUrl(u)).whereType<String>(),
        );

      if (vidUrl != null && vidUrl.isNotEmpty) {
        _mediaKind = MediaKind.video;

        _uploadedVideoUrl = vidUrl;
        _uploadedVideoFilename = _filenameFromUrl(vidUrl);

        _imageBytes = null;
        _imageName = null;
        _uploadedImageUrl = null;
        _uploadedImageFilename = null;
        _imageCtrl.clear();
      } else if (_questionImageFilenames.isNotEmpty) {
        _mediaKind = MediaKind.image;

        final firstUrl =
            questionImages.isNotEmpty ? questionImages.first : null;
        _uploadedImageUrl = firstUrl;
        _uploadedImageFilename =
            firstUrl != null
                ? _filenameFromUrl(firstUrl)
                : _questionImageFilenames.first;

        _imageBytes = null;
        _imageName = null;
        _imageCtrl.clear();

        _videoBytes = null;
        _videoName = null;
        _uploadedVideoUrl = null;
        _uploadedVideoFilename = null;
        _disposeLocalTempVideo();
      } else {
        _mediaKind = MediaKind.none;

        _questionImageFilenames.clear();

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

      _imageHeightPx = null;
      _imageHeightCtrl.clear();

      final cleaned = _stripStyleAndImage(rawHtml);
      _contentCtrl.text = _unescapeLtGt(cleaned);

      _odp1Ctrl.text = _answerToUi(q['odp1']?.toString());
      _odp2Ctrl.text = _answerToUi(q['odp2']?.toString());
      _odp3Ctrl.text = _answerToUi(q['odp3']?.toString());
      _odp4Ctrl.text = _answerToUi(q['odp4']?.toString());

      _setupAnswerKindFromRaw(q['odp1']?.toString(), 1);
      _setupAnswerKindFromRaw(q['odp2']?.toString(), 2);
      _setupAnswerKindFromRaw(q['odp3']?.toString(), 3);
      _setupAnswerKindFromRaw(q['odp4']?.toString(), 4);

      _opisPoprawneCtrl.text = q['opisPoprawne']?.toString() ?? '';
      _opisNiepoprawneCtrl.text = q['opisNiepoprawne']?.toString() ?? '';

      final poprawna = (q['poprawna']?.toString().toUpperCase() ?? 'A');
      _correct = ['A', 'B', 'C', 'D'].contains(poprawna) ? poprawna : 'A';
    });
  }

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
        _sanitizedTable(),
        _imageBytes!,
        _imageName!,
      );

      if (!result.isSuccess) {
        throw result.errorMessage ?? 'Upload HTTP ${result.statusCode}';
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
          SnackBar(content: Text('Błąd podczas wysyłania obrazka: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
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

  Future<void> _pickAnswerImage(int index) async {
    try {
      final typeGroup = const XTypeGroup(
        label: 'images',
        extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;
      final bytes = await file.readAsBytes();

      setState(() {
        switch (index) {
          case 1:
            _odp1Kind = AnswerKind.image;
            _odp1ImageBytes = bytes;
            _odp1ImageName = file.name;
            _odp1UploadedImageUrl = null;
            _odp1UploadedImageFilename = null;
            break;
          case 2:
            _odp2Kind = AnswerKind.image;
            _odp2ImageBytes = bytes;
            _odp2ImageName = file.name;
            _odp2UploadedImageUrl = null;
            _odp2UploadedImageFilename = null;
            break;
          case 3:
            _odp3Kind = AnswerKind.image;
            _odp3ImageBytes = bytes;
            _odp3ImageName = file.name;
            _odp3UploadedImageUrl = null;
            _odp3UploadedImageFilename = null;
            break;
          case 4:
            _odp4Kind = AnswerKind.image;
            _odp4ImageBytes = bytes;
            _odp4ImageName = file.name;
            _odp4UploadedImageUrl = null;
            _odp4UploadedImageFilename = null;
            break;
        }
      });
      _refreshIfPreview(immediate: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nie udało się otworzyć obrazka odpowiedzi: $e'),
        ),
      );
    }
  }

  Future<void> _uploadAnswerImage(int index) async {
    Uint8List? bytes;
    String? name;

    switch (index) {
      case 1:
        bytes = _odp1ImageBytes;
        name = _odp1ImageName;
        break;
      case 2:
        bytes = _odp2ImageBytes;
        name = _odp2ImageName;
        break;
      case 3:
        bytes = _odp3ImageBytes;
        name = _odp3ImageName;
        break;
      case 4:
        bytes = _odp4ImageBytes;
        name = _odp4ImageName;
        break;
    }

    if (bytes == null || name == null) return;
    if (mounted) setState(() => _isUploading = true);

    try {
      final result = await ApiService.instance.uploadImage(
        _sanitizedTable(),
        bytes,
        name,
      );

      if (!result.isSuccess) {
        throw result.errorMessage ?? 'Upload HTTP ${result.statusCode}';
      }

      setState(() {
        final url = result.data!['url']!;
        final filename = result.data!['filename'];

        switch (index) {
          case 1:
            _odp1UploadedImageUrl = url;
            _odp1UploadedImageFilename = filename;
            break;
          case 2:
            _odp2UploadedImageUrl = url;
            _odp2UploadedImageFilename = filename;
            break;
          case 3:
            _odp3UploadedImageUrl = url;
            _odp3UploadedImageFilename = filename;
            break;
          case 4:
            _odp4UploadedImageUrl = url;
            _odp4UploadedImageFilename = filename;
            break;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd uploadu obrazka odpowiedzi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadVideo() async {
    if (_videoBytes == null || _videoName == null) return;
    if (mounted) setState(() => _isUploading = true);

    try {
      final result = await ApiService.instance.uploadVideo(
        _sanitizedTable(),
        _videoBytes!,
        _videoName!,
      );

      if (!result.isSuccess) {
        throw result.errorMessage ?? 'Upload HTTP ${result.statusCode}';
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
          SnackBar(content: Text('Błąd podczas wysyłania filmu: $e')),
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
      _imageCtrl.clear();
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

  Future<void> _saveQuestion() async {
    final pyt = _contentCtrl.text.trim();

    String ansText(int i) =>
        [_odp1Ctrl, _odp2Ctrl, _odp3Ctrl, _odp4Ctrl][i].text.trim();

    AnswerKind ansKind(int i) =>
        [_odp1Kind, _odp2Kind, _odp3Kind, _odp4Kind][i];

    bool hasImageForIndex(int i) {
      switch (i) {
        case 0:
          return _odp1ImageBytes != null || _odp1UploadedImageUrl != null;
        case 1:
          return _odp2ImageBytes != null || _odp2UploadedImageUrl != null;
        case 2:
          return _odp3ImageBytes != null || _odp3UploadedImageUrl != null;
        default:
          return _odp4ImageBytes != null || _odp4UploadedImageUrl != null;
      }
    }

    if (pyt.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Uzupełnij treść pytania.')));
      return;
    }

    final letters = ['A', 'B', 'C', 'D'];
    for (int i = 0; i < 4; i++) {
      if (ansKind(i) == AnswerKind.text) {
        if (ansText(i).isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Uzupełnij tekst odpowiedzi ${letters[i]}.'),
            ),
          );
          return;
        }
      } else {
        if (!hasImageForIndex(i)) {
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
        _imageBytes != null &&
        _imageBytes!.isNotEmpty) {
      await _uploadImage(addToQuestionList: true);
      if (_questionImageFilenames.isEmpty) return;
    }

    if (_mediaKind == MediaKind.video &&
        _uploadedVideoUrl == null &&
        _videoBytes != null &&
        _videoBytes!.isNotEmpty) {
      await _uploadVideo();
      if (_uploadedVideoUrl == null) return;
    }

    for (int idx = 1; idx <= 4; idx++) {
      AnswerKind kind;
      Uint8List? bytes;
      String? url;

      switch (idx) {
        case 1:
          kind = _odp1Kind;
          bytes = _odp1ImageBytes;
          url = _odp1UploadedImageUrl;
          break;
        case 2:
          kind = _odp2Kind;
          bytes = _odp2ImageBytes;
          url = _odp2UploadedImageUrl;
          break;
        case 3:
          kind = _odp3Kind;
          bytes = _odp3ImageBytes;
          url = _odp3UploadedImageUrl;
          break;
        default:
          kind = _odp4Kind;
          bytes = _odp4ImageBytes;
          url = _odp4UploadedImageUrl;
      }

      if (kind == AnswerKind.image &&
          url == null &&
          bytes != null &&
          bytes.isNotEmpty) {
        await _uploadAnswerImage(idx);
        switch (idx) {
          case 1:
            if (_odp1UploadedImageUrl == null) return;
            break;
          case 2:
            if (_odp2UploadedImageUrl == null) return;
            break;
          case 3:
            if (_odp3UploadedImageUrl == null) return;
            break;
          case 4:
            if (_odp4UploadedImageUrl == null) return;
            break;
        }
      }
    }

    final payload = <String, dynamic>{
      'egzamin': _sanitizedTable(),
      'pytanie': pyt,
      'poprawna': _correct,
      'opisPoprawne': _opisPoprawneCtrl.text.trim(),
      'opisNiepoprawne': _opisNiepoprawneCtrl.text.trim(),
      if (editingId != null) 'id': editingId,
    };

    for (int i = 0; i < 4; i++) {
      final text = [_odp1Ctrl, _odp2Ctrl, _odp3Ctrl, _odp4Ctrl][i].text.trim();
      final kind = [_odp1Kind, _odp2Kind, _odp3Kind, _odp4Kind][i];

      String? filename;
      switch (i) {
        case 0:
          filename = _odp1UploadedImageFilename;
          break;
        case 1:
          filename = _odp2UploadedImageFilename;
          break;
        case 2:
          filename = _odp3UploadedImageFilename;
          break;
        case 3:
          filename = _odp4UploadedImageFilename;
          break;
      }

      if (kind == AnswerKind.text) {
        payload['odp${i + 1}'] = text;
      } else {
        if (filename != null && filename.isNotEmpty) {
          payload['odp${i + 1}_img_filename'] = filename;
        }
        payload['odp${i + 1}'] = text;
      }
    }

    if (_mediaKind == MediaKind.image && _questionImageFilenames.isNotEmpty) {
      payload['question_images'] = _questionImageFilenames;
      payload['img_filename'] = _questionImageFilenames.first;

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
      final result = await ApiService.instance.saveQuestion(payload);
      if (!result.isSuccess || result.data?['ok'] != true) {
        throw result.data?['error'] ?? 'Nieznany błąd serwera';
      }

      final isEdit = editingId != null;
      final int? savedId =
          (result.data!['id'] is int)
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
      final result = await ApiService.instance.deleteQuestion(
        _sanitizedTable(),
        id,
      );
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
      final result = await ApiService.instance.resetDifficulty(
        _sanitizedTable(),
      );
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
      final result = await ApiService.instance.resetDifficulty(
        _sanitizedTable(),
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
    bool extractInlineImages =
        true, // możesz to już olać, ale zostawiam sygnaturę
    double minImageHeight = 100,
    double maxImageHeight = 500,
  }) {
    const double videoHeight = 400;

    // dokładnie jak w EgzaminView: odkoduj cały HTML
    final plain = _clean(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (plain.isNotEmpty) Text(plain, style: const TextStyle(fontSize: 16)),

        // OBRAZKI (z tablicy images – tak jak w EgzaminView z *_images)
        ...?images?.map(
          (url) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: minImageHeight,
                  maxHeight: maxImageHeight,
                ),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
          ),
        ),

        // WIDEO (tak samo)
        ...?videos?.map(
          (url) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: InlineVideoPlayer(url: url, height: videoHeight),
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

  Widget _buildAnswerEditor(int index, String label) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ctrl = [_odp1Ctrl, _odp2Ctrl, _odp3Ctrl, _odp4Ctrl][index];
    final letter = ['A', 'B', 'C', 'D'][index];

    AnswerKind kind;
    String? fileLabel;
    bool hasImage = false;

    switch (index) {
      case 0:
        kind = _odp1Kind;
        fileLabel = _odp1UploadedImageUrl ?? _odp1ImageName;
        hasImage = _odp1ImageBytes != null || _odp1UploadedImageUrl != null;
        break;
      case 1:
        kind = _odp2Kind;
        fileLabel = _odp2UploadedImageUrl ?? _odp2ImageName;
        hasImage = _odp2ImageBytes != null || _odp2UploadedImageUrl != null;
        break;
      case 2:
        kind = _odp3Kind;
        fileLabel = _odp3UploadedImageUrl ?? _odp3ImageName;
        hasImage = _odp3ImageBytes != null || _odp3UploadedImageUrl != null;
        break;
      default:
        kind = _odp4Kind;
        fileLabel = _odp4UploadedImageUrl ?? _odp4ImageName;
        hasImage = _odp4ImageBytes != null || _odp4UploadedImageUrl != null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(label),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Tekst'),
              selected: kind == AnswerKind.text,
              onSelected: (_) {
                setState(() {
                  switch (index) {
                    case 0:
                      _odp1Kind = AnswerKind.text;
                      break;
                    case 1:
                      _odp2Kind = AnswerKind.text;
                      break;
                    case 2:
                      _odp3Kind = AnswerKind.text;
                      break;
                    case 3:
                      _odp4Kind = AnswerKind.text;
                      break;
                  }
                });
              },
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: const Text('Obrazek'),
              selected: kind == AnswerKind.image,
              onSelected: (_) {
                setState(() {
                  switch (index) {
                    case 0:
                      _odp1Kind = AnswerKind.image;
                      break;
                    case 1:
                      _odp2Kind = AnswerKind.image;
                      break;
                    case 2:
                      _odp3Kind = AnswerKind.image;
                      break;
                    case 3:
                      _odp4Kind = AnswerKind.image;
                      break;
                  }
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (kind == AnswerKind.text)
          TextField(
            controller: ctrl,
            onChanged: (_) => _refreshTextPreview(),
            decoration: InputDecoration(
              labelText: 'Odpowiedź $letter (tekst)',
              border: const OutlineInputBorder(),
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
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickAnswerImage(index + 1),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Wybierz obrazek'),
                  ),
                  const SizedBox(width: 8),
                  if (hasImage)
                    Expanded(
                      child: Text(
                        fileLabel ?? '',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: ctrl,
                onChanged: (_) => _refreshTextPreview(),
                decoration: const InputDecoration(
                  labelText: 'Opis / alt (opcjonalnie)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
      ],
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
                      // --- obrazki do treści pytania (max 5) ---
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickAndUploadQuestionImage,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Dodaj obrazek (max 5)'),
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
                      if (_questionImageFilenames.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Obrazki pytania (${_questionImageFilenames.length}/5):',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ..._questionImageFilenames.asMap().entries.map((e) {
                              final idx = e.key;
                              final name = e.value;
                              return Row(
                                children: [
                                  const Icon(Icons.image, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Usuń ten obrazek',
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _questionImageFilenames.removeAt(idx);
                                        if (_questionImageFilenames.isEmpty) {
                                          _uploadedImageUrl = null;
                                          _uploadedImageFilename = null;
                                        }
                                      });
                                      _refreshIfPreview(immediate: true);
                                    },
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_questionImageFilenames.isNotEmpty)
                            TextButton.icon(
                              onPressed: _removeMedia,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Usuń wszystkie'),
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
                  _buildAnswerEditor(0, 'Odpowiedź A'),
                  const SizedBox(height: 8),
                  _buildAnswerEditor(1, 'Odpowiedź B'),
                  const SizedBox(height: 8),
                  _buildAnswerEditor(2, 'Odpowiedź C'),
                  const SizedBox(height: 8),
                  _buildAnswerEditor(3, 'Odpowiedź D'),
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

  Widget _buildAnswerImage({String? url, Uint8List? bytes}) {
    if (url == null || url.isEmpty) {
      if (bytes == null || bytes.isEmpty) {
        return const SizedBox.shrink();
      }
    }

    Widget img;
    if (url != null && url.isNotEmpty) {
      img = Image.network(url, fit: BoxFit.contain);
    } else {
      img = Image.memory(bytes!, fit: BoxFit.contain);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50, maxHeight: 200),
        child: img,
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, Map<String, dynamic> q) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final extras = theme.extension<ExtraColors>()!;
    final id = int.tryParse(q['id']?.toString() ?? '');
    final poprawna = (q['poprawna']?.toString().toUpperCase() ?? 'A');

    final defaultTextColor =
        theme.brightness == Brightness.light ? Colors.black : Colors.white;

    final rawImages =
        (q['images'] is List)
            ? (q['images'] as List).cast<String>()
            : <String>[];

    final Set<String> answerImageUrls = {};
    for (int i = 1; i <= 4; i++) {
      final odpRaw = q['odp$i']?.toString() ?? '';
      final odpHtml = _unescapeLtGt(odpRaw);
      final img = _extractFirstImageSrcSmart(odpHtml);
      if (img != null && img.isNotEmpty) {
        answerImageUrls.add(img);
      }
    }

    final questionImages =
        rawImages.where((url) => !answerImageUrls.contains(url)).toList();

    final answers =
        ['A', 'B', 'C', 'D'].asMap().entries.map((e) {
          final index = e.key;
          final letter = e.value;
          final isCorrect = letter == poprawna;

          final odpRaw = q['odp${index + 1}']?.toString() ?? '';
          final odpHtml = _unescapeLtGt(
            odpRaw.replaceFirst(RegExp(r'^[A-D]\.\s*'), ''),
          );

          final imgFromBody = _extractFirstImageSrcSmart(odpHtml);
          String odpTextOnly = odpHtml;
          if (imgFromBody != null) {
            odpTextOnly = odpHtml.replaceAll(
              RegExp('<img[^>]*>', caseSensitive: false),
              '',
            );
          }
          final odpPlain = odpTextOnly.trim();

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            child: IgnorePointer(
              ignoring: true,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isCorrect ? extras.correct : colorScheme.surface,
                  foregroundColor: isCorrect ? Colors.black : defaultTextColor,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // literka + tekst
                    if (odpPlain.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$letter. '),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              odpPlain,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      )
                    else
                      Text('$letter.'),
                    if (imgFromBody != null) ...[
                      const SizedBox(height: 8),
                      _buildAnswerImage(url: imgFromBody),
                    ],
                  ],
                ),
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
                    images: questionImages,
                    videos: (q['videos'] as List?)?.cast<String>(),
                    extractInlineImages: false,
                    minImageHeight: 100,
                    maxImageHeight: 500,
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
                  onPressed:
                      id == null
                          ? null
                          : () async {
                            final ok =
                                await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (dialogCtx) => AlertDialog(
                                        title: const Text('Usuń pytanie'),
                                        content: Text(
                                          'Na pewno chcesz usunąć pytanie ID $id?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  dialogCtx,
                                                  false,
                                                ),
                                            child: const Text('Anuluj'),
                                          ),
                                          FilledButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  dialogCtx,
                                                  true,
                                                ),
                                            child: const Text('Usuń'),
                                          ),
                                        ],
                                      ),
                                ) ??
                                false;
                            if (!context.mounted) return;
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

    final defaultTextColor =
        theme.brightness == Brightness.light ? Colors.black : Colors.white;

    Widget? mediaWidget;
    if (_mediaKind == MediaKind.image && _questionImageFilenames.isNotEmpty) {
      final kvalPath = _sanitizedTable();
      mediaWidget = Column(
        children:
            _questionImageFilenames.map((fname) {
              final url = '$apiBaseUrl/$kvalPath/obrazy/$fname';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 100,
                      maxHeight: 500,
                    ),
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                ),
              );
            }).toList(),
      );
    } else if (_mediaKind == MediaKind.video) {
      Widget player;

      if (_uploadedVideoUrl != null) {
        player = InlineVideoPlayer(url: _uploadedVideoUrl!, height: 400);
      } else if (_videoBytes != null && _videoBytes!.isNotEmpty) {
        return FutureBuilder<String?>(
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
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: InlineVideoPlayer(
                url: kIsWeb ? null : null,
                filePath: kIsWeb ? null : snapshot.data,
                blobUrl: kIsWeb ? snapshot.data : null,
                height: 400,
              ),
            );
          },
        );
      } else {
        player = const SizedBox.shrink();
      }

      mediaWidget = Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: player,
      );
    } else if (_mediaKind == MediaKind.video && _uploadedVideoUrl != null) {
      mediaWidget = Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: InlineVideoPlayer(url: _uploadedVideoUrl!, height: 400),
      );
    }

    final answers =
        ['A', 'B', 'C', 'D'].asMap().entries.map((e) {
          final index = e.key;
          final letter = e.value;
          final isCorrect = letter == _correct;

          final ctrl = [_odp1Ctrl, _odp2Ctrl, _odp3Ctrl, _odp4Ctrl][index];
          final kind = [_odp1Kind, _odp2Kind, _odp3Kind, _odp4Kind][index];
          final body = ctrl.text.trim();

          String? url;
          Uint8List? bytes;
          switch (index) {
            case 0:
              url = _odp1UploadedImageUrl;
              bytes = _odp1ImageBytes;
              break;
            case 1:
              url = _odp2UploadedImageUrl;
              bytes = _odp2ImageBytes;
              break;
            case 2:
              url = _odp3UploadedImageUrl;
              bytes = _odp3ImageBytes;
              break;
            case 3:
              url = _odp4UploadedImageUrl;
              bytes = _odp4ImageBytes;
              break;
          }

          Widget child;

          if (kind == AnswerKind.text) {
            child = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$letter. '),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(body, style: const TextStyle(fontSize: 16)),
                ),
              ],
            );
          } else {
            child = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$letter.'),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _buildAnswerImage(url: url, bytes: bytes),
              ],
            );
          }

          return Container(
            margin: const EdgeInsets.only(top: 6),
            child: IgnorePointer(
              ignoring: true,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isCorrect ? extras.correct : colorScheme.surface,
                  foregroundColor: isCorrect ? Colors.black : defaultTextColor,
                  alignment: Alignment.centerLeft,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ).borderRadius,
                  ),
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                ),
                child: child,
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
