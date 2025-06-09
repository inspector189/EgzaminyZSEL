<?php

require_once '/var/strony/config.php';

// Nagłówki CORS
header("Access-Control-Allow-Origin: *"); // ← zmień na swoją domenę
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// Obsługa preflight (OPTIONS)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Uwierzytelnianie: Authorization: Bearer superSekretnyToken123
$headers = apache_request_headers();
$authHeader = $headers['Authorization'] ?? '';

if (!preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    http_response_code(401);
    die('❌ Brak lub błędny nagłówek Authorization');
}

$token = $matches[1];

if ($token !== API_SECRET_TOKEN) {
    http_response_code(403);
    die('❌ Nieprawidłowy token dostępu');
}

// Połączenie z bazą (z config.php)
$conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
if ($conn->connect_error) {
    http_response_code(500);
    die("❌ Błąd połączenia z bazą danych");
}

// Pobranie danych POST
$kwalifikacja = $_POST['kwalifikacja'] ?? null;
$wynik = isset($_POST['wynik']) ? (float) $_POST['wynik'] : null;
$data_czas = $_POST['data_czas'] ?? null;
$czas_trwania = isset($_POST['czas_trwania']) ? (int) $_POST['czas_trwania'] : null;
$userID = $_POST['userName'] ?? 'anonymous'; // Default to 'anonymous' if not provided

// Walidacja danych
if (!$kwalifikacja || !$wynik || !$data_czas || !$czas_trwania || !$userID) {
    http_response_code(400);
    die("❌ Brakuje wymaganych danych");
}

if (!strtotime($data_czas)) {
    http_response_code(400);
    die("❌ Nieprawidłowy format daty");
}

// Zapis do bazy z userID
$stmt = $conn->prepare("INSERT INTO egzaminy_wyniki (kwalifikacja, wynik, data_czas, czas_trwania_sec, userID) VALUES (?, ?, ?, ?, ?)");
$stmt->bind_param("sdsis", $kwalifikacja, $wynik, $data_czas, $czas_trwania, $userID);
$stmt->execute();

if ($stmt->affected_rows > 0) {
    echo "✅ OK";
} else {
    http_response_code(500);
    echo "❌ Błąd zapisu";
}

$stmt->close();
$conn->close();
?>
