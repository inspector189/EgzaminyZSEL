import 'dart:async' show Timer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '/report_selection.dart';
import '/exam_preview.dart';

import '/services/api_service.dart';
import '/utils/async_state_view.dart';
import '/utils/app_themes.dart';
import 'utils/helpers.dart';
import '/widgets/search_bar.dart' as search_bar;

class _FilterParams {
  const _FilterParams({
    this.search = '',
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.qualification,
  });
  final String search;
  final DateTime? startDate;
  final DateTime? endDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final String? qualification;

  bool get isActive =>
      search.isNotEmpty ||
      startDate != null ||
      endDate != null ||
      startTime != null ||
      endTime != null ||
      qualification != null;
}

class _StatsResult {
  const _StatsResult({
    required this.filteredResults,
    required this.filteredUsers,
    required this.qualifications,
  });
  final List<dynamic> filteredResults;
  final List<Map<String, dynamic>> filteredUsers;
  final Map<String, List<dynamic>> qualifications;
}

_StatsResult _computeStats(List<dynamic> allResults, _FilterParams f) {
  final filteredResults = allResults.where((exam) {
    final examDate = DateTime.tryParse(exam['data_czas'] ?? '');
    if (examDate == null) return false;

    if (f.startDate != null && examDate.isBefore(f.startDate!)) return false;
    if (f.endDate != null &&
        examDate.isAfter(f.endDate!.add(const Duration(days: 1)))) {
      return false;
    }
    if (f.startTime != null) {
      final examMins = examDate.hour * 60 + examDate.minute;
      final startMins = f.startTime!.hour * 60 + f.startTime!.minute;
      if (examMins < startMins) return false;
    }
    if (f.endTime != null) {
      final examMins = examDate.hour * 60 + examDate.minute;
      final endMins = f.endTime!.hour * 60 + f.endTime!.minute;
      if (examMins > endMins) return false;
    }
    if (f.qualification != null &&
        (exam['kwalifikacja'] ?? '').toString() != f.qualification) {
      return false;
    }
    return true;
  }).toList();

  final Map<String, List<dynamic>> usersByUid = {};
  for (final exam in filteredResults) {
    final uid = (exam['UID'] ?? '').toString().trim();
    String name = (exam['userID'] ?? '').toString().trim();
    if (name.isEmpty || name.toLowerCase() == 'anonymous') {
      name = 'Użytkownik anonimowy';
    }
    final key = uid.isNotEmpty ? uid : name;
    usersByUid.putIfAbsent(key, () => []).add(exam);
  }

  final q = f.search.toLowerCase();
  final filteredUsers =
      usersByUid.entries
          .map((entry) {
            final exams = entry.value
              ..sort((a, b) {
                final da =
                    DateTime.tryParse(a['data_czas'] ?? '') ?? DateTime(2000);
                final db =
                    DateTime.tryParse(b['data_czas'] ?? '') ?? DateTime(2000);
                return db.compareTo(da);
              });
            final first = exams.first;
            String name = (first['userID'] ?? '').toString().trim();
            if (name.isEmpty || name.toLowerCase() == 'anonymous') {
              name = 'Użytkownik anonimowy';
            }
            final uid = (first['UID'] ?? '').toString().trim();
            final examsByQual = <String, List<dynamic>>{};
            for (final exam in exams) {
              final qk = (exam['kwalifikacja'] ?? '').toString().trim();
              if (isValidQualification(qk)) {
                examsByQual.putIfAbsent(qk, () => []).add(exam);
              }
            }

            return {
              'name': name,
              'uid': uid,
              'exams': exams,
              'examsByQual': examsByQual,
            };
          })
          .where((u) {
            return u['name'].toString().toLowerCase().contains(q) ||
                u['uid'].toString().toLowerCase().contains(q);
          })
          .toList()
        ..sort((a, b) {
          if (a['name'] == 'Użytkownik anonimowy') return 1;
          if (b['name'] == 'Użytkownik anonimowy') return -1;
          return a['name'].toString().compareTo(b['name'].toString());
        });

  final qualifications = <String, List<dynamic>>{};
  for (final r in filteredResults) {
    final qk = (r['kwalifikacja'] ?? '').toString().trim();
    if (isValidQualification(qk)) {
      qualifications.putIfAbsent(qk, () => []).add(r);
    }
  }

  return _StatsResult(
    filteredResults: filteredResults,
    filteredUsers: filteredUsers,
    qualifications: qualifications,
  );
}

