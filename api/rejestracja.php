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

if (!isset($_POST['login']) || !isset($_POST['haslo']) || !isset($_POST['email'])) {
    die(json_encode(["status" => "error", "message" => "Brak wymaganych danych (login, hasło, email)"]));
}

$login = $_POST['login'];
$haslo = $_POST['haslo'];
$email = $_POST['email'];

$stmt = $conn->prepare("SELECT id FROM konta WHERE login = ?");
$stmt->bind_param("s", $login);
$stmt->execute();
$stmt->store_result();

if ($stmt->num_rows > 0) {
    echo json_encode(["status" => "error", "message" => "Login już istnieje"]);
    $stmt->close();
    $conn->close();
    exit;
}
$stmt->close();

$stmt = $conn->prepare("SELECT id FROM konta WHERE email = ?");
$stmt->bind_param("s", $email);
$stmt->execute();
$stmt->store_result();

if ($stmt->num_rows > 0) {
    echo json_encode(["status" => "error", "message" => "Email już istnieje"]);
    $stmt->close();
    $conn->close();
    exit;
}
$stmt->close();

$hashedPassword = password_hash($haslo, PASSWORD_BCRYPT);

$stmt = $conn->prepare("INSERT INTO konta (login, haslo, email) VALUES (?, ?, ?)");
$stmt->bind_param("sss", $login, $hashedPassword, $email);

if ($stmt->execute()) {
    echo json_encode(["status" => "success", "message" => "Rejestracja zakończona sukcesem"]);
    $stmt->close();
    $conn->close();
    exit;
} else {
    echo json_encode(["status" => "error", "message" => "Błąd podczas rejestracji", "details" => $stmt->error]);
    $stmt->close();
    $conn->close();
    exit;
}
?>
