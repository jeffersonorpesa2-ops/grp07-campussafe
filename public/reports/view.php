<?php
/**
 * CampusSafe: View Report Details & Audit Trail
 */

require_once __DIR__ . '/../../src/config/Database.php';
require_once __DIR__ . '/../../src/auth/Auth.php';
require_once __DIR__ . '/../../src/auth/Csrf.php';
require_once __DIR__ . '/../../src/models/Report.php';
require_once __DIR__ . '/../../src/models/Attachment.php';
require_once __DIR__ . '/../../src/models/MaintenanceAction.php';
require_once __DIR__ . '/../../src/helpers/functions.php';

Auth::requireLogin();

$reportId = (int)($_GET['id'] ?? 0);
if ($reportId <= 0) {
    flash('error', 'Invalid report ID specified.');
    redirect('/reports/list.php');
}

$report = Report::findById($reportId);
if (!$report) {
    flash('error', 'Hazard report not found.');
    redirect('/reports/list.php');
}

// Student/Faculty authorization: can only inspect own reports
$currentUser = Auth::user();
$currentRole = Auth::role();
if (in_array($currentRole, ['Student', 'Faculty/Staff'], true) && $report['reporter_user_id'] !== Auth::id()) {
    flash('error', 'You are only authorized to view reports filed by yourself.');
    redirect('/reports/list.php');
}

// Handle administrative status transition (e.g. Close Report)
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    Csrf::enforce();
    $action = $_POST['action'] ?? '';

    try {
        if ($action === 'close' && Auth::hasRole('Administrator')) {
            $notes = trim($_POST['notes'] ?? '');
            Report::close($reportId, Auth::id(), $notes);
            flash('success', "Report #{$reportId} has been successfully verified and closed.");
            redirect("/reports/view.php?id={$reportId}");
        } elseif ($action === 'start_work' && Auth::hasRole('Maintenance')) {
            $notes = trim($_POST['notes'] ?? '');
            Report::startProgress($reportId, Auth::id(), $notes);
            flash('success', "Work on report #{$reportId} is now In Progress.");
            redirect("/reports/view.php?id={$reportId}");
        }
    } catch (Exception $e) {
        flash('error', 'Action failed: ' . $e->getMessage());
        redirect("/reports/view.php?id={$reportId}");
    }
}

$history = Report::getHistory($reportId);
$actions = MaintenanceAction::getByReportId($reportId);
$attachments = Attachment::getByReportId($reportId);

$pageTitle = "Report #{$reportId} Details";
require_once __DIR__ . '/../../src/helpers/header.php';
?>

<div style="margin-bottom: 1.5rem;">
    <a href="/reports/list.php" class="btn btn-outline btn-sm">&larr; Back to Reports List</a>
</div>

