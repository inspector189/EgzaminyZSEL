import 'dart:async';
import 'dart:math';

import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'widgets/home_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/admin_panel.dart';
import '/theme_personalisation.dart';
import '/qualification_exam_selection.dart';
import '/user_stats.dart';
import '/about_us.dart';

import '/services/oauth2_service.dart';
import '/services/api_service.dart';
import '/utils/helpers.dart';
import '/utils/qualifications_class.dart';
import '/utils/app_themes.dart';
import '/utils/theme_manager.dart';
import '/utils/quotes_array.dart';
import '/widgets/profile_popup.dart';
import '/widgets/question_tile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kUseFakeData) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', kFakeUserName);
    await prefs.setString('userEmail', kFakeEmail);
    await prefs.setBool('isAdmin', kFakeSuperAdmin);
    await prefs.setBool('isSuperAdmin', kFakeSuperAdmin);
  }

  if (kIsWeb && !kDebugMode) {
    final success = await OAuth2Service.handleRedirect();
    if (success) {
      cleanUrl();
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

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  late final String selectedQuote;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _isLoggedIn = false;
  String? _userName;
  String? _userEmail;
  bool _isAdmin = false;
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    selectedQuote = quotes[Random().nextInt(quotes.length)];
    Future.microtask(_checkLoginState);
  }

  @override
  void dispose() {
    _profileOverlay?.remove();
    _profileOverlay = null;
    _profileController?.dispose();
    _profileController = null;
    super.dispose();
  }

  Future<void> _syncWithServerSession() async {
    if (!kIsWeb) return;
    if (!_isLoggedIn || _userEmail == null) return;

    try {
      final result = await ApiService.instance.checkSession();

      if (result.statusCode == 401 || result.isNetworkError) {
        await _signOut(showSnack: false);
        if (kDebugMode) {
          debugPrint('${result.statusCode} - nastąpiło wylogowanie!');
        }
        return;
      }

      if (result.isSuccess) {
        final ok = result.data?['ok'] == true;
        if (!ok) {
          await _signOut(showSnack: false);
          if (kDebugMode) {
            debugPrint(
              'Brak aktualnej sesji na serwerze - nastąpiło wylogowanie!',
            );
          }
        } else {
          if (mounted) {
            setState(() {
              _isAdmin = result.data?['isAdmin'] == true;
              _isSuperAdmin = result.data?['isSuperAdmin'] == true;
            });
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Wystąpił błąd podczas sprawdzania sesji na serwerze: $e');
      }
    }
  }

  Future<void> _checkLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('userName');
    final userEmail = prefs.getString('userEmail');
    final isAdmin = prefs.getBool('isAdmin') ?? false;
    final isSuperAdmin = prefs.getBool('isSuperAdmin') ?? false;

    final bool isLoggedIn = userName != null && userEmail != null;

    if (kDebugMode) {
      if (isLoggedIn) {
        debugPrint(
          'Dane logowania: '
          'userName=$userName, userEmail=$userEmail, isAdmin=$isAdmin, isSuperAdmin=$isSuperAdmin.',
        );
      } else {
        debugPrint('Użytkownik nie jest zalogowany.');
      }
    }

    setState(() {
      _isLoggedIn = isLoggedIn;
      _userName = isLoggedIn ? userName : null;
      _userEmail = isLoggedIn ? userEmail : null;
      _isAdmin = isLoggedIn ? isAdmin : false;
      _isSuperAdmin = isLoggedIn ? isSuperAdmin : false;
    });

    if (!kUseFakeData) _syncWithServerSession();
  }

  Future<void> _showLoginInfoAndStart() async {
    final shouldLogin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Zaloguj się"),
        content: const Text(
          "Zaloguj się przy pomocy maila z domeną @zselektr.onmicrosoft.com.\n\n"
          "Dzięki zalogowaniu się jako uczeń będziesz miał możliwość "
          "sprawdzenia swoich statystyk oraz robienia testów z zestawu od nauczyciela.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Anuluj"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("OK"),
          ),
        ],
      ),
    );

    if (!shouldLogin!) return;

    try {
      OAuth2Service.startLogin();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Błąd logowania: $e")));
      }
    }
  }

  void _openStatistics(BuildContext context) {
    Future.microtask(() {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserStatisticsPage()),
        );
      }
    });
  }

  Future<void> _signOut({bool showSnack = true}) async {
    if (kIsWeb) {
      try {
        await ApiService.instance.logout();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Wystąpił błąd przy wylogowaniu: $e');
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userName');
    await prefs.remove('userEmail');
    await prefs.remove('isAdmin');
    await prefs.remove('isSuperAdmin');

    setState(() {
      _isLoggedIn = false;
      _userName = null;
      _userEmail = null;
      _isAdmin = false;
      _isSuperAdmin = false;
    });

    if (mounted && showSnack) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Wylogowano')));
    }
  }

  OverlayEntry? _profileOverlay;

  void _toggleProfilePopup() {
    if (_profileOverlay != null) {
      _closeProfilePopup();
      return;
    }

    final overlay = Overlay.of(context);

    _profileController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    final fade = CurvedAnimation(
      parent: _profileController!,
      curve: Curves.easeOut,
    );

    final slide =
        Tween<Offset>(
          begin: const Offset(0.0, -0.08),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _profileController!,
            curve: Curves.easeOutCubic,
          ),
        );

    final scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _profileController!, curve: Curves.easeOutCubic),
    );

    _profileOverlay = OverlayEntry(
      builder: (_) {
        final topPadding = MediaQuery.of(context).padding.top;
        final appBarHeight = kToolbarHeight;
        final popupTop = topPadding + appBarHeight + 8.0;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeProfilePopup,
              ),
            ),

            Positioned(
              top: popupTop,
              right: 12,
              width: 300,
              child: FadeTransition(
                opacity: fade,
                child: SlideTransition(
                  position: slide,
                  child: ScaleTransition(
                    scale: scale,
                    alignment: Alignment.topRight,
                    child: ProfilePopup(
                      userName: _userName!,
                      userEmail: _userEmail!,
                      isAdmin: _isAdmin,
                      isSuperAdmin: _isSuperAdmin,
                      onOpenAdminPanel: () {
                        _closeProfilePopup();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminPanelPage(
                              isSuperAdmin: _isSuperAdmin,
                              currentUserEmail: _userEmail ?? '',
                              currentUserName: _userName ?? '',
                            ),
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
            ),
          ],
        );
      },
    );

    overlay.insert(_profileOverlay!);
    _profileController!.forward();
  }

  AnimationController? _profileController;

  void _closeProfilePopup() {
    if (_profileOverlay == null) return;

    _profileController?.reverse().then((_) {
      _profileOverlay?.remove();
      _profileOverlay = null;
      _profileController?.dispose();
      _profileController = null;
    });
  }

  Widget buildPopupMenu(String title) {
    final cs = Theme.of(context).colorScheme;

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
                    color: cs.onSecondary,
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
    final profession = professions.firstWhere(
      (p) => p.name == title,
      orElse: () => Profession(name: '', qualifications: []),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: PopupMenuButton<Qualification>(
        tooltip: "technik $title",
        offset: const Offset(0, kToolbarHeight),
        color: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (qualification) {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => QualificationExamSelectionPage(
                qualification: qualification.code,
                isAdmin: _isAdmin,
                isLoggedIn: _isLoggedIn,
              ),
            ),
            ModalRoute.withName('/home'),
          );
        },
        itemBuilder: (context) {
          return profession.qualifications.map((q) {
            return PopupMenuItem<Qualification>(
              value: q,
              child: Row(
                children: [
                  Icon(q.icon, size: 20, color: cs.onPrimary),
                  const SizedBox(width: 8),
                  Text(q.code),
                ],
              ),
            );
          }).toList();
        },
        child: Container(
          constraints: const BoxConstraints(minWidth: 80),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "technik",
                  style: TextStyle(
                    color: cs.onSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: cs.onSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
              builder: (context) => QualificationExamSelectionPage(
                qualification: title,
                isAdmin: _isAdmin,
                isLoggedIn: _isLoggedIn,
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      drawer: width <= 900
          ? Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(color: cs.primary),
                    child: Text(
                      'Menu',
                      style: TextStyle(color: cs.onPrimary, fontSize: 24),
                    ),
                  ),
                  _drawerItem(context, 'Strona Główna'),

                  ...professions.map(
                    (profession) => ExpansionTile(
                      title: Text("technik ${profession.name}"),
                      children: profession.qualifications.map((q) {
                        return ListTile(
                          leading: Icon(q.icon),
                          title: Text(q.code),
                          onTap: () {
                            Navigator.pop(context);
                            _navigatorKey.currentState?.push(
                              MaterialPageRoute(
                                builder: (_) => QualificationExamSelectionPage(
                                  qualification: q.code,
                                  isAdmin: _isAdmin,
                                  isLoggedIn: _isLoggedIn,
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(_isLoggedIn ? Icons.person : Icons.login),
                    title: Text(_isLoggedIn ? 'Profil' : 'Logowanie'),
                    onTap: () async {
                      Navigator.pop(context);
                      if (_isLoggedIn) {
                        _toggleProfilePopup();
                      } else {
                        if (!kIsWeb) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Logowanie dostępne tylko na przeglądarce!",
                              ),
                            ),
                          );
                          return;
                        }
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _showLoginInfoAndStart();
                        });
                      }
                    },
                  ),

                  ListTile(
                    leading: Icon(switch (themeProvider.themeMode) {
                      ThemeMode.light => Icons.wb_sunny_rounded,
                      ThemeMode.dark => Icons.nightlight_rounded,
                      ThemeMode.system => Icons.brightness_auto_rounded,
                    }),
                    title: Text(switch (themeProvider.themeMode) {
                      ThemeMode.light => 'Motyw jasny',
                      ThemeMode.dark => 'Motyw ciemny',
                      ThemeMode.system => 'Motyw systemowy',
                    }),
                    onTap: () {
                      Navigator.pop(context);
                      themeProvider.toggleTheme();
                    },
                  ),
                ],
              ),
            )
          : null,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: cs.primary,
        actions: width > 900
            ? [
                const Spacer(),
                buildPopupMenu('Strona Główna'),
                ...professions.map((p) => buildPopupMenu(p.name)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.info_rounded),
                  tooltip: 'O nas',
                  color: cs.onPrimary,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutUsPage()),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    _isLoggedIn ? Icons.person_rounded : Icons.login_rounded,
                  ),
                  tooltip: _isLoggedIn ? 'Profil' : 'Logowanie',
                  color: cs.onPrimary,
                  onPressed: () async {
                    if (_isLoggedIn) {
                      _toggleProfilePopup();
                    } else {
                      if (!kIsWeb) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Logowanie dostępne tylko na przeglądarce!',
                            ),
                          ),
                        );
                        return;
                      }

                      _showLoginInfoAndStart();
                    }
                  },
                ),

                IconButton(
                  color: cs.onPrimary,
                  icon: Icon(switch (themeProvider.themeMode) {
                    ThemeMode.light => Icons.wb_sunny_rounded,
                    ThemeMode.dark => Icons.nightlight_rounded,
                    ThemeMode.system => Icons.brightness_auto_rounded,
                  }),
                  tooltip: (switch (themeProvider.themeMode) {
                    ThemeMode.light => 'Motyw jasny',
                    ThemeMode.dark => 'Motyw ciemny',
                    ThemeMode.system => 'Motyw systemowy',
                  }),
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
            builder: (context) => HomeContent(
              onQualificationTap: (qualification) {
                _navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (context) => QualificationExamSelectionPage(
                      qualification: qualification,
                      isAdmin: _isAdmin,
                      isLoggedIn: _isLoggedIn,
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
  final void Function(String) onQualificationTap;
  final String selectedQuote;

  const HomeContent({
    super.key,
    required this.onQualificationTap,
    required this.selectedQuote,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final width = MediaQuery.of(context).size.width;
    final hPad = width < 600 ? 20.0 : (width < 1000 ? 32.0 : width * 0.08);

    return ListView(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 32),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 32, bottom: 8),
          child: HomeHeader(selectedQuote: selectedQuote),
        ),

        const SizedBox(height: 32),
        ...professions.map((profession) {
          final tiles = profession.qualifications.map((q) {
            return QuestionTile(
              icon: q.icon,
              code: q.code,
              label: q.description,
              onTap: () => onQualificationTap(q.code),
            );
          }).toList();

          return _ProfessionSection(
            name: profession.name,
            tiles: tiles,
            cs: cs,
            tt: tt,
          );
        }),
      ],
    );
  }
}

class _ProfessionSection extends StatelessWidget {
  const _ProfessionSection({
    required this.name,
    required this.tiles,
    required this.cs,
    required this.tt,
  });

  final String name;
  final List<Widget> tiles;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  const SizedBox(width: 10),
                  Text(
                    'Technik $name',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: cs.onSurface,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 16, runSpacing: 16, children: tiles),
        ],
      ),
    );
  }
}
