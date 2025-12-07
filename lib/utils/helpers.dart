bool isValidQualification(String? qual) {
  if (qual == null) return false;
  final trimmed = qual.trim().toLowerCase();
  return RegExp(r'^[a-z]{3}\d{2}$').hasMatch(trimmed);
}

const apiKey = 'zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^';
const String debugSecret =
    '5b056d89c6ecb7fa54f0268cb6df39eb73d27c9fe60b52393c36f262971ec047';
const String apiToken = 'zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^';
const String apiBaseUrl = 'https://egzaminy.zsel.edu.pl/egzaminy/';
const String allTestsUrl =
    'https://egzaminy.zsel.edu.pl/egzaminy/publishedTests_admin.php';
const String publishedTestsUrl =
    'https://egzaminy.zsel.edu.pl/egzaminy/publishedTests.php';
