<?php
/**
 * CampusSafe: User Sign Out Handler
 */

require_once __DIR__ . '/../src/auth/Auth.php';
require_once __DIR__ . '/../src/helpers/functions.php';

Auth::logout();
flash('info', 'You have been safely signed out.');
redirect('/');
