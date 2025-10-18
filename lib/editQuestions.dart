import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;


class EditQuestionsPage extends StatefulWidget {
  const EditQuestionsPage({super.key, required this.qualification});

  /// kwalifikacja np. "elm05" / "INF.03" (może mieć kropki i spacje)
  final String qualification;

  @override
  State<EditQuestionsPage> createState() => _EditQuestionsPageState();
}

class _EditQuestionsPageState extends State<EditQuestionsPage> {
  // ====== stałe i pomocniki dla trybu edycji ======
  // Ten sam <style> jaki dokładamy przy zapisie
static const _kStyleTag =
  '<style>img{display:block;max-width:100%;height:auto;margin:12px auto;}</style>';

// Wersja escapowana (np. gdy w bazie treść ma &lt;style&gt;…)
static final _kStyleTagEsc = const HtmlEscape().convert(_kStyleTag);

// RegExy dla <img ... image123.jpg> – raw i escapowane
static final _imgTagRawRe = RegExp(
  r'<img[^>]+src="https://interpage\.pl/egzaminy/[^/]+/obrazy/image\d+\.jpg"[^>]*\/?>',
  caseSensitive: false,
);

static final _imgTagEscRe = RegExp(
  r'&lt;img[^&]+src=&quot;https://interpage\.pl/egzaminy/[^/]+/obrazy/image\d+\.jpg&quot;[^&]*&gt;',
  caseSensitive: false,
);

 String _stripStyleAndImage(String html) {
  var out = html;

  // 1) Usuń <style> (raw i escapowane)
  out = out.replaceAll(_kStyleTag, '');
  out = out.replaceAll(_kStyleTagEsc, '');

  // 2) Usuń <img ... imageNNN.jpg> (raw i escapowane)
  out = out.replaceAll(_imgTagRawRe, '');
  out = out.replaceAll(_imgTagEscRe, '');

  // 3) Porządki
  out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
  return out;
}


  String _unescapeLtGt(String s) =>
      s.replaceAll('&lt;', '<').replaceAll('&gt;', '>');

  // do pól A–D: usuń prefiks "A. " / "B. " itd. i od-enkoduj &lt; &gt;
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

  // ====== ID nowego pytania (max istniejących + 1) ======
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

  // Wszystkie pytania
  List<dynamic> questions = [];

  // Filtrowanie po treści lub ID
  String searchText = '';

  // Kontroler listy
  final ScrollController _listController = ScrollController();

  // ====== Boczny panel – wyszukiwarka ======
  final TextEditingController _textSearchCtrl = TextEditingController();
  final ScrollController _leftPanelScroll = ScrollController();

  // ====== Formularz dodawania/edycji ======
  int? editingId; // jeśli != null -> edycja istniejącego pytania
  final TextEditingController _imageCtrl =
      TextEditingController(); // URL tylko do podglądu w edycji
  final TextEditingController _contentCtrl =
      TextEditingController(); // surowa treść pytania (bez <style>/<img>)
  final TextEditingController _odp1Ctrl = TextEditingController();
  final TextEditingController _odp2Ctrl = TextEditingController();
  final TextEditingController _odp3Ctrl = TextEditingController();
  final TextEditingController _odp4Ctrl = TextEditingController();

  final TextEditingController _imageHeightCtrl = TextEditingController(); // np. "320"
  int? _imageHeightPx; // null => auto

  // NOWE: opisy
  final TextEditingController _opisPoprawneCtrl = TextEditingController();
  final TextEditingController _opisNiepoprawneCtrl = TextEditingController();

  String _correct = 'A';

  // ====== Upload obrazka (UI) ======
  Uint8List? _imageBytes;
  String? _imageName;
  String? _uploadedImageUrl;
  String? _uploadedImageFilename; // <= NAZWA PLIKU (np. image10.jpg)
  bool _isUploading = false;

  bool _showPreview = false;

