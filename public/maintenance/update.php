<?php
/**
 * CampusSafe: Technician Action Logging & Hazard Resolution
 * Phase 3, Step 7: Record actions, update progress, set resolved_at in transaction
 */

require_once __DIR__ . '/../../src/config/Database.php';
require_once __DIR__ . '/../../src/auth/Auth.php';
require_once __DIR__ . '/../../src/auth/Csrf.php';
require_once __DIR__ . '/../../src/models/Report.php';
require_once __DIR__ . '/../../src/models/Assignment.php';
require_once __DIR__ . '/../../src/models/MaintenanceAction.php';
require_once __DIR__ . '/../../src/helpers/functions.php';

Auth::requireRole('Maintenance');

$reportId = (int)($_GET['id'] ?? 0);
if ($reportId <= 0) {
    flash('error', 'Invalid report ID.');
    redirect('/maintenance/index.php');
}

$report = Report::findById($reportId);
if (!$report) {
    flash('error', 'Hazard report not found.');
    redirect('/maintenance/index.php');
}

// Enforce technician assignment check
$assignment = Assignment::getByReportId($reportId);
if (!$assignment || (int)$assignment['maintenance_user_id'] !== Auth::id()) {
    flash('error', 'You are not assigned to this hazard report.');
    redirect('/maintenance/index.php');
}

$error = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    Csrf::enforce();

    $actionDetails = trim($_POST['action_details'] ?? '');
    $notes = trim($_POST['notes'] ?? '');
    $isResolution = isset($_POST['is_resolution']) && $_POST['is_resolution'] === '1';

    if (empty($actionDetails)) {
        $error = 'Please provide details of the action or maintenance performed.';
    } else {
        try {
            if ($isResolution) {
                // Execute resolution workflow in a single PDO transaction
                Report::resolve($reportId, Auth::id(), $actionDetails, $notes);
                flash('success', "Hazard #{$reportId} has been successfully resolved and logged.");
                redirect("/reports/view.php?id={$reportId}");
            } else {
                // Record intermediate progress action
                MaintenanceAction::create($reportId, Auth::id(), $actionDetails, false, $notes);
                
                // Ensure report is In Progress
                if ($report['status'] === 'Assigned') {
                    Report::startProgress($reportId, Auth::id(), 'Technician logged initial progress.');
                }
                
                flash('success', "Maintenance action logged for Report #{$reportId}.");
                redirect("/maintenance/update.php?id={$reportId}");
            }
        } catch (Exception $e) {
            $error = 'Failed to record maintenance update: ' . $e->getMessage();
        }
    }
}

$actions = MaintenanceAction::getByReportId($reportId);

$pageTitle = "Update Hazard #{$reportId}";
require_once __DIR__ . '/../../src/helpers/header.php';
?>

<div style="max-width: 800px; margin: 1rem auto;">
    <div style="margin-bottom: 1.5rem;">
        <a href="/maintenance/index.php" class="btn btn-outline btn-sm">&larr; Back to Work Orders</a>
    </div>

    <!-- Hazard Summary -->
    <div class="card" style="margin-bottom: 1.5rem;">
        <div class="card-header">
            <div>
                <span style="font-size: 0.8rem; color: #64748b; font-weight: 600;">ACTIVE WORK ORDER</span>
                <h2 style="font-size: 1.3rem; margin-top: 0.2rem;">Hazard #<?= e((string)$report['report_id']) ?>: <?= e($report['category_name']) ?></h2>
            </div>
            <div>
                <?= priorityBadge($report['priority']) ?>
                <?= statusBadge($report['status']) ?>
            </div>
        </div>
        <div class="card-body">
            <p><strong>Location:</strong> <?= e($report['building']) ?> [<?= e($report['floor']) ?>] &bull; <?= e($report['room_area']) ?></p>
            <p style="margin-top: 0.5rem;"><strong>Reported Condition:</strong></p>
            <p style="background: #f8fafc; padding: 0.85rem; border-radius: 6px; border: 1px solid #e2e8f0; font-style: italic;">
                <?= e($report['description']) ?>
            </p>
        </div>
    </div>

    <!-- Update / Resolve Action Form -->
    <div class="card">
        <div class="card-header" style="background: #f8fafc;">
            <h3>Log Maintenance Activity / Mark Resolved</h3>
        </div>
        <div class="card-body">
            <?php if ($error): ?>
                <div class="alert alert-danger"><?= e($error) ?></div>
            <?php endif; ?>

            <form method="POST" action="/maintenance/update.php?id=<?= e((string)$reportId) ?>">
                <?= Csrf::field() ?>

                <div class="form-group">
                    <label for="action_details" class="form-label">Work Done / Action Taken <span style="color:#ef4444;">*</span></label>
                    <textarea name="action_details" id="action_details" class="form-control" rows="4" required
                              placeholder="Detail what was repaired, inspected, barricaded, or replaced..."></textarea>
                </div>

                <div class="form-group">
                    <label for="notes" class="form-label">Equipment Used / Parts Replaced / Follow-up Notes</label>
                    <input type="text" name="notes" id="notes" class="form-control"
                           placeholder="e.g. Installed Eaton 30A breaker; tested voltage 120V">
                </div>

                <div style="background: #ecfdf5; border: 1px solid #a7f3d0; border-radius: 8px; padding: 1rem; margin: 1.5rem 0;">
                    <label style="display: flex; align-items: flex-start; gap: 0.75rem; cursor: pointer;">
                        <input type="checkbox" name="is_resolution" value="1" style="width: 20px; height: 20px; margin-top: 2px;">
                        <div>
                            <strong style="color: #065f46; display: block; font-size: 0.95rem;">
                                Hazard Fully Resolved &amp; Safe for Campus Use
                            </strong>
                            <small style="color: #047857; display: block; margin-top: 0.2rem;">
                                Checking this box sets the report status to <strong>Resolved</strong>, timestamps <code>resolved_at</code>, and marks your assignment completed.
                            </small>
                        </div>
                    </label>
                </div>

                <div style="display: flex; gap: 1rem; justify-content: flex-end;">
                    <a href="/maintenance/index.php" class="btn btn-secondary">Cancel</a>
                    <button type="submit" class="btn btn-primary">
                        Submit Maintenance Log
                    </button>
                </div>
            </form>
        </div>
    </div>

    <!-- Previous Action History -->
    <?php if (!empty($actions)): ?>
        <div class="card" style="margin-top: 1.5rem;">
            <div class="card-header">
                <h3>Previous Actions on This Hazard (<?= count($actions) ?>)</h3>
            </div>
            <div class="card-body" style="padding: 0;">
                <table class="table">
                    <thead>
                        <tr>
                            <th>Timestamp</th>
                            <th>Technician</th>
                            <th>Action Performed</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($actions as $act): ?>
                            <tr>
                                <td><?= formatDate($act['action_date']) ?></td>
                                <td><?= e($act['technician_name']) ?></td>
                                <td><?= e($act['action_details']) ?></td>
                                <td>
                                    <?php if ($act['is_resolution']): ?>
                                        <span class="status-badge badge-status-resolved">Final Resolution</span>
                                    <?php else: ?>
                                        <span class="status-badge badge-status-in-progress">In Progress Note</span>
                                    <?php endif; ?>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
    <?php endif; ?>
</div>

<?php require_once __DIR__ . '/../../src/helpers/footer.php'; ?>
