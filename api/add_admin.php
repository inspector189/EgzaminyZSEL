<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

$host = "localhost";
$user = "local_user";
$password = "egz@min123!";
$dbname = "quali_que";

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Tylko POST']);
    exit;
}

$email = isset($_POST['email']) ? trim($_POST['email']) : null;

if (!$email || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode(['error' => 'Nieprawidłowy email']);
    exit;
}

$domain = '@zselektr.onmicrosoft.com';
if (strpos($email, $domain) === false) {
    http_response_code(400);
    echo json_encode(['error' => 'Email nie pochodzi z danej organizacji']);
    exit;
}

$conn = new mysqli($host, $user, $password, $dbname);
$conn->set_charset("utf8mb4");

if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode(['error' => 'Błąd połączenia: ' . $conn->connect_error]);
    exit;
}

$stmt_check = $conn->prepare("SELECT id FROM Users_Admin WHERE email = ?");
$stmt_check->bind_param("s", $email);
$stmt_check->execute();
if ($stmt_check->get_result()->num_rows > 0) {
    http_response_code(400);
    echo json_encode(['error' => 'Email już istnieje w bazie']);
    $stmt_check->close();
    $conn->close();
    exit;
}
$stmt_check->close();

$stmt = $conn->prepare("INSERT INTO Users_Admin (email) VALUES (?)");
$stmt->bind_param("s", $email);
$success = $stmt->execute();

if ($success) {
    echo json_encode(['success' => true]);
} else {
    http_response_code(500);
    echo json_encode(['error' => 'Błąd dodawania: ' . $conn->error]);
}

$stmt->close();
$conn->close();
?>