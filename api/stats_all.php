<?php
require_once '/var/strony/config.php';

// Nagłówki CORS
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Authorization, Content-Type');

// Preflight (OPTIONS)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Tylko POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Metoda nie dozwolona (użyj POST)']);
    exit;
}

// Pobranie nagłówków (działa i na Apache, i na nginx/FPM)
$headers = function_exists('getallheaders') ? getallheaders() : [];
$authHeader = $headers['Authorization'] ?? ($headers['authorization'] ?? '');

if (!preg_match('/Bearer\s(\S+)/', $authHeader, $m)) {
    http_response_code(401);
    echo json_encode(['error' => 'Brak lub błędny nagłówek Authorization']);
    exit;
}
$token = $m[1];
if ($token !== API_SECRET_TOKEN) {
    http_response_code(403);
    echo json_encode(['error' => 'Nieprawidłowy token dostępu']);
    exit;
}

// Połączenie z bazą
$conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode(['error' => 'Błąd połączenia z bazą danych']);
    exit;
}
$conn->set_charset('utf8mb4');

// Pobranie całej tabeli
$sql = "SELECT * FROM egzaminy_wyniki ORDER BY data_czas DESC";

//$sql = "SELECT * FROM egzaminy_wyniki ORDER BY id DESC";
$result = $conn->query($sql);

if (!$result) {
    http_response_code(500);
    echo json_encode(['error' => 'Błąd zapytania: ' . $conn->error]);
    $conn->close();
    exit;
}

$data = [];
while ($row = $result->fetch_assoc()) {
    // konwersja typów
    if (isset($row['id'])) $row['id'] = (int)$row['id'];
    if (isset($row['wynik'])) $row['wynik'] = (float)$row['wynik'];
    if (isset($row['czas_trwania_sec'])) $row['czas_trwania_sec'] = (int)$row['czas_trwania_sec'];
    $data[] = $row;
}

$conn->close();

if (empty($data)) {
    http_response_code(404);
    echo json_encode(['error' => 'Brak danych w tabeli egzaminy_wyniki']);
    exit;
}

// Zwróć wszystko
http_response_code(200);
echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT);
