@echo off
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

set "MOUNT_DIR=%~1"

echo [MODULE] Registry Tweaks
echo   Edition: %WINDOWS_EDITION% ^(%TARGET_WINDOWS_VER% %TARGET_WINDOWS_TYPE%^)
echo.

:: Validate parameter
if "%MOUNT_DIR%"=="" (
    echo [ERROR] Mount directory parameter is missing!
    echo Usage: %~nx0 "mount_directory_path"
    exit /b 1
)

if not exist "%MOUNT_DIR%" (
    echo [ERROR] Mount directory does not exist: %MOUNT_DIR%
    exit /b 1
)

echo   - Loading registry hives...
set "SOFTWARE_LOADED=0"
set "DEFAULT_LOADED=0"
set "SYSTEM_LOADED=0"
set "NTUSER_LOADED=0"

reg load HKLM\MOUNTED_SOFTWARE "%MOUNT_DIR%\Windows\System32\config\SOFTWARE"
if !errorlevel! equ 0 (
    set "SOFTWARE_LOADED=1"
    echo     ^> SOFTWARE hive loaded successfully
) else (
    echo [WARNING] Failed to load SOFTWARE hive
)

reg load HKLM\MOUNTED_DEFAULT "%MOUNT_DIR%\Users\Default\NTUSER.DAT"
if !errorlevel! equ 0 (
    set "DEFAULT_LOADED=1"
    set "NTUSER_LOADED=1"
    echo     ^> DEFAULT hive loaded successfully
) else (
    echo [WARNING] Failed to load DEFAULT hive
)

reg load HKLM\MOUNTED_SYSTEM "%MOUNT_DIR%\Windows\System32\config\SYSTEM"
if !errorlevel! equ 0 (
    set "SYSTEM_LOADED=1"
    echo     ^> SYSTEM hive loaded successfully
) else (
    echo [WARNING] Failed to load SYSTEM hive
)

:: Check if any hive was loaded successfully
if !SOFTWARE_LOADED! equ 0 if !DEFAULT_LOADED! equ 0 if !SYSTEM_LOADED! equ 0 if !NTUSER_LOADED! equ 0 (
    echo [ERROR] Cannot load required registry hives
    echo [INFO] Registry tweaks will be skipped
    goto :skip_registry
)

echo.

:: ========================================
:: APPLY REGISTRY TWEAKS
:: ========================================
echo   - Applying registry tweaks...

if !SOFTWARE_LOADED! equ 1 (
    echo     - SOFTWARE hive tweaks...
    goto APPLY_SOFTWARE_TWEAKS
)

:AFTER_SOFTWARE
if !DEFAULT_LOADED! equ 1 (
    echo     - DEFAULT hive tweaks...
    goto APPLY_DEFAULT_TWEAKS
)

:AFTER_DEFAULT
if !SYSTEM_LOADED! equ 1 (
    echo     - SYSTEM hive tweaks...
    goto APPLY_SYSTEM_TWEAKS
)

:AFTER_SYSTEM

:: Apply Windows-specific tweaks
if "%WINDOWS_EDITION%"=="W10C" (
    echo     - Windows 10 Consumer specific tweaks...
    call :APPLY_WIN10C_TWEAKS
)
if "%WINDOWS_EDITION%"=="W10E" (
    echo     - Windows 10 LTSC specific tweaks...
    call :APPLY_WIN10E_TWEAKS
)
if "%WINDOWS_EDITION%"=="W11C" (
    echo     - Windows 11 Consumer specific tweaks...
    call :APPLY_WIN11_TWEAKS
)
if "%WINDOWS_EDITION%"=="W11E" (
    echo     - Windows 11 LTSC specific tweaks...
    call :APPLY_WIN11_TWEAKS
)

