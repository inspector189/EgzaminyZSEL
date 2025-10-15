import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;

class EditQuestionsPage extends StatefulWidget {
  const EditQuestionsPage({super.key, required this.qualification});

  /// kwalifikacja typu "elm05" (bez kropek/spacji)
  final String qualification;

  @override
  State<EditQuestionsPage> createState() => _EditQuestionsPageState();
}

class _EditQuestionsPageState extends State<EditQuestionsPage> {
  bool isLoading = true;

  // Wszystkie pytania (oryginał)
  List<dynamic> questions = [];

  // Filtrowanie po treści
  String searchText = '';

  // Kontroler listy i klucze elementów, by skakać do ID
  final ScrollController _listController = ScrollController();

  // ====== Boczny panel – wyszukiwarka ======
  final TextEditingController _textSearchCtrl = TextEditingController();

  // ====== Boczny panel – formularz dodawania/edycji ======
  int? editingId; // jeśli != null -> edycja istniejącego pytania
  final TextEditingController _imageCtrl = TextEditingController();
  final TextEditingController _contentCtrl = TextEditingController(); // pytanie (HTML)
  final TextEditingController _odp1Ctrl = TextEditingController();
  final TextEditingController _odp2Ctrl = TextEditingController();
  final TextEditingController _odp3Ctrl = TextEditingController();
  final TextEditingController _odp4Ctrl = TextEditingController();
  String _correct = 'A';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _listController.dispose();
    _textSearchCtrl.dispose();
    _imageCtrl.dispose();
    _contentCtrl.dispose();
    _odp1Ctrl.dispose();
    _odp2Ctrl.dispose();
    _odp3Ctrl.dispose();
    _odp4Ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => isLoading = true);
    try {
      final qs = await _fetchQuestions(widget.qualification);
      final trud = await _fetchAllTrudnosci();

      // dociągnij trudności do pytań
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

      // wyczyść klucze (zbudujemy przy renderze)
      //_itemKeys.clear();

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

  // ====== Boczny panel – akcje ======

  void _applyTextFilter(String value) {
    setState(() {
      searchText = value.trim();
    });
  }

/*  void _jumpToId() {
    final id = int.tryParse(_idSearchCtrl.text.trim());
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaj poprawne ID (liczba całkowita).')),
      );
      return;
    }
    final key = _itemKeys[id];
    if (key == null || key.currentContext == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie znaleziono pytania o ID $id.')),
      );
      return;
    }
    Scrollable.ensureVisible(
      key.currentContext!,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
*/
  void _startNewQuestion() {
    setState(() {
      editingId = null;
      _imageCtrl.clear();
      _contentCtrl.clear();
      _odp1Ctrl.clear();
      _odp2Ctrl.clear();
      _odp3Ctrl.clear();
      _odp4Ctrl.clear();
      _correct = 'A';
    });
  }

  void _openForEdit(Map<String, dynamic> q) {
    setState(() {
      editingId = int.tryParse(q['id'].toString());
      // heurystyka: pytanie może zawierać <img>, wyciągaj src jeśli chcesz – dla prostoty dajemy ręczne pole URL
      _imageCtrl.text = _extractFirstImageSrc(q['pytanie']?.toString() ?? '') ?? '';
      _contentCtrl.text = q['pytanie']?.toString() ?? '';
      _odp1Ctrl.text = q['odp1']?.toString() ?? '';
      _odp2Ctrl.text = q['odp2']?.toString() ?? '';
      _odp3Ctrl.text = q['odp3']?.toString() ?? '';
      _odp4Ctrl.text = q['odp4']?.toString() ?? '';
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

  Future<void> _saveQuestion() async {
    // payload (dopasujemy do backendu, gdy podasz endpoint)
    final payload = {
      if (editingId != null) 'id': editingId,
      'kwalifikacja': widget.qualification,
      'image': _imageCtrl.text.trim(), // opcjonalny URL obrazka
      'pytanie': _contentCtrl.text.trim(),
      'odp1': _odp1Ctrl.text.trim(),
      'odp2': _odp2Ctrl.text.trim(),
      'odp3': _odp3Ctrl.text.trim(),
      'odp4': _odp4Ctrl.text.trim(),
      'poprawna': _correct,
    };

    // ✅ Walidacja podstawowa — poprawnie sprawdza puste pola
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


    // TODO: Wyślij na API (np. add_question.php / update_question.php)
    // final res = await http.post( ... );
    // if (res.statusCode == 200) { await _loadAll(); }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Podgląd zapisu (TODO API): ${jsonEncode(payload)}')),
    );
  }

  Future<void> _deleteQuestion(int id) async {
    // TODO: usuń po API i odśwież listę
    // await http.post('.../delete_question.php', body: {'id': '$id'});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Usuwanie (TODO API) – ID: $id')),
    );
  }

  // ====== Render HTML (jak w trybie "wszystkie") ======

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
                                    color:
                                        Theme.of(context).colorScheme.surface,
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

    final diff = (trudnosc is num
            ? trudnosc
            : int.tryParse(trudnosc.toString()) ?? 0)
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
        title: Text('🛠️ Edytor pytań — ${widget.qualification.toUpperCase()}'),
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
          // PANEL BOCZNY – stała szerokość, brak scrolla
          SizedBox(
            width: 420, // było 360
            child: leftPanel,
          ),

          // pionowy separator
          Container(width: 1, color: Theme.of(context).dividerColor),

          // LISTA – skrolowana niezależnie
          Expanded(
            child: rightList,
          ),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sekcja wyszukiwania
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

          // Sekcja formularza dodawania/edycji
          Row(
            children: [
              Text(
                editingId == null ? '➕ Dodaj nowe pytanie' : '✏️ Edytujesz ID $editingId',
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

          // UWAGA: bez scrolla – zachowaj zwięzłość pól
          TextField(
            controller: _imageCtrl,
            decoration: const InputDecoration(
              labelText: 'URL obrazka (opcjonalnie)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _contentCtrl,
            decoration: const InputDecoration(
              labelText: 'Treść pytania (HTML do flutter_html)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            minLines: 3,
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _odp1Ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Odpowiedź A',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _odp2Ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Odpowiedź B',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _odp3Ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Odpowiedź C',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _odp4Ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Odpowiedź D',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

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
        return Container(
          child: Card(
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

                  // Odpowiedzi A–D (podgląd – przyciski disabled)
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
                                      builder: (_) => AlertDialog(
                                        title: const Text('Usuń pytanie'),
                                        content: Text(
                                          'Na pewno chcesz usunąć pytanie ID $id?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Anuluj'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Usuń'),
                                          ),
                                        ],
                                      ),
                                    ) ??
                                    false;
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
          ),
        );
      },
    );
  }
}