class AdminStatsPage extends StatefulWidget {
  const AdminStatsPage({super.key});

  @override
  State<AdminStatsPage> createState() => _AdminStatsPageState();
}

class _AdminStatsPageState extends State<AdminStatsPage> {
  List<dynamic> allResults = [];
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> _filteredResults = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  Map<String, List<dynamic>> _qualifications = {};

  @override
  void initState() {
    super.initState();
    fetchAllStats();
  }

  // ── Data ──────────────────────────────────────────────────────

  Future<void> fetchAllStats() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final result = await ApiService.instance.fetchAllStats();
      if (!mounted) return;
      if (result.isSuccess) {
        allResults = result.data!;
        final stats = _computeStats(allResults, const _FilterParams());
        setState(() {
          isLoading = false;
          _filteredResults = stats.filteredResults;
          _filteredUsers = stats.filteredUsers;
          _qualifications = stats.qualifications;
        });
      } else {
        throw Exception('Błąd HTTP: ${result.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────

  String _fmtDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '-';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }

  Map<String, dynamic> calculateStats(List<dynamic> results) {
    if (results.isEmpty) {
      return {'count': 0, 'avg': 0.0, 'best': 0.0, 'worst': 0.0};
    }
    final scores = results.map<double>((e) {
      final raw = e['wynik'];
      if (raw is num) return raw.toDouble();
      return double.tryParse('$raw') ?? 0.0;
    }).toList();
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    final best = scores.reduce((a, b) => a > b ? a : b);
    final worst = scores.reduce((a, b) => a < b ? a : b);
    return {'count': scores.length, 'avg': avg, 'best': best, 'worst': worst};
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final extras = Theme.of(context).extension<ExtraColors>()!;
    final screenWidth = MediaQuery.of(context).size.width;
    const double kMaxContent = 1100.0;
    final double contentWidth = screenWidth < 600
        ? screenWidth - 32
        : (screenWidth * 0.90).clamp(0.0, kMaxContent);
    final double hPad = ((screenWidth - contentWidth) / 2).clamp(
      20.0,
      double.infinity,
    );
    final bool isCompact = screenWidth < 380;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statystyki egzaminów'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        iconTheme: IconThemeData(color: cs.onPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Odśwież',
            onPressed: fetchAllStats,
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: AsyncStateView.loading(
                subtitle: 'Pobieranie statystyk...',
              ),
            )
          : errorMessage != null
          ? Center(
              child: AsyncStateView.error(
                message: 'Błąd ładowania',
                subtitle: errorMessage,
                icon: Icons.cloud_off_rounded,
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchAllStats,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 0),
                      child: _ReportButton(
                        filteredResults: _filteredResults,
                        cs: cs,
                        tt: tt,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
                      child: _UsersHeader(
                        userCount: _filteredUsers.length,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _UsersListPage(
                                allResults: allResults,
                                calculateStats: calculateStats,
                                fmtDuration: _fmtDuration,
                              ),
                            ),
                          );
                        },
                        cs: cs,
                        tt: tt,
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 12),
                      child: _SectionHeader(
                        label: 'Kwalifikacje',
                        count: _qualifications.length,
                        cs: cs,
                        tt: tt,
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((ctx, i) {
                        final entry = _qualifications.entries.elementAt(i);
                        final qStats = calculateStats(entry.value);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _QualificationCard(
                            qualification: entry.key.toUpperCase(),
                            qStats: qStats,
                            isCompact: isCompact,
                            cs: cs,
                            tt: tt,
                            extras: extras,
                          ),
                        );
                      }, childCount: _qualifications.length),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────
//                Section header
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.count,
    required this.cs,
    required this.tt,
  });
  final String label;
  final int count;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 20,
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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _QualificationDropdown extends StatelessWidget {
  const _QualificationDropdown({
    required this.selected,
    required this.keys,
    required this.onChanged,
    required this.cs,
    required this.tt,
  });
  final String? selected;
  final List<String> keys;
  final ValueChanged<String?> onChanged;
  final ColorScheme cs;
  final TextTheme tt;

  static const String _allValue = '__all__';

  @override
  Widget build(BuildContext context) {
    final bool hasSelection = selected != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        return DropdownMenu<String>(
          key: ValueKey(selected),
          initialSelection: selected ?? _allValue,
          width: constraints.maxWidth,
          enableSearch: false,
          leadingIcon: Icon(
            Icons.school_rounded,
            size: 18,
            color: hasSelection ? cs.primary : cs.onSurfaceVariant,
          ),
          trailingIcon: Icon(
            Icons.expand_more_rounded,
            size: 18,
            color: hasSelection ? cs.primary : cs.onSurfaceVariant,
          ),
          selectedTrailingIcon: Icon(
            Icons.expand_less_rounded,
            size: 18,
            color: cs.primary,
          ),
          textStyle: tt.bodySmall?.copyWith(
            color: hasSelection ? cs.primary : cs.onSurface,
            fontWeight: hasSelection ? FontWeight.w600 : FontWeight.w400,
          ),
          menuHeight: 360,
          menuStyle: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHigh),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            elevation: const WidgetStatePropertyAll(3),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: hasSelection
                ? cs.primaryContainer.withValues(alpha: 0.5)
                : cs.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasSelection
                    ? cs.primary.withValues(alpha: 0.4)
                    : cs.outlineVariant.withValues(alpha: 0.6),
                width: hasSelection ? 1.5 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: cs.primary, width: 1.5),
            ),
          ),
          dropdownMenuEntries: [
            DropdownMenuEntry(
              value: _allValue,
              label: 'Wszystkie kwalifikacje',
              style: MenuItemButton.styleFrom(
                foregroundColor: cs.onSurface,
                textStyle: tt.bodySmall,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            ...keys.map(
              (q) => DropdownMenuEntry(
                value: q,
                label: q,
                style: MenuItemButton.styleFrom(
                  foregroundColor: cs.onSurface,
                  textStyle: tt.bodySmall,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
          onSelected: (value) {
            onChanged(value == null || value == _allValue ? null : value);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//          Users collapsible header
// ─────────────────────────────────────────────

class _UsersHeader extends StatelessWidget {
  const _UsersHeader({
    required this.userCount,
    required this.onTap,
    required this.cs,
    required this.tt,
  });
  final int userCount;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.people_rounded,
                size: 16,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Uczniowie',
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    '$userCount użytkowników',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
              ),
              child: Text(
                '$userCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurfaceVariant,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//            Dedicated users page
// ─────────────────────────────────────────────

class _UsersListPage extends StatefulWidget {
  const _UsersListPage({
    required this.allResults,
    required this.calculateStats,
    required this.fmtDuration,
  });
  final List<dynamic> allResults;
  final Map<String, dynamic> Function(List<dynamic>) calculateStats;
  final String Function(int?) fmtDuration;

  @override
  State<_UsersListPage> createState() => _UsersListPageState();
}

class _UsersListPageState extends State<_UsersListPage>
    with TickerProviderStateMixin {
  String _search = '';
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _qualification;
  Timer? _searchDebounce;

  late final List<String> _allQualificationKeys =
      widget.allResults
          .map((r) => (r['kwalifikacja'] ?? 'Nieznana').toString())
          .toSet()
          .toList()
        ..sort();

  late _StatsResult _stats;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _stats = _recompute();
    _tabController = TabController(length: 2, vsync: this);
  }

  _StatsResult _recompute() => _computeStats(
    widget.allResults,
    _FilterParams(
      search: _search,
      startDate: _startDate,
      endDate: _endDate,
      startTime: _startTime,
      endTime: _endTime,
      qualification: _qualification,
    ),
  );

  void _apply() => setState(() => _stats = _recompute());

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _search = value;
      _apply();
    });
  }

  void _clearFilters() {
    setState(() {
      _search = '';
      _startDate = null;
      _endDate = null;
      _startTime = null;
      _endTime = null;
      _qualification = null;
      _stats = _recompute();
    });
  }

  bool get _hasActiveFilters =>
      _search.isNotEmpty ||
      _startDate != null ||
      _endDate != null ||
      _startTime != null ||
      _endTime != null ||
      _qualification != null;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isCompact = screenWidth < 600;
    final bool isWide = screenWidth >= 960;

    final filtersPanel = _FiltersPanel(
      search: _search,
      startDate: _startDate,
      endDate: _endDate,
      startTime: _startTime,
      endTime: _endTime,
      qualification: _qualification,
      allQualificationKeys: _allQualificationKeys,
      hasActiveFilters: _hasActiveFilters,
      isCompact: isCompact,
      onSearchChanged: _onSearchChanged,
      onStartDatePick: _pickStartDate,
      onEndDatePick: _pickEndDate,
      onStartTimePick: _pickStartTime,
      onEndTimePick: _pickEndTime,
      onQualificationChanged: (v) {
        _qualification = v;
        _apply();
      },
      onClearFilters: _clearFilters,
      fmtDate: _fmtDate,
      fmtTime: _fmtTime,
      cs: cs,
      tt: tt,
    );

    final report = _ReportButton(
      filteredResults: _stats.filteredResults,
      cs: cs,
      tt: tt,
    );

    final usersContent = _UsersListContent(
      stats: _stats,
      calculateStats: widget.calculateStats,
      fmtDuration: widget.fmtDuration,
      startDate: _startDate,
      endDate: _endDate,
      isCompact: isCompact,
      cs: cs,
      tt: tt,
    );

    if (isWide) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Statystyki uczniów'),
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          iconTheme: IconThemeData(color: cs.onPrimary),
        ),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: screenWidth * 0.30,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                        child: filtersPanel,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: cs.outlineVariant.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      child: report,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: usersContent),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        title: Text('Statystyki uczniów'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(75),
          child: Material(
            color: cs.surface,
            elevation: 0,
            child: TabBar(
              controller: _tabController,
              indicatorColor: cs.primary,
              indicatorWeight: 3,
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurfaceVariant,
              labelStyle: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              unselectedLabelStyle: tt.titleSmall,
              tabs: const [
                Tab(icon: Icon(Icons.filter_list_rounded), text: 'Filtry'),
                Tab(icon: Icon(Icons.people_rounded), text: 'Uczniowie'),
              ],
            ),
          ),
        ),
        actions: [
          if (_hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_rounded),
              onPressed: _clearFilters,
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [filtersPanel, const SizedBox(height: 24), report],
            ),
          ),
          usersContent,
        ],
      ),
    );
  }

  // ── Date / Time Pickers ─────────────────────────────
  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _startDate = picked;
      _apply();
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _endDate = picked;
      _apply();
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 0, minute: 0),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      _startTime = picked;
      _apply();
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 23, minute: 59),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      _endTime = picked;
      _apply();
    }
  }
}

