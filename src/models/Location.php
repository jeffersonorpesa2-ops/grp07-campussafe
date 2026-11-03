<?php
/**
 * CampusSafe: Campus Location Model
 */

require_once __DIR__ . '/../config/Database.php';

class Location
{
    public static function getAll(bool $activeOnly = false): array
    {
        $pdo = Database::getConnection();
        $sql = "SELECT * FROM campus_location";
        if ($activeOnly) {
            $sql .= " WHERE is_active = TRUE";
        }
        $sql .= " ORDER BY building ASC, floor ASC, room_area ASC";

        return $pdo->query($sql)->fetchAll();
    }

    public static function findById(int $locationId): ?array
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("SELECT * FROM campus_location WHERE location_id = :id LIMIT 1");
        $stmt->execute([':id' => $locationId]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    public static function create(array $data): int
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("
            INSERT INTO campus_location (building, floor, room_area, location_description, is_active)
            VALUES (:building, :floor, :room_area, :description, :is_active)
            RETURNING location_id
        ");
        $stmt->execute([
            ':building'    => $data['building'],
            ':floor'       => $data['floor'] ?? null,
            ':room_area'   => $data['room_area'],
            ':description' => $data['location_description'] ?? null,
            ':is_active'   => !empty($data['is_active']) ? 'TRUE' : 'FALSE'
        ]);
        return (int)$stmt->fetchColumn();
    }

    public static function update(int $locationId, array $data): bool
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("
            UPDATE campus_location
            SET building = :building,
                floor = :floor,
                room_area = :room_area,
                location_description = :description,
                is_active = :is_active
            WHERE location_id = :id
        ");
        return $stmt->execute([
            ':building'    => $data['building'],
            ':floor'       => $data['floor'] ?? null,
            ':room_area'   => $data['room_area'],
            ':description' => $data['location_description'] ?? null,
            ':is_active'   => !empty($data['is_active']) ? 'TRUE' : 'FALSE',
            ':id'          => $locationId
        ]);
    }

    public static function toggleActive(int $locationId): bool
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("UPDATE campus_location SET is_active = NOT is_active WHERE location_id = :id");
        return $stmt->execute([':id' => $locationId]);
    }
}
