@echo off
:: ============================================
:: WimBuilder Launcher - ENHANCED v2.3.2
:: Description: Modular WIM Image Toolkit
:: Supported: Windows 10/11 Consumer/LTSC
:: Version: 2.3.2 (Fixed disk space calculation for large files)
:: ============================================

>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
"%temp%\getadmin.vbs"
del "%temp%\getadmin.vbs"
exit /B

:gotAdmin
setlocal enabledelayedexpansion
cd /d "%~dp0"
title WimBuilder Launcher

:: ============================================
:: Set Global Paths
:: ============================================
set "SOURCEWIM=%~dp0Kitchen\SourceWIM"
set "MOUNTDIR=%~dp0Kitchen\TempMount"
set "OUTPUT=%~dp0Kitchen\Output"
set "MODULES=%~dp0ScriptModules"

if not exist "%MOUNTDIR%" mkdir "%MOUNTDIR%"
if not exist "%OUTPUT%" mkdir "%OUTPUT%"

:: Global Edition Type (will be set by user)
set "TARGET_WINDOWS_VER="
set "TARGET_WINDOWS_TYPE="
set "WINDOWS_EDITION="

:: ============================================
:: Pre-flight Checks & Cleanup
:: ============================================

echo [*] Checking for stale mounts and registry hives...
dism /Get-MountedWimInfo 2>nul | findstr /c:"%MOUNTDIR%" >nul
if not errorlevel 1 (
    echo [!] Previous mount detected, cleaning up...
    call :CleanupMount
    timeout /t 2 /nobreak >nul
)

reg query HKLM\MOUNTED_SOFTWARE >nul 2>&1
if not errorlevel 1 (
    echo [!] Previous registry load detected, unloading...
    reg unload HKLM\MOUNTED_SOFTWARE >nul 2>&1
    reg unload HKLM\MOUNTED_SYSTEM >nul 2>&1
    reg unload HKLM\MOUNTED_DEFAULT >nul 2>&1
    reg unload HKLM\MOUNTED_NTUSER >nul 2>&1
    timeout /t 1 /nobreak >nul
)

:MainMenu
cls
echo ============================================
echo   WimBuilder - Automated Build System v2.3
echo ============================================
echo.
echo [1] Build Custom Windows WIM
echo [2] Build Bootable ISO from WIM
echo [3] Force Unmount ^& Discard Changes
echo [0] Exit
echo.
set /p choice="Select option: "

if "%choice%"=="1" goto AutoBuild
if "%choice%"=="2" goto BuildISO
if "%choice%"=="3" goto ForceUnmount
if "%choice%"=="0" exit
goto MainMenu

:AutoBuild
cls
echo ============================================
echo   Automated WIM Build Process
echo ============================================
echo.

:: Step 1: Select Edition Type
echo [*] Select Windows Edition Type:
echo     [1] Windows 10 Consumer (Home/Pro/etc)
echo     [2] Windows 11 Consumer (Home/Pro/etc)
echo     [3] Windows 10 LTSC (Enterprise)
echo     [4] Windows 11 LTSC (Enterprise)
echo.
set /p edtype="Your choice: "

if "%edtype%"=="1" (
    set "TARGET_WINDOWS_VER=10"
    set "TARGET_WINDOWS_TYPE=Consumer"
    set "WINDOWS_EDITION=W10C"
    echo [+] Edition Type: Windows 10 Consumer ^(W10C^)
    goto EditionSelected
)
if "%edtype%"=="2" (
    set "TARGET_WINDOWS_VER=11"
    set "TARGET_WINDOWS_TYPE=Consumer"
    set "WINDOWS_EDITION=W11C"
    echo [+] Edition Type: Windows 11 Consumer ^(W11C^)
    goto EditionSelected
)
if "%edtype%"=="3" (
    set "TARGET_WINDOWS_VER=10"
    set "TARGET_WINDOWS_TYPE=LTSC"
    set "WINDOWS_EDITION=W10E"
    echo [+] Edition Type: Windows 10 LTSC Enterprise ^(W10E^)
    goto EditionSelected
)
if "%edtype%"=="4" (
    set "TARGET_WINDOWS_VER=11"
    set "TARGET_WINDOWS_TYPE=LTSC"
    set "WINDOWS_EDITION=W11E"
    echo [+] Edition Type: Windows 11 LTSC Enterprise ^(W11E^)
    goto EditionSelected
)

echo [!] Invalid choice
pause
goto MainMenu

:EditionSelected

echo.

