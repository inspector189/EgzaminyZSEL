// lib/logowanie.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ouath2_service.dart'; 

class LogowaniePage extends StatefulWidget {
  const LogowaniePage({super.key});

  @override
  State<LogowaniePage> createState() => _LogowaniePageState();
}

class _LogowaniePageState extends State<LogowaniePage> {
  String? _userName;
  String? _userEmail;
  bool _isLoading = false;

  Future<void> _loginWithMicrosoft() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    if (kIsWeb) {
      OAuth2Service.startLogin(); 
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logowanie tylko na webie')),
      );
    }
  }

  // Sprawdź, czy użytkownik jest już zalogowany
  Future<void> _checkLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('userName');
    final email = prefs.getString('userEmail');

    if (name != null && email != null) {
      setState(() {
        _userName = name;
        _userEmail = email;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _checkLoginState();
  }

  @override
  Widget build(BuildContext context) {
    // Jeśli już zalogowany – pokaż dane
    if (_userName != null && _userEmail != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Zalogowano")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              Text(
                'Zalogowano jako:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _userName!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(_userEmail!),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Powrót"),
              ),
            ],
          ),
        ),
      );
    }

    // Ekran logowania
    return Scaffold(
      appBar: AppBar(title: const Text("Logowanie z Microsoft")),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_circle, size: 80, color: Colors.blue),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    label: const Text("Zaloguj się z Microsoft"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: _loginWithMicrosoft,
                  ),
                ],
              ),
      ),
    );
  }
}