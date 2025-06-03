<?php
$host = 'localhost';
$user = 'root';
$pass = '';
$db   = 'quali_que';

$conn = new mysqli($host, $user, $pass, $db);
if ($conn->connect_error) {
    die("Błąd połączenia: " . $conn->connect_error);
}

$kwalifikacja = $_POST['kwalifikacja'] ?? null;
$wynik = isset($_POST['wynik']) ? (float) $_POST['wynik'] : null;
$data_czas = $_POST['data_czas'] ?? null;
$czas_trwania = isset($_POST['czas_trwania']) ? (int) $_POST['czas_trwania'] : null;
$userID = $_POST['userID'] ?? 'anonymous'; // Default to 'anonymous' if not provided

if (!$kwalifikacja || !$wynik || !$data_czas || !$czas_trwania || !$userID) {
    die("❌ Brakuje danych w żądaniu POST");
}

$stmt = $conn->prepare("INSERT INTO egzaminy_wyniki (kwalifikacja, wynik, data_czas, czas_trwania_sec, userID) VALUES (?, ?, ?, ?, ?)");
$stmt->bind_param("sdsis", $kwalifikacja, $wynik, $data_czas, $czas_trwania, $userID);
$stmt->execute();

if ($stmt->affected_rows > 0) {
    echo "OK";
} else {
    echo "Błąd zapisu";
}

$stmt->close();
$conn->close();
?>