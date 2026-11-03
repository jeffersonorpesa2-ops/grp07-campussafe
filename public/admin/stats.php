<?php
/**
 * CampusSafe: System Statistics & Analytics Dashboard
 * Phase 3, Step 9: Visual safety analytics across statuses, categories, and buildings
 */

require_once __DIR__ . '/../../src/config/Database.php';
require_once __DIR__ . '/../../src/auth/Auth.php';
require_once __DIR__ . '/../../src/models/Report.php';
require_once __DIR__ . '/../../src/helpers/functions.php';

Auth::requireRole(['Administrator', 'Auditor']);

$stats = Report::getStatistics();
$total = $stats['total_reports'] ?: 1; // avoid division by zero
$resolved = ($stats['by_status']['Resolved'] ?? 0) + ($stats['by_status']['Closed'] ?? 0);
$resolveRate = round(($resolved / $total) * 100, 1);

$pageTitle = 'Safety Statistics & Analytics';
require_once __DIR__ . '/../../src/helpers/header.php';
?>

<div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 2rem;">
    <div>
        <h1 style="font-size: 1.8rem; font-weight: 700;">Campus Safety &amp; Hazard Analytics</h1>
        <p style="color: #64748b;">Comprehensive health and resolution metrics for safety administration and audit compliance.</p>
    </div>
    <button onclick="window.print()" class="btn btn-outline btn-sm">🖨️ Print / Export Report</button>
</div>

<!-- Primary KPIs -->
<div class="metrics-grid">
    <div class="metric-card">
        <span class="metric-label">Total Hazards Logged</span>
        <div class="metric-value"><?= e((string)$stats['total_reports']) ?></div>
        <span class="metric-sub">Complete historical archive</span>
    </div>

    <div class="metric-card" style="border-left: 4px solid var(--status-submitted);">
        <span class="metric-label">Unresolved / Open</span>
        <div class="metric-value" style="color: #d97706;">
            <?= e((string)($stats['total_reports'] - $resolved)) ?>
        </div>
        <span class="metric-sub">Submitted, Verified, or In Progress</span>
    </div>

    <div class="metric-card" style="border-left: 4px solid var(--status-resolved);">
        <span class="metric-label">Remediated &amp; Closed</span>
        <div class="metric-value" style="color: #059669;"><?= e((string)$resolved) ?></div>
        <span class="metric-sub">Resolved + Closed</span>
    </div>

    <div class="metric-card" style="border-left: 4px solid var(--primary);">
        <span class="metric-label">Resolution Rate</span>
        <div class="metric-value" style="color: var(--primary);"><?= e((string)$resolveRate) ?>%</div>
        <span class="metric-sub">Campus compliance benchmark</span>
    </div>
</div>

<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(450px, 1fr)); gap: 1.5rem; margin-bottom: 2rem;">
    <!-- Status Distribution -->
    <div class="card">
        <div class="card-header">
            <h3>Lifecycle Status Distribution</h3>
        </div>
        <div class="card-body">
            <?php
            $statusOrder = ['Submitted', 'Verified', 'Assigned', 'In Progress', 'Resolved', 'Closed'];
            foreach ($statusOrder as $st):
                $count = $stats['by_status'][$st] ?? 0;
                $pct = round(($count / $total) * 100, 1);
            ?>
                <div style="margin-bottom: 1rem;">
                    <div style="display: flex; justify-content: space-between; margin-bottom: 0.25rem;">
                        <span><?= statusBadge($st) ?></span>
                        <span style="font-weight: 600; font-size: 0.9rem;"><?= $count ?> <small style="color:#64748b;">(<?= $pct ?>%)</small></span>
                    </div>
                    <div style="background: #e2e8f0; height: 8px; border-radius: 9999px; overflow: hidden;">
                        <div style="width: <?= $pct ?>%; height: 100%; background: var(--primary);"></div>
                    </div>
                </div>
            <?php endforeach; ?>
        </div>
    </div>

    <!-- Priority Distribution -->
    <div class="card">
        <div class="card-header">
            <h3>Hazard Priority Breakdown</h3>
        </div>
        <div class="card-body">
            <?php
            $priorities = ['Critical', 'High', 'Medium', 'Low', 'Unassigned'];
            foreach ($priorities as $pr):
                $count = $stats['by_priority'][$pr] ?? 0;
                $pct = round(($count / $total) * 100, 1);
            ?>
                <div style="margin-bottom: 1rem;">
                    <div style="display: flex; justify-content: space-between; margin-bottom: 0.25rem;">
                        <span><?= priorityBadge($pr === 'Unassigned' ? null : $pr) ?></span>
                        <span style="font-weight: 600; font-size: 0.9rem;"><?= $count ?> <small style="color:#64748b;">(<?= $pct ?>%)</small></span>
                    </div>
                    <div style="background: #e2e8f0; height: 8px; border-radius: 9999px; overflow: hidden;">
                        <div style="width: <?= $pct ?>%; height: 100%; background: #ef4444;"></div>
                    </div>
                </div>
            <?php endforeach; ?>
        </div>
    </div>
</div>

<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(450px, 1fr)); gap: 1.5rem;">
    <!-- Reports by Category -->
    <div class="card">
        <div class="card-header">
            <h3>Reports by Hazard Category</h3>
        </div>
        <div class="card-body" style="padding: 0;">
            <div class="table-responsive">
                <table class="table">
                    <thead>
                        <tr>
                            <th>Category Name</th>
                            <th>Total Reports</th>
                            <th style="width: 150px;">Share</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($stats['by_category'] as $cat):
                            $cCount = (int)$cat['count'];
                            $cPct = round(($cCount / $total) * 100, 1);
                        ?>
                            <tr>
                                <td><strong><?= e($cat['category_name']) ?></strong></td>
                                <td><?= $cCount ?></td>
                                <td>
                                    <div style="display: flex; align-items: center; gap: 0.5rem;">
                                        <div style="flex: 1; background: #e2e8f0; height: 6px; border-radius: 9999px; overflow: hidden;">
                                            <div style="width: <?= $cPct ?>%; height: 100%; background: #0284c7;"></div>
                                        </div>
                                        <span style="font-size: 0.8rem; color: #64748b;"><?= $cPct ?>%</span>
                                    </div>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <!-- Reports by Building Location -->
    <div class="card">
        <div class="card-header">
            <h3>Reports by Campus Facility / Building</h3>
        </div>
        <div class="card-body" style="padding: 0;">
            <div class="table-responsive">
                <table class="table">
                    <thead>
                        <tr>
                            <th>Building</th>
                            <th>Report Count</th>
                            <th style="width: 150px;">Share</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($stats['by_location'] as $loc):
                            $lCount = (int)$loc['count'];
                            $lPct = round(($lCount / $total) * 100, 1);
                        ?>
                            <tr>
                                <td><strong><?= e($loc['building']) ?></strong></td>
                                <td><?= $lCount ?></td>
                                <td>
                                    <div style="display: flex; align-items: center; gap: 0.5rem;">
                                        <div style="flex: 1; background: #e2e8f0; height: 6px; border-radius: 9999px; overflow: hidden;">
                                            <div style="width: <?= $lPct ?>%; height: 100%; background: #6366f1;"></div>
                                        </div>
                                        <span style="font-size: 0.8rem; color: #64748b;"><?= $lPct ?>%</span>
                                    </div>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<?php require_once __DIR__ . '/../../src/helpers/footer.php'; ?>
