import 'dart:convert';
import 'dart:math' show Random;

import 'package:web/web.dart' as web;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/services/api_service.dart';
import '/utils/helpers.dart';

class OAuth2Service {
  static const List<String> _scopes = [
    'openid',
    'profile',
    'email',
    'User.Read',
    'offline_access',
  ];

  static const String _microsoftUrl = "https://login.microsoftonline.com/";
  static const String _tokenUrl = '$_microsoftUrl/$tenantId/oauth2/v2.0/token';
  static const String _authorizeUrl =
      '$_microsoftUrl/$tenantId/oauth2/v2.0/authorize';

  static const String _redirectUri = '${baseUrl}redirect.html';

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

    final authUrl = Uri.parse(_authorizeUrl).replace(
      queryParameters: {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': _redirectUri,
        'scope': _scopes.join(' '),
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
      final result = await ApiService.instance.exchangeOAuthCode(
        clientId: clientId,
        tokenUrl: _tokenUrl,
        code: code,
        redirectUri: _redirectUri,
        codeVerifier: codeVerifier,
      );

      if (!result.isSuccess) {
        if (kDebugMode) {
          debugPrint(
            'Wystąpił błąd podczas pobierania token\'a: ${result.statusCode} - ${result.errorMessage}',
          );
        }
        return false;
      }

      final tokenData = result.data!;
      final idToken = tokenData['id_token'] as String?;

      await _saveUserFromIdToken(idToken);

      bool isAdmin = false;

      if (idToken != null) {
        final loginResult = await ApiService.instance.logIntoMicrosoft(idToken);

        if (loginResult.isSuccess) {
          final loginData = loginResult.data!;
          isAdmin = loginData['isAdmin'] == true;
        } else {
          if (kDebugMode) {
            debugPrint(
              'Wystąpił błąd podczas logowania: ${loginResult.statusCode} ${loginResult.errorMessage}',
            );
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAdmin', isAdmin);

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Wystąpił wewnętrzny błąd: $e');
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
        debugPrint('Wystąpił błąd podczas przetwarzania ID: $e');
      }
    }
  }
}
