<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Authorization, Content-Type');

// Validating Authorization header
$headers = apache_request_headers();
$expectedToken = 'Bearer zT93@rP!cV7YkXp#qLm&92oFvN*AhdM@#SSd&^';
if (!isset($headers['Authorization']) || $headers['Authorization'] !== $expectedToken) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

// Retrieving POST data
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

$userName = $_POST['userName'] ?? '';

if (empty($userName)) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing userName']);
    exit;
}

// Logging request for debugging
file_put_contents('debug.log', "Request: userName=$userName\n", FILE_APPEND);

// Connecting to MySQL database
$host = 'localhost';
$dbUser = 'local_user';
$dbPass = 'pdi30665';
$dbName = 'quali_que';

$conn = new mysqli($host, $dbUser, $dbPass, $dbName);

if ($conn->connect_error) {
    die("Błąd połączenia: " . $conn->connect_error);
}

// Querying statistics from the wyniki_egzaminow table for the user across all qualifications
$query = "SELECT 
    COUNT(*) as liczba_egzaminow,
    COALESCE(AVG(wynik), 0) as sredni_wynik,
    COALESCE(MAX(wynik), 0) as najlepszy_wynik,
    COALESCE(MIN(wynik), 0) as najgorszy_wynik
FROM wyniki_egzaminow
WHERE userName = ?";
$stmt = $conn->prepare($query);

if (!$stmt) {
    die("Błąd przygotowania zapytania: " . $conn->error);
}

$stmt->bind_param('s', $userName); // Bind only userName
$stmt->execute();
$result = $stmt->get_result();
$data = $result->fetch_assoc();

if (!$data || $data['liczba_egzaminow'] == 0) {
    http_response_code(404);
    echo json_encode(['error' => 'No exams found for this user']);
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