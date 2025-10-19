import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme_manager.dart';
import 'personalisation_page.dart';
import 'app_themes.dart';
import 'dart:io';
import 'logowanie.dart';
import 'qualification_page.dart';
import 'statistics.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ouath2_service.dart';
import 'admin_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    ByteData data = await rootBundle.load('assets/cert/interpage.cer');
    SecurityContext.defaultContext.setTrustedCertificatesBytes(
      data.buffer.asUint8List(),
    );
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Egzaminy',
      theme: AppThemes.lightTheme(
        themeProvider.primaryColor,
        themeProvider.secondaryColor,
      ),
      darkTheme: AppThemes.darkTheme(
        themeProvider.primaryColor,
        themeProvider.secondaryColor,
      ),
      themeMode: themeProvider.themeMode,
      home: const MyHomePage(title: 'Egzaminy'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final String selectedQuote;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _isLoggedIn = false;
  String? _userName;
  String? _userEmail;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    final quotes = [
      '„Nie uczysz się dla szkoły, lecz dla siebie.” – Seneka',
      '„Nauka to potęgi klucz.” – Ignacy Krasicki',
      '„Człowiek uczy się przez całe życie.”',
      '„Wiedza to potęga.”',
      '„Im więcej wiem, tym więcej wiem, że nic nie wiem.” – Sokrates',
      '„Uczyć się to odkrywać to, co już wiesz. Działać to pokazywać, że to wiesz.” – Richard Bach',
      '„Uczenie się jest jak wiosłowanie pod prąd – gdy przestajesz, cofasz się.” – Edward Benjamin Britten',
      '„Kiedy uczymy innych, uczymy się podwójnie.” – Joseph Joubert',
      '„Inwestycja w wiedzę zawsze przynosi największe zyski.” – Benjamin Franklin',
      '„Nie ma większej siły niż wiedza i nie ma większej wolności niż edukacja.” – Malcolm X',
      '„Edukacja jest najpotężniejszą bronią, której możesz użyć, aby zmienić świat.” – Nelson Mandela',
      '„Nauka bez myślenia jest bezużyteczna. Myślenie bez nauki – niebezpieczne.” – Konfucjusz',
      '„Błąd jest dowodem na to, że próbujesz.” – Jennifer Lim',
      '„Ciekawość jest początkiem mądrości.” – Sokrates',
      '„Uczymy się nie dla szkoły, lecz dla życia.” – Seneka Młodszy',
      '„Sukces to suma niewielkiego wysiłku powtarzanego dzień po dniu.” – Robert Collier',
      '„Edukacja to nie wypełnianie wiadra, lecz rozpalanie ognia.” – William Butler Yeats',
      '„Nie musisz być wielki, by zacząć, ale musisz zacząć, by być wielki.” – Zig Ziglar',
      '„Każdy mistrz kiedyś był początkującym.” – Robin Sharma',
      '„Ucz się tak, jakbyś miał żyć wiecznie.” – Gandhi',
      '„Ucz się, ucz, bo nauka to potęgi klucz, a kto ma dużo kluczy... zostaje woźnym.” – Ludowa mądrość z przestrogą',
    ];
    selectedQuote = quotes[Random().nextInt(quotes.length)];
    _checkLoginState();
  }

  Future<void> _checkLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('userName');
    final userEmail = prefs.getString('userEmail');
    if (kDebugMode) {
      debugPrint(
        'ℹ️ Sprawdzanie statusu logowania: userName=$userName, userEmail=$userEmail',
      );
    }
    setState(() {
      _isLoggedIn = userName != null && userEmail != null;
      if (_isLoggedIn) {
        _userName = userName;
        _userEmail = userEmail;
      }
    });

    if (_isLoggedIn && _userEmail != null) {
      await _verifyEmail(_userEmail!);
    }

    if (kDebugMode) {
      debugPrint(
        '📥 Zweryfikowano parametry - Czy użytkownik jest zalogowany: _isLoggedIn=$_isLoggedIn, Czy użytkownik jest adminem: _isAdmin=$_isAdmin',
      );
    }
  }

  Future<void> _verifyEmail(String email) async {
    try {
      final url = Uri.parse('https://interpage.pl/egzaminy/verify-email.php');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isAdmin = data['isValid'] == true;
        });
        if (kDebugMode) {
          debugPrint('✅ Weryfikacja email: _isAdmin ustawiony na $_isAdmin');
        }
      } else {
        setState(() {
          _isAdmin = false;
        });
        if (kDebugMode) {
          debugPrint(
            '❌ Weryfikacja email nie powiodła się: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      setState(() {
        _isAdmin = false;
      });
      if (kDebugMode) {
        debugPrint('❌ Błąd podczas weryfikacji email: $e');
      }
    }
  }

  void _openStatistics(BuildContext context) {
    Future.delayed(Duration.zero, () {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => StatisticsPage()),
        );
      }
    });
  }

  Future<void> _signOut() async {
    await OAuth2Service.instance.oauth2Helper.removeAllTokens();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userName');
    await prefs.remove('userEmail');
    setState(() {
      _isLoggedIn = false;
      _userName = null;
      _userEmail = null;
      _isAdmin = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Wylogowano')));
    }
  }

  void _showProfilePopup(BuildContext context) {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 80, 0, 0),
      items: [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[300],
                    child: Text(
                      _userName![0].toUpperCase(),
                      style: const TextStyle(fontSize: 20, color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _userEmail!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 5),
                  const Text('Dostępny', style: TextStyle(fontSize: 12)),
                ],
              ),
              const Divider(),

              if (_isAdmin)
                PopupMenuItem(
                  child: const Text('Panel Administratora'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminPanelPage(),
                      ),
                    );
                  },
                ),
              PopupMenuItem(
                child: const Text('Personalizacja'),
                onTap: () {
                  Future.delayed(Duration.zero, () {
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PersonalisationPage(),
                        ),
                      );
                    }
                  });
                },
              ),

              PopupMenuItem(
                child: const Text('Statystyki'),
                onTap: () {
                  _openStatistics(context);
                },
              ),
              PopupMenuItem(onTap: _signOut, child: const Text('Wyloguj się')),
            ],
          ),
        ),
      ],
      color: Theme.of(context).colorScheme.surface,
    );
  }

  List<String> getMenuItems(String category) {
    switch (category) {
      case 'Programista':
        return ['INF 03', 'INF 04'];
      case 'Informatyk':
        return ['INF 03', 'INF 02'];
      case 'Elektryk':
        return ['ELE.05', 'ELM.02', 'ELE.02', 'E.08'];
      case 'Elektronik':
        return ['ELM.05', 'E.06', 'ELM.02', 'EE.22'];
      case 'Teleinformatyk':
        return ['INF.08', 'INF.07'];
      case 'Automatyk':
        return ['ELM.04', 'ELM.01'];
      default:
        return [];
    }
  }

  Widget buildPopupMenu(String title) {
    if (title == 'Strona Główna') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () {
              _navigatorKey.currentState?.popUntil((route) => route.isFirst);
            },
            child: Container(
              constraints: const BoxConstraints(minWidth: 80),
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.transparent,
              ),
              child: Center(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: PopupMenuButton<String>(
        tooltip: title,
        offset: const Offset(0, kToolbarHeight),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (value) {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder:
                  (context) => QualificationPage(
                    qualification: value,
                    isAdmin: _isAdmin, // ⬅️
                  ),
            ),
            ModalRoute.withName('/home'),
          );
        },
        itemBuilder: (context) {
          return getMenuItems(title).map((item) {
            return PopupMenuItem<String>(value: item, child: Text(item));
          }).toList();
        },
        child: Container(
          constraints: const BoxConstraints(minWidth: 80),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(BuildContext context, String title) {
    return ListTile(
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        if (title == 'Strona Główna') {
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        } else {
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder:
                  (context) => QualificationPage(
                    qualification: title,
                    isAdmin: _isAdmin, // ⬅️
                  ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer:
          MediaQuery.of(context).size.width <= 900
              ? Drawer(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      child: const Text(
                        'Menu',
                        style: TextStyle(color: Colors.white, fontSize: 24),
                      ),
                    ),
                    _drawerItem(context, 'Strona Główna'),
                    ExpansionTile(
                      title: const Text('Programista'),
                      children:
                          getMenuItems('Programista').map((kwal) {
                            return ListTile(
                              title: Text(kwal),
                              onTap: () {
                                Navigator.pop(context);
                                _navigatorKey.currentState?.push(
                                  MaterialPageRoute(
                                    builder:
                                        (context) => QualificationPage(
                                          qualification: kwal,
                                          isAdmin: _isAdmin,
                                        ),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                    ),
                    ExpansionTile(
                      title: const Text('Informatyk'),
                      children:
                          getMenuItems('Informatyk').map((kwal) {
                            return ListTile(
                              title: Text(kwal),
                              onTap: () {
                                Navigator.pop(context);
                                _navigatorKey.currentState?.push(
                                  MaterialPageRoute(
                                    builder:
                                        (context) => QualificationPage(
                                          qualification: kwal,
                                          isAdmin: _isAdmin, // ⬅️
                                        ),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                    ),
                    ExpansionTile(
                      title: const Text('Elektryk'),
                      children:
                          getMenuItems('Elektryk').map((kwal) {
                            return ListTile(
                              title: Text(kwal),
                              onTap: () {
                                Navigator.pop(context);
                                _navigatorKey.currentState?.push(
                                  MaterialPageRoute(
                                    builder:
                                        (context) => QualificationPage(
                                          qualification: kwal,
                                          isAdmin: _isAdmin, // ⬅️
                                        ),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                    ),
                    ExpansionTile(
                      title: const Text('Elektronik'),
                      children:
                          getMenuItems('Elektronik').map((kwal) {
                            return ListTile(
                              title: Text(kwal),
                              onTap: () {
                                Navigator.pop(context);
                                _navigatorKey.currentState?.push(
                                  MaterialPageRoute(
                                    builder:
                                        (context) => QualificationPage(
                                          qualification: kwal,
                                          isAdmin: _isAdmin, // ⬅️
                                        ),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                    ),
                    ExpansionTile(
                      title: const Text('Teleinformatyk'),
                      children:
                          getMenuItems('Teleinformatyk').map((kwal) {
                            return ListTile(
                              title: Text(kwal),
                              onTap: () {
                                Navigator.pop(context);
                                _navigatorKey.currentState?.push(
                                  MaterialPageRoute(
                                    builder:
                                        (context) => QualificationPage(
                                          qualification: kwal,
                                          isAdmin: _isAdmin, // ⬅️
                                        ),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                    ),
                    ExpansionTile(
                      title: const Text('Automatyk'),
                      children:
                          getMenuItems('Automatyk').map((kwal) {
                            return ListTile(
                              title: Text(kwal),
                              onTap: () {
                                Navigator.pop(context);
                                _navigatorKey.currentState?.push(
                                  MaterialPageRoute(
                                    builder:
                                        (context) => QualificationPage(
                                          qualification: kwal,
                                          isAdmin: _isAdmin, // ⬅️
                                        ),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                    ),
                    const Divider(),
                    ListTile(
                      leading: Icon(_isLoggedIn ? Icons.person : Icons.login),
                      title: Text(_isLoggedIn ? 'Profil' : 'Logowanie'),
                      onTap: () async {
                        Navigator.pop(context);
                        if (_isLoggedIn) {
                          _showProfilePopup(context);
                        } else {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LogowaniePage(),
                            ),
                          );

                          if (result == true) {
                            _checkLoginState();
                          }
                        }
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        Theme.of(context).brightness == Brightness.dark
                            ? Icons.wb_sunny
                            : Icons.nightlight_round,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      title: const Text('Przełącz motyw'),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              )
              : null,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions:
            MediaQuery.of(context).size.width > 900
                ? [
                  const Spacer(),
                  buildPopupMenu('Strona Główna'),
                  buildPopupMenu('Programista'),
                  buildPopupMenu('Informatyk'),
                  buildPopupMenu('Elektryk'),
                  buildPopupMenu('Elektronik'),
                  buildPopupMenu('Teleinformatyk'),
                  buildPopupMenu('Automatyk'),
                  const Spacer(),
                  IconButton(
                    icon: Icon(_isLoggedIn ? Icons.person : Icons.login),
                    tooltip: _isLoggedIn ? 'Profil' : 'Logowanie',
                    onPressed: () async {
                      if (_isLoggedIn) {
                        _showProfilePopup(context);
                      } else {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LogowaniePage(),
                          ),
                        );

                        if (result == true) {
                          _checkLoginState();
                        }
                      }
                    },
                  ),
                  /*IconButton(
                    icon: Icon(
                      Theme.of(context).brightness == Brightness.dark
                          ? Icons.wb_sunny
                          : Icons.nightlight_round,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    tooltip: 'Przełącz motyw',
                    
                  ),*/
                ]
                : null,
      ),
      body: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            settings: const RouteSettings(name: '/home'),
            builder:
                (context) => HomeContent(
                  onQualificationTap: (qualification) {
                    _navigatorKey.currentState?.push(
                      MaterialPageRoute(
                        builder:
                            (context) => QualificationPage(
                              qualification: qualification,
                              isAdmin: _isAdmin,
                            ),
                      ),
                    );
                  },
                  selectedQuote: selectedQuote,
                ),
          );
        },
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  final Function(String) onQualificationTap;
  final String selectedQuote;

  const HomeContent({
    super.key,
    required this.onQualificationTap,
    required this.selectedQuote,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Witamy w aplikacji Egzaminy! 👋',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Przygotuj się do egzaminu zawodowego z najlepszą bazą pytań! Poniżej znajdziesz kwalifikacje, które możesz przeglądać:',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              '💬 $selectedQuote',
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        const SizedBox(height: 40),
        _buildGrid(context, '👨‍💻 Technik Programista', [
          QuestionTile(
            icon: Icons.code,
            code: 'INF.03',
            label: 'programowanie i aplikacje',
            onTap: onQualificationTap,
          ),
          QuestionTile(
            icon: Icons.router,
            code: 'INF.04',
            label: 'administrowanie siecią',
            onTap: onQualificationTap,
          ),
        ]),
        _buildGrid(context, '💻 Technik Informatyk', [
          QuestionTile(
            icon: Icons.code,
            code: 'INF.03',
            label: 'programowanie i aplikacje',
            onTap: onQualificationTap,
          ),
          QuestionTile(
            icon: Icons.memory,
            code: 'INF.02',
            label: 'sprzęt, systemy i sieci',
            onTap: onQualificationTap,
          ),
        ]),
        _buildGrid(context, '🌐 Technik Teleinformatyk', [
          QuestionTile(
            icon: Icons.security,
            code: 'INF.08',
            label: 'usługi sieciowe i bezpieczeństwo',
            onTap: onQualificationTap,
          ),
          QuestionTile(
            icon: Icons.network_check,
            code: 'INF.07',
            label: 'systemy i urządzenia sieciowe',
            onTap: onQualificationTap,
          ),
        ]),
        _buildGrid(context, '🧑‍🔧 Technik Elektronik', [
          Column(
            children: [
              QuestionTile(
                icon: Icons.devices_other,
                code: 'E.06',
                label: 'montaż urządzeń elektronicznych',
                onTap: onQualificationTap,
              ),
              const SizedBox(height: 20),
              QuestionTile(
                icon: Icons.bolt,
                code: 'EE.22',
                label: 'eksploatacja instalacji elektrycznych',
                onTap: onQualificationTap,
              ),
            ],
          ),
          Column(
            children: [
              QuestionTile(
                icon: Icons.analytics,
                code: 'ELM.02',
                label: 'instalacje i pomiary',
                onTap: onQualificationTap,
              ),
              const SizedBox(height: 20),
              QuestionTile(
                icon: Icons.build,
                code: 'ELM.05',
                label: 'serwis urządzeń elektronicznych',
                onTap: onQualificationTap,
              ),
            ],
          ),
        ]),
        _buildGrid(context, '🧑‍🏭 Technik Elektryk', [
          QuestionTile(
            icon: Icons.precision_manufacturing,
            code: 'ELE.05',
            label: 'eksploatacja maszyn i urządzeń',
            onTap: onQualificationTap,
          ),
          QuestionTile(
            icon: Icons.electrical_services,
            code: 'ELE.02',
            label: 'układy elektryczne',
            onTap: onQualificationTap,
          ),
          QuestionTile(
            icon: Icons.cable,
            code: 'E.08',
            label: 'sieci lokalne i konfiguracja',
            onTap: onQualificationTap,
          ),
        ]),
        _buildGrid(context, '🤖 Technik Automatyk', [
          QuestionTile(
            icon: Icons.build_circle,
            code: 'ELM.01',
            label: 'montaż automatyki przemysłowej',
            onTap: onQualificationTap,
          ),
          QuestionTile(
            icon: Icons.settings_input_component,
            code: 'ELM.04',
            label: 'układy automatyki',
            onTap: onQualificationTap,
          ),
          QuestionTile(
            icon: Icons.electrical_services,
            code: 'EE.18',
            label: '(opcjonalne)',
            onTap: onQualificationTap,
          ),
        ]),
      ],
    );
  }

  Widget _buildGrid(BuildContext context, String title, List<Widget> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 20,
            children: items,
          ),
        ],
      ),
    );
  }
}

Future<int?> fetchQuestionCount(String kwalifikacja) async {
  try {
    final sanitized = kwalifikacja.replaceAll('.', '').toLowerCase();
    final url = Uri.parse('https://interpage.pl/egzaminy/$sanitized.php');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data.length;
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ Błąd podczas pobierania danych: $e');
    }
  }
  return null;
}

class QuestionTile extends StatefulWidget {
  final IconData icon;
  final String code;
  final String label;
  final Function(String) onTap;

  const QuestionTile({
    super.key,
    required this.icon,
    required this.code,
    required this.label,
    required this.onTap,
  });

  @override
  State<QuestionTile> createState() => _QuestionTileState();
}

class _QuestionTileState extends State<QuestionTile> {
  int? questionCount;

  @override
  void initState() {
    super.initState();
    fetchQuestionCount(widget.code).then((value) {
      if (mounted) {
        setState(() {
          questionCount = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    double itemWidth = screenWidth < 600 ? screenWidth - 40 : 300;

    return InkWell(
      onTap: () => widget.onTap(widget.code),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: itemWidth,
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              size: 36,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              widget.code,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              questionCount != null ? '$questionCount pytań' : '⏳ Ładowanie...',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
