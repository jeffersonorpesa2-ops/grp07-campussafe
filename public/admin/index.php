<?php
/**
 * CampusSafe: Admin Command Center
 */

require_once __DIR__ . '/../../src/config/Database.php';
require_once __DIR__ . '/../../src/auth/Auth.php';
require_once __DIR__ . '/../../src/models/Report.php';
require_once __DIR__ . '/../../src/helpers/functions.php';

Auth::requireRole('Administrator');

$stats = Report::getStatistics();
$unverifiedCount = $stats['by_status']['Submitted'] ?? 0;
$unassignedCount = $stats['by_status']['Verified'] ?? 0;
$inProgressCount = $stats['by_status']['In Progress'] ?? 0;

$pageTitle = 'Admin Command Center';
require_once __DIR__ . '/../../src/helpers/header.php';
?>

<div style="margin-bottom: 2rem;">
    <h1 style="font-size: 2rem; font-weight: 700;">Safety Administration Dashboard</h1>
    <p style="color: #64748b;">Oversee incoming hazard reports, maintenance assignments, and master campus records.</p>
</div>

<!-- Workflow Cards -->
<div class="metrics-grid">
    <a href="/admin/verify.php" style="text-decoration: none; color: inherit;">
        <div class="metric-card" style="border-top: 4px solid var(--status-submitted); transition: transform 0.15s ease;">
            <span class="metric-label">Needs Verification</span>
            <div class="metric-value" style="color: #d97706;"><?= e((string)$unverifiedCount) ?></div>
            <span class="metric-sub">Reports waiting for admin review &rarr;</span>
        </div>
    </a>

    <a href="/admin/assign.php" style="text-decoration: none; color: inherit;">
        <div class="metric-card" style="border-top: 4px solid var(--status-verified); transition: transform 0.15s ease;">
            <span class="metric-label">Ready for Assignment</span>
            <div class="metric-value" style="color: #0284c7;"><?= e((string)$unassignedCount) ?></div>
            <span class="metric-sub">Verified reports awaiting technician &rarr;</span>
        </div>
    </a>

    <a href="/reports/list.php?status=In+Progress" style="text-decoration: none; color: inherit;">
        <div class="metric-card" style="border-top: 4px solid var(--status-in-progress); transition: transform 0.15s ease;">
            <span class="metric-label">Active Work In Progress</span>
            <div class="metric-value" style="color: #7c3aed;"><?= e((string)$inProgressCount) ?></div>
            <span class="metric-sub">Technicians currently on site &rarr;</span>
        </div>
    </a>

    <a href="/admin/stats.php" style="text-decoration: none; color: inherit;">
        <div class="metric-card" style="border-top: 4px solid #10b981; transition: transform 0.15s ease;">
            <span class="metric-label">Safety Analytics</span>
            <div class="metric-value" style="color: #059669;">Charts</div>
            <span class="metric-sub">View breakdown by building & category &rarr;</span>
        </div>
    </a>
</div>

<!-- Quick Administration Management Hub -->
<div class="card">
    <div class="card-header">
        <h3>Master Data & System Operations</h3>
    </div>
    <div class="card-body">
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1.5rem;">
            <div style="border: 1px solid #e2e8f0; border-radius: 8px; padding: 1.25rem; background: #f8fafc;">
                <h4 style="margin-bottom: 0.5rem; font-size: 1.1rem;">👥 User Management</h4>
                <p style="color: #64748b; font-size: 0.9rem; margin-bottom: 1rem;">
                    Manage administrator, technician, reporter, and auditor accounts. Deactivate or suspend accounts.
                </p>
                <a href="/admin/users.php" class="btn btn-outline btn-sm">Manage Users &rarr;</a>
            </div>

            <div style="border: 1px solid #e2e8f0; border-radius: 8px; padding: 1.25rem; background: #f8fafc;">
                <h4 style="margin-bottom: 0.5rem; font-size: 1.1rem;">🏷️ Hazard Categories</h4>
                <p style="color: #64748b; font-size: 0.9rem; margin-bottom: 1rem;">
                    Configure classification tags (Electrical, Structural, Sanitation, Fire Safety, Equipment).
                </p>
                <a href="/admin/categories.php" class="btn btn-outline btn-sm">Configure Categories &rarr;</a>
            </div>

            <div style="border: 1px solid #e2e8f0; border-radius: 8px; padding: 1.25rem; background: #f8fafc;">
                <h4 style="margin-bottom: 0.5rem; font-size: 1.1rem;">🏛️ Campus Locations</h4>
                <p style="color: #64748b; font-size: 0.9rem; margin-bottom: 1rem;">
                    Maintain buildings, floor designations, and room/area identifiers for precision dispatching.
                </p>
                <a href="/admin/locations.php" class="btn btn-outline btn-sm">Configure Locations &rarr;</a>
            </div>
        </div>
    </div>
</div>

<?php require_once __DIR__ . '/../../src/helpers/footer.php'; ?>
