<?php
/**
 * CampusSafe: Shared Header Layout
 */

require_once __DIR__ . '/functions.php';
require_once __DIR__ . '/../auth/Auth.php';

$currentUser = Auth::user();
$currentRole = Auth::role();
$pageTitle = $pageTitle ?? 'Campus Hazard & Safety Reporting';

// Current script detection for active navbar link highlighting
$currentUri = $_SERVER['REQUEST_URI'] ?? '';
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= e($pageTitle) ?> — CampusSafe</title>
    <link rel="stylesheet" href="/assets/css/style.css?v=<?= time() ?>">
</head>
<body>
    <header class="navbar">
        <div class="nav-container">
            <!-- Left: Brand Logo & Main Navigation -->
            <div class="nav-left">
                <a href="/" class="navbar-brand" title="CampusSafe Portal Home">
                    <span class="shield-icon">🛡️</span>
                    <span class="brand-text">Campus<span class="brand-accent">Safe</span></span>
                </a>

                <div class="nav-divider"></div>

                <ul class="nav-menu">
                    <li>
                        <a href="/" class="nav-link <?= ($currentUri === '/' || $currentUri === '/index.php') ? 'active' : '' ?>">
                            Home
                        </a>
                    </li>

                    <?php if (!$currentUser): ?>
                        <li><a href="/reports/new.php" class="nav-link <?= str_contains($currentUri, 'new.php') ? 'active' : '' ?>">Submit Report</a></li>
                    <?php else: ?>
                        <?php if ($currentRole === 'Administrator'): ?>
                            <li>
                                <a href="/admin/verify.php" class="nav-link <?= str_contains($currentUri, 'verify.php') ? 'active' : '' ?>">
                                    Verify Queue
                                </a>
                            </li>
                            <li>
                                <a href="/admin/assign.php" class="nav-link <?= str_contains($currentUri, 'assign.php') ? 'active' : '' ?>">
                                    Assignments
                                </a>
                            </li>
                            <li>
                                <a href="/reports/list.php" class="nav-link <?= (str_contains($currentUri, 'reports/list.php') && !str_contains($currentUri, 'admin/')) ? 'active' : '' ?>">
                                    All Reports
                                </a>
                            </li>
                            <li>
                                <a href="/admin/stats.php" class="nav-link <?= str_contains($currentUri, 'stats.php') ? 'active' : '' ?>">
                                    Statistics
                                </a>
                            </li>

                            <!-- Admin Master Data Dropdown -->
                            <li class="nav-dropdown">
                                <button type="button" class="nav-link dropdown-toggle <?= (str_contains($currentUri, 'users.php') || str_contains($currentUri, 'categories.php') || str_contains($currentUri, 'locations.php')) ? 'active' : '' ?>">
                                    Manage <span class="dropdown-arrow">▾</span>
                                </button>
                                <div class="dropdown-menu">
                                    <a href="/admin/users.php" class="dropdown-item <?= str_contains($currentUri, 'users.php') ? 'active' : '' ?>">
                                        <span class="dropdown-icon">👥</span> Users &amp; Accounts
                                    </a>
                                    <a href="/admin/categories.php" class="dropdown-item <?= str_contains($currentUri, 'categories.php') ? 'active' : '' ?>">
                                        <span class="dropdown-icon">🏷️</span> Hazard Categories
                                    </a>
                                    <a href="/admin/locations.php" class="dropdown-item <?= str_contains($currentUri, 'locations.php') ? 'active' : '' ?>">
                                        <span class="dropdown-icon">🏛️</span> Campus Locations
                                    </a>
                                </div>
                            </li>

                        <?php elseif ($currentRole === 'Maintenance'): ?>
                            <li>
                                <a href="/maintenance/index.php" class="nav-link <?= str_contains($currentUri, 'maintenance') ? 'active' : '' ?>">
                                    My Work Queue
                                </a>
                            </li>
                            <li>
                                <a href="/reports/list.php" class="nav-link <?= str_contains($currentUri, 'reports/list.php') ? 'active' : '' ?>">
                                    Browse Hazards
                                </a>
                            </li>

                        <?php elseif ($currentRole === 'Auditor'): ?>
                            <li>
                                <a href="/reports/list.php" class="nav-link <?= str_contains($currentUri, 'reports/list.php') ? 'active' : '' ?>">
                                    Reports Registry
                                </a>
                            </li>
                            <li>
                                <a href="/admin/stats.php" class="nav-link <?= str_contains($currentUri, 'stats.php') ? 'active' : '' ?>">
                                    Safety Analytics
                                </a>
                            </li>

                        <?php else: /* Student / Faculty / Staff */ ?>
                            <li>
                                <a href="/reports/new.php" class="nav-link <?= str_contains($currentUri, 'new.php') ? 'active' : '' ?>">
                                    + Submit Hazard
                                </a>
                            </li>
                            <li>
                                <a href="/reports/list.php" class="nav-link <?= str_contains($currentUri, 'reports/list.php') ? 'active' : '' ?>">
                                    My Reports
                                </a>
                            </li>
                        <?php endif; ?>
                    <?php endif; ?>
                </ul>
            </div>

            <!-- Right: User Identity & Actions -->
            <div class="nav-right">
                <?php if (!$currentUser): ?>
                    <a href="/login.php" class="btn btn-primary btn-sm">Sign In</a>
                <?php else: ?>
                    <div class="user-badge" title="Logged in as <?= e($currentUser['username']) ?>">
                        <span class="user-avatar">👤</span>
                        <span class="user-name"><?= e($currentUser['full_name']) ?></span>
                        <span class="role-tag"><?= e($currentRole) ?></span>
                    </div>
                    <a href="/logout.php" class="btn-logout" title="Sign out of CampusSafe">
                        Sign Out
                    </a>
                <?php endif; ?>
            </div>
        </div>
    </header>

    <div class="main-content">
        <div class="container">
            <?= renderFlashMessages() ?>
