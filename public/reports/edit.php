<?php
/**
 * CampusSafe: Edit Pending Report
 */

require_once __DIR__ . '/../../src/config/Database.php';
require_once __DIR__ . '/../../src/auth/Auth.php';
require_once __DIR__ . '/../../src/auth/Csrf.php';
require_once __DIR__ . '/../../src/models/Report.php';
require_once __DIR__ . '/../../src/models/Category.php';
require_once __DIR__ . '/../../src/models/Location.php';
require_once __DIR__ . '/../../src/helpers/functions.php';

Auth::requireLogin();

$reportId = (int)($_GET['id'] ?? 0);
$report = Report::findById($reportId);

if (!$report) {
    flash('error', 'Report not found.');
    redirect('/reports/list.php');
}

// Can only edit own reports and only while still 'Submitted'
if ($report['reporter_user_id'] !== Auth::id()) {
    flash('error', 'You cannot edit reports filed by other users.');
    redirect('/reports/list.php');
}

if ($report['status'] !== 'Submitted') {
    flash('error', "Reports in '{$report['status']}' status cannot be edited. Only pending 'Submitted' reports may be modified.");
    redirect("/reports/view.php?id={$reportId}");
}

$categories = Category::getAll(true);
$locations = Location::getAll(true);
$error = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    Csrf::enforce();

    $categoryId = (int)($_POST['category_id'] ?? 0);
    $locationId = (int)($_POST['location_id'] ?? 0);
    $description = trim($_POST['description'] ?? '');

    if ($categoryId <= 0 || $locationId <= 0 || empty($description)) {
        $error = 'Please fill out all required fields.';
    } elseif (strlen($description) < 10) {
        $error = 'Please provide a descriptive explanation (at least 10 characters).';
    } else {
        try {
            $updated = Report::updatePending($reportId, Auth::id(), [
                'category_id' => $categoryId,
                'location_id' => $locationId,
                'description' => $description
            ]);

            if ($updated) {
                flash('success', "Report #{$reportId} was successfully updated.");
                redirect("/reports/view.php?id={$reportId}");
            } else {
                $error = 'Report could not be updated. It may have already been verified or changed status by an administrator.';
            }
        } catch (Exception $e) {
            $error = 'Update failed: ' . $e->getMessage();
        }
    }
}

$pageTitle = "Edit Report #{$reportId}";
require_once __DIR__ . '/../../src/helpers/header.php';
?>

<div style="max-width: 800px; margin: 1rem auto;">
    <div style="margin-bottom: 1.5rem;">
        <a href="/reports/view.php?id=<?= e((string)$reportId) ?>" class="btn btn-outline btn-sm">&larr; Back to Report</a>
    </div>

    <div class="card">
        <div class="card-header">
            <h2>Edit Pending Hazard Report #<?= e((string)$reportId) ?></h2>
        </div>
        <div class="card-body">
            <?php if ($error): ?>
                <div class="alert alert-danger"><?= e($error) ?></div>
            <?php endif; ?>

            <form method="POST" action="/reports/edit.php?id=<?= e((string)$reportId) ?>">
                <?= Csrf::field() ?>

                <div class="form-group">
                    <label for="category_id" class="form-label">Hazard Category</label>
                    <select name="category_id" id="category_id" class="form-select" required>
                        <?php foreach ($categories as $cat): ?>
                            <option value="<?= e((string)$cat['category_id']) ?>" <?= (int)$report['category_id'] === (int)$cat['category_id'] ? 'selected' : '' ?>>
                                <?= e($cat['category_name']) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>

                <div class="form-group">
                    <label for="location_id" class="form-label">Campus Location</label>
                    <select name="location_id" id="location_id" class="form-select" required>
                        <?php foreach ($locations as $loc): ?>
                            <option value="<?= e((string)$loc['location_id']) ?>" <?= (int)$report['location_id'] === (int)$loc['location_id'] ? 'selected' : '' ?>>
                                <?= e($loc['building']) ?> - <?= e($loc['room_area']) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>

                <div class="form-group">
                    <label for="description" class="form-label">Hazard Description</label>
                    <textarea name="description" id="description" class="form-control" rows="5" required><?= e($report['description']) ?></textarea>
                </div>

                <div style="display: flex; gap: 1rem; justify-content: flex-end; margin-top: 2rem;">
                    <a href="/reports/view.php?id=<?= e((string)$reportId) ?>" class="btn btn-secondary">Cancel</a>
                    <button type="submit" class="btn btn-primary">Save Changes</button>
                </div>
            </form>
        </div>
    </div>
</div>

<?php require_once __DIR__ . '/../../src/helpers/footer.php'; ?>
