import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import '../utils/helpers.dart';

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
  ApiService._();
  static final ApiService instance = ApiService._();

  // ─── Headers ──────────────────────────────────────────────────────────────

  Map<String, String> get _authHeaders => {'Authorization': 'Bearer $apiToken'};

  Map<String, String> get _authJsonHeaders => {
    'Authorization': 'Bearer $apiToken',
    'Content-Type': 'application/json',
  };

  Map<String, String> get _apiKeyFormHeaders => {
    'Content-Type': 'application/x-www-form-urlencoded',
    'Authorization': 'Bearer $apiKey',
  };

  Map<String, String> get _apiKeyJsonHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $apiKey',
  };

  // ─── Questions ────────────────────────────────────────────────────────────

  /// Fetches the raw question list for [qualification] (e.g. "inf03").
  Future<ApiResult<List<dynamic>>> fetchQuestions(String qualification) async {
    try {
      final res = await http.get(Uri.parse('$apiBaseUrl/$qualification.php'));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        return ApiResult(
          statusCode: res.statusCode,
          data: json.decode(res.body) as List<dynamic>,
        );
      }
      return ApiResult(statusCode: res.statusCode);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Fetches difficulty stats for all questions.
  Future<ApiResult<List<dynamic>>> fetchDifficultyStats() async {
    try {
      final res = await http.get(
        Uri.parse('$apiBaseUrl/wyswietl_trudnosci.php'),
        headers: _apiKeyJsonHeaders,
      );
      if (res.statusCode == 200) {
        return ApiResult(
          statusCode: res.statusCode,
          data: json.decode(res.body) as List<dynamic>,
        );
      }
      return ApiResult(statusCode: res.statusCode);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Saves or updates a question. Pass [id] when editing an existing question.
  Future<ApiResult<Map<String, dynamic>>> saveQuestion(
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/add_question.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $apiKey',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );
      if (res.statusCode == 200) {
        return ApiResult(
          statusCode: res.statusCode,
          data: json.decode(res.body) as Map<String, dynamic>,
        );
      }
      return ApiResult(statusCode: res.statusCode, errorMessage: res.body);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Deletes a question by [id] in [qualification].
  Future<ApiResult<void>> deleteQuestion(String qualification, int id) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/delete_question.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'X-API-Key': apiKey,
        },
        body: jsonEncode({'egzamin': qualification, 'id': id}),
      );
      return ApiResult(statusCode: res.statusCode);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Resets difficulty stats for a whole [qualification],
  /// or for a single [questionId] if provided.
  Future<ApiResult<void>> resetDifficulty(
    String qualification, {
    int? questionId,
  }) async {
    try {
      final body = <String, String>{'kwalifikacja': qualification};
      if (questionId != null) body['pytanie_id'] = '$questionId';

      final res = await http.post(
        Uri.parse('$apiBaseUrl/reset_trudnosc.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
          'Authorization': 'Bearer $apiKey',
        },
        body: body,
      );
      return ApiResult(statusCode: res.statusCode);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Records whether a question was answered correctly (used in single-question mode).
  Future<ApiResult<void>> recordDifficulty(
    int questionId,
    String qualification,
    bool correct,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/zapis_trudnosci.php'),
        headers: _apiKeyFormHeaders,
        body: {
          'pytanie_id': questionId.toString(),
          'kwalifikacja': qualification.replaceAll(' ', ''),
          'poprawna': correct ? '1' : '0',
        },
      );
      return ApiResult(statusCode: res.statusCode);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  // ─── Media Uploads ────────────────────────────────────────────────────────

  /// Uploads an image for a question or answer.
  /// Returns the uploaded [url] and [filename] on success.
  Future<ApiResult<Map<String, String>>> uploadImage(
    String qualification,
    Uint8List bytes,
    String filename,
  ) async {
    try {
      final ext = filename.split('.').last.toLowerCase();
      final req =
          http.MultipartRequest(
              'POST',
              Uri.parse('$apiBaseUrl/upload_image_next.php'),
            )
            ..headers['Authorization'] = 'Bearer $apiKey'
            ..headers['X-API-Key'] = apiKey
            ..headers['Accept'] = 'application/json'
            ..fields['kwalifikacja'] = qualification
            ..fields['egzamin'] = qualification
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                bytes,
                filename: filename,
                contentType: http_parser.MediaType(
                  'image',
                  ext == 'jpg' ? 'jpeg' : ext,
                ),
              ),
            );

      final res = await http.Response.fromStream(await req.send());
      if (res.statusCode != 200) {
        return ApiResult(statusCode: res.statusCode, errorMessage: res.body);
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['ok'] != true || data['url'] == null) {
        return ApiResult(
          statusCode: res.statusCode,
          errorMessage: data['error']?.toString() ?? 'Upload failed',
        );
      }
      return ApiResult(
        statusCode: res.statusCode,
        data: {
          'url': data['url'] as String,
          'filename': (data['filename'] as String?) ?? filename,
        },
      );
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Uploads a video for a question.
  Future<ApiResult<Map<String, String>>> uploadVideo(
    String qualification,
    Uint8List bytes,
    String filename,
  ) async {
    try {
      final ext = filename.split('.').last.toLowerCase();
      final mt = switch (ext) {
        'webm' => http_parser.MediaType('video', 'webm'),
        'ogg' => http_parser.MediaType('video', 'ogg'),
        _ => http_parser.MediaType('video', 'mp4'),
      };
      final req =
          http.MultipartRequest(
              'POST',
              Uri.parse('$apiBaseUrl/upload_video.php'),
            )
            ..headers['Authorization'] = 'Bearer $apiKey'
            ..headers['X-API-Key'] = apiKey
            ..headers['Accept'] = 'application/json'
            ..fields['kwalifikacja'] = qualification
            ..fields['egzamin'] = qualification
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                bytes,
                filename: filename,
                contentType: mt,
              ),
            );

      final res = await http.Response.fromStream(await req.send());
      if (res.statusCode != 200) {
        return ApiResult(statusCode: res.statusCode, errorMessage: res.body);
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['ok'] != true || data['url'] == null) {
        return ApiResult(
          statusCode: res.statusCode,
          errorMessage: data['error']?.toString() ?? 'Upload failed',
        );
      }
      return ApiResult(
        statusCode: res.statusCode,
        data: {
          'url': data['url'] as String,
          'filename': (data['filename'] as String?) ?? filename,
        },
      );
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Downloads raw image bytes from [url] — used when building PDFs.
  Future<ApiResult<Uint8List>> downloadImage(String url) async {
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        return ApiResult(statusCode: res.statusCode, data: res.bodyBytes);
      }
      return ApiResult(statusCode: res.statusCode);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  // ─── Exams ────────────────────────────────────────────────────────────────

  /// Saves a standard 40-question exam result with full payload.
  Future<ApiResult<void>> saveExam(Map<String, dynamic> payload) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/save_exam.php'),
        headers: _apiKeyJsonHeaders,
        body: jsonEncode(payload),
      );
      return ApiResult(statusCode: res.statusCode);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Saves a result for a published teacher test.
  Future<ApiResult<void>> savePublishedTestResult(
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/savePublishedResult.php'),
        headers: _apiKeyJsonHeaders,
        body: jsonEncode(payload),
      );
      return ApiResult(statusCode: res.statusCode);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Saves a quick exam score (used in single/40-question modes via zapisz_wynik.php).
  Future<ApiResult<void>> saveExamScore({
    required String qualification,
    required double score,
    required String dateTime,
    required int durationSeconds,
    required String userName,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/zapisz_wynik.php'),
        headers: _apiKeyFormHeaders,
        body: {
          'kwalifikacja': qualification.replaceAll(' ', ''),
          'wynik': score.toStringAsFixed(2),
          'data_czas': dateTime,
          'czas_trwania': durationSeconds.toString(),
          'userName': userName,
        },
      );
      return ApiResult(statusCode: res.statusCode);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  // ─── Published Tests ──────────────────────────────────────────────────────

  /// Fetches all published tests (student-facing, no auth needed).
  Future<ApiResult<List<Map<String, dynamic>>>> fetchPublishedTests() async {
    try {
      final res = await http.get(
        Uri.parse(publishedTestsUrl),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        return ApiResult(
          statusCode: res.statusCode,
          data: (json.decode(res.body) as List).cast<Map<String, dynamic>>(),
        );
      }
      return ApiResult(statusCode: res.statusCode);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Fetches all tests (teacher-facing, includes unpublished).
  Future<ApiResult<List<Map<String, dynamic>>>> fetchAllTests() async {
    try {
      final res = await http.get(Uri.parse(allTestsUrl), headers: _authHeaders);
      if (res.statusCode == 200) {
        return ApiResult(
          statusCode: res.statusCode,
          data: (json.decode(res.body) as List).cast<Map<String, dynamic>>(),
        );
      }
      return ApiResult(statusCode: res.statusCode);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Creates a new test on the server. Returns 409 on name conflict.
  Future<ApiResult<void>> createTest(Map<String, dynamic> test) async {
    try {
      final res = await http.post(
        Uri.parse(publishedTestsUrl),
        headers: _authJsonHeaders,
        body: json.encode({'action': 'create', 'test': test}),
      );
      return ApiResult(
        statusCode: res.statusCode,
        errorMessage: res.statusCode != 200 ? res.body : null,
      );
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Publishes or unpublishes a test.
  Future<ApiResult<void>> setTestPublished(
    Map<String, dynamic> test,
    bool publish,
  ) async {
    try {
      final res = await http.post(
        Uri.parse(publishedTestsUrl),
        headers: _authJsonHeaders,
        body: json.encode({
          'action': publish ? 'publish' : 'unpublish',
          'test': test,
        }),
      );
      return ApiResult(statusCode: res.statusCode);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Deletes a test from the server.
  Future<ApiResult<void>> deleteTest(Map<String, dynamic> test) async {
    try {
      final res = await http.post(
        Uri.parse(publishedTestsUrl),
        headers: _authJsonHeaders,
        body: json.encode({'action': 'delete', 'test': test}),
      );
      return ApiResult(statusCode: res.statusCode);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Fetches all submitted results for a specific test by [testKey].
  Future<ApiResult<List<dynamic>>> fetchTestResults(String testKey) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/getPublishedResults.php'),
        headers: _authJsonHeaders,
        body: json.encode({'test_key': testKey}),
      );
      if (res.statusCode == 200) {
        return ApiResult(
          statusCode: res.statusCode,
          data: json.decode(res.body) as List<dynamic>,
        );
      }
      return ApiResult(statusCode: res.statusCode);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Fetches available qualifications from the exam results endpoint.
  Future<ApiResult<List<dynamic>>> fetchQualifications() async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/egzaminy_wyniki_post.php'),
        headers: _authJsonHeaders,
        body: json.encode({}),
      );
      if (res.statusCode == 200) {
        return ApiResult(
          statusCode: res.statusCode,
          data: json.decode(res.body) as List<dynamic>,
        );
      }
      return ApiResult(statusCode: res.statusCode);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  // ─── Statistics ───────────────────────────────────────────────────────────

  /// Fetches per-user statistics for [userName].
  Future<ApiResult<Map<String, dynamic>>> fetchUserStats(
    String userName,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/stats.php'),
        headers: _apiKeyFormHeaders,
        body: {'userName': userName},
      );
      if (res.statusCode == 200) {
        return ApiResult(
          statusCode: res.statusCode,
          data: json.decode(res.body) as Map<String, dynamic>,
        );
      }
      return ApiResult(statusCode: res.statusCode);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Fetches all exam results (admin view).
  Future<ApiResult<List<dynamic>>> fetchAllStats() async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/stats_all.php'),
        headers: _apiKeyFormHeaders,
        body: {'api_token': apiKey},
      );
      if (res.statusCode == 200) {
        return ApiResult(
          statusCode: res.statusCode,
          data: json.decode(res.body) as List<dynamic>,
        );
      }
      return ApiResult(statusCode: res.statusCode);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Fetches the full question/answer detail for an exam (admin view).
  Future<ApiResult<Map<String, dynamic>>> fetchExamPreviewAdmin({
    required int examId,
    required String userName,
    required String examDateTime,
    required int durationSec,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/podgladEgzaminu.php'),
        body: {
          'api_token': apiKey,
          'exam_id': examId.toString(),
          'userName': userName,
          'exam_date': examDateTime,
          'duration_sec': durationSec.toString(),
        },
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return ApiResult(statusCode: res.statusCode, data: data);
        }
      }
      return ApiResult(statusCode: res.statusCode, errorMessage: res.body);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Fetches exam detail for a user's own history preview.
  Future<ApiResult<Map<String, dynamic>>> fetchExamPreviewUser({
    required int examId,
    required String examDateTime,
    required int durationSec,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/podgladEgzaminu_user.php'),
        body: {
          'api_token': apiKey,
          'exam_id': examId.toString(),
          'exam_date': examDateTime,
          'duration_sec': durationSec.toString(),
        },
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return ApiResult(statusCode: res.statusCode, data: data);
        }
      }
      return ApiResult(statusCode: res.statusCode, errorMessage: res.body);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Fetches exam detail for teacher test result preview.
  Future<ApiResult<Map<String, dynamic>>> fetchExamPreviewForTest(
    int examId,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/podgladEgzaminuDlaTestow.php'),
        body: {'api_token': apiToken, 'exam_id': examId.toString()},
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return ApiResult(statusCode: res.statusCode, data: data);
        }
      }
      return ApiResult(statusCode: res.statusCode, errorMessage: res.body);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  // ─── Admin Management ─────────────────────────────────────────────────────

  /// Checks whether [email] has super admin privileges.
  Future<ApiResult<bool>> checkSuperAdmin(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/is_super_admin.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        return ApiResult(
          statusCode: res.statusCode,
          data: data['isSuperAdmin'] == true,
        );
      }
      return ApiResult(statusCode: res.statusCode, data: false);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString(), data: false);
    }
  }

  /// Fetches the list of all admin accounts.
  Future<ApiResult<List<dynamic>>> fetchAdmins() async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/showAdmins.php'),
        headers: _apiKeyFormHeaders,
      );
      if (res.statusCode == 200) {
        return ApiResult(
          statusCode: res.statusCode,
          data: json.decode(res.body) as List<dynamic>,
        );
      }
      return ApiResult(statusCode: res.statusCode);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Adds a new admin by [email].
  Future<ApiResult<Map<String, dynamic>>> addAdmin(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/add_admin.php'),
        headers: _apiKeyFormHeaders,
        body: {'email': email},
      );
      if (res.statusCode == 200) {
        return ApiResult(
          statusCode: res.statusCode,
          data: json.decode(res.body) as Map<String, dynamic>,
        );
      }
      return ApiResult(statusCode: res.statusCode, errorMessage: res.body);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Promotes admin [id] to super admin.
  Future<ApiResult<Map<String, dynamic>>> promoteToSuperAdmin(int id) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/promote_super_admin.php'),
        headers: _apiKeyFormHeaders,
        body: {'id': id.toString()},
      );
      if (res.statusCode == 200) {
        return ApiResult(
          statusCode: res.statusCode,
          data: json.decode(res.body) as Map<String, dynamic>,
        );
      }
      return ApiResult(statusCode: res.statusCode, errorMessage: res.body);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Demotes super admin [id] back to regular admin.
  Future<ApiResult<Map<String, dynamic>>> demoteSuperAdmin(int id) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/demote_super_admin.php'),
        headers: _apiKeyFormHeaders,
        body: {'id': id.toString()},
      );
      if (res.statusCode == 200) {
        return ApiResult(
          statusCode: res.statusCode,
          data: json.decode(res.body) as Map<String, dynamic>,
        );
      }
      return ApiResult(statusCode: res.statusCode, errorMessage: res.body);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Deletes admin [id].
  Future<ApiResult<Map<String, dynamic>>> deleteAdmin(int id) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/delete_admin.php'),
        headers: _apiKeyFormHeaders,
        body: {'id': id.toString()},
      );
      if (res.statusCode == 200) {
        return ApiResult(
          statusCode: res.statusCode,
          data: json.decode(res.body) as Map<String, dynamic>,
        );
      }
      return ApiResult(statusCode: res.statusCode, errorMessage: res.body);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  Future<ApiResult<Map<String, dynamic>>> checkSession() async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/session-status.php'),
        headers: _authJsonHeaders,
        body: json.encode({}),
      );
      if (res.statusCode == 200) {
        return ApiResult(
          statusCode: res.statusCode,
          data: json.decode(res.body) as Map<String, dynamic>,
        );
      }
      return ApiResult(statusCode: res.statusCode);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }

  /// Logs the user out on the server.
  Future<ApiResult<void>> logout() async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/logout.php'),
        headers: _authJsonHeaders,
        body: json.encode({}),
      );
      return ApiResult(statusCode: res.statusCode);
    } catch (e) {
      return ApiResult(statusCode: -1, errorMessage: e.toString());
    }
  }
}
