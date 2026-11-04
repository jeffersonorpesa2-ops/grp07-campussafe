@echo off
setlocal enabledelayedexpansion
title CampusSafe - 1-Click Automated Setup

echo ========================================================
echo   CampusSafe: Campus Hazard and Safety Reporting System
echo   1-Click Automated Setup Wizard (COMP 018 Group 7)
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
echo.

:: 2. Execute bin/setup.php
"%PHP_CMD%" "%~dp0bin\setup.php" %*

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Setup encountered an issue. Please review the messages above.
    pause
    exit /b %errorlevel%
)

echo.
echo ========================================================
echo   Setup completed successfully.
echo ========================================================
echo.
set /p START_NOW="Do you want to start the CampusSafe local server now? [Y/n]: "
if /i "%START_NOW%"=="n" (
    echo.
    echo You can start the server anytime by double-clicking start.bat.
    echo.
    pause
    exit /b 0
)

:: 3. Launch start.bat
call "%~dp0start.bat"
