@echo off
:: ============================================
:: Test Script for WallpaperChange Module
:: ============================================

setlocal enabledelayedexpansion

echo ============================================
echo   WallpaperChange Module Test
echo ============================================
echo.

:: Setup test environment
set "MODULES=%~dp0"
set "MOUNTDIR=%~dp0TestMount"
set "WINDOWS_EDITION=W10E"
set "TARGET_WINDOWS_VER=10"
set "TARGET_WINDOWS_TYPE=LTSC"

echo [*] Setting up test environment...
echo     MODULES=%MODULES%
echo     MOUNTDIR=%MOUNTDIR%
echo     EDITION=%WINDOWS_EDITION%
echo.

:: Clean previous test
if exist "%MOUNTDIR%" (
    echo [*] Cleaning previous test mount...
    rd /s /q "%MOUNTDIR%" 2>nul
)

:: Create test directory structure
echo [*] Creating test directory structure...
mkdir "%MOUNTDIR%\Windows\System32" 2>nul
mkdir "%MOUNTDIR%\Windows\Web\Wallpaper\Windows" 2>nul
mkdir "%MOUNTDIR%\Windows\Web\Screen" 2>nul

:: Create dummy wallpaper files (original Windows wallpapers)
echo [*] Creating dummy original wallpapers...
echo dummy-desktop > "%MOUNTDIR%\Windows\Web\Wallpaper\Windows\img0.jpg"
echo dummy-lockscreen > "%MOUNTDIR%\Windows\Web\Screen\img100.jpg"

echo [+] Test environment ready
echo.

:: Run the WallpaperChange module
echo ============================================
echo   Running WallpaperChange.bat
echo ============================================
echo.

call "%MODULES%\WallpaperChange.bat"

set "MODULE_RESULT=%errorlevel%"

echo.
echo ============================================
echo   Test Results
echo ============================================
echo.
echo Module exit code: %MODULE_RESULT%
echo.

:: Verify results
echo [*] Verifying replacements...
echo.

if exist "%MOUNTDIR%\Windows\Web\Wallpaper\Windows\img0.jpg" (
    echo [CHECK] Desktop wallpaper exists
    fc /b "%MOUNTDIR%\Windows\Web\Wallpaper\Windows\img0.jpg" "%MODULES%\..\Packages\Wallpaper\desktop.jpg" >nul 2>&1
    if !errorlevel! equ 0 (
        echo     [OK] Desktop wallpaper REPLACED correctly
    ) else (
        echo     [FAILED] Desktop wallpaper NOT replaced
    )
) else (
    echo [FAILED] Desktop wallpaper not found
)

echo.

if exist "%MOUNTDIR%\Windows\Web\Screen\img100.jpg" (
    echo [CHECK] Lock screen exists
    fc /b "%MOUNTDIR%\Windows\Web\Screen\img100.jpg" "%MODULES%\..\Packages\Wallpaper\lock.jpg" >nul 2>&1
    if !errorlevel! equ 0 (
        echo     [OK] Lock screen REPLACED correctly
    ) else (
        echo     [FAILED] Lock screen NOT replaced
    )
) else (
    echo [FAILED] Lock screen not found
)

echo.
echo ============================================
echo   Cleanup
echo ============================================
echo.

set /p cleanup="Delete test mount directory? (y/n): "
if /i "%cleanup%"=="y" (
    echo [*] Cleaning up test environment...
    rd /s /q "%MOUNTDIR%" 2>nul
    echo [+] Cleanup complete
) else (
    echo [*] Test mount preserved at: %MOUNTDIR%
)

echo.
echo Test completed!
pause
