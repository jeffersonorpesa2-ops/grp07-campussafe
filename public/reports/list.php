<?php
/**
 * CampusSafe: Reports Search & Listing Page
 */

require_once __DIR__ . '/../../src/config/Database.php';
require_once __DIR__ . '/../../src/auth/Auth.php';
require_once __DIR__ . '/../../src/models/Report.php';
require_once __DIR__ . '/../../src/models/Category.php';
require_once __DIR__ . '/../../src/models/Location.php';
require_once __DIR__ . '/../../src/helpers/functions.php';

Auth::requireLogin();

$currentUser = Auth::user();
$currentRole = Auth::role();

// Prepare filter criteria
$filters = [
    'status'      => $_GET['status'] ?? '',
    'category_id' => $_GET['category_id'] ?? '',
    'location_id' => $_GET['location_id'] ?? '',
    'priority'    => $_GET['priority'] ?? '',
    'search'      => $_GET['search'] ?? '',
    'date_from'   => $_GET['date_from'] ?? '',
    'date_to'     => $_GET['date_to'] ?? '',
];

// If student or faculty, restrict to their own submissions only
$isRestrictedReporter = in_array($currentRole, ['Student', 'Faculty/Staff'], true);
if ($isRestrictedReporter) {
    $filters['reporter_user_id'] = Auth::id();
}

$categories = Category::getAll();
$locations = Location::getAll();
$reports = Report::getAll($filters);

$pageTitle = $isRestrictedReporter ? 'My Submitted Reports' : 'Hazard Reports Registry';
require_once __DIR__ . '/../../src/helpers/header.php';
?>

<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem; flex-wrap: wrap; gap: 1rem;">
    <div>
        <h1 style="font-size: 1.8rem; font-weight: 700;"><?= e($pageTitle) ?></h1>
        <p style="color: #64748b; font-size: 0.95rem;">
            <?= $isRestrictedReporter ? 'Tracking all hazards you have filed on campus.' : 'Central safety records database & status overview.' ?>
        </p>
    </div>
    <div>
        <a href="/reports/new.php" class="btn btn-primary">+ New Hazard Report</a>
    </div>
</div>

<!-- Filter Bar -->
<div class="card" style="margin-bottom: 1.5rem;">
    <div class="card-body" style="padding: 1.25rem;">
        <form method="GET" action="/reports/list.php" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 1rem; align-items: end;">
            <div>
                <label class="form-label" style="font-size: 0.8rem;">Search Keyword</label>
                <input type="text" name="search" class="form-control" placeholder="Search description, room..." value="<?= e($filters['search']) ?>">
            </div>

            <div>
                <label class="form-label" style="font-size: 0.8rem;">Status</label>
                <select name="status" class="form-select">
                    <option value="">All Statuses</option>
                    <?php foreach (['Submitted', 'Verified', 'Assigned', 'In Progress', 'Resolved', 'Closed'] as $st): ?>
                        <option value="<?= e($st) ?>" <?= $filters['status'] === $st ? 'selected' : '' ?>><?= e($st) ?></option>
                    <?php endforeach; ?>
                </select>
            </div>

            <div>
                <label class="form-label" style="font-size: 0.8rem;">Priority</label>
                <select name="priority" class="form-select">
                    <option value="">All Priorities</option>
                    <?php foreach (['Critical', 'High', 'Medium', 'Low'] as $pr): ?>
                        <option value="<?= e($pr) ?>" <?= $filters['priority'] === $pr ? 'selected' : '' ?>><?= e($pr) ?></option>
                    <?php endforeach; ?>
                </select>
            </div>

            <div>
                <label class="form-label" style="font-size: 0.8rem;">Category</label>
                <select name="category_id" class="form-select">
                    <option value="">All Categories</option>
                    <?php foreach ($categories as $cat): ?>
                        <option value="<?= e((string)$cat['category_id']) ?>" <?= (string)$filters['category_id'] === (string)$cat['category_id'] ? 'selected' : '' ?>>
                            <?= e($cat['category_name']) ?>
                        </option>
                    <?php endforeach; ?>
                </select>
            </div>

            <div>
                <label class="form-label" style="font-size: 0.8rem;">Location</label>
                <select name="location_id" class="form-select">
                    <option value="">All Locations</option>
                    <?php foreach ($locations as $loc): ?>
                        <option value="<?= e((string)$loc['location_id']) ?>" <?= (string)$filters['location_id'] === (string)$loc['location_id'] ? 'selected' : '' ?>>
                            <?= e($loc['building']) ?> - <?= e($loc['room_area']) ?>
                        </option>
                    <?php endforeach; ?>
                </select>
            </div>

            <div style="display: flex; gap: 0.5rem;">
                <button type="submit" class="btn btn-primary" style="flex: 1;">Filter</button>
                <a href="/reports/list.php" class="btn btn-outline" title="Reset Filters">Reset</a>
            </div>
        </form>
    </div>
</div>

<!-- Results Table -->
<div class="card">
    <div class="card-header">
        <h3>Matching Records (<?= count($reports) ?>)</h3>
    </div>
    <div class="card-body" style="padding: 0;">
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th style="width: 70px;">ID</th>
                        <th>Status</th>
                        <th>Priority</th>
                        <th>Category</th>
                        <th>Location</th>
                        <?php if (!$isRestrictedReporter): ?>
                            <th>Reporter</th>
                            <th>Assigned Tech</th>
                        <?php endif; ?>
                        <th>Date Submitted</th>
                        <th style="text-align: right;">Action</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($reports)): ?>
                        <tr>
                            <td colspan="<?= $isRestrictedReporter ? '7' : '9' ?>" style="text-align: center; padding: 2.5rem; color: #64748b;">
                                No reports match the selected criteria.
                            </td>
                        </tr>
                    <?php else: ?>
                        <?php foreach ($reports as $r): ?>
                            <tr>
                                <td><strong>#<?= e((string)$r['report_id']) ?></strong></td>
                                <td><?= statusBadge($r['status']) ?></td>
                                <td><?= priorityBadge($r['priority']) ?></td>
                                <td><?= e($r['category_name']) ?></td>
                                <td>
                                    <strong><?= e($r['building']) ?></strong><br>
                                    <small style="color: #64748b;"><?= e($r['floor'] ? $r['floor'] . ' &bull; ' : '') ?><?= e($r['room_area']) ?></small>
                                </td>
                                <?php if (!$isRestrictedReporter): ?>
                                    <td><?= e($r['reporter_name']) ?></td>
                                    <td><?= e($r['assigned_technician_name'] ?? '—') ?></td>
                                <?php endif; ?>
                                <td><?= formatDate($r['submitted_at']) ?></td>
                                <td style="text-align: right;">
                                    <a href="/reports/view.php?id=<?= e((string)$r['report_id']) ?>" class="btn btn-outline btn-sm">
                                        View Details
                                    </a>
                                    <?php if ($r['status'] === 'Submitted' && $r['reporter_user_id'] === Auth::id()): ?>
                                        <a href="/reports/edit.php?id=<?= e((string)$r['report_id']) ?>" class="btn btn-secondary btn-sm">
                                            Edit
                                        </a>
                                    <?php endif; ?>
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
