import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http_parser/http_parser.dart' as http_parser;

import '/utils/helpers.dart';

/// A typed response wrapper. [statusCode] of -1 means a network/exception failure.
class ApiResult<T> {
  final T? data;
  final int statusCode;
  final String? errorMessage;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  bool get isNetworkError => statusCode == -1;
  bool get isConflict => statusCode == 409;
  bool get isNotFound => statusCode == 404;

  const ApiResult({required this.statusCode, this.data, this.errorMessage});

  @override
  String toString() =>
      'ApiResult(status: $statusCode, ok: $isSuccess, error: $errorMessage)';
}

class ApiService {
  ApiService._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 30),
        validateStatus: (_) => true,
      ),
    );

    // Every request gets the bearer token unless explicitly opted out
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.extra['skipAuth'] != true) {
            options.headers['Authorization'] = 'Bearer $apiToken';
          }
          handler.next(options);
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onError: (e, handler) {
            debugPrint(
              '[API] Wystąpił błąd podczas pobierania danych: ${e.requestOptions.method} ${e.requestOptions.path} → ${e.message}',
            );
            handler.next(e);
          },
        ),
      );
    }
  }

  static final ApiService instance = ApiService._();
  late final Dio _dio;

  // ─── Shared response/error handling ────────────────────────────────────────

  ApiResult<T> _ok<T>(Response res, T Function(dynamic) parse) {
    if (res.statusCode == 200) {
      try {
        return ApiResult(statusCode: 200, data: parse(res.data));
      } catch (e) {
        return ApiResult(
          statusCode: res.statusCode ?? -1,
          errorMessage: 'Błąd przetwarzania odpowiedzi: $e',
        );
      }
    }
    return ApiResult(
      statusCode: res.statusCode ?? -1,
      errorMessage: res.data?.toString(),
    );
  }

  ApiResult<T> _fail<T>(Object e) {
    if (e is DioException) {
      final msg = switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'Przekroczono czas oczekiwania na odpowiedź serwera',
        DioExceptionType.connectionError => 'Błąd połączenia z serwerem',
        DioExceptionType.cancel => 'Żądanie zostało anulowane',
        DioExceptionType.badCertificate => 'Nieprawidłowy certyfikat serwera',
        _ => e.message ?? 'Nieznany błąd sieci',
      };
      return ApiResult(statusCode: -1, errorMessage: msg);
    }
    return ApiResult(statusCode: -1, errorMessage: e.toString());
  }

  Options _form({bool skipAuth = false}) => Options(
    contentType: Headers.formUrlEncodedContentType,
    extra: {'skipAuth': skipAuth},
  );

  // ─── Questions ────────────────────────────────────────────────────────────

  /// Fetches the raw question list for [qualification] (e.g. "inf03").
  Future<ApiResult<List<dynamic>>> fetchQuestions(
    String qualification, {
    int? limit,
  }) async {
    try {
      final res = await _dio.get(
        '/getQuestions.php',
        queryParameters: {'egzamin': qualification, 'limit': ?limit},
      );
      return _ok(res, (d) => d as List<dynamic>);
    } catch (e) {
      return _fail(e);
    }
  }

  Future<ApiResult<List<dynamic>>> fetchQualificationDifficulty(
    String kwal,
  ) async {
    try {
      final res = await _dio.post(
        '/getQualificationDifficulty.php',
        data: {'kwalifikacja': kwal},
      );
      return _ok(res, (d) => d as List<dynamic>);
    } catch (e) {
      return _fail(e);
    }
  }

  /// Fetches difficulty stats for all questions.
  Future<ApiResult<List<dynamic>>> fetchDifficultyStats() async {
    try {
      final res = await _dio.get('/getDifficultyStats.php');
      return _ok(res, (d) => d as List<dynamic>);
    } catch (e) {
      return _fail(e);
    }
  }

  /// Saves or updates a question. Pass [id] when editing an existing question.
  Future<ApiResult<Map<String, dynamic>>> saveQuestion(
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await _dio.post('/add_question.php', data: payload);
      return _ok(res, (d) => d as Map<String, dynamic>);
    } catch (e) {
      return _fail(e);
    }
  }

  /// Deletes a question by [id] in [qualification].
  Future<ApiResult<void>> deleteQuestion(String qualification, int id) async {
    try {
      final res = await _dio.post(
        '/delete_question.php',
        data: {'egzamin': qualification, 'id': id},
      );
      return ApiResult(statusCode: res.statusCode ?? -1);
    } catch (e) {
      return _fail(e);
    }
  }

  /// Resets difficulty stats for a whole [qualification],
  /// or for a single [questionId] if provided.
  Future<ApiResult<void>> resetDifficulty(
    String qualification, {
    int? questionId,
  }) async {
    try {
      final res = await _dio.post(
        '/reset_trudnosc.php',
        data: {'kwalifikacja': qualification, 'pytanie_id': ?questionId},
        options: _form(),
      );
      return ApiResult(statusCode: res.statusCode ?? -1);
    } catch (e) {
      return _fail(e);
    }
  }

  /// Records whether a question was answered correctly (used in single-question mode).
  Future<ApiResult<void>> recordDifficulty(
    int questionId,
    String qualification,
    bool correct,
  ) async {
    try {
      final res = await _dio.post(
        '/zapis_trudnosci.php',
        data: {
          'pytanie_id': questionId,
          'kwalifikacja': qualification.replaceAll(' ', ''),
          'poprawna': correct ? '1' : '0',
        },
        options: _form(),
      );
      return ApiResult(statusCode: res.statusCode ?? -1);
    } catch (e) {
      return _fail(e);
    }
  }

  // ─── Media Uploads ────────────────────────────────────────────────────────

  Future<ApiResult<Map<String, String>>> _upload(
    String path,
    Uint8List bytes,
    String filename,
    http_parser.MediaType contentType,
    String qualification,
  ) async {
    try {
      final formData = FormData.fromMap({
        'kwalifikacja': qualification,
        'egzamin': qualification,
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: contentType,
        ),
      });

      final res = await _dio.post(path, data: formData);

      if (res.statusCode != 200) {
        return ApiResult(
          statusCode: res.statusCode ?? -1,
          errorMessage: res.data?.toString(),
        );
      }
      final data = res.data as Map<String, dynamic>;
      if (data['ok'] != true || data['url'] == null) {
        return ApiResult(
          statusCode: res.statusCode ?? -1,
          errorMessage: data['error']?.toString() ?? 'Upload failed',
        );
      }
      return ApiResult(
        statusCode: res.statusCode ?? -1,
        data: {
          'url': data['url'] as String,
          'filename': (data['filename'] as String?) ?? filename,
        },
      );
    } catch (e) {
      return _fail(e);
    }
  }

  /// Uploads an image for a question or answer.
  /// Returns the uploaded [url] and [filename] on success.
  Future<ApiResult<Map<String, String>>> uploadImage(
    String qualification,
    Uint8List bytes,
    String filename,
  ) {
    final ext = filename.split('.').last.toLowerCase();
    return _upload(
      '/upload_image_next.php',
      bytes,
      filename,
      http_parser.MediaType('image', ext == 'jpg' ? 'jpeg' : ext),
      qualification,
    );
  }

  /// Uploads a video for a question.
  Future<ApiResult<Map<String, String>>> uploadVideo(
    String qualification,
    Uint8List bytes,
    String filename,
  ) {
    final ext = filename.split('.').last.toLowerCase();
    final mt = switch (ext) {
      'webm' => http_parser.MediaType('video', 'webm'),
      'ogg' => http_parser.MediaType('video', 'ogg'),
      _ => http_parser.MediaType('video', 'mp4'),
    };
    return _upload('/upload_video.php', bytes, filename, mt, qualification);
  }

  /// Downloads raw image bytes from [url] — used when building PDFs.
  Future<ApiResult<Uint8List>> downloadImage(String url) async {
    try {
      final res = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          extra: {'skipAuth': true},
        ),
      );
      if (res.statusCode == 200 && res.data != null) {
        return ApiResult(
          statusCode: res.statusCode!,
          data: Uint8List.fromList(res.data!),
        );
      }
      return ApiResult(statusCode: res.statusCode ?? -1);
    } catch (e) {
      return _fail(e);
    }
  }

  // ─── Exams ────────────────────────────────────────────────────────────────

  /// Saves a standard 40-question exam result with full payload.
  Future<ApiResult<void>> saveExam(Map<String, dynamic> payload) async {
    try {
      final res = await _dio.post('/save_exam.php', data: payload);
      return ApiResult(statusCode: res.statusCode ?? -1);
    } catch (e) {
      return _fail(e);
    }
  }

  /// Saves a result for a published teacher test.
  Future<ApiResult<void>> savePublishedTestResult(
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await _dio.post('/savePublishedResult.php', data: payload);
      return ApiResult(statusCode: res.statusCode ?? -1);
    } catch (e) {
      return _fail(e);
    }
  }

  // ─── Published Tests ──────────────────────────────────────────────────────

  Future<ApiResult<List<Map<String, dynamic>>>>
  fetchAdminTestsMetadata() async {
    try {
      final res = await _dio.get('/publishedTests_adminMetadata.php');
      return _ok(res, (d) => (d as List).cast<Map<String, dynamic>>());
    } catch (e) {
      return _fail(e);
    }
  }

  Future<ApiResult<List<Map<String, dynamic>>>> fetchUserTestsMetadata(
    String qualification,
  ) async {
    try {
      final res = await _dio.get(
        '/publishedTests_userMetadata.php',
        queryParameters: {'qualification': qualification},
      );
      return _ok(res, (d) => (d as List).cast<Map<String, dynamic>>());
    } catch (e) {
      return _fail(e);
    }
  }

  Future<ApiResult<Map<String, dynamic>>> fetchAdminTestQuestions(
    int id,
  ) async {
    try {
      final res = await _dio.get(
        '/publishedTests_adminQuestions.php',
        queryParameters: {'id': id},
      );
      return _ok(res, (d) => d as Map<String, dynamic>);
    } catch (e) {
      return _fail(e);
    }
  }

  Future<ApiResult<Map<String, dynamic>>> fetchUserTestQuestions(int id) async {
    try {
      final res = await _dio.get(
        '/publishedTests_userQuestions.php',
        queryParameters: {'id': id},
      );
      return _ok(res, (d) => d as Map<String, dynamic>);
    } catch (e) {
      return _fail(e);
    }
  }

  /// Creates a new test on the server. Returns 409 on name conflict.
  Future<ApiResult<Map<String, dynamic>>> createTest(
    Map<String, dynamic> test,
  ) async {
    try {
      final res = await _dio.post(
        '/publishedTests_adminManage.php',
        data: {'action': 'create', 'test': test},
      );
      return _ok(res, (d) => d as Map<String, dynamic>);
    } catch (e) {
      return _fail(e);
    }
  }

  Future<ApiResult<void>> setTestPublished(int id, bool publish) async {
    try {
      final res = await _dio.post(
        '/publishedTests_adminManage.php',
        data: {
          'action': publish ? 'publish' : 'unpublish',
          'test': {'id': id},
        },
      );
      return ApiResult(statusCode: res.statusCode ?? -1);
    } catch (e) {
      return _fail(e);
    }
  }

  Future<ApiResult<void>> deleteTest(int id) async {
    try {
      final res = await _dio.post(
        '/publishedTests_adminManage.php',
        data: {
          'action': 'delete',
          'test': {'id': id},
        },
      );
      return ApiResult(statusCode: res.statusCode ?? -1);
    } catch (e) {
      return _fail(e);
    }
  }

  Future<ApiResult<List<dynamic>>> fetchTestResults(String testKey) async {
    try {
      final res = await _dio.post(
        '/getPublishedResults.php',
        data: {'test_key': testKey},
      );
      return _ok(res, (d) => d as List<dynamic>);
    } catch (e) {
      return _fail(e);
    }
  }

  Future<ApiResult<List<dynamic>>> fetchQualifications() async {
    try {
      final res = await _dio.post('/egzaminy_wyniki_post.php', data: {});
      return _ok(res, (d) => d as List<dynamic>);
    } catch (e) {
      return _fail(e);
    }
  }

  // ─── Statistics ───────────────────────────────────────────────────────────

  static final Map<String, _CountCacheEntry> _countCache = {};

  Future<ApiResult<int>> fetchQuestionCount(String cacheKey) async {
    final cached = _countCache[cacheKey];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return ApiResult(statusCode: 200, data: cached.count);
    }

    try {
      final res = await _dio.get(
        '/count/countQuestions.php',
        queryParameters: {'egzamin': cacheKey},
        options: Options(sendTimeout: const Duration(seconds: 10)),
      );
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        final count = data['count'];
        final parsed = count is int ? count : int.tryParse('$count');
        if (parsed != null) {
          _countCache[cacheKey] = _CountCacheEntry(
            count: parsed,
            expiresAt: DateTime.now().add(const Duration(minutes: 15)),
          );
          return ApiResult(statusCode: 200, data: parsed);
        }
      }
      return ApiResult(statusCode: res.statusCode ?? -1);
    } catch (e) {
      return _fail(e);
    }
  }

  Future<ApiResult<Map<String, dynamic>>> fetchUserStats() async {
    try {
      final res = await _dio.post('/stats.php', options: _form());
      return _ok(res, (d) => d as Map<String, dynamic>);
    } catch (e) {
      return _fail(e);
    }
  }

  Future<ApiResult<List<dynamic>>> fetchAllStats() async {
    try {
      final res = await _dio.post('/stats_all.php', options: _form());
      return _ok(res, (d) => d as List<dynamic>);
    } catch (e) {
      return _fail(e);
    }
  }

  Future<ApiResult<Map<String, dynamic>>> fetchExamPreviewAdmin({
    required int examId,
    required String userName,
    required String examDateTime,
    required int durationSec,
  }) async {
    try {
      final res = await _dio.post(
        '/podgladEgzaminu.php',
        data: {
          'exam_id': examId,
          'userName': userName,
          'exam_date': examDateTime,
          'duration_sec': durationSec,
        },
        options: _form(),
      );
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        if (data['success'] == true) {
          return ApiResult(statusCode: res.statusCode!, data: data);
        }
      }
      return ApiResult(
        statusCode: res.statusCode ?? -1,
        errorMessage: res.data?.toString(),
      );
    } catch (e) {
      return _fail(e);
    }
  }

  Future<ApiResult<Map<String, dynamic>>> fetchExamPreviewUser({
    required int examId,
    required String examDateTime,
    required int durationSec,
  }) async {
    try {
      final res = await _dio.post(
        '/podgladEgzaminu_user.php',
        data: {
          'exam_id': examId,
          'exam_date': examDateTime,
          'duration_sec': durationSec,
        },
        options: _form(),
      );
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        if (data['success'] == true) {
          return ApiResult(statusCode: res.statusCode!, data: data);
        }
      }
      return ApiResult(
        statusCode: res.statusCode ?? -1,
        errorMessage: res.data?.toString(),
      );
    } catch (e) {
      return _fail(e);
    }
  }

  Future<ApiResult<Map<String, dynamic>>> fetchExamPreviewForTest(
    int examId,
  ) async {
    try {
      final res = await _dio.post(
        '/podgladEgzaminuDlaTestow.php',
        data: {'exam_id': examId},
        options: _form(),
      );
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        if (data['success'] == true) {
          return ApiResult(statusCode: res.statusCode!, data: data);
        }
      }
      return ApiResult(
        statusCode: res.statusCode ?? -1,
        errorMessage: res.data?.toString(),
      );
    } catch (e) {
      return _fail(e);
    }
  }

  // ─── Admin Management ─────────────────────────────────────────────────────

  Future<ApiResult<List<dynamic>>> fetchAdmins() async {
    try {
      final res = await _dio.post('/showAdmins.php', options: _form());
      return _ok(res, (d) => d as List<dynamic>);
    } catch (e) {
      return _fail(e);
    }
  }

  Future<ApiResult<Map<String, dynamic>>> addAdmin(String email) async {
    try {
      final res = await _dio.post(
        '/add_admin.php',
        data: {'email': email},
        options: _form(),
      );
      return _ok(res, (d) => d as Map<String, dynamic>);
    } catch (e) {
      return _fail(e);
    }
  }

  Future<ApiResult<Map<String, dynamic>>> promoteToSuperAdmin(int id) async {
    try {
      final res = await _dio.post(
        '/promote_super_admin.php',
        data: {'id': id},
        options: _form(),
      );
      return _ok(res, (d) => d as Map<String, dynamic>);
    } catch (e) {
      return _fail(e);
    }
  }

  Future<ApiResult<Map<String, dynamic>>> demoteSuperAdmin(int id) async {
    try {
      final res = await _dio.post(
        '/demote_super_admin.php',
        data: {'id': id},
        options: _form(),
      );
      return _ok(res, (d) => d as Map<String, dynamic>);
    } catch (e) {
      return _fail(e);
    }
  }

  Future<ApiResult<Map<String, dynamic>>> deleteAdmin(int id) async {
    try {
      final res = await _dio.post(
        '/delete_admin.php',
        data: {'id': id},
        options: _form(),
      );
      return _ok(res, (d) => d as Map<String, dynamic>);
    } catch (e) {
      return _fail(e);
    }
  }

  Future<ApiResult<Map<String, dynamic>>> checkSession() async {
    try {
      final res = await _dio.post('/session-status.php', data: {});
      return _ok(res, (d) => d as Map<String, dynamic>);
    } catch (e) {
      return _fail(e);
    }
  }

  /// Logs the user out on the server.
  Future<ApiResult<void>> logout() async {
    try {
      final res = await _dio.post('/logout.php', data: {});
      return ApiResult(statusCode: res.statusCode ?? -1);
    } catch (e) {
      return _fail(e);
    }
  }

  /// Handles the oauth2 token request — talks to Microsoft
  Future<ApiResult<Map<String, dynamic>>> exchangeOAuthCode({
    required String clientId,
    required String tokenUrl,
    required String code,
    required String redirectUri,
    required String codeVerifier,
  }) async {
    try {
      final res = await _dio.post(
        tokenUrl,
        data: {
          'client_id': clientId,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
          'code_verifier': codeVerifier,
        },
        options: _form(skipAuth: true),
      );
      return _ok(res, (d) => d as Map<String, dynamic>);
    } catch (e) {
      return _fail(e);
    }
  }

  /// Handles the oauth2 login mechanism authenticated via the id_token payload
  Future<ApiResult<Map<String, dynamic>>> logIntoMicrosoft(
    String idToken,
  ) async {
    try {
      final res = await _dio.post(
        '/ms-login.php',
        data: {'id_token': idToken},
        options: _form(skipAuth: true),
      );
      return _ok(res, (d) => d as Map<String, dynamic>);
    } catch (e) {
      return _fail(e);
    }
  }
}

class _CountCacheEntry {
  final int count;
  final DateTime expiresAt;
  _CountCacheEntry({required this.count, required this.expiresAt});
}