:skip_registry
echo   - Unloading registry hives...
if !SOFTWARE_LOADED! equ 1 reg unload HKLM\MOUNTED_SOFTWARE
if !DEFAULT_LOADED! equ 1 reg unload HKLM\MOUNTED_DEFAULT
if !SYSTEM_LOADED! equ 1 reg unload HKLM\MOUNTED_SYSTEM

echo   Registry tweaks completed.
echo.
exit /b 0

:: ============================================================================
:: SOFTWARE HIVE TWEAKS
:: ============================================================================
:APPLY_SOFTWARE_TWEAKS

:: GLOBAL TWEAKS

:: ONEDRIVE DISABLE (Skip for LTSC - OneDrive not included)
if not "%WINDOWS_EDITION%"=="W10E" if not "%WINDOWS_EDITION%"=="W11E" (
    echo [*] Disabling OneDrive...
    reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v DisableFileSyncNGSC /t REG_DWORD /d 1 /f
) else (
    echo [*] Skipping OneDrive disable ^(not present in LTSC^)
)

:: Remove context menu items
reg delete "HKLM\MOUNTED_SOFTWARE\Classes\*\shellex\ContextMenuHandlers\ModernSharing" /f 2>nul
reg delete "HKLM\MOUNTED_SOFTWARE\Classes\*\shellex\ContextMenuHandlers\Sharing" /f 2>nul

:: Remove virtual folders from Explorer
reg delete "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}" /f 2>nul
reg delete "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}" /f 2>nul
reg delete "HKLM\MOUNTED_SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}" /f 2>nul

:: Bypass Network Requirement in OOBE, Hide Settings homepage
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v BypassNRO /t REG_DWORD /d 1 /f

:: Disable reserved storage, Disable OOBE updates, DevHomeUpdate, OutlookUpdate, Mark updates as completed
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" /v ShippedWithReserves /t REG_DWORD /d 0 /f
reg delete "HKLM\MOUNTED_SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate" /f 2>nul
reg delete "HKLM\MOUNTED_SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate" /f 2>nul
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\DevHomeUpdate" /v workCompleted /t REG_DWORD /d 1 /f
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\OutlookUpdate" /v workCompleted /t REG_DWORD /d 1 /f

:: Disable consumer features and cloud content
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableCloudOptimizedContent /t REG_DWORD /d 1 /f
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableConsumerAccountStateContent /t REG_DWORD /d 1 /f
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f

:: Disable telemetry
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f

:: Disable activity history
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\System" /v PublishUserActivities /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\System\ActivityHistory" /v CloudSync /t REG_DWORD /d 0 /f

:: Disable Cortana (Windows 10 only - W10C and W10E)
if "%WINDOWS_EDITION%"=="W10C" (
    echo [*] Disabling Cortana ^(Windows 10 Consumer^)...
    reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /t REG_DWORD /d 0 /f
    reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v CortanaConsent /t REG_DWORD /d 0 /f
)
if "%WINDOWS_EDITION%"=="W10E" (
    echo [*] Disabling Cortana ^(Windows 10 LTSC^)...
    reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /t REG_DWORD /d 0 /f
    reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v CortanaConsent /t REG_DWORD /d 0 /f
)

:: Hide Recent and Frequent files in Explorer
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v ShowRecent /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v ShowFrequent /t REG_DWORD /d 0 /f

:: Remove BMP ShellNew entry
reg delete "HKLM\MOUNTED_SOFTWARE\Classes\.bmp\ShellNew" /f 2>nul

:: Add Show Home option to File Explorer folder options (default disabled)
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\NavPane\ShowHome" /v CheckedValue /t REG_DWORD /d 1 /f
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\NavPane\ShowHome" /v DefaultValue /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\NavPane\ShowHome" /v HKeyRoot /t REG_DWORD /d 0x80000001 /f
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\NavPane\ShowHome" /v Id /t REG_DWORD /d 0x0000000d /f
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\NavPane\ShowHome" /v RegPath /t REG_SZ /d "Software\\Classes\\CLSID\\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" /f
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\NavPane\ShowHome" /v Text /t REG_SZ /d "Show Home" /f
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\NavPane\ShowHome" /v Type /t REG_SZ /d "checkbox" /f
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\NavPane\ShowHome" /v UncheckedValue /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\NavPane\ShowHome" /v ValueName /t REG_SZ /d "System.IsPinnedToNameSpaceTree" /f

