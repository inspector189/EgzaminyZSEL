
bool isValidQualification(String? qual) {
  if (qual == null) return false;
  final trimmed = qual.trim().toLowerCase();
  return RegExp(r'^[a-z]{3}\d{2}$').hasMatch(trimmed);
}

const _apiKey = 'zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^';
const String apiToken = 'zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^';
const String publishedTestsUrl = 'https://egzaminy.zsel.edu.pl/egzaminy/publishedTests.php';