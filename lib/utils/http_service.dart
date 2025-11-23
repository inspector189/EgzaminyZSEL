import 'dart:convert' show jsonEncode, jsonDecode;

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http show Client, Response, get;

class HttpService {
  HttpService._();
  static final http.Client _client = http.Client();
  static const Duration _defaultTimeout = Duration(seconds: 10);

  static Future<http.Response?> postJson(
    Uri url,
    Object body, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _client
          .post(
            url,
            headers: headers ?? {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_defaultTimeout);
      return response;
    } catch (e) {
      if (kDebugMode) debugPrint('Json error: $e');
      return null;
    }
  }

  static Future<http.Response?> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _client
          .get(url, headers: headers)
          .timeout(_defaultTimeout);
      return response;
    } catch (e) {
      if (kDebugMode) debugPrint('Get error: $e');
      return null;
    }
  }
}

class QuestionCountCache {
  QuestionCountCache._();
  static final QuestionCountCache instance = QuestionCountCache._();

  final Map<String, Future<int?>> _cache = {};

  Future<int?> getCount(String code) {
    return _cache.putIfAbsent(
      code,
      () => Future.microtask(() => _fetchQuestionCount(code)),
    );
  }

  Future<int?> _fetchQuestionCount(String kwalifikacja) async {
    try {
      final sanitized = kwalifikacja.replaceAll('.', '').toLowerCase();
      final url = Uri.parse(
        'https://egzaminy.zsel.edu.pl/egzaminy/count/countQuestions.php?egzamin=$sanitized',
      );
      debugPrint('Requesting: $url');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is Map && data.containsKey('count')) {
          return data['count'] as int;
        } else {
          debugPrint('⚠️ Nieprawidłowy format: $data');
        }
      } else {
        debugPrint('❌ Serwer zwrócił kod błędu ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Błąd podczas zbierania danych: $e');
    }

    return null;
  }
}
