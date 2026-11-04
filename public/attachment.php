<?php
/**
 * CampusSafe: Secure Attachment Viewer & Downloader
 * 
 * Safely resolves, streams, and downloads report evidence attachments.
 * Prevents directory traversal attacks and provides graceful SVG fallbacks.
 */

require_once __DIR__ . '/../src/config/Database.php';
require_once __DIR__ . '/../src/models/Attachment.php';
require_once __DIR__ . '/../src/auth/Auth.php';

Auth::startSession();

$attachmentId = (int)($_GET['id'] ?? 0);
$requestedFile = trim($_GET['file'] ?? '');
$isDownload = isset($_GET['download']) && $_GET['download'] === '1';

$attachment = null;
if ($attachmentId > 0) {
    $attachment = Attachment::findById($attachmentId);
}

// Security: Prevent directory traversal
$sanitizedFileName = null;
if ($attachment) {
    $sanitizedFileName = basename($attachment['file_path_or_url']);
} elseif (!empty($requestedFile)) {
    $sanitizedFileName = basename($requestedFile);
}

if (!$sanitizedFileName) {
    http_response_code(400);
    die("Invalid attachment request.");
}

// Locate file in public/uploads or root uploads
$publicPath = __DIR__ . DIRECTORY_SEPARATOR . 'uploads' . DIRECTORY_SEPARATOR . $sanitizedFileName;
$rootPath = dirname(__DIR__) . DIRECTORY_SEPARATOR . 'uploads' . DIRECTORY_SEPARATOR . $sanitizedFileName;

$filePath = null;
if (file_exists($publicPath)) {
    $filePath = $publicPath;
} elseif (file_exists($rootPath)) {
    $filePath = $rootPath;
    // Mirror to public/uploads for direct web serving
    @copy($rootPath, $publicPath);
}

// Determine MIME type
$mimeType = $attachment['mime_type'] ?? null;
if ($filePath && file_exists($filePath)) {
    if (empty($mimeType) && function_exists('finfo_open')) {
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mimeType = finfo_file($finfo, $filePath);
        finfo_close($finfo);
    }
}

// If file does not exist on disk, render an attractive fallback SVG
if (!$filePath || !file_exists($filePath)) {
    header("Content-Type: image/svg+xml");
    header("Cache-Control: public, max-age=86400");
    $displayTitle = htmlspecialchars($attachment['file_name'] ?? $sanitizedFileName, ENT_QUOTES, 'UTF-8');
    echo <<<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="600" height="400" viewBox="0 0 600 400">
    <rect width="600" height="400" fill="#0f172a"/>
    <rect x="20" y="20" width="560" height="360" rx="10" fill="#1e293b" stroke="#334155" stroke-width="2"/>
    <circle cx="300" cy="160" r="45" fill="#334155"/>
    <text x="300" y="175" font-family="-apple-system, sans-serif" font-size="40" text-anchor="middle" fill="#38bdf8">📷</text>
    <text x="300" y="240" font-family="-apple-system, sans-serif" font-size="18" font-weight="bold" text-anchor="middle" fill="#f8fafc">EVIDENCE PHOTO</text>
    <text x="300" y="270" font-family="-apple-system, sans-serif" font-size="14" text-anchor="middle" fill="#94a3b8">{$displayTitle}</text>
    <rect x="220" y="300" width="160" height="28" rx="14" fill="#f59e0b"/>
    <text x="300" y="319" font-family="-apple-system, sans-serif" font-size="12" font-weight="bold" text-anchor="middle" fill="#0f172a">CAMPUS SAFETY RECORD</text>
</svg>
SVG;
    exit;
}

// Deliver physical file
$fileName = $attachment['file_name'] ?? $sanitizedFileName;
$disposition = $isDownload ? 'attachment' : 'inline';

header("Content-Type: " . ($mimeType ?: 'application/octet-stream'));
header("Content-Length: " . filesize($filePath));
header("Content-Disposition: {$disposition}; filename=\"" . addslashes($fileName) . "\"");
header("Cache-Control: public, max-age=86400");

readfile($filePath);
exit;
