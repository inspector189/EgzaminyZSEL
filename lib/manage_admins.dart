import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/modern_admin_row.dart';

const _apiKey = 'zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^';

class ManageAdminsPage extends StatefulWidget {
  const ManageAdminsPage({super.key});

  @override
  State<ManageAdminsPage> createState() => _ManageAdminsPageState();
}

class _ManageAdminsPageState extends State<ManageAdminsPage> {
  List users = [];
  bool isLoading = true;
  String errorMessage = '';
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> fetchUsers() async {
    try {
      final response = await http.post(
        Uri.parse('https://egzaminy.zsel.edu.pl/egzaminy/showAdmins.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $_apiKey',
        },
      );

      if (kDebugMode) {
        debugPrint('📥 Otrzymano odpowiedź: ${response.statusCode}');
        debugPrint('Treść: ${response.body}');
      }

      if (response.statusCode == 200) {
        if (response.body.isEmpty ||
            response.body ==
                '----------------------------------------------------------------------------------------------------') {
          throw Exception('❌ Pusta odpowiedź od serwera!');
        }
        final data = json.decode(response.body);
        if (data is List) {
          setState(() {
            users = data;
            isLoading = false;
            errorMessage = '';
          });
        } else if (data is Map && data.containsKey('error')) {
          throw Exception('❌ Błąd serwera: ${data['error']}');
        } else {
          throw Exception('❌ Nieprawidłowy format odpowiedzi!');
        }
      } else {
        throw Exception('❌ Kod błędu HTTP: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Błąd ładowania użytkowników: $e')),
        );
      }
    }
  }

  bool _isSnackBarVisible = false;

  Future<void> addUser(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      if (_isSnackBarVisible) return;
      _isSnackBarVisible = true;
      final controller = ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Podaj poprawny email (musi zawierać znak "@")'),
          duration: Duration(seconds: 3),
        ),
      );
      controller.closed.then((_) => _isSnackBarVisible = false);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://egzaminy.zsel.edu.pl/egzaminy/add_admin.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $_apiKey',
        },
        body: {'email': email},
      );

      if (kDebugMode) {
        debugPrint('📥 Otrzymano odpowiedź: ${response.statusCode}');
        debugPrint('Treść: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Administrator dodany')),
            );
          }
          _emailController.clear();
          fetchUsers();
        } else {
          throw Exception('❌ Dodanie administratora nie powiodło się!');
        }
      } else {
        throw Exception('❌ Kod błędu HTTP: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Błąd przy dodawaniu administratora: $e')),
        );
      }
    }
  }

  Future<void> deleteUser(int id) async {
    try {
      final response = await http.post(
        Uri.parse('https://egzaminy.zsel.edu.pl/egzaminy/delete_admin.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $_apiKey',
        },
        body: {'id': id.toString()},
      );

      if (kDebugMode) {
        debugPrint('📥 Otrzymano odpowiedź: ${response.statusCode}');
        debugPrint('Treść: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Administrator został usunięty')),
            );
          }
          fetchUsers();
        } else {
          throw Exception('❌ Nie udało się usunąć administratora!');
        }
      } else {
        throw Exception('❌ Kod błędu HTTP: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Błąd przy usuwaniu administratora: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Zarządzaj administratorami')),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText:
                                      'Adres e-mail nowego administratora',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                onSubmitted: (value) {
                                  addUser(value.trim());
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed:
                                  () => addUser(_emailController.text.trim()),
                              icon: const Icon(Icons.add),
                              label: const Text('Dodaj'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Expanded(
                      child:
                          users.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.admin_panel_settings_outlined,
                                      size: 48,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Brak adminów do zarządzania.',
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: users.length,
                                itemBuilder: (context, index) {
                                  final user = users[index];
                                  return ModernAdminRow(
                                    email: user['email'],
                                    onDelete:
                                        () => _confirmDeleteAdmin(
                                          context,
                                          int.parse(user['id'].toString()),
                                          user['email'],
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

  Future<void> _confirmDeleteAdmin(
    BuildContext context,
    int id,
    String email,
  ) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final screen = MediaQuery.of(context).size;
        final isDesktop = screen.width > 600;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1000 : double.infinity,
              minWidth: isDesktop ? 500 : 280,
            ),
            child: Material(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 48,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Usunąć administratora?',
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      email,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tego działania nie można cofnąć.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Anuluj'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Usuń'),
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.errorContainer,
                            foregroundColor: colorScheme.onErrorContainer,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      deleteUser(id);
    }
  }
}
