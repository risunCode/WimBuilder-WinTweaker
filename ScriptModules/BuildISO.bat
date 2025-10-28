@echo off
:: ============================================
:: Module: Build Bootable ISO
:: Description: Convert custom WIM to bootable ISO
::              Simple approach: Replace install.wim only
::              No boot file manipulation for maximum compatibility
:: Supported: Windows 10/11 Consumer/LTSC
:: Version: 2.0 (LTSC 10 Fixed)
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

:: Set paths
set "OSCDIMG=%~dp0..\packages\oscdimg"
set "ISO_WORK=%~dp0..\Kitchen\ISO_Work"
set "ISO_OUTPUT=%~dp0..\Kitchen\ISO_Output"
set "WIM_OUTPUT=%OUTPUT%"

echo ============================================
echo   WIM to ISO Builder
echo ============================================
echo.

:: Check if oscdimg exists
if not exist "%OSCDIMG%\oscdimg.exe" (
    echo [ERROR] oscdimg.exe not found in packages\oscdimg\
    echo Please ensure oscdimg package is installed.
    exit /b 1
)

:: Check for WIM files in Output folder
dir /b "%WIM_OUTPUT%\*.wim" 2>nul | findstr /i ".wim" >nul
if errorlevel 1 (
    echo [ERROR] No WIM file found in Kitchen\Output\
    echo Please build a custom WIM first.
    exit /b 1
)

:: Display available WIM files
echo [*] Available WIM files:
echo.
set "count=0"
for %%F in ("%WIM_OUTPUT%\*.wim") do (
    set /a count+=1
    set "WIM_FILE_!count!=%%F"
    set "WIM_NAME_!count!=%%~nxF"
    echo     [!count!] %%~nxF
)
echo.

:: Select WIM file
set /p wimchoice="Select WIM file (1-!count!): "

:: Validate selection
if not defined WIM_FILE_%wimchoice% (
    echo [ERROR] Invalid selection
    exit /b 1
)

set "SELECTED_WIM=!WIM_FILE_%wimchoice%!"
set "SELECTED_NAME=!WIM_NAME_%wimchoice%!"
echo [+] Selected: !SELECTED_NAME!
echo.

:: Ask for source ISO or use default boot files
echo [*] Select boot file source:
echo     [1] Use existing Windows ISO (global-recommended)
echo     [2] Use default boot files for LTSC (may not work for all versions)
echo.
set /p bootsource="Your choice: "

if "%bootsource%"=="1" goto UseSourceISO
if "%bootsource%"=="2" goto UseDefaultBoot

echo [ERROR] Invalid choice
exit /b 1

:UseSourceISO
echo.
set /p isopath="Enter path to Windows ISO file: "

:: Remove quotes from path if present
set "isopath=%isopath:"=%"

if not exist "%isopath%" (
    echo [ERROR] ISO file not found: %isopath%
    exit /b 1
)

echo [+] ISO file found
echo.

:: Clean and create working directory
echo [*] Preparing working directory...
if exist "%ISO_WORK%" rd /s /q "%ISO_WORK%" >nul 2>&1
mkdir "%ISO_WORK%" >nul 2>&1

:: Mount source ISO and get drive letter using PowerShell (Windows 10/11 compatible)
echo [*] Mounting source ISO...

