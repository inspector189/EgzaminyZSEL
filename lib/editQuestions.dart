import 'dart:convert';
import 'dart:typed_data';

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

  // Filtrowanie po treści
  String searchText = '';

  // Kontroler listy
  final ScrollController _listController = ScrollController();

  // ====== Boczny panel – wyszukiwarka ======
  final TextEditingController _textSearchCtrl = TextEditingController();
final ScrollController _leftPanelScroll = ScrollController();

  // ====== Formularz dodawania/edycji ======
  int? editingId; // jeśli != null -> edycja istniejącego pytania
  final TextEditingController _imageCtrl = TextEditingController(); // URL gdy edycja
  final TextEditingController _contentCtrl = TextEditingController(); // pytanie (HTML)
  final TextEditingController _odp1Ctrl = TextEditingController();
  final TextEditingController _odp2Ctrl = TextEditingController();
  final TextEditingController _odp3Ctrl = TextEditingController();
  final TextEditingController _odp4Ctrl = TextEditingController();

  // NOWE: opisy
  final TextEditingController _opisPoprawneCtrl = TextEditingController();
  final TextEditingController _opisNiepoprawneCtrl = TextEditingController();

  String _correct = 'A';

  // ====== Upload obrazka (UI na przyszłość) ======
  Uint8List? _imageBytes;
  String? _imageName;
  String? _uploadedImageUrl;
  bool _isUploading = false;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd ładowania: $e')),
      );
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
      throw 'Nieprawidłowy format danych pytań';
    }
    throw 'HTTP ${res.statusCode} przy pobieraniu pytań';
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

  // ====== Filtrowanie ======
  void _applyTextFilter(String value) {
    setState(() {
      searchText = value.trim();
    });
  }

  // ====== Form actions ======
  void _startNewQuestion() {
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
      _isUploading = false;
    });
  }

  void _openForEdit(Map<String, dynamic> q) {
    setState(() {
      editingId = int.tryParse(q['id'].toString());
      final imgUrl = _extractFirstImageSrc(q['pytanie']?.toString() ?? '') ?? '';
      _imageCtrl.text = imgUrl;
      _uploadedImageUrl = imgUrl.isNotEmpty ? imgUrl : null;
      _imageBytes = null;
      _imageName = null;

      _contentCtrl.text = q['pytanie']?.toString() ?? '';
      _odp1Ctrl.text = q['odp1']?.toString() ?? '';
      _odp2Ctrl.text = q['odp2']?.toString() ?? '';
      _odp3Ctrl.text = q['odp3']?.toString() ?? '';
      _odp4Ctrl.text = q['odp4']?.toString() ?? '';
      _opisPoprawneCtrl.text = q['opisPoprawne']?.toString() ?? '';
      _opisNiepoprawneCtrl.text = q['opisNiepoprawne']?.toString() ?? '';
      final poprawna = (q['poprawna']?.toString().toUpperCase() ?? 'A');
      _correct = ['A', 'B', 'C', 'D'].contains(poprawna) ? poprawna : 'A';
    });
  }

  String? _extractFirstImageSrc(String html) {
    final idx = html.indexOf('<img');
    if (idx == -1) return null;
    final srcIdx = html.indexOf('src=', idx);
    if (srcIdx == -1) return null;
    final quote = html.contains('src="') ? '"' : (html.contains("src='") ? "'" : '"');
    final qIdx = html.indexOf('src=$quote', idx);
    if (qIdx == -1) return null;
    final start = qIdx + 5; // src="
    final end = html.indexOf(quote, start);
    if (end == -1) return null;
    return html.substring(start, end);
  }

  // ====== Upload obrazka (UI; upload obsłużysz później) ======
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
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się otworzyć selektora plików: $e')),
      );
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
            contentType: http_parser.MediaType('image', _imageName!.split('.').last),
          ),
        );

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == true && data['url'] is String) {
          setState(() => _uploadedImageUrl = data['url']);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Obrazek wgrany.')),
          );
        } else {
          throw 'Nieprawidłowa odpowiedź serwera';
        }
      } else {
        throw 'HTTP ${res.statusCode}';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd uploadu: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _removeImage() {
    setState(() {
      _imageBytes = null;
      _imageName = null;
      _uploadedImageUrl = null;
      _imageCtrl.clear();
    });
  }

  void _previewImage() {
    final src = _uploadedImageUrl ?? _imageCtrl.text.trim();
    if (src.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brak obrazka do podglądu.')),
      );
      return;
    }
    _showImageDialog(context, src);
  }

  // ====== Zapis nowego/edytowanego pytania ======
  String _sanitizeForDb(String s) =>
      s.replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  Future<void> _saveQuestion() async {
    // (Na razie) obrazek pomijamy w zapisie nowego pytania – backend dodamy później.
    final payload = {
      'egzamin': _sanitizedTable(),
      'pytanie': _sanitizeForDb(_contentCtrl.text.trim()),
      'odp1': _sanitizeForDb(_odp1Ctrl.text.trim()),
      'odp2': _sanitizeForDb(_odp2Ctrl.text.trim()),
      'odp3': _sanitizeForDb(_odp3Ctrl.text.trim()),
      'odp4': _sanitizeForDb(_odp4Ctrl.text.trim()),
      'poprawna': _correct,
      'opisPoprawne': _sanitizeForDb(_opisPoprawneCtrl.text.trim()),
      'opisNiepoprawne': _sanitizeForDb(_opisNiepoprawneCtrl.text.trim()),
    };

    // Walidacja
    if ((payload['pytanie'] as String).isEmpty ||
        (payload['odp1'] as String).isEmpty ||
        (payload['odp2'] as String).isEmpty ||
        (payload['odp3'] as String).isEmpty ||
        (payload['odp4'] as String).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uzupełnij treść i wszystkie odpowiedzi.')),
      );
      return;
    }

    try {
      final uri = Uri.parse('https://interpage.pl/egzaminy/add_question.php');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode(payload),
      );

      if (res.statusCode != 200) {
        throw 'HTTP ${res.statusCode}: ${res.body}';
      }

      final body = jsonDecode(res.body);
      if (body is! Map || body['ok'] != true) {
        throw body['error'] ?? 'Nieznany błąd serwera';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Pytanie dodane')),
      );

      // wyczyść formularz i odśwież listę
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
    final uri = Uri.parse('https://interpage.pl/egzaminy/delete_question.php');
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^',
      },
      body: jsonEncode({
        'egzamin': _sanitizedTable(), // np. "elm05"
        'id': id,
      }),
    );

    if (res.statusCode != 200) {
      throw 'HTTP ${res.statusCode}: ${res.body}';
    }
    final body = jsonDecode(res.body);
    if (body['ok'] != true) throw body['error'] ?? 'Błąd usuwania';

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Pytanie usunięte')),
    );
    await _loadAll(); // odśwież listę
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ Błąd usuwania: $e')),
    );
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
            if (src == null) {
              return Text(
                '⚠️ Brak obrazka',
                style: TextStyle(color: Theme.of(context).colorScheme.surface),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Builder(
                builder: (context) => Center(
                  child: Tooltip(
                    message: 'Kliknij, aby powiększyć',
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _showImageDialog(context, src),
                        child: Image.network(
                          src,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Text(
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
    final iloscOdp = int.tryParse(q['ilosc_odpowiedzi']?.toString() ?? '') ?? 0;
    if (trudnosc == null || iloscOdp < 5) return const SizedBox.shrink();

    final diff = (trudnosc is num ? trudnosc : int.tryParse(trudnosc.toString()) ?? 0).toInt();
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
      return txt.contains(q) || a.contains(q) || b.contains(q) || c.contains(q) || d.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final leftPanel = _buildLeftPanel(context);
    final rightList = isLoading
        ? const Center(child: CircularProgressIndicator())
        : _buildList();

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

  // całość panelu jest skrolowana
  return Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Scrollbar(
      controller: _leftPanelScroll,
      thumbVisibility: true, // w razie czego możesz wyłączyć
      child: SingleChildScrollView(
        controller: _leftPanelScroll,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- wszystko co miałeś dotąd w panelu ---
            Text('🔎 Wyszukaj', style: labelStyle),
            const SizedBox(height: 8),
            TextField(
              controller: _textSearchCtrl,
              decoration: const InputDecoration(
                labelText: 'Szukaj w treści/odpowiedziach',
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
                      ? '➕ Dodaj nowe pytanie${_nextId != null ? ' (ID ${_nextId})' : ''}'
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
                          Icon(Icons.image,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary),
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
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_imageBytes != null && _uploadedImageUrl == null)
                            ElevatedButton.icon(
                              onPressed: _isUploading ? null : _uploadImage,
                              icon: const Icon(Icons.cloud_upload),
                              label: const Text('Wyślij na serwer'),
                            ),
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
            decoration: const InputDecoration(
              labelText: 'Treść pytania (HTML do flutter_html)',
              border: OutlineInputBorder(),
            ),
            maxLines: 8,
            minLines: 8,
          ),
          const SizedBox(height: 16),

          // NOWE: opisy
          TextField(
            controller: _opisPoprawneCtrl,
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
                decoration: const InputDecoration(
                  labelText: 'Odpowiedź B',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _odp3Ctrl,
                decoration: const InputDecoration(
                  labelText: 'Odpowiedź C',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _odp4Ctrl,
                decoration: const InputDecoration(
                  labelText: 'Odpowiedź D',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),

          Row(
            children: [
              const Text('Poprawna:'),
              const SizedBox(width: 8),
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
              const Spacer(),
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
                                content: Text('Na pewno chcesz usunąć pytanie ID $id?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogCtx, false),
                                    child: const Text('Anuluj'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(dialogCtx, true),
                                    child: const Text('Usuń'),
                                  ),
                                ],
                              ),
                            ) ?? false;

                            if (!mounted) return;        // ✅ po await
                            if (ok) {
                              await _deleteQuestion(id); // ✅ wywołanie po dialogu
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
}
