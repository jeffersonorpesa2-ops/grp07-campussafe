<?php
/**
 * CampusSafe: Dynamic User Seeding Utility
 * 
 * Generates fresh bcrypt password hashes based on DEMO_PASSWORD from .env
 * and populates or updates app_user demo accounts in the database.
 * 
 * Usage:
 *   php database/seed_users.php
 */

require_once __DIR__ . '/../src/config/Env.php';
require_once __DIR__ . '/../src/config/Database.php';

Env::load(__DIR__ . '/../.env');

$demoPassword = Env::get('DEMO_PASSWORD', 'Password123!');
$hash = password_hash($demoPassword, PASSWORD_DEFAULT);

echo "========================================================\n";
echo " CampusSafe - Dynamic User Seeder\n";
echo "========================================================\n";
echo "Using DEMO_PASSWORD : {$demoPassword}\n";
echo "Generated Hash      : {$hash}\n\n";

try {
    $pdo = Database::getConnection();

    $users = [
        [
            'role_id' => 4, // Administrator
            'full_name' => 'Eleanor Vance (Admin)',
            'email' => 'admin@campussafe.edu',
            'username' => 'demo_admin',
            'status' => 'active'
        ],
        [
            'role_id' => 3, // Maintenance
            'full_name' => 'Alex Davis (Senior Tech)',
            'email' => 'davis@campussafe.edu',
            'username' => 'demo_maint1',
            'status' => 'active'
        ],
        [
            'role_id' => 3, // Maintenance
            'full_name' => 'Carlos Reyes (Electrician)',
            'email' => 'reyes@campussafe.edu',
            'username' => 'demo_maint2',
            'status' => 'active'
        ],
        [
            'role_id' => 1, // Student
            'full_name' => 'Maria Santos (Student)',
            'email' => 'santos@campussafe.edu',
            'username' => 'demo_student',
            'status' => 'active'
        ],
        [
            'role_id' => 2, // Faculty/Staff
            'full_name' => 'Dr. Robert Hernandez (Faculty)',
            'email' => 'hernandez@campussafe.edu',
            'username' => 'demo_faculty',
            'status' => 'active'
        ],
        [
            'role_id' => 5, // Auditor
            'full_name' => 'Grace Kim (Safety Auditor)',
            'email' => 'kim@campussafe.edu',
            'username' => 'demo_auditor',
            'status' => 'active'
        ]
    ];

    $checkStmt = $pdo->prepare("SELECT user_id FROM app_user WHERE username = ?");
    $updateStmt = $pdo->prepare("UPDATE app_user SET password_hash = ?, account_status = 'active' WHERE user_id = ?");
    $insertStmt = $pdo->prepare("INSERT INTO app_user (role_id, full_name, email, username, password_hash, account_status) VALUES (?, ?, ?, ?, ?, ?)");

    foreach ($users as $u) {
        $checkStmt->execute([$u['username']]);
        $existing = $checkStmt->fetchColumn();

        if ($existing) {
            $updateStmt->execute([$hash, $existing]);
            echo "[UPDATED] {$u['username']} ({$u['full_name']}) - Password reset.\n";
        } else {
            $insertStmt->execute([
                $u['role_id'],
                $u['full_name'],
                $u['email'],
                $u['username'],
                $hash,
                $u['status']
            ]);
            echo "[INSERTED] {$u['username']} ({$u['full_name']}) created.\n";
        }
    }

    echo "\nAll demo user accounts are successfully configured!\n";
    echo "Login credentials for all demo accounts:\n";
    echo "  Password: {$demoPassword}\n";
    echo "========================================================\n";

} catch (Exception $e) {
    echo "[ERROR] Database seeding failed: " . $e->getMessage() . "\n";
    echo "Please ensure PostgreSQL is running and .env credentials are correct.\n";
    exit(1);
}
