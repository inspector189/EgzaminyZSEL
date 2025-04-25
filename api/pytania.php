<?php
header('Content-Type: application/json; charset=utf-8');

$host = "78.10.167.155";
$user = "tulek";
$password = "pdi30665";
$dbname = "quali_que";

$conn = new mysqli($host, $user, $password, $dbname);
$conn->set_charset("utf8mb4");

if ($conn->connect_error) {
    die(json_encode(["error" => "Błąd połączenia z bazą"]));
}

$result = $conn->query("SELECT * FROM inf03 ORDER BY id ASC");

$questions = [];
while ($row = $result->fetch_assoc()) {
    $questions[] = $row;
}

$conn->close();
echo json_encode($questions, JSON_UNESCAPED_UNICODE);
?>