import 'package:flutter/foundation.dart' show kDebugMode;

const String clientId = '67af475e-082d-4187-b1ef-5fa26fa0fe77';
const String tenantId = 'de78aefd-fda9-4eaf-a2d1-cf8492188649';

const String baseUrl = 'https://egzaminy.zsel.edu.pl/';
const String apiToken = 'zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^';
const String apiBaseUrl = '$baseUrl/egzaminy/';

const bool kUseFakeData = kDebugMode;
const bool kFakeSuperAdmin = true;
const String kFakeEmail = "superadmin@zselektr.onmicrosoft.com";
const String kFakeUserName = "Super Admin";

bool isValidQualification(String? qual) {
  if (qual == null) return false;
  final trimmed = qual.trim().toLowerCase();
  return RegExp(r'^[a-z]{3}\d{2}$').hasMatch(trimmed);
}