<?php
/**
 * CampusSafe: Authentication and Session Role Guard
 * 
 * Manages user logins, session state, role-based authorization,
 * password verification, and session fixation prevention.
 */

require_once __DIR__ . '/../config/Database.php';

class Auth
{
    /**
     * Start session with hardened cookie settings
     */
    public static function startSession(): void
    {
        if (session_status() === PHP_SESSION_NONE) {
            ini_set('session.cookie_httponly', '1');
            ini_set('session.use_only_cookies', '1');
            ini_set('session.cookie_samesite', 'Lax');
            session_start();
        }
    }

    /**
     * Attempt login with username or email and password
     */
    public static function login(string $usernameOrEmail, string $password): array
    {
        self::startSession();

        $pdo = Database::getConnection();
        $stmt = $pdo->prepare("
            SELECT u.user_id, u.role_id, r.role_name, u.full_name, u.email, u.username,
                   u.password_hash, u.account_status, u.created_at
            FROM app_user u
            JOIN role r ON u.role_id = r.role_id
            WHERE LOWER(u.username) = LOWER(:login) OR LOWER(u.email) = LOWER(:login)
            LIMIT 1
        ");
        $stmt->execute([':login' => trim($usernameOrEmail)]);
        $user = $stmt->fetch();

        if (!$user) {
            return ['success' => false, 'message' => 'Invalid username or password.'];
        }

        if ($user['account_status'] === 'inactive') {
            return ['success' => false, 'message' => 'This account has been deactivated. Please contact an administrator.'];
        }

        if ($user['account_status'] === 'suspended') {
            return ['success' => false, 'message' => 'This account is currently suspended. Access denied.'];
        }

        if (!password_verify($password, $user['password_hash'])) {
            return ['success' => false, 'message' => 'Invalid username or password.'];
        }

        // Prevent session fixation attacks
        session_regenerate_id(true);

        // Remove hash from session payload for defense-in-depth
        unset($user['password_hash']);
        $_SESSION['user'] = $user;

        return ['success' => true, 'user' => $user];
    }

    /**
     * Terminate the user session and clear session cookies
     */
    public static function logout(): void
    {
        self::startSession();
        $_SESSION = [];

        if (ini_get("session.use_cookies")) {
            $params = session_get_cookie_params();
            setcookie(
                session_name(),
                '',
                time() - 42000,
                $params["path"],
                $params["domain"],
                $params["secure"],
                $params["httponly"]
            );
        }

        session_destroy();
    }

    /**
     * Get the logged-in user array
     */
    public static function user(): ?array
    {
        self::startSession();
        return $_SESSION['user'] ?? null;
    }

    /**
     * Get the logged-in user ID
     */
    public static function id(): ?int
    {
        self::startSession();
        return isset($_SESSION['user']['user_id']) ? (int)$_SESSION['user']['user_id'] : null;
    }

    /**
     * Check if a user is authenticated
     */
    public static function check(): bool
    {
        self::startSession();
        return !empty($_SESSION['user']);
    }

    /**
     * Get current user role name
     */
    public static function role(): ?string
    {
        self::startSession();
        return $_SESSION['user']['role_name'] ?? null;
    }

    /**
     * Check if current user has any of the specified roles
     */
    public static function hasRole(string|array $roles): bool
    {
        self::startSession();
        if (!self::check()) {
            return false;
        }

        $userRole = self::role();
        $allowed = is_array($roles) ? $roles : [$roles];

        return in_array($userRole, $allowed, true);
    }

    /**
     * Require authentication; redirect to login if guest
     */
    public static function requireLogin(): void
    {
        self::startSession();
        if (!self::check()) {
            $_SESSION['flash_error'] = 'Please log in to access this page.';
            $_SESSION['intended_url'] = $_SERVER['REQUEST_URI'] ?? '/';
            header('Location: /login.php');
            exit;
        }
    }

    /**
     * Require specific role(s); abort with 403 Forbidden if unauthorized
     */
    public static function requireRole(string|array $roles): void
    {
        self::requireLogin();

        if (!self::hasRole($roles)) {
            http_response_code(403);
            $required = is_array($roles) ? implode(', ', $roles) : $roles;
            $current = self::role() ?? 'Guest';

            die("<!DOCTYPE html>
            <html>
            <head>
                <meta charset='UTF-8'>
                <title>403 Forbidden - CampusSafe</title>
                <style>
                    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #f8fafc; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
                    .card { background: #1e293b; padding: 2.5rem; border-radius: 12px; border: 1px solid #334155; max-width: 500px; text-align: center; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }
                    h1 { color: #ef4444; margin-top: 0; font-size: 2.2rem; }
                    p { color: #94a3b8; line-height: 1.6; }
                    .badge { display: inline-block; padding: 0.25rem 0.6rem; border-radius: 4px; font-size: 0.85rem; font-weight: 600; background: #334155; color: #38bdf8; }
                    .btn { display: inline-block; margin-top: 1.5rem; padding: 0.75rem 1.5rem; background: #2563eb; color: #fff; text-decoration: none; border-radius: 6px; font-weight: 500; transition: background 0.2s; }
                    .btn:hover { background: #1d4ed8; }
                </style>
            </head>
            <body>
                <div class='card'>
                    <h1>403 Forbidden</h1>
                    <p>You do not have administrative privilege to access this module.</p>
                    <p>Your current role is <span class='badge'>{$current}</span>.<br>Required role(s): <span class='badge'>{$required}</span></p>
                    <a href='/' class='btn'>Return to Dashboard</a>
                </div>
            </body>
            </html>");
        }
    }
}
