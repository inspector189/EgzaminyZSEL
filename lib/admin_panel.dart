import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminPanelPage extends StatelessWidget {
  final bool isDarkMode;

  const AdminPanelPage({super.key, this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Administratora'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Witaj w panelu administratora',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.people),
            label: const Text('Zarządzaj użytkownikami'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageUsersPage()),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.bar_chart),
            label: const Text('Raporty i statystyki'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Funkcja w przygotowaniu 🚧')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
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
      final response = await http.get(
        Uri.parse('https://interpage.pl/egzaminy/showAdmins.php'),
        headers: {'Content-Type': 'application/json'},
      );
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty || response.body == '----------------------------------------------------------------------------------------------------') {
          throw Exception('Pusta odpowiedź – sprawdź PHP na serwerze');
        }
        final data = json.decode(response.body);
        if (data is List) {
          setState(() {
            users = data;
            isLoading = false;
            errorMessage = '';
          });
        } else if (data is Map && data.containsKey('error')) {
          throw Exception('Błąd serwera: ${data['error']}');
        } else {
          throw Exception('Nieprawidłowy format odpowiedzi');
        }
      } else {
        throw Exception('Błąd HTTP: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd ładowania: $e')),
      );
    }
  }

  Future<void> addUser(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaj poprawny email (musi zawierać @)')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://interpage.pl/egzaminy/add_admin.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'email': email},
      );
      print('Add Status: ${response.statusCode}');
      print('Add Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Administrator dodany ✅')),
          );
          _emailController.clear();
          fetchUsers();
        } else {
          throw Exception('Nie udało się dodać');
        }
      } else {
        throw Exception('Błąd HTTP: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd przy dodawaniu: $e')),
      );
    }
  }

  Future<void> deleteUser(int id) async {
    try {
      final response = await http.post(
        Uri.parse('https://interpage.pl/egzaminy/delete_admin.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'id': id.toString()},
      );
      print('Delete Status: ${response.statusCode}');
      print('Delete Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Administrator został usunięty ✅')),
          );
          fetchUsers();
        } else {
          throw Exception('Nie udało się usunąć');
        }
      } else {
        throw Exception('Błąd HTTP: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd przy usuwaniu: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zarządzaj użytkownikami')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Text('Błąd: $errorMessage\n\nSpróbuj ponownie', textAlign: TextAlign.center))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Nowy email',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => addUser(_emailController.text.trim()),
                            icon: const Icon(Icons.add),
                            label: const Text('Dodaj'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: users.isEmpty
                          ? const Center(child: Text('Brak adminów do zarządzania.'))
                          : ListView.builder(
                              itemCount: users.length,
                              itemBuilder: (context, index) {
                                final user = users[index];
                                return ListTile(
                                  leading: const Icon(Icons.email),
                                  title: Text(user['email']),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => deleteUser(int.parse(user['id'].toString())),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}