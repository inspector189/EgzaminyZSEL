<?php
// 🔓 CORS dla aplikacji Flutter Web
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=utf-8");

// 🔑 Dane dostępowe do bazy danych
$host = "localhost";
$user = "local_user";         // ← zamień na swój użytkownik
$password = "egz@min123!";       // ← zamień na swoje hasło
$dbname = "quali_que";

// 🔌 Połącz z bazą
$conn = new mysqli($host, $user, $password, $dbname);
$conn->set_charset("utf8mb4");

// 🧨 Błąd połączenia?
if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode(["error" => "Błąd połączenia z bazą danych"]);
    exit();
}

// 📦 Pobierz dane z tabeli
$result = $conn->query("SELECT * FROM inf03");
$data = [];

// 🌐 URL do folderu z obrazkami
$imageBaseUrl = "https://interpage.pl/egzaminy/inf03/obrazy/";
$imgStyle = '<style>img{display:block;max-width:100%;height:auto;margin:12px auto;}</style>';

while ($row = $result->fetch_assoc()) {
    foreach ($row as $key => $value) {
        if (is_string($value)) {
            // 🔗 Napraw linki do obrazków
            $value = str_replace('src="image', 'src="' . $imageBaseUrl . 'image', $value);
            $value = str_replace('\/', '/', $value);

            // 🎨 Dodaj style tylko jeśli jest <img>
            if (strpos($value, '<img') !== false) {
                $value = $imgStyle . $value;
            }

            $row[$key] = $value;
        }
    }
    $data[] = $row;
}

// 📴 Zamknij połączenie
$conn->close();

// 📤 Zwróć dane w JSON
echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
