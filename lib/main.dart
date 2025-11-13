import 'widgets/question_tile.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'widgets/home_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_panel.dart';
import 'app_themes.dart';
import 'widgets/profile_popup.dart';
//import 'logowanie.dart';
import 'oauth2_service.dart';
import 'personalisation_page.dart';
import 'qualification_page.dart';
import 'statistics.dart';
import 'theme_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    final success = await OAuth2Service.handleRedirect();
    if (success) {
      cleanUrl();
    }
  }
  if (!kIsWeb) {
    try {
      final ByteData data = await rootBundle.load('assets/cert/interpage.cer');
      SecurityContext.defaultContext.setTrustedCertificatesBytes(
        data.buffer.asUint8List(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Błąd ładownaia certyfikatu: $e');
      }
    }
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

void cleanUrl() {
  if (kIsWeb) {
    final uri = Uri.parse(web.window.location.href);
    final cleanUri = uri.replace(queryParameters: {});
    web.window.history.replaceState(null, '', cleanUri.toString());
  }
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
      themeAnimationDuration: const Duration(milliseconds: 100),
      themeAnimationCurve: Curves.easeInOutCubic,
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

  bool _isVerifyingEmail = false;

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
    Future.microtask(_checkLoginState);
  }

  Future<void> _checkLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('userName');
    final userEmail = prefs.getString('userEmail');

    final bool isLoggedIn = userName != null && userEmail != null;

    if (kDebugMode) {
      debugPrint(
        'ℹ️ Sprawdzanie statusu logowania: userName=$userName, userEmail=$userEmail',
      );
    }
    setState(() {
      _isLoggedIn = isLoggedIn;
      _userName = isLoggedIn ? userName : null;
      _userEmail = isLoggedIn ? userEmail : null;
    });

    if (_isLoggedIn && _userEmail != null) {
      unawaited(_verifyEmail(_userEmail!));
    }

    if (kDebugMode) {
      debugPrint(
        '📥 Zweryfikowano parametry - Czy użytkownik jest zalogowany: _isLoggedIn=$_isLoggedIn, Czy użytkownik jest adminem: _isAdmin=$_isAdmin',
      );
    }
  }

  Future<void> _verifyEmail(String email) async {
    if (_isVerifyingEmail) return;
    _isVerifyingEmail = true;

    try {
      final url = Uri.parse('https://interpage.pl/egzaminy/verify-email.php');
      final response = await HttpService.postJson(url, {'email': email});

      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bool admin = data['isValid'] == true;

        if (mounted) {
          setState(() {
            _isAdmin = admin;
          });
        }

        if (kDebugMode) {
          debugPrint('✅ Weryfikacja email: isAdmin=$_isAdmin');
        }
      } else {
        if (mounted) {
          setState(() {
            _isAdmin = false;
          });
        }
        if (kDebugMode) {
          debugPrint(
            '❌ Weryfikacja email nie powiodła się: ${response?.statusCode}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAdmin = false;
        });
      }
      if (kDebugMode) debugPrint('❌ Błąd weryfikacji email: $e');
    } finally {
      _isVerifyingEmail = false;
    }
  }

  void _openStatistics(BuildContext context) {
    Future.microtask(() {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const StatisticsPage()),
        );
      }
    });
  }

  Future<void> _signOut() async {
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

  OverlayEntry? _currentProfilePopup;

  void _toggleProfilePopup(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_currentProfilePopup != null) {
      _closeProfilePopup();
      return;
    }

    late OverlayEntry overlayEntry;

    final controller = AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 250),
    );
    final fadeAnimation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
    );
    final slideAnimation = Tween<Offset>(
      begin: const Offset(0.2, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));

    overlayEntry = OverlayEntry(
      builder:
          (context) => Stack(
            children: [
              GestureDetector(
                onTap: _closeProfilePopup,
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
              Positioned(
                top: kToolbarHeight + 16,
                right: 16,
                width: 300,
                child: FadeTransition(
                  opacity: fadeAnimation,
                  child: SlideTransition(
                    position: slideAnimation,
                    child: ProfilePopup(
                      userName: _userName!,
                      userEmail: _userEmail!,
                      isAdmin: _isAdmin,
                      colorScheme: colorScheme,
                      onClose: _closeProfilePopup,
                      onOpenAdminPanel: () {
                        _closeProfilePopup();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminPanelPage(),
                          ),
                        );
                      },
                      onOpenPersonalisation: () {
                        _closeProfilePopup();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PersonalisationPage(),
                          ),
                        );
                      },
                      onOpenStatistics: () {
                        _closeProfilePopup();
                        _openStatistics(context);
                      },
                      onSignOut: () async {
                        _closeProfilePopup();
                        await _signOut();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
    );

    _currentProfilePopup = overlayEntry;
    Overlay.of(context).insert(overlayEntry);
    controller.forward();

    _profilePopupController = controller;
  }

  AnimationController? _profilePopupController;

  void _closeProfilePopup() {
    if (_currentProfilePopup == null) return;

    _profilePopupController?.reverse().then((_) {
      _currentProfilePopup?.remove();
      _currentProfilePopup = null;
      _profilePopupController?.dispose();
      _profilePopupController = null;
    });
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
    final colorScheme = Theme.of(context).colorScheme;
    if (title == 'Strona Główna') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
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
                borderRadius: BorderRadius.circular(16),
                color: Colors.transparent,
              ),
              child: Center(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onSecondary,
                    fontSize: 14,
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
        color: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (value) {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder:
                  (context) => QualificationPage(
                    qualification: value,
                    isAdmin: _isAdmin,
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
              style: TextStyle(
                color: colorScheme.onSecondary,
                fontSize: 14,
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
                    isAdmin: _isAdmin,
                  ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      drawer:
          MediaQuery.of(context).size.width <= 900
              ? Drawer(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: BoxDecoration(color: colorScheme.primary),
                      child: Text(
                        'Menu',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 24,
                        ),
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
                                          isAdmin: _isAdmin,
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
                                          isAdmin: _isAdmin,
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
                                          isAdmin: _isAdmin,
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
                                          isAdmin: _isAdmin,
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
                                          isAdmin: _isAdmin,
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
                          _toggleProfilePopup(context);
                        } else {
                          if (kIsWeb) {
                            try {
                              OAuth2Service.startLogin();
                              await _checkLoginState();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Zalogowano pomyślnie'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Błąd logowania: $e')),
                                );
                              }
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Logowanie dostępne tylko na webie',
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),

                    ListTile(
                      leading: Icon(
                        theme.brightness == Brightness.dark
                            ? Icons.wb_sunny
                            : Icons.nightlight_round,
                        color: colorScheme.onSurface,
                      ),
                      title: const Text('Przełącz motyw'),
                      onTap: () {
                        Navigator.pop(context);
                        Provider.of<ThemeProvider>(
                          context,
                          listen: false,
                        ).toggleTheme();
                      },
                    ),
                  ],
                ),
              )
              : null,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: colorScheme.primary,
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
                    color: colorScheme.onPrimary,
                    onPressed: () async {
                      if (_isLoggedIn) {
                        _toggleProfilePopup(context);
                      } else {
                        if (kIsWeb) {
                          try {
                            OAuth2Service.startLogin();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Błąd logowania: $e')),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Logowanie tylko na webie'),
                            ),
                          );
                        }
                      }
                    },
                  ),

                  IconButton(
                    icon: Icon(
                      theme.brightness == Brightness.dark
                          ? Icons.wb_sunny
                          : Icons.nightlight_round,
                      color: colorScheme.onPrimary,
                    ),
                    tooltip: 'Przełącz motyw',
                    onPressed: () {
                      Provider.of<ThemeProvider>(
                        context,
                        listen: false,
                      ).toggleTheme();
                    },
                  ),
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
        HomeHeader(selectedQuote: selectedQuote),
        const SizedBox(height: 40),
        _buildGrid('👨‍💻 Technik Programista', [
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
        _buildGrid('💻 Technik Informatyk', [
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
        _buildGrid('🌐 Technik Teleinformatyk', [
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
        _buildGrid('🧑‍🔧 Technik Elektronik', [
          QuestionTile(
            icon: Icons.devices_other,
            code: 'E.06',
            label: 'montaż urządzeń elektronicznych',
            onTap: onQualificationTap,
          ),
          QuestionTile(
            icon: Icons.bolt,
            code: 'EE.22',
            label: 'eksploatacja instalacji elektrycznych',
            onTap: onQualificationTap,
          ),
          QuestionTile(
            icon: Icons.analytics,
            code: 'ELM.02',
            label: 'instalacje i pomiary',
            onTap: onQualificationTap,
          ),
          QuestionTile(
            icon: Icons.build,
            code: 'ELM.05',
            label: 'serwis urządzeń elektronicznych',
            onTap: onQualificationTap,
          ),
        ]),
        _buildGrid('🧑‍🏭 Technik Elektryk', [
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
        _buildGrid('🤖 Technik Automatyk', [
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

  Widget _buildGrid(String title, List<QuestionTile> items) {
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

class HttpService {
  HttpService._();
  static final http.Client _client = http.Client();
  static const Duration _defaultTimeout = Duration(seconds: 10);

  static Future<http.Response?> postJson(
    Uri url,
    Object body, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _client
          .post(
            url,
            headers: headers ?? {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_defaultTimeout);
      return response;
    } catch (e) {
      if (kDebugMode) debugPrint('Json error: $e');
      return null;
    }
  }

  static Future<http.Response?> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _client
          .get(url, headers: headers)
          .timeout(_defaultTimeout);
      return response;
    } catch (e) {
      if (kDebugMode) debugPrint('Get error: $e');
      return null;
    }
  }
}

class QuestionCountCache {
  QuestionCountCache._();
  static final QuestionCountCache instance = QuestionCountCache._();

  final Map<String, Future<int?>> _cache = {};

  Future<int?> getCount(String code) {
    return _cache.putIfAbsent(
      code,
      () => Future.microtask(() => _fetchQuestionCount(code)),
    );
  }

  Future<int?> _fetchQuestionCount(String kwalifikacja) async {
    try {
      final sanitized = kwalifikacja.replaceAll('.', '').toLowerCase();
      final url = Uri.parse(
        'https://interpage.pl/egzaminy/count/countQuestions.php?egzamin=$sanitized',
      );
      debugPrint('Requesting: $url');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is Map && data.containsKey('count')) {
          return data['count'] as int;
        } else {
          debugPrint('⚠️ Nieprawidłowy format: $data');
        }
      } else {
        debugPrint('❌ Serwer zwrócił kod błędu ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Błąd podczas zbierania danych: $e');
    }

    return null;
  }
}
