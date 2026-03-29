import 'dart:convert';
import 'package:web/web.dart' as web;
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/helpers.dart';

class OAuth2Service {

  static String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(64, (_) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  static String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  static void startLogin() {
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);
    final stateBytes = List<int>.generate(
      32,
      (_) => Random.secure().nextInt(256),
    );
    final state = base64UrlEncode(stateBytes).replaceAll('=', '');

    web.window.localStorage.setItem('code_verifier', codeVerifier);
    web.window.localStorage.setItem('oauth_state', state);

    final authUrl = Uri.parse(authorizeUrl).replace(
      queryParameters: {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'scope': scopes.join(' '),
        'state': state,
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

        await _saveUserFromIdToken(idToken);

        bool isAdmin = false;

        if (idToken != null) {
          final msRes = await http.post(
            Uri.parse('$apiBaseUrl/ms-login.php'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'id_token': idToken},
          );

          if (msRes.statusCode == 200) {
            final msJson = jsonDecode(msRes.body) as Map<String, dynamic>;
            isAdmin = msJson['isAdmin'] == true;
          } else {
            if (kDebugMode) {
              print('ms-login error: ${msRes.statusCode} ${msRes.body}');
            }
          }
        }

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

    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final jsonStr = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(jsonStr);

      final name = json['name'] as String?;
      final email = (json['email'] ?? json['preferred_username']) as String?;

      if (name != null && email != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userName', name);
        await prefs.setString('userEmail', email);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to parse id_token: $e');
      }
    }
  }
}