echo [+] SOFTWARE global tweaks applied
goto AFTER_SOFTWARE

:: ============================================================================
:: DEFAULT HIVE TWEAKS
:: ============================================================================
:APPLY_DEFAULT_TWEAKS

:: Open File Explorer to This PC instead of Quick Access
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 1 /f

:: Show file extensions,  Disable taskbar widgets button, Disable track programs for Start Menu, Disable advertising ID
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 0 /f 2>nul
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackProgs /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f

:: Disable content delivery manager
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v ContentDeliveryAllowed /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v FeatureManagementEnabled /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v OemPreInstalledAppsEnabled /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v PreInstalledAppsEnabled /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v PreInstalledAppsEverEnabled /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SilentInstalledAppsEnabled /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SoftLandingEnabled /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-310093Enabled /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338388Enabled /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338387Enabled /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338393Enabled /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353694Enabled /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353696Enabled /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContentEnabled /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v RotatingLockScreenOverlayEnabled /t REG_DWORD /d 0 /f
reg delete "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Subscriptions" /f 2>nul

:: Disable tailored experiences, Disable typing insights,Disable handwriting and typing personalization
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Privacy" /v TailoredExperiencesWithDiagnosticDataEnabled /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Input\TIPC" /v Enabled /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\InputPersonalization" /v RestrictImplicitInkCollection /t REG_DWORD /d 1 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\InputPersonalization" /v RestrictImplicitTextCollection /t REG_DWORD /d 1 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\InputPersonalization\TrainedDataStore" /v HarvestContacts /t REG_DWORD /d 0 /f

:: Disable personalization privacy policy, Disable online speech privacy
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Personalization\Settings" /v AcceptedPrivacyPolicy /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" /v HasAccepted /t REG_DWORD /d 0 /f

:: Set Feedback Frequency to Never
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Siuf\Rules" /v NumberOfSIUFInPeriod /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Siuf\Rules" /v PeriodInNanoSeconds /t REG_DWORD /d 0 /f

:: Disable Sharing Wizard
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v SharingWizardOn /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Folder\SharingWizardOn" /v DefaultValue /t REG_DWORD /d 0 /f

:: Disable Cloud Backup Notification
reg add "HKLM\MOUNTED_DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudExperienceHost" /v DisableCloudOptimizedContent /t REG_DWORD /d 1 /f

echo [+] DEFAULT global tweaks applied
goto AFTER_DEFAULT

:: ============================================================================
:: SYSTEM HIVE TWEAKS
:: ============================================================================
:APPLY_SYSTEM_TWEAKS

:: GLOBAL TWEAKS

:: Disable BitLocker device encryption
reg add "HKLM\MOUNTED_SYSTEM\ControlSet001\Control\BitLocker" /v PreventDeviceEncryption /t REG_DWORD /d 1 /f

:: Disable Push Notification Service (dmwappushservice)
reg add "HKLM\MOUNTED_SYSTEM\ControlSet001\Services\dmwappushservice" /v Start /t REG_DWORD /d 4 /f

:: SYSTEM - Set Windows Update service (wuauserv) to manual for all editions
reg add "HKLM\MOUNTED_SYSTEM\ControlSet001\Services\wuauserv" /v Start /t REG_DWORD /d 3 /f

echo [+] SYSTEM global tweaks applied
goto AFTER_SYSTEM

:: ============================================================================
:: WINDOWS 11 SPECIFIC TWEAKS
:: ============================================================================
:APPLY_WIN11_TWEAKS

