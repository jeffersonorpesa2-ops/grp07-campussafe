<?php
/**
 * CampusSafe: Admin User Management Module
 * Phase 3, Step 10: CRUD operations with soft deactivation
 */

require_once __DIR__ . '/../../src/config/Database.php';
require_once __DIR__ . '/../../src/auth/Auth.php';
require_once __DIR__ . '/../../src/auth/Csrf.php';
require_once __DIR__ . '/../../src/models/User.php';
require_once __DIR__ . '/../../src/helpers/functions.php';

Auth::requireRole('Administrator');

$editId = (int)($_GET['edit'] ?? 0);
$editUser = $editId > 0 ? User::findById($editId) : null;
$roles = User::getAllRoles();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    Csrf::enforce();
    $action = $_POST['action'] ?? '';

    try {
        if ($action === 'create') {
            $roleId = (int)($_POST['role_id'] ?? 0);
            $fullName = trim($_POST['full_name'] ?? '');
            $email = trim($_POST['email'] ?? '');
            $username = trim($_POST['username'] ?? '');
            $password = $_POST['password'] ?? '';

            if ($roleId <= 0 || empty($fullName) || empty($email) || empty($username) || empty($password)) {
                flash('error', 'All fields are required when creating a new user.');
            } else {
                $newId = User::create([
                    'role_id'        => $roleId,
                    'full_name'      => $fullName,
                    'email'          => $email,
                    'username'       => $username,
                    'password'       => $password,
                    'account_status' => 'active'
                ]);
                flash('success', "User '{$username}' successfully created (ID #{$newId}).");
                redirect('/admin/users.php');
            }
        } elseif ($action === 'update' && $editUser) {
            $roleId = (int)($_POST['role_id'] ?? 0);
            $fullName = trim($_POST['full_name'] ?? '');
            $email = trim($_POST['email'] ?? '');
            $status = trim($_POST['account_status'] ?? 'active');

            User::update($editUser['user_id'], [
                'role_id'        => $roleId,
                'full_name'      => $fullName,
                'email'          => $email,
                'account_status' => $status
            ]);

            // Optional password update if provided
            $newPass = $_POST['new_password'] ?? '';
            if (!empty($newPass)) {
                User::changePassword($editUser['user_id'], $newPass);
            }

            flash('success', "User '{$editUser['username']}' updated successfully.");
            redirect('/admin/users.php');
        } elseif ($action === 'toggle_status') {
            $userId = (int)($_POST['user_id'] ?? 0);
            $targetStatus = trim($_POST['status'] ?? 'active');

            if ($userId === Auth::id()) {
                flash('error', 'You cannot alter your own administrative account status.');
            } else {
                User::setStatus($userId, $targetStatus);
                flash('success', "User account status updated to '{$targetStatus}'.");
            }
            redirect('/admin/users.php');
        }
    } catch (Exception $e) {
        flash('error', 'Operation failed: ' . $e->getMessage());
    }
}

$users = User::getAll();

$pageTitle = 'User Management';
require_once __DIR__ . '/../../src/helpers/header.php';
?>

<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem;">
    <div>
        <h1 style="font-size: 1.8rem; font-weight: 700;">CampusSafe User Accounts</h1>
        <p style="color: #64748b;">Manage user profiles, authorization roles, and account security states.</p>
    </div>
</div>

