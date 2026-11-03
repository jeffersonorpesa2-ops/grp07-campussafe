<?php
/**
 * CampusSafe: User Authentication Login Page
 */

require_once __DIR__ . '/../src/config/Database.php';
require_once __DIR__ . '/../src/auth/Auth.php';
require_once __DIR__ . '/../src/auth/Csrf.php';
require_once __DIR__ . '/../src/helpers/functions.php';

Auth::startSession();

// If already logged in, redirect to dashboard
if (Auth::check()) {
    redirect('/');
}

$error = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    Csrf::enforce();

    $username = trim($_POST['username'] ?? '');
    $password = $_POST['password'] ?? '';

    if (empty($username) || empty($password)) {
        $error = 'Please enter both your username/email and password.';
    } else {
        $result = Auth::login($username, $password);
        if ($result['success']) {
            flash('success', "Welcome back, {$result['user']['full_name']}!");
            $redirectUrl = $_SESSION['intended_url'] ?? '/';
            unset($_SESSION['intended_url']);
            redirect($redirectUrl);
        } else {
            $error = $result['message'];
        }
    }
}

$pageTitle = 'Sign In';
require_once __DIR__ . '/../src/helpers/header.php';
?>

<div style="max-width: 480px; margin: 2rem auto;">
    <div class="card" style="box-shadow: 0 10px 25px -5px rgba(0,0,0,0.1);">
        <div class="card-header" style="text-align: center; display: block; padding: 2rem 1.5rem 1rem;">
            <div style="font-size: 2.5rem; margin-bottom: 0.5rem;">🛡️</div>
            <h2 style="font-size: 1.5rem; margin-bottom: 0.25rem;">Sign In to CampusSafe</h2>
            <p style="color: #64748b; font-size: 0.9rem;">Enter your campus credentials to access the safety system.</p>
        </div>

        <div class="card-body" style="padding: 1.5rem 2rem 2rem;">
            <?php if ($error): ?>
                <div class="alert alert-danger" style="font-size: 0.9rem;">
                    <?= e($error) ?>
                </div>
            <?php endif; ?>

            <form method="POST" action="/login.php">
                <?= Csrf::field() ?>

                <div class="form-group">
                    <label for="username" class="form-label">Username or Campus Email</label>
                    <input type="text" id="username" name="username" class="form-control"
                           value="<?= e($_POST['username'] ?? '') ?>" required autofocus autocomplete="username"
                           placeholder="e.g. demo_admin or user@campussafe.edu">
                </div>

                <div class="form-group">
                    <label for="password" class="form-label">Password</label>
                    <input type="password" id="password" name="password" class="form-control"
                           required autocomplete="current-password" placeholder="••••••••">
                </div>

                <button type="submit" class="btn btn-primary" style="width: 100%; padding: 0.75rem; font-weight: 600;">
                    Sign In
                </button>
            </form>

            <div class="demo-switcher">
                <span style="font-size: 0.8rem; font-weight: 700; text-transform: uppercase; color: #475569;">
                    Quick Demo Logins (Click to autofill)
                </span>
                <div class="demo-btn-group">
                    <button type="button" class="btn btn-sm btn-outline demo-login-btn"
                            data-user="demo_admin" data-pass="Password123!">
                        👑 Administrator
                    </button>
                    <button type="button" class="btn btn-sm btn-outline demo-login-btn"
                            data-user="demo_maint1" data-pass="Password123!">
                        🔧 Maintenance
                    </button>
                    <button type="button" class="btn btn-sm btn-outline demo-login-btn"
                            data-user="demo_student" data-pass="Password123!">
                        🎓 Student Reporter
                    </button>
                    <button type="button" class="btn btn-sm btn-outline demo-login-btn"
                            data-user="demo_auditor" data-pass="Password123!">
                        📋 Safety Auditor
                    </button>
                </div>
                <p style="font-size: 0.78rem; color: #64748b; margin-top: 0.5rem;">
                    Demo password for all accounts: <code>Password123!</code>
                </p>
            </div>
        </div>
    </div>
</div>

<?php require_once __DIR__ . '/../src/helpers/footer.php'; ?>
