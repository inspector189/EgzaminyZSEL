import 'package:flutter/material.dart';
import 'package:flutter_app/services/api_service.dart';
import 'package:flutter_app/utils/async_state_view.dart';
import 'package:flutter_app/utils/helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html_unescape_xx/html_unescape.dart';
import 'test_and_report_creation.dart';

// ─── Fake data toggle ────────────────────────────────────────────────────────

List<Map<String, dynamic>> _buildFakeQuestions(int count) => List.generate(
  count,
  (i) => {
    'id': '${i + 1}',
    'pytanie_text': 'Przykładowe pytanie nr ${i + 1} z kwalifikacji',
    'pytanie_images': <String>[],
    'pytanie_videos': <String>[],
    'odp1_text': 'Odpowiedź A',
    'odp1_images': <String>[],
    'odp2_text': 'Odpowiedź B',
    'odp2_images': <String>[],
    'odp3_text': 'Odpowiedź C',
    'odp3_images': <String>[],
    'odp4_text': 'Odpowiedź D',
    'odp4_images': <String>[],
  },
);
// ─────────────────────────────────────────────────────────────────────────────

enum TestCreationMode { random, manual }

class TestCreatorPage extends StatefulWidget {
  final String qualification;
  final TestCreationMode mode;

  const TestCreatorPage({
    super.key,
    required this.qualification,
    required this.mode,
  });

  @override
  State<TestCreatorPage> createState() => _TestCreatorPageState();
}

class _TestCreatorPageState extends State<TestCreatorPage> {
  final TextEditingController _nameController = TextEditingController();

  List<Map<String, dynamic>> allQuestions = [];
  final Set<String> _selectedIds = {};
  bool isLoading = true;
  bool isSaving = false;
  String? _errorMessage;

  String _userName = 'Nauczyciel';

  List<Map<String, dynamic>> get selectedQuestions => allQuestions
      .where((q) => _selectedIds.contains(q['id'] as String?))
      .toList();

