<?php
/**
 * CampusSafe: Automated Command-Line Setup Script
 * 
 * Configures environment, verifies PHP extensions, creates database,
 * executes schema and seed data, generates demo assets, and prepares .env.
 * 
 * Usage:
 *   php bin/setup.php
 *   php bin/setup.php --defaults
 */

if (php_sapi_name() !== 'cli') {
    die("This script must be run from the command line.\n");
}

$projectRoot = dirname(__DIR__);
$envPath = $projectRoot . '/.env';
$envExamplePath = $projectRoot . '/.env.example';

echo "=================================================================\n";
echo "  CampusSafe - Automated Setup Wizard (COMP 018 Group 7)\n";
echo "=================================================================\n\n";

// Helper for colored console output
function color($text, $color = 'green'): string {
    $colors = [
        'green'  => "\033[32m",
        'red'    => "\033[31m",
        'yellow' => "\033[33m",
        'blue'   => "\033[34m",
        'cyan'   => "\033[36m",
        'reset'  => "\033[0m"
    ];
    // On Windows cmd without VT100 support, strip escape codes if unsupported
    return ($colors[$color] ?? '') . $text . ($colors['reset'] ?? '');
}

// 1. Check PHP Version
echo "[1/6] Checking PHP environment...\n";
if (version_compare(PHP_VERSION, '8.2.0', '<')) {
    echo color("  [FAIL] PHP version " . PHP_VERSION . " detected. PHP 8.2 or higher is required.\n", 'red');
    exit(1);
}
echo color("  [PASS] PHP version: " . PHP_VERSION . "\n", 'green');

// 2. Check Extensions & Auto-Fix php.ini if needed
$requiredExtensions = ['pdo', 'pdo_pgsql', 'pgsql'];
$optionalExtensions = ['gd', 'fileinfo'];
$missingRequired = [];

foreach ($requiredExtensions as $ext) {
    if (!extension_loaded($ext)) {
        $missingRequired[] = $ext;
    }
}

if (!empty($missingRequired)) {
    echo color("  [WARN] Missing required PostgreSQL extension(s): " . implode(', ', $missingRequired) . "\n", 'yellow');
    
    // Attempt automatic php.ini configuration
    $iniFile = php_ini_loaded_file();
    if (!$iniFile) {
        $candidate = dirname(PHP_BINARY) . '/php.ini';
        if (file_exists($candidate)) {
            $iniFile = $candidate;
        } elseif (file_exists(dirname(PHP_BINARY) . '/php.ini-development')) {
            copy(dirname(PHP_BINARY) . '/php.ini-development', $candidate);
            $iniFile = $candidate;
        }
    }

    if ($iniFile && is_writable($iniFile)) {
        echo "  [INFO] Found php.ini at: {$iniFile}\n";
        echo "  [INFO] Attempting to auto-enable PostgreSQL extensions in php.ini...\n";
        
        $iniContent = file_get_contents($iniFile);
        $modified = false;

        // Ensure extension_dir = "ext" on Windows
        if (stripos($iniContent, 'extension_dir') === false || preg_match('/;extension_dir\s*=\s*"ext"/', $iniContent)) {
            $iniContent = preg_replace('/;extension_dir\s*=\s*"ext"/', 'extension_dir = "ext"', $iniContent, 1);
            $modified = true;
        }

        // Uncomment extensions
        foreach (['pdo_pgsql', 'pgsql', 'gd', 'fileinfo'] as $extName) {
            $pattern = '/;extension\s*=\s*' . preg_quote($extName, '/') . '/i';
            if (preg_match($pattern, $iniContent)) {
                $iniContent = preg_replace($pattern, 'extension=' . $extName, $iniContent);
                $modified = true;
            }
        }

        if ($modified) {
            file_put_contents($iniFile, $iniContent);
            echo color("  [SUCCESS] Updated php.ini! Enabled pdo_pgsql and pgsql.\n", 'green');
            echo color("  [NOTICE] Please re-run 'setup.bat' or 'php bin/setup.php' to load the new settings.\n", 'yellow');
            exit(0);
        }
    }

    echo color("  [ERROR] Could not automatically enable pdo_pgsql.\n", 'red');
    echo "  Please open your php.ini and uncomment:\n";
    echo "    extension=pdo_pgsql\n";
    echo "    extension=pgsql\n\n";
    exit(1);
}
echo color("  [PASS] PostgreSQL PDO drivers loaded.\n\n", 'green');

// 3. Gather Database Credentials
echo "[2/6] Database Connection Configuration\n";

$useDefaults = in_array('--defaults', $argv) || in_array('-y', $argv);

// Load current defaults from existing .env if present
$dbHost = 'localhost';
$dbPort = '5432';
$dbName = 'grp07_campussafedb';
$dbUser = 'postgres';
$dbPass = 'postgres';

