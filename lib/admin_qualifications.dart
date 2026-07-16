import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//                 Data models
// ─────────────────────────────────────────────

class QualificationData {
  final String code;
  final String description;
  final String emoji;

  const QualificationData({
    required this.code,
    required this.description,
    required this.emoji,
  });

  QualificationData copyWith({
    String? code,
    String? description,
    String? emoji,
  }) => QualificationData(
    code: code ?? this.code,
    description: description ?? this.description,
    emoji: emoji ?? this.emoji,
  );
}

class ProfessionData {
  final String name;
  final String emoji;
  final List<QualificationData> qualifications;

  const ProfessionData({
    required this.name,
    required this.emoji,
    required this.qualifications,
  });

  ProfessionData copyWith({
    String? name,
    String? emoji,
    List<QualificationData>? qualifications,
  }) => ProfessionData(
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    qualifications: qualifications ?? this.qualifications,
  );
}

// ─────────────────────────────────────────────
//             QualificationsStore
// ─────────────────────────────────────────────

class QualificationsStore extends ChangeNotifier {
  static final instance = QualificationsStore._();
  QualificationsStore._();

  final List<QualificationData> _qualifications = [];
  final List<ProfessionData> _professions = [];

  List<QualificationData> get qualifications =>
      List.unmodifiable(_qualifications);
  List<ProfessionData> get professions => List.unmodifiable(_professions);

  void addQualification(QualificationData q) {
    _qualifications.add(q);
    notifyListeners();
  }

  void updateQualification(int index, QualificationData q) {
    _qualifications[index] = q;
    notifyListeners();
  }

  void addProfession(ProfessionData p) {
    _professions.add(p);
    notifyListeners();
  }

  void updateProfession(int index, ProfessionData p) {
    _professions[index] = p;
    notifyListeners();
  }
}

// ─────────────────────────────────────────────
//                  Emoji picker
// ─────────────────────────────────────────────

