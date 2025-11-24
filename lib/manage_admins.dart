import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

const String _apiBaseUrl = 'https://egzaminy.zsel.edu.pl/egzaminy';
const String _apiKey = 'zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^';

class ManageAdminsPage extends StatefulWidget {
  const ManageAdminsPage({super.key});
  @override
  State<ManageAdminsPage> createState() => _ManageAdminsPageState();
}

class _ManageAdminsPageState extends State<ManageAdminsPage> {
  List<dynamic> users = [];
  bool isLoading = true;
  bool isSuperAdmin = false;
  String? currentUserEmail;
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserAndCheckPermissions();
  }

  Future<void> _loadUserAndCheckPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail');

    if (email == null || email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brak danych logowania')),
        );
      }
      setState(() => isLoading = false);
      return;
    }

    setState(() => currentUserEmail = email);

    await Future.wait([
      _checkSuperAdminStatus(email),
      _fetchAdmins(),
    ]);

    setState(() => isLoading = false);
  }

  Future<void> _checkSuperAdminStatus(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/is_super_admin.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          isSuperAdmin = data['isSuperAdmin'] == true;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Błąd sprawdzania Administrator Nadrzędny: $e');
      setState(() => isSuperAdmin = false);
    }
  }

  Future<void> _fetchAdmins() async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/showAdmins.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $_apiKey',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          setState(() => users = data);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd ładowania listy: $e')),
        );
      }
    }
  }

  Future<void> _refreshAfterAction() async {
    if (currentUserEmail != null) {
      await _checkSuperAdminStatus(currentUserEmail!);
    }
    await _fetchAdmins();
  }

  // Akcje
  Future<void> _addAdmin(String email) async {
    if (!isSuperAdmin) return _noPermission();
    if (!email.contains('@')) return _showError('Nieprawidłowy email');

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/add_admin.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $_apiKey',
        },
        body: {'email': email.trim()},
      );
      if (response.statusCode == 200 && json.decode(response.body)['success'] == true) {
        _showSuccess('Administrator dodany');
        _emailController.clear();
        await _refreshAfterAction();
      }
    } catch (e) {
      _showError('Błąd dodawania');
    }
  }

 Future<void> _toggleSuperAdmin(int id, String email, bool currentlySuper) async {
    if (!isSuperAdmin) return _noPermission();

    if (email == currentUserEmail && currentlySuper) {
      _showError('Nie możesz odebrać sobie statusu Admina Nadrzędnego!');
      return;
    }

    final endpoint = currentlySuper
        ? '$_apiBaseUrl/demote_super_admin.php'
        : '$_apiBaseUrl/promote_super_admin.php';

    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $_apiKey',
        },
        body: {'id': id.toString()},
      );

      final responseBody = json.decode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        _showSuccess(currentlySuper
            ? 'Odebrano status Admina Nadrzędnego'
            : 'Nadano status Admina Nadrzędnego');
        await _refreshAfterAction();
      } else {
        final errorMsg = responseBody['error'] 
            ?? responseBody['message'] 
            ?? 'Nieznany błąd serwera';
        _showError(errorMsg);
      }
    } catch (e) {
      _showError('Brak połączenia z serwerem');
    }
  }

  Future<void> _deleteAdmin(int id, String email) async {
    if (!isSuperAdmin) return _noPermission();
    if (email == currentUserEmail) {
      _showError('Nie możesz usunąć samego siebie!');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usunąć administratora?'),
        content: Text('Usunąć $email?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usuń', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/delete_admin.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $_apiKey',
        },
        body: {'id': id.toString()},
      );

      if (response.statusCode == 200 && json.decode(response.body)['success'] == true) {
        _showSuccess('Administrator usunięty');
        await _refreshAfterAction();
      }
    } catch (e) {
      _showError('Błąd usuwania');
    }
  }

  void _noPermission() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Brak uprawnień Admina Nadrzędnego')),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Zarządzanie administratorami')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Panel dodawania
                  if (isSuperAdmin)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Nowy administrator (email)',
                                  prefixIcon: Icon(Icons.person_add),
                                ),
                                onSubmitted: (v) => _addAdmin(v.trim()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: () => _addAdmin(_emailController.text.trim()),
                              icon: const Icon(Icons.add),
                              label: const Text('Dodaj'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const Card(
                      color: Colors.orange,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline),
                            SizedBox(width: 12),
                            Text('Tryb tylko do odczytu – brak uprawnień Admina Nadrzędnego'),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  Expanded(
                    child: users.isEmpty
                        ? const Center(child: Text('Brak administratorów'))
                        : ListView.builder(
                            itemCount: users.length,
                            itemBuilder: (ctx, i) {
                              final user = users[i];
                              final String userEmail = user['email'];
                              final int userId = int.parse(user['id'].toString());
                              final bool isThisSuper = (user['SuperAdmin'] as int?) == 1;
                              final bool isCurrentUser = userEmail == currentUserEmail;

                              return Card(
                                child: ListTile(
                                  title: Text(
                                    userEmail,
                                    style: TextStyle(
                                      fontWeight: isCurrentUser ? FontWeight.bold : null,
                                      color: isCurrentUser ? colorScheme.primary : null,
                                    ),
                                  ),
                                  subtitle: isThisSuper
                                      ? const Text('Administrator Nadrzędny', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))
                                      : null,
                                  trailing: isSuperAdmin
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                isThisSuper ? Icons.star : Icons.star_border,
                                                color: Colors.amber,
                                                size: 32,
                                              ),
                                              tooltip: isThisSuper
                                                  ? 'Kliknij, aby odebrać status Admina Nadrzędnego'
                                                  : 'Kliknij, aby nadać status Admina Nadrzędnego',
                                              onPressed: (isThisSuper && isCurrentUser)
                                                  ? null
                                                  : () => _toggleSuperAdmin(userId, userEmail, isThisSuper),
                                            ),
                                            if (!isCurrentUser)
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red),
                                                tooltip: 'Usuń administratora',
                                                onPressed: () => _deleteAdmin(userId, userEmail),
                                              )
                                            else
                                              const Icon(Icons.block, color: Colors.grey),
                                          ],
                                        )
                                      : const Icon(Icons.visibility, color: Colors.grey),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}