class _FiltersPanel extends StatelessWidget {
  const _FiltersPanel({
    required this.search,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.qualification,
    required this.allQualificationKeys,
    required this.hasActiveFilters,
    required this.isCompact,
    required this.onSearchChanged,
    required this.onStartDatePick,
    required this.onEndDatePick,
    required this.onStartTimePick,
    required this.onEndTimePick,
    required this.onQualificationChanged,
    required this.onClearFilters,
    required this.fmtDate,
    required this.fmtTime,
    required this.cs,
    required this.tt,
  });

  final String search;
  final DateTime? startDate;
  final DateTime? endDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final String? qualification;
  final List<String> allQualificationKeys;
  final bool hasActiveFilters;
  final bool isCompact;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onStartDatePick;
  final VoidCallback onEndDatePick;
  final VoidCallback onStartTimePick;
  final VoidCallback onEndTimePick;
  final ValueChanged<String?> onQualificationChanged;
  final VoidCallback onClearFilters;
  final String Function(DateTime) fmtDate;
  final String Function(TimeOfDay) fmtTime;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        search_bar.SearchBar(onChanged: onSearchChanged),
        const SizedBox(height: 16),
        if (hasActiveFilters) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.errorContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: cs.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Aktywne filtry',
                    style: tt.bodyMedium?.copyWith(color: cs.onErrorContainer),
                  ),
                ),
                TextButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Wyczyść'),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        _FilterGroupCard(
          title: 'Zakres dat',
          icon: Icons.calendar_today_rounded,
          cs: cs,
          tt: tt,
          children: [
            _StyledFilterChip(
              icon: Icons.calendar_today_outlined,
              label: startDate != null
                  ? 'Od: ${fmtDate(startDate!)}'
                  : 'Data rozpoczęcia',
              active: startDate != null,
              onTap: onStartDatePick,
              cs: cs,
              tt: tt,
            ),
            const SizedBox(height: 8),
            _StyledFilterChip(
              icon: Icons.calendar_today_outlined,
              label: endDate != null
                  ? 'Do: ${fmtDate(endDate!)}'
                  : 'Data zakończenia',
              active: endDate != null,
              onTap: onEndDatePick,
              cs: cs,
              tt: tt,
            ),
          ],
        ),

        const SizedBox(height: 16),

        _FilterGroupCard(
          title: 'Godzina',
          icon: Icons.schedule_rounded,
          cs: cs,
          tt: tt,
          children: [
            _StyledFilterChip(
              icon: Icons.access_time_rounded,
              label: startTime != null
                  ? 'Od: ${fmtTime(startTime!)}'
                  : 'Godzina od',
              active: startTime != null,
              onTap: onStartTimePick,
              cs: cs,
              tt: tt,
            ),
            const SizedBox(height: 8),
            _StyledFilterChip(
              icon: Icons.access_time_rounded,
              label: endTime != null
                  ? 'Do: ${fmtTime(endTime!)}'
                  : 'Godzina do',
              active: endTime != null,
              onTap: onEndTimePick,
              cs: cs,
              tt: tt,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FilterGroupCard(
          title: 'Kwalifikacja',
          icon: Icons.school_rounded,
          cs: cs,
          tt: tt,
          children: [
            _QualificationDropdown(
              selected: qualification,
              keys: allQualificationKeys,
              onChanged: onQualificationChanged,
              cs: cs,
              tt: tt,
            ),
          ],
        ),
      ],
    );
  }
}