  int get selectedCount => _selectedIds.length;
  bool get canSave =>
      selectedCount == 40 && _nameController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString('userName') ?? 'Nauczyciel';
    await _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      _errorMessage = null;
    });

    if (kUseFakeData) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      final fake = _buildFakeQuestions(120);
      setState(() {
        allQuestions = fake;
        isLoading = false;
        if (widget.mode == TestCreationMode.random) {
          _autoSelectRandom(fake);
        }
      });
      return;
    }

    try {
      final result = await ApiService.instance.fetchQuestions(
        widget.qualification,
      );
      if (!mounted) return;

      if (result.isSuccess && result.data != null) {
        final unescape = HtmlUnescapeSmall();
        final List<Map<String, dynamic>> data = (result.data!)
            .cast<Map<String, dynamic>>();

        for (final q in data) {
          q['pytanie_text'] = unescape.convert(q['pytanie'] ?? '');
          for (int i = 1; i <= 4; i++) {
            q['odp${i}_text'] = unescape.convert(q['odp$i'] ?? '');
          }
          q['pytanie_images'] = (q['images'] as List?)?.cast<String>() ?? [];
          q['pytanie_videos'] = (q['videos'] as List?)?.cast<String>() ?? [];
          for (int i = 1; i <= 4; i++) {
            q['odp${i}_images'] =
                (q['odp${i}_images'] as List?)?.cast<String>() ?? [];
            q['odp${i}_videos'] =
                (q['odp${i}_videos'] as List?)?.cast<String>() ?? [];
          }
        }

        setState(() {
          allQuestions = data;
          isLoading = false;
          if (widget.mode == TestCreationMode.random) {
            _autoSelectRandom(data);
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Błąd serwera (${result.statusCode})';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _autoSelectRandom(List<Map<String, dynamic>> questions) {
    final shuffled = List.of(questions)..shuffle();
    final take = shuffled.take(40).toList();
    _selectedIds
      ..clear()
      ..addAll(take.map((q) => q['id'] as String));
  }

  void _toggleQuestion(Map<String, dynamic> question) {
    final id = question['id'] as String;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (selectedCount < 40) {
        _selectedIds.add(id);
      }
    });
  }

  void _rerollQuestion(int index) {
    final current = selectedQuestions[index];
    final unselected = allQuestions
        .where((q) => !_selectedIds.contains(q['id'] as String))
        .toList();
    if (unselected.isEmpty) return;
    unselected.shuffle();
    setState(() {
      _selectedIds.remove(current['id'] as String);
      _selectedIds.add(unselected.first['id'] as String);
    });
  }

  void _reshuffleAll() {
    setState(() {
      _selectedIds.clear();
      _autoSelectRandom(allQuestions);
    });
  }

  Future<void> _saveTest() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || selectedCount != 40 || isSaving) return;

    setState(() => isSaving = true);

    final cleanQual = widget.qualification
        .replaceAll('.', '')
        .replaceAll(' ', '')
        .toLowerCase();

    final newTest = {
      'name': name,
      'qualification': cleanQual,
      'author': _userName,
      'createdAt': DateTime.now().toIso8601String(),
      'published': false,
      'results': <Map<String, dynamic>>[],
      'questions': selectedQuestions,
    };

    try {
      final result = await ApiService.instance.createTest(newTest);
      if (!mounted) return;

      final cs = Theme.of(context).colorScheme;

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Test zapisany! Przejdź do „Utworzone testy" → opublikuj',
            ),
            backgroundColor: cs.primary,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      } else if (result.isConflict) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage ??
                  'Test o takiej samej nazwie w tej kwalifikacji już istnieje!',
            ),
            backgroundColor: cs.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd zapisu testu (${result.statusCode})'),
            backgroundColor: cs.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Błąd połączenia z serwerem'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isRandom = widget.mode == TestCreationMode.random;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isRandom
              ? 'Losowy test – ${widget.qualification.toUpperCase()}'
              : 'Ręczny dobór pytań',
        ),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        iconTheme: IconThemeData(color: cs.onPrimary),
        actions: [
          if (isRandom && !isLoading)
            IconButton(
              icon: const Icon(Icons.shuffle_rounded),
              tooltip: 'Przetasuj wszystko',
              onPressed: _reshuffleAll,
            ),
        ],
      ),
      body: isLoading
          ? Center(
              child: AsyncStateView.loading(subtitle: 'Pobieranie pytań...'),
            )
          : _errorMessage != null
          ? Center(
              child: AsyncStateView.error(
                message: 'Błąd ładowania',
                subtitle: _errorMessage,
                icon: Icons.cloud_off_rounded,
              ),
            )
          // Warn user if bank has fewer than 40 questions
          : allQuestions.length < 40
          ? Center(
              child: AsyncStateView.empty(
                message: 'Za mało pytań',
                subtitle:
                    'Test zawiera tylko ${allQuestions.length} z 40 wymaganych pytań.',
                icon: Icons.warning_amber_rounded,
              ),
            )
          : Column(
              children: [
                _HeaderPanel(
                  nameController: _nameController,
                  selectedCount: selectedCount,
                  canSave: canSave,
                  isSaving: isSaving,
                  isRandom: isRandom,
                  onSave: _saveTest,
                  cs: cs,
                  tt: tt,
                ),
                Expanded(
                  child: isRandom
                      ? _RandomList(
                          questions: selectedQuestions,
                          qualification: widget.qualification,
                          onReroll: _rerollQuestion,
                          cs: cs,
                        )
                      : _ManualList(
                          questions: allQuestions,
                          selectedIds: _selectedIds,
                          selectedCount: selectedCount,
                          onToggle: _toggleQuestion,
                          cs: cs,
                          tt: tt,
                          qualification: widget.qualification,
                        ),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────
//                Header panel
// ─────────────────────────────────────────────

class _HeaderPanel extends StatelessWidget {
  const _HeaderPanel({
    required this.nameController,
    required this.selectedCount,
    required this.canSave,
    required this.isSaving,
    required this.isRandom,
    required this.onSave,
    required this.cs,
    required this.tt,
  });

  final TextEditingController nameController;
  final int selectedCount;
  final bool canSave;
  final bool isSaving;
  final bool isRandom;
  final VoidCallback onSave;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final progress = selectedCount / 40;
    final countColor = selectedCount == 40 ? cs.primary : cs.error;
    final nameEmpty = nameController.text.trim().isEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Name field
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Nazwa testu',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.title_rounded),
              // Show hint when name is empty so user knows why save is disabled
              helperText: nameEmpty ? 'Wymagane do zapisania testu' : null,
              helperStyle: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),

          // Progress row
          Row(
            children: [
              // Count badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: countColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: countColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '$selectedCount / 40',
                  style: tt.labelMedium?.copyWith(
                    color: countColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Progress bar
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation(countColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Save button
              FilledButton.icon(
                onPressed: canSave && !isSaving ? onSave : null,
                icon: isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onPrimary,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('Zapisz'),
              ),
            ],
          ),

          if (!canSave) ...[
            const SizedBox(height: 6),
            Text(
              selectedCount < 40
                  ? 'Wybierz jeszcze ${40 - selectedCount} ${_pytanLabel(40 - selectedCount)}'
                  : 'Podaj nazwę testu',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  static String _pytanLabel(int n) {
    if (n == 1) return 'pytanie';
    if (n >= 2 && n <= 4) return 'pytania';
    return 'pytań';
  }
}

// ─────────────────────────────────────────────
//              Random mode list
// ─────────────────────────────────────────────

class _RandomList extends StatelessWidget {
  const _RandomList({
    required this.questions,
    required this.qualification,
    required this.onReroll,
    required this.cs,
  });

  final List<Map<String, dynamic>> questions;
  final String qualification;
  final void Function(int index) onReroll;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: questions.length,
      itemBuilder: (context, i) {
        final q = questions[i];
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 44),
              child: RichQuestionWidget(
                question: q,
                number: i + 1,
                qualification: qualification,
              ),
            ),
            Positioned(
              right: 6,
              top: 0,
              bottom: 0,
              child: Center(
                child: Tooltip(
                  message: 'Zamień to pytanie',
                  child: Material(
                    color: cs.surface,
                    shape: const CircleBorder(),
                    elevation: 1.5,
                    shadowColor: cs.shadow.withValues(alpha: 0.2),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => onReroll(i),
                      child: Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.refresh_rounded,
                          size: 18,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//             Manual mode list
// ─────────────────────────────────────────────

class _ManualList extends StatefulWidget {
  const _ManualList({
    required this.questions,
    required this.selectedIds,
    required this.selectedCount,
    required this.onToggle,
    required this.cs,
    required this.tt,
    required this.qualification,
  });

  final List<Map<String, dynamic>> questions;
  final Set<String> selectedIds;
  final int selectedCount;
  final void Function(Map<String, dynamic>) onToggle;
  final ColorScheme cs;
  final TextTheme tt;
  final String qualification;

  @override
  State<_ManualList> createState() => _ManualListState();
}

class _ManualListState extends State<_ManualList> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchText = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchText.trim().isEmpty) return widget.questions;
    final q = _searchText.trim().toLowerCase();
    return widget.questions.where((question) {
      final text = (question['pytanie_text'] as String? ?? '').toLowerCase();
      final id = (question['id']?.toString() ?? '').toLowerCase();
      return text.contains(q) || id.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final tt = widget.tt;
    final filtered = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Szukaj pytania...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchText.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchText = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _searchText = v),
          ),
        ),
        if (_searchText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Znalezione: ${filtered.length} / ${widget.questions.length}',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'Brak wyników',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final q = filtered[i];
                    final id = q['id'] as String;
                    final isSelected = widget.selectedIds.contains(id);
                    final isDisabled =
                        !isSelected && widget.selectedCount >= 40;

                    return _SelectableQuestionCard(
                      question: q,
                      number: widget.questions.indexOf(q) + 1,
                      qualification: widget.qualification,
                      isSelected: isSelected,
                      isDisabled: isDisabled,
                      cs: cs,
                      onTap: isDisabled ? null : () => widget.onToggle(q),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Selectable wrapper around ExamQuestionCard
// ─────────────────────────────────────────────

class _SelectableQuestionCard extends StatelessWidget {
  const _SelectableQuestionCard({
    required this.question,
    required this.number,
    required this.qualification,
    required this.isSelected,
    required this.isDisabled,
    required this.cs,
    required this.onTap,
  });

  final Map<String, dynamic> question;
  final int number;
  final String qualification;
  final bool isSelected;
  final bool isDisabled;
  final ColorScheme cs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            IgnorePointer(
              child: RichQuestionWidget(
                question: question,
                number: number,
                qualification: qualification,
                accentColorOverride: isSelected ? cs.primary : null,
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isSelected ? cs.primary : cs.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? cs.primary
                        : cs.outlineVariant.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: isSelected
                    ? Icon(Icons.check_rounded, size: 16, color: cs.onPrimary)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
