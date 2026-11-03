<?php
/**
 * CampusSafe: Submit New Hazard Report
 */

require_once __DIR__ . '/../../src/config/Database.php';
require_once __DIR__ . '/../../src/auth/Auth.php';
require_once __DIR__ . '/../../src/auth/Csrf.php';
require_once __DIR__ . '/../../src/models/Report.php';
require_once __DIR__ . '/../../src/models/Category.php';
require_once __DIR__ . '/../../src/models/Location.php';
require_once __DIR__ . '/../../src/helpers/functions.php';

Auth::requireLogin();

$categories = Category::getAll(true);
$locations = Location::getAll(true);
$error = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    Csrf::enforce();

    $categoryId = (int)($_POST['category_id'] ?? 0);
    $locationId = (int)($_POST['location_id'] ?? 0);
    $description = trim($_POST['description'] ?? '');

    if ($categoryId <= 0 || $locationId <= 0 || empty($description)) {
        $error = 'Please fill out all required fields (Category, Location, and Description).';
    } elseif (strlen($description) < 10) {
        $error = 'Please provide a more descriptive summary of the hazard (at least 10 characters).';
    } else {
        try {
            $fileData = null;
            if (isset($_FILES['attachment']) && $_FILES['attachment']['error'] !== UPLOAD_ERR_NO_FILE) {
                $targetDir = dirname(__DIR__, 2) . '/uploads';
                $fileData = handleFileUpload($_FILES['attachment'], $targetDir);
            }

            $reportId = Report::create([
                'reporter_user_id' => Auth::id(),
                'category_id'      => $categoryId,
                'location_id'      => $locationId,
                'description'      => $description,
            ], $fileData);

            flash('success', "Hazard report #{$reportId} has been submitted successfully and entered the verification queue.");
            redirect("/reports/view.php?id={$reportId}");
        } catch (Exception $e) {
            $error = 'Failed to file report: ' . $e->getMessage();
        }
    }
}

$pageTitle = 'Submit Hazard Report';
require_once __DIR__ . '/../../src/helpers/header.php';
?>

<div style="max-width: 800px; margin: 1rem auto;">
    <div style="margin-bottom: 1.5rem;">
        <a href="/reports/list.php" class="btn btn-outline btn-sm">&larr; Back to Reports</a>
    </div>

    <div class="card">
        <div class="card-header">
            <h2>⚠️ File a Campus Safety or Hazard Report</h2>
        </div>
        <div class="card-body">
            <?php if ($error): ?>
                <div class="alert alert-danger"><?= e($error) ?></div>
            <?php endif; ?>

            <p style="color: #64748b; font-size: 0.95rem; margin-bottom: 1.5rem;">
                Please provide accurate details about the physical condition or safety risk.
                Our campus safety team will review the submission, classify priority, and dispatch maintenance technicians.
            </p>

            <form method="POST" action="/reports/new.php" enctype="multipart/form-data">
                <?= Csrf::field() ?>

                <div class="form-group">
                    <label for="category_id" class="form-label">Hazard Category <span style="color:#ef4444;">*</span></label>
                    <select name="category_id" id="category_id" class="form-select" required>
                        <option value="">-- Select a Category --</option>
                        <?php foreach ($categories as $cat): ?>
                            <option value="<?= e((string)$cat['category_id']) ?>" <?= (isset($_POST['category_id']) && (int)$_POST['category_id'] === (int)$cat['category_id']) ? 'selected' : '' ?>>
                                <?= e($cat['category_name']) ?> &mdash; <?= e($cat['description']) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>

                <div class="form-group">
                    <label for="location_id" class="form-label">Campus Location <span style="color:#ef4444;">*</span></label>
                    <select name="location_id" id="location_id" class="form-select" required>
                        <option value="">-- Select Specific Location --</option>
                        <?php foreach ($locations as $loc): ?>
                            <option value="<?= e((string)$loc['location_id']) ?>" <?= (isset($_POST['location_id']) && (int)$_POST['location_id'] === (int)$loc['location_id']) ? 'selected' : '' ?>>
                                <?= e($loc['building']) ?> [<?= e($loc['floor']) ?>] &bull; <?= e($loc['room_area']) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>

                <div class="form-group">
                    <label for="description" class="form-label">Detailed Description of the Hazard <span style="color:#ef4444;">*</span></label>
                    <textarea name="description" id="description" class="form-control" rows="5" required
                              placeholder="Describe what is wrong, exactly where it is located, and any immediate danger..."><?= e($_POST['description'] ?? '') ?></textarea>
                </div>

                <div class="form-group">
                    <label for="report_file_input" class="form-label">Photo or Document Evidence (Optional)</label>
                    <input type="file" name="attachment" id="report_file_input" class="form-control"
                           accept="image/jpeg,image/png,image/webp,application/pdf">
                    <small style="color: #64748b; display: block; margin-top: 0.35rem;">
                        Supported formats: JPG, PNG, WEBP, PDF (Max 5MB)
                    </small>

                    <!-- Preview Container -->
                    <div id="file_preview_container" style="display: none; margin-top: 1rem; padding: 0.75rem; background: #f8fafc; border: 1px dashed #cbd5e1; border-radius: 6px;">
                        <span id="preview_filename" style="font-size: 0.85rem; font-weight: 600; color: #334155;"></span>
                        <div style="margin-top: 0.5rem;">
                            <img id="preview_image" src="" alt="Preview" style="max-height: 180px; max-width: 100%; border-radius: 6px; display: none;">
                        </div>
                    </div>
                </div>

                <div style="display: flex; gap: 1rem; justify-content: flex-end; margin-top: 2rem;">
                    <a href="/reports/list.php" class="btn btn-secondary">Cancel</a>
                    <button type="submit" class="btn btn-primary" style="padding: 0.7rem 1.8rem;">
                        Submit Report
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>

<?php require_once __DIR__ . '/../../src/helpers/footer.php'; ?>
