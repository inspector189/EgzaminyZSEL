import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  const ManageAdminsPage({super.key});

  @override
  State<ManageAdminsPage> createState() => _ManageAdminsPageState();
}

class _ManageAdminsPageState extends State<ManageAdminsPage> {
  List<AdminUser> admins = [];
  bool isLoading = true;
  bool isSuperAdmin = false;
  String? currentUserEmail;
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

    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail')?.trim();

    if (email == null || email.isEmpty) {
      if (mounted) {
        _showSnackBar('Brak danych logowania', isError: true);
      }
      setState(() => isLoading = false);
      return;
    }

    currentUserEmail = email;

    await Future.wait([_checkSuperAdminStatus(email), _fetchAdmins()]);

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _checkSuperAdminStatus(String email) async {
    try {
      final result = await ApiService.instance.checkSuperAdmin(email);

      if (result.isSuccess && mounted) {
        setState(() {
          isSuperAdmin = result.data ?? false;
        });
      }
    } catch (e, st) {
      if (mounted) {
        debugPrint('checkSuperAdmin error: $e\n$st');
        setState(() => isSuperAdmin = false);
      }
    }
  }

  Future<void> _fetchAdmins() async {
    try {
      final result = await ApiService.instance.fetchAdmins();

      if (!result.isSuccess) {
        _showSnackBar('Błąd serwera (${result.statusCode})', isError: true);
        return;
      }
      if (mounted) {
        setState(() {
          admins = result.data!.map((e) => AdminUser.fromJson(e)).toList();
        });
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('fetchAdmins error: $e\n$st');
      if (mounted) _showSnackBar('Nie udało się pobrać listy', isError: true);
    }
  }

  Future<bool> _addAdmin() async {
    if (!_formKey.currentState!.validate()) return false;
    final email = _emailController.text.trim();

    setState(() => isPerformingAction = true);

    try {
      final result = await ApiService.instance.addAdmin(email);

      if (!mounted) return false;

      if (!result.isSuccess || result.data?['success'] != true) {
        _showSnackBar(result.data?['error'] ?? 'Error', isError: true);
        return false;
      }

      _showSnackBar('Administrator dodany pomyślnie');
      _emailController.clear();
      await _refresh();
      return true;
    } catch (e) {
      if (mounted) _showSnackBar('Błąd podczas dodawania', isError: true);
      return false;
    } finally {
      if (mounted) setState(() => isPerformingAction = false);
    }
  }

  Future<bool> _toggleSuperAdmin(AdminUser user) async {
    if (user.email == currentUserEmail && user.isSuperAdmin) {
      _showSnackBar(
        'Nie możesz odebrać sobie statusu Admina Nadrzędnego!',
        isError: true,
      );
      return false;
    }
    if (mounted) {
      setState(() => isPerformingAction = true);
    }

    try {
      final result =
          user.isSuperAdmin
              ? await ApiService.instance.demoteSuperAdmin(user.id)
              : await ApiService.instance.promoteToSuperAdmin(user.id);

      if (!mounted) return false;

      if (!result.isSuccess || result.data?['success'] != true) {
        _showSnackBar(
          result.data?['error'] ?? result.data?['message'] ?? 'Nieznany błąd',
          isError: true,
        );
        return false;
      }

      _showSnackBar(
        user.isSuperAdmin
            ? 'Odebrano status Admina Nadrzędnego'
            : 'Nadano status Admina Nadrzędnego',
      );

      await _refresh();
      return true;
    } catch (e) {
      if (mounted) _showSnackBar('Brak połączenia z serwerem', isError: true);
      return false;
    } finally {
      if (mounted) setState(() => isPerformingAction = false);
    }
  }

  Future<bool> _deleteAdmin(AdminUser user) async {
    if (user.email == currentUserEmail) {
      _showSnackBar('Nie możesz usunąć samego siebie!', isError: true);
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Usunąć administratora?'),
            content: Text('Czy na pewno usunąć ${user.email}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Anuluj'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Usuń'),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return false;

    setState(() => isPerformingAction = true);

    try {
      final result = await ApiService.instance.deleteAdmin(user.id);

      if (!mounted) return false;

      if (!result.isSuccess || result.data?['success'] != true) {
        _showSnackBar(result.data?['error'] ?? 'Nieznany błąd', isError: true);
        return false;
      }

      _showSnackBar('Administrator usunięty');
      await _refresh();
      return true;
    } catch (e) {
      if (mounted) _showSnackBar('Błąd podczas usuwania', isError: true);
      return false;
    } finally {
      if (mounted) setState(() => isPerformingAction = false);
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await Future.wait([
      _checkSuperAdminStatus(currentUserEmail!),
      _fetchAdmins(),
    ]);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Zarządzanie administratorami')),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _refresh,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (isSuperAdmin)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Form(
                              key: _formKey,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _emailController,
                                      decoration: const InputDecoration(
                                        labelText:
                                            'Email nowego administratora',
                                        prefixIcon: Icon(Icons.email_outlined),
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.done,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Pole wymagane';
                                        }
                                        if (!v.contains('@') ||
                                            !v.contains('.')) {
                                          return 'Nieprawidłowy email';
                                        }
                                        return null;
                                      },
                                      onFieldSubmitted: (_) => _addAdmin(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton.icon(
                                    onPressed:
                                        isPerformingAction ? null : _addAdmin,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Dodaj'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        Card(
                          color: Colors.red.shade700,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_outline),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'Tryb tylko do odczytu - brak uprawnień administratora nadrzędnego!',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),

                      Expanded(
                        child:
                            admins.isEmpty
                                ? const Center(
                                  child: Text(
                                    'Brak administratorów w systemie!',
                                  ),
                                )
                                : ListView.builder(
                                  itemCount: admins.length,
                                  itemBuilder: (context, index) {
                                    final user = admins[index];
                                    final isCurrent =
                                        user.email == currentUserEmail;

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        leading:
                                            isCurrent
                                                ? Icon(
                                                  Icons.person,
                                                  color: colorScheme.primary,
                                                )
                                                : null,
                                        title: Text(
                                          user.email,
                                          style: TextStyle(
                                            fontWeight:
                                                isCurrent
                                                    ? FontWeight.bold
                                                    : null,
                                            color:
                                                isCurrent
                                                    ? colorScheme.primary
                                                    : null,
                                          ),
                                        ),
                                        subtitle:
                                            user.isSuperAdmin
                                                ? const Text(
                                                  'Administrator Nadrzędny',
                                                  style: TextStyle(
                                                    color: Colors.amber,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                )
                                                : null,
                                        trailing:
                                            isSuperAdmin
                                                ? Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: Icon(
                                                        user.isSuperAdmin
                                                            ? Icons.star
                                                            : Icons.star_border,
                                                        color: Colors.amber,
                                                        size: 28,
                                                      ),
                                                      tooltip:
                                                          user.isSuperAdmin
                                                              ? 'Odebranie statusu Administratora Nadrzędnego'
                                                              : 'Nadaj status Administratora Nadrzędnego',
                                                      onPressed:
                                                          isPerformingAction ||
                                                                  (user.isSuperAdmin &&
                                                                      isCurrent)
                                                              ? null
                                                              : () =>
                                                                  _toggleSuperAdmin(
                                                                    user,
                                                                  ),
                                                    ),
                                                    if (!isCurrent)
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.delete_outline,
                                                          color: Colors.red,
                                                        ),
                                                        tooltip:
                                                            'Usuń administratora',
                                                        onPressed:
                                                            isPerformingAction
                                                                ? null
                                                                : () =>
                                                                    _deleteAdmin(
                                                                      user,
                                                                    ),
                                                      )
                                                    else
                                                      const Padding(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                            ),
                                                        child: Icon(
                                                          Icons.block,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                  ],
                                                )
                                                : const Icon(
                                                  Icons.visibility,
                                                  color: Colors.grey,
                                                ),
                                      ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
