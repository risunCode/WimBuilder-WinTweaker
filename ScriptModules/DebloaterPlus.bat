@echo off
:: ============================================
:: Module: DebloaterPlus - FIXED v2.4
:: Description: Remove Appx, Features, Capabilities
:: Supported: Windows 10/11 Consumer/LTSC
:: Version: 2.4 (Simplified - direct removal)
:: Note: Requires HKLM\MOUNTED_SYSTEM to be loaded
::       by parent script for service modifications
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
echo [*] Module: Debloater Plus v2.4
echo.

if not exist "%MOUNTDIR%\Windows\System32" (
    echo [!] WIM not mounted. Please mount first.
    exit /b 1
)

echo [*] Removing Appx Packages...
set "TEMP_APPX=%TEMP%\appx_packages.txt"
dism /Image:"%MOUNTDIR%" /Get-ProvisionedAppxPackages > "%TEMP_APPX%" 2>&1

set "APPX_LIST=Microsoft.Paint3D Recall Microsoft.MSPaint Microsoft.XboxApp Microsoft.XboxIdentityProvider Microsoft.XboxSpeechToTextOverlay Microsoft.Xbox.TCUI Microsoft.GamingApp Microsoft.BingWeather Microsoft.BingNews Microsoft.BingFinance Microsoft.BingSports Microsoft.GetHelp Microsoft.Getstarted Microsoft.Messaging Microsoft.Microsoft3DViewer Microsoft.MicrosoftOfficeHub Microsoft.MicrosoftSolitaireCollection Microsoft.MixedReality.Portal Microsoft.Office.OneNote Microsoft.People Microsoft.Print3D Microsoft.SkypeApp Microsoft.Wallet Microsoft.WindowsAlarms Microsoft.windowscommunicationsapps Microsoft.WindowsFeedbackHub Microsoft.WindowsMaps Microsoft.WindowsSoundRecorder Microsoft.YourPhone Microsoft.ZuneMusic Microsoft.ZuneVideo Microsoft.Todos Microsoft.PowerAutomateDesktop Microsoft.MicrosoftStickyNotes Microsoft.Whiteboard MicrosoftCorporationII.QuickAssist Clipchamp.Clipchamp Microsoft.549981C3F5F10 MicrosoftTeams Teams Microsoft.Teams Disney.37853FC22B2CE SpotifyAB.SpotifyMusic king.com.CandyCrushSaga king.com.CandyCrushSodaSaga king.com.FarmHeroesSaga king.com.BubbleWitch3Saga AmazonVideo.PrimeVideo Facebook.Facebook Instagram.Instagram Twitter.Twitter LinkedIn.LinkedIn Netflix.Netflix ACGMediaPlayer ActiproSoftwareLLC AdobeSystemsIncorporated.AdobePhotoshopExpress Duolingo-LearnLanguagesforFree EclipseManager Flipboard.Flipboard GAMELOFTSA PandoraMediaInc Royal.Revolt.2 Shazam Sidia.LiveWallpaper TuneInRadio Wunderlist XING Microsoft.Advertising.Xaml Microsoft.ECapp MicrosoftCorporationII.MicrosoftFamily MicrosoftCorporationII.WindowsPC Microsoft.BingFoodAndDrink Microsoft.BingHealthAndFitness Microsoft.BingTravel Microsoft.OutlookForWindows"

set "REMOVED_COUNT=0"

for %%P in (%APPX_LIST%) do (
    set "PACKAGE_FOUND=0"
    for /f "tokens=2* delims=:" %%A in ('findstr /i "%%P" "%TEMP_APPX%" 2^>nul') do (
        set "FULL_NAME=%%A"
        for /f "tokens=* delims= " %%B in ("!FULL_NAME!") do set "FULL_NAME=%%B"
        if not "!FULL_NAME!"==" " (
            set "PACKAGE_FOUND=1"
            dism /Image:"%MOUNTDIR%" /Remove-ProvisionedAppxPackage /PackageName:"!FULL_NAME!" >nul 2>&1
            if !errorlevel! equ 0 (
                echo     [OK] %%P
                set /a REMOVED_COUNT+=1
            )
        )
    )
)

if exist "%TEMP_APPX%" del "%TEMP_APPX%"

echo [+] Appx removal complete - Removed: !REMOVED_COUNT!

echo.
echo [*] Disabling optional features...

set "FEATURES_LIST=Recall Microsoft-Windows-TabletPCMath Copilot Printing-XPSServices-Features WindowsMediaPlayer SmbDirect MicrosoftWindowsPowerShellV2 MicrosoftWindowsPowerShellV2Root Internet-Explorer-Optional-amd64 WorkFolders-Client"

set "DISABLED_FEATURES=0"

for %%F in (%FEATURES_LIST%) do (
    dism /Image:"%MOUNTDIR%" /Disable-Feature /FeatureName:%%F /Remove /NoRestart >nul 2>&1
    if !errorlevel! equ 0 (
        echo     [OK] %%F
        set /a DISABLED_FEATURES+=1
    )
)

echo [+] Features disabled: !DISABLED_FEATURES!

echo.
echo [*] Removing capabilities...

set "CAPABILITIES_LIST=Recall App.Support.QuickAssist~~~~0.0.1.0 MathRecognizer~~~~0.0.1.0 App.StepsRecorder~~~~0.0.1.0 OneCoreUAP.OneSync~~~~0.0.1.0 Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0 Microsoft.WordPad~~~~0.0.1.0"

set "REMOVED_CAPS=0"

for %%C in (%CAPABILITIES_LIST%) do (
    dism /Image:"%MOUNTDIR%" /Remove-Capability /CapabilityName:%%C >nul 2>&1
    if !errorlevel! equ 0 (
        echo     [OK] %%C
        set /a REMOVED_CAPS+=1
    )
)

echo [+] Capabilities removed: !REMOVED_CAPS!

echo.
echo [*] Disabling unnecessary scheduled tasks...

set "TASKS_TO_DELETE=Microsoft\Windows\Application Experience\ProgramDataUpdater Microsoft\Windows\Autochk\Proxy Microsoft\Windows\Customer Experience Improvement Program\* Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector Microsoft\Windows\WDI\ResolutionHost"

set "TASKS_DELETED=0"

for %%T in (%TASKS_TO_DELETE%) do (
    schtasks /delete /tn "%%T" /f >nul 2>&1
    if !errorlevel! equ 0 (
        echo     [OK] %%T deleted
        set /a TASKS_DELETED+=1
    )
)

echo [+] Scheduled tasks deleted: !TASKS_DELETED!

echo.
echo [*] Disabling unnecessary services...

set "SERVICES_LIST=MapsBrokerService WerSvc WSearch"

set "SERVICES_DISABLED=0"

for %%S in (%SERVICES_LIST%) do (
    reg add "HKLM\MOUNTED_SYSTEM\ControlSet001\Services\%%S" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
    if !errorlevel! equ 0 (
        echo     [OK] %%S disabled
        set /a SERVICES_DISABLED+=1
    )
)

echo [+] Services disabled: !SERVICES_DISABLED!

echo.
echo ============================================
echo   DEBLOAT SUMMARY
echo ============================================
echo [+] Appx Packages Removed: !REMOVED_COUNT!
echo [+] Features Disabled: !DISABLED_FEATURES!
echo [+] Capabilities Removed: !REMOVED_CAPS!
echo [+] Scheduled Tasks Deleted: !TASKS_DELETED!
echo [+] Services Disabled: !SERVICES_DISABLED!
echo.
echo [+] Debloat completed successfully
endlocal
exit /b 0