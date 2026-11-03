<?php
/**
 * CampusSafe: Cross-Site Request Forgery (CSRF) Protection
 */

class Csrf
{
    private static function initSession(): void
    {
        if (session_status() === PHP_SESSION_NONE) {
            session_start();
        }
    }

    /**
     * Get or create a secure CSRF token in session
     */
    public static function getToken(): string
    {
        self::initSession();

        if (empty($_SESSION['csrf_token'])) {
            $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
        }

        return $_SESSION['csrf_token'];
    }

    /**
     * Validate an incoming CSRF token against session
     */
    public static function validateToken(?string $token): bool
    {
        self::initSession();

        if (empty($_SESSION['csrf_token']) || empty($token)) {
            return false;
        }

        return hash_equals($_SESSION['csrf_token'], $token);
    }

    /**
     * Generate hidden input field containing CSRF token
     */
    public static function field(): string
    {
        $token = htmlspecialchars(self::getToken(), ENT_QUOTES, 'UTF-8');
        return '<input type="hidden" name="csrf_token" value="' . $token . '">';
    }

    /**
     * Enforce token verification for POST requests, terminating execution if invalid
     */
    public static function enforce(): void
    {
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $token = $_POST['csrf_token'] ?? $_SERVER['HTTP_X_CSRF_TOKEN'] ?? null;
            if (!self::validateToken($token)) {
                http_response_code(403);
                die("<!DOCTYPE html><html><head><title>403 Forbidden</title></head><body style='font-family:sans-serif;text-align:center;padding:5rem;'><h1>403 Forbidden</h1><p>Invalid or expired CSRF security token. Please refresh the page and try again.</p><p><a href='javascript:history.back()'>Go Back</a></p></body></html>");
            }
        }
    }
}
