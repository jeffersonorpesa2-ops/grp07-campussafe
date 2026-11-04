<?php
/**
 * CampusSafe: 1-Click Graphical Web Installer
 * 
 * Allows students and evaluators to configure, create, and seed the entire database
 * through a browser interface without manual terminal commands.
 */

$projectRoot = dirname(__DIR__);
$envPath = $projectRoot . '/.env';
$envExamplePath = $projectRoot . '/.env.example';

// Check system requirements
$reqs = [
    'PHP Version >= 8.2' => [
        'passed' => version_compare(PHP_VERSION, '8.2.0', '>='),
        'current' => PHP_VERSION,
        'help' => 'Please use PHP 8.2 or higher.'
    ],
    'PDO Extension' => [
        'passed' => extension_loaded('pdo'),
        'current' => extension_loaded('pdo') ? 'Enabled' : 'Missing',
        'help' => 'Enable extension=pdo in php.ini.'
    ],
    'PostgreSQL PDO Driver (pdo_pgsql)' => [
        'passed' => extension_loaded('pdo_pgsql'),
        'current' => extension_loaded('pdo_pgsql') ? 'Enabled' : 'Missing',
        'help' => 'Uncomment extension=pdo_pgsql in your php.ini file.'
    ],
    'PostgreSQL Extension (pgsql)' => [
        'passed' => extension_loaded('pgsql'),
        'current' => extension_loaded('pgsql') ? 'Enabled' : 'Missing',
        'help' => 'Uncomment extension=pgsql in your php.ini file.'
    ],
    'File Uploads Directory' => [
        'passed' => is_writable($projectRoot) || is_writable($projectRoot . '/uploads'),
        'current' => is_writable($projectRoot . '/uploads') ? 'Writable' : 'Needs Write Access',
        'help' => 'Ensure the project folder and uploads/ have write permissions.'
    ],
];

$allReqsPassed = true;
foreach ($reqs as $r) {
    if (!$r['passed']) {
        $allReqsPassed = false;
        break;
    }
}

// Load existing values from .env if present
$defaultHost = 'localhost';
$defaultPort = '5432';
$defaultDbName = 'grp07_campussafedb';
$defaultUser = 'postgres';
$defaultPass = 'postgres';

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
            if ($k === 'DB_HOST') $defaultHost = $v;
            if ($k === 'DB_PORT') $defaultPort = $v;
            if ($k === 'DB_NAME') $defaultDbName = $v;
            if ($k === 'DB_USER') $defaultUser = $v;
            if ($k === 'DB_PASSWORD') $defaultPass = $v;
        }
    }
}

