<?php
header('Content-Type: application/json; charset=utf-8');

$host = "localhost";
$user = "root";
$password = "";
$dbname = "login";

$conn = new mysqli($host, $user, $password, $dbname);
$conn->set_charset("utf8mb4");

if ($conn->connect_error) {
    die(json_encode(["status" => "error", "message" => "Błąd połączenia z bazą danych", "details" => $conn->connect_error]));
}

if (!isset($_POST['login']) || !isset($_POST['haslo'])) {
    die(json_encode(["status" => "error", "message" => "Brak wymaganych danych (login i hasło)"]));
}

$login = $_POST['login'];
$haslo = $_POST['haslo'];

// Przygotowane zapytanie
$stmt = $conn->prepare("SELECT haslo FROM konta WHERE login = ?");
$stmt->bind_param("s", $login);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    echo json_encode(["status" => "error", "message" => "Niepoprawny login lub hasło"]);
} else {
    $row = $result->fetch_assoc();
    $hashedPassword = $row['haslo'];

    if (password_verify($haslo, $hashedPassword)) {
        echo json_encode(["status" => "success", "message" => "Zalogowano pomyślnie"]);
    } else {
        echo json_encode(["status" => "error", "message" => "Niepoprawny login lub hasło"]);
    }
}

$stmt->close();
$conn->close();
?>
