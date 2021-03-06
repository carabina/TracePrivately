<?php
$path = realpath(dirname(__FILE__) . '/../data/trace.sqlite');
$db = new SQLite3($path, SQLITE3_OPEN_READWRITE);

// TODO: Validate bearer token and throw 401 if not valid
// TODO: Implement proper error responses


$minTime = time() - (86400 * 14);
$time = $minTime;

if (array_key_exists('since', $_GET)) {
    try {
        $dateTime = new DateTime($_GET['since']);
        $time = max($minTime, $dateTime->getTimestamp());
    }
    catch (Exception $e) {
	
    }
}

$stmt = $db->prepare('SELECT infected_key FROM infected_keys WHERE status = :s AND status_updated >= :t');
$stmt->bindValue(':t', $time, SQLITE3_INTEGER);
$stmt->bindValue(':s', 'A', SQLITE3_TEXT);

$result = $stmt->execute();

$keys = array();

while (($row = $result->fetchArray(SQLITE3_NUM))) {
    $keys[] = $row[0];
}

$date = new DateTime();

$json = array(
    'status' => 'OK',
    'date' => $date->format(DateTimeInterface::ISO8601),
    'keys' => $keys,
    'deleted_keys' => array()
);

//$data = json_encode($json, JSON_PRETTY_PRINT);
$data = json_encode($json);

header('Content-type: application/json; charset=utf-8');
echo $data;

