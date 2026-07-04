<?php
/**
 * db_connect.php — PMD Couture
 * Connexion PDO à la base de données db_couture
 * ⚠️  Modifiez DB_USER et DB_PASS avant déploiement
 */

define('DB_HOST',    'localhost');
define('DB_NAME',    'db_couture');
define('DB_USER',    'root');       // ← à modifier
define('DB_PASS',    '');           // ← à modifier
define('DB_CHARSET', 'utf8mb4');

function getPDO(): PDO {
    static $pdo = null;
    if ($pdo === null) {
        $dsn = "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=" . DB_CHARSET;
        try {
            $pdo = new PDO($dsn, DB_USER, DB_PASS, [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES   => false,
            ]);
        } catch (PDOException $e) {
            error_log('[Couture] DB Error: ' . $e->getMessage());
            http_response_code(500);
            die(json_encode(['success' => false, 'message' => 'Erreur de connexion à la base de données.']));
        }
    }
    return $pdo;
}
