// lib/ouath2_service.dart
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OAuth2Service {
  static const String clientId = '67af475e-082d-4187-b1ef-5fa26fa0fe77';
  static const String tenantId = 'de78aefd-fda9-4eaf-a2d1-cf8492188649';
  static const String redirectUri = 'https://interpage.pl/egzaminyzsel/redirect.html'; 
  static const String tokenUrl =
      'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token';
  static const String authorizeUrl =
      'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize';
  static const List<String> scopes = [
    'openid',
    'profile',
    'email',
    'User.Read',
    'offline_access'
  ];

  static String? _codeVerifier;
  static String? _state;

  // Generuj code_verifier (PKCE)
  static String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(128, (_) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '').substring(0, 128);
  }

  // Generuj code_challenge (S256)
  static String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  // Start login – DODAJ PKCE DO URL
  static void startLogin() {
    _codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(_codeVerifier!);
    _state = DateTime.now().millisecondsSinceEpoch.toRadixString(36);

    html.window.localStorage['code_verifier'] = _codeVerifier!;
    html.window.localStorage['oauth_state'] = _state!;

    final authUrl = Uri.parse(authorizeUrl).replace(queryParameters: {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'scope': scopes.join(' '),
      'state': _state!,
      'response_mode': 'query',
      'code_challenge': codeChallenge, // DODAJ TO!
      'code_challenge_method': 'S256', // DODAJ TO!
    });

    html.window.location.href = authUrl.toString();
  }

  // Handle redirect – UŻYJ code_verifier DO TOKENA
  static Future<bool> handleRedirect() async {
    final uri = Uri.parse(html.window.location.href);
    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    final storedState = html.window.localStorage['oauth_state'];
    final codeVerifier = html.window.localStorage['code_verifier'];

    if (code == null || state != storedState || codeVerifier == null) {
      return false;
    }

    html.window.localStorage.remove('oauth_state');
    html.window.localStorage.remove('code_verifier');

    try {
      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientId,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
          'code_verifier': codeVerifier, // DODAJ TO – KLUCZOWE!
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final idToken = json['id_token'] as String?;
        await _saveUserFromIdToken(idToken);
        return true;
      } else {
        if (kDebugMode) print('Token error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) print('Błąd tokena: $e');
    }
    return false;
  }

  // _saveUserFromIdToken – BEZ ZMIAN
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