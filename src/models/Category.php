<?php
/**
 * CampusSafe: Hazard Category Model
 */

require_once __DIR__ . '/../config/Database.php';

class Category
{
    public static function getAll(bool $activeOnly = false): array
    {
        $pdo = Database::getConnection();
        $sql = "SELECT * FROM hazard_category";
        if ($activeOnly) {
            $sql .= " WHERE is_active = TRUE";
        }
        $sql .= " ORDER BY category_name ASC";

        return $pdo->query($sql)->fetchAll();
    }

    public static function findById(int $categoryId): ?array
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("SELECT * FROM hazard_category WHERE category_id = :id LIMIT 1");
        $stmt->execute([':id' => $categoryId]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    public static function create(array $data): int
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("
            INSERT INTO hazard_category (category_name, description, is_active)
            VALUES (:name, :description, :is_active)
            RETURNING category_id
        ");
        $stmt->execute([
            ':name'        => $data['category_name'],
            ':description' => $data['description'] ?? null,
            ':is_active'   => !empty($data['is_active']) ? 'TRUE' : 'FALSE'
        ]);
        return (int)$stmt->fetchColumn();
    }

    public static function update(int $categoryId, array $data): bool
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("
            UPDATE hazard_category
            SET category_name = :name,
                description   = :description,
                is_active     = :is_active
            WHERE category_id = :id
        ");
        return $stmt->execute([
            ':name'        => $data['category_name'],
            ':description' => $data['description'] ?? null,
            ':is_active'   => !empty($data['is_active']) ? 'TRUE' : 'FALSE',
            ':id'          => $categoryId
        ]);
    }

    public static function toggleActive(int $categoryId): bool
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("UPDATE hazard_category SET is_active = NOT is_active WHERE category_id = :id");
        return $stmt->execute([':id' => $categoryId]);
    }
}
