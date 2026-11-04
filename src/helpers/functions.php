<?php
/**
 * CampusSafe: Utility and Helper Functions
 */

require_once __DIR__ . '/../auth/Csrf.php';
require_once __DIR__ . '/../auth/Auth.php';

/**
 * Escape output for safe HTML rendering (prevents XSS)
 */
function e(?string $string): string
{
    return htmlspecialchars($string ?? '', ENT_QUOTES, 'UTF-8');
}

/**
 * Set or retrieve one-time flash messages
 */
function flash(string $key, ?string $message = null): ?string
{
    Auth::startSession();

    if ($message !== null) {
        $_SESSION['flash_' . $key] = $message;
        return null;
    }

    $sessionKey = 'flash_' . $key;
    if (isset($_SESSION[$sessionKey])) {
        $msg = $_SESSION[$sessionKey];
        unset($_SESSION[$sessionKey]);
        return $msg;
    }

    return null;
}

/**
 * Display flash alerts if present
 */
function renderFlashMessages(): string
{
    $html = '';
    $types = [
        'success' => 'alert-success',
        'error'   => 'alert-danger',
        'warning' => 'alert-warning',
        'info'    => 'alert-info'
    ];

    foreach ($types as $key => $cssClass) {
        $msg = flash($key);
        if ($msg) {
            $html .= '<div class="alert ' . $cssClass . ' alert-dismissible fade show" role="alert">';
            $html .= e($msg);
            $html .= '<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>';
            $html .= '</div>';
        }
    }

    return $html;
}

/**
 * Safely redirect to a URL
 */
function redirect(string $url): void
{
    header("Location: {$url}");
    exit;
}

/**
 * Resolve root-relative URL
 */
function url(string $path = ''): string
{
    $cleanPath = '/' . ltrim($path, '/');
    return $cleanPath;
}

/**
 * Format timestamp into readable string
 */
function formatDate(?string $timestamp, string $format = 'M d, Y h:i A'): string
{
    if (empty($timestamp)) {
        return '—';
    }
    try {
        $date = new DateTime($timestamp);
        return $date->format($format);
    } catch (Exception $e) {
        return e($timestamp);
    }
}

/**
 * Render visual status badge HTML
 */
function statusBadge(string $status): string
{
    $classes = [
        'Submitted'   => 'badge-status-submitted',
        'Verified'    => 'badge-status-verified',
        'Assigned'    => 'badge-status-assigned',
        'In Progress' => 'badge-status-in-progress',
        'Resolved'    => 'badge-status-resolved',
        'Closed'      => 'badge-status-closed',
    ];

    $badgeClass = $classes[$status] ?? 'badge-secondary';
    return '<span class="status-badge ' . $badgeClass . '">' . e($status) . '</span>';
}

/**
 * Render visual priority badge HTML
 */
function priorityBadge(?string $priority): string
{
    if (empty($priority)) {
        return '<span class="priority-badge badge-priority-unassigned">Pending Verification</span>';
    }

    $classes = [
        'Low'      => 'badge-priority-low',
        'Medium'   => 'badge-priority-medium',
        'High'     => 'badge-priority-high',
        'Critical' => 'badge-priority-critical',
    ];

    $badgeClass = $classes[$priority] ?? 'badge-secondary';
    return '<span class="priority-badge ' . $badgeClass . '">' . e($priority) . '</span>';
}

/**
 * Validate and handle uploaded file securely
 */
function handleFileUpload(array $fileArray, string $targetDir): ?array
{
    if (!isset($fileArray['error']) || $fileArray['error'] === UPLOAD_ERR_NO_FILE) {
        return null;
    }

    if ($fileArray['error'] !== UPLOAD_ERR_OK) {
        throw new Exception("File upload encountered error code: " . $fileArray['error']);
    }

    // Maximum file size: 5MB
    $maxBytes = 5 * 1024 * 1024;
    if ($fileArray['size'] > $maxBytes) {
        throw new Exception("Uploaded file exceeds 5MB size limit.");
    }

    // Verify MIME type using fileinfo
    $finfo = new finfo(FILEINFO_MIME_TYPE);
    $realMime = $finfo->file($fileArray['tmp_name']);

    $allowedMimes = [
        'image/jpeg'      => 'jpg',
        'image/png'       => 'png',
        'image/webp'      => 'webp',
        'application/pdf' => 'pdf'
    ];

    if (!array_key_exists($realMime, $allowedMimes)) {
        throw new Exception("Invalid file type ({$realMime}). Allowed types: JPG, PNG, WEBP, and PDF.");
    }

    $origName = basename($fileArray['name']);
    $ext = $allowedMimes[$realMime];

    // Resolve both public/uploads (for web serving) and root uploads (for archive)
    $projectRoot = dirname(__DIR__, 2);
    $rootUploadDir = $projectRoot . DIRECTORY_SEPARATOR . 'uploads';
    $publicUploadDir = $projectRoot . DIRECTORY_SEPARATOR . 'public' . DIRECTORY_SEPARATOR . 'uploads';

    if (!is_dir($rootUploadDir)) {
        mkdir($rootUploadDir, 0755, true);
    }
    if (!is_dir($publicUploadDir)) {
        mkdir($publicUploadDir, 0755, true);
    }

    // Generate random unguessable filename
    $uniqueName = 'hazard_' . bin2hex(random_bytes(8)) . '_' . time() . '.' . $ext;
    $publicDest = $publicUploadDir . DIRECTORY_SEPARATOR . $uniqueName;
    $rootDest = $rootUploadDir . DIRECTORY_SEPARATOR . $uniqueName;

    if (!move_uploaded_file($fileArray['tmp_name'], $publicDest)) {
        throw new Exception("Failed to move uploaded file to destination storage.");
    }
    // Also archive a copy in the root uploads folder
    copy($publicDest, $rootDest);

    return [
        'file_name'        => $origName,
        'file_path_or_url' => 'uploads/' . $uniqueName,
        'mime_type'        => $realMime
    ];
}
