@echo off
:: ============================================
:: OneDrive Simple Manager v4.0
:: Disable/Enable OneDrive - Simple & Modern
:: ============================================

:: Auto-elevation
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting admin privileges...
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B
)

cd /d "%~dp0"
setlocal enabledelayedexpansion

title OneDrive Simple Manager
color 0B

:MainMenu
cls
echo ============================================
echo   OneDrive Simple Manager v4.0
echo ============================================
echo.

:: Check status
set "STATUS=ENABLED"
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v DisableFileSyncNGSC 2>nul | findstr "0x1" >nul
if not errorlevel 1 set "STATUS=DISABLED"

:: Check if running
set "RUNNING=False"
tasklist /FI "IMAGENAME eq OneDrive.exe" 2>nul | findstr /i "OneDrive.exe" >nul
if not errorlevel 1 set "RUNNING=True"

:: Check if installed
set "INSTALLED=No"
set "ONEDRIVE_PATH="
if exist "%LOCALAPPDATA%\Microsoft\OneDrive\OneDrive.exe" (
    set "INSTALLED=Yes"
    set "ONEDRIVE_PATH=%LOCALAPPDATA%\Microsoft\OneDrive"
)
if exist "%ProgramFiles%\Microsoft OneDrive\OneDrive.exe" (
    set "INSTALLED=Yes"
    set "ONEDRIVE_PATH=%ProgramFiles%\Microsoft OneDrive"
)
if exist "%ProgramFiles(x86)%\Microsoft OneDrive\OneDrive.exe" (
    set "INSTALLED=Yes"
    set "ONEDRIVE_PATH=%ProgramFiles(x86)%\Microsoft OneDrive"
)

echo Status           : !STATUS!
echo Is Running       : !RUNNING!
if "!INSTALLED!"=="Yes" (
    echo OneDrive Path    : !ONEDRIVE_PATH!
) else (
    echo OneDrive Path    : Not available
)

echo.
echo [1] Disable OneDrive
echo [2] Enable OneDrive
echo [0] Exit
echo.
set /p choice="Select: "

if "%choice%"=="1" goto DisableOneDrive
if "%choice%"=="2" goto EnableOneDrive
if "%choice%"=="0" exit /B 0
goto MainMenu

:: ============================================
:: Disable OneDrive
:: ============================================
:DisableOneDrive
cls
echo ============================================
echo   Disable OneDrive
echo ============================================
echo.
echo This will:
echo  - Stop OneDrive process
echo  - Disable via Group Policy
echo  - Hide from File Explorer
echo  - Remove from startup
echo.
echo Your files remain safe in: %USERPROFILE%\OneDrive
echo.
set /p confirm="Continue? (y/n): "
if /i not "%confirm%"=="y" goto MainMenu

echo.
echo [1/5] Stopping OneDrive...
start /wait "" "%LOCALAPPDATA%\Microsoft\OneDrive\OneDrive.exe" /shutdown >nul 2>&1
timeout /t 2 /nobreak >nul
taskkill /f /im OneDrive.exe >nul 2>&1
echo     [+] Stopped

echo.
echo [2/5] Setting Group Policy...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v DisableFileSyncNGSC /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v DisableFileSync /t REG_DWORD /d 1 /f >nul
echo     [+] Disabled via policy

echo.
echo [3/5] Removing startup...
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /f >nul 2>&1
echo     [+] Startup removed

echo.
echo [4/5] Hiding from Explorer...
reg add "HKCU\Software\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 0 /f >nul
echo     [+] Hidden from sidebar

echo.
echo [5/5] Refreshing Explorer...
taskkill /f /im explorer.exe >nul 2>&1
start explorer.exe
timeout /t 2 /nobreak >nul
echo     [+] Done

echo.
echo ============================================
echo   OneDrive Disabled Successfully!
echo ============================================
echo.
echo Restart your PC for full effect.
echo.
pause
goto MainMenu

:: ============================================
:: Enable OneDrive
:: ============================================
:EnableOneDrive
cls
echo ============================================
echo   Enable OneDrive
echo ============================================
echo.

echo [1/5] Removing Group Policy restrictions...
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v DisableFileSyncNGSC /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v DisableFileSync /f >nul 2>&1
echo     [+] Policy cleared

echo.
echo [2/5] Restoring Explorer integration...
reg delete "HKCU\Software\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /v System.IsPinnedToNameSpaceTree /f >nul 2>&1
echo     [+] Visible in sidebar

echo.
echo [3/5] Checking installation...
set "ONEDRIVE_EXE="
if exist "%LOCALAPPDATA%\Microsoft\OneDrive\OneDrive.exe" set "ONEDRIVE_EXE=%LOCALAPPDATA%\Microsoft\OneDrive\OneDrive.exe"
if exist "%ProgramFiles%\Microsoft OneDrive\OneDrive.exe" set "ONEDRIVE_EXE=%ProgramFiles%\Microsoft OneDrive\OneDrive.exe"
if exist "%ProgramFiles(x86)%\Microsoft OneDrive\OneDrive.exe" set "ONEDRIVE_EXE=%ProgramFiles(x86)%\Microsoft OneDrive\OneDrive.exe"

if not defined ONEDRIVE_EXE (
    echo     [!] OneDrive NOT installed
    echo.
    set /p dl="Open download page? (y/n): "
    if /i "!dl!"=="y" start https://www.microsoft.com/microsoft-365/onedrive/download
    echo.
    pause
    goto MainMenu
) else (
    echo     [+] Found: !ONEDRIVE_EXE!
)

echo.
echo [4/5] Refreshing Explorer...
taskkill /f /im explorer.exe >nul 2>&1
start explorer.exe
timeout /t 2 /nobreak >nul
echo     [+] Done

echo.
echo [5/5] Starting OneDrive...
start "" "!ONEDRIVE_EXE!"
echo     [+] Launched

echo.
echo ============================================
echo   OneDrive Enabled Successfully!
echo ============================================
echo.
echo OneDrive will start automatically on next login.
echo.
pause
goto MainMenu