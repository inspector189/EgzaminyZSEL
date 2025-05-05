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
  final theme = Theme.of(context);
  return Scaffold(
    appBar: AppBar(title: Text(_isLoginMode ? 'Logowanie' : 'Rejestracja')),
    body: Center(
      child: Card(
        elevation: 8,
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isLoginMode ? Icons.lock_open : Icons.person_add,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _loginController,
                  decoration: InputDecoration(
                    labelText: 'Login',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _hasloController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Hasło',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (!_isLoginMode) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _powtorzHasloController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Powtórz hasło',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoginMode ? logowanie : rejestracja,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: Text(
                      _isLoginMode ? 'Zaloguj się' : 'Zarejestruj się',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => setState(() => _isLoginMode = !_isLoginMode),
                      child: Text(
                        _isLoginMode
                            ? 'Nie masz konta? Zarejestruj się'
                            : 'Masz już konto? Zaloguj się',
                        style: TextStyle(
                          color: theme.colorScheme.primary.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
