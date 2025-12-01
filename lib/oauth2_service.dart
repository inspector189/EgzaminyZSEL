import 'dart:convert';
import 'package:web/web.dart' as web;
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OAuth2Service {
  static const String clientId = '67af475e-082d-4187-b1ef-5fa26fa0fe77';
  static const String tenantId = 'de78aefd-fda9-4eaf-a2d1-cf8492188649';
  static const String redirectUri =
      'https://egzaminy.zsel.edu.pl/redirect.html';
  static const String tokenUrl =
      'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token';
  static const String authorizeUrl =
      'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize';
  static const List<String> scopes = [
    'openid',
    'profile',
    'email',
    'User.Read',
    'offline_access',
  ];

  static String? _codeVerifier;
  static String? _state;

  static String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(128, (_) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '').substring(0, 128);
  }

  static String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  static void startLogin() {
    _codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(_codeVerifier!);
    _state = DateTime.now().millisecondsSinceEpoch.toRadixString(36);

    web.window.localStorage.setItem('code_verifier', _codeVerifier!);
    web.window.localStorage.setItem('oauth_state', _state!);

    final authUrl = Uri.parse(authorizeUrl).replace(
      queryParameters: {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'scope': scopes.join(' '),
        'state': _state!,
        'response_mode': 'query',
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      },
    );

    web.window.location.href = authUrl.toString();
  }

  static Future<bool> handleRedirect() async {
  final uri = Uri.parse(web.window.location.href);
  final code = uri.queryParameters['code'];
  final state = uri.queryParameters['state'];
  final storedState = web.window.localStorage.getItem('oauth_state');
  final codeVerifier = web.window.localStorage.getItem('code_verifier');

  if (code == null || state != storedState || codeVerifier == null) {
    return false;
  }

  web.window.localStorage.removeItem('oauth_state');
  web.window.localStorage.removeItem('code_verifier');

  try {
    final response = await http.post(
      Uri.parse(tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': clientId,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'code_verifier': codeVerifier,
      },
    );

    if (response.statusCode == 200) {
      final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
      final idToken = jsonMap['id_token'] as String?;

      // zapis nazwy + maila (tak jak miałeś)
      await _saveUserFromIdToken(idToken);

      bool isAdmin = false;

      if (idToken != null) {
        // ---- wywołanie ms-login.php ----
        final msRes = await http.post(
          Uri.parse('https://egzaminy.zsel.edu.pl/egzaminy/ms-login.php'),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'id_token': idToken,
          },
        );

        if (msRes.statusCode == 200) {
          final msJson =
              jsonDecode(msRes.body) as Map<String, dynamic>;
          isAdmin = msJson['isAdmin'] == true;
        } else {
          if (kDebugMode) {
            print(
              'ms-login error: ${msRes.statusCode} ${msRes.body}',
            );
          }
        }
      }

      // zapisujemy info o adminie w SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAdmin', isAdmin);

      return true;
    } else {
      if (kDebugMode) {
        print('Token error: ${response.statusCode} - ${response.body}');
      }
    }
  } catch (e) {
    if (kDebugMode) print('Błąd tokena: $e');
  }
  return false;
}


  static Future<void> _saveUserFromIdToken(String? idToken) async {
    if (idToken == null) return;

    final parts = idToken.split('.');
    if (parts.length != 3) return;

    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final jsonStr = utf8.decode(base64Url.decode(normalized));
    final json = jsonDecode(jsonStr);

    final name = json['name'] as String?;
    final email = json['email'] ?? json['preferred_username'] as String?;

    if (name != null && email != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', name);
      await prefs.setString('userEmail', email);
    }
  }
}
