<?php
/**
 * CampusSafe: Database Connection Manager (PDO)
 * 
 * Provides connection pooling/singleton pattern for PostgreSQL 14+
 * Reads configuration exclusively from environment variables.
 */

require_once __DIR__ . '/Env.php';

class Database
{
    private static ?PDO $connection = null;

    /**
     * Get active PDO database connection
     */
    public static function getConnection(): PDO
    {
        if (self::$connection !== null) {
            return self::$connection;
        }

        // Ensure environment variables are loaded
        $envPath = dirname(__DIR__, 2) . '/.env';
        if (file_exists($envPath)) {
            Env::load($envPath);
        } else {
            // If .env is missing and running in a browser, redirect to the 1-click installer
            if (php_sapi_name() !== 'cli' && basename($_SERVER['SCRIPT_NAME'] ?? '') !== 'install.php') {
                header('Location: /install.php');
                exit;
            }
        }

        $host = Env::get('DB_HOST', 'localhost');
        $port = Env::get('DB_PORT', '5432');
        $dbname = Env::get('DB_NAME', 'grp07_campussafedb');
        $user = Env::get('DB_USER', 'campussafe_app');
        $password = Env::get('DB_PASSWORD', '');

        $dsn = "pgsql:host={$host};port={$port};dbname={$dbname}";

        $options = [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
            PDO::ATTR_TIMEOUT            => 5,
        ];

        try {
            self::$connection = new PDO($dsn, $user, $password, $options);
            return self::$connection;
        } catch (PDOException $e) {
            $errorMsg = "Database Connection Failed: " . $e->getMessage();
            error_log($errorMsg);

            if (php_sapi_name() === 'cli') {
                die("Database Connection Error: " . $e->getMessage() . "\n");
            }

            // Display friendly troubleshooting page with 1-click wizard button
            http_response_code(500);
            die("<!DOCTYPE html>
            <html lang='en'>
            <head>
                <meta charset='UTF-8'>
                <meta name='viewport' content='width=device-width, initial-scale=1.0'>
                <title>Database Setup Required - CampusSafe</title>
                <style>
                    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #f8fafc; padding: 2rem 1rem; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; }
                    .card { background: #1e293b; border: 1px solid #334155; border-radius: 12px; padding: 2rem; max-width: 620px; width: 100%; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.5); }
                    .tag { background: #ef4444; color: #fff; padding: 0.25rem 0.6rem; border-radius: 4px; font-size: 0.75rem; font-weight: 700; text-transform: uppercase; }
                    h2 { margin: 1rem 0 0.5rem 0; font-size: 1.5rem; color: #f8fafc; }
                    p { color: #cbd5e1; font-size: 0.95rem; line-height: 1.5; margin: 0.5rem 0; }
                    .code-box { background: #090d16; border: 1px solid #1e293b; padding: 0.85rem; border-radius: 6px; font-family: monospace; font-size: 0.85rem; color: #f87171; overflow-x: auto; margin: 1rem 0; }
                    .btn-wizard { display: block; text-align: center; background: #2563eb; color: #fff; text-decoration: none; padding: 0.85rem; border-radius: 6px; font-weight: 600; font-size: 1rem; transition: background 0.15s; margin-top: 1.5rem; }
                    .btn-wizard:hover { background: #1d4ed8; }
                </style>
            </head>
            <body>
                <div class='card'>
                    <span class='tag'>Database Connection Notice</span>
                    <h2>CampusSafe Database Setup Required</h2>
                    <p>The application could not establish a connection to PostgreSQL with the configured settings.</p>
                    <div class='code-box'>" . htmlspecialchars($e->getMessage()) . "</div>
                    <p><strong>Configured Target:</strong> <code>" . htmlspecialchars($user) . "@" . htmlspecialchars($host) . ":" . htmlspecialchars($port) . "/" . htmlspecialchars($dbname) . "</code></p>
                    <p>If you have not set up the database yet, click below to automatically create and seed it in one click:</p>
                    <a href='/install.php' class='btn-wizard'>🚀 Open 1-Click Setup Wizard (/install.php) &rarr;</a>
                </div>
            </body>
            </html>");
        }
    }

    /**
     * Check if database schema tables have been installed
     */
    public static function isInitialized(): bool
    {
        try {
            $pdo = self::getConnection();
            $stmt = $pdo->query("SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'hazard_report'");
            return (bool)$stmt->fetchColumn();
        } catch (Throwable $e) {
            return false;
        }
    }

    /**
     * Explicitly close connection if needed
     */
    public static function closeConnection(): void
    {
        self::$connection = null;
    }
}
