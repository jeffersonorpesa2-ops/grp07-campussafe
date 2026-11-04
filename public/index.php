<?php
/**
 * CampusSafe: Home / Portal Dashboard
 */

require_once __DIR__ . '/../src/config/Database.php';
require_once __DIR__ . '/../src/auth/Auth.php';
require_once __DIR__ . '/../src/models/Report.php';
require_once __DIR__ . '/../src/helpers/functions.php';

if (!Database::isInitialized()) {
    header('Location: /install.php');
    exit;
}

$pageTitle = 'Home';
$stats = Report::getStatistics();
$recentReports = Report::getAll([], 6);

require_once __DIR__ . '/../src/helpers/header.php';
?>

<div style="background: linear-gradient(135deg, #1e3a8a, #0f172a); color: #fff; padding: 2.5rem 2rem; border-radius: 12px; margin-bottom: 2rem; box-shadow: 0 10px 15px -3px rgba(0,0,0,0.2);">
    <div style="max-width: 800px;">
        <span style="background: #38bdf8; color: #0f172a; padding: 0.25rem 0.6rem; border-radius: 4px; font-size: 0.75rem; font-weight: 700; text-transform: uppercase;">Campus Safety Management</span>
        <h1 style="font-size: 2.3rem; font-weight: 800; margin: 0.75rem 0; line-height: 1.2;">Report Hazards. Protect Our Campus.</h1>
        <p style="color: #cbd5e1; font-size: 1.05rem; margin-bottom: 1.5rem;">
            CampusSafe is the centralized incident reporting and resolution platform for our university community.
            Submit immediate safety concerns, track maintenance remediation, and monitor compliance in real time.
        </p>
        <div style="display: flex; gap: 1rem; flex-wrap: wrap;">
            <?php if (!Auth::check()): ?>
                <a href="/login.php" class="btn btn-primary" style="background:#38bdf8; color:#0f172a; font-weight:600;">Sign In with Campus ID</a>
                <a href="/reports/new.php" class="btn btn-outline" style="color:#fff; border-color:#94a3b8;">File a Hazard Report</a>
            <?php elseif (Auth::hasRole('Administrator')): ?>
                <a href="/admin/verify.php" class="btn btn-primary" style="background:#38bdf8; color:#0f172a; font-weight:600;">Open Verification Queue (<?= $stats['by_status']['Submitted'] ?? 0 ?>)</a>
                <a href="/admin/assign.php" class="btn btn-outline" style="color:#fff; border-color:#94a3b8;">Assign Verified Hazards (<?= $stats['by_status']['Verified'] ?? 0 ?>)</a>
            <?php elseif (Auth::hasRole('Maintenance')): ?>
                <a href="/maintenance/index.php" class="btn btn-primary" style="background:#38bdf8; color:#0f172a; font-weight:600;">View My Assigned Work</a>
            <?php else: ?>
                <a href="/reports/new.php" class="btn btn-primary" style="background:#38bdf8; color:#0f172a; font-weight:600;">+ Report a Safety Hazard</a>
                <a href="/reports/list.php" class="btn btn-outline" style="color:#fff; border-color:#94a3b8;">My Submitted Reports</a>
            <?php endif; ?>
        </div>
    </div>
</div>

<!-- Metrics Overview -->
<div class="metrics-grid">
    <div class="metric-card">
        <span class="metric-label">Total Reports Filed</span>
        <div class="metric-value"><?= e((string)$stats['total_reports']) ?></div>
        <span class="metric-sub">Across all campus zones</span>
    </div>
    <div class="metric-card" style="border-left: 4px solid var(--status-submitted);">
        <span class="metric-label">Pending Verification</span>
        <div class="metric-value" style="color: #d97706;"><?= e((string)($stats['by_status']['Submitted'] ?? 0)) ?></div>
        <span class="metric-sub">Awaiting admin review</span>
    </div>
    <div class="metric-card" style="border-left: 4px solid var(--status-in-progress);">
        <span class="metric-label">Active In-Progress</span>
        <div class="metric-value" style="color: #7c3aed;"><?= e((string)($stats['by_status']['In Progress'] ?? 0)) ?></div>
        <span class="metric-sub">Under active maintenance</span>
    </div>
    <div class="metric-card" style="border-left: 4px solid var(--status-resolved);">
        <span class="metric-label">Resolved Incidents</span>
        <div class="metric-value" style="color: #059669;"><?= e((string)($stats['by_status']['Resolved'] ?? 0)) ?></div>
        <span class="metric-sub">Verified & safe for use</span>
    </div>
</div>

<!-- Recent Activity & Quick Navigation -->
<div class="card">
    <div class="card-header">
        <h2>Recent Hazard Reports</h2>
        <a href="/reports/list.php" class="btn btn-outline btn-sm">View All Reports &rarr;</a>
    </div>
    <div class="card-body" style="padding: 0;">
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Status</th>
                        <th>Priority</th>
                        <th>Category</th>
                        <th>Campus Location</th>
                        <th>Reported Date</th>
                        <th>Action</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($recentReports)): ?>
                        <tr><td colspan="7" style="text-align:center; padding: 2rem; color: #64748b;">No hazard reports found in system.</td></tr>
                    <?php else: ?>
                        <?php foreach (array_slice($recentReports, 0, 6) as $r): ?>
                            <tr>
                                <td><strong>#<?= e((string)$r['report_id']) ?></strong></td>
                                <td><?= statusBadge($r['status']) ?></td>
                                <td><?= priorityBadge($r['priority']) ?></td>
                                <td><?= e($r['category_name']) ?></td>
                                <td><?= e($r['building']) ?> &bull; <small style="color:#64748b;"><?= e($r['room_area']) ?></small></td>
                                <td><?= formatDate($r['submitted_at']) ?></td>
                                <td>
                                    <a href="/reports/view.php?id=<?= e((string)$r['report_id']) ?>" class="btn btn-outline btn-sm">Inspect</a>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>
</div>

<?php require_once __DIR__ . '/../src/helpers/footer.php'; ?>
