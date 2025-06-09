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

// Validating Authorization header
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

// Retrieving POST data
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
// Connecting to MySQL database
$conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
if ($conn->connect_error) {
    http_response_code(500);
    die("❌ Błąd połączenia z bazą danych");
}


// Querying statistics from the wyniki_egzaminow table for the user
$query = "SELECT 
    COUNT(*) as liczba_egzaminow,
    AVG(wynik) as sredni_wynik,
    MAX(wynik) as najlepszy_wynik,
    MIN(wynik) as najgorszy_wynik
FROM egzaminy_wyniki
WHERE userID = ?";
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
$data = $result->fetch_assoc();

if (!$data || $data['liczba_egzaminow'] == 0) {
    http_response_code(404);
    echo json_encode(['error' => 'Nie znaleziono egzaminów dla tego użytkownika']);
    file_put_contents('debug.log', "No data for userName=$userName\n", FILE_APPEND);
    $stmt->close();
    $conn->close();
    exit;
}

// Formatting the response to match Dart expectations
$response = [
    'Liczba podjętych egzaminów' => (int) $data['liczba_egzaminow'],
    'Średni wynik' => number_format($data['sredni_wynik'], 2) . '%',
    'Najlepszy wynik' => number_format($data['najlepszy_wynik'], 2) . '%',
    'Najgorszy wynik' => number_format($data['najgorszy_wynik'], 2) . '%',
];

// Logging successful response
file_put_contents('debug.log', "Response: " . json_encode($response) . "\n", FILE_APPEND);

// Closing database connections
$stmt->close();
$conn->close();

// Sending JSON response
http_response_code(200);
echo json_encode($response);
?>