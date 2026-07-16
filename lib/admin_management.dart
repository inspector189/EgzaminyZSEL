import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '/services/api_service.dart';
import '/utils/async_state_view.dart';
import '/utils/helpers.dart';

// ─── Fake data for UI preview ────────────────────────────────────────────────

final _fakeAdmins = [
  AdminUser(
    id: 1,
    email: 'superadmin@zselektr.onmicrosoft.com',
    isSuperAdmin: true,
  ),
  AdminUser(
    id: 2,
    email: 'jan.kowalski@zselektr.onmicrosoft.com',
    isSuperAdmin: false,
  ),
  AdminUser(
    id: 3,
    email: 'anna.nowak@zselektr.onmicrosoft.com',
    isSuperAdmin: false,
  ),
  AdminUser(
    id: 4,
    email: 'piotr.wisniewski@zselektr.onmicrosoft.com',
    isSuperAdmin: true,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────

class AdminUser {
  final int id;
  final String email;
  final bool isSuperAdmin;

  AdminUser({
    required this.id,
    required this.email,
    required this.isSuperAdmin,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      email: json['email'] as String? ?? '',
      isSuperAdmin: (json['SuperAdmin'] as int? ?? 0) == 1,
    );
  }
}

class ManageAdminsPage extends StatefulWidget {
  final bool isSuperAdmin;
  final String currentUserEmail;

  const ManageAdminsPage({
    super.key,
    required this.isSuperAdmin,
    required this.currentUserEmail,
  });

  @override
  State<ManageAdminsPage> createState() => _ManageAdminsPageState();
}

class _ManageAdminsPageState extends State<ManageAdminsPage> {
  List<AdminUser> admins = [];
  bool isLoading = true;
  bool isPerformingAction = false;

  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    if (kUseFakeData) {
      if (!mounted) return;
      setState(() {
        admins = List.from(_fakeAdmins);
        isLoading = false;
      });
      return;
    }

    await _fetchAdmins();
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _fetchAdmins() async {
    try {
      final result = await ApiService.instance.fetchAdmins();
      if (!result.isSuccess) {
        _showSnackBar('Wystąpił błąd serwera (HTTP ${result.statusCode})', isError: true);
        return;
      }
      if (mounted) {
        setState(() {
          admins = result.data!.map((e) => AdminUser.fromJson(e)).toList();
        });
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Wystąpił błąd podczas ładowania administratorów: $e\n$st');
      }
      if (mounted) _showSnackBar('Pobieranie listy nie powiodło się', isError: true);
    }
  }

  Future<void> _addAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    setState(() => isPerformingAction = true);

    try {
      if (kUseFakeData) {
        if (!mounted) return;
        setState(() {
          admins.add(
            AdminUser(
              id: admins.length + 10,
              email: email,
              isSuperAdmin: false,
            ),
          );
        });
        _showSnackBar('Status administratora nadany pomyślnie');
        _emailController.clear();
        return;
      }

      final result = await ApiService.instance.addAdmin(email);
      if (!mounted) return;

      if (!result.isSuccess || result.data?['success'] != true) {
        _showSnackBar(result.data?['error'] ?? 'Error', isError: true);
        return;
      }

      _showSnackBar('Status administratora nadany pomyślnie');
      _emailController.clear();
      await _refresh();
    } catch (e) {
      if (mounted) _showSnackBar('Wystąpił błąd podczas dodawania administratora', isError: true);
    } finally {
      if (mounted) setState(() => isPerformingAction = false);
    }
  }

  Future<void> _toggleSuperAdmin(AdminUser user) async {
    if (user.email == widget.currentUserEmail && user.isSuperAdmin) {
      _showSnackBar(
        'Nie możesz odebrać sobie statusu Administratora Nadrzędnego!',
        isError: true,
      );
      return;
    }
    setState(() => isPerformingAction = true);

    try {
      if (kUseFakeData) {
        if (!mounted) return;
        setState(() {
          final idx = admins.indexWhere((a) => a.id == user.id);
          if (idx != -1) {
            admins[idx] = AdminUser(
              id: user.id,
              email: user.email,
              isSuperAdmin: !user.isSuperAdmin,
            );
          }
        });
        _showSnackBar(
          user.isSuperAdmin
              ? 'Odebrano status Administratora Nadrzędnego'
              : 'Nadano status Administratora Nadrzędnego',
        );
        return;
      }

      final result = user.isSuperAdmin
          ? await ApiService.instance.demoteSuperAdmin(user.id)
          : await ApiService.instance.promoteToSuperAdmin(user.id);

      if (!mounted) return;

      if (!result.isSuccess || result.data?['success'] != true) {
        _showSnackBar(
          result.data?['error'] ?? result.data?['message'] ?? 'Nieznany błąd',
          isError: true,
        );
        return;
      }

      _showSnackBar(
        user.isSuperAdmin
            ? 'Odebrano status Administratora Nadrzędnego'
            : 'Nadano status Administratora Nadrzędnego',
      );
      await _refresh();
    } catch (e) {
      if (mounted) _showSnackBar('Brak połączenia z serwerem', isError: true);
    } finally {
      if (mounted) setState(() => isPerformingAction = false);
    }
  }

  Future<void> _deleteAdmin(AdminUser user) async {
    if (user.email == widget.currentUserEmail) {
      _showSnackBar('Nie możesz usunąć swojego statusu administratora!', isError: true);
      return;
    }

    final cs = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usunąć status administratora?'),
        content: Text(
          'Czy na pewno chcesz usunąć ${user.email} z listy administratorów?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;
    setState(() => isPerformingAction = true);

    try {
      if (kUseFakeData) {
        setState(() => admins.removeWhere((a) => a.id == user.id));
        _showSnackBar('Status administratora został pomyślnie usunięty');
        return;
      }

      final result = await ApiService.instance.deleteAdmin(user.id);
      if (!mounted) return;

      if (!result.isSuccess || result.data?['success'] != true) {
        _showSnackBar(result.data?['error'] ?? 'Nieznany błąd', isError: true);
        return;
      }

      _showSnackBar('Status administratora został pomyślnie usunięty');
      await _refresh();
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Błąd podczas usuwania statusu administratora',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => isPerformingAction = false);
      }
    }
  }

  Future<void> _refresh() async {
    await _fetchAdmins();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? cs.error : cs.inverseSurface,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final width = MediaQuery.of(context).size.width;
    final hPad = width < 600 ? 16.0 : 24.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administratorzy'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        iconTheme: IconThemeData(color: cs.onPrimary),
      ),
      body: isLoading
          ? Center(child: AsyncStateView.loading())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // ── Permission banner ──────────────────────────
                  if (widget.isSuperAdmin)
                    _AddAdminCard(
                      formKey: _formKey,
                      controller: _emailController,
                      isPerformingAction: isPerformingAction,
                      onAdd: _addAdmin,
                      cs: cs,
                      tt: tt,
                    )
                  else
                    _ReadOnlyBanner(cs: cs, tt: tt),

                  const SizedBox(height: 24),

                  // ── Section label ──────────────────────────────
                  Row(
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
                        'LISTA ADMINISTRATORÓW (${admins.length})',
                        style: tt.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Admin list ─────────────────────────────────
                  if (admins.isEmpty)
                    _EmptyState(cs: cs, tt: tt)
                  else
                    ...admins.map(
                      (user) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AdminRow(
                          user: user,
                          isCurrent: user.email == widget.currentUserEmail,
                          isSuperAdmin: widget.isSuperAdmin,
                          isPerformingAction: isPerformingAction,
                          onToggleSuperAdmin: () => _toggleSuperAdmin(user),
                          onDelete: () => _deleteAdmin(user),
                          cs: cs,
                          tt: tt,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────
//               Add admin card
// ─────────────────────────────────────────────

class _AddAdminCard extends StatelessWidget {
  const _AddAdminCard({
    required this.formKey,
    required this.controller,
    required this.isPerformingAction,
    required this.onAdd,
    required this.cs,
    required this.tt,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool isPerformingAction;
  final VoidCallback onAdd;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person_add_rounded,
                    size: 18,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Nadaj status administratora',
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Adres email nowego administratora',
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 14,
                      ),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Pole jest wymagane!';
                      }
                      if (!v.contains('@') || !v.contains('.')) {
                        return 'Nieprawidłowy adres email!';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => onAdd(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: isPerformingAction ? null : onAdd,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Dodaj'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//                Read-only banner
// ─────────────────────────────────────────────

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            color: cs.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tryb tylko do odczytu — brak uprawnień Administratora Nadrzędnego.',
              style: tt.bodySmall?.copyWith(
                color: cs.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//               Admin row card
// ─────────────────────────────────────────────

class _AdminRow extends StatelessWidget {
  const _AdminRow({
    required this.user,
    required this.isCurrent,
    required this.isSuperAdmin,
    required this.isPerformingAction,
    required this.onToggleSuperAdmin,
    required this.onDelete,
    required this.cs,
    required this.tt,
  });
  final AdminUser user;
  final bool isCurrent;
  final bool isSuperAdmin;
  final bool isPerformingAction;
  final VoidCallback onToggleSuperAdmin;
  final VoidCallback onDelete;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? cs.primary.withValues(alpha: 0.3)
              : cs.outlineVariant.withValues(alpha: 0.35),
          width: isCurrent ? 1.5 : 1.0,
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
          // Accent bar
          Container(
            width: 4,
            height: 64,
            decoration: BoxDecoration(
              color: isCurrent
                  ? cs.primary
                  : cs.outlineVariant.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isCurrent
                  ? cs.primaryContainer
                  : cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              user.email.isNotEmpty ? user.email[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isCurrent ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Email + badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.email,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isCurrent ? cs.primary : cs.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.isSuperAdmin) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 12, color: cs.tertiary),
                      const SizedBox(width: 4),
                      Text(
                        'Administrator Nadrzędny',
                        style: tt.labelSmall?.copyWith(
                          color: cs.tertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Actions
          if (isSuperAdmin)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Super admin toggle
                Tooltip(
                  message: user.isSuperAdmin
                      ? 'Odbierz status Administratora Nadrzędnego'
                      : 'Nadaj status Administratora Nadrzędnego',
                  child: IconButton(
                    icon: Icon(
                      user.isSuperAdmin
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: user.isSuperAdmin
                          ? cs.tertiary
                          : cs.onSurfaceVariant,
                      size: 22,
                    ),
                    onPressed:
                        isPerformingAction || (user.isSuperAdmin && isCurrent)
                        ? null
                        : onToggleSuperAdmin,
                  ),
                ),
                // Delete
                if (!isCurrent)
                  Tooltip(
                    message: 'Usuń administratora',
                    child: IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: cs.error,
                        size: 22,
                      ),
                      onPressed: isPerformingAction ? null : onDelete,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Tooltip(
                      message:
                          'Nie możesz usunąć statusu administratora z własnego konta!',
                      child: Icon(
                        Icons.shield_rounded,
                        color: cs.primary.withValues(alpha: 0.4),
                        size: 22,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(
                Icons.visibility_outlined,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//                 Empty state
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 52,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Brak administratorów!',
            style: tt.titleSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Dodaj pierwszego administratora powyżej.',
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
