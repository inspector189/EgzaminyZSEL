import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
//import 'package:oauth2_client/oauth2_helper.dart';
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
    if (kDebugMode) {
      debugPrint('📢 Uruchamianie procesu logowania...');
    }
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Zezwól na wyskakujące okna dla interpage.pl, aby się zalogować',
          ),
        ),
      );
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 100));
    if (!_isLoading) return;
    final existingToken =
        await OAuth2Service.instance.oauth2Helper.getTokenFromStorage();
    if (kDebugMode) {
      debugPrint('✔️ Token już istnieje: ${existingToken?.toMap()}');
    }

    if (existingToken != null &&
        existingToken.accessToken != null &&
        existingToken.isValid()) {
      if (kDebugMode) {
        debugPrint('🔃 Używanie istniejącego tokena...');
      }
      try {
        final userResponse = await OAuth2Service.instance.oauth2Helper.get(
          'https://graph.microsoft.com/v1.0/me',
          headers: {'Authorization': 'Bearer ${existingToken.accessToken}'},
        );
        if (kDebugMode) {
          debugPrint(
            '📥 Otrzymano odpowiedź od serwera: ${userResponse.statusCode}',
          );
        }
        if (userResponse.statusCode == 200) {
          final json = jsonDecode(userResponse.body);
          setState(() {
            _userName = json['displayName'];
            _userEmail = json['mail'] ?? json['userPrincipalName'];
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userName', _userName!);
          await prefs.setString('userEmail', _userEmail!);
          if (kDebugMode) {
            debugPrint(
              '📝 Zapisano dane użytkownika: name=$_userName, email=$_userEmail',
            );
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Zalogowano jako $_userName')),
            );
            Navigator.pop(context, true);
          }
          setState(() => _isLoading = false);
          return;
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint(
            '❌ Wystąpił błąd podczas użycia istniejącego tokena: $e\n$st',
          );
        }
      }
    }

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        if (kDebugMode) {
          debugPrint('🔁 Próba numer $attempt: Pobieranie tokena...');
        }
        final tokenResponse =
            await OAuth2Service.instance.oauth2Helper.fetchToken();

        if (kDebugMode) {
          debugPrint('📥 Otrzymano odpowiedź z Tokenem: ${tokenResponse.toMap()}');
        }

        if (tokenResponse.accessToken != null) {
          if (kDebugMode) {
            debugPrint('⏬ Pobieranie danych użytkownika...');
          }

          final userResponse = await OAuth2Service.instance.oauth2Helper.get(
            'https://graph.microsoft.com/v1.0/me',
            headers: {'Authorization': 'Bearer ${tokenResponse.accessToken}'},
          );

          if (kDebugMode) {
            debugPrint(
              '📥 Otrzymano odpowiedź od serwera: ${userResponse.statusCode}',
            );
          }

          if (userResponse.statusCode == 200) {
            final json = jsonDecode(userResponse.body);
            setState(() {
              _userName = json['displayName'];
              _userEmail = json['mail'] ?? json['userPrincipalName'];
            });

            final prefs = await SharedPreferences.getInstance();

            await prefs.setString('userName', _userName!);
            await prefs.setString('userEmail', _userEmail!);

            if (kDebugMode) {
              debugPrint(
                '📝 Zapisano dane użytkownika: name=$_userName, email=$_userEmail',
              );
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Zalogowano jako $_userName')),
              );
              Navigator.pop(context, true);
            }
            return;
          } else {
            throw Exception(
              '❌ Nie udało się pobrać informacji o użytkowniku: ${userResponse.body}',
            );
          }
        } else {
          throw Exception('❌ Nie otrzymano tokenu dostępu!');
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('❌ Próba numer $attempt nie powiodła się: $e\n$st');
        }

        if (attempt == 3) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('❌ Błąd logowania po $attempt próbach: $e')),
            );
          }
        }
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Logowanie z Microsoft")),
      body: Center(
        child:
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                  onPressed: _isLoading ? null : _loginWithMicrosoft,
                  child: const Text("Zaloguj się z Microsoft"),
                ),
      ),
    );
  }
}
