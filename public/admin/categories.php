<?php
/**
 * CampusSafe: Admin Hazard Category Management
 * Phase 3, Step 10: Master data CRUD with soft deactivation
 */

require_once __DIR__ . '/../../src/config/Database.php';
require_once __DIR__ . '/../../src/auth/Auth.php';
require_once __DIR__ . '/../../src/auth/Csrf.php';
require_once __DIR__ . '/../../src/models/Category.php';
require_once __DIR__ . '/../../src/helpers/functions.php';

Auth::requireRole('Administrator');

$editId = (int)($_GET['edit'] ?? 0);
$editCategory = $editId > 0 ? Category::findById($editId) : null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    Csrf::enforce();
    $action = $_POST['action'] ?? '';

    try {
        if ($action === 'create') {
            $name = trim($_POST['category_name'] ?? '');
            $desc = trim($_POST['description'] ?? '');

            if (empty($name)) {
                flash('error', 'Category name is required.');
            } else {
                Category::create([
                    'category_name' => $name,
                    'description'   => $desc,
                    'is_active'     => isset($_POST['is_active'])
                ]);
                flash('success', "Category '{$name}' created successfully.");
                redirect('/admin/categories.php');
            }
        } elseif ($action === 'update' && $editCategory) {
            $name = trim($_POST['category_name'] ?? '');
            $desc = trim($_POST['description'] ?? '');

            Category::update($editCategory['category_id'], [
                'category_name' => $name,
                'description'   => $desc,
                'is_active'     => isset($_POST['is_active'])
            ]);
            flash('success', "Category '{$name}' updated successfully.");
            redirect('/admin/categories.php');
        } elseif ($action === 'toggle_active') {
            $catId = (int)($_POST['category_id'] ?? 0);
            Category::toggleActive($catId);
            flash('success', 'Category status toggled.');
            redirect('/admin/categories.php');
        }
    } catch (Exception $e) {
        flash('error', 'Operation failed: ' . $e->getMessage());
    }
}

$categories = Category::getAll();

$pageTitle = 'Hazard Categories';
require_once __DIR__ . '/../../src/helpers/header.php';
?>

<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem;">
    <div>
        <h1 style="font-size: 1.8rem; font-weight: 700;">Hazard Categories</h1>
        <p style="color: #64748b;">Manage safety hazard taxonomy and classifications.</p>
    </div>
</div>

<!-- Edit / Create Form -->
<div class="card" style="margin-bottom: 2rem;">
    <div class="card-header" style="background: <?= $editCategory ? '#e0f2fe' : '#f8fafc' ?>;">
        <h3><?= $editCategory ? 'Edit Category: ' . e($editCategory['category_name']) : '+ Add New Hazard Category' ?></h3>
        <?php if ($editCategory): ?>
            <a href="/admin/categories.php" class="btn btn-secondary btn-sm">Cancel Edit</a>
        <?php endif; ?>
    </div>
    <div class="card-body">
        <form method="POST" action="/admin/categories.php<?= $editCategory ? '?edit=' . e((string)$editCategory['category_id']) : '' ?>">
            <?= Csrf::field() ?>
            <input type="hidden" name="action" value="<?= $editCategory ? 'update' : 'create' ?>">

            <div style="display: grid; grid-template-columns: 1fr 2fr auto; gap: 1rem; align-items: end;">
                <div class="form-group" style="margin-bottom: 0;">
                    <label class="form-label">Category Name <span style="color:#ef4444;">*</span></label>
                    <input type="text" name="category_name" class="form-control" required
                           value="<?= e($editCategory['category_name'] ?? '') ?>" placeholder="e.g. Chemical Safety">
                </div>

                <div class="form-group" style="margin-bottom: 0;">
                    <label class="form-label">Scope Description</label>
                    <input type="text" name="description" class="form-control"
                           value="<?= e($editCategory['description'] ?? '') ?>" placeholder="Brief description of hazard type">
                </div>

                <div class="form-group" style="margin-bottom: 0;">
                    <label style="display: flex; align-items: center; gap: 0.5rem; cursor: pointer; padding-bottom: 0.5rem;">
                        <input type="checkbox" name="is_active" value="1"
                               <?= (!$editCategory || $editCategory['is_active']) ? 'checked' : '' ?>>
                        <span style="font-size: 0.9rem; font-weight: 600;">Active</span>
                    </label>
                </div>
            </div>

            <div style="text-align: right; margin-top: 1.25rem;">
                <button type="submit" class="btn btn-primary">
                    <?= $editCategory ? 'Update Category' : 'Save Category' ?>
                </button>
            </div>
        </form>
    </div>
</div>

<!-- Categories Table -->
<div class="card">
    <div class="card-header">
        <h3>Master Categories Registry (<?= count($categories) ?>)</h3>
    </div>
    <div class="card-body" style="padding: 0;">
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th style="width: 60px;">ID</th>
                        <th>Category Name</th>
                        <th>Description</th>
                        <th>Status</th>
                        <th style="text-align: right;">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($categories as $cat): ?>
                        <tr>
                            <td>#<?= e((string)$cat['category_id']) ?></td>
                            <td><strong><?= e($cat['category_name']) ?></strong></td>
                            <td style="color: #64748b;"><?= e($cat['description'] ?? '—') ?></td>
                            <td>
                                <?php if ($cat['is_active']): ?>
                                    <span class="status-badge badge-status-resolved">Active</span>
                                <?php else: ?>
                                    <span class="status-badge badge-status-closed">Inactive</span>
                                <?php endif; ?>
                            </td>
                            <td style="text-align: right; white-space: nowrap;">
                                <a href="/admin/categories.php?edit=<?= e((string)$cat['category_id']) ?>" class="btn btn-outline btn-sm">Edit</a>
                                <form method="POST" action="/admin/categories.php" style="display: inline-block;">
                                    <?= Csrf::field() ?>
                                    <input type="hidden" name="action" value="toggle_active">
                                    <input type="hidden" name="category_id" value="<?= e((string)$cat['category_id']) ?>">
                                    <button type="submit" class="btn btn-secondary btn-sm">
                                        <?= $cat['is_active'] ? 'Deactivate' : 'Activate' ?>
                                    </button>
                                </form>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
</div>

<?php require_once __DIR__ . '/../../src/helpers/footer.php'; ?>