  void _refreshIfPreview() {
    if (_showPreview) setState(() {});
  }
  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
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
    final url =
        Uri.parse('https://interpage.pl/egzaminy/wyswietl_trudnosci.php');
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

  // ====== Filtrowanie ======
  void _applyTextFilter(String value) {
    setState(() {
      searchText = value.trim();
    });
  }

  // ====== Form actions ======
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
      _isUploading = false;
      _imageHeightPx = null;
      _imageHeightCtrl.clear();
    });
  }

  void _openForEdit(Map<String, dynamic> q) {
  setState(() {
    editingId = int.tryParse(q['id']?.toString() ?? '');

    final rawHtml = q['pytanie']?.toString() ?? '';

    final imgUrl = _extractFirstImageSrc(rawHtml) ?? '';
    _imageCtrl.text = imgUrl;
    _uploadedImageUrl = imgUrl.isNotEmpty ? imgUrl : null;

    // NOWE: odczyt wysokości <img style="height: Npx">
    _imageHeightPx = _parseImageHeightFromHtml(rawHtml);
    _imageHeightCtrl.text = _imageHeightPx?.toString() ?? '';

    final cleaned = _stripStyleAndImage(rawHtml);
    _contentCtrl.text = _unescapeLtGt(cleaned);

    _odp1Ctrl.text = _answerToUi(q['odp1']?.toString());
    _odp2Ctrl.text = _answerToUi(q['odp2']?.toString());
    _odp3Ctrl.text = _answerToUi(q['odp3']?.toString());
    _odp4Ctrl.text = _answerToUi(q['odp4']?.toString());

    _opisPoprawneCtrl.text    = q['opisPoprawne']?.toString() ?? '';
    _opisNiepoprawneCtrl.text = q['opisNiepoprawne']?.toString() ?? '';

    final poprawna = (q['poprawna']?.toString().toUpperCase() ?? 'A');
    _correct = ['A','B','C','D'].contains(poprawna) ? poprawna : 'A';

    _imageBytes = null;
    _imageName  = null;
  });
}

