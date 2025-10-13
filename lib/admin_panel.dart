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
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.people),
            label: const Text('Zarządzaj administratorami'),
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminStatsPage()),
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
        if (response.body.isEmpty ||
            response.body ==
                '----------------------------------------------------------------------------------------------------') {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd ładowania: $e')));
    }
  }

  Future<void> addUser(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Podaj poprawny email (musi zawierać znak "@")'),
        ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd przy dodawaniu: $e')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd przy usuwaniu: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zarządzaj administratorami')),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage.isNotEmpty
              ? Center(
                child: Text(
                  'Błąd: $errorMessage\n\nSpróbuj ponownie',
                  textAlign: TextAlign.center,
                ),
              )
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
                          onPressed:
                              () => addUser(_emailController.text.trim()),
                          icon: const Icon(Icons.add),
                          label: const Text('Dodaj'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child:
                        users.isEmpty
                            ? const Center(
                              child: Text('Brak adminów do zarządzania.'),
                            )
                            : ListView.builder(
                              itemCount: users.length,
                              itemBuilder: (context, index) {
                                final user = users[index];
                                return ListTile(
                                  leading: const Icon(Icons.email),
                                  title: Text(user['email']),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed:
                                        () => deleteUser(
                                          int.parse(user['id'].toString()),
                                        ),
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

  @override
  void initState() {
    super.initState();
    fetchAllStats();
  }

  Future<void> fetchAllStats() async {
    try {
      final url = Uri.parse('https://interpage.pl/egzaminy/stats_all.php');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^',
        },
      );

      print(
        '📥 Admin statistics response: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          setState(() {
            allResults = data;
            isLoading = false;
          });
        } else {
          throw Exception('Unexpected response format');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Map<String, List<dynamic>> groupByUser() {
    final Map<String, List<dynamic>> grouped = {};
    for (var r in allResults) {
      String user = (r['userID'] ?? '').toString().trim();
      if (user.isEmpty || user.toLowerCase() == 'anonymous') {
        user = 'Użytkownik anonimowy';
      }
      if (!grouped.containsKey(user)) grouped[user] = [];
      grouped[user]!.add(r);
    }
    return grouped;
  }

  Map<String, List<dynamic>> groupByQualification() {
    final Map<String, List<dynamic>> grouped = {};
    for (var r in allResults) {
      final q = (r['kwalifikacja'] ?? 'Nieznana').toString();
      if (!grouped.containsKey(q)) grouped[q] = [];
      grouped[q]!.add(r);
    }
    return grouped;
  }

  Map<String, dynamic> calculateStats(List<dynamic> results) {
    final scores = results.map((e) => (e['wynik'] as num).toDouble()).toList();
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    final best = scores.reduce((a, b) => a > b ? a : b);
    final worst = scores.reduce((a, b) => a < b ? a : b);
    return {'count': scores.length, 'avg': avg, 'best': best, 'worst': worst};
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorAccent =
        isDark ? Theme.of(context).colorScheme.primary : Colors.blue;

    final users = groupByUser();
    final qualifications = groupByQualification();

    final filteredUsers =
        users.entries
            .where(
              (e) => e.key.toLowerCase().contains(searchQuery.toLowerCase()),
            )
            .toList();

    filteredUsers.sort((a, b) {
      if (a.key == 'Użytkownik anonimowy') return 1;
      if (b.key == 'Użytkownik anonimowy') return -1;
      return a.key.compareTo(b.key);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Statystyki Egzaminów'),
        backgroundColor: colorAccent.withValues(alpha: 0.9),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : RefreshIndicator(
                onRefresh: fetchAllStats,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [

                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Szukaj użytkownika po nazwisku...',
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    Text(
                      '👤 Statystyki według użytkownika',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (filteredUsers.isEmpty)
                      const Text('Brak wyników dla tego użytkownika.'),

                    ...filteredUsers.map((entry) {
                      final user = entry.key;
                      final userStats = calculateStats(entry.value);
                      final isAnonymous = user == 'Użytkownik anonimowy';

                      final Map<String, List<dynamic>> examsByQual = {};
                      for (final exam in entry.value) {
                        final kwal = exam['kwalifikacja'] ?? 'Nieznana';
                        examsByQual.putIfAbsent(kwal, () => []).add(exam);
                      }

                      final visibleQualifications =
                          examsByQual.entries
                              .where((e) => e.value.isNotEmpty)
                              .toList();

                      if (isAnonymous) {
                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Liczba egzaminów: ${userStats['count']}',
                                    ),
                                    Text(
                                      'Śr. wynik: ${userStats['avg'].toStringAsFixed(2)}%',
                                      style: TextStyle(color: colorAccent),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Najlepszy: ${userStats['best']}%'),
                                    Text('Najgorszy: ${userStats['worst']}%'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          title: Text(
                            user,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Śr. wynik: ${userStats['avg'].toStringAsFixed(2)}% • Egzaminów: ${userStats['count']}',
                            style: TextStyle(color: colorAccent),
                          ),
                          childrenPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          children: [
                            ...visibleQualifications.map((qualEntry) {
                              final qual = qualEntry.key;
                              final qualStats = calculateStats(qualEntry.value);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '📘 $qual',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Egzaminów: ${qualStats['count']}',
                                        ),
                                        Text(
                                          'Śr. wynik: ${qualStats['avg'].toStringAsFixed(2)}%',
                                          style: TextStyle(color: colorAccent),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Najlepszy: ${qualStats['best']}%',
                                        ),
                                        Text(
                                          'Najgorszy: ${qualStats['worst']}%',
                                        ),
                                      ],
                                    ),
                                    const Divider(thickness: 1, height: 16),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 32),

                    // 🎓 Per qualification stats
                    Text(
                      '🎓 Statystyki według kwalifikacji',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...qualifications.entries.map((entry) {
                      final q = entry.key.toUpperCase();
                      final qStats = calculateStats(entry.value);

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors:
                                isDark
                                    ? [
                                      Theme.of(context).colorScheme.primary
                                          .withValues(alpha: 0.3),
                                      Theme.of(context).colorScheme.primary
                                          .withValues(alpha: 0.15),
                                    ]
                                    : [Colors.blue.shade100, Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: colorAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.school,
                                    color: colorAccent,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    q,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Egzaminów: ${qStats['count']}'),
                                  Text(
                                    'Śr: ${qStats['avg'].toStringAsFixed(2)}%',
                                    style: TextStyle(color: colorAccent),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Najlepszy: ${qStats['best']}%'),
                                  Text('Najgorszy: ${qStats['worst']}%'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
    );
  }
}
