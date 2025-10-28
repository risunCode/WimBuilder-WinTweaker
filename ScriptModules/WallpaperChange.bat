@echo off
:: ============================================
:: Module: WallpaperChange
:: Description: Replace default wallpapers globally (all users)
::              Uses TrustedInstaller privileges for system files
::              Replaces 4K variants and sets registry defaults
:: Supported: Windows 10/11 Consumer/LTSC
:: Version: 1.2
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

:: Use global paths from launcher
echo [*] Module: Wallpaper Change v1.2 (TrustedInstaller)
echo   Edition: %WINDOWS_EDITION% ^(%TARGET_WINDOWS_VER% %TARGET_WINDOWS_TYPE%^)
echo.

if not exist "%MOUNTDIR%\Windows\System32" (
    echo [!] WIM not mounted. Please mount first.
    exit /b 1
)

set "SOURCE_WALLPAPER=%~dp0..\Packages\Wallpaper"
set "DESKTOP_WALLPAPER=%SOURCE_WALLPAPER%\desktop.jpg"
set "LOCK_WALLPAPER=%SOURCE_WALLPAPER%\lock.jpg"
set "RUNASTI=%~dp0..\Packages\RunasTrustedInstaller\RunAsTI.exe"

:: Verify RunAsTI exists
if not exist "%RUNASTI%" (
    echo [!] RunAsTI.exe not found: %RUNASTI%
    exit /b 1
)

:: Verify source wallpapers exist
if not exist "%DESKTOP_WALLPAPER%" (
    echo [!] Desktop wallpaper not found: %DESKTOP_WALLPAPER%
    exit /b 1
)

if not exist "%LOCK_WALLPAPER%" (
    echo [!] Lock screen wallpaper not found: %LOCK_WALLPAPER%
    exit /b 1
)

echo [*] Source Wallpapers:
echo     - Desktop: %DESKTOP_WALLPAPER%
echo     - Lock Screen: %LOCK_WALLPAPER%
echo.
echo [*] Using TrustedInstaller privileges for system file modification
echo.

set "REPLACED_COUNT=0"

:: ============================================================================
:: REPLACE MAIN DESKTOP WALLPAPER
:: ============================================================================
echo [*] Replacing main desktop wallpaper...

:: Main default wallpaper (Works for both Windows 10 & 11)
if exist "%MOUNTDIR%\Windows\Web\Wallpaper\Windows\img0.jpg" (
    "%RUNASTI%" cmd.exe /c copy /Y "%DESKTOP_WALLPAPER%" "%MOUNTDIR%\Windows\Web\Wallpaper\Windows\img0.jpg" >nul 2>&1
    if !errorlevel! equ 0 (
        echo     [OK] Desktop wallpaper replaced
        set /a REPLACED_COUNT+=1
    ) else (
        echo     [FAILED] Desktop wallpaper
    )
) else (
    echo     [SKIP] Desktop wallpaper not found
)

:: Windows 11 Bloom wallpaper (if exists)
if "%TARGET_WINDOWS_VER%"=="11" (
    if exist "%MOUNTDIR%\Windows\Web\Wallpaper\Windows\img19.jpg" (
        "%RUNASTI%" cmd.exe /c copy /Y "%DESKTOP_WALLPAPER%" "%MOUNTDIR%\Windows\Web\Wallpaper\Windows\img19.jpg" >nul 2>&1
        if !errorlevel! equ 0 (
            echo     [OK] Windows 11 Bloom wallpaper replaced
            set /a REPLACED_COUNT+=1
        )
    )
)

:: Replace all 4K wallpaper variants (multiple resolutions)
if exist "%MOUNTDIR%\Windows\Web\4K\Wallpaper\Windows" (
    echo [*] Replacing 4K wallpaper variants...
    for %%F in ("%MOUNTDIR%\Windows\Web\4K\Wallpaper\Windows\img0_*.jpg" "%MOUNTDIR%\Windows\Web\4K\Wallpaper\Windows\img0_*.png") do (
        "%RUNASTI%" cmd.exe /c copy /Y "%DESKTOP_WALLPAPER%" "%%F" >nul 2>&1
        if !errorlevel! equ 0 (
            echo     [OK] 4K\%%~nxF
            set /a REPLACED_COUNT+=1
        )
    )
)

:: ============================================================================
:: REPLACE MAIN LOCK SCREEN
:: ============================================================================
echo [*] Replacing main lock screen...

:: Main lock screen (Works for both Windows 10 & 11)
if exist "%MOUNTDIR%\Windows\Web\Screen\img100.jpg" (
    "%RUNASTI%" cmd.exe /c copy /Y "%LOCK_WALLPAPER%" "%MOUNTDIR%\Windows\Web\Screen\img100.jpg" >nul 2>&1
    if !errorlevel! equ 0 (
        echo     [OK] Lock screen replaced
        set /a REPLACED_COUNT+=1
    ) else (
        echo     [FAILED] Lock screen
    )
) else (
    echo     [SKIP] Lock screen not found
)

:: ============================================================================
:: SET REGISTRY DEFAULT WALLPAPER
:: ============================================================================
echo [*] Setting registry default wallpaper...

:: Load registry hives if not already loaded
reg query HKLM\MOUNTED_DEFAULT >nul 2>&1
if errorlevel 1 (
    echo     Loading DEFAULT user hive...
    reg load HKLM\MOUNTED_DEFAULT "%MOUNTDIR%\Users\Default\NTUSER.DAT" >nul 2>&1
    set "LOADED_DEFAULT=1"
) else (
    set "LOADED_DEFAULT=0"
)

:: Set default wallpaper path for new users
reg add "HKLM\MOUNTED_DEFAULT\Control Panel\Desktop" /v Wallpaper /t REG_SZ /d "C:\Windows\Web\Wallpaper\Windows\img0.jpg" /f >nul 2>&1
if !errorlevel! equ 0 (
    echo     [OK] Default wallpaper registry set
) else (
    echo     [SKIP] Registry update failed
)

:: Unload if we loaded it
if "%LOADED_DEFAULT%"=="1" (
    reg unload HKLM\MOUNTED_DEFAULT >nul 2>&1
)

echo.
echo ============================================
echo   WALLPAPER REPLACEMENT SUMMARY
echo ============================================
echo [+] Total wallpapers replaced: !REPLACED_COUNT!
echo [+] Desktop wallpaper source: desktop.jpg
echo [+] Lock screen source: lock.jpg
echo.
echo [+] Wallpaper replacement completed successfully
echo [*] Changes will apply to all users globally
echo.

endlocal
exit /b 0
