<?php
/**
 * CampusSafe: Maintenance Action Model
 */

require_once __DIR__ . '/../config/Database.php';

class MaintenanceAction
{
    public static function create(int $reportId, int $maintenanceUserId, string $actionDetails, bool $isResolution = false, ?string $notes = null): int
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("
            INSERT INTO maintenance_action (report_id, maintenance_user_id, action_details, is_resolution, notes)
            VALUES (:report_id, :user_id, :action_details, :is_resolution, :notes)
            RETURNING action_id
        ");
        $stmt->execute([
            ':report_id'      => $reportId,
            ':user_id'        => $maintenanceUserId,
            ':action_details' => $actionDetails,
            ':is_resolution'  => $isResolution ? 'TRUE' : 'FALSE',
            ':notes'          => $notes
        ]);
        return (int)$stmt->fetchColumn();
    }

    public static function getByReportId(int $reportId): array
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("
            SELECT m.*, u.full_name AS technician_name
            FROM maintenance_action m
            JOIN app_user u ON m.maintenance_user_id = u.user_id
            WHERE m.report_id = :report_id
            ORDER BY m.action_date ASC
        ");
        $stmt->execute([':report_id' => $reportId]);
        return $stmt->fetchAll();
    }
}