if (file_exists($envPath)) {
    $lines = file($envPath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        $line = trim($line);
        if ($line === '' || str_starts_with($line, '#')) continue;
        $parts = explode('=', $line, 2);
        if (count($parts) === 2) {
            $k = trim($parts[0]);
            $v = trim(trim($parts[1]), '"\'');
            if (str_contains($v, '#')) {
                $v = trim(substr($v, 0, strpos($v, '#')));
            }
            if ($k === 'DB_HOST') $dbHost = $v;
            if ($k === 'DB_PORT') $dbPort = $v;
            if ($k === 'DB_NAME') $dbName = $v;
            if ($k === 'DB_USER') $dbUser = $v;
            if ($k === 'DB_PASSWORD') $dbPass = $v;
        }
    }
}

if (!$useDefaults) {
    function prompt(string $label, string $default): string {
        echo "  {$label} [{$default}]: ";
        $handle = fopen("php://stdin", "r");
        $line = fgets($handle);
        $input = trim($line);
        return $input === '' ? $default : $input;
    }

    $dbHost = prompt("PostgreSQL Host", $dbHost);
    $dbPort = prompt("PostgreSQL Port (5432 or 5433)", $dbPort);
    $dbName = prompt("Target Database Name", $dbName);
    $dbUser = prompt("PostgreSQL User", $dbUser);
    $dbPass = prompt("PostgreSQL Password", $dbPass);
    echo "\n";
} else {
    echo "  Using defaults: host={$dbHost}, port={$dbPort}, dbname={$dbName}, user={$dbUser}\n\n";
}

// 4. Test Connection & Create Database
echo "[3/6] Connecting to PostgreSQL...\n";
try {
    $serverDsn = "pgsql:host={$dbHost};port={$dbPort};dbname=postgres";
    $serverPdo = new PDO($serverDsn, $dbUser, $dbPass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_TIMEOUT => 5
    ]);
    echo color("  [PASS] Connected to PostgreSQL server.\n", 'green');

    // Check if database exists
    $stmt = $serverPdo->prepare("SELECT 1 FROM pg_database WHERE datname = :dbname");
    $stmt->execute([':dbname' => $dbName]);
    $exists = (bool)$stmt->fetchColumn();

    if (!$exists) {
        echo "  [INFO] Database '{$dbName}' does not exist. Creating now...\n";
        $safeDb = preg_replace('/[^a-zA-Z0-9_]/', '', $dbName);
        $serverPdo->exec("CREATE DATABASE {$safeDb}");
        echo color("  [PASS] Database '{$dbName}' created.\n\n", 'green');
    } else {
        echo color("  [PASS] Database '{$dbName}' already exists.\n\n", 'green');
    }
} catch (PDOException $e) {
    echo color("  [FAIL] Could not connect to PostgreSQL: " . $e->getMessage() . "\n", 'red');
    echo "  Please check your PostgreSQL password, port, and make sure the PostgreSQL service is running.\n\n";
    exit(1);
}

// 5. Connect to Target Database & Run SQL Scripts
echo "[4/6] Initializing Schema, Seeds, and Roles...\n";
try {
    $targetDsn = "pgsql:host={$dbHost};port={$dbPort};dbname={$dbName}";
    $targetPdo = new PDO($targetDsn, $dbUser, $dbPass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_TIMEOUT => 5
    ]);

    // Run 01_schema.sql
    $schemaFile = $projectRoot . '/database/01_schema.sql';
    if (file_exists($schemaFile)) {
        echo "  - Running database/01_schema.sql (9 tables, checks & indexes)...\n";
        $sql = file_get_contents($schemaFile);
        $targetPdo->exec($sql);
        echo color("    [OK] Tables and constraints created.\n", 'green');
    }

    // Run 02_seed.sql
    $seedFile = $projectRoot . '/database/02_seed.sql';
    if (file_exists($seedFile)) {
        echo "  - Running database/02_seed.sql (populating demo users & 16 reports)...\n";
        $sql = file_get_contents($seedFile);
        $targetPdo->exec($sql);
        echo color("    [OK] Seed records inserted.\n", 'green');
    }

    // Run 03_roles_and_privileges.sql
    $rolesFile = $projectRoot . '/database/03_roles_and_privileges.sql';
    if (file_exists($rolesFile)) {
        echo "  - Running database/03_roles_and_privileges.sql...\n";
        $sql = file_get_contents($rolesFile);
        try {
            $targetPdo->exec($sql);
            echo color("    [OK] Least-privilege roles configured.\n\n", 'green');
        } catch (Exception $e) {
            echo color("    [INFO] Roles notice: " . $e->getMessage() . "\n\n", 'yellow');
        }
    }
} catch (PDOException $e) {
    echo color("  [FAIL] Error executing SQL scripts: " . $e->getMessage() . "\n", 'red');
    exit(1);
}

