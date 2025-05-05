import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'egzamin.dart';
import 'logowanie.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'dart:ui';
void main() async {
   WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    ByteData data = await rootBundle.load('assets/cert/interpage.cer');
    SecurityContext.defaultContext.setTrustedCertificatesBytes(data.buffer.asUint8List());
  }

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Egzaminy',
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFFFF7373),
          onPrimary: Color(0xFFFF7373),
          surface: Colors.white,
          onSurface: Colors.black,
          secondary: Colors.blue,
          onSecondary: Colors.white,
          background: Color(0xFFD2D2D2),
          error: Colors.red,
          onError: Colors.redAccent,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFFFF7373),
          onPrimary: Color(0xFFFF7373),
          surface: Color(0xFF222222),
          onSurface: Colors.white,
          secondary: Colors.blueAccent,
          onSecondary: Colors.white,
          background: Color(0xFF222222),
          error: Colors.red,
          onError: Colors.redAccent,
        ),
      ),
      themeMode: _themeMode,
      home: MyHomePage(
        title: 'Egzaminy',
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  final String title;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

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
    // Handle "Strona Główna" separately
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
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
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


    // Other categories use PopupMenuButton
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: PopupMenuButton<String>(
        tooltip: title,
        offset: const Offset(0, kToolbarHeight),
        color: widget.isDarkMode ? Color(0xFF666666) : Color(0xFFAAAAAA),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onSelected: (value) {
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => QualificationPage(
                qualification: value,
                isDarkMode: widget.isDarkMode,
              ),
            ),
          );
        },
        itemBuilder: (context) {
          return getMenuItems(title).map((item) {
            return PopupMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList();
        },
        child: Container(
          constraints: const BoxConstraints(minWidth: 80),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
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
            builder: (context) => QualificationPage(
              qualification: title,
              isDarkMode: widget.isDarkMode,
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
  drawer: MediaQuery.of(context).size.width <= 900
      ? Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Text(
                  'Menu',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
              _drawerItem(context, 'Strona Główna'),
              ExpansionTile(
              title: const Text('Programista'),
              children: getMenuItems('Programista').map((kwal) {
                return ListTile(
                  title: Text(kwal),
                  onTap: () {
                    Navigator.pop(context);
                    _navigatorKey.currentState?.push(
                      MaterialPageRoute(
                        builder: (context) => QualificationPage(
                          qualification: kwal,
                          isDarkMode: widget.isDarkMode,
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
              ExpansionTile(
                title: const Text('Informatyk'),
                children: getMenuItems('Informatyk').map((kwal) {
                  return ListTile(
                    title: Text(kwal),
                    onTap: () {
                      Navigator.pop(context);
                      _navigatorKey.currentState?.push(
                        MaterialPageRoute(
                          builder: (context) => QualificationPage(
                            qualification: kwal,
                            isDarkMode: widget.isDarkMode,
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
              ExpansionTile(
                title: const Text('Elektryk'),
                children: getMenuItems('Elektryk').map((kwal) {
                  return ListTile(
                    title: Text(kwal),
                    onTap: () {
                      Navigator.pop(context);
                      _navigatorKey.currentState?.push(
                        MaterialPageRoute(
                          builder: (context) => QualificationPage(
                            qualification: kwal,
                            isDarkMode: widget.isDarkMode,
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
              ExpansionTile(
                title: const Text('Elektronik'),
                children: getMenuItems('Elektronik').map((kwal) {
                  return ListTile(
                    title: Text(kwal),
                    onTap: () {
                      Navigator.pop(context);
                      _navigatorKey.currentState?.push(
                        MaterialPageRoute(
                          builder: (context) => QualificationPage(
                            qualification: kwal,
                            isDarkMode: widget.isDarkMode,
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
              ExpansionTile(
                title: const Text('Teleinformatyk'),
                children: getMenuItems('Teleinformatyk').map((kwal) {
                  return ListTile(
                    title: Text(kwal),
                    onTap: () {
                      Navigator.pop(context);
                      _navigatorKey.currentState?.push(
                        MaterialPageRoute(
                          builder: (context) => QualificationPage(
                            qualification: kwal,
                            isDarkMode: widget.isDarkMode,
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
              ExpansionTile(
                title: const Text('Automatyk'),
                children: getMenuItems('Automatyk').map((kwal) {
                  return ListTile(
                    title: Text(kwal),
                    onTap: () {
                      Navigator.pop(context);
                      _navigatorKey.currentState?.push(
                        MaterialPageRoute(
                          builder: (context) => QualificationPage(
                            qualification: kwal,
                            isDarkMode: widget.isDarkMode,
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Logowanie'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LogowaniePage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(widget.isDarkMode ? Icons.wb_sunny : Icons.nightlight_round),
                title: const Text('Przełącz motyw'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onToggleTheme();
                },
              ),
            ],
          ),
        )
      : null,

  appBar: AppBar(
    title: Text(widget.title),
    backgroundColor: Theme.of(context).colorScheme.primary,
    actions: MediaQuery.of(context).size.width > 900
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
              icon: const Icon(Icons.login),
              tooltip: 'Logowanie',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LogowaniePage()),
                );
              },
            ),
            IconButton(
              icon: Icon(widget.isDarkMode ? Icons.wb_sunny : Icons.nightlight_round),
              tooltip: 'Przełącz motyw',
              onPressed: widget.onToggleTheme,
            ),
          ]
        : null,
  ),
      body: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => HomeContent(
              isDarkMode: widget.isDarkMode,
              onQualificationTap: (qualification) {
                _navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (context) => QualificationPage(
                      qualification: qualification,
                      isDarkMode: widget.isDarkMode,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  final bool isDarkMode;
  final Function(String) onQualificationTap;

  const HomeContent({
    super.key,
    required this.isDarkMode,
    required this.onQualificationTap,
  });

  @override
  Widget build(BuildContext context) {
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
];
    final random = Random();
    final selectedQuote = quotes[random.nextInt(quotes.length)];

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
          _item(context, Icons.code, 'INF.03', 'programowanie i aplikacje'),
          _item(context, Icons.router, 'INF.04', 'administrowanie siecią'),
        ]),
        _buildGrid(context, '💻 Technik Informatyk', [
          _item(context, Icons.code, 'INF.03', 'programowanie i aplikacje'),
          _item(context, Icons.memory, 'INF.02', 'sprzęt, systemy i sieci'),
        ]),
        _buildGrid(context, '🌐 Technik Teleinformatyk', [
          _item(context, Icons.security, 'INF.08', 'usługi sieciowe i bezpieczeństwo'),
          _item(context, Icons.network_check, 'INF.07', 'systemy i urządzenia sieciowe'),
        ]),
        _buildGrid(context, '🧑‍🔧 Technik Elektronik', [
          Column(
            children: [
              _item(context, Icons.devices_other, 'E.06', 'montaż urządzeń elektronicznych'),
              const SizedBox(height: 20),
              _item(context, Icons.bolt, 'EE.22', 'eksploatacja instalacji elektrycznych'),
            ],
          ),
          Column(
            children: [
              _item(context, Icons.analytics, 'ELM.02', 'instalacje i pomiary'),
              const SizedBox(height: 20),
              _item(context, Icons.build, 'ELM.05', 'serwis urządzeń elektronicznych'),
            ],
          ),
        ]),
        _buildGrid(context, '🧑‍🏭 Technik Elektryk', [
          _item(context, Icons.precision_manufacturing, 'ELE.05', 'eksploatacja maszyn i urządzeń'),
          _item(context, Icons.electrical_services, 'ELE.02', 'układy elektryczne'),
          _item(context, Icons.cable, 'E.08', 'sieci lokalne i konfiguracja'),
        ]),
        _buildGrid(context, '🤖 Technik Automatyk', [
          _item(context, Icons.build_circle, 'ELM.01', 'montaż automatyki przemysłowej'),
          _item(context, Icons.settings_input_component, 'ELM.04', 'układy automatyki'),
          _item(context, Icons.electrical_services, 'EE.18', '(opcjonalne)'),
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

  Widget _item(BuildContext context, IconData icon, String code, String label) {
    final screenWidth = MediaQuery.of(context).size.width;
    double itemWidth = screenWidth < 600 ? screenWidth - 40 : 300;

    return InkWell(
      onTap: () => onQualificationTap(code),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: itemWidth,
        height: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: const Color(0xFFFF7373)),
            const SizedBox(height: 12),
            Text(
              code,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            )
          ],
        ),
      ),
    );
  }
}

// Widget for the qualification page
class QualificationPage extends StatelessWidget {
  const QualificationPage({
    super.key,
    required this.qualification,
    required this.isDarkMode,
  });

  final String qualification;
  final bool isDarkMode;
Widget _buildQuestionsBox(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(Icons.assignment, size: 50, color: const Color(0xFFFF7373)),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(qualification),
        backgroundColor: Theme.of(context).colorScheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),

        child: Center(
          child: Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
             _buildQuestionsBox(
  context,
  title: 'Losuj 1 pytanie',
  subtitle: 'Sprawdź swoją wiedzę',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EgzaminView(
                tryb: TrybEgzaminu.jednoPytanie,
                kwalifikacja: qualification.toLowerCase().replaceAll('.', ''),
                isDarkMode: isDarkMode, // Przekazanie isDarkMode
                ),
              ),
            );
          },
        ),
        _buildQuestionsBox(
          context,
          title: 'Test 40 losowych pytań',
          subtitle: 'Pełny egzamin próbny',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EgzaminView(
                  tryb: TrybEgzaminu.czterdziesciPytan,
                  kwalifikacja: qualification.toLowerCase().replaceAll('.', ''),
                  isDarkMode: isDarkMode, // Przekazanie isDarkMode
                ),
              ),
            );
          },
        ),
        _buildQuestionsBox(
          context,
          title: 'Baza wszystkich odpowiedzi',
          subtitle: 'Przeglądaj wszystkie pytania',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EgzaminView(
                  tryb: TrybEgzaminu.wszystkie,
                  kwalifikacja: qualification.toLowerCase().replaceAll('.', ''),
                  isDarkMode: isDarkMode, // Przekazanie isDarkMode
                ),
              ),
            );
          },
        ),
            ],
          ),
        ),
      ),
    );
  }
}
