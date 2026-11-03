<?php
/**
 * CampusSafe: Hazard Report Model
 * 
 * Handles core hazard reporting lifecycle, transactional status transitions,
 * search/filter querying, and statistical reporting.
 */

require_once __DIR__ . '/../config/Database.php';
require_once __DIR__ . '/Assignment.php';
require_once __DIR__ . '/MaintenanceAction.php';
require_once __DIR__ . '/Attachment.php';

class Report
{
    /**
     * Submit a new hazard report (Phase 3, Step 3)
     * Inserts hazard_report and initial status history in a single transaction.
     */
    public static function create(array $data, ?array $fileData = null): int
    {
        $pdo = Database::getConnection();
        $pdo->beginTransaction();

        try {
            $stmt = $pdo->prepare("
                INSERT INTO hazard_report (
                    reporter_user_id, location_id, category_id, description,
                    priority, status, submitted_at, verified_by_user_id, verified_at, resolved_at
                ) VALUES (
                    :reporter_id, :location_id, :category_id, :description,
                    NULL, 'Submitted', CURRENT_TIMESTAMP, NULL, NULL, NULL
                )
                RETURNING report_id
            ");

            $stmt->execute([
                ':reporter_id' => $data['reporter_user_id'],
                ':location_id' => $data['location_id'],
                ':category_id' => $data['category_id'],
                ':description' => trim($data['description']),
            ]);

            $reportId = (int)$stmt->fetchColumn();

            // Insert initial status history
            $histStmt = $pdo->prepare("
                INSERT INTO report_status_history (report_id, changed_by_user_id, status, notes)
                VALUES (:report_id, :user_id, 'Submitted', :notes)
            ");
            $histStmt->execute([
                ':report_id' => $reportId,
                ':user_id'   => $data['reporter_user_id'],
                ':notes'     => 'Initial hazard report filed by user.'
            ]);

            // Save attachment if provided
            if ($fileData !== null) {
                $attachStmt = $pdo->prepare("
                    INSERT INTO attachment (report_id, uploaded_by_user_id, file_name, file_path_or_url, mime_type)
                    VALUES (:report_id, :user_id, :file_name, :file_path, :mime_type)
                ");
                $attachStmt->execute([
                    ':report_id' => $reportId,
                    ':user_id'   => $data['reporter_user_id'],
                    ':file_name' => $fileData['file_name'],
                    ':file_path' => $fileData['file_path_or_url'],
                    ':mime_type' => $fileData['mime_type'] ?? null
                ]);
            }

            $pdo->commit();
            return $reportId;
        } catch (Exception $e) {
            $pdo->rollBack();
            throw $e;
        }
    }

    /**
     * Find a report with joined details
     */
    public static function findById(int $reportId): ?array
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("
            SELECT r.*,
                   u.full_name AS reporter_name,
                   u.email AS reporter_email,
                   u.username AS reporter_username,
                   c.category_name,
                   l.building,
                   l.floor,
                   l.room_area,
                   l.location_description,
                   v.full_name AS verifier_name,
                   m.full_name AS assigned_technician_name,
                   m.user_id AS assigned_technician_id,
                   a.assignment_status,
                   a.assigned_at
            FROM hazard_report r
            JOIN app_user u ON r.reporter_user_id = u.user_id
            JOIN hazard_category c ON r.category_id = c.category_id
            JOIN campus_location l ON r.location_id = l.location_id
            LEFT JOIN app_user v ON r.verified_by_user_id = v.user_id
            LEFT JOIN assignment a ON r.report_id = a.report_id
            LEFT JOIN app_user m ON a.maintenance_user_id = m.user_id
            WHERE r.report_id = :id
            LIMIT 1
        ");
        $stmt->execute([':id' => $reportId]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    /**
     * Search and filter reports
     */
    public static function getAll(array $filters = []): array
    {
        $pdo = Database::getConnection();

        $sql = "
            SELECT r.report_id, r.description, r.priority, r.status, r.submitted_at,
                   r.verified_at, r.resolved_at,
                   u.full_name AS reporter_name,
                   u.user_id AS reporter_user_id,
                   c.category_name,
                   l.building, l.floor, l.room_area,
                   m.full_name AS assigned_technician_name
            FROM hazard_report r
            JOIN app_user u ON r.reporter_user_id = u.user_id
            JOIN hazard_category c ON r.category_id = c.category_id
            JOIN campus_location l ON r.location_id = l.location_id
            LEFT JOIN assignment a ON r.report_id = a.report_id
            LEFT JOIN app_user m ON a.maintenance_user_id = m.user_id
            WHERE 1=1
        ";

        $params = [];

        // Filter: reporter (for student/faculty self-service)
        if (!empty($filters['reporter_user_id'])) {
            $sql .= " AND r.reporter_user_id = :reporter_id";
            $params[':reporter_id'] = $filters['reporter_user_id'];
        }

        // Filter: status
        if (!empty($filters['status'])) {
            $sql .= " AND r.status = :status";
            $params[':status'] = $filters['status'];
        }

        // Filter: category
        if (!empty($filters['category_id'])) {
            $sql .= " AND r.category_id = :category_id";
            $params[':category_id'] = $filters['category_id'];
        }

        // Filter: location
        if (!empty($filters['location_id'])) {
            $sql .= " AND r.location_id = :location_id";
            $params[':location_id'] = $filters['location_id'];
        }

        // Filter: priority
        if (!empty($filters['priority'])) {
            $sql .= " AND r.priority = :priority";
            $params[':priority'] = $filters['priority'];
        }

        // Filter: search keyword
        if (!empty($filters['search'])) {
            $sql .= " AND (
                LOWER(r.description) LIKE LOWER(:search) OR
                LOWER(l.building) LIKE LOWER(:search) OR
                LOWER(l.room_area) LIKE LOWER(:search) OR
                LOWER(c.category_name) LIKE LOWER(:search)
            )";
            $params[':search'] = '%' . trim($filters['search']) . '%';
        }

        // Filter: date range
        if (!empty($filters['date_from'])) {
            $sql .= " AND r.submitted_at >= :date_from";
            $params[':date_from'] = $filters['date_from'] . ' 00:00:00';
        }

        if (!empty($filters['date_to'])) {
            $sql .= " AND r.submitted_at <= :date_to";
            $params[':date_to'] = $filters['date_to'] . ' 23:59:59';
        }

        // Filter: assigned to specific maintenance technician
        if (!empty($filters['maintenance_user_id'])) {
            $sql .= " AND a.maintenance_user_id = :maint_id";
            $params[':maint_id'] = $filters['maintenance_user_id'];
        }

        $sql .= " ORDER BY r.submitted_at DESC";

        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }

    /**
     * Transition: Submitted -> Verified (Administrator)
     */
    public static function verify(int $reportId, int $adminUserId, string $priority, ?string $notes = null): bool
    {
        if (!in_array($priority, ['Low', 'Medium', 'High', 'Critical'], true)) {
            throw new InvalidArgumentException("Invalid priority value.");
        }

        $pdo = Database::getConnection();
        $pdo->beginTransaction();

        try {
            $checkStmt = $pdo->prepare("SELECT status FROM hazard_report WHERE report_id = :id FOR UPDATE");
            $checkStmt->execute([':id' => $reportId]);
            $currentStatus = $checkStmt->fetchColumn();

            if ($currentStatus !== 'Submitted') {
                throw new Exception("Only reports in 'Submitted' status can be verified. Current status: {$currentStatus}");
            }

            $updateStmt = $pdo->prepare("
                UPDATE hazard_report
                SET priority = :priority,
                    status = 'Verified',
                    verified_by_user_id = :admin_id,
                    verified_at = CURRENT_TIMESTAMP
                WHERE report_id = :id
            ");
            $updateStmt->execute([
                ':priority' => $priority,
                ':admin_id' => $adminUserId,
                ':id'       => $reportId
            ]);

            $histStmt = $pdo->prepare("
                INSERT INTO report_status_history (report_id, changed_by_user_id, status, notes)
                VALUES (:report_id, :admin_id, 'Verified', :notes)
            ");
            $noteText = 'Verified as ' . $priority . ' priority. ' . ($notes ? 'Notes: ' . trim($notes) : '');
            $histStmt->execute([
                ':report_id' => $reportId,
                ':admin_id'  => $adminUserId,
                ':notes'     => $noteText
            ]);

            $pdo->commit();
            return true;
        } catch (Exception $e) {
            $pdo->rollBack();
            throw $e;
        }
    }

    /**
     * Transition: Verified -> Assigned (Administrator)
     */
    public static function assign(int $reportId, int $adminUserId, int $maintenanceUserId, ?string $notes = null): bool
    {
        $pdo = Database::getConnection();
        $pdo->beginTransaction();

        try {
            $checkStmt = $pdo->prepare("SELECT status FROM hazard_report WHERE report_id = :id FOR UPDATE");
            $checkStmt->execute([':id' => $reportId]);
            $currentStatus = $checkStmt->fetchColumn();

            if ($currentStatus !== 'Verified') {
                throw new Exception("Reports must be 'Verified' before assignment. Current status: {$currentStatus}");
            }

            // Insert or update assignment record
            $assignStmt = $pdo->prepare("
                INSERT INTO assignment (report_id, maintenance_user_id, assigned_by_user_id, assignment_status)
                VALUES (:report_id, :maint_id, :admin_id, 'Assigned')
                ON CONFLICT (report_id, maintenance_user_id) 
                DO UPDATE SET assignment_status = 'Assigned', assigned_at = CURRENT_TIMESTAMP
            ");
            $assignStmt->execute([
                ':report_id' => $reportId,
                ':maint_id'  => $maintenanceUserId,
                ':admin_id'  => $adminUserId
            ]);

            // Update report status
            $updateStmt = $pdo->prepare("UPDATE hazard_report SET status = 'Assigned' WHERE report_id = :id");
            $updateStmt->execute([':id' => $reportId]);

            // Fetch technician name for history log
            $techStmt = $pdo->prepare("SELECT full_name FROM app_user WHERE user_id = :id");
            $techStmt->execute([':id' => $maintenanceUserId]);
            $techName = $techStmt->fetchColumn() ?: "Technician #{$maintenanceUserId}";

            // Insert status history
            $histStmt = $pdo->prepare("
                INSERT INTO report_status_history (report_id, changed_by_user_id, status, notes)
                VALUES (:report_id, :admin_id, 'Assigned', :notes)
            ");
            $noteText = "Assigned to {$techName}. " . ($notes ? 'Notes: ' . trim($notes) : '');
            $histStmt->execute([
                ':report_id' => $reportId,
                ':admin_id'  => $adminUserId,
                ':notes'     => $noteText
            ]);

            $pdo->commit();
            return true;
        } catch (Exception $e) {
            $pdo->rollBack();
            throw $e;
        }
    }

    /**
     * Transition: Assigned -> In Progress (Maintenance Technician)
     */
    public static function startProgress(int $reportId, int $maintenanceUserId, ?string $notes = null): bool
    {
        $pdo = Database::getConnection();
        $pdo->beginTransaction();

        try {
            $checkStmt = $pdo->prepare("SELECT status FROM hazard_report WHERE report_id = :id FOR UPDATE");
            $checkStmt->execute([':id' => $reportId]);
            $currentStatus = $checkStmt->fetchColumn();

            if (!in_array($currentStatus, ['Assigned', 'In Progress'], true)) {
                throw new Exception("Report cannot be transitioned to 'In Progress' from status '{$currentStatus}'.");
            }

            $updateStmt = $pdo->prepare("UPDATE hazard_report SET status = 'In Progress' WHERE report_id = :id");
            $updateStmt->execute([':id' => $reportId]);

            $assignStmt = $pdo->prepare("
                UPDATE assignment
                SET assignment_status = 'In Progress'
                WHERE report_id = :report_id AND maintenance_user_id = :maint_id
            ");
            $assignStmt->execute([
                ':report_id' => $reportId,
                ':maint_id'  => $maintenanceUserId
            ]);

            $histStmt = $pdo->prepare("
                INSERT INTO report_status_history (report_id, changed_by_user_id, status, notes)
                VALUES (:report_id, :user_id, 'In Progress', :notes)
            ");
            $noteText = 'Technician started inspection / repair work. ' . ($notes ? 'Notes: ' . trim($notes) : '');
            $histStmt->execute([
                ':report_id' => $reportId,
                ':user_id'   => $maintenanceUserId,
                ':notes'     => $noteText
            ]);

            $pdo->commit();
            return true;
        } catch (Exception $e) {
            $pdo->rollBack();
            throw $e;
        }
    }

    /**
     * Transition: In Progress -> Resolved (Maintenance Technician)
     * Enforces Business Rules 10 & 11:
     * - Records resolution action log
     * - Sets resolved_at timestamp
     * - Updates status to 'Resolved' and assignment to 'Completed'
     */
    public static function resolve(int $reportId, int $maintenanceUserId, string $actionDetails, ?string $notes = null): bool
    {
        if (empty(trim($actionDetails))) {
            throw new InvalidArgumentException("Resolution action details are required.");
        }

        $pdo = Database::getConnection();
        $pdo->beginTransaction();

        try {
            // Update report status and timestamp
            $updateStmt = $pdo->prepare("
                UPDATE hazard_report
                SET status = 'Resolved',
                    resolved_at = CURRENT_TIMESTAMP
                WHERE report_id = :id
            ");
            $updateStmt->execute([':id' => $reportId]);

            // Insert resolution action
            $actionStmt = $pdo->prepare("
                INSERT INTO maintenance_action (report_id, maintenance_user_id, action_details, is_resolution, notes)
                VALUES (:report_id, :user_id, :action_details, TRUE, :notes)
            ");
            $actionStmt->execute([
                ':report_id'      => $reportId,
                ':user_id'        => $maintenanceUserId,
                ':action_details' => trim($actionDetails),
                ':notes'          => $notes ? trim($notes) : null
            ]);

            // Update assignment status
            $assignStmt = $pdo->prepare("
                UPDATE assignment
                SET assignment_status = 'Completed'
                WHERE report_id = :report_id
            ");
            $assignStmt->execute([':report_id' => $reportId]);

            // Insert status history
            $histStmt = $pdo->prepare("
                INSERT INTO report_status_history (report_id, changed_by_user_id, status, notes)
                VALUES (:report_id, :user_id, 'Resolved', :notes)
            ");
            $histStmt->execute([
                ':report_id' => $reportId,
                ':user_id'   => $maintenanceUserId,
                ':notes'     => 'Hazard resolved: ' . trim($actionDetails)
            ]);

            $pdo->commit();
            return true;
        } catch (Exception $e) {
            $pdo->rollBack();
            throw $e;
        }
    }

    /**
     * Transition: Resolved -> Closed (Administrator)
     */
    public static function close(int $reportId, int $adminUserId, ?string $notes = null): bool
    {
        $pdo = Database::getConnection();
        $pdo->beginTransaction();

        try {
            $checkStmt = $pdo->prepare("SELECT status FROM hazard_report WHERE report_id = :id FOR UPDATE");
            $checkStmt->execute([':id' => $reportId]);
            $currentStatus = $checkStmt->fetchColumn();

            if ($currentStatus !== 'Resolved') {
                throw new Exception("Only 'Resolved' reports can be marked 'Closed'. Current status: {$currentStatus}");
            }

            $updateStmt = $pdo->prepare("UPDATE hazard_report SET status = 'Closed' WHERE report_id = :id");
            $updateStmt->execute([':id' => $reportId]);

            $histStmt = $pdo->prepare("
                INSERT INTO report_status_history (report_id, changed_by_user_id, status, notes)
                VALUES (:report_id, :admin_id, 'Closed', :notes)
            ");
            $noteText = 'Safety audit verified and report officially closed. ' . ($notes ? 'Notes: ' . trim($notes) : '');
            $histStmt->execute([
                ':report_id' => $reportId,
                ':admin_id'  => $adminUserId,
                ':notes'     => $noteText
            ]);

            $pdo->commit();
            return true;
        } catch (Exception $e) {
            $pdo->rollBack();
            throw $e;
        }
    }

    /**
     * Update report (only allowed while still 'Submitted')
     */
    public static function updatePending(int $reportId, int $userId, array $data): bool
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("
            UPDATE hazard_report
            SET location_id = :location_id,
                category_id = :category_id,
                description = :description
            WHERE report_id = :id AND reporter_user_id = :user_id AND status = 'Submitted'
        ");

        return $stmt->execute([
            ':location_id' => $data['location_id'],
            ':category_id' => $data['category_id'],
            ':description' => trim($data['description']),
            ':id'          => $reportId,
            ':user_id'     => $userId
        ]);
    }

    /**
     * Get status history timeline for a report
     */
    public static function getHistory(int $reportId): array
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("
            SELECT h.*, u.full_name AS changed_by_name, r.role_name
            FROM report_status_history h
            JOIN app_user u ON h.changed_by_user_id = u.user_id
            JOIN role r ON u.role_id = r.role_id
            WHERE h.report_id = :report_id
            ORDER BY h.changed_at ASC
        ");
        $stmt->execute([':report_id' => $reportId]);
        return $stmt->fetchAll();
    }

    /**
     * System statistics & analytics for dashboard
     */
    public static function getStatistics(): array
    {
        $pdo = Database::getConnection();

        // Status counts
        $statusCounts = $pdo->query("
            SELECT status, COUNT(*) AS count
            FROM hazard_report
            GROUP BY status
        ")->fetchAll(PDO::FETCH_KEY_PAIR);

        // Priority counts
        $priorityCounts = $pdo->query("
            SELECT COALESCE(priority, 'Unassigned') AS priority, COUNT(*) AS count
            FROM hazard_report
            GROUP BY priority
        ")->fetchAll(PDO::FETCH_KEY_PAIR);

        // Category counts
        $categoryCounts = $pdo->query("
            SELECT c.category_name, COUNT(r.report_id) AS count
            FROM hazard_category c
            LEFT JOIN hazard_report r ON c.category_id = r.category_id
            GROUP BY c.category_name
            ORDER BY count DESC
        ")->fetchAll();

        // Location counts
        $locationCounts = $pdo->query("
            SELECT l.building, COUNT(r.report_id) AS count
            FROM campus_location l
            LEFT JOIN hazard_report r ON l.location_id = r.location_id
            GROUP BY l.building
            ORDER BY count DESC
        ")->fetchAll();

        // Total reports
        $totalReports = (int)$pdo->query("SELECT COUNT(*) FROM hazard_report")->fetchColumn();

        return [
            'total_reports'   => $totalReports,
            'by_status'       => $statusCounts,
            'by_priority'     => $priorityCounts,
            'by_category'     => $categoryCounts,
            'by_location'     => $locationCounts,
        ];
    }
}