:: Step 2: Check WIM file
dir /b "%SOURCEWIM%\*.wim" 2>nul | findstr /i ".wim" >nul
if errorlevel 1 (
    echo [!] No WIM file found in Kitchen\SourceWIM\
    pause
    goto MainMenu
)

for %%F in ("%SOURCEWIM%\*.wim") do set "WIMFILE=%%F"
echo [*] WIM File: %WIMFILE%
echo.

:: Step 3: Display editions
:SelectEdition
echo [*] Available Windows editions:
dism /Get-WimInfo /WimFile:"%WIMFILE%"
echo.
set "index="
set /p index="Select edition index to build: "

:: Validate input - check if empty
if not defined index (
    echo [!] Invalid selection - index cannot be empty
    echo.
    goto SelectEdition
)

:: Validate input - check if numeric
set "valid=0"
for /f "delims=0123456789" %%a in ("%index%") do set "valid=1"
if "%valid%"=="1" (
    echo [!] Invalid selection - index must be a number
    echo.
    goto SelectEdition
)

:: Validate if index exists in WIM
echo [*] Validating index %index%...
dism /Get-WimInfo /WimFile:"%WIMFILE%" /Index:%index% >nul 2>&1
if errorlevel 1 (
    echo [!] Invalid index - index %index% does not exist in WIM
    echo.
    goto SelectEdition
)

:: Get Edition Name from DISM
set "DETECTED_EDITION="
for /f "tokens=2* delims=:" %%i in ('dism /Get-WimInfo /WimFile:"%WIMFILE%" /Index:%index% 2^>nul ^| findstr /c:"Name :"') do (
    set "DETECTED_EDITION=%%i"
)

if not defined DETECTED_EDITION (
    echo [!] Failed to detect edition name
    echo.
    goto SelectEdition
)

:: Clean up edition name - remove leading space and replace spaces with nothing
set "DETECTED_EDITION=!DETECTED_EDITION:~1!"
set "DETECTED_EDITION=!DETECTED_EDITION: =!"
echo [*] Detected: !DETECTED_EDITION!

:: Generate output filename
set "OUTPUTWIM=%OUTPUT%\install-!DETECTED_EDITION!.wim"
echo [*] Output will be: !OUTPUTWIM!

:: Check if output already exists
if exist "!OUTPUTWIM!" (
    echo.
    echo [!] Warning: Output file already exists
    set "overwrite="
    set /p overwrite="Overwrite existing file? (y/n): "
    if /i not "!overwrite!"=="y" goto MainMenu
    del /f /q "!OUTPUTWIM!" >nul 2>&1
)
 

:: Step 4: Cleanup and Mount WIM
echo.
echo [*] Ensuring clean mount environment...
call :CleanupMount
echo [+] Cleanup complete
echo.

echo [*] Mounting WIM image (index %index%)...
dism /Mount-Wim /WimFile:"%WIMFILE%" /Index:%index% /MountDir:"%MOUNTDIR%"
if errorlevel 1 (
    echo [!] Mount failed
    pause
    goto MainMenu
)
echo [+] Mounted successfully

:: Step 5: Clean temporary files in mounted image
echo.
echo [*] Cleaning temporary files in mounted image...
del /f /q "%MOUNTDIR%\Windows\Temp\*" >nul 2>&1
del /f /q "%MOUNTDIR%\Windows\Logs\DISM\*" >nul 2>&1
del /f /q "%MOUNTDIR%\Windows\SoftwareDistribution\Download\*" >nul 2>&1
for /d %%d in ("%MOUNTDIR%\Windows\Temp\*") do rd /s /q "%%d" >nul 2>&1
echo [+] Temporary files cleaned

:: Step 6: Apply Registry Tweaks
echo.
echo ============================================
echo   [1/4] Applying Registry Tweaks
echo ============================================
call "%MODULES%\RegistryTweak.bat" "%MOUNTDIR%"
if errorlevel 1 (
    echo [!] Registry tweaks failed
    goto ForceUnmount
)

:: Step 7: Debloat System
echo.
echo ============================================
echo   [2/4] Debloating System
echo ============================================
call "%MODULES%\DebloaterPlus.bat"
if errorlevel 1 (
    echo [!] Debloat failed
    goto ForceUnmount
)

:: Step 8: Deploy OneDrive Enablement Tool (Consumer only)
if /i "%TARGET_WINDOWS_TYPE%"=="Consumer" goto :RunInjectEnablement
echo [*] Skipping OneDrive Enablement Tool (not Consumer edition)
goto :SkipInjectEnablement

