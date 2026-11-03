<?php
/**
 * CampusSafe: User Model
 */

require_once __DIR__ . '/../config/Database.php';

class User
{
    public static function findById(int $userId): ?array
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("
            SELECT u.*, r.role_name
            FROM app_user u
            JOIN role r ON u.role_id = r.role_id
            WHERE u.user_id = :id
            LIMIT 1
        ");
        $stmt->execute([':id' => $userId]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    public static function getAll(): array
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->query("
            SELECT u.user_id, u.role_id, r.role_name, u.full_name, u.email,
                   u.username, u.account_status, u.created_at
            FROM app_user u
            JOIN role r ON u.role_id = r.role_id
            ORDER BY u.user_id ASC
        ");
        return $stmt->fetchAll();
    }

    public static function getMaintenanceUsers(): array
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->query("
            SELECT u.user_id, u.full_name, u.email, u.username
            FROM app_user u
            JOIN role r ON u.role_id = r.role_id
            WHERE r.role_name = 'Maintenance' AND u.account_status = 'active'
            ORDER BY u.full_name ASC
        ");
        return $stmt->fetchAll();
    }

    public static function getAllRoles(): array
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->query("SELECT * FROM role ORDER BY role_id ASC");
        return $stmt->fetchAll();
    }

    public static function create(array $data): int
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("
            INSERT INTO app_user (role_id, full_name, email, username, password_hash, account_status)
            VALUES (:role_id, :full_name, :email, :username, :password_hash, :account_status)
            RETURNING user_id
        ");

        $stmt->execute([
            ':role_id'        => $data['role_id'],
            ':full_name'      => $data['full_name'],
            ':email'          => $data['email'],
            ':username'       => $data['username'],
            ':password_hash'  => password_hash($data['password'], PASSWORD_DEFAULT),
            ':account_status' => $data['account_status'] ?? 'active'
        ]);

        return (int)$stmt->fetchColumn();
    }

    public static function update(int $userId, array $data): bool
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("
            UPDATE app_user
            SET role_id = :role_id,
                full_name = :full_name,
                email = :email,
                account_status = :account_status
            WHERE user_id = :id
        ");

        return $stmt->execute([
            ':id'             => $userId,
            ':role_id'        => $data['role_id'],
            ':full_name'      => $data['full_name'],
            ':email'          => $data['email'],
            ':account_status' => $data['account_status']
        ]);
    }

    public static function setStatus(int $userId, string $status): bool
    {
        if (!in_array($status, ['active', 'inactive', 'suspended'], true)) {
            throw new InvalidArgumentException("Invalid account status: {$status}");
        }

        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("UPDATE app_user SET account_status = :status WHERE user_id = :id");
        return $stmt->execute([':status' => $status, ':id' => $userId]);
    }

    public static function changePassword(int $userId, string $newPassword): bool
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("UPDATE app_user SET password_hash = :hash WHERE user_id = :id");
        return $stmt->execute([
            ':hash' => password_hash($newPassword, PASSWORD_DEFAULT),
            ':id'   => $userId
        ]);
    }
}
