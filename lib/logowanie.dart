import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:oauth2_client/oauth2_client.dart';
import 'package:oauth2_client/oauth2_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

class LogowaniePage extends StatefulWidget {
  const LogowaniePage({super.key});

  @override
  State<LogowaniePage> createState() => _LogowaniePageState();
}

class _LogowaniePageState extends State<LogowaniePage> {
  String? _userName;
  String? _userEmail;
  bool _isLoading = false;
  late OAuth2Helper _oauth2Helper;

final String _clientId = '67af475e-082d-4187-b1ef-5fa26fa0fe77';
final String _authorizeUrl = 'https://login.microsoftonline.com/de78aefd-fda9-4eaf-a2d1-cf8492188649/oauth2/v2.0/authorize';
final String _tokenUrl = 'https://login.microsoftonline.com/de78aefd-fda9-4eaf-a2d1-cf8492188649/oauth2/v2.0/token';
  final List<String> _scopes = [
    'openid',
    'profile',
    'email',
    'User.Read',
    'offline_access',
  ];

String get _redirectUri {
  if (kIsWeb) {
    return 'https://interpage.pl/egzaminyzsel/redirect.html';
  } else if (Platform.isAndroid || Platform.isIOS) {
    return 'com.example.myapp://oauthredirect';
  }
  return 'https://interpage.pl/egzaminyzsel/redirect.html'; 
}

String get _customScheme {
  if (kIsWeb) {
    return ''; 
  }
  return 'com.example.myapp';
}

  @override
  void initState() {
    super.initState();

    final client = OAuth2Client(
      authorizeUrl:
          _authorizeUrl,
      tokenUrl:
          _tokenUrl,
      redirectUri: _redirectUri,
      customUriScheme: _customScheme,
    );

    _oauth2Helper = OAuth2Helper(
      client,
      grantType: OAuth2Helper.authorizationCode,
      clientId: _clientId,
      scopes: _scopes,
      enablePKCE: true,
      authCodeParams: {'response_mode': 'query'},
    );
  }

  Future<void> _loginWithMicrosoft() async {
    setState(() => _isLoading = true);
        debugPrint('Redirect URI being sent: $_redirectUri');
    try {
      debugPrint('Logging in using redirect: $_redirectUri');
      final tokenResponse = await _oauth2Helper.fetchToken();
      debugPrint('Got token response: $tokenResponse');
      if (tokenResponse.accessToken != null) {
        debugPrint('Access token: ${tokenResponse.accessToken}');

        // Fetch user info
        final userResponse = await _oauth2Helper.get(
          'https://graph.microsoft.com/v1.0/me',
          headers: {'Authorization': 'Bearer ${tokenResponse.accessToken}'},
        );

        if (userResponse.statusCode == 200) {
          final json = jsonDecode(userResponse.body);

          setState(() {
            _userName = json['displayName'];
            _userEmail = json['mail'] ?? json['userPrincipalName'];
          });

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userName', _userName!);
          await prefs.setString('userEmail', _userEmail!);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Zalogowano jako $_userName')),
          );

          // Navigate back to MyHomePage
          Navigator.pop(context, true);
        } else {
          throw Exception('Nie udało się pobrać informacji o użytkowniku');
        }
      } else {
        throw Exception('Nie otrzymano tokenu dostępu');
      }
    } catch (e, st) {
      debugPrint('Login error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd logowania: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Microsoft Login")),
      body: Center(
        child:
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                  onPressed: _loginWithMicrosoft,
                  child: const Text("Zaloguj się z Microsoft"),
                ),
      ),
    );
  }
}
