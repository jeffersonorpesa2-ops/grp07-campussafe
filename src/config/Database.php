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

            // Display informative page if in debug mode, otherwise generic message
            $debug = Env::get('APP_DEBUG', 'false') === 'true';
            if ($debug) {
                die("<!DOCTYPE html>
                <html>
                <head><title>Database Connection Error</title>
                <style>body{font-family:sans-serif;padding:2rem;background:#fef2f2;color:#991b1b;} .box{background:#fff;padding:2rem;border-radius:8px;border:1px solid #f87171;max-width:650px;margin:auto;}</style>
                </head>
                <body>
                    <div class='box'>
                        <h2>Database Connection Error</h2>
                        <p><strong>Error:</strong> " . htmlspecialchars($e->getMessage()) . "</p>
                        <p><strong>DSN:</strong> " . htmlspecialchars($dsn) . "</p>
                        <p><strong>Configured User:</strong> " . htmlspecialchars($user) . "</p>
                        <hr>
                        <p><em>Please verify your PostgreSQL service status, database name, port (5432 or 5433), and credentials in your <code>.env</code> file.</em></p>
                    </div>
                </body>
                </html>");
            } else {
                die("A database error occurred. Please contact the system administrator.");
            }
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
