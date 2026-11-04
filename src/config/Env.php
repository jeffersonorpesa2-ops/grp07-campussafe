<?php
/**
 * CampusSafe: Lightweight Environment Configuration Loader
 */

class Env
{
    private static array $variables = [];
    private static bool $loaded = false;

    /**
     * Load environment variables from a .env file
     */
    public static function load(string $filePath): void
    {
        if (self::$loaded && !empty(self::$variables)) {
            return;
        }

        if (!file_exists($filePath)) {
            return;
        }

        $lines = file($filePath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        if ($lines === false) {
            return;
        }

        foreach ($lines as $line) {
            $line = trim($line);
            if ($line === '' || str_starts_with($line, '#')) {
                continue;
            }

            $parts = explode('=', $line, 2);
            if (count($parts) === 2) {
                $key = trim($parts[0]);
                $val = trim($parts[1]);

                // Remove surrounding quotes if present
                if ((str_starts_with($val, '"') && str_ends_with($val, '"')) ||
                    (str_starts_with($val, "'") && str_ends_with($val, "'"))) {
                    $val = substr($val, 1, -1);
                } else {
                    // Strip unquoted inline comments (e.g. "5432 # comment" -> "5432")
                    if (str_contains($val, '#')) {
                        $commentPos = strpos($val, '#');
                        $val = trim(substr($val, 0, $commentPos));
                    }
                }

                self::$variables[$key] = $val;
                if (!array_key_exists($key, $_ENV)) {
                    $_ENV[$key] = $val;
                }
            }
        }

        self::$loaded = true;
    }

    /**
     * Get an environment variable with optional fallback
     */
    public static function get(string $key, mixed $default = null): mixed
    {
        if (isset(self::$variables[$key])) {
            return self::$variables[$key];
        }

        $envVal = getenv($key);
        if ($envVal !== false) {
            return $envVal;
        }

        return $default;
    }
}
