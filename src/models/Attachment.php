<?php
/**
 * CampusSafe: Attachment Model
 */

require_once __DIR__ . '/../config/Database.php';

class Attachment
{
    public static function create(int $reportId, int $userId, string $fileName, string $filePath, ?string $mimeType): int
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("
            INSERT INTO attachment (report_id, uploaded_by_user_id, file_name, file_path_or_url, mime_type)
            VALUES (:report_id, :user_id, :file_name, :file_path, :mime_type)
            RETURNING attachment_id
        ");
        $stmt->execute([
            ':report_id'  => $reportId,
            ':user_id'    => $userId,
            ':file_name'  => $fileName,
            ':file_path'  => $filePath,
            ':mime_type'  => $mimeType
        ]);
        return (int)$stmt->fetchColumn();
    }

    public static function getByReportId(int $reportId): array
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("
            SELECT a.*, u.full_name AS uploaded_by_name
            FROM attachment a
            JOIN app_user u ON a.uploaded_by_user_id = u.user_id
            WHERE a.report_id = :report_id
            ORDER BY a.uploaded_at ASC
        ");
        $stmt->execute([':report_id' => $reportId]);
        return $stmt->fetchAll();
    }

    public static function findById(int $attachmentId): ?array
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("
            SELECT a.*, u.full_name AS uploaded_by_name
            FROM attachment a
            JOIN app_user u ON a.uploaded_by_user_id = u.user_id
            WHERE a.attachment_id = :id
            LIMIT 1
        ");
        $stmt->execute([':id' => $attachmentId]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    public static function delete(int $attachmentId): bool
    {
        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("DELETE FROM attachment WHERE attachment_id = :id");
        return $stmt->execute([':id' => $attachmentId]);
    }
}
