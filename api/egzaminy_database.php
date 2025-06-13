<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

$host = "localhost"; // lub IP serwera
$user = "local_user";
$password = "egz@min123!";
$dbname = "quali_que";

$conn = new mysqli($host, $user, $password, $dbname);
$conn->set_charset("utf8mb4");

if ($conn->connect_error) {
    die("❌ Błąd połączenia: " . $conn->connect_error);
}

$sql = "SELECT * FROM inf03";
$result = $conn->query($sql);
?>

<!DOCTYPE html>
<html lang="pl">
<head>
    <meta charset="UTF-8">
    <title>Lista pytań</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: #f3f3f3;
            padding: 20px;
        }
        h1 {
            text-align: center;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            background: #fff;
            box-shadow: 0 0 8px rgba(0,0,0,0.1);
        }
        th, td {
            border: 1px solid #ddd;
            padding: 12px;
            vertical-align: top;
        }
        th {
            background-color: #4CAF50;
            color: white;
        }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .code-block {
            font-family: Consolas, monospace;
            background: #eee;
            padding: 6px;
            display: inline-block;
        }
    </style>
</head>
<body>

<h1>📚 Lista pytań z bazy danych</h1>

<table>
    <tr>
        <th>ID</th>
        <th>Pytanie</th>
        <th>A</th>
        <th>B</th>
        <th>C</th>
        <th>D</th>
        <th>Poprawna</th>
        <th>Opis poprawnej</th>
        <th>Opis błędnej</th>
    </tr>

    <?php while ($row = $result->fetch_assoc()): ?>
    <tr>
        <td><?= htmlspecialchars($row["id"]) ?></td>
        <td><?= $row["pytanie"] ?></td>
        <td><?= $row["odp1"] ?></td>
        <td><?= $row["odp2"] ?></td>
        <td><?= $row["odp3"] ?></td>
        <td><?= $row["odp4"] ?></td>
        <td style="text-align:center;"><strong><?= $row["poprawna"] ?></strong></td>
        <td><?= $row["opisPoprawne"] ?></td>
        <td><?= $row["opisNiepoprawne"] ?></td>
    </tr>
    <?php endwhile; ?>

</table>

</body>
</html>

<?php
$conn->close();
?>
