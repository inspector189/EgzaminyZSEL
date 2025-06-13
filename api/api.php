<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=utf-8");

$host = "localhost";
$user = "local_user";
$password = "egz@min123!";
$dbname = "quali_que";

$conn = new mysqli($host, $user, $password, $dbname);
$conn->set_charset("utf8mb4");

if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode(["error" => "Błąd połączenia z bazą danych"]);
    exit();
}

if (!isset($_GET['egzamin']) || !preg_match('/^[a-zA-Z0-9_]+$/', $_GET['egzamin'])) {
    http_response_code(400);
    echo json_encode(["error" => "Niepoprawna lub brakująca nazwa egzaminu"]);
    exit();
}

$table = $_GET['egzamin'];

$checkTable = $conn->query("SHOW TABLES LIKE '$table'");
if ($checkTable->num_rows === 0) {
    http_response_code(404);
    echo json_encode(["error" => "Nie znaleziono danych dla: $table"]);
    exit();
}

$imageBaseUrl = "https://interpage.pl/egzaminy/$table/obrazy/";
$imgStyle = '<style>img{display:block;max-width:100%;height:auto;margin:12px auto;}</style>';

$result = $conn->query("SELECT * FROM `$table`");
$data = [];

while ($row = $result->fetch_assoc()) {
    foreach ($row as $key => $value) {
        if (is_string($value)) {
            $value = str_replace('src="image', 'src="' . $imageBaseUrl . 'image', $value);
            $value = str_replace('\/', '/', $value);
            if (strpos($value, '<img') !== false) {
                $value = $imgStyle . $value;
            }
            $row[$key] = $value;
        }
    }
    $data[] = $row;
}

$conn->close();

echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