:: SOFTWARE - Disable Windows Spotlight
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsSpotlightFeatures /t REG_DWORD /d 1 /f
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsSpotlightOnActionCenter /t REG_DWORD /d 1 /f

:: SOFTWARE - Disable Windows AI and Recall, Hide Home Settings page
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v AllowRecallEnablement /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /t REG_DWORD /d 1 /f
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v SettingsPageVisibility /t REG_SZ /d "hide:home" /f
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\Windows Chat" /v ChatIcon /t REG_DWORD /d 3 /f

:: SOFTWARE - Disable taskbar widgets (Windows 11), DEFAULT - Disable search box suggestions
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarMn /t REG_DWORD /d 0 /f 2>nul
reg add "HKLM\MOUNTED_DEFAULT\Software\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f

:: RunOnce tweaks for Explorer UI (Old Context Menu, Hide Gallery and Home, Enable End task)
:: NOTE, A CMD/TERMINAL POPUP WILL APPEAR, THIS IS NORMAL
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v RestoreWin10ContextMenu /t REG_SZ /d "reg add HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32 /ve /t REG_SZ /d \"\" /f" /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v HideGalleryExplorer /t REG_SZ /d "reg add HKCU\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c} /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 0 /f" /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v HideHomeExplorer1 /t REG_SZ /d "reg add HKCU\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903} /ve /t REG_SZ /d \"CLSID_MSGraphHomeFolder\" /f" /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v HideHomeExplorer2 /t REG_SZ /d "reg add HKCU\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903} /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 0 /f" /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v EnableEndTask /t REG_SZ /d "reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings /v TaskbarEndTask /t REG_DWORD /d 1 /f" /f

:: DEFAULT - Disable Teams auto-start
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Office\Teams" /v HomeUserAutoStartAfterInstall /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Office\Teams" /v PreventFirstLaunchAfterInstall /t REG_DWORD /d 1 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Policies\Microsoft\Office\Teams" /v AutoStart /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_DEFAULT\Software\Policies\Microsoft\Office\Teams" /v PreventFirstLaunchAfterInstall /t REG_DWORD /d 1 /f