<!-- Edit or Create Card -->
<div class="card" style="margin-bottom: 2rem;">
    <div class="card-header" style="background: <?= $editUser ? '#e0f2fe' : '#f8fafc' ?>;">
        <h3><?= $editUser ? 'Edit User: ' . e($editUser['username']) : '+ Create New User Account' ?></h3>
        <?php if ($editUser): ?>
            <a href="/admin/users.php" class="btn btn-secondary btn-sm">Cancel Edit</a>
        <?php endif; ?>
    </div>
    <div class="card-body">
        <form method="POST" action="/admin/users.php<?= $editUser ? '?edit=' . e((string)$editUser['user_id']) : '' ?>">
            <?= Csrf::field() ?>
            <input type="hidden" name="action" value="<?= $editUser ? 'update' : 'create' ?>">

            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 1rem;">
                <div class="form-group">
                    <label class="form-label">Full Name <span style="color:#ef4444;">*</span></label>
                    <input type="text" name="full_name" class="form-control" required
                           value="<?= e($editUser['full_name'] ?? $_POST['full_name'] ?? '') ?>" placeholder="e.g. Jane Doe">
                </div>

                <div class="form-group">
                    <label class="form-label">Email Address <span style="color:#ef4444;">*</span></label>
                    <input type="email" name="email" class="form-control" required
                           value="<?= e($editUser['email'] ?? $_POST['email'] ?? '') ?>" placeholder="jane@campussafe.edu">
                </div>

                <div class="form-group">
                    <label class="form-label">Username <span style="color:#ef4444;">*</span></label>
                    <input type="text" name="username" class="form-control" required
                           <?= $editUser ? 'readonly style="background:#f1f5f9;"' : '' ?>
                           value="<?= e($editUser['username'] ?? $_POST['username'] ?? '') ?>" placeholder="jdoe">
                </div>

                <div class="form-group">
                    <label class="form-label">Authorization Role <span style="color:#ef4444;">*</span></label>
                    <select name="role_id" class="form-select" required>
                        <?php foreach ($roles as $r): ?>
                            <option value="<?= e((string)$r['role_id']) ?>"
                                <?= ($editUser && (int)$editUser['role_id'] === (int)$r['role_id']) ? 'selected' : '' ?>>
                                <?= e($r['role_name']) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>

                <?php if ($editUser): ?>
                    <div class="form-group">
                        <label class="form-label">Account Status</label>
                        <select name="account_status" class="form-select">
                            <option value="active" <?= $editUser['account_status'] === 'active' ? 'selected' : '' ?>>Active</option>
                            <option value="inactive" <?= $editUser['account_status'] === 'inactive' ? 'selected' : '' ?>>Inactive (Deactivated)</option>
                            <option value="suspended" <?= $editUser['account_status'] === 'suspended' ? 'selected' : '' ?>>Suspended</option>
                        </select>
                    </div>

                    <div class="form-group">
                        <label class="form-label">New Password (leave blank to keep unchanged)</label>
                        <input type="password" name="new_password" class="form-control" placeholder="••••••••">
                    </div>
                <?php else: ?>
                    <div class="form-group">
                        <label class="form-label">Initial Password <span style="color:#ef4444;">*</span></label>
                        <input type="password" name="password" class="form-control" required placeholder="Minimum 8 characters">
                    </div>
                <?php endif; ?>
            </div>

            <div style="text-align: right; margin-top: 1rem;">
                <button type="submit" class="btn btn-primary">
                    <?= $editUser ? 'Save User Changes' : 'Create User Account' ?>
                </button>
            </div>
        </form>
    </div>
</div>

<!-- Users Table -->
<div class="card">
    <div class="card-header">
        <h3>System Users (<?= count($users) ?>)</h3>
    </div>
    <div class="card-body" style="padding: 0;">
        <div class="table-responsive">
            <table class="table">
                <thead>
                    <tr>
                        <th style="width: 60px;">ID</th>
                        <th>User</th>
                        <th>Role</th>
                        <th>Email</th>
                        <th>Account Status</th>
                        <th>Created</th>
                        <th style="text-align: right;">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($users as $u): ?>
                        <tr>
                            <td>#<?= e((string)$u['user_id']) ?></td>
                            <td>
                                <strong><?= e($u['full_name']) ?></strong><br>
                                <small style="color: #64748b;">@<?= e($u['username']) ?></small>
                            </td>
                            <td>
                                <span class="role-tag" style="background:#0f172a; color:#fff; font-size:0.75rem; padding:0.2rem 0.5rem; border-radius:4px;">
                                    <?= e($u['role_name']) ?>
                                </span>
                            </td>
                            <td><?= e($u['email']) ?></td>
                            <td>
                                <?php if ($u['account_status'] === 'active'): ?>
                                    <span class="status-badge badge-status-resolved">Active</span>
                                <?php elseif ($u['account_status'] === 'inactive'): ?>
                                    <span class="status-badge badge-status-closed">Inactive</span>
                                <?php else: ?>
                                    <span class="status-badge badge-status-submitted">Suspended</span>
                                <?php endif; ?>
                            </td>
                            <td><?= formatDate($u['created_at'], 'M d, Y') ?></td>
                            <td style="text-align: right; white-space: nowrap;">
                                <a href="/admin/users.php?edit=<?= e((string)$u['user_id']) ?>" class="btn btn-outline btn-sm">Edit</a>
                                
                                <?php if ($u['user_id'] !== Auth::id()): ?>
                                    <form method="POST" action="/admin/users.php" style="display: inline-block;">
                                        <?= Csrf::field() ?>
                                        <input type="hidden" name="action" value="toggle_status">
                                        <input type="hidden" name="user_id" value="<?= e((string)$u['user_id']) ?>">
                                        <?php if ($u['account_status'] === 'active'): ?>
                                            <input type="hidden" name="status" value="inactive">
                                            <button type="submit" class="btn btn-secondary btn-sm" data-confirm="Deactivate this user account?">Deactivate</button>
                                        <?php else: ?>
                                            <input type="hidden" name="status" value="active">
                                            <button type="submit" class="btn btn-success btn-sm">Activate</button>
                                        <?php endif; ?>
                                    </form>
                                <?php endif; ?>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
</div>

<?php require_once __DIR__ . '/../../src/helpers/footer.php'; ?>