int? _parseImageHeightFromHtml(String html) {
  final imgStart = html.toLowerCase().indexOf('<img');
  if (imgStart == -1) return null;
  final imgEnd = html.indexOf('>', imgStart);
  if (imgEnd == -1) return null;
  final tag = html.substring(imgStart, imgEnd + 1);

  // style="... height: Npx ..."
  final styleRe = RegExp(
    r'''style\s*=\s*["']([^"']+)["']''', // raw + potrójne cudzysłowy
    caseSensitive: false,
  );
  final styleMatch = styleRe.firstMatch(tag);
  if (styleMatch == null) return null;

  final style = styleMatch.group(1)!;

  final hRe = RegExp(
    r'height\s*:\s*(\d+)\s*px',
    caseSensitive: false,
  );
  final hMatch = hRe.firstMatch(style);
  if (hMatch == null) return null;

  final v = int.tryParse(hMatch.group(1)!);
  if (v == null || v <= 0) return null;
  return v;
}


  String? _extractFirstImageSrc(String html) {
    final idx = html.indexOf('<img');
    if (idx == -1) return null;
    final srcIdx = html.indexOf('src=', idx);
    if (srcIdx == -1) return null;
    final quote =
        html.contains('src="') ? '"' : (html.contains("src='") ? "'" : '"');
    final qIdx = html.indexOf('src=$quote', idx);
    if (qIdx == -1) return null;
    final start = qIdx + 5; // src="
    final end = html.indexOf(quote, start);
    if (end == -1) return null;
    return html.substring(start, end);
  }

  String _escapeLtGt(String s) =>
    s.replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _buildPreviewHtml() {
  final escapedBody = _escapeLtGt(_contentCtrl.text.trim());

  // źródło obrazka: 1) URL po uploadzie 2) ręcznie wpisany URL 3) lokalny plik -> data URI
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
  final imgTag = (imgSrc == null)
      ? ''
      : '<img alt="" src="$imgSrc"${h != null ? ' style="height: ${h}px;"' : ''}/>';

  // identycznie jak na serwerze: style + escapowany body + (opcjonalnie) <img>
  return _kStyleTag + escapedBody + imgTag;
}


  // ====== Upload obrazka ======
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
        _imageBytes = bytes;
        _imageName = file.name;
        _uploadedImageUrl = null;
        _uploadedImageFilename = null;
      });
    } catch (e) {
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

    try {
      final uri = Uri.parse('https://interpage.pl/egzaminy/upload_image.php');
      final req = http.MultipartRequest('POST', uri)
        ..fields['kwalifikacja'] = _sanitizedTable()
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            _imageBytes!,
            filename: _imageName!,
            contentType: http_parser.MediaType(
              'image',
              _imageName!.split('.').last,
            ),
          ),
        );

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == true && data['url'] is String) {
          setState(() {
            _uploadedImageUrl = data['url'] as String?;
            _uploadedImageFilename =
                (data['filename'] as String?) ??
                    (_uploadedImageUrl != null
                        ? _filenameFromUrl(_uploadedImageUrl!)
                        : null);
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Obrazek został wgrany.')),
            );
          }
        } else {
          throw '❌ Nieprawidłowa odpowiedź serwera!';
        }
      } else {
        throw 'HTTP ${res.statusCode}';
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

  void _removeImage() {
    setState(() {
      _imageBytes = null;
      _imageName = null;
      _uploadedImageUrl = null;
      _uploadedImageFilename = null;
      _imageCtrl.clear();
    });
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
      height: _imageHeightPx?.toDouble(), // wykorzystaj wymuszoną wysokość jeśli chcesz
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

// Wspólny „szkielet” dialogu
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
                            child: builder(screen), // tu wstrzykujemy Image.*
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: Icon(Icons.close, size: 30,
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


  // ====== Zapis nowego/edytowanego pytania ======
  Future<void> _saveQuestion() async {
  // 1) Walidacja pól
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

  // 2) (opcjonalnie) upload obrazu teraz
  String? imageUrl;
  if (_imageBytes != null && _imageBytes!.isNotEmpty) {
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

      imageUrl = data['url'] as String;
      setState(() {
        _uploadedImageUrl = imageUrl;
        _uploadedImageFilename =
            (data['filename'] as String?) ?? _filenameFromUrl(imageUrl!);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Błąd uploadu obrazka: $e')),
      );
      return;
    }
  }

  // 3) jeśli nie uploadowano teraz, a jest istniejący URL — wyciągnij nazwę
  if (_uploadedImageFilename == null && _imageCtrl.text.trim().isNotEmpty) {
    _uploadedImageFilename = _filenameFromUrl(_imageCtrl.text.trim());
  }

  // 4) payload: surowe pola + (opcjonalnie) img_filename + (opcjonalnie) id
  final payload = <String, dynamic>{
  'egzamin': _sanitizedTable(),
  'pytanie': pyt,
  'odp1': a, 'odp2': b, 'odp3': c, 'odp4': d,
  'poprawna': _correct,
  'opisPoprawne': _opisPoprawneCtrl.text.trim(),
  'opisNiepoprawne': _opisNiepoprawneCtrl.text.trim(),
  if (_uploadedImageFilename != null && _uploadedImageFilename!.isNotEmpty)
    'img_filename': _uploadedImageFilename,
  if (editingId != null) 'id': editingId,

  // NOWE:
  if (_imageHeightPx != null && _imageHeightPx! > 0) 'img_height': _imageHeightPx,
};


  if (_uploadedImageFilename != null && _uploadedImageFilename!.isNotEmpty) {
    payload['img_filename'] = _uploadedImageFilename; // np. image10.jpg
  }
  if (editingId != null) {
    payload['id'] = editingId; // <<< KLUCZOWE: sygnalizuje UPDATE
  }

  // 5) wyślij do add_question.php (obsłuży add albo update)
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
    final int? savedId =
        (body['id'] is int) ? body['id'] as int : int.tryParse('${body['id']}');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isEdit
          ? '✅ Pytanie zaktualizowane (ID ${savedId ?? editingId})'
          : '✅ Pytanie dodane (ID ${savedId ?? '—'})')),
    );
    setState(() => _showPreview = false);
    _startNewQuestion();
    await _loadAll();
  } catch (e) {
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

  // ====== Render HTML ======
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
  TagExtension(
    tagsToExtend: {'img'},
    builder: (ctx) {
  final src = ctx.attributes['src'];

  // 1) Wysokość z atrybutów <img> (style/height) — ale w podglądzie
  //    ostatecznie i tak sterujemy przez _imageHeightPx:
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

  // W trybie podglądu zawsze używamy aktualnej `_imageHeightPx`
  if (_showPreview && _imageHeightPx != null) {
    forcedHeight = _imageHeightPx!.toDouble();
  }

  // 2) Funkcja, która opakowuje obraz w interaktywną "rączkę" resize
  Widget _wrapInteractive(Widget child) {
    final minH = 80;
    final maxH = 2000;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Listener(
          // scroll kółkiem myszy = zmiana wysokości
          onPointerSignal: (signal) {
            if (!_showPreview) return;
            if (signal is PointerScrollEvent) {
              int cur = _imageHeightPx ?? (forcedHeight?.round() ?? 320);
              // przewijanie w dół -> zmniejsz; w górę -> zwiększ
              final next = (cur - signal.scrollDelta.dy).clamp(minH, maxH).round();
              setState(() {
                _imageHeightPx = next;
                _imageHeightCtrl.text = next.toString();
              });
            }
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // przeciągnięcie w pionie = zmiana wysokości
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) {
                  if (!_showPreview) return;
                  int cur = _imageHeightPx ?? (forcedHeight?.round() ?? 320);
                  final next = (cur + details.delta.dy).clamp(minH, maxH).round();
                  setState(() {
                    _imageHeightPx = next;
                    _imageHeightCtrl.text = next.toString();
                  });
                },
                child: child,
              ),

              // uchwyt – wizualna "rączka" na dole
              if (_showPreview)
                Positioned(
                  bottom: 8,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUpDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.unfold_more, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            '${_imageHeightPx ?? forcedHeight?.round() ?? 320}px',
                            style: const TextStyle(color: Colors.white),
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

  // 3) Różne źródła obrazka
  if (src == null || src.isEmpty) {
    return Text(
      '⚠️ Brak obrazka',
      style: TextStyle(color: Theme.of(context).colorScheme.surface),
    );
  }

  // data:image/... (lokalny plik w podglądzie)
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

  // URL (sieciowy)
  return _wrapInteractive(
    Tooltip(
      message: _showPreview ? 'Przeciągnij / przewiń, aby zmienić wysokość' : 'Kliknij, aby powiększyć',
      child: MouseRegion(
        cursor: _showPreview ? SystemMouseCursors.resizeUpDown : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _showPreview ? null : () => _showImageDialog(context, src),
          child: Image.network(
            src,
            height: forcedHeight,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Text(
              '❌ Nie udało się załadować obrazka',
              style: TextStyle(color: Theme.of(context).colorScheme.surface),
            ),
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
      child: const Text(
        'TRUDNE',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ====== Widok ======
  List<dynamic> get _filteredQuestions {
    if (searchText.isEmpty) return questions;
    final q = searchText.toLowerCase();

    return questions.where((e) {
      final txt = (e['pytanie']?.toString() ?? '').toLowerCase();
      final a = (e['odp1']?.toString() ?? '').toLowerCase();
      final b = (e['odp2']?.toString() ?? '').toLowerCase();
      final c = (e['odp3']?.toString() ?? '').toLowerCase();
      final d = (e['odp4']?.toString() ?? '').toLowerCase();

      // NOWE: wyszukiwanie po ID
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

              // ======= OBRAZEK (opcjonalnie – UI) =======
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Obrazek (opcjonalnie)', style: labelStyle),
                    const SizedBox(height: 8),

                    if (_imageBytes == null &&
                        _uploadedImageUrl == null &&
                        _imageCtrl.text.trim().isEmpty)
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Wgraj obrazek'),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.image,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _uploadedImageUrl != null
                                      ? 'Wgrano: $_uploadedImageUrl'
                                      : (_imageName ?? 'Załadowany obrazek'),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_isUploading)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _imageHeightCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Wysokość obrazka [px] (puste = auto)',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) {
                                    final n = int.tryParse(v.trim());
                                    setState(() {
                                      _imageHeightPx = (n == null || n <= 0) ? null : n;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _imageHeightPx = null;
                                    _imageHeightCtrl.clear();
                                  });
                                },
                                child: const Text('Ustaw „auto”'),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _previewImage,
                                icon: const Icon(Icons.visibility),
                                label: const Text('Podgląd'),
                              ),
                              TextButton.icon(
                                onPressed: _removeImage,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Usuń'),
                              ),
                              TextButton.icon(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.swap_horiz),
                                label: const Text('Zmień plik'),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _contentCtrl,
                onChanged: (_) => _refreshIfPreview(),
                decoration: const InputDecoration(
                  labelText: 'Treść pytania',
                  border: OutlineInputBorder(),
                ),
                maxLines: 8,
                minLines: 8,
              ),
              const SizedBox(height: 16),

              // NOWE: opisy
              TextField(
                controller: _opisPoprawneCtrl,
                onChanged: (_) => _refreshIfPreview(),
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
                onChanged: (_) => _refreshIfPreview(),
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
                    decoration: const InputDecoration(
                      labelText: 'Odpowiedź A',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _odp2Ctrl,
                    onChanged: (_) => _refreshIfPreview(),
                    decoration: const InputDecoration(
                      labelText: 'Odpowiedź B',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _odp3Ctrl,
                    onChanged: (_) => _refreshIfPreview(),
                    decoration: const InputDecoration(
                      labelText: 'Odpowiedź C',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _odp4Ctrl,
                    onChanged: (_) => _refreshIfPreview(),
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
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showPreview = true),
                  icon: const Icon(Icons.visibility),
                  label: const Text('Zobacz podgląd'),
                ),
                ElevatedButton.icon(
                  onPressed: _saveQuestion,
                  icon: const Icon(Icons.save),
                  label: const Text('Zapisz'),
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
                // Nagłówek + badge
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

                // Odpowiedzi A–D (podgląd – disabled)
                ...['A', 'B', 'C', 'D'].map((litera) {
                  final odp = q['odp${'ABCD'.indexOf(litera) + 1}'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 240, 240, 240),
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                      ),
                      onPressed: null,
                      child: _html(odp ?? ""),
                    ),
                  );
                }),

                const SizedBox(height: 8),

                // Pasek akcji
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
  final html = _buildPreviewHtml();

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
              child: _html(html),
            ),
          ),
          const SizedBox(height: 8),
          // podgląd odpowiedzi A–D jak na liście
          // podgląd odpowiedzi A–D z prefiksami A./B./C./D.
          ...List.generate(4, (i) {
            final labels = ['A', 'B', 'C', 'D'];
            final texts  = [_odp1Ctrl.text, _odp2Ctrl.text, _odp3Ctrl.text, _odp4Ctrl.text];
            final label  = labels[i];
            final body   = _escapeLtGt(texts[i]);

            // tak samo jak po zapisie: "A. " + treść (zachowujemy HTML-renderer)
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
