<?php
// getSingleResult.php
require_once 'config.php';
check_session_or_guest(); // opcjonalnie – możesz zostawić tylko token

$API_TOKEN = "zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^";

// =============================
// SPRAWDZENIE TOKENA
// =============================
$headers = apache_request_headers();
$auth = $headers['Authorization'] ?? $headers['authorization'] ?? '';
if (!preg_match('/Bearer\s(\S+)/', $auth, $m) || $m[1] !== $API_TOKEN) {
    http_response_code(401);
    echo json_encode(['error' => 'Brak autoryzacji']);
    exit;
}

// =============================
// ODCZYT JSON
// =============================
$data = json_decode(file_get_contents("php://input"), true);
if (!$data) {
    http_response_code(400);
    echo json_encode(['error' => 'Brak danych JSON']);
    exit;
}

$resultId   = $data['result_id'] ?? null;        // najbezpieczniejsze – po ID rekordu
$testKey    = $data['test_key'] ?? null;
$userName   = $data['userName'] ?? null;
$date       = $data['date'] ?? null;             // format: 2025-12-01 15:30:22

if (!$resultId && (!$testKey || !$userName || !$date)) {
    http_response_code(400);
    echo json_encode(['error' => 'Brak wymaganych parametrów']);
    exit;
}

// =============================
// POŁĄCZENIE Z BAZĄ
// =============================
$mysqli = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
$mysqli->set_charset('utf8mb4');

$sql = "";
$params = [];
$types = "";

if ($resultId) {
    // najszybsza i najpewniejsza metoda
    $sql = "SELECT userName, wynik, data_czas, czas_trwania_sec, pytania, wybrane_odpowiedzi 
            FROM published_tests_results 
            WHERE id = ? 
            LIMIT 1";
    $types = "i";
    $params[] = $resultId;
} else {
    // zapasowa metoda – po kluczu testu + uczeń + data (dokładna sekunda)
    $sql = "SELECT userName, wynik, data_czas, czas_trwania_sec, pytania, wybrane_odpowiedzi 
            FROM published_tests_results 
            WHERE test_key = ? AND userName = ? AND data_czas = ? 
            LIMIT 1";
    $types = "sss";
    $params = [$testKey, $userName, $date];
}

$stmt = $mysqli->prepare($sql);
$stmt->bind_param($types, ...$params);
$stmt->execute();
$result = $stmt->get_result();

if ($row = $result->fetch_assoc()) {
    // Zwróć wszystko co potrzebne do podglądu
    echo json_encode([
        'userName'          => $row['userName'],
        'score'             => round((float)$row['wynik'], 1),
        'date'              => $row['data_czas'],
        'duration_sec'      => (int)$row['czas_trwania_sec'],
        'questions'         => json_decode($row['pytania'], true),           // tablica pytań (tak jak w teście)
        'selectedAnswers'   => json_decode($row['wybrane_odpowiedzi'], true), // tablica "A","B",null,"C" itp.
    ], JSON_UNESCAPED_UNICODE);
} else {
    http_response_code(404);
    echo json_encode(['error' => 'Nie znaleziono wyniku']);
}

$stmt->close();
$mysqli->close();
?>