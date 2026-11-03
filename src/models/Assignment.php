<?php
/**
 * CampusSafe: Assignment Model
 */

require_once __DIR__ . '/../config/Database.php';

class Assignment
{
    public static function create(int $reportId, int $maintenanceUserId, int $assignedByUserId): int
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("
            INSERT INTO assignment (report_id, maintenance_user_id, assigned_by_user_id, assignment_status)
            VALUES (:report_id, :maint_id, :assigned_by, 'Assigned')
            RETURNING assignment_id
        ");
        $stmt->execute([
            ':report_id'    => $reportId,
            ':maint_id'     => $maintenanceUserId,
            ':assigned_by'  => $assignedByUserId
        ]);
        return (int)$stmt->fetchColumn();
    }

    public static function getByReportId(int $reportId): ?array
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("
            SELECT a.*,
                   m.full_name AS maintenance_name,
                   m.email AS maintenance_email,
                   b.full_name AS assigned_by_name
            FROM assignment a
            JOIN app_user m ON a.maintenance_user_id = m.user_id
            JOIN app_user b ON a.assigned_by_user_id = b.user_id
            WHERE a.report_id = :report_id
            ORDER BY a.assigned_at DESC
            LIMIT 1
        ");
        $stmt->execute([':report_id' => $reportId]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    public static function getAssignedToUser(int $maintenanceUserId, ?string $statusFilter = null): array
    {
        $pdo = Database::getConnection();
        $sql = "
            SELECT a.*, r.description, r.priority, r.status AS report_status, r.submitted_at,
                   c.category_name, l.building, l.floor, l.room_area
            FROM assignment a
            JOIN hazard_report r ON a.report_id = r.report_id
            JOIN hazard_category c ON r.category_id = c.category_id
            JOIN campus_location l ON r.location_id = l.location_id
            WHERE a.maintenance_user_id = :user_id
        ";

        $params = [':user_id' => $maintenanceUserId];
        if (!empty($statusFilter)) {
            $sql .= " AND a.assignment_status = :status";
            $params[':status'] = $statusFilter;
        }

        $sql .= " ORDER BY a.assigned_at DESC";

        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }

    public static function updateStatus(int $reportId, string $status): bool
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("
            UPDATE assignment
            SET assignment_status = :status
            WHERE report_id = :report_id
        ");
        return $stmt->execute([
            ':status'    => $status,
            ':report_id' => $reportId
        ]);
    }
}
