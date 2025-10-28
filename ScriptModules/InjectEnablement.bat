@echo off
:: ============================================
:: Module: InjectEnablement
:: Description: Copy OneDrive Enablement script to Public Desktop
:: Supported: Windows 10/11 Consumer ONLY
:: Version: 2.3 (Fixed - Create Public Desktop if missing)
:: ============================================

setlocal enabledelayedexpansion

:: ============================================================================
:: Launcher Detection - Ensure script is run from WimBuilder
:: ============================================================================
if not defined MODULES (
    echo ============================================================================
    echo [ERROR] Please launch script from WimBuilder launcher.
    echo ============================================================================
    echo.
    echo This script module requires variables and paths that are set by
    echo WimBuilder_Launcher.bat. Please run the launcher first.
    echo.
    pause
    exit /b 1
)

if not exist "%MOUNTDIR%\Windows\System32" (
    echo [!] Enablement injection failed - WIM not mounted
    exit /b 1
)

set "PUBDESKTOP=%MOUNTDIR%\Users\Public\Desktop"
set "SOURCE_SCRIPT=%MODULES%\OneDrive-Enabler.bat"

:: Create Public Desktop if missing
if not exist "%PUBDESKTOP%" (
    mkdir "%PUBDESKTOP%" 2>nul
    if not exist "%PUBDESKTOP%" (
        echo [!] Enablement injection failed - Cannot create Public Desktop
        exit /b 1
    )
)

if not exist "%SOURCE_SCRIPT%" (
    echo [!] Enablement injection failed - OneDrive-Enabler.bat not found
    exit /b 1
)

copy /Y "%SOURCE_SCRIPT%" "%PUBDESKTOP%\OneDrive-Enabler.bat" >nul 2>&1

if exist "%PUBDESKTOP%\OneDrive-Enabler.bat" (
    echo [+] OneDrive Enablement script injected successfully
) else (
    echo [!] Enablement injection failed - Copy error
    exit /b 1
)

endlocal
exit /b 0
