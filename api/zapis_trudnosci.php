<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

$host = "localhost";
$user = "local_user";
$password = "egz@min123!";
$dbname = "quali_que";

$conn = new mysqli($host, $user, $password, $dbname);
$conn->set_charset("utf8mb4");

if ($conn->connect_error) {
    header('Content-Type: application/json');
    http_response_code(500);
    echo json_encode(['error' => 'Błąd połączenia: ' . $conn->connect_error]);
    exit;
}

// Check if it's a POST request
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    header('Content-Type: application/json');
    $pytanie_id = isset($_POST['pytanie_id']) ? (int)$_POST['pytanie_id'] : 0;
    $kwalifikacja = isset($_POST['kwalifikacja']) ? trim($_POST['kwalifikacja']) : 'default';
    $poprawna = isset($_POST['poprawna']) ? (int)$_POST['poprawna'] : 0;

    error_log("POST data: " . print_r($_POST, true));
    error_log("Inserting: pytanie_id=$pytanie_id, kwalifikacja=$kwalifikacja, poprawna=$poprawna");

    if ($pytanie_id <= 0) {
        echo json_encode(['status' => 'OK', 'message' => 'Pominięto zapis, nieprawidłowy pytanie_id', 'trudnosc' => 0]);
        exit;
    }

    $stmt = $conn->prepare("INSERT INTO pytania_trudnosc (pytanie_id, kwalifikacja, ilosc_odpowiedzi, ilosc_poprawnych_odpowiedzi)
        VALUES (?, ?, 1, ?) 
        ON DUPLICATE KEY UPDATE 
          ilosc_odpowiedzi = ilosc_odpowiedzi + 1,
          ilosc_poprawnych_odpowiedzi = ilosc_poprawnych_odpowiedzi + ?");
    if (!$stmt) {
        error_log("Prepare error: " . $conn->error);
        http_response_code(500);
        echo json_encode(['error' => 'Błąd przygotowania zapytania: ' . $conn->error]);
        exit;
    }

    $stmt->bind_param("isii", $pytanie_id, $kwalifikacja, $poprawna, $poprawna);
    if (!$stmt->execute()) {
        error_log("Execute error: " . $stmt->error);
        http_response_code(500);
        echo json_encode(['error' => 'Błąd wykonania zapytania: ' . $stmt->error]);
        exit;
    }

    // Calculate updated difficulty
    $stmt = $conn->prepare("SELECT ilosc_poprawnych_odpowiedzi, ilosc_odpowiedzi 
                            FROM pytania_trudnosc 
                            WHERE pytanie_id = ? AND kwalifikacja = ?");
    $stmt->bind_param("is", $pytanie_id, $kwalifikacja);
    $stmt->execute();
    $result = $stmt->get_result();
    $trudnosc = 0;
    if ($row = $result->fetch_assoc()) {
        $trudnosc = $row['ilosc_odpowiedzi'] > 0 
            ? ($row['ilosc_poprawnych_odpowiedzi'] / $row['ilosc_odpowiedzi']) * 100 
            : 0;
    }

    echo json_encode(['status' => 'OK', 'trudnosc' => round($trudnosc)]);
    $stmt->close();
} elseif ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['kwalifikacja'])) {
    header('Content-Type: application/json');
    $kwalifikacja = trim($_GET['kwalifikacja']);

    // Fetch questions with difficulty
    $stmt = $conn->prepare("SELECT pt.pytanie_id AS id, 
                           (SELECT pytanie FROM pytania p WHERE p.id = pt.pytanie_id AND p.kwalifikacja = pt.kwalifikacja LIMIT 1) AS pytanie,
                           (SELECT odp1 FROM pytania p WHERE p.id = pt.pytanie_id AND p.kwalifikacja = pt.kwalifikacja LIMIT 1) AS odp1,
                           (SELECT odp2 FROM pytania p WHERE p.id = pt.pytanie_id AND p.kwalifikacja = pt.kwalifikacja LIMIT 1) AS odp2,
                           (SELECT odp3 FROM pytania p WHERE p.id = pt.pytanie_id AND p.kwalifikacja = pt.kwalifikacja LIMIT 1) AS odp3,
                           (SELECT odp4 FROM pytania p WHERE p.id = pt.pytanie_id AND p.kwalifikacja = pt.kwalifikacja LIMIT 1) AS odp4,
                           (SELECT poprawna FROM pytania p WHERE p.id = pt.pytanie_id AND p.kwalifikacja = pt.kwalifikacja LIMIT 1) AS poprawna,
                           (SELECT opisPoprawne FROM pytania p WHERE p.id = pt.pytanie_id AND p.kwalifikacja = pt.kwalifikacja LIMIT 1) AS opisPoprawne,
                           (SELECT opisNiepoprawne FROM pytania p WHERE p.id = pt.pytanie_id AND p.kwalifikacja = pt.kwalifikacja LIMIT 1) AS opisNiepoprawne,
                           (pt.ilosc_poprawnych_odpowiedzi / pt.ilosc_odpowiedzi * 100) AS trudnosc
                           FROM pytania_trudnosc pt 
                           WHERE pt.kwalifikacja = ?");
    if (!$stmt) {
        error_log("Prepare error: " . $conn->error);
        http_response_code(500);
        echo json_encode(['error' => 'Błąd przygotowania zapytania: ' . $conn->error]);
        exit;
    }

    $stmt->bind_param("s", $kwalifikacja);
    $stmt->execute();
    $result = $stmt->get_result();

    $questions = [];
    while ($row = $result->fetch_assoc()) {
        if ($row['ilosc_odpowiedzi'] > 0) {
            $questions[] = $row;
        }
    }

    echo json_encode($questions);
    $stmt->close();
} else {
    // Display HTML table for direct browser access
    header('Content-Type: text/html; charset=UTF-8');
    ?>
    <!DOCTYPE html>
    <html lang="pl">
    <head>
        <meta charset="UTF-8">
        <title>Pytania – statystyki trudności</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                padding: 40px;
                background-color: #f7f7f7;
            }
            h1 {
                text-align: center;
                margin-bottom: 30px;
            }
            .table-container {
                overflow-x: auto;
                background: white;
                padding: 20px;
                border-radius: 12px;
                box-shadow: 0 0 10px rgba(0,0,0,0.1);
                max-width: 1000px;
                margin: auto;
            }
            table {
                border-collapse: collapse;
                width: 100%;
                min-width: 600px;
            }
            th, td {
                border: 1px solid #ccc;
                padding: 12px 16px;
                text-align: center;
            }
            th {
                background-color: #004488;
                color: white;
            }
            tr:nth-child(even) {
                background-color: #f2f2f2;
            }
            .latwe {
                color: green;
                font-weight: bold;
            }
            .trudne {
                color: red;
                font-weight: bold;
            }
        </style>
    </head>
    <body>
        <h1>Statystyki trudności pytań</h1>
        <div class="table-container">
            <?php
            $result = $conn->query("SELECT pt.pytanie_id, pt.kwalifikacja, pt.ilosc_odpowiedzi, pt.ilosc_poprawnych_odpowiedzi,
                                    IF(pt.ilosc_odpowiedzi > 0, (pt.ilosc_poprawnych_odpowiedzi / pt.ilosc_odpowiedzi * 100), 0) AS trudnosc
                                    FROM pytania_trudnosc pt ORDER BY trudnosc ASC");

            if ($result && $result->num_rows > 0) {
                echo "<table>";
                echo "<thead><tr><th>pytanie_id</th><th>kwalifikacja</th><th>ilosc_odpowiedzi</th><th>ilosc_poprawnych_odpowiedzi</th><th>trudnosc</th></tr></thead><tbody>";

                while ($row = $result->fetch_assoc()) {
                    echo "<tr>";
                    echo "<td>" . htmlspecialchars($row['pytanie_id']) . "</td>";
                    echo "<td>" . htmlspecialchars($row['kwalifikacja']) . "</td>";
                    echo "<td>" . htmlspecialchars($row['ilosc_odpowiedzi']) . "</td>";
                    echo "<td>" . htmlspecialchars($row['ilosc_poprawnych_odpowiedzi']) . "</td>";
                    echo "<td class='" . ($row['trudnosc'] < 50 ? "trudne" : "latwe") . "'>" . round($row['trudnosc']) . "%</td>";
                    echo "</tr>";
                }

                echo "</tbody></table>";
            } else {
                echo "<p style='text-align: center; font-size: 18px; color: #555;'>Brak pytań w bazie danych.</p>";
            }
            ?>
        </div>
    </body>
    </html>
    <?php
}

$conn->close();
?>