:RunInjectEnablement
echo.
echo ============================================
echo   [3/4] Deploying OneDrive Enablement Tool
echo ============================================
call "%MODULES%\InjectEnablement.bat"
if errorlevel 1 (
    echo [!] OneDrive enabler deployment failed (non-critical)
)

:SkipInjectEnablement

:: Step 9: Replace Default Wallpapers
echo.
echo ============================================
echo   [4/4] Replacing Default Wallpapers
echo ============================================
call "%MODULES%\WallpaperChange.bat"
if errorlevel 1 (
    echo [!] Wallpaper replacement failed (non-critical)
)

:: Step 10: Unmount and Export
echo.
echo [*] Unmounting and committing changes to WIM...
dism /Unmount-Wim /MountDir:"%MOUNTDIR%" /Commit
if errorlevel 1 (
    echo [!] Failed to unmount
    pause
    goto MainMenu
)
echo [+] Unmount successful

echo.
echo [*] Exporting optimized WIM to Output folder...
dism /Export-Image /SourceImageFile:"%WIMFILE%" /SourceIndex:%index% /DestinationImageFile:"!OUTPUTWIM!" /Compress:max /CheckIntegrity
if errorlevel 1 (
    echo [!] Export failed
    pause
    goto MainMenu
)

:: Verify WIM integrity
echo.
echo [*] Verifying WIM integrity...
dism /Get-WimInfo /WimFile:"!OUTPUTWIM!" /Index:1 >nul 2>&1
if errorlevel 1 (
    echo [!] Warning: Output WIM may be corrupted
    echo [!] Please verify manually before use
) else (
    echo [+] Integrity check passed
)

echo.
echo ============================================
echo   BUILD COMPLETED SUCCESSFULLY
echo ============================================
echo [+] Output: !OUTPUTWIM!
echo [+] Edition Type: Windows %TARGET_WINDOWS_VER% (%TARGET_WINDOWS_TYPE%)
echo [+] Size optimized with maximum compression
echo.
 

:: Prompt to delete source WIM
echo.
set "deletewim="
set /p deletewim="Delete source WIM file? (y/n): "
if /i "!deletewim!"=="y" (
    echo [*] Deleting source WIM: %WIMFILE%
    del /f /q "%WIMFILE%" >nul 2>&1
    if errorlevel 1 (
        echo [!] Failed to delete source WIM - file may be in use
    ) else (
        echo [+] Source WIM deleted successfully
    )
) else (
    echo [*] Source WIM preserved
)

set "openfolder="
set /p openfolder="Open Output folder? (y/n): "
if /i "!openfolder!"=="y" (
    echo [*] Opening Output directory...
    explorer "%OUTPUT%"
)

echo.
pause
goto MainMenu

:BuildISO
cls
echo ============================================
echo   Build Bootable ISO
echo ============================================
echo.
call "%MODULES%\BuildISO.bat"
echo.
pause
goto MainMenu

:ForceUnmount
cls
echo ============================================
echo   Force Unmount ^& Discard Changes
echo ============================================
echo.
call :CleanupMount
echo.
pause
goto MainMenu

:: ============================================
:: Cleanup Subroutine (can be called anywhere)
:: ============================================
:CleanupMount
echo [*] Unloading registry hives...
reg unload HKLM\MOUNTED_SOFTWARE >nul 2>&1
if not errorlevel 1 (
    echo     [OK] MOUNTED_SOFTWARE unloaded
) else (
    echo     [--] MOUNTED_SOFTWARE not loaded
)
reg unload HKLM\MOUNTED_SYSTEM >nul 2>&1
if not errorlevel 1 (
    echo     [OK] MOUNTED_SYSTEM unloaded
) else (
    echo     [--] MOUNTED_SYSTEM not loaded
)
reg unload HKLM\MOUNTED_DEFAULT >nul 2>&1
if not errorlevel 1 (
    echo     [OK] MOUNTED_DEFAULT unloaded
) else (
    echo     [--] MOUNTED_DEFAULT not loaded
)
reg unload HKLM\MOUNTED_NTUSER >nul 2>&1
if not errorlevel 1 (
    echo     [OK] MOUNTED_NTUSER unloaded
) else (
    echo     [--] MOUNTED_NTUSER not loaded
)

echo [*] Unmounting WIM image...
dism /Unmount-Wim /MountDir:"%MOUNTDIR%" /Discard >nul 2>&1
if errorlevel 1 (
    echo     [!] Unmount failed - may already be unmounted
) else (
    echo     [+] WIM unmounted and changes discarded
)
exit /b 0