<?php

require_once '/var/strony/config.php';

// Nagłówki CORS
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type');

// Obsługa preflight (OPTIONS)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Walidacja nagłówka Authorization
$headers = apache_request_headers();
$authHeader = $headers['Authorization'] ?? '';

if (!preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    http_response_code(401);
    echo json_encode(['error' => 'Brak lub błędny nagłówek Authorization']);
    exit;
}

$token = $matches[1];

if ($token !== API_SECRET_TOKEN) {
    http_response_code(403);
    die('❌ Nieprawidłowy token dostępu');
}

// Pobieranie danych POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Metoda nie dozwolona']);
    exit;
}

$userName = $_POST['userName'] ?? '';

if (empty($userName)) {
    http_response_code(400);
    echo json_encode(['error' => 'Brak parametru userName']);
    exit;
}

// Połączenie z bazą danych MySQL
$conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
if ($conn->connect_error) {
    http_response_code(500);
    die("❌ Błąd połączenia z bazą danych");
}

// Zapytanie o statystyki dla każdej kwalifikacji
$query = "SELECT 
    kwalifikacja,
    COUNT(*) as liczba_egzaminow,
    AVG(wynik) as sredni_wynik,
    MAX(wynik) as najlepszy_wynik,
    MIN(wynik) as najgorszy_wynik
FROM egzaminy_wyniki
WHERE userID = ?
GROUP BY kwalifikacja
HAVING liczba_egzaminow > 0";
$stmt = $conn->prepare($query);

if (!$stmt) {
    http_response_code(500);
    echo json_encode(['error' => 'Błąd przygotowania zapytania']);
    file_put_contents('debug.log', "Błąd zapytania: " . $conn->error . "\n", FILE_APPEND);
    $conn->close();
    exit;
}

$stmt->bind_param('s', $userName);
$stmt->execute();
$result = $stmt->get_result();

$statsByQualification = [];
while ($row = $result->fetch_assoc()) {
    $statsByQualification[$row['kwalifikacja']] = [
        'Liczba podjętych egzaminów' => (int) $row['liczba_egzaminow'],
        'Średni wynik' => number_format($row['sredni_wynik'], 2) . '%',
        'Najlepszy wynik' => number_format($row['najlepszy_wynik'], 2) . '%',
        'Najgorszy wynik' => number_format($row['najgorszy_wynik'], 2) . '%',
    ];
}

if (empty($statsByQualification)) {
    http_response_code(404);
    echo json_encode(['error' => 'Nie znaleziono egzaminów dla tego użytkownika']);
    file_put_contents('debug.log', "No data for userName=$userName\n", FILE_APPEND);
    $stmt->close();
    $conn->close();
    exit;
}

// Logowanie odpowiedzi
file_put_contents('debug.log', "Response: " . json_encode($statsByQualification) . "\n", FILE_APPEND);

// Zamykanie połączeń z bazą danych
$stmt->close();
$conn->close();

// Wysłanie odpowiedzi JSON
http_response_code(200);
echo json_encode($statsByQualification);
?>