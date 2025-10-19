import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_html/flutter_html.dart';

const _apiKey = 'zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^';

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
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.bar_chart),
            label: const Text('Statystyki trudności pytań'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => QuestionStatsPage()),
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
      );
      if (kDebugMode) {
        debugPrint('📥 Otrzymano odpowiedź od serwera: ${response.statusCode}');
        debugPrint('Treść odpowiedzi: ${response.body}');
      }

      if (response.statusCode == 200) {
        if (response.body.isEmpty ||
            response.body ==
                '----------------------------------------------------------------------------------------------------') {
          throw Exception('❌ Pusta odpowiedź od serwera – sprawdź PHP!');
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Błąd ładowania użytkowników: $e')));
      }
    }
  }

  bool _isSnackBarVisible = false;

  Future<void> addUser(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      if (_isSnackBarVisible) return;

      _isSnackBarVisible = true;
      final messenger = ScaffoldMessenger.of(context);

      final controller = messenger.showSnackBar(
        const SnackBar(
          content: Text('❌ Podaj poprawny email (musi zawierać znak "@")'),
          duration: Duration(seconds: 3),
        ),
      );

      controller.closed.then((_) {
        _isSnackBarVisible = false;
      });

      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://interpage.pl/egzaminy/add_admin.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $_apiKey',
        },
        body: {'email': email},
      );
      if (kDebugMode) {
        debugPrint('📥 Otrzymano odpowiedź od serwera: ${response.statusCode}');
        debugPrint('Treść odpowiedzi: ${response.body}');
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
        Uri.parse('https://interpage.pl/egzaminy/delete_admin.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $_apiKey',
        },
        body: {'id': id.toString()},
      );
      if (kDebugMode) {
        debugPrint('📥 Otrzymano odpowiedź od serwera: ${response.statusCode}');
        debugPrint('Treść odpowiedzi: ${response.body}');
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
      if (kDebugMode) {
        debugPrint('📥 Otrzymano odpowiedź od serwera: ${response.statusCode}');
        debugPrint('Treść odpowiedzi: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          setState(() {
            allResults = data;
            isLoading = false;
          });
        } else {
          throw Exception(
            '❌ Nieprawidłowy format - dane nie są listą, a: ${data.runtimeType}',
          );
        }
      } else {
        throw Exception('❌ Kod błędu HTTP: ${response.statusCode}');
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

  String _fmtDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '-';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
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
                        hintText: 'Wyszukaj użytkownika..',
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
                      final exams = entry.value;

                      // Sortowanie po dacie egzaminu (najnowszy pierwszy)
                      exams.sort((a, b) {
                        final da =
                            DateTime.tryParse(a['data_czas'] ?? '') ??
                            DateTime(2000);
                        final db =
                            DateTime.tryParse(b['data_czas'] ?? '') ??
                            DateTime(2000);
                        return db.compareTo(da);
                      });

                      // Ostatni egzamin
                      final lastExam = exams.isNotEmpty ? exams.first : null;
                      final lastExamScore =
                          lastExam?['wynik']?.toString() ?? '-';
                      final lastExamDate =
                          lastExam?['data_czas']?.toString() ?? '-';

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
                            'Śr. wynik: ${userStats['avg'].toStringAsFixed(2)}% • '
                            'Egzaminów: ${userStats['count']} • '
                            'Ostatni: $lastExamScore% ($lastExamDate)',
                            style: TextStyle(color: colorAccent),
                          ),
                          childrenPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          children: [
                            ...visibleQualifications.map((qualEntry) {
                              final qual = qualEntry.key;

                              final List<dynamic> qualExams =
                                  List<dynamic>.from(qualEntry.value);

                              // sort: najnowsze pierwsze
                              qualExams.sort((a, b) {
                                final da =
                                    DateTime.tryParse(a['data_czas'] ?? '') ??
                                    DateTime(2000);
                                final db =
                                    DateTime.tryParse(b['data_czas'] ?? '') ??
                                    DateTime(2000);
                                return db.compareTo(da);
                              });

                              // TOP 5 (lub mniej)
                              final recent = qualExams.take(5).toList();

                              final qualStats = calculateStats(qualEntry.value);

                              String scoreStr(dynamic v) {
                                if (v is num) {
                                  return v.toStringAsFixed(v % 1 == 0 ? 0 : 2);
                                }
                                return v?.toString() ?? '-';
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  childrenPadding: const EdgeInsets.only(
                                    left: 8,
                                    right: 0,
                                    bottom: 8,
                                  ),
                                  title: Row(
                                    children: [
                                      const Text(
                                        '📘 ',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      Expanded(
                                        child: Text(
                                          qual,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Row(
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
                                  ),
                                  children: [
                                    if (recent.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12.0,
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          '❌ Brak egzaminów dla tej kwalifikacji.',
                                        ),
                                      )
                                    else
                                      ...recent.map((exam) {
                                        final date =
                                            (exam['data_czas'] ?? '-')
                                                as String;
                                        final wynik = scoreStr(exam['wynik']);
                                        final czas = _fmtDuration(
                                          (exam['czas_trwania_sec'] is int)
                                              ? exam['czas_trwania_sec'] as int
                                              : int.tryParse(
                                                '${exam['czas_trwania_sec'] ?? ''}',
                                              ),
                                        );
                                        final tryb =
                                            (exam['tryb'] ?? exam['mode'] ?? '')
                                                as String;

                                        return ListTile(
                                          contentPadding: const EdgeInsets.only(
                                            left: 12,
                                            right: 0,
                                          ),
                                          leading: const Icon(Icons.history),
                                          title: Text(date),
                                          subtitle: Text(
                                            'Wynik: $wynik% • Czas: $czas${tryb.isNotEmpty ? ' • Tryb: $tryb' : ''}',
                                          ),
                                          dense: true,
                                          visualDensity: const VisualDensity(
                                            vertical: -2,
                                          ),
                                        );
                                      }),
                                    const Divider(thickness: 1, height: 8),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 32),

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
class QuestionStatsPage extends StatefulWidget {
  const QuestionStatsPage({super.key});

  @override
  _QuestionStatsPageState createState() => _QuestionStatsPageState();
}

class _QuestionStatsPageState extends State<QuestionStatsPage> {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> questionStats = [];

  @override
  void initState() {
    super.initState();
    fetchQuestionStats();
  }

  Future<void> fetchQuestionStats() async {
    try {
      final response = await http.get(
        Uri.parse('https://interpage.pl/egzaminy/wyswietl_trudnosci.php'),
      );
      if (kDebugMode) {
        debugPrint('📥 Status: ${response.statusCode}');
        debugPrint('📄 Treść: ${response.body.substring(0, 200)}...');
      }
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          final enrichedStats = await Future.wait(data.map((item) async {
            final trudnosc = (item['trudnosc'] is num)
                ? (item['trudnosc'] as num).toDouble()
                : double.tryParse(item['trudnosc'].toString()) ?? 0.0;
            final pytanieId = item['pytanie_id'];
            final kwalifikacja = item['kwalifikacja']?.replaceAll(' ', '') ?? 'default';
            final questionData = await fetchQuestionDetails(pytanieId, kwalifikacja);
            return {
              'pytanie_id': pytanieId,
              'kwalifikacja': item['kwalifikacja'],
              'ilosc_odpowiedzi': item['ilosc_odpowiedzi'],
              'ilosc_poprawnych_odpowiedzi': item['ilosc_poprawnych_odpowiedzi'],
              'trudnosc': trudnosc,
              ...questionData,
            };
          }).toList());
          setState(() {
            questionStats = enrichedStats;
            isLoading = false;
            errorMessage = null;
          });
        } else {
          throw Exception('Nieprawidłowy format: ${data.runtimeType}');
        }
      } else {
        throw Exception('Błąd serwera: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Błąd sieci: ${e.message}. Spróbuj na mobile.';
      });
      _showErrorSnackBar('Błąd sieci – testuj na Android/iOS!');
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Błąd: $e';
      });
      _showErrorSnackBar('Błąd: $e');
    }
  }

  Future<Map<String, dynamic>> fetchQuestionDetails(String? pytanieId, String kwalifikacja) async {
    try {
      final url = Uri.parse('https://interpage.pl/egzaminy/$kwalifikacja.php');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          final question = data.firstWhere(
            (q) => q['id'].toString() == pytanieId,
            orElse: () => null,
          );
          if (question != null) {
            return {
              'pytanie': question['pytanie'] ?? 'Brak treści pytania',
              'odp1': question['odp1'] ?? 'Brak odpowiedzi 1',
              'odp2': question['odp2'] ?? 'Brak odpowiedzi 2',
              'odp3': question['odp3'] ?? 'Brak odpowiedzi 3',
              'odp4': question['odp4'] ?? 'Brak odpowiedzi 4',
              'poprawna': question['poprawna'] ?? 'Brak poprawnej odpowiedzi',
            };
          }
        }
      }
      return {
        'pytanie': 'Brak treści pytania',
        'odp1': 'Brak odpowiedzi 1',
        'odp2': 'Brak odpowiedzi 2',
        'odp3': 'Brak odpowiedzi 3',
        'odp4': 'Brak odpowiedzi 4',
        'poprawna': 'Brak poprawnej odpowiedzi',
      };
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Błąd pobierania szczegółów pytania: $e');
      return {
        'pytanie': 'Błąd pobierania treści',
        'odp1': 'Błąd pobierania odpowiedzi',
        'odp2': 'Błąd pobierania odpowiedzi',
        'odp3': 'Błąd pobierania odpowiedzi',
        'odp4': 'Błąd pobierania odpowiedzi',
        'poprawna': 'Błąd pobierania odpowiedzi',
      };
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Map<String, List<dynamic>> groupByQualification() {
    final Map<String, List<dynamic>> grouped = {};
    for (var r in questionStats) {
      final q = (r['kwalifikacja'] ?? 'Nieznana').toString();
      final iloscOdp = int.tryParse(r['ilosc_odpowiedzi']?.toString() ?? '0') ?? 0;
      final trudnosc = (r['trudnosc'] is num ? r['trudnosc'] : double.tryParse(r['trudnosc'].toString()) ?? 0.0) as double;
      if (iloscOdp >= 2 && trudnosc > 0) { // Filtruj tylko pytania z badge'ami
        grouped.putIfAbsent(q, () => []);
        grouped[q]!.add(r);
      }
    }
    return Map.fromEntries(grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  Html _html(BuildContext context, String html) {
    html = html.replaceAll('<img', '<br><img');
    return Html(
      data: html,
      style: {
        "body": Style(color: Theme.of(context).colorScheme.onSurface),
        "b": Style(color: Theme.of(context).colorScheme.onSurface),
        "span": Style(
          color: html.contains("style='color:green;'")
              ? Colors.green
              : Theme.of(context).colorScheme.onSurface,
        ),
      },
      extensions: [
        TagExtension(
          tagsToExtend: {'img'},
          builder: (extensionContext) {
            final src = extensionContext.attributes['src'];
            if (src != null) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Tooltip(
                    message: 'Kliknij, aby powiększyć',
                    child: GestureDetector(
                      onTap: () => _showImageDialog(context, src),
                      child: Image.network(
                        src,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Text(
                          '❌ Nie udało się załadować obrazka',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return Text(
              '⚠️ Brak obrazka',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            );
          },
        ),
      ],
    );
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Zamknij',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        final screenSize = MediaQuery.of(context).size;
        bool isPressed = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return GestureDetector(
              onTap: () => Navigator.of(context, rootNavigator: true).pop(),
              child: Scaffold(
                backgroundColor: Colors.black.withValues(alpha: 0.9),
                body: Stack(
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: () {},
                        child: Listener(
                          onPointerDown: (_) => setState(() => isPressed = true),
                          onPointerUp: (_) => setState(() => isPressed = false),
                          child: MouseRegion(
                            cursor: isPressed
                                ? SystemMouseCursors.grabbing
                                : SystemMouseCursors.grab,
                            child: InteractiveViewer(
                              panEnabled: true,
                              minScale: 0.5,
                              maxScale: 4,
                              child: Image.network(
                                imageUrl,
                                width: screenSize.width * 0.8,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Text(
                                  '❌ Nie udało się załadować obrazka',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 30,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        tooltip: 'Zamknij',
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDifficultyBadge(dynamic stat) {
    final trudnoscRaw = stat['trudnosc'];
    final iloscOdp = int.tryParse(stat['ilosc_odpowiedzi']?.toString() ?? '0') ?? 0;
    if (trudnoscRaw == null || iloscOdp < 2) return const SizedBox.shrink();

    final trudnosc = (trudnoscRaw is num ? trudnoscRaw : trudnoscRaw.toInt()) as int;
    final isTrudne = trudnosc > 50;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isTrudne ? Colors.red : Colors.green,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${isTrudne ? 'TRUDNE' : 'ŁATWE'} ($trudnosc%)',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildQuestionCard(dynamic q) {
    final questionId = q['pytanie_id'] ?? '-';
    final qualification = q['kwalifikacja'] ?? '-';
    final totalAnswers = q['ilosc_odpowiedzi'] ?? '0';
    final correctAnswers = q['ilosc_poprawnych_odpowiedzi'] ?? '0';
    final difficulty = q['trudnosc']?.toStringAsFixed(1) ?? '0';
    final successRate = totalAnswers != '0' ? ((int.parse(correctAnswers) / int.parse(totalAnswers)) * 100).toStringAsFixed(1) : '0';
    final pytanie = q['pytanie'] ?? 'Brak treści pytania';
    final odp1 = q['odp1'] ?? 'Brak odpowiedzi 1';
    final odp2 = q['odp2'] ?? 'Brak odpowiedzi 2';
    final odp3 = q['odp3'] ?? 'Brak odpowiedzi 3';
    final odp4 = q['odp4'] ?? 'Brak odpowiedzi 4';
    final poprawna = q['poprawna'] ?? 'Brak poprawnej odpowiedzi';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _html(context, "<b>Pytanie #$questionId</b>"),
                ),
                _buildDifficultyBadge(q),
              ],
            ),
            const SizedBox(height: 10),
            _html(context, "<b>Pytanie:</b><br>$pytanie"),
            const SizedBox(height: 10),
            ...['A', 'B', 'C', 'D'].map((litera) {
              final odp = {
                'A': odp1,
                'B': odp2,
                'C': odp3,
                'D': odp4,
              }[litera] ?? 'Brak odpowiedzi';
              final isCorrectAnswer = litera == poprawna;

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCorrectAnswer ? Colors.green : null,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: () {},
                  child: _html(context, odp),
                ),
              );
            }),
            const SizedBox(height: 6),
            _html(
              context,
              "<b>✅ Odpowiedź poprawna to: <span style='color:green;'>$poprawna</span></b>",
            ),
            const SizedBox(height: 4),
            Text('Kwalifikacja: $qualification', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text('Odpowiedzi: $totalAnswers')),
                Expanded(child: Text('Poprawne: $correctAnswers ($successRate%)')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = groupByQualification();

    return Scaffold(
      appBar: AppBar(
        title: const Text('📉 Statystyki Trudności Pytań'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchQuestionStats,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: fetchQuestionStats,
                          child: const Text('Spróbuj ponownie'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: fetchQuestionStats,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: grouped.length,
                    itemBuilder: (context, index) {
                      final entry = grouped.entries.elementAt(index);
                      final kwal = entry.key;
                      final questions = entry.value;
                      // Sortowanie od najtrudniejszych do najłatwiejszych
                      questions.sort((a, b) {
                        final trudnoscA = (a['trudnosc'] is num ? a['trudnosc'] : double.tryParse(a['trudnosc'].toString()) ?? 0.0) as double;
                        final trudnoscB = (b['trudnosc'] is num ? b['trudnosc'] : double.tryParse(b['trudnosc'].toString()) ?? 0.0) as double;
                        return trudnoscB.compareTo(trudnoscA); // Od najtrudniejszych
                      });

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ExpansionTile(
                          title: Row(
                            children: [
                              Icon(Icons.school, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$kwal (${questions.length} pytań)',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          children: questions.map<Widget>(_buildQuestionCard).toList(),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}