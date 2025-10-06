<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *'); 
header('Access-Control-Allow-Methods: GET');
header('Access-Control-Allow-Headers: Content-Type');

$host = "localhost";
$user = "local_user";
$password = "egz@min123!";
$dbname = "quali_que";
$admins = [];
$error = null;

$conn = new mysqli($host, $user, $password, $dbname);
$conn->set_charset("utf8mb4");

if ($conn->connect_error) {
    $error = 'Błąd połączenia: ' . $conn->connect_error;
    http_response_code(500);
} else {
    $result = $conn->query("SELECT id, email FROM Users_Admin");
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            $admins[] = $row;
        }
        $result->free();
    } else {
        $error = 'Błąd zapytania: ' . $conn->error;
        http_response_code(500);
    }
    $conn->close();
}

if ($error) {
    echo json_encode(['error' => $error]);
} else {
    echo json_encode($admins);
}
?>