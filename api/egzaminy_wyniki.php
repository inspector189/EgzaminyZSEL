<?php
// Połączenie z bazą danych
$host = 'localhost';
$user = 'local_user';
$pass = 'egz@min123!';
$dbname = 'quali_que';

$conn = new mysqli($host, $user, $pass, $dbname);
if ($conn->connect_error) {
    die("Błąd połączenia: " . $conn->connect_error);
}

$sql = "SELECT * FROM egzaminy_wyniki";
$result = $conn->query($sql);
?>

<!DOCTYPE html>
<html lang="pl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Wyniki egzaminów</title>
    <style>
        body {
            background-color: #121212;
            color: #ffffff;
            font-family: Arial, sans-serif;
            padding: 20px;
        }
        h1 {
            text-align: center;
        }
        .table-container {
            overflow-x: auto;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin-top: 20px;
            background-color: #1e1e1e;
        }
        th, td {
            border: 1px solid #333;
            padding: 12px;
            text-align: left;
        }
        th {
            background-color: #2a2a2a;
        }
        tr:hover {
            background-color: #2e2e2e;
        }
        @media (max-width: 600px) {
            th, td {
                font-size: 14px;
                padding: 8px;
            }
        }
    </style>
</head>
<body>

<h1>Wyniki egzaminów</h1>

<div class="table-container">
    <table>
        <thead>
            <tr>
                <?php
                if ($result->num_rows > 0) {
                    // Wyświetlenie nagłówków kolumn
                    $firstRow = $result->fetch_assoc();
                    foreach ($firstRow as $colName => $value) {
                        echo "<th>" . htmlspecialchars($colName) . "</th>";
                    }
                    echo "</tr><tr>";
                    // Wyświetlenie pierwszego wiersza
                    foreach ($firstRow as $value) {
                        echo "<td>" . htmlspecialchars($value) . "</td>";
                    }
                    // Reszta wierszy
                    while ($row = $result->fetch_assoc()) {
                        echo "</tr><tr>";
                        foreach ($row as $value) {
                            echo "<td>" . htmlspecialchars($value) . "</td>";
                        }
                    }
                } else {
                    echo "<tr><td colspan='100%'>Brak wyników.</td></tr>";
                }
                ?>
            </tr>
        </thead>
    </table>
</div>

</body>
</html>

<?php
$conn->close();
?>
