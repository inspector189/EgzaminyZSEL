bool isValidQualification(String? qual) {
  if (qual == null) return false;
  final trimmed = qual.trim().toLowerCase();
  return RegExp(r'^[a-z]{3}\d{2}$').hasMatch(trimmed);
}

const String clientId = '67af475e-082d-4187-b1ef-5fa26fa0fe77';
const String tenantId = 'de78aefd-fda9-4eaf-a2d1-cf8492188649';
const String redirectUri = 'https://egzaminy.zsel.edu.pl/redirect.html';
const String tokenUrl =
    'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token';
const String authorizeUrl =
    'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize';
const List<String> scopes = [
  'openid',
  'profile',
  'email',
  'User.Read',
  'offline_access',
];

const apiKey = 'zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^';
const String debugSecret =
    '5b056d89c6ecb7fa54f0268cb6df39eb73d27c9fe60b52393c36f262971ec047';
const String apiToken = 'zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^';
const String apiBaseUrl = 'https://egzaminy.zsel.edu.pl/egzaminy/';
const String allTestsUrl =
    'https://egzaminy.zsel.edu.pl/egzaminy/publishedTests_admin.php';
const String publishedTestsUrl =
    'https://egzaminy.zsel.edu.pl/egzaminy/publishedTests.php';