Future<String?> showEmojiPicker(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  String? picked;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => SizedBox(
      height: 420,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: EmojiPicker(
              onEmojiSelected: (_, emoji) {
                picked = emoji.emoji;
                Navigator.pop(context);
              },
              config: Config(
                height: 380,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  backgroundColor: cs.surface,
                  emojiSizeMax:
                      28 *
                      (defaultTargetPlatform == TargetPlatform.iOS
                          ? 1.20
                          : 1.0),
                ),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: cs.surface,
                  buttonIconColor: cs.primary,
                ),
                categoryViewConfig: CategoryViewConfig(
                  backgroundColor: cs.surface,
                  iconColor: cs.onSurfaceVariant,
                  iconColorSelected: cs.primary,
                  indicatorColor: cs.primary,
                ),
                bottomActionBarConfig: BottomActionBarConfig(
                  backgroundColor: cs.surface,
                  buttonIconColor: cs.onSurfaceVariant,
                ),
                viewOrderConfig: const ViewOrderConfig(
                  top: EmojiPickerItem.categoryBar,
                  middle: EmojiPickerItem.emojiView,
                  bottom: EmojiPickerItem.searchBar,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  return picked;
}

// ─────────────────────────────────────────────
//             Emoji selector button
// ─────────────────────────────────────────────

class _EmojiButton extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;

  const _EmojiButton({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Zmień emoji',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 30)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//                Section header
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;

  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label.toUpperCase(),
          style: tt.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: cs.primary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//         Qualification form dialog
// ─────────────────────────────────────────────

class QualificationFormDialog extends StatefulWidget {
  final QualificationData? existing;
  final int? editIndex;

  const QualificationFormDialog({super.key, this.existing, this.editIndex});

  static Future<void> show(
    BuildContext context, {
    QualificationData? existing,
    int? editIndex,
  }) => showDialog(
    context: context,
    builder: (_) =>
        QualificationFormDialog(existing: existing, editIndex: editIndex),
  );

  @override
  State<QualificationFormDialog> createState() =>
      _QualificationFormDialogState();
}

class _QualificationFormDialogState extends State<QualificationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _description;
  late String _emoji;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.existing?.code ?? '');
    _description = TextEditingController(
      text: widget.existing?.description ?? '',
    );
    _emoji = widget.existing?.emoji ?? '📋';
  }

  @override
  void dispose() {
    _code.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickEmoji() async {
    final picked = await showEmojiPicker(context);
    if (picked != null) setState(() => _emoji = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final q = QualificationData(
      code: _code.text.trim().toUpperCase(),
      description: _description.text.trim(),
      emoji: _emoji,
    );
    if (widget.editIndex != null) {
      QualificationsStore.instance.updateQualification(widget.editIndex!, q);
    } else {
      QualificationsStore.instance.addQualification(q);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isEdit = widget.existing != null;

    return AlertDialog(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.school_rounded,
              size: 18,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isEdit ? 'Edytuj kwalifikację' : 'Dodaj kwalifikację',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      _EmojiButton(emoji: _emoji, onTap: _pickEmoji),
                      const SizedBox(height: 4),
                      Text(
                        'Emoji',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _code,
                      decoration: InputDecoration(
                        labelText: 'Kod kwalifikacji',
                        hintText: 'np. INF.03',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: cs.surfaceContainerLow,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Podaj kod kwalifikacji';
                        }
                        final exists = QualificationsStore
                            .instance
                            .qualifications
                            .where((q) => q.code == v.trim().toUpperCase())
                            .where((_) => widget.editIndex == null)
                            .isNotEmpty;
                        if (exists) return 'Ten kod już istnieje';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                decoration: InputDecoration(
                  labelText: 'Opis kwalifikacji',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Podaj opis' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: Icon(isEdit ? Icons.save_rounded : Icons.add_rounded),
          label: Text(isEdit ? 'Zapisz' : 'Dodaj'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//           Profession form dialog
// ─────────────────────────────────────────────

class ProfessionFormDialog extends StatefulWidget {
  final ProfessionData? existing;
  final int? editIndex;

  const ProfessionFormDialog({super.key, this.existing, this.editIndex});

  static Future<void> show(
    BuildContext context, {
    ProfessionData? existing,
    int? editIndex,
  }) => showDialog(
    context: context,
    builder: (_) =>
        ProfessionFormDialog(existing: existing, editIndex: editIndex),
  );

  @override
  State<ProfessionFormDialog> createState() => _ProfessionFormDialogState();
}

class _ProfessionFormDialogState extends State<ProfessionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late String _emoji;
  late Set<String> _selectedCodes;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _emoji = widget.existing?.emoji ?? '💼';
    _selectedCodes =
        widget.existing?.qualifications.map((q) => q.code).toSet() ?? {};
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickEmoji() async {
    final picked = await showEmojiPicker(context);
    if (picked != null) setState(() => _emoji = picked);
  }

  void _submit() {
    final cs = Theme.of(context).colorScheme;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Wybierz co najmniej jedną kwalifikację'),
          backgroundColor: cs.error,
        ),
      );
      return;
    }
    final allQuals = QualificationsStore.instance.qualifications;
    final linked = allQuals
        .where((q) => _selectedCodes.contains(q.code))
        .toList();
    final p = ProfessionData(
      name: _name.text.trim(),
      emoji: _emoji,
      qualifications: linked,
    );
    if (widget.editIndex != null) {
      QualificationsStore.instance.updateProfession(widget.editIndex!, p);
    } else {
      QualificationsStore.instance.addProfession(p);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final allQuals = QualificationsStore.instance.qualifications;
    final isEdit = widget.existing != null;

    return AlertDialog(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.work_rounded,
              size: 18,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isEdit ? 'Edytuj zawód' : 'Dodaj zawód',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      _EmojiButton(emoji: _emoji, onTap: _pickEmoji),
                      const SizedBox(height: 4),
                      Text(
                        'Emoji',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _name,
                      decoration: InputDecoration(
                        labelText: 'Nazwa zawodu',
                        hintText: 'np. Programista',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: cs.surfaceContainerLow,
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Podaj nazwę' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Qualifications section header
              _SectionHeader(
                label: 'Kwalifikacje',
                count: _selectedCodes.length,
              ),
              const SizedBox(height: 10),

              if (allQuals.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Najpierw dodaj kwalifikacje',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    children: allQuals.asMap().entries.map((e) {
                      final q = e.value;
                      final isLast = e.key == allQuals.length - 1;
                      final selected = _selectedCodes.contains(q.code);
                      return Column(
                        children: [
                          InkWell(
                            onTap: () => setState(
                              () => selected
                                  ? _selectedCodes.remove(q.code)
                                  : _selectedCodes.add(q.code),
                            ),
                            borderRadius: BorderRadius.vertical(
                              top: e.key == 0
                                  ? const Radius.circular(10)
                                  : Radius.zero,
                              bottom: isLast
                                  ? const Radius.circular(10)
                                  : Radius.zero,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    q.emoji,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          q.code,
                                          style: tt.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: selected
                                                ? cs.primary
                                                : cs.onSurface,
                                          ),
                                        ),
                                        Text(
                                          q.description,
                                          style: tt.bodySmall?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Checkbox(
                                    value: selected,
                                    activeColor: cs.primary,
                                    onChanged: (val) => setState(
                                      () => val == true
                                          ? _selectedCodes.add(q.code)
                                          : _selectedCodes.remove(q.code),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!isLast)
                            Divider(
                              height: 1,
                              color: cs.outlineVariant.withValues(alpha: 0.35),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: Icon(isEdit ? Icons.save_rounded : Icons.add_rounded),
          label: Text(isEdit ? 'Zapisz' : 'Dodaj'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//               Management page
// ─────────────────────────────────────────────

class ManageQualificationsPage extends StatefulWidget {
  const ManageQualificationsPage({super.key});

  @override
  State<ManageQualificationsPage> createState() =>
      _ManageQualificationsPageState();
}

class _ManageQualificationsPageState extends State<ManageQualificationsPage> {
  @override
  void initState() {
    super.initState();
    QualificationsStore.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    QualificationsStore.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final store = QualificationsStore.instance;
    final screenWidth = MediaQuery.of(context).size.width;
    const double kMaxContent = 900.0;
    final double contentWidth = screenWidth < 600
        ? screenWidth - 32
        : (screenWidth * 0.90).clamp(0.0, kMaxContent);
    final double hPad = ((screenWidth - contentWidth) / 2).clamp(
      20.0,
      double.infinity,
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kwalifikacje i zawody'),
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          iconTheme: IconThemeData(color: cs.onPrimary),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.school_rounded), text: 'Kwalifikacje'),
              Tab(icon: Icon(Icons.work_rounded), text: 'Zawody'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _QualificationsTab(
              qualifications: store.qualifications,
              hPad: hPad,
            ),
            _ProfessionsTab(
              professions: store.professions,
              hasQualifications: store.qualifications.isNotEmpty,
              hPad: hPad,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//             Qualifications tab
// ─────────────────────────────────────────────

class _QualificationsTab extends StatelessWidget {
  final List<QualificationData> qualifications;
  final double hPad;

  const _QualificationsTab({required this.qualifications, required this.hPad});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionHeader(
                  label: 'Kwalifikacje',
                  count: qualifications.length,
                ),
                FilledButton.icon(
                  onPressed: () => QualificationFormDialog.show(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Dodaj'),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        if (qualifications.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.school_outlined,
                      size: 40,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Brak kwalifikacji',
                    style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Dodaj pierwszą kwalifikację',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _QualificationCard(data: qualifications[i], index: i),
                ),
                childCount: qualifications.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _QualificationCard extends StatelessWidget {
  final QualificationData data;
  final int index;

  const _QualificationCard({required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Emoji badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(data.emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          data.code,
                          style: tt.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.onPrimaryContainer,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    data.description,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.edit_outlined, color: cs.primary),
              tooltip: 'Edytuj',
              onPressed: () => QualificationFormDialog.show(
                context,
                existing: data,
                editIndex: index,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//               Professions tab
// ─────────────────────────────────────────────

class _ProfessionsTab extends StatelessWidget {
  final List<ProfessionData> professions;
  final bool hasQualifications;
  final double hPad;

  const _ProfessionsTab({
    required this.professions,
    required this.hasQualifications,
    required this.hPad,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionHeader(label: 'Zawody', count: professions.length),
                Tooltip(
                  message: hasQualifications
                      ? ''
                      : 'Najpierw dodaj kwalifikacje',
                  child: FilledButton.icon(
                    onPressed: hasQualifications
                        ? () => ProfessionFormDialog.show(context)
                        : null,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Dodaj'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!hasQualifications)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Dodaj najpierw kwalifikacje, aby móc tworzyć zawody.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        if (professions.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.work_outline_rounded,
                      size: 40,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Brak zawodów',
                    style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Dodaj pierwszy zawód',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ProfessionCard(data: professions[i], index: i),
                ),
                childCount: professions.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfessionCard extends StatelessWidget {
  final ProfessionData data;
  final int index;

  const _ProfessionCard({required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(data.emoji, style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.name,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${data.qualifications.length} kwalifikacji',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: cs.primary),
                  tooltip: 'Edytuj',
                  onPressed: () => ProfessionFormDialog.show(
                    context,
                    existing: data,
                    editIndex: index,
                  ),
                ),
              ],
            ),
          ),

          // Qualification chips
          if (data.qualifications.isNotEmpty) ...[
            Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: data.qualifications
                    .map(
                      (q) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(q.emoji, style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 5),
                            Text(
                              q.code,
                              style: tt.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
