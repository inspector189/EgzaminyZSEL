import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LogowaniePage extends StatefulWidget {
  const LogowaniePage({super.key});

  @override
  State<LogowaniePage> createState() => _LogowaniePageState();
}

class _LogowaniePageState extends State<LogowaniePage> {
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _hasloController = TextEditingController();
  final TextEditingController _powtorzHasloController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isLoginMode = true;

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool isEmailValid(String email) {
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    return emailRegex.hasMatch(email);
  }

  Future<void> logowanie() async {
    if (_loginController.text.isEmpty || _hasloController.text.isEmpty) {
      showMessage('Uzupełnij login i hasło');
      return;
    }

    final url = Uri.parse('http://localhost/logowanie.php');

    try {
      final response = await http.post(
        url,
        body: {
          'login': _loginController.text,
          'haslo': _hasloController.text,
        },
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        showMessage('Zalogowano pomyślnie!');
        // Przejście do innej strony
      } else {
        showMessage('Niepoprawne dane logowania');
      }
    } catch (e) {
      showMessage('Błąd połączenia z serwerem');
    }
  }

  Future<void> rejestracja() async {
    final login = _loginController.text.trim();
    final haslo = _hasloController.text;
    final powtorzHaslo = _powtorzHasloController.text;
    final email = _emailController.text.trim();

    if (login.isEmpty || haslo.isEmpty || powtorzHaslo.isEmpty || email.isEmpty) {
      showMessage('Uzupełnij wszystkie pola');
      return;
    }

    if (haslo != powtorzHaslo) {
      showMessage('Hasła nie są takie same');
      return;
    }

    if (!isEmailValid(email)) {
      showMessage('Niepoprawny adres e-mail');
      return;
    }

    final url = Uri.parse('http://localhost/rejestracja.php');

    try {
      final response = await http.post(
        url,
        body: {
          'login': login,
          'haslo': haslo,
          'email': email,
        },
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        showMessage('Rejestracja zakończona pomyślnie!');
        setState(() => _isLoginMode = true);
      } else {
        showMessage(data['message'] ?? 'Błąd rejestracji');
      }
    } catch (e) {
      showMessage('Błąd połączenia z serwerem');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLoginMode ? 'Logowanie' : 'Rejestracja')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(
              controller: _loginController,
              decoration: const InputDecoration(labelText: 'Login'),
            ),
            TextField(
              controller: _hasloController,
              decoration: const InputDecoration(labelText: 'Hasło'),
              obscureText: true,
            ),
            if (!_isLoginMode)
              TextField(
                controller: _powtorzHasloController,
                decoration: const InputDecoration(labelText: 'Powtórz hasło'),
                obscureText: true,
              ),
            if (!_isLoginMode)
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoginMode ? logowanie : rejestracja,
              child: Text(_isLoginMode ? 'Zaloguj' : 'Zarejestruj'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoginMode = !_isLoginMode;
                });
              },
              child: Text(
                _isLoginMode
                    ? 'Nie masz konta? Zarejestruj się'
                    : 'Masz już konto? Zaloguj się',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
