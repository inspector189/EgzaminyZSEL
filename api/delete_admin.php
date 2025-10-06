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

$id = isset($_POST['id']) ? (int)$_POST['id'] : null;

if (!$id) {
    http_response_code(400);
    echo json_encode(['error' => 'Brak ID']);
    exit;
}

$conn = new mysqli($host, $user, $password, $dbname);
$conn->set_charset("utf8mb4");

if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode(['error' => 'Błąd połączenia: ' . $conn->connect_error]);
    exit;
}

$stmt = $conn->prepare("DELETE FROM Users_Admin WHERE id = ?");
$stmt->bind_param("i", $id);
$success = $stmt->execute();

if ($success && $stmt->affected_rows > 0) {
    echo json_encode(['success' => true]);
} else {
    http_response_code(404);
    echo json_encode(['error' => 'Admin nie znaleziony']);
}

$stmt->close();
$conn->close();
?>