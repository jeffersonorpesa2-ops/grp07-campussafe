<?php
/**
 * CampusSafe: Admin Hazard Assignment Dispatch
 * Phase 3, Step 6: Assign verified reports only, to a maintenance user
 */

require_once __DIR__ . '/../../src/config/Database.php';
require_once __DIR__ . '/../../src/auth/Auth.php';
require_once __DIR__ . '/../../src/auth/Csrf.php';
require_once __DIR__ . '/../../src/models/Report.php';
require_once __DIR__ . '/../../src/models/User.php';
require_once __DIR__ . '/../../src/helpers/functions.php';

Auth::requireRole('Administrator');

$selectedId = (int)($_GET['id'] ?? 0);
$selectedReport = null;

if ($selectedId > 0) {
    $selectedReport = Report::findById($selectedId);
    if (!$selectedReport || $selectedReport['status'] !== 'Verified') {
        flash('error', "Report #{$selectedId} is either not found or not in 'Verified' status.");
        redirect('/admin/assign.php');
    }
}

$maintenanceUsers = User::getMaintenanceUsers();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    Csrf::enforce();

    $reportId = (int)($_POST['report_id'] ?? 0);
    $maintUserId = (int)($_POST['maintenance_user_id'] ?? 0);
    $notes = trim($_POST['notes'] ?? '');

    if ($reportId <= 0 || $maintUserId <= 0) {
        flash('error', 'Please select a qualified maintenance technician to assign.');
    } else {
        try {
            Report::assign($reportId, Auth::id(), $maintUserId, $notes);
            flash('success', "Report #{$reportId} has been officially assigned and dispatched to maintenance.");
            redirect("/reports/view.php?id={$reportId}");
        } catch (Exception $e) {
            flash('error', 'Assignment failed: ' . $e->getMessage());
        }
    }
}

// Fetch all reports in 'Verified' status
$verifiedReports = Report::getAll(['status' => 'Verified']);

$pageTitle = 'Assign Maintenance';
require_once __DIR__ . '/../../src/helpers/header.php';
?>

<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem;">
    <div>
        <h1 style="font-size: 1.8rem; font-weight: 700;">Maintenance Dispatch &amp; Assignment</h1>
        <p style="color: #64748b;">Dispatch verified hazards to specialized on-duty maintenance technicians.</p>
    </div>
    <span class="status-badge badge-status-verified" style="font-size: 0.9rem; padding: 0.4rem 0.8rem;">
        <?= count($verifiedReports) ?> Awaiting Technician Assignment
    </span>
</div>

<?php if ($selectedReport): ?>
    <!-- Assignment Dispatch Panel -->
    <div class="card" style="border: 2px solid #6366f1; box-shadow: 0 4px 12px rgba(99, 102, 241, 0.15); margin-bottom: 2rem;">
        <div class="card-header" style="background: #e0e7ff;">
            <h2 style="color: #4338ca; font-size: 1.3rem;">Dispatch Report #<?= e((string)$selectedReport['report_id']) ?></h2>
            <a href="/admin/assign.php" class="btn btn-secondary btn-sm">Close Panel</a>
        </div>
        <div class="card-body">
            <div style="margin-bottom: 1.5rem; background: #f8fafc; padding: 1.25rem; border-radius: 8px; border: 1px solid #e2e8f0;">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem;">
                    <strong><?= e($selectedReport['category_name']) ?> Hazard</strong>
                    <?= priorityBadge($selectedReport['priority']) ?>
                </div>
                <p><strong>Location:</strong> <?= e($selectedReport['building']) ?> [<?= e($selectedReport['floor']) ?>] &bull; <?= e($selectedReport['room_area']) ?></p>
                <p style="margin-top: 0.5rem;"><strong>Description:</strong></p>
                <p style="color: #334155; font-style: italic; white-space: pre-wrap; margin-top: 0.25rem;"><?= e($selectedReport['description']) ?></p>
            </div>

            <form method="POST" action="/admin/assign.php">
                <?= Csrf::field() ?>
                <input type="hidden" name="report_id" value="<?= e((string)$selectedReport['report_id']) ?>">

                <div class="form-group">
                    <label for="maintenance_user_id" class="form-label">Select Maintenance Technician <span style="color:#ef4444;">*</span></label>
                    <select name="maintenance_user_id" id="maintenance_user_id" class="form-select" required>
                        <option value="">-- Choose Available Technician --</option>
                        <?php foreach ($maintenanceUsers as $m): ?>
                            <option value="<?= e((string)$m['user_id']) ?>">
                                🔧 <?= e($m['full_name']) ?> (<?= e($m['username']) ?> &bull; <?= e($m['email']) ?>)
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>

                <div class="form-group">
                    <label for="notes" class="form-label">Dispatch Work Order Instructions / Equipment Needed</label>
                    <textarea name="notes" id="notes" class="form-control" rows="3" placeholder="Specify any tools, special personal protective equipment (PPE), or instructions..."></textarea>
                </div>

                <div style="display: flex; gap: 1rem; justify-content: flex-end; margin-top: 1.5rem;">
                    <a href="/admin/assign.php" class="btn btn-secondary">Cancel</a>
                    <button type="submit" class="btn btn-primary" style="padding: 0.65rem 1.75rem;">
                        Dispatch Work Order &rarr;
                    </button>
                </div>
            </form>
        </div>
    </div>
<?php endif; ?>

<!-- Verified Reports Table -->
<div class="card">
    <div class="card-header">
        <h3>Verified Hazards Ready for Dispatch (<?= count($verifiedReports) ?>)</h3>
    </div>
    <div class="card-body" style="padding: 0;">
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th style="width: 70px;">ID</th>
                        <th>Priority</th>
                        <th>Category</th>
                        <th>Location</th>
                        <th>Verified At</th>
                        <th>Description Preview</th>
                        <th style="text-align: right;">Action</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($verifiedReports)): ?>
                        <tr>
                            <td colspan="7" style="text-align: center; padding: 2.5rem; color: #64748b;">
                                No verified hazards are currently waiting for assignment.
                            </td>
                        </tr>
                    <?php else: ?>
                        <?php foreach ($verifiedReports as $r): ?>
                            <tr>
                                <td><strong>#<?= e((string)$r['report_id']) ?></strong></td>
                                <td><?= priorityBadge($r['priority']) ?></td>
                                <td><?= e($r['category_name']) ?></td>
                                <td><?= e($r['building']) ?> - <?= e($r['room_area']) ?></td>
                                <td><?= formatDate($r['verified_at']) ?></td>
                                <td style="max-width: 280px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                                    <?= e($r['description']) ?>
                                </td>
                                <td style="text-align: right; white-space: nowrap;">
                                    <a href="/admin/assign.php?id=<?= e((string)$r['report_id']) ?>" class="btn btn-primary btn-sm">
                                        Assign Technician
                                    </a>
                                    <a href="/reports/view.php?id=<?= e((string)$r['report_id']) ?>" class="btn btn-outline btn-sm">
                                        Inspect
                                    </a>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>
</div>

<?php require_once __DIR__ . '/../../src/helpers/footer.php'; ?>