<!-- Header Card -->
<div class="card">
    <div class="card-header" style="flex-wrap: wrap; gap: 1rem;">
        <div>
            <span style="font-size: 0.85rem; color: #64748b; font-weight: 600;">HAZARD INCIDENT REPORT</span>
            <h1 style="font-size: 1.6rem; margin: 0.2rem 0;"><?= e($report['category_name']) ?> Hazard #<?= e((string)$report['report_id']) ?></h1>
            <p style="color: #64748b; font-size: 0.88rem;">Submitted on <?= formatDate($report['submitted_at']) ?> by <?= e($report['reporter_name']) ?></p>
        </div>
        <div style="display: flex; gap: 0.6rem; align-items: center;">
            <div><?= priorityBadge($report['priority']) ?></div>
            <div><?= statusBadge($report['status']) ?></div>
        </div>
    </div>

    <div class="card-body">
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 1.5rem; margin-bottom: 1.5rem; padding-bottom: 1.5rem; border-bottom: 1px solid #e2e8f0;">
            <div>
                <span class="metric-label">Location</span>
                <p style="font-weight: 600; margin-top: 0.2rem;"><?= e($report['building']) ?></p>
                <p style="font-size: 0.85rem; color: #64748b;"><?= e($report['floor'] ? $report['floor'] . ' &bull; ' : '') ?><?= e($report['room_area']) ?></p>
                <?php if (!empty($report['location_description'])): ?>
                    <small style="color: #64748b;"><?= e($report['location_description']) ?></small>
                <?php endif; ?>
            </div>

            <div>
                <span class="metric-label">Assigned Technician</span>
                <p style="font-weight: 600; margin-top: 0.2rem;"><?= e($report['assigned_technician_name'] ?? 'Not Yet Assigned') ?></p>
                <?php if (!empty($report['assigned_at'])): ?>
                    <p style="font-size: 0.85rem; color: #64748b;">Dispatched on <?= formatDate($report['assigned_at']) ?></p>
                <?php endif; ?>
            </div>

            <div>
                <span class="metric-label">Verification Status</span>
                <?php if ($report['verified_by_user_id']): ?>
                    <p style="font-weight: 600; color: #0284c7; margin-top: 0.2rem;">Verified by <?= e($report['verifier_name']) ?></p>
                    <p style="font-size: 0.85rem; color: #64748b;"><?= formatDate($report['verified_at']) ?></p>
                <?php else: ?>
                    <p style="color: #d97706; font-style: italic; margin-top: 0.2rem;">Pending Review</p>
                <?php endif; ?>
            </div>

            <div>
                <span class="metric-label">Resolution Timestamp</span>
                <?php if ($report['resolved_at']): ?>
                    <p style="font-weight: 600; color: #059669; margin-top: 0.2rem;">Resolved</p>
                    <p style="font-size: 0.85rem; color: #64748b;"><?= formatDate($report['resolved_at']) ?></p>
                <?php else: ?>
                    <p style="color: #64748b; font-style: italic; margin-top: 0.2rem;">Unresolved</p>
                <?php endif; ?>
            </div>
        </div>

        <div>
            <h3 style="font-size: 1.1rem; margin-bottom: 0.5rem;">Hazard Description</h3>
            <div style="background: #f8fafc; padding: 1.25rem; border-radius: 8px; border: 1px solid #e2e8f0; font-size: 0.98rem; line-height: 1.6; white-space: pre-wrap;"><?= e($report['description']) ?></div>
        </div>

        <!-- Attachments Section -->
        <?php if (!empty($attachments)): ?>
            <div style="margin-top: 2rem;">
                <h3 style="font-size: 1.15rem; margin-bottom: 0.85rem; display: flex; align-items: center; gap: 0.5rem;">
                    <span>📷</span> Attached Evidence &amp; Photos (<?= count($attachments) ?>)
                </h3>
                <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 320px)); gap: 1.25rem;">
                    <?php foreach ($attachments as $att): 
                        $isImage = str_starts_with($att['mime_type'] ?? '', 'image/') || preg_match('/\.(jpg|jpeg|png|webp|gif)$/i', $att['file_name']);
                        $viewUrl = "/attachment.php?id=" . (int)$att['attachment_id'];
                        $downloadUrl = "/attachment.php?id=" . (int)$att['attachment_id'] . "&download=1";
                    ?>
                        <div class="card" style="margin-bottom: 0; box-shadow: 0 2px 5px rgba(0,0,0,0.06); transition: transform 0.15s ease, box-shadow 0.15s ease; overflow: hidden; border: 1px solid #cbd5e1;">
                            <a href="<?= $viewUrl ?>" target="_blank" title="Click to open full-size image" style="display: block; position: relative; background: #0f172a; text-decoration: none;">
                                <?php if ($isImage): ?>
                                    <img src="<?= $viewUrl ?>" alt="<?= e($att['file_name']) ?>" 
                                         style="width: 100%; height: 175px; object-fit: cover; display: block; border-bottom: 1px solid #e2e8f0;">
                                    <div style="position: absolute; bottom: 8px; right: 8px; background: rgba(15, 23, 42, 0.75); color: #fff; padding: 0.2rem 0.5rem; border-radius: 4px; font-size: 0.72rem; font-weight: 600; display: flex; align-items: center; gap: 0.3rem;">
                                        🔍 Click to Enlarge
                                    </div>
                                <?php else: ?>
                                    <div style="height: 175px; display: flex; flex-direction: column; align-items: center; justify-content: center; background: #f8fafc; border-bottom: 1px solid #e2e8f0; color: #475569;">
                                        <span style="font-size: 3rem; margin-bottom: 0.3rem;">📄</span>
                                        <span style="font-size: 0.8rem; font-weight: 600; text-transform: uppercase; background: #e2e8f0; padding: 0.15rem 0.5rem; border-radius: 4px;">PDF DOCUMENT</span>
                                    </div>
                                <?php endif; ?>
                            </a>

                            <div style="padding: 0.85rem;">
                                <p style="font-size: 0.88rem; font-weight: 600; color: #1e293b; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; margin-bottom: 0.25rem;" title="<?= e($att['file_name']) ?>">
                                    <?= e($att['file_name']) ?>
                                </p>
                                <p style="font-size: 0.78rem; color: #64748b; margin-bottom: 0.75rem;">
                                    Uploaded by <strong><?= e($att['uploaded_by_name']) ?></strong> &bull; <?= formatDate($att['uploaded_at'], 'M d, Y') ?>
                                </p>
                                <div style="display: flex; gap: 0.5rem;">
                                    <a href="<?= $viewUrl ?>" target="_blank" class="btn btn-outline btn-sm" style="flex: 1; font-size: 0.8rem; padding: 0.35rem 0.5rem;">
                                        🔍 View Photo
                                    </a>
                                    <a href="<?= $downloadUrl ?>" class="btn btn-secondary btn-sm" style="font-size: 0.8rem; padding: 0.35rem 0.6rem;" title="Download file">
                                        ⬇️ Download
                                    </a>
                                </div>
                            </div>
                        </div>
                    <?php endforeach; ?>
                </div>
            </div>
        <?php endif; ?>

        <!-- Role Action Shortcuts -->
        <?php if (Auth::hasRole('Administrator')): ?>
            <div class="action-panel">
                <h4 style="font-size: 0.95rem; font-weight: 700; text-transform: uppercase; color: #1e3a8a; margin-bottom: 0.5rem;">Administrator Actions</h4>
                <div style="display: flex; gap: 0.75rem; flex-wrap: wrap;">
                    <?php if ($report['status'] === 'Submitted'): ?>
                        <a href="/admin/verify.php?id=<?= e((string)$report['report_id']) ?>" class="btn btn-primary btn-sm">
                            Verify & Prioritize This Hazard
                        </a>
                    <?php elseif ($report['status'] === 'Verified'): ?>
                        <a href="/admin/assign.php?id=<?= e((string)$report['report_id']) ?>" class="btn btn-primary btn-sm">
                            Assign to Maintenance Technician
                        </a>
                    <?php elseif ($report['status'] === 'Resolved'): ?>
                        <form method="POST" action="/reports/view.php?id=<?= e((string)$report['report_id']) ?>" style="display: inline-block;">
                            <?= Csrf::field() ?>
                            <input type="hidden" name="action" value="close">
                            <input type="text" name="notes" placeholder="Closing audit remarks..." class="form-control" style="display:inline-block; width:260px; font-size:0.85rem; margin-right:0.5rem;" required>
                            <button type="submit" class="btn btn-secondary btn-sm" data-confirm="Confirm closing this resolved hazard report?">
                                Close Report
                            </button>
                        </form>
                    <?php endif; ?>
                </div>
            </div>
        <?php elseif (Auth::hasRole('Maintenance') && (int)$report['assigned_technician_id'] === Auth::id()): ?>
            <div class="action-panel">
                <h4 style="font-size: 0.95rem; font-weight: 700; text-transform: uppercase; color: #4338ca; margin-bottom: 0.5rem;">Technician Work Panel</h4>
                <div style="display: flex; gap: 0.75rem; flex-wrap: wrap;">
                    <?php if ($report['status'] === 'Assigned'): ?>
                        <form method="POST" action="/reports/view.php?id=<?= e((string)$report['report_id']) ?>">
                            <?= Csrf::field() ?>
                            <input type="hidden" name="action" value="start_work">
                            <button type="submit" class="btn btn-primary btn-sm">
                                Start Work (Set In Progress)
                            </button>
                        </form>
                    <?php elseif ($report['status'] === 'In Progress'): ?>
                        <a href="/maintenance/update.php?id=<?= e((string)$report['report_id']) ?>" class="btn btn-success btn-sm">
                            Log Action or Mark Resolved &rarr;
                        </a>
                    <?php endif; ?>
                </div>
            </div>
        <?php endif; ?>
    </div>
