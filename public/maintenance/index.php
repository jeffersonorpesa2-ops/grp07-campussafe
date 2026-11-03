<?php
/**
 * CampusSafe: Maintenance Technician Portal
 * Displays assigned work orders and dispatched safety hazards
 */

require_once __DIR__ . '/../../src/config/Database.php';
require_once __DIR__ . '/../../src/auth/Auth.php';
require_once __DIR__ . '/../../src/auth/Csrf.php';
require_once __DIR__ . '/../../src/models/Assignment.php';
require_once __DIR__ . '/../../src/models/Report.php';
require_once __DIR__ . '/../../src/helpers/functions.php';

Auth::requireRole('Maintenance');

$statusFilter = $_GET['filter'] ?? '';
$assignedWork = Assignment::getAssignedToUser(Auth::id(), $statusFilter ?: null);

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    Csrf::enforce();
    $reportId = (int)($_POST['report_id'] ?? 0);
    $action = $_POST['action'] ?? '';

    if ($action === 'start_work' && $reportId > 0) {
        try {
            Report::startProgress($reportId, Auth::id(), 'Technician accepted dispatch and commenced on-site work.');
            flash('success', "Work on hazard #{$reportId} is now marked 'In Progress'.");
            redirect('/maintenance/index.php');
        } catch (Exception $e) {
            flash('error', 'Failed to update work order: ' . $e->getMessage());
        }
    }
}

$pageTitle = 'My Work Orders';
require_once __DIR__ . '/../../src/helpers/header.php';
?>

<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem; flex-wrap: wrap; gap: 1rem;">
    <div>
        <h1 style="font-size: 1.8rem; font-weight: 700;">My Assigned Work Orders</h1>
        <p style="color: #64748b;">Hazards dispatched to you for physical repair, hazard mitigation, or inspection.</p>
    </div>
    <div style="display: flex; gap: 0.5rem;">
        <a href="/maintenance/index.php" class="btn btn-sm <?= empty($statusFilter) ? 'btn-primary' : 'btn-outline' ?>">All</a>
        <a href="/maintenance/index.php?filter=Assigned" class="btn btn-sm <?= $statusFilter === 'Assigned' ? 'btn-primary' : 'btn-outline' ?>">Awaiting Start</a>
        <a href="/maintenance/index.php?filter=In+Progress" class="btn btn-sm <?= $statusFilter === 'In Progress' ? 'btn-primary' : 'btn-outline' ?>">In Progress</a>
        <a href="/maintenance/index.php?filter=Completed" class="btn btn-sm <?= $statusFilter === 'Completed' ? 'btn-primary' : 'btn-outline' ?>">Completed</a>
    </div>
</div>

<div class="card">
    <div class="card-header">
        <h3>Assigned Incidents (<?= count($assignedWork) ?>)</h3>
    </div>
    <div class="card-body" style="padding: 0;">
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th style="width: 70px;">ID</th>
                        <th>Work Status</th>
                        <th>Priority</th>
                        <th>Category</th>
                        <th>Campus Location</th>
                        <th>Dispatched Date</th>
                        <th style="text-align: right;">Action</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($assignedWork)): ?>
                        <tr>
                            <td colspan="7" style="text-align: center; padding: 2.5rem; color: #64748b;">
                                No work orders match your current filter. Check back soon for new dispatches.
                            </td>
                        </tr>
                    <?php else: ?>
                        <?php foreach ($assignedWork as $item): ?>
                            <tr>
                                <td><strong>#<?= e((string)$item['report_id']) ?></strong></td>
                                <td><?= statusBadge($item['assignment_status']) ?></td>
                                <td><?= priorityBadge($item['priority']) ?></td>
                                <td><?= e($item['category_name']) ?></td>
                                <td>
                                    <strong><?= e($item['building']) ?></strong><br>
                                    <small style="color: #64748b;"><?= e($item['floor'] ? $item['floor'] . ' &bull; ' : '') ?><?= e($item['room_area']) ?></small>
                                </td>
                                <td><?= formatDate($item['assigned_at']) ?></td>
                                <td style="text-align: right; white-space: nowrap;">
                                    <?php if ($item['assignment_status'] === 'Assigned'): ?>
                                        <form method="POST" action="/maintenance/index.php" style="display: inline-block;">
                                            <?= Csrf::field() ?>
                                            <input type="hidden" name="action" value="start_work">
                                            <input type="hidden" name="report_id" value="<?= e((string)$item['report_id']) ?>">
                                            <button type="submit" class="btn btn-primary btn-sm">Start Work</button>
                                        </form>
                                    <?php elseif ($item['assignment_status'] === 'In Progress'): ?>
                                        <a href="/maintenance/update.php?id=<?= e((string)$item['report_id']) ?>" class="btn btn-success btn-sm">
                                            Update / Resolve &rarr;
                                        </a>
                                    <?php endif; ?>

                                    <a href="/reports/view.php?id=<?= e((string)$item['report_id']) ?>" class="btn btn-outline btn-sm">
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