// 6. Setup Upload Directories and Sample Images
echo "[5/6] Generating Demo Attachments & Assets...\n";
$publicUploads = $projectRoot . '/public/uploads';
$rootUploads = $projectRoot . '/uploads';
if (!is_dir($publicUploads)) @mkdir($publicUploads, 0755, true);
if (!is_dir($rootUploads)) @mkdir($rootUploads, 0755, true);

if (extension_loaded('gd')) {
    $sampleImages = [
        'exposed_cable_photo.jpg' => ['title' => 'Report #1: Exposed Cables', 'sub' => 'Science Lab 204'],
        'oil_spill_cnc.jpg' => ['title' => 'Report #3: Machine Oil Puddle', 'sub' => 'Engineering Wing'],
        'ceiling_leak_bulge.png' => ['title' => 'Report #4: Ceiling Plaster Bulge', 'sub' => 'Central Library'],
        'jammed_exit_door.jpg' => ['title' => 'Report #7: Blocked Exit Door', 'sub' => 'Fine Arts Hall'],
        'discharged_extinguisher.jpg' => ['title' => 'Report #11: Discharged Extinguisher', 'sub' => 'Student Center'],
    ];

    foreach ($sampleImages as $imgName => $meta) {
        $w = 640; $h = 400;
        $im = imagecreatetruecolor($w, $h);
        $bg = imagecolorallocate($im, 15, 23, 42);
        $card = imagecolorallocate($im, 30, 41, 59);
        $amber = imagecolorallocate($im, 245, 158, 11);
        $text = imagecolorallocate($im, 248, 250, 252);
        $sub = imagecolorallocate($im, 148, 163, 184);

        imagefilledrectangle($im, 0, 0, $w, $h, $bg);
        imagefilledrectangle($im, 25, 25, $w - 25, $h - 25, $card);
        imagefilledrectangle($im, 45, 45, 220, 80, $amber);
        $dark = imagecolorallocate($im, 15, 23, 42);
        imagestring($im, 5, 55, 55, "[!] CAMPUS HAZARD", $dark);
        imagestring($im, 5, 45, 110, $meta['title'], $text);
        imagestring($im, 4, 45, 145, $meta['sub'], $sub);
        imagerectangle($im, 45, 180, $w - 45, $h - 45, imagecolorallocate($im, 51, 65, 85));
        imagestring($im, 4, 65, 220, "EVIDENCE INSPECTION PHOTO - VERIFIED INCIDENT", $text);
        imagestring($im, 3, 65, 260, "Archived under COMP 018 Safety Administration", $sub);

        foreach ([$publicUploads . '/' . $imgName, $rootUploads . '/' . $imgName] as $dest) {
            if (str_ends_with($imgName, '.png')) {
                imagepng($im, $dest);
            } else {
                imagejpeg($im, $dest, 85);
            }
        }
    }
    echo color("  [PASS] Sample hazard evidence photos generated.\n\n", 'green');
} else {
    echo color("  [INFO] GD extension not enabled; skipping photo synthesis.\n\n", 'yellow');
}

// 7. Write .env Configuration
echo "[6/6] Writing .env Configuration File...\n";
$envContent = "# CampusSafe Local Environment Configuration\n";
$envContent .= "APP_NAME=\"CampusSafe\"\n";
$envContent .= "APP_ENV=local\n";
$envContent .= "APP_DEBUG=true\n";
$envContent .= "APP_URL=\"http://localhost:8000\"\n\n";
$envContent .= "# Database Connection Settings\n";
$envContent .= "DB_HOST={$dbHost}\n";
$envContent .= "DB_PORT={$dbPort}\n";
$envContent .= "DB_NAME={$dbName}\n";
$envContent .= "DB_USER={$dbUser}\n";
$envContent .= "DB_PASSWORD=\"" . addcslashes($dbPass, '"\\$') . "\"\n\n";
$envContent .= "# File Upload Configuration\n";
$envContent .= "UPLOAD_DIR=uploads\n";
$envContent .= "MAX_UPLOAD_SIZE_MB=5\n\n";
$envContent .= "# Demo Accounts Default Password\n";
$envContent .= "DEMO_PASSWORD=Password123!\n";

file_put_contents($envPath, $envContent);
echo color("  [PASS] Saved database credentials to .env\n\n", 'green');

echo "=================================================================\n";
echo color("  🎉 INSTALLATION COMPLETE! CampusSafe is ready to use.\n", 'green');
echo "=================================================================\n\n";
echo "Demo Accounts Available (Password for all: Password123!)\n";
echo "  - Administrator: demo_admin\n";
echo "  - Maintenance:   demo_maint1\n";
echo "  - Student:       demo_student\n";
echo "  - Auditor:       demo_auditor\n\n";
echo "To run the application, double-click start.bat or execute:\n";
echo "  php -S localhost:8000 -t public\n\n";

exit(0);