:: Use PowerShell to mount and get drive letter
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "$disk = Mount-DiskImage -ImagePath '%isopath%' -PassThru; $vol = Get-Volume -DiskImage $disk; Write-Host $vol.DriveLetter"`) do set "MOUNT_LETTER=%%I"

:: Check if mount was successful
if not defined MOUNT_LETTER (
    echo [ERROR] Failed to mount ISO
    exit /b 1
)

:: Verify sources folder exists
if not exist "%MOUNT_LETTER%:\sources\" (
    echo [ERROR] Invalid Windows ISO - sources folder not found
    powershell -NoProfile -Command "Dismount-DiskImage -ImagePath '%isopath%' | Out-Null" >nul 2>&1
    exit /b 1
)

echo [+] ISO mounted to %MOUNT_LETTER%:
echo.

:: Copy all files from ISO (this may take a few minutes)
echo [*] Copying files from ISO ^(this may take several minutes^)...
echo     Please wait...

:: Copy everything from ISO
xcopy "%MOUNT_LETTER%:\*" "%ISO_WORK%\" /E /H /C /I /Y >nul 2>&1

if errorlevel 1 (
    echo [ERROR] Failed to copy files from ISO
    powershell -NoProfile -Command "Dismount-DiskImage -ImagePath '%isopath%' | Out-Null" >nul 2>&1
    goto CleanupError
)

:: Delete original install.wim/esd to be replaced with custom WIM
echo     Removing original install.wim/esd...
if exist "%ISO_WORK%\sources\install.wim" del /f /q "%ISO_WORK%\sources\install.wim" >nul 2>&1
if exist "%ISO_WORK%\sources\install.esd" del /f /q "%ISO_WORK%\sources\install.esd" >nul 2>&1

echo [+] Files copied successfully
echo.

:: Unmount ISO
echo [*] Unmounting source ISO...
powershell -NoProfile -Command "Dismount-DiskImage -ImagePath '%isopath%' | Out-Null" >nul 2>&1
echo [+] ISO unmounted
echo.

goto CopyCustomWIM

:UseDefaultBoot
echo.
echo [WARNING] Default boot method may not work for all Windows versions
echo [WARNING] Using existing Windows ISO is highly recommended
echo.
pause

:: Create minimal boot structure
echo [*] Creating minimal boot structure...
if exist "%ISO_WORK%" rd /s /q "%ISO_WORK%" >nul 2>&1
mkdir "%ISO_WORK%\boot" >nul 2>&1
mkdir "%ISO_WORK%\efi\boot" >nul 2>&1
mkdir "%ISO_WORK%\sources" >nul 2>&1

echo [ERROR] Default boot method not implemented yet
echo Please use option [1] with source ISO instead
exit /b 1

:CopyCustomWIM
:: Simple approach: Just replace install.wim, keep everything else as-is from source ISO
:: No boot file manipulation needed - use source ISO structure exactly as-is
echo.
echo ============================================
echo   Simple Replace Method
echo ============================================
echo [*] This method preserves ALL source ISO files
echo [*] Only install.wim will be replaced
echo [*] Maximum compatibility for LTSC editions
echo.
echo [*] Replacing install.wim with custom WIM...
copy /y "%SELECTED_WIM%" "%ISO_WORK%\sources\install.wim" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Failed to copy WIM file
    exit /b 1
)
echo [+] Custom WIM replaced successfully
echo.

:: Create output directory
if not exist "%ISO_OUTPUT%" mkdir "%ISO_OUTPUT%" >nul 2>&1

:: Generate ISO filename
set "ISO_NAME=%SELECTED_NAME:~0,-4%.iso"
set "ISO_PATH=%ISO_OUTPUT%\%ISO_NAME%"

:: Check if ISO already exists
if exist "%ISO_PATH%" (
    echo [WARNING] ISO file already exists: %ISO_NAME%
    set /p overwrite="Overwrite? (y/n): "
    if /i not "!overwrite!"=="y" (
        echo [*] Operation cancelled
        exit /b 0
    )
    del /f /q "%ISO_PATH%" >nul 2>&1
)

echo.
echo [*] Building bootable ISO...
echo [*] This may take several minutes...
echo.

:: Detect boot type and files from original structure
set "BOOT_TYPE=BIOS"
set "BIOS_BOOT="
set "UEFI_BOOT="

:: Check for BIOS boot file
if exist "%ISO_WORK%\boot\etfsboot.com" (
    set "BIOS_BOOT=boot\etfsboot.com"
)

:: Check for UEFI boot file in multiple possible locations
if exist "%ISO_WORK%\efi\microsoft\boot\efisys_noprompt.bin" (
    set "UEFI_BOOT=efi\microsoft\boot\efisys_noprompt.bin"
    set "BOOT_TYPE=UEFI"
) else if exist "%ISO_WORK%\efi\boot\efisys_noprompt.bin" (
    set "UEFI_BOOT=efi\boot\efisys_noprompt.bin"
    set "BOOT_TYPE=UEFI"
)

:: Verify boot files
if not defined BIOS_BOOT (
    echo [WARNING] BIOS boot file not found, ISO may not boot on Legacy BIOS
)

:: Build ISO with appropriate boot options
pushd "%ISO_WORK%"

if defined UEFI_BOOT if defined BIOS_BOOT (
    echo [*] Boot Type: UEFI + Legacy BIOS ^(Hybrid^)
    echo [*] BIOS: %BIOS_BOOT%
    echo [*] UEFI: %UEFI_BOOT%
    "%OSCDIMG%\oscdimg.exe" -m -o -u2 -udfver102 -bootdata:2#p0,e,b"%BIOS_BOOT%"#pEF,e,b"%UEFI_BOOT%" . "%ISO_PATH%"
) else if defined BIOS_BOOT (
    echo [*] Boot Type: Legacy BIOS only
    echo [*] BIOS: %BIOS_BOOT%
    "%OSCDIMG%\oscdimg.exe" -m -o -u2 -udfver102 -b"%BIOS_BOOT%" . "%ISO_PATH%"
) else (
    echo [ERROR] No bootable files found!
    popd
    goto CleanupError
)

popd

if errorlevel 1 (
    echo.
    echo [ERROR] Failed to create ISO
    goto CleanupError
)

echo.
echo ============================================
echo   ISO BUILD COMPLETED
echo ============================================
echo [+] Output: %ISO_PATH%
echo [+] Boot Type: %BOOT_TYPE%
echo.

:: Get ISO size
for %%I in ("%ISO_PATH%") do set "ISO_SIZE=%%~zI"
set /a ISO_SIZE_MB=%ISO_SIZE% / 1048576
echo [+] ISO Size: !ISO_SIZE_MB! MB
echo.

:: Cleanup
echo [*] Cleaning up temporary files...
if exist "%ISO_WORK%" rd /s /q "%ISO_WORK%" >nul 2>&1
echo [+] Cleanup complete
echo.

:: Ask to open folder
set /p openfolder="Open ISO Output folder? (y/n): "
if /i "!openfolder!"=="y" (
    echo [*] Opening ISO Output directory...
    explorer "%ISO_OUTPUT%"
)

echo.
exit /b 0

:CleanupError
echo.
echo [*] Cleaning up after error...
if exist "%ISO_WORK%" rd /s /q "%ISO_WORK%" >nul 2>&1
echo.
exit /b 1
