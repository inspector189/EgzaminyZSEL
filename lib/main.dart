import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'egzamin.dart';
import 'package:flutter/foundation.dart';
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
          surface: Color(0xFFD2D2D2),
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
        child: GestureDetector(
          onTap: () {
            // Pop all pages until the home page is reached
            _navigatorKey.currentState?.popUntil((route) => route.isFirst);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
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
            icon: Icon(widget.isDarkMode ? Icons.wb_sunny : Icons.nightlight_round),
            tooltip: 'Przełącz motyw',
            onPressed: widget.onToggleTheme,
          ),
        ],
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

// Widget for the home page content
class HomeContent extends StatelessWidget {
  const HomeContent({
    super.key,
    required this.isDarkMode,
    required this.onQualificationTap,
  });

  final bool isDarkMode;
  final Function(String) onQualificationTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Egzamin z teorii (test 40 pytań)',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 48,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Oferujemy tutaj całkowicie darmowy dostęp do ogromnej bazy pytań z informatycznych egzaminów zawodowych. '
            'Pytania pochodzą wprost z arkuszy z lat ubiegłych. Wybierz poniżej swoją kwalifikację i zacznij zdobywać wiedzę:',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Center(
            child: Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                _buildQualificationBox(
                  context,
                  title: 'INF.02 (dawniej EE.08)',
                  subtitle: 'sprzęt, systemy i sieci',
                  onTap: () => onQualificationTap('INF.02'),
                ),
                _buildQualificationBox(
                  context,
                  title: 'INF.03 (dawniej EE.09/E14)',
                  subtitle: 'programowanie',
                  onTap: () => onQualificationTap('INF.03'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualificationBox(
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
                    MaterialPageRoute(builder: (context) => const EgzaminView(tryb: TrybEgzaminu.jednoPytanie)),
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
                    MaterialPageRoute(builder: (context) => const EgzaminView(tryb: TrybEgzaminu.czterdziesciPytan)),
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
                    MaterialPageRoute(builder: (context) => const EgzaminView(tryb: TrybEgzaminu.wszystkie)),
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