class _FilterGroupCard extends StatelessWidget {
  const _FilterGroupCard({
    required this.title,
    required this.icon,
    required this.children,
    required this.cs,
    required this.tt,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: cs.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _StyledFilterChip extends StatelessWidget {
  const _StyledFilterChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.cs,
    required this.tt,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: active ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? cs.primary
                : cs.outlineVariant.withValues(alpha: 0.8),
            width: active ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: active ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: tt.bodyMedium?.copyWith(
                  color: active ? cs.onPrimaryContainer : cs.onSurface,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (active)
              Icon(Icons.check_circle_rounded, size: 18, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

class _UsersListContent extends StatelessWidget {
  const _UsersListContent({
    required this.stats,
    required this.calculateStats,
    required this.fmtDuration,
    required this.startDate,
    required this.endDate,
    required this.isCompact,
    required this.cs,
    required this.tt,
  });

  final _StatsResult stats;
  final Map<String, dynamic> Function(List<dynamic>) calculateStats;
  final String Function(int?) fmtDuration;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isCompact;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: _SectionHeader(
              label: 'Uczniowie',
              count: stats.filteredUsers.length,
              cs: cs,
              tt: tt,
            ),
          ),
        ),
        if (stats.filteredUsers.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: AsyncStateView.empty(
                  message: 'Brak wyników',
                  subtitle: 'Brak wyników dla podanych filtrów.',
                  icon: Icons.person_search_rounded,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final u = stats.filteredUsers[index];
                  final uidStr = (u['uid'] ?? '').toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _UserCard(
                      key: ValueKey(uidStr.isNotEmpty ? uidStr : u['name']),
                      userData: u,
                      calculateStats: calculateStats,
                      fmtDuration: fmtDuration,
                      startDate: startDate,
                      endDate: endDate,
                      isCompact: isCompact,
                      cs: cs,
                      tt: tt,
                    ),
                  );
                },
                childCount: stats.filteredUsers.length,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//                  User card
// ─────────────────────────────────────────────

class _UserCard extends StatefulWidget {
  const _UserCard({
    super.key,
    required this.userData,
    required this.calculateStats,
    required this.fmtDuration,
    required this.startDate,
    required this.endDate,
    required this.isCompact,
    required this.cs,
    required this.tt,
  });
  final Map<String, dynamic> userData;
  final Map<String, dynamic> Function(List<dynamic>) calculateStats;
  final String Function(int?) fmtDuration;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isCompact;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard>
    with AutomaticKeepAliveClientMixin {
  bool _expanded = false;

  @override
  bool get wantKeepAlive => _expanded;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final userData = widget.userData;
    final cs = widget.cs;
    final tt = widget.tt;

    final String name = userData['name'] as String;
    final String uid = (userData['uid'] ?? '').toString();
    final exams = userData['exams'] as List<dynamic>;
    final examsByQual = userData['examsByQual'] as Map<String, List<dynamic>>;

    final userStats = widget.calculateStats(exams);

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: cs.surface,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          onExpansionChanged: (v) => setState(() => _expanded = v),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UserTileTitle(name: name, uid: uid, cs: cs, tt: tt),
              const SizedBox(height: 6),
              Row(
                children: [
                  _StatPill(
                    label: 'Egz.',
                    value: '${userStats['count']}',
                    cs: cs,
                    tt: tt,
                  ),
                  const SizedBox(width: 6),
                  _StatPill(
                    label: 'Śr.',
                    value:
                        '${(userStats['avg'] as double).toStringAsFixed(1)}%',
                    cs: cs,
                    tt: tt,
                  ),
                  const SizedBox(width: 6),
                  _StatPill(
                    label: 'Najl.',
                    value:
                        '${(userStats['best'] as double).toStringAsFixed(1)}%',
                    cs: cs,
                    tt: tt,
                  ),
                ],
              ),
            ],
          ),
          children: _expanded
              ? examsByQual.entries.where((e) => e.value.isNotEmpty).map((
                  qualEntry,
                ) {
                  final qualExams = qualEntry.value;
                  final recent =
                      (widget.startDate == null && widget.endDate == null)
                      ? qualExams.take(5).toList()
                      : qualExams;

                  final qualStats = widget.calculateStats(qualEntry.value);

                  return _QualificationTile(
                    qualification: qualEntry.key,
                    recentExams: recent,
                    qualStats: qualStats,
                    fmtDuration: widget.fmtDuration,
                    isCompact: widget.isCompact,
                    cs: cs,
                    tt: tt,
                  );
                }).toList()
              : const [],
        ),
      ),
    );
  }
}