:: SYSTEM - Bypass system requirements (Consumer editions only, LTSC doesn't need this)
if not "%WINDOWS_EDITION%"=="W10E" if not "%WINDOWS_EDITION%"=="W11E" (
    echo [*] Applying system requirement bypass ^(Consumer edition^)...
    reg add "HKLM\MOUNTED_SYSTEM\Setup\LabConfig" /v BypassCPUCheck /t REG_DWORD /d 1 /f
    reg add "HKLM\MOUNTED_SYSTEM\Setup\LabConfig" /v BypassRAMCheck /t REG_DWORD /d 1 /f
    reg add "HKLM\MOUNTED_SYSTEM\Setup\LabConfig" /v BypassSecureBootCheck /t REG_DWORD /d 1 /f
    reg add "HKLM\MOUNTED_SYSTEM\Setup\LabConfig" /v BypassStorageCheck /t REG_DWORD /d 1 /f
    reg add "HKLM\MOUNTED_SYSTEM\Setup\LabConfig" /v BypassTPMCheck /t REG_DWORD /d 1 /f
    reg add "HKLM\MOUNTED_SYSTEM\Setup\MoSetup" /v AllowUpgradesWithUnsupportedTPMOrCPU /t REG_DWORD /d 1 /f
    
    :: Additional TPM bypass methods (more reliable)
    reg add "HKLM\MOUNTED_SYSTEM\Setup" /v TPMCheck /t REG_DWORD /d 0 /f
    reg add "HKLM\MOUNTED_SYSTEM\Setup\LabConfig" /v LabConfig /t REG_DWORD /d 1 /f
    reg add "HKLM\MOUNTED_SYSTEM\Setup\MoSetup" /v BypassTPM /t REG_DWORD /d 1 /f
    reg add "HKLM\MOUNTED_SYSTEM\Setup\MoSetup" /v BypassCPU /t REG_DWORD /d 1 /f
    reg add "HKLM\MOUNTED_SYSTEM\Setup\MoSetup" /v BypassSecureBoot /t REG_DWORD /d 1 /f
    reg add "HKLM\MOUNTED_SYSTEM\Setup\MoSetup" /v BypassRAM /t REG_DWORD /d 1 /f
    reg add "HKLM\MOUNTED_SYSTEM\Setup\MoSetup" /v BypassStorage /t REG_DWORD /d 1 /f
    
    :: Disable unsupported hardware notifications
    reg add "HKLM\MOUNTED_DEFAULT\Control Panel\UnsupportedHardwareNotificationCache" /v SV1 /t REG_DWORD /d 0 /f
    reg add "HKLM\MOUNTED_DEFAULT\Control Panel\UnsupportedHardwareNotificationCache" /v SV2 /t REG_DWORD /d 0 /f
) else (
    echo [*] Skipping system requirement bypass ^(LTSC Enterprise doesn't need it^)
)

echo [+] Windows 11 specific tweaks applied

exit /b 0

:: ============================================================================
:: WINDOWS 10 CONSUMER SPECIFIC TWEAKS
:: ============================================================================
:APPLY_WIN10C_TWEAKS

:: SOFTWARE - Disable News and Interests
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\PolicyManager\default\NewsAndInterests\AllowNewsAndInterests" /v value /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" /v EnableFeeds /t REG_DWORD /d 0 /f

:: DEFAULT - Hide News and Interests completely
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Feeds" /v ShellFeedsTaskbarViewMode /t REG_DWORD /d 2 /f

:: SOFTWARE & DEFAULT - Hide Meet Now button
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v HideSCAMeetNow /t REG_DWORD /d 1 /f
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v HideSCAMeetNow /t REG_DWORD /d 1 /f
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\Explorer" /v HideSCAMeetNow /t REG_DWORD /d 1 /f

echo [+] Windows 10 Consumer specific tweaks applied

exit /b 0

:: ============================================================================
:: WINDOWS 10 LTSC SPECIFIC TWEAKS
:: ============================================================================
:APPLY_WIN10E_TWEAKS

:: SOFTWARE - Disable Windows Update completely for LTSC
echo [*] Disabling Windows Update ^(LTSC^)...
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DoNotConnectToWindowsUpdateInternetLocations /t REG_DWORD /d 1 /f
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DisableWindowsUpdateAccess /t REG_DWORD /d 1 /f
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 1 /f

:: SOFTWARE - Disable cloud search for LTSC
echo [*] Disabling cloud search ^(LTSC^)...
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCloudSearch /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v ConnectedSearchUseWeb /t REG_DWORD /d 0 /f
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v DisableWebSearch /t REG_DWORD /d 1 /f

:: SOFTWARE - Disable News and Interests (W10 LTSC may have this)
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\PolicyManager\default\NewsAndInterests\AllowNewsAndInterests" /v value /t REG_DWORD /d 0 /f 2>nul
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /t REG_DWORD /d 0 /f 2>nul
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" /v EnableFeeds /t REG_DWORD /d 0 /f 2>nul

:: DEFAULT - Hide News and Interests completely
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Feeds" /v ShellFeedsTaskbarViewMode /t REG_DWORD /d 2 /f 2>nul

:: SOFTWARE & DEFAULT - Hide Meet Now button
reg add "HKLM\MOUNTED_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v HideSCAMeetNow /t REG_DWORD /d 1 /f 2>nul
reg add "HKLM\MOUNTED_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v HideSCAMeetNow /t REG_DWORD /d 1 /f 2>nul
reg add "HKLM\MOUNTED_SOFTWARE\Policies\Microsoft\Windows\Explorer" /v HideSCAMeetNow /t REG_DWORD /d 1 /f 2>nul

echo [+] Windows 10 LTSC specific tweaks applied

exit /b 0