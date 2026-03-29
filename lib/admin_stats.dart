import 'dart:async' show Timer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/exam_preview.dart';
import 'package:flutter_app/services/api_service.dart';
import 'report_selection.dart';
import 'widgets/search_bar.dart' as search_bar;

class AdminStatsPage extends StatefulWidget {
  const AdminStatsPage({super.key});

  @override
  State<AdminStatsPage> createState() => _AdminStatsPageState();
}

class _AdminStatsPageState extends State<AdminStatsPage> {
  List<dynamic> allResults = [];
  bool isLoading = true;
  String? errorMessage;
  String searchQuery = '';
  DateTime? startDate;
  DateTime? endDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String? selectedQualification;
  Timer? _searchDebounce;
  List<dynamic> _filteredResults = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  Map<String, List<dynamic>> _qualifications = {};
  List<String> _allQualificationKeys = [];

  @override
  void initState() {
    super.initState();
    fetchAllStats();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
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
        _recompute();
        setState(() => isLoading = false);
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

  void _recompute() {
    final filteredResults =
        allResults.where((exam) {
          final examDate = DateTime.tryParse(exam['data_czas'] ?? '');
          if (examDate == null) return false;

          if (startDate != null && examDate.isBefore(startDate!)) return false;
          if (endDate != null &&
              examDate.isAfter(endDate!.add(const Duration(days: 1)))) {
            return false;
          }

          if (startTime != null) {
            final examMins = examDate.hour * 60 + examDate.minute;
            final startMins = startTime!.hour * 60 + startTime!.minute;
            if (examMins < startMins) return false;
          }
          if (endTime != null) {
            final examMins = examDate.hour * 60 + examDate.minute;
            final endMins = endTime!.hour * 60 + endTime!.minute;
            if (examMins > endMins) return false;
          }

          if (selectedQualification != null &&
              (exam['kwalifikacja'] ?? '').toString() !=
                  selectedQualification) {
            return false;
          }
          return true;
        }).toList();

    // Group by user
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

    final q = searchQuery.toLowerCase();
    final filteredUsers =
        usersByUid.entries
            .map((entry) {
              final exams = entry.value;
              final first = exams.first;
              String name = (first['userID'] ?? '').toString().trim();
              if (name.isEmpty || name.toLowerCase() == 'anonymous') {
                name = 'Użytkownik anonimowy';
              }
              final uid = (first['UID'] ?? '').toString().trim();
              return {'name': name, 'uid': uid, 'exams': exams};
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

    setState(() {
      _filteredResults = filteredResults;
      _filteredUsers = filteredUsers;
      _qualifications = qualifications;
      _allQualificationKeys =
          allResults
              .map((r) => (r['kwalifikacja'] ?? 'Nieznana').toString())
              .toSet()
              .toList()
            ..sort();
    });
  }

  void _clearFilters() {
    setState(() {
      startDate = null;
      endDate = null;
      startTime = null;
      endTime = null;
      selectedQualification = null;
      searchQuery = '';
    });
    _recompute();
  }

  bool get _hasActiveFilters =>
      startDate != null ||
      endDate != null ||
      startTime != null ||
      endTime != null ||
      selectedQualification != null ||
      searchQuery.isNotEmpty;

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
    final scores =
        results.map<double>((e) {
          final raw = e['wynik'];
          if (raw is num) return raw.toDouble();
          return double.tryParse('$raw') ?? 0.0;
        }).toList();
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    final best = scores.reduce((a, b) => a > b ? a : b);
    final worst = scores.reduce((a, b) => a < b ? a : b);
    return {'count': scores.length, 'avg': avg, 'best': best, 'worst': worst};
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    // Constrain content to 85% of screen width (max 880px), centred.
    // On narrow phones keep a minimum 16px inset on each side.
    const double kMaxContent = 1100.0;
    final double contentWidth =
        screenWidth < 600
            ? screenWidth -
                32 // phone: 16px each side
            : (screenWidth * 0.90).clamp(0.0, kMaxContent);
    final double hPad = ((screenWidth - contentWidth) / 2).clamp(
      20.0,
      double.infinity,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statystyki egzaminów'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        iconTheme: IconThemeData(color: cs.onPrimary),
        actions: [
          if (_hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_rounded),
              tooltip: 'Wyczyść filtry',
              onPressed: _clearFilters,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Odśwież',
            onPressed: fetchAllStats,
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? _ErrorState(
                message: errorMessage!,
                onRetry: fetchAllStats,
                cs: cs,
                tt: tt,
              )
              : RefreshIndicator(
                onRefresh: fetchAllStats,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // ── Filters ──────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 0),
                        child: _FiltersSection(
                          startDate: startDate,
                          endDate: endDate,
                          startTime: startTime,
                          endTime: endTime,
                          selectedQualification: selectedQualification,
                          allQualificationKeys: _allQualificationKeys,
                          hasActiveFilters: _hasActiveFilters,
                          onSearchChanged: (value) {
                            _searchDebounce?.cancel();
                            _searchDebounce = Timer(
                              const Duration(milliseconds: 200),
                              () {
                                searchQuery = value;
                                _recompute();
                              },
                            );
                          },
                          onStartDatePick: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => startDate = picked);
                              _recompute();
                            }
                          },
                          onEndDatePick: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: endDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => endDate = picked);
                              _recompute();
                            }
                          },
                          onStartTimePick: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime:
                                  startTime ??
                                  const TimeOfDay(hour: 0, minute: 0),
                              builder:
                                  (ctx, child) => MediaQuery(
                                    data: MediaQuery.of(
                                      ctx,
                                    ).copyWith(alwaysUse24HourFormat: true),
                                    child: child!,
                                  ),
                              initialEntryMode: TimePickerEntryMode.input,
                            );
                            if (picked != null) {
                              setState(() => startTime = picked);
                              _recompute();
                            }
                          },
                          onEndTimePick: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime:
                                  endTime ??
                                  const TimeOfDay(hour: 23, minute: 59),
                              builder:
                                  (ctx, child) => MediaQuery(
                                    data: MediaQuery.of(
                                      ctx,
                                    ).copyWith(alwaysUse24HourFormat: true),
                                    child: child!,
                                  ),
                              initialEntryMode: TimePickerEntryMode.input,
                            );
                            if (picked != null) {
                              setState(() => endTime = picked);
                              _recompute();
                            }
                          },
                          onQualificationChanged: (value) {
                            setState(() => selectedQualification = value);
                            _recompute();
                          },
                          onClearFilters: _clearFilters,
                          fmtDate: _fmtDate,
                          fmtTime: _fmtTime,
                          cs: cs,
                          tt: tt,
                        ),
                      ),
                    ),

                    // ── Report button ─────────────────────────
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

                    // ── Users collapsible section ─────────────
                    // Header card toggles the list. SliverList inside
                    // virtualizes rendering — fixes the 300-user lag.
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
                        child: _UsersSection(
                          users: _filteredUsers,
                          calculateStats: calculateStats,
                          fmtDuration: _fmtDuration,
                          startDate: startDate,
                          endDate: endDate,
                          cs: cs,
                          tt: tt,
                        ),
                      ),
                    ),

                    // ── Qualifications section ────────────────
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
                            child: _QualificationCardV2(
                              qualification: entry.key.toUpperCase(),
                              qStats: qStats,
                              cs: cs,
                              tt: tt,
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
//  Section header (accent bar style)
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
//  Filters section
// ─────────────────────────────────────────────

class _FiltersSection extends StatelessWidget {
  const _FiltersSection({
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.selectedQualification,
    required this.allQualificationKeys,
    required this.hasActiveFilters,
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

  final DateTime? startDate;
  final DateTime? endDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final String? selectedQualification;
  final List<String> allQualificationKeys;
  final bool hasActiveFilters;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search
          search_bar.SearchBar(onChanged: onSearchChanged),
          const SizedBox(height: 12),

          // Date row
          Row(
            children: [
              Expanded(
                child: _FilterChip(
                  icon: Icons.calendar_today_rounded,
                  label:
                      startDate != null
                          ? 'Od: ${fmtDate(startDate!)}'
                          : 'Data od',
                  active: startDate != null,
                  onTap: onStartDatePick,
                  cs: cs,
                  tt: tt,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterChip(
                  icon: Icons.calendar_today_rounded,
                  label:
                      endDate != null ? 'Do: ${fmtDate(endDate!)}' : 'Data do',
                  active: endDate != null,
                  onTap: onEndDatePick,
                  cs: cs,
                  tt: tt,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Time row
          Row(
            children: [
              Expanded(
                child: _FilterChip(
                  icon: Icons.schedule_rounded,
                  label:
                      startTime != null
                          ? 'Od: ${fmtTime(startTime!)}'
                          : 'Godz. od',
                  active: startTime != null,
                  onTap: onStartTimePick,
                  cs: cs,
                  tt: tt,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterChip(
                  icon: Icons.schedule_rounded,
                  label:
                      endTime != null ? 'Do: ${fmtTime(endTime!)}' : 'Godz. do',
                  active: endTime != null,
                  onTap: onEndTimePick,
                  cs: cs,
                  tt: tt,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Qualification dropdown — styled to match filter chips
          _QualificationDropdown(
            selected: selectedQualification,
            keys: allQualificationKeys,
            onChanged: onQualificationChanged,
            cs: cs,
            tt: tt,
          ),

          // Active filter summary
          if (hasActiveFilters) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.filter_alt_rounded, size: 14, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _buildFilterSummary(),
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text('Wyczyść'),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.error,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _buildFilterSummary() {
    final parts = <String>[];
    if (startDate != null || endDate != null) {
      parts.add(
        '${startDate != null ? fmtDate(startDate!) : '—'} → ${endDate != null ? fmtDate(endDate!) : '—'}',
      );
    }
    if (startTime != null || endTime != null) {
      parts.add(
        '${startTime != null ? fmtTime(startTime!) : '—'} → ${endTime != null ? fmtTime(endTime!) : '—'}',
      );
    }
    if (selectedQualification != null) parts.add(selectedQualification!);
    return parts.join(' • ');
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color:
              active
                  ? cs.primaryContainer.withValues(alpha: 0.5)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                active
                    ? cs.primary.withValues(alpha: 0.4)
                    : cs.outlineVariant.withValues(alpha: 0.35),
            width: active ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: active ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                style: tt.bodySmall?.copyWith(
                  color: active ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color:
            selected != null
                ? cs.primaryContainer.withValues(alpha: 0.5)
                : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              selected != null
                  ? cs.primary.withValues(alpha: 0.4)
                  : cs.outlineVariant.withValues(alpha: 0.35),
          width: selected != null ? 1.5 : 1.0,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isExpanded: true,
          hint: Row(
            children: [
              Icon(Icons.school_rounded, size: 15, color: cs.onSurfaceVariant),
              const SizedBox(width: 7),
              Text(
                'Kwalifikacja',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          icon: Icon(
            Icons.expand_more_rounded,
            color: selected != null ? cs.primary : cs.onSurfaceVariant,
            size: 18,
          ),
          style: tt.bodySmall?.copyWith(
            color: selected != null ? cs.primary : cs.onSurface,
            fontWeight: selected != null ? FontWeight.w600 : FontWeight.w400,
          ),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(
                'Wszystkie kwalifikacje',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            ...keys.map((q) => DropdownMenuItem(value: q, child: Text(q))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Users collapsible section
// ─────────────────────────────────────────────

class _UsersSection extends StatefulWidget {
  const _UsersSection({
    required this.users,
    required this.calculateStats,
    required this.fmtDuration,
    required this.startDate,
    required this.endDate,
    required this.cs,
    required this.tt,
  });
  final List<Map<String, dynamic>> users;
  final Map<String, dynamic> Function(List<dynamic>) calculateStats;
  final String Function(int?) fmtDuration;
  final DateTime? startDate;
  final DateTime? endDate;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  State<_UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<_UsersSection>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _rotation = Tween<double>(
    begin: 0,
    end: 0.5,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final tt = widget.tt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Collapsible header ───────────────────────────────────
        InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color:
                  _expanded
                      ? cs.primaryContainer.withValues(alpha: 0.25)
                      : cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    _expanded
                        ? cs.primary.withValues(alpha: 0.4)
                        : cs.outlineVariant.withValues(alpha: 0.4),
                width: _expanded ? 1.5 : 1.0,
              ),
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
                    color: _expanded ? cs.primary : cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.people_rounded,
                    size: 16,
                    color: _expanded ? cs.onPrimary : cs.onPrimaryContainer,
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
                          color: _expanded ? cs.primary : cs.onSurface,
                        ),
                      ),
                      Text(
                        '${widget.users.length} użytkowników',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.users.length}',
                    style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                RotationTransition(
                  turns: _rotation,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _expanded ? cs.primary : cs.onSurfaceVariant,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── User list (shown when expanded) ──────────────────────
        if (_expanded) ...[
          const SizedBox(height: 10),
          if (widget.users.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: _EmptyState(
                message: 'Brak wyników dla podanych filtrów.',
                cs: cs,
                tt: tt,
              ),
            )
          else
            // ListView.builder inside a constrained box — virtualizes
            // rendering so 300+ users don't all build at once.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: ListView.builder(
                shrinkWrap: false,
                itemCount: widget.users.length,
                itemBuilder: (ctx, i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _UserCard(
                      userData: widget.users[i],
                      calculateStats: widget.calculateStats,
                      fmtDuration: widget.fmtDuration,
                      startDate: widget.startDate,
                      endDate: widget.endDate,
                      cs: cs,
                      tt: tt,
                    ),
                  );
                },
              ),
            ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  User card (virtualized)
// ─────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.userData,
    required this.calculateStats,
    required this.fmtDuration,
    required this.startDate,
    required this.endDate,
    required this.cs,
    required this.tt,
  });
  final Map<String, dynamic> userData;
  final Map<String, dynamic> Function(List<dynamic>) calculateStats;
  final String Function(int?) fmtDuration;
  final DateTime? startDate;
  final DateTime? endDate;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final String name = userData['name'] as String;
    final String uid = (userData['uid'] ?? '').toString();
    final exams = List<dynamic>.from(userData['exams'] as List)..sort((a, b) {
      final da = DateTime.tryParse(a['data_czas'] ?? '') ?? DateTime(2000);
      final db = DateTime.tryParse(b['data_czas'] ?? '') ?? DateTime(2000);
      return db.compareTo(da);
    });

    final userStats = calculateStats(exams);
    final isAnonymous = name == 'Użytkownik anonimowy' || name == 'anonymous';

    final Map<String, List<dynamic>> examsByQual = {};
    for (final exam in exams) {
      final qk = (exam['kwalifikacja'] ?? '').toString().trim();
      if (isValidQualification(qk)) {
        examsByQual.putIfAbsent(qk, () => []).add(exam);
      }
    }

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
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
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color:
                  isAnonymous
                      ? cs.surfaceContainerHighest
                      : cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              isAnonymous ? Icons.person_off_rounded : null,
              size: 18,
              color: cs.onSurfaceVariant,
              // Show initial letter for named users:
              semanticLabel: isAnonymous ? null : initial,
            ),
          ),
          title:
              isAnonymous
                  ? Text(
                    name,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                  : _UserTileTitle(name: name, uid: uid, cs: cs, tt: tt),
          subtitle: Text(
            'Egz.: ${userStats['count']}  •  Śr.: ${(userStats['avg'] as double).toStringAsFixed(1)}%  •  Najl.: ${(userStats['best'] as double).toStringAsFixed(1)}%',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          children:
              examsByQual.entries.where((e) => e.value.isNotEmpty).map((
                qualEntry,
              ) {
                final qualExams = List<dynamic>.from(qualEntry.value)..sort((
                  a,
                  b,
                ) {
                  final da =
                      DateTime.tryParse(a['data_czas'] ?? '') ?? DateTime(2000);
                  final db =
                      DateTime.tryParse(b['data_czas'] ?? '') ?? DateTime(2000);
                  return db.compareTo(da);
                });

                final recent =
                    (startDate == null && endDate == null)
                        ? qualExams.take(5).toList()
                        : qualExams;

                final qualStats = calculateStats(qualEntry.value);

                return _QualificationTile(
                  qualification: qualEntry.key,
                  recentExams: recent,
                  qualStats: qualStats,
                  fmtDuration: fmtDuration,
                  cs: cs,
                  tt: tt,
                );
              }).toList(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: tt.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        if (uid.isNotEmpty)
          Text(
            'UID: $uid',
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Qualification tile (inside user card)
// ─────────────────────────────────────────────

class _QualificationTile extends StatelessWidget {
  const _QualificationTile({
    required this.qualification,
    required this.recentExams,
    required this.qualStats,
    required this.fmtDuration,
    required this.cs,
    required this.tt,
  });
  final String qualification;
  final List<dynamic> recentExams;
  final Map<String, dynamic> qualStats;
  final String Function(int?) fmtDuration;
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
          'selectedAnswers':
              (result.data!['selectedAnswers'] as List).cast<String?>(),
        };
      }
    } catch (e) {
      if (kDebugMode) debugPrint('fetchExamDetails error: $e');
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
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          leading: Icon(Icons.book_rounded, color: cs.primary, size: 20),
          title: Text(
            qualification.toUpperCase(),
            style: tt.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              letterSpacing: 0.5,
            ),
          ),
          subtitle: Text(
            'Egz.: ${qualStats['count']}  •  Śr.: ${(qualStats['avg'] as double).toStringAsFixed(1)}%',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          children:
              recentExams.isEmpty
                  ? [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Brak egzaminów.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ]
                  : recentExams.map((exam) {
                    final dateTimeStr = (exam['data_czas'] ?? '-') as String;
                    final wynik = _scoreStr(exam['wynik']);
                    final durationSec =
                        (exam['czas_trwania_sec'] is int)
                            ? exam['czas_trwania_sec'] as int
                            : int.tryParse(
                                  '${exam['czas_trwania_sec'] ?? '0'}',
                                ) ??
                                0;
                    final czas = fmtDuration(durationSec);
                    final tryb = (exam['tryb'] ?? exam['mode'] ?? '') as String;
                    final examId = int.tryParse('${exam['id'] ?? '0'}') ?? 0;
                    final userName = (exam['userID'] ?? '').toString();

                    return _ExamRow(
                      date: dateTimeStr.split(' ').first,
                      wynik: wynik,
                      czas: czas,
                      tryb: tryb,
                      onPreview:
                          examId <= 0
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
                                      builder:
                                          (_) => EgzaminPodgladView(
                                            questions: details['questions'],
                                            selectedAnswers:
                                                details['selectedAnswers'],
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
//  Exam row
// ─────────────────────────────────────────────

class _ExamRow extends StatelessWidget {
  const _ExamRow({
    required this.date,
    required this.wynik,
    required this.czas,
    required this.tryb,
    required this.onPreview,
    required this.cs,
    required this.tt,
  });
  final String date;
  final String wynik;
  final String czas;
  final String tryb;
  final VoidCallback? onPreview;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.history_rounded, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: tt.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  'Wynik: $wynik%  •  Czas: $czas${tryb.isNotEmpty ? '  •  $tryb' : ''}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (onPreview != null)
            OutlinedButton.icon(
              onPressed: onPreview,
              icon: const Icon(Icons.visibility_rounded, size: 14),
              label: const Text('Podgląd'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Report button
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
      child: Row(
        children: [
          Container(
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
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
            ),
          ),
          FilledButton(
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
          ),
        ],
      ),
    );
  }
}
// ─────────────────────────────────────────────
//  Error state
// ─────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.cs,
    required this.tt,
  });
  final String message;
  final VoidCallback onRetry;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Nie udało się pobrać danych',
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Empty state
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    required this.cs,
    required this.tt,
  });
  final String message;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.search_off_rounded,
          size: 40,
          color: cs.onSurfaceVariant.withValues(alpha: 0.35),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Qualification summary card (improved)
// ─────────────────────────────────────────────

class _QualificationCardV2 extends StatelessWidget {
  const _QualificationCardV2({
    required this.qualification,
    required this.qStats,
    required this.cs,
    required this.tt,
  });
  final String qualification;
  final Map<String, dynamic> qStats;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final avg = (qStats['avg'] as double);
    final best = (qStats['best'] as double);
    final worst = (qStats['worst'] as double);
    final count = qStats['count'] as int;

    final Color accentColor =
        avg >= 75
            ? const Color(0xFF2E7D32)
            : avg >= 50
            ? cs.primary
            : cs.error;
    final Color accentBg =
        avg >= 75
            ? const Color(0xFF2E7D32).withValues(alpha: 0.10)
            : avg >= 50
            ? cs.primaryContainer.withValues(alpha: 0.35)
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
          // Header
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
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Śr. ${avg.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _QStatBox(
                  icon: Icons.format_list_numbered_rounded,
                  label: 'Egzaminów',
                  value: '$count',
                  color: cs.onSurfaceVariant,
                  cs: cs,
                  tt: tt,
                ),
                _QStatDivider(cs: cs),
                _QStatBox(
                  icon: Icons.emoji_events_rounded,
                  label: 'Najlepszy',
                  value: '${best.toStringAsFixed(1)}%',
                  color: const Color(0xFF2E7D32),
                  cs: cs,
                  tt: tt,
                ),
                _QStatDivider(cs: cs),
                _QStatBox(
                  icon: Icons.trending_down_rounded,
                  label: 'Najgorszy',
                  value: '${worst.toStringAsFixed(1)}%',
                  color: cs.error,
                  cs: cs,
                  tt: tt,
                ),
              ],
            ),
          ),

          // Progress bar
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
                const SizedBox(height: 6),
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
          ),
          Text(
            label,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 11,
            ),
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
      height: 40,
      color: cs.outlineVariant.withValues(alpha: 0.4),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