class _UserTileTitle extends StatelessWidget {
  const _UserTileTitle({
    required this.name,
    required this.uid,
    required this.cs,
    required this.tt,
  });
  final String name;
  final String uid;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 8,
      children: [
        Text(
          name,
          style: tt.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        if (uid.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_box_rounded,
                  size: 12,
                  color: cs.onPrimaryContainer,
                ),
                const SizedBox(width: 4),
                Text(
                  'UID: $uid',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//               Qualification tile
// ─────────────────────────────────────────────

class _QualificationTile extends StatelessWidget {
  const _QualificationTile({
    required this.qualification,
    required this.recentExams,
    required this.qualStats,
    required this.fmtDuration,
    required this.isCompact,
    required this.cs,
    required this.tt,
  });
  final String qualification;
  final List<dynamic> recentExams;
  final Map<String, dynamic> qualStats;
  final String Function(int?) fmtDuration;
  final bool isCompact;
  final ColorScheme cs;
  final TextTheme tt;

  Future<Map<String, dynamic>?> _fetchExamDetails(
    int examId,
    String userName,
    String examDateTime,
    int durationSec,
  ) async {
    try {
      final result = await ApiService.instance.fetchExamPreviewAdmin(
        examId: examId,
        userName: userName,
        examDateTime: examDateTime,
        durationSec: durationSec,
      );
      if (result.isSuccess && result.data?['success'] == true) {
        return {
          'questions': List<dynamic>.from(result.data!['questions']),
          'selectedAnswers': (result.data!['selectedAnswers'] as List)
              .cast<String?>(),
        };
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Wystąpił błąd podczas pobierania danych egzaminów: $e');
      }
    }
    return null;
  }

  String _scoreStr(dynamic v) {
    if (v is num) {
      return v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    }
    return v?.toString() ?? '-';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: cs.surfaceContainerLowest,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          title: LayoutBuilder(
            builder: (context, constraints) {
              final iconAndName = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_rounded, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      qualification.toUpperCase(),
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );

              final pills = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StatPill(
                    label: 'Egz.',
                    value: '${qualStats['count']}',
                    cs: cs,
                    tt: tt,
                  ),
                  const SizedBox(width: 6),
                  _StatPill(
                    label: 'Śr.',
                    value:
                        '${(qualStats['avg'] as double).toStringAsFixed(1)}%',
                    cs: cs,
                    tt: tt,
                  ),
                ],
              );

              if (constraints.maxWidth < 260) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [iconAndName, const SizedBox(height: 6), pills],
                );
              }

              return Row(
                children: [
                  Flexible(child: iconAndName),
                  const SizedBox(width: 10),
                  pills,
                ],
              );
            },
          ),
          children: recentExams.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Brak egzaminów.',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ]
              : recentExams.map((exam) {
                  final dateTimeStr = (exam['data_czas'] ?? '-') as String;
                  final wynik = _scoreStr(exam['wynik']);
                  final durationSec = (exam['czas_trwania_sec'] is int)
                      ? exam['czas_trwania_sec'] as int
                      : int.tryParse('${exam['czas_trwania_sec'] ?? '0'}') ?? 0;
                  final czas = fmtDuration(durationSec);
                  final tryb = (exam['tryb'] ?? exam['mode'] ?? '') as String;
                  final examId = int.tryParse('${exam['id'] ?? '0'}') ?? 0;
                  final userName = (exam['userID'] ?? '').toString();

                  return _ExamRow(
                    date: dateTimeStr.split(' ').first,
                    wynik: wynik,
                    czas: czas,
                    tryb: tryb,
                    isCompact: isCompact,
                    onPreview: examId <= 0
                        ? null
                        : () async {
                            final details = await _fetchExamDetails(
                              examId,
                              userName,
                              dateTimeStr,
                              durationSec,
                            );
                            if (!context.mounted) return;
                            if (details != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ExamPreviewPage(
                                    questions: details['questions'],
                                    selectedAnswers: details['selectedAnswers'],
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Nie udało się wczytać podglądu',
                                  ),
                                  backgroundColor: cs.error,
                                ),
                              );
                            }
                          },
                    cs: cs,
                    tt: tt,
                  );
                }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//                   Exam row