$installLogs = [];
$installSuccess = false;
$errorMessage = null;
$iniNotice = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['fix_php_ini'])) {
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
        $iniContent = file_get_contents($iniFile);
        $modified = false;

        if (stripos($iniContent, 'extension_dir') === false || preg_match('/;extension_dir\s*=\s*"ext"/', $iniContent)) {
            $iniContent = preg_replace('/;extension_dir\s*=\s*"ext"/', 'extension_dir = "ext"', $iniContent, 1);
            $modified = true;
        }

        foreach (['pdo_pgsql', 'pgsql', 'gd', 'fileinfo'] as $extName) {
            $pattern = '/;extension\s*=\s*' . preg_quote($extName, '/') . '/i';
            if (preg_match($pattern, $iniContent)) {
                $iniContent = preg_replace($pattern, 'extension=' . $extName, $iniContent);
                $modified = true;
            }
        }

        if ($modified) {
            file_put_contents($iniFile, $iniContent);
            $iniNotice = "Successfully updated php.ini ({$iniFile})! Please restart your terminal/server (run start.bat) for changes to take effect.";
        } else {
            $iniNotice = "PostgreSQL extensions already appear to be uncommented in php.ini. Make sure PostgreSQL DLLs are in your PHP ext/ directory and restart the server.";
        }
    } else {
        $iniNotice = "Could not automatically write to php.ini at " . ($iniFile ?: 'unknown path') . ". Please open php.ini manually and uncomment extension=pdo_pgsql and extension=pgsql.";
    }
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['run_install'])) {
    $host = trim($_POST['db_host'] ?? 'localhost');
    $port = trim($_POST['db_port'] ?? '5432');
    $dbname = trim($_POST['db_name'] ?? 'grp07_campussafedb');
    $user = trim($_POST['db_user'] ?? 'postgres');
    $password = $_POST['db_password'] ?? '';
    $reseed = isset($_POST['reseed']);

    try {
        $installLogs[] = "Connecting to PostgreSQL server at {$host}:{$port}...";

        // Connect to maintenance database 'postgres' to check/create target database
        $serverDsn = "pgsql:host={$host};port={$port};dbname=postgres";
        $serverPdo = new PDO($serverDsn, $user, $password, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_TIMEOUT => 5
        ]);
        $installLogs[] = "✓ Successfully connected to PostgreSQL server.";

        // Check if target database exists
        $checkStmt = $serverPdo->prepare("SELECT 1 FROM pg_database WHERE datname = :dbname");
        $checkStmt->execute([':dbname' => $dbname]);
        $dbExists = (bool)$checkStmt->fetchColumn();

        if (!$dbExists) {
            $installLogs[] = "Database '{$dbname}' does not exist. Creating database...";
            // PostgreSQL does not allow CREATE DATABASE inside a prepared statement
            $safeDbName = preg_replace('/[^a-zA-Z0-9_]/', '', $dbname);
            $serverPdo->exec("CREATE DATABASE {$safeDbName}");
            $installLogs[] = "✓ Database '{$dbname}' created successfully.";
        } else {
            $installLogs[] = "✓ Database '{$dbname}' already exists.";
        }

        // Connect directly to target database
        $targetDsn = "pgsql:host={$host};port={$port};dbname={$dbname}";
        $targetPdo = new PDO($targetDsn, $user, $password, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_TIMEOUT => 5
        ]);
        $installLogs[] = "✓ Connected to '{$dbname}'.";

        // Execute 01_schema.sql
        $schemaFile = $projectRoot . '/database/01_schema.sql';
        if (file_exists($schemaFile)) {
            $installLogs[] = "Running 01_schema.sql (creating 9 relational tables, checks & indexes)...";
            $sql = file_get_contents($schemaFile);
            $targetPdo->exec($sql);
            $installLogs[] = "✓ Tables, constraints, and performance indexes created.";
        }

        // Execute 02_seed.sql
        $seedFile = $projectRoot . '/database/02_seed.sql';
        if (file_exists($seedFile)) {
            $installLogs[] = "Running 02_seed.sql (populating demo users, locations, categories & reports)...";
            $sql = file_get_contents($seedFile);
            $targetPdo->exec($sql);
            $installLogs[] = "✓ Seed data successfully inserted (16 reports across all 6 lifecycle stages).";
        }

        // Execute 03_roles_and_privileges.sql
        $rolesFile = $projectRoot . '/database/03_roles_and_privileges.sql';
        if (file_exists($rolesFile)) {
            $installLogs[] = "Running 03_roles_and_privileges.sql (configuring Activity 4 least-privilege roles)...";
            $sql = file_get_contents($rolesFile);
            try {
                $targetPdo->exec($sql);
                $installLogs[] = "✓ Group roles (app_runtime_grp, app_readonly_grp, app_backup_grp) configured.";
            } catch (Exception $e) {
                // Roles might already exist or require superuser privileges
                $installLogs[] = "ℹ Role privileges notice: " . $e->getMessage();
            }
        }

        // Setup uploads directory & sample images
        $publicUploads = $projectRoot . '/public/uploads';
        $rootUploads = $projectRoot . '/uploads';
        if (!is_dir($publicUploads)) @mkdir($publicUploads, 0755, true);
        if (!is_dir($rootUploads)) @mkdir($rootUploads, 0755, true);

        // Generate sample images if GD is available
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
            $installLogs[] = "✓ Sample evidence photos generated for demo reports.";
        }

        // Write configuration into .env file
        $envContent = "# CampusSafe Local Environment Configuration\n";
        $envContent .= "APP_NAME=\"CampusSafe\"\n";
        $envContent .= "APP_ENV=local\n";
        $envContent .= "APP_DEBUG=true\n";
        $envContent .= "APP_URL=\"http://localhost:8000\"\n\n";
        $envContent .= "# Database Connection Settings\n";
        $envContent .= "DB_HOST={$host}\n";
        $envContent .= "DB_PORT={$port}\n";
        $envContent .= "DB_NAME={$dbname}\n";
        $envContent .= "DB_USER={$user}\n";
        $envContent .= "DB_PASSWORD=\"" . addcslashes($password, '"\\$') . "\"\n\n";
        $envContent .= "# File Upload Configuration\n";
        $envContent .= "UPLOAD_DIR=uploads\n";
        $envContent .= "MAX_UPLOAD_SIZE_MB=5\n\n";
        $envContent .= "# Demo Accounts Default Password\n";
        $envContent .= "DEMO_PASSWORD=Password123!\n";

        file_put_contents($envPath, $envContent);
        $installLogs[] = "✓ Saved database credentials to .env file.";

        $installSuccess = true;
    } catch (Exception $e) {
        $errorMessage = $e->getMessage();
        $installLogs[] = "❌ Error: " . $e->getMessage();
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CampusSafe 1-Click Installation Wizard</title>
    <link rel="stylesheet" href="/assets/css/style.css">
    <style>
        body { background: #0f172a; color: #f8fafc; min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 2rem 1rem; }
        .wizard-card { background: #1e293b; border: 1px solid #334155; border-radius: 12px; max-width: 760px; width: 100%; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.5); overflow: hidden; }
        .wizard-header { background: linear-gradient(135deg, #1e3a8a, #0f172a); padding: 2rem; border-bottom: 1px solid #334155; text-align: center; }
        .wizard-body { padding: 2rem; }
        .check-item { display: flex; justify-content: space-between; align-items: center; padding: 0.65rem 0.85rem; border-radius: 6px; margin-bottom: 0.5rem; background: #0f172a; border: 1px solid #334155; font-size: 0.88rem; }
        .badge-pass { background: #065f46; color: #a7f3d0; padding: 0.2rem 0.55rem; border-radius: 4px; font-weight: 600; font-size: 0.75rem; }
        .badge-fail { background: #7f1d1d; color: #fecaca; padding: 0.2rem 0.55rem; border-radius: 4px; font-weight: 600; font-size: 0.75rem; }
        .log-box { background: #090d16; border: 1px solid #1e293b; padding: 1rem; border-radius: 6px; font-family: monospace; font-size: 0.82rem; color: #38bdf8; max-height: 200px; overflow-y: auto; margin: 1.5rem 0; line-height: 1.5; }
        .account-box { background: #0f172a; border: 1px dashed #38bdf8; border-radius: 8px; padding: 1rem; margin-top: 1.5rem; }
        .btn-install { width: 100%; padding: 0.85rem; background: #2563eb; color: #fff; font-size: 1rem; font-weight: 600; border-radius: 6px; border: none; cursor: pointer; transition: background 0.15s ease; }
        .btn-install:hover { background: #1d4ed8; }
        .btn-launch { display: block; text-align: center; width: 100%; padding: 0.85rem; background: #10b981; color: #fff; font-size: 1rem; font-weight: 700; border-radius: 6px; text-decoration: none; transition: background 0.15s ease; }
        .btn-launch:hover { background: #059669; }
    </style>
</head>
<body>

<div class="wizard-card">
    <div class="wizard-header">
        <span style="font-size: 2.5rem; display: block; margin-bottom: 0.5rem;">🛡️</span>
        <h1 style="font-size: 1.8rem; margin: 0; color: #f8fafc;">CampusSafe 1-Click Setup Wizard</h1>
        <p style="color: #94a3b8; font-size: 0.92rem; margin-top: 0.4rem;">
            Automatic database creation, table schema setup, seed records &amp; configuration.
        </p>
    </div>

    <div class="wizard-body">
        <?php if ($installSuccess): ?>
            <div style="background: #064e3b; border: 1px solid #059669; padding: 1.25rem; border-radius: 8px; margin-bottom: 1.5rem;">
                <h3 style="color: #a7f3d0; margin-top: 0; font-size: 1.2rem;">🎉 Installation Completed Successfully!</h3>
                <p style="color: #d1fae5; font-size: 0.9rem; margin-bottom: 0;">
                    Database <strong><?= htmlspecialchars($dbname) ?></strong> has been created, schema tables established, 16 sample hazard reports seeded, and connection saved to <code>.env</code>.
                </p>
            </div>

            <div class="log-box">
                <?php foreach ($installLogs as $log): ?>
                    <div><?= htmlspecialchars($log) ?></div>
                <?php endforeach; ?>
            </div>

            <div class="account-box">
                <span style="font-size: 0.8rem; font-weight: 700; text-transform: uppercase; color: #38bdf8; display: block; margin-bottom: 0.5rem;">
                    Default Demo Accounts (Password for all: <code>Password123!</code>)
                </span>
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; font-size: 0.85rem; color: #cbd5e1;">
                    <div>👑 <strong>Administrator:</strong> <code>demo_admin</code></div>
                    <div>🔧 <strong>Maintenance Lead:</strong> <code>demo_maint1</code></div>
                    <div>🎓 <strong>Student Reporter:</strong> <code>demo_student</code></div>
                    <div>📋 <strong>Safety Auditor:</strong> <code>demo_auditor</code></div>
                </div>
            </div>

            <div style="margin-top: 1.5rem;">
                <a href="/" class="btn-launch">Launch CampusSafe Portal &rarr;</a>
            </div>

        <?php else: ?>

            <!-- System Pre-Check -->
            <div style="margin-bottom: 1.5rem;">
                <h3 style="font-size: 1rem; color: #cbd5e1; margin-bottom: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em;">
                    1. System Environment Check
                </h3>
                <?php foreach ($reqs as $label => $info): ?>
                    <div class="check-item">
                        <span><?= htmlspecialchars($label) ?>: <code><?= htmlspecialchars($info['current']) ?></code></span>
                        <?php if ($info['passed']): ?>
                            <span class="badge-pass">PASS</span>
                        <?php else: ?>
                            <span class="badge-fail">MISSING</span>
                        <?php endif; ?>
                    </div>
                <?php endforeach; ?>
            </div>

            <?php if (!empty($iniNotice)): ?>
                <div style="background: #1e3a8a; border: 1px solid #3b82f6; padding: 1rem; border-radius: 8px; margin-bottom: 1.5rem; font-size: 0.88rem; color: #dbeafe;">
                    <?= htmlspecialchars($iniNotice) ?>
                </div>
            <?php endif; ?>

            <?php if (!$allReqsPassed): ?>
                <div style="background: #7f1d1d; border: 1px solid #ef4444; padding: 1rem; border-radius: 8px; margin-bottom: 1.5rem; font-size: 0.88rem;">
                    <strong>Notice:</strong> One or more requirements are missing. Please ensure PHP 8.2 has <code>extension=pdo_pgsql</code> enabled in your <code>php.ini</code> file before proceeding.
                    <?php if (!$reqs['PostgreSQL PDO Driver (pdo_pgsql)']['passed']): ?>
                        <form method="POST" action="/install.php" style="margin-top: 0.75rem;">
                            <button type="submit" name="fix_php_ini" style="background: #d97706; color: #fff; border: none; padding: 0.5rem 1rem; border-radius: 6px; cursor: pointer; font-weight: 600; font-size: 0.85rem;">
                                🔧 Attempt Auto-Enable in php.ini
                            </button>
                        </form>
                    <?php endif; ?>
                </div>
            <?php endif; ?>

            <?php if ($errorMessage): ?>
                <div style="background: #7f1d1d; border: 1px solid #ef4444; padding: 1rem; border-radius: 8px; margin-bottom: 1.5rem; font-size: 0.88rem;">
                    <strong>Connection Failed:</strong> <?= htmlspecialchars($errorMessage) ?>
                </div>
                <?php if (!empty($installLogs)): ?>
                    <div class="log-box">
                        <?php foreach ($installLogs as $log): ?>
                            <div><?= htmlspecialchars($log) ?></div>
                        <?php endforeach; ?>
                    </div>
                <?php endif; ?>
            <?php endif; ?>

            <!-- Installation Form -->
            <form method="POST" action="/install.php">
                <h3 style="font-size: 1rem; color: #cbd5e1; margin-bottom: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em;">
                    2. PostgreSQL Connection Details
                </h3>

                <div style="display: grid; grid-template-columns: 2fr 1fr; gap: 1rem; margin-bottom: 1rem;">
                    <div class="form-group">
                        <label class="form-label" style="color: #cbd5e1;">PostgreSQL Host</label>
                        <input type="text" name="db_host" class="form-control" style="background:#0f172a; border-color:#334155; color:#fff;"
                               value="<?= htmlspecialchars($_POST['db_host'] ?? $defaultHost) ?>" required>
                    </div>

                    <div class="form-group">
                        <label class="form-label" style="color: #cbd5e1;">Port (5432 or 5433)</label>
                        <input type="number" name="db_port" class="form-control" style="background:#0f172a; border-color:#334155; color:#fff;"
                               value="<?= htmlspecialchars($_POST['db_port'] ?? $defaultPort) ?>" required>
                    </div>
                </div>

                <div class="form-group" style="margin-bottom: 1rem;">
                    <label class="form-label" style="color: #cbd5e1;">Database Name</label>
                    <input type="text" name="db_name" class="form-control" style="background:#0f172a; border-color:#334155; color:#fff;"
                           value="<?= htmlspecialchars($_POST['db_name'] ?? $defaultDbName) ?>" required>
                    <small style="color: #94a3b8; font-size: 0.78rem;">Will be created automatically if it does not already exist.</small>
                </div>

                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 1.5rem;">
                    <div class="form-group">
                        <label class="form-label" style="color: #cbd5e1;">PostgreSQL User</label>
                        <input type="text" name="db_user" class="form-control" style="background:#0f172a; border-color:#334155; color:#fff;"
                               value="<?= htmlspecialchars($_POST['db_user'] ?? $defaultUser) ?>" required>
                    </div>

                    <div class="form-group">
                        <label class="form-label" style="color: #cbd5e1;">PostgreSQL Password</label>
                        <input type="password" name="db_password" class="form-control" style="background:#0f172a; border-color:#334155; color:#fff;"
                               value="<?= htmlspecialchars($_POST['db_password'] ?? $defaultPass) ?>" placeholder="e.g. postgres">
                    </div>
                </div>

                <button type="submit" name="run_install" class="btn-install" <?= !$allReqsPassed ? 'disabled style="opacity:0.6; cursor:not-allowed;"' : '' ?>>
                    🚀 Run 1-Click Installation &amp; Seed Database
                </button>
            </form>

        <?php endif; ?>
    </div>
</div>

</body>
</html>
