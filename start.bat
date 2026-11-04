@echo off
setlocal enabledelayedexpansion
title CampusSafe - Local Web Server

echo ========================================================
echo   CampusSafe: Campus Hazard and Safety Reporting System
echo   COMP 018 Group 7 Local Server Launcher
echo ========================================================
echo.

:: 1. Search for PHP
set "PHP_CMD="

where php.exe >nul 2>&1
if %errorlevel% equ 0 (
    set "PHP_CMD=php"
) else (
    for %%P in (
        "D:\php\php.exe"
        "C:\php\php.exe"
        "C:\tools\php\php.exe"
        "C:\xampp\php\php.exe"
        "D:\xampp\php\php.exe"
        "E:\xampp\php\php.exe"
        "C:\laragon\bin\php\php-8.2*\php.exe"
        "C:\laragon\bin\php\php-8.3*\php.exe"
        "C:\laragon\bin\php\php-8.4*\php.exe"
        "C:\laragon\bin\php\php-8.5*\php.exe"
    ) do (
        if not defined PHP_CMD (
            if exist %%P (
                set "PHP_CMD=%%~fP"
            )
        )
    )
)

if not defined PHP_CMD (
    echo [ERROR] PHP executable not found!
    echo.
    echo Please make sure PHP 8.2+ or XAMPP is installed on your computer.
    echo If installed, add the PHP directory to your system PATH or install to C:\xampp.
    echo.
    pause
    exit /b 1
)

echo [OK] Using PHP: %PHP_CMD%

:: 2. Check environment configuration
if not exist "%~dp0.env" (
    echo [INFO] First time run: .env not found.
    echo [INFO] The browser will open the 1-Click Setup Wizard at http://localhost:8000/install.php
    echo.
    start "" cmd /c "timeout /t 2 /nobreak >nul & start http://localhost:8000/install.php"
) else (
    start "" cmd /c "timeout /t 1 /nobreak >nul & start http://localhost:8000"
)

echo [INFO] Starting CampusSafe web server on http://localhost:8000
echo [INFO] Document root: %~dp0public
echo.
echo ========================================================
echo   SERVER RUNNING ON http://localhost:8000
echo   Press Ctrl+C to stop the server
echo ========================================================
echo.

"%PHP_CMD%" -S localhost:8000 -t "%~dp0public"
pause
