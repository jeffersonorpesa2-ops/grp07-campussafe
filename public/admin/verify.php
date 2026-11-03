<?php
/**
 * CampusSafe: Admin Verification Queue
 * Phase 3, Step 5: View submitted reports, set priority, set verified_by/at, transition to Verified
 */

require_once __DIR__ . '/../../src/config/Database.php';
require_once __DIR__ . '/../../src/auth/Auth.php';
require_once __DIR__ . '/../../src/auth/Csrf.php';
require_once __DIR__ . '/../../src/models/Report.php';
require_once __DIR__ . '/../../src/helpers/functions.php';

Auth::requireRole('Administrator');

$selectedId = (int)($_GET['id'] ?? 0);
$selectedReport = null;

if ($selectedId > 0) {
    $selectedReport = Report::findById($selectedId);
    if (!$selectedReport || $selectedReport['status'] !== 'Submitted') {
        flash('error', "Report #{$selectedId} is either not found or already verified.");
        redirect('/admin/verify.php');
    }
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    Csrf::enforce();

    $reportId = (int)($_POST['report_id'] ?? 0);
    $priority = trim($_POST['priority'] ?? '');
    $notes = trim($_POST['notes'] ?? '');

    if ($reportId <= 0 || !in_array($priority, ['Low', 'Medium', 'High', 'Critical'], true)) {
        flash('error', 'Please select a valid priority level for verification.');
    } else {
        try {
            Report::verify($reportId, Auth::id(), $priority, $notes);
            flash('success', "Report #{$reportId} was successfully verified as {$priority} priority. Ready for assignment.");
            redirect('/admin/assign.php?id=' . $reportId);
        } catch (Exception $e) {
            flash('error', 'Verification failed: ' . $e->getMessage());
        }
    }
}

// Fetch all reports currently in 'Submitted' status
$unverifiedReports = Report::getAll(['status' => 'Submitted']);

$pageTitle = 'Verification Queue';
require_once __DIR__ . '/../../src/helpers/header.php';
?>

<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem;">
    <div>
        <h1 style="font-size: 1.8rem; font-weight: 700;">Hazard Verification Queue</h1>
        <p style="color: #64748b;">Review newly reported hazards, determine risk severity, and assign priority ratings.</p>
    </div>
    <span class="status-badge badge-status-submitted" style="font-size: 0.9rem; padding: 0.4rem 0.8rem;">
        <?= count($unverifiedReports) ?> Awaiting Verification
    </span>
</div>

<?php if ($selectedReport): ?>
    <!-- Verification Action Form for Selected Report -->
    <div class="card" style="border: 2px solid #0284c7; box-shadow: 0 4px 12px rgba(2, 132, 199, 0.15); margin-bottom: 2rem;">
        <div class="card-header" style="background: #e0f2fe;">
            <h2 style="color: #0369a1; font-size: 1.3rem;">Verify Hazard Report #<?= e((string)$selectedReport['report_id']) ?></h2>
            <a href="/admin/verify.php" class="btn btn-secondary btn-sm">Close Form</a>
        </div>
        <div class="card-body">
            <div style="margin-bottom: 1.5rem; background: #f8fafc; padding: 1.25rem; border-radius: 8px; border: 1px solid #e2e8f0;">
                <p><strong>Category:</strong> <?= e($selectedReport['category_name']) ?> &bull; <strong>Reporter:</strong> <?= e($selectedReport['reporter_name']) ?></p>
                <p><strong>Location:</strong> <?= e($selectedReport['building']) ?> &bull; <?= e($selectedReport['room_area']) ?></p>
                <p style="margin-top: 0.5rem;"><strong>Description:</strong></p>
                <p style="color: #334155; font-style: italic; white-space: pre-wrap; margin-top: 0.25rem;"><?= e($selectedReport['description']) ?></p>
            </div>

            <form method="POST" action="/admin/verify.php">
                <?= Csrf::field() ?>
                <input type="hidden" name="report_id" value="<?= e((string)$selectedReport['report_id']) ?>">

                <div class="form-group">
                    <label for="priority" class="form-label">Assign Priority Classification <span style="color:#ef4444;">*</span></label>
                    <select name="priority" id="priority" class="form-select" required>
                        <option value="">-- Select Priority Level --</option>
                        <option value="Critical">🔴 Critical (Immediate life safety or structural risk)</option>
                        <option value="High">🟠 High (Serious safety risk or major service outage)</option>
                        <option value="Medium">🟡 Medium (Moderate hazard requiring repair within 48h)</option>
                        <option value="Low">🟢 Low (Cosmetic, minor inconvenience or routine upkeep)</option>
                    </select>
                </div>

                <div class="form-group">
                    <label for="notes" class="form-label">Verification Assessment Notes</label>
                    <textarea name="notes" id="notes" class="form-control" rows="3" placeholder="Enter findings from initial inspection or specific dispatch instructions..."></textarea>
                </div>

                <div style="display: flex; gap: 1rem; justify-content: flex-end; margin-top: 1.5rem;">
                    <a href="/admin/verify.php" class="btn btn-secondary">Cancel</a>
                    <button type="submit" class="btn btn-primary" style="padding: 0.65rem 1.75rem;">
                        Confirm Verification &amp; Proceed to Assignment &rarr;
                    </button>
                </div>
            </form>
        </div>
    </div>
<?php endif; ?>

<!-- Queue Table -->
<div class="card">
    <div class="card-header">
        <h3>Pending Reports (<?= count($unverifiedReports) ?>)</h3>
    </div>
    <div class="card-body" style="padding: 0;">
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th style="width: 70px;">ID</th>
                        <th>Category</th>
                        <th>Location</th>
                        <th>Reporter</th>
                        <th>Submitted At</th>
                        <th>Description Preview</th>
                        <th style="text-align: right;">Action</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($unverifiedReports)): ?>
                        <tr>
                            <td colspan="7" style="text-align: center; padding: 2.5rem; color: #64748b;">
                                🎉 Great news! There are no unverified hazard reports in the queue.
                            </td>
                        </tr>
                    <?php else: ?>
                        <?php foreach ($unverifiedReports as $r): ?>
                            <tr>
                                <td><strong>#<?= e((string)$r['report_id']) ?></strong></td>
                                <td><?= e($r['category_name']) ?></td>
                                <td><?= e($r['building']) ?> - <?= e($r['room_area']) ?></td>
                                <td><?= e($r['reporter_name']) ?></td>
                                <td><?= formatDate($r['submitted_at']) ?></td>
                                <td style="max-width: 280px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                                    <?= e($r['description']) ?>
                                </td>
                                <td style="text-align: right; white-space: nowrap;">
                                    <a href="/admin/verify.php?id=<?= e((string)$r['report_id']) ?>" class="btn btn-primary btn-sm">
                                        Verify &amp; Prioritize
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