</div>

<!-- Maintenance Actions Log -->
<?php if (!empty($actions)): ?>
    <div class="card">
        <div class="card-header">
            <h3>Maintenance Technician Action Logs (<?= count($actions) ?>)</h3>
        </div>
        <div class="card-body" style="padding: 0;">
            <div class="table-responsive">
                <table class="table">
                    <thead>
                        <tr>
                            <th>Date & Time</th>
                            <th>Technician</th>
                            <th>Action Details</th>
                            <th>Resolution Flag</th>
                            <th>Notes</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($actions as $act): ?>
                            <tr>
                                <td><?= formatDate($act['action_date']) ?></td>
                                <td><strong><?= e($act['technician_name']) ?></strong></td>
                                <td><?= e($act['action_details']) ?></td>
                                <td>
                                    <?php if ($act['is_resolution']): ?>
                                        <span class="status-badge badge-status-resolved">Final Resolution</span>
                                    <?php else: ?>
                                        <span class="status-badge badge-status-in-progress">Progress Note</span>
                                    <?php endif; ?>
                                </td>
                                <td><?= e($act['notes'] ?? '—') ?></td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
<?php endif; ?>

<!-- Status Transition Audit Trail -->
<div class="card">
    <div class="card-header">
        <h3>Report Status History & Audit Trail</h3>
    </div>
    <div class="card-body">
        <ul class="timeline">
            <?php foreach ($history as $h): ?>
                <li class="timeline-item">
                    <div class="timeline-header">
                        <?= statusBadge($h['status']) ?>
                        <strong><?= e($h['changed_by_name']) ?></strong>
                        <span style="font-size: 0.8rem; color: #64748b;">(<?= e($h['role_name']) ?>)</span>
                        <span class="timeline-meta">&bull; <?= formatDate($h['changed_at']) ?></span>
                    </div>
                    <?php if (!empty($h['notes'])): ?>
                        <div class="timeline-body">
                            <?= e($h['notes']) ?>
                        </div>
                    <?php endif; ?>
                </li>
            <?php endforeach; ?>
        </ul>
    </div>
</div>

<?php require_once __DIR__ . '/../../src/helpers/footer.php'; ?>
