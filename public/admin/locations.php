<?php
/**
 * CampusSafe: Admin Campus Location Management
 * Phase 3, Step 10: Master data CRUD with soft deactivation
 */

require_once __DIR__ . '/../../src/config/Database.php';
require_once __DIR__ . '/../../src/auth/Auth.php';
require_once __DIR__ . '/../../src/auth/Csrf.php';
require_once __DIR__ . '/../../src/models/Location.php';
require_once __DIR__ . '/../../src/helpers/functions.php';

Auth::requireRole('Administrator');

$editId = (int)($_GET['edit'] ?? 0);
$editLocation = $editId > 0 ? Location::findById($editId) : null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    Csrf::enforce();
    $action = $_POST['action'] ?? '';

    try {
        if ($action === 'create') {
            $building = trim($_POST['building'] ?? '');
            $floor = trim($_POST['floor'] ?? '');
            $room = trim($_POST['room_area'] ?? '');
            $desc = trim($_POST['location_description'] ?? '');

            if (empty($building) || empty($room)) {
                flash('error', 'Building and Room/Area are required.');
            } else {
                Location::create([
                    'building'             => $building,
                    'floor'                => $floor,
                    'room_area'            => $room,
                    'location_description' => $desc,
                    'is_active'            => isset($_POST['is_active'])
                ]);
                flash('success', "Location '{$building} - {$room}' created.");
                redirect('/admin/locations.php');
            }
        } elseif ($action === 'update' && $editLocation) {
            $building = trim($_POST['building'] ?? '');
            $floor = trim($_POST['floor'] ?? '');
            $room = trim($_POST['room_area'] ?? '');
            $desc = trim($_POST['location_description'] ?? '');

            Location::update($editLocation['location_id'], [
                'building'             => $building,
                'floor'                => $floor,
                'room_area'            => $room,
                'location_description' => $desc,
                'is_active'            => isset($_POST['is_active'])
            ]);
            flash('success', "Location updated successfully.");
            redirect('/admin/locations.php');
        } elseif ($action === 'toggle_active') {
            $locId = (int)($_POST['location_id'] ?? 0);
            Location::toggleActive($locId);
            flash('success', 'Location status toggled.');
            redirect('/admin/locations.php');
        }
    } catch (Exception $e) {
        flash('error', 'Operation failed: ' . $e->getMessage());
    }
}

$locations = Location::getAll();

$pageTitle = 'Campus Locations';
require_once __DIR__ . '/../../src/helpers/header.php';
?>

<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem;">
    <div>
        <h1 style="font-size: 1.8rem; font-weight: 700;">Campus Physical Locations</h1>
        <p style="color: #64748b;">Configure buildings, floor levels, and specialized hazard report zones.</p>
    </div>
</div>

<!-- Edit / Create Form -->
<div class="card" style="margin-bottom: 2rem;">
    <div class="card-header" style="background: <?= $editLocation ? '#e0f2fe' : '#f8fafc' ?>;">
        <h3><?= $editLocation ? 'Edit Location #' . e((string)$editLocation['location_id']) : '+ Add New Campus Location' ?></h3>
        <?php if ($editLocation): ?>
            <a href="/admin/locations.php" class="btn btn-secondary btn-sm">Cancel Edit</a>
        <?php endif; ?>
    </div>
    <div class="card-body">
        <form method="POST" action="/admin/locations.php<?= $editLocation ? '?edit=' . e((string)$editLocation['location_id']) : '' ?>">
            <?= Csrf::field() ?>
            <input type="hidden" name="action" value="<?= $editLocation ? 'update' : 'create' ?>">

            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem;">
                <div class="form-group">
                    <label class="form-label">Building / Facility <span style="color:#ef4444;">*</span></label>
                    <input type="text" name="building" class="form-control" required
                           value="<?= e($editLocation['building'] ?? '') ?>" placeholder="e.g. Science Complex">
                </div>

                <div class="form-group">
                    <label class="form-label">Floor / Level</label>
                    <input type="text" name="floor" class="form-control"
                           value="<?= e($editLocation['floor'] ?? '') ?>" placeholder="e.g. 3rd Floor or Basement">
                </div>

                <div class="form-group">
                    <label class="form-label">Room / Area Identifier <span style="color:#ef4444;">*</span></label>
                    <input type="text" name="room_area" class="form-control" required
                           value="<?= e($editLocation['room_area'] ?? '') ?>" placeholder="e.g. Room 304 or West Stairwell">
                </div>

                <div class="form-group">
                    <label class="form-label">Location Notes / Landmarks</label>
                    <input type="text" name="location_description" class="form-control"
                           value="<?= e($editLocation['location_description'] ?? '') ?>" placeholder="e.g. Near north emergency exit">
                </div>
            </div>

            <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 1rem;">
                <label style="display: flex; align-items: center; gap: 0.5rem; cursor: pointer;">
                    <input type="checkbox" name="is_active" value="1"
                           <?= (!$editLocation || $editLocation['is_active']) ? 'checked' : '' ?>>
                    <span style="font-size: 0.9rem; font-weight: 600;">Location Active for Reporting</span>
                </label>

                <button type="submit" class="btn btn-primary">
                    <?= $editLocation ? 'Update Location' : 'Save Location' ?>
                </button>
            </div>
        </form>
    </div>
</div>

<!-- Locations Table -->
<div class="card">
    <div class="card-header">
        <h3>Registered Locations (<?= count($locations) ?>)</h3>
    </div>
    <div class="card-body" style="padding: 0;">
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th style="width: 60px;">ID</th>
                        <th>Building</th>
                        <th>Floor</th>
                        <th>Room / Area</th>
                        <th>Landmarks</th>
                        <th>Status</th>
                        <th style="text-align: right;">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($locations as $loc): ?>
                        <tr>
                            <td>#<?= e((string)$loc['location_id']) ?></td>
                            <td><strong><?= e($loc['building']) ?></strong></td>
                            <td><?= e($loc['floor'] ?? '—') ?></td>
                            <td><?= e($loc['room_area']) ?></td>
                            <td style="color: #64748b; font-size: 0.88rem;"><?= e($loc['location_description'] ?? '—') ?></td>
                            <td>
                                <?php if ($loc['is_active']): ?>
                                    <span class="status-badge badge-status-resolved">Active</span>
                                <?php else: ?>
                                    <span class="status-badge badge-status-closed">Inactive</span>
                                <?php endif; ?>
                            </td>
                            <td style="text-align: right; white-space: nowrap;">
                                <a href="/admin/locations.php?edit=<?= e((string)$loc['location_id']) ?>" class="btn btn-outline btn-sm">Edit</a>
                                <form method="POST" action="/admin/locations.php" style="display: inline-block;">
                                    <?= Csrf::field() ?>
                                    <input type="hidden" name="action" value="toggle_active">
                                    <input type="hidden" name="location_id" value="<?= e((string)$loc['location_id']) ?>">
                                    <button type="submit" class="btn btn-secondary btn-sm">
                                        <?= $loc['is_active'] ? 'Deactivate' : 'Activate' ?>
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