// ─────────────────────────────────────────────

class _ExamRow extends StatelessWidget {
  const _ExamRow({
    required this.date,
    required this.wynik,
    required this.czas,
    required this.tryb,
    required this.onPreview,
    required this.isCompact,
    required this.cs,
    required this.tt,
  });

  final String date;
  final String wynik;
  final String czas;
  final String tryb;
  final VoidCallback? onPreview;
  final bool isCompact;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
            ),
            child: Text(
              date,
              style: tt.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'Wynik: $wynik',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      '%',
                      style: tt.titleMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 15,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Czas: $czas',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (tryb.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tryb,
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (onPreview != null)
            FilledButton.icon(
              onPressed: onPreview,
              icon: const Icon(Icons.visibility_rounded, size: 16),
              label: const Text('Podgląd'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//                 Report button
// ─────────────────────────────────────────────

class _ReportButton extends StatelessWidget {
  const _ReportButton({
    required this.filteredResults,
    required this.cs,
    required this.tt,
  });
  final List<dynamic> filteredResults;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final icon = Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.description_rounded,
              size: 20,
              color: cs.onPrimaryContainer,
            ),
          );
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Raport PDF',
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              Text(
                'Eksportuj ${filteredResults.length} wyników',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          );
          final button = FilledButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportSelectionPage(data: filteredResults),
                ),
              );
            },
            child: const Padding(
              padding: EdgeInsetsGeometry.symmetric(
                vertical: 10,
                horizontal: 20,
              ),
              child: Text('Generuj Raport'),
            ),
          );
          if (constraints.maxWidth < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    icon,
                    const SizedBox(width: 14),
                    Expanded(child: text),
                  ],
                ),
                const SizedBox(height: 12),
                button,
              ],
            );
          }

          return Row(
            children: [
              icon,
              const SizedBox(width: 14),
              Expanded(child: text),
              button,
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//          Qualification summary card
// ─────────────────────────────────────────────

class _QualificationCard extends StatelessWidget {
  const _QualificationCard({
    required this.qualification,
    required this.qStats,
    required this.isCompact,
    required this.cs,
    required this.extras,
    required this.tt,
  });
  final String qualification;
  final Map<String, dynamic> qStats;
  final bool isCompact;
  final ColorScheme cs;
  final ExtraColors extras;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final avg = (qStats['avg'] as double);
    final best = (qStats['best'] as double);
    final worst = (qStats['worst'] as double);
    final count = qStats['count'] as int;

    final Color accentColor = avg >= 50
        ? extras.correct.withValues(alpha: 0.7)
        : extras.incorrect;
    final Color accentBg = avg >= 50
        ? extras.correct.withValues(alpha: 0.10)
        : cs.errorContainer.withValues(alpha: 0.35);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: accentBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    size: 18,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    qualification,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Śr. ${avg.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: isCompact
                ? Row(
                    children: [
                      _QStatBox(
                        icon: Icons.format_list_numbered_rounded,
                        label: 'Egzaminów',
                        value: '$count',
                        color: cs.primary,
                        cs: cs,
                        tt: tt,
                      ),
                      _QStatBox(
                        icon: Icons.emoji_events_rounded,
                        label: 'Najlepszy',
                        value: '${best.toStringAsFixed(1)}%',
                        color: extras.correct,
                        cs: cs,
                        tt: tt,
                      ),
                      _QStatBox(
                        icon: Icons.trending_down_rounded,
                        label: 'Najgorszy',
                        value: '${worst.toStringAsFixed(1)}%',
                        color: extras.incorrect,
                        cs: cs,
                        tt: tt,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      _QStatBox(
                        icon: Icons.format_list_numbered_rounded,
                        label: 'Egzaminów',
                        value: '$count',
                        color: cs.primary,
                        cs: cs,
                        tt: tt,
                      ),
                      _QStatDivider(cs: cs),
                      _QStatBox(
                        icon: Icons.emoji_events_rounded,
                        label: 'Najlepszy',
                        value: '${best.toStringAsFixed(1)}%',
                        color: extras.correct,
                        cs: cs,
                        tt: tt,
                      ),
                      _QStatDivider(cs: cs),
                      _QStatBox(
                        icon: Icons.trending_down_rounded,
                        label: 'Najgorszy',
                        value: '${worst.toStringAsFixed(1)}%',
                        color: extras.incorrect,
                        cs: cs,
                        tt: tt,
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Średnia zdawalność',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    Text(
                      '${avg.toStringAsFixed(1)}%',
                      style: tt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (avg / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QStatBox extends StatelessWidget {
  const _QStatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.cs,
    required this.tt,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _QStatDivider extends StatelessWidget {
  const _QStatDivider({required this.cs});
  final ColorScheme cs;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 60,
      color: cs.outlineVariant.withValues(alpha: 0.4),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.cs,
    required this.tt,
  });

  final String label;
  final String value;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
