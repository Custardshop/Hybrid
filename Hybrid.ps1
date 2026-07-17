# ============================================================
# Hybrid - Console Categorized Menu (Verbose Edition)
# ============================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Continue'

$isAdmin = ([Security.Principal.WindowsPrincipal]([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host ""; Write-Host "  ERROR: Must run as Administrator!" -f Magenta
    Write-Host "  Right-click Hybrid.bat > Run as administrator" -f Yellow
    Write-Host ""; Read-Host "  Press Enter to exit"; exit
}
$Host.UI.RawUI.WindowTitle = "Hybrid Optimizer"
try {
    $Host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(120, 300)
    $Host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size(120, 50)
} catch {}

# ============================================================
# CENTER WINDOW ON SCREEN
# ============================================================
try {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WinScreen {
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
    [DllImport("user32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern int GetSystemMetrics(int nIndex);
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@ -EA 0

    $hwnd = [WinScreen]::GetConsoleWindow()
    if ($hwnd -ne [IntPtr]::Zero) {
        $rect = New-Object WinScreen+RECT
        [WinScreen]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
        $winW = $rect.Right - $rect.Left
        $winH = $rect.Bottom - $rect.Top
        $screenW = [WinScreen]::GetSystemMetrics(0)
        $screenH = [WinScreen]::GetSystemMetrics(1)
        $posX = [math]::Floor(($screenW - $winW) / 2)
        $posY = [math]::Floor(($screenH - $winH) / 2)
        [WinScreen]::MoveWindow($hwnd, $posX, $posY, $winW, $winH, $true) | Out-Null
    }
} catch {}

# ============================================================
# HELPERS
# ============================================================
function Get-NvidiaGPU {
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' -EA 0 | Where-Object { (Get-ItemProperty $_.PSPath -Name 'DriverDesc' -EA 0).DriverDesc -match 'NVIDIA' }
}
function Get-PhysNIC {
    Get-NetAdapter -Physical -EA 0 | Where-Object { $_.Status -ne 'Not Present' }
}
function Get-SystemInfo {
    $cpu = (Get-CimInstance Win32_Processor -EA 0 | Select-Object -First 1).Name
    if ($cpu) { $cpu = $cpu.Trim() } else { $cpu = "N/A" }
    $ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem -EA 0).TotalPhysicalMemory / 1GB, 0)
    $gpu = (Get-CimInstance Win32_VideoController -EA 0 | Where-Object { $_.Name -match 'NVIDIA|AMD|Radeon|GeForce|RTX|GTX|Arc' } | Select-Object -First 1).Name
    if (-not $gpu) { $gpu = (Get-CimInstance Win32_VideoController -EA 0 | Select-Object -First 1).Name }
    if ($gpu) { $gpu = $gpu.Trim() } else { $gpu = "N/A" }
    $osObj = Get-CimInstance Win32_OperatingSystem -EA 0
    return @{ CPU=$cpu; RAM="$ramGB GB"; GPU=$gpu; OS="$($osObj.Caption) ($($osObj.Version))" }
}
function Write-Center {
    param([string]$Text,[ConsoleColor]$Color="White")
    $W=$Host.UI.RawUI.WindowSize.Width
    $pad=[math]::Max(0,[math]::Floor(($W-$Text.Length)/2))
    Write-Host (" "*$pad+$Text) -ForegroundColor $Color
}
function Write-CenterMulti {
    param([array]$Parts)
    $totalLen=0; foreach($p in $Parts){$totalLen+=$p.Text.Length}
    $W=$Host.UI.RawUI.WindowSize.Width
    $pad=[math]::Max(0,[math]::Floor(($W-$totalLen)/2))
    Write-Host (" "*$pad) -NoNewline
    foreach($p in $Parts){Write-Host $p.Text -ForegroundColor $p.Color -NoNewline}
    Write-Host ""
}
function Write-Header {
    Clear-Host
    $sys=Get-SystemInfo; $W=$Host.UI.RawUI.WindowSize.Width
    Write-Host ""
    Write-CenterMulti @(@{Text="Administrator:";Color="Cyan"},@{Text=" HYBRID";Color="White"})
    Write-Host ""
   $art = @(
    "▄▄▄   ▄▄▄ ▄▄▄   ▄▄▄ ▄▄▄▄▄▄▄   ▄▄▄▄▄▄▄   ▄▄▄▄▄ ▄▄▄▄▄▄ "
    "███   ███ ███   ███ ███▀▀███▄ ███▀▀███▄  ███  ███▀▀██▄"
    "█████████ ▀███▄███▀ ███▄▄███▀ ███▄▄███▀  ███  ███  ███"
    "███▀▀▀███   ▀███▀   ███  ███▄ ███▀▀██▄   ███  ███  ███"
    "███   ███    ███    ████████▀ ███  ▀███ ▄███▄ ██████▀ "
)
$artClr = @("DarkMagenta", "Magenta", "Yellow", "Magenta", "DarkMagenta")
for ($i = 0; $i -lt $art.Length; $i++) { Write-Center $art[$i] $artClr[$i] }
    Write-Host ""; Write-Center "-----------------------------------------------------" DarkGray; Write-Host ""
    $bw=50; $boxPad=[math]::Max(0,[math]::Floor(($W-$bw-2)/2)); $bp=" "*$boxPad
    Write-Host "${bp}+" -f Cyan -NoNewline; Write-Host ("-"*$bw) -f DarkGray -NoNewline; Write-Host "+" -f Cyan
    foreach($line in @(@{L="CPU";V=$sys.CPU},@{L="RAM";V=$sys.RAM},@{L="GPU";V=$sys.GPU},@{L="OS ";V=$sys.OS})){
        $inner=" $($line.L) : $($line.V)"
        if($inner.Length-gt $bw){$inner=$inner.Substring(0,$bw-1)+"~"}
        $padLen=[math]::Max(0,$bw-$inner.Length)
        Write-Host "${bp}|" -f Cyan -NoNewline
        Write-Host " $($line.L)" -f Cyan -NoNewline; Write-Host " : " -f DarkGray -NoNewline
        Write-Host $line.V -f White -NoNewline; Write-Host (" "*$padLen) -NoNewline; Write-Host "|" -f Cyan
    }
    Write-Host "${bp}+" -f Cyan -NoNewline; Write-Host ("-"*$bw) -f DarkGray -NoNewline; Write-Host "+" -f Cyan
    Write-Host ""; Write-Center "-----------------------------------------------------" DarkGray; Write-Host ""
}

# ============================================================
# COMMAND INTERCEPTORS
# ============================================================
function reg {
    $a=@($args); if($a.Count-eq 0){& reg.exe; return}
    try {
        $v=$a[0].ToString().ToLower()
        if($v-eq'add'){
            $vi=[array]::IndexOf($a,'/v'); $di=[array]::IndexOf($a,'/d')
            $vn=if($vi-ge 0-and($vi+1)-lt $a.Count){$a[$vi+1]}else{''}
            $dd=if($di-ge 0-and($di+1)-lt $a.Count){$a[$di+1]}else{''}
            if($vn){Write-Host "      +-- $vn = $dd" -f Yellow}
        }elseif($v-eq'delete'){
            $vi=[array]::IndexOf($a,'/v')
            $vn=if($vi-ge 0-and($vi+1)-lt $a.Count){$a[$vi+1]}else{''}
            Write-Host "      +-- DEL: $vn" -f Magenta
        }
    } catch {}
    & reg.exe @a 2>$null | Out-Null
}
function bcdedit {
    $a=@($args)
    try {
        if($a.Count-ge 2){
            $vb=$a[0]; $nm=$a[1]
            $vl=if($a.Count-ge 3){" = $($a[2])"}else{""}
            Write-Host "      +-- bcdedit $vb $nm$vl" -f DarkGray
        }
    } catch {}
    & bcdedit.exe @a 2>$null | Out-Null
}
function powercfg {
    $a=@($args)
    try {
        $d=($a -join ' ')
        if($d.Length-gt 65){$d=$d.Substring(0,62)+"..."}
        Write-Host "      +-- powercfg $d" -f DarkGray
    } catch {}
    & powercfg.exe @a 2>$null | Out-Null
}
function netsh {
    $a=@($args)
    try {
        $d=($a -join ' ')
        if($d.Length-gt 65){$d=$d.Substring(0,62)+"..."}
        Write-Host "      +-- netsh $d" -f DarkGray
    } catch {}
    & netsh.exe @a 2>$null | Out-Null
}
function Disable-OServices([string[]]$N) {
    foreach($s in $N){
        Write-Host "      +-- [X] $s" -f Magenta
        sc.exe stop $s 2>$null | Out-Null
        sc.exe config $s start= disabled 2>$null | Out-Null
    }
}
function DisTask([string]$n) {
    $s=$n -replace '^\\Microsoft\\Windows\\','...\'
    $s=$s -replace '^\\Microsoft\\','...\'
    $s=$s -replace '^\\',''
    Write-Host "      +-- [/] $s" -f DarkYellow
    schtasks /Change /TN "$n" /Disable 2>$null | Out-Null
}
function GpuProp([string]$p,[string]$n,$v) {
    Write-Host "      +-- $n = $v" -f Yellow
    Set-ItemProperty -Path $p -Name $n -Value $v -Type DWord -Force -EA 0
}
function NicProp([string]$n,[string]$k,$v) {
    Write-Host "      +-- $k = $v" -f Yellow
    Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword $k -RegistryValue $v -EA 0
}
function NicDisp([string]$n,[string]$d,[string]$v) {
    Write-Host "      +-- $d -> $v" -f Yellow
    Set-NetAdapterAdvancedProperty -Name $n -DisplayName $d -DisplayValue $v -EA 0
}

# ============================================================
# POPUP HELPER
# ============================================================
try {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class HybridMsgBox {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int MessageBox(IntPtr hWnd, string lpText, string lpCaption, uint uType);
}
"@ -EA 0
} catch {}
function Show-RestartPopup([string]$msg) {
    try { [HybridMsgBox]::MessageBox([IntPtr]::Zero, $msg, "Hybrid Optimizer", 0x40) | Out-Null } catch {}
}

# ============================================================
# [1] WINDOWS SETTINGS
# ============================================================
$Cat_Windows = [ordered]@{
    "Visual Effects" = {
        Write-Host "    [Visual FX]" -f Cyan
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f
        reg add "HKCU\Control Panel\Desktop" /v UserPreferencesMask /t REG_BINARY /d 9012038010000000 /f
        reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 0 /f
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAnimations /t REG_DWORD /d 0 /f
        reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 0 /f
        reg add "HKCU\Control Panel\Desktop" /v DragFullWindows /t REG_SZ /d 0 /f
    }
    "GameBar DVR + GameMode OFF" = {
        Write-Host "    [GameDVR]" -f Cyan
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f
        reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v EnableXamlStartMenu /t REG_DWORD /d 0 /f
        reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 0 /f
        reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 0 /f
        reg add "HKCU\Software\Microsoft\GameBar" /v GamePanelStartupTipIndex /t REG_DWORD /d 3 /f
        reg add "HKCU\Software\Microsoft\GameBar" /v UseNexusForGameBarEnabled /t REG_DWORD /d 0 /f
    }
    "Input and USB" = {
        Write-Host "    [Mouse/Keyboard queue]" -f Cyan
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" /v MouseDataQueueSize /t REG_DWORD /d 16 /f
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" /v KeyboardDataQueueSize /t REG_DWORD /d 16 /f
        Write-Host "    [Power Throttling OFF]" -f Cyan
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" /v PowerThrottlingOff /t REG_DWORD /d 1 /f
        Write-Host "    [Mouse accel OFF]" -f Cyan
        reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f
        reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f
        reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f
        Write-Host "    [Keyboard speed]" -f Cyan
        reg add "HKCU\Control Panel\Keyboard" /v KeyboardDelay /t REG_SZ /d 0 /f
        reg add "HKCU\Control Panel\Keyboard" /v KeyboardSpeed /t REG_SZ /d 31 /f
        Write-Host "    [USB idle/suspend]" -f Cyan
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\USB" /v DisableSelectiveSuspend /t REG_DWORD /d 1 /f
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\HidUsb" /v IdleEnable /t REG_DWORD /d 0 /f
        reg add "HKCU\Control Panel\Mouse" /v MouseHoverTime /t REG_SZ /d 0 /f
        Write-Host "    [Accessibility keys]" -f Cyan
        reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 506 /f
        reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v Flags /t REG_SZ /d 58 /f
        reg add "HKCU\Control Panel\Accessibility\MouseKeys" /v Flags /t REG_SZ /d 0 /f
    }
    "Boot and Login Speed" = {
        Write-Host "    [Boot policy]" -f Cyan
        bcdedit /set bootmenupolicy standard
        bcdedit /set bootlog no
        Write-Host "    [Lock screen]" -f Cyan
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreen /t REG_DWORD /d 1 /f
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableLogonBackgroundImage /t REG_DWORD /d 1 /f
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableStatusMessages /t REG_DWORD /d 1 /f
    }
    "SmartScreen + AutoPlay" = {
        Write-Host "    [SmartScreen OFF]" -f Cyan
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableSmartScreen /t REG_DWORD /d 0 /f
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v SmartScreenEnabled /t REG_SZ /d Off /f
        reg add "HKCU\Software\Microsoft\Internet Explorer\PhishingFilter" /v EnabledV9 /t REG_DWORD /d 0 /f
        Write-Host "    [PUA Protection OFF]" -f Cyan
        try { Set-MpPreference -PUAProtection 0 -EA 0 } catch {}
        Write-Host "    [Script Host OFF]" -f Cyan
        reg add "HKLM\SOFTWARE\Microsoft\Windows Script Host\Settings" /v Enabled /t REG_DWORD /d 0 /f
        Write-Host "    [AutoPlay OFF]" -f Cyan
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" /v DisableAutoplay /t REG_DWORD /d 1 /f
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDriveTypeAutoRun /t REG_DWORD /d 255 /f
    }
    "MPO Disable" = {
        Write-Host "    [Multi-Plane Overlay]" -f Cyan
        reg add "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v OverlayTestMode /t REG_DWORD /d 5 /f
    }
    "DWM Optimization" = {
        Write-Host "    [dwm.exe priority]" -f Cyan
        $dw = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe\PerfOptions"
        reg add "$dw" /v CpuPriorityClass /t REG_DWORD /d 4 /f
        reg add "$dw" /v IoPriority /t REG_DWORD /d 3 /f
        Write-Host "    [Aero effects]" -f Cyan
        reg add "HKCU\Software\Microsoft\Windows\DWM" /v EnableAeroPeek /t REG_DWORD /d 0 /f
        reg add "HKCU\Software\Microsoft\Windows\DWM" /v AlwaysHibernateThumbnails /t REG_DWORD /d 0 /f
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f
    }
    "CSRSS Priority" = {
        Write-Host "    [csrss.exe priority]" -f Cyan
        $cs = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions"
        reg add "$cs" /v CpuPriorityClass /t REG_DWORD /d 4 /f
        reg add "$cs" /v IoPriority /t REG_DWORD /d 3 /f
    }
    "Spotlight and Clipboard" = {
        Write-Host "    [Spotlight OFF]" -f Cyan
        $sys = "HKLM\SOFTWARE\Policies\Microsoft\Windows\System"
        reg add "HKCU\Software\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsSpotlightFeatures /t REG_DWORD /d 1 /f
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v RotatingLockScreenEnabled /t REG_DWORD /d 0 /f
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v RotatingLockScreenOverlayEnabled /t REG_DWORD /d 0 /f
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /v "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}" /t REG_DWORD /d 1 /f
        Write-Host "    [Clipboard OFF]" -f Cyan
        reg add "$sys" /v AllowClipboardHistory /t REG_DWORD /d 0 /f
        reg add "$sys" /v AllowCrossDeviceClipboard /t REG_DWORD /d 0 /f
        Write-Host "    [PhoneSvc]" -f Cyan
        sc.exe stop PhoneSvc 2>$null | Out-Null
        sc.exe config PhoneSvc start= disabled 2>$null | Out-Null
        Write-Host "    [Activity Feed OFF]" -f Cyan
        reg add "$sys" /v EnableActivityFeed /t REG_DWORD /d 0 /f
        reg add "$sys" /v PublishUserActivities /t REG_DWORD /d 0 /f
    }
    "News + Copilot Disable" = {
        Write-Host "    [Copilot OFF]" -f Cyan
        reg add "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowCopilotButton /t REG_DWORD /d 0 /f
        Write-Host "    [News/Widgets OFF]" -f Cyan
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /t REG_DWORD /d 0 /f
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 0 /f
        Write-Host "      +-- Kill Widgets" -f Magenta
        Stop-Process -Name "Widgets" -Force -EA 0
        Stop-Process -Name "WidgetService" -Force -EA 0
    }
    "Storage Sense + Edge" = {
        Write-Host "    [Storage Sense OFF]" -f Cyan
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 01 /t REG_DWORD /d 0 /f
        Write-Host "    [Edge policies]" -f Cyan
        $edge = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
        reg add "$edge" /v StartupBoostEnabled /t REG_DWORD /d 0 /f
        reg add "$edge" /v BackgroundModeEnabled /t REG_DWORD /d 0 /f
        reg add "$edge" /v EdgeCollectionsEnabled /t REG_DWORD /d 0 /f
        reg add "$edge" /v EdgeSidebarEnabled /t REG_DWORD /d 0 /f
        reg add "$edge" /v HubsSidebarEnabled /t REG_DWORD /d 0 /f
        reg add "$edge" /v EdgeShoppingAssistantEnabled /t REG_DWORD /d 0 /f
        reg add "$edge" /v ShowRecommendationsEnabled /t REG_DWORD /d 0 /f
        Write-Host "    [Edge prelaunch OFF]" -f Cyan
        reg add "HKLM\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main" /v AllowPrelaunch /t REG_DWORD /d 0 /f
        reg add "HKLM\SOFTWARE\Policies\Microsoft\MicrosoftEdge\TabPreloader" /v AllowTabPreloading /t REG_DWORD /d 0 /f
        Write-Host "      +-- Kill msedge" -f Magenta
        Stop-Process -Name "msedge" -Force -EA 0
    }
    "Windows Ads and Tips" = {
        Write-Host "    [ContentDeliveryManager]" -f Cyan
        $cdm = "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        reg add "$cdm" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f
        reg add "$cdm" /v SoftLandingEnabled /t REG_DWORD /d 0 /f
        reg add "$cdm" /v RotatingLockScreenOverlayEnabled /t REG_DWORD /d 0 /f
        reg add "$cdm" /v RotatingLockScreenEnabled /t REG_DWORD /d 0 /f
        reg add "$cdm" /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f
        reg add "$cdm" /v SubscribedContent-310093Enabled /t REG_DWORD /d 0 /f
        reg add "$cdm" /v SubscribedContent-338388Enabled /t REG_DWORD /d 0 /f
        reg add "$cdm" /v SubscribedContent-338393Enabled /t REG_DWORD /d 0 /f
        reg add "$cdm" /v SubscribedContent-353694Enabled /t REG_DWORD /d 0 /f
        reg add "$cdm" /v SubscribedContent-353696Enabled /t REG_DWORD /d 0 /f
        Write-Host "    [Notifications]" -f Cyan
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 0 /f
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowSyncProviderNotifications /t REG_DWORD /d 0 /f
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowInfoBar /t REG_DWORD /d 0 /f
        Write-Host "    [Consumer features OFF]" -f Cyan
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableSoftLanding /t REG_DWORD /d 1 /f
    }
    "Background Apps" = {
        Write-Host "    [Global background OFF]" -f Cyan
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 1 /f
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsRunInBackground /t REG_DWORD /d 2 /f
    }
    "UWP Background Disable" = {
        Write-Host "    [UWP apps background]" -f Cyan
        $apps = @('Microsoft.Windows.Photos_8wekyb3d8bbwe','Microsoft.ZuneVideo_8wekyb3d8bbwe','Microsoft.BingNews_8wekyb3d8bbwe','Microsoft.BingWeather_8wekyb3d8bbwe','Microsoft.GetHelp_8wekyb3d8bbwe','Microsoft.Getstarted_8wekyb3d8bbwe','Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe','Microsoft.People_8wekyb3d8bbwe','Microsoft.SkypeApp_kzf8qxf38zg5c','Microsoft.MicrosoftSolitaireCollection_8wekyb3d8bbwe','Microsoft.WindowsFeedbackHub_8wekyb3d8bbwe','Microsoft.Xbox.TCUI_8wekyb3d8bbwe','Microsoft.XboxApp_8wekyb3d8bbwe','Microsoft.XboxGameOverlay_8wekyb3d8bbwe','Microsoft.XboxGamingOverlay_8wekyb3d8bbwe','Microsoft.XboxIdentityProvider_8wekyb3d8bbwe','Microsoft.YourPhone_8wekyb3d8bbwe','Microsoft.WindowsMaps_8wekyb3d8bbwe','Microsoft.Messaging_8wekyb3d8bbwe','Microsoft.WindowsSoundRecorder_8wekyb3d8bbwe')
        foreach ($app in $apps) {
            $short = $app -replace '_[a-z0-9]+$',''
            Write-Host "      +-- $short" -f Magenta
            $p = "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\$app"
            reg add "$p" /v Disabled /t REG_DWORD /d 1 /f
            reg add "$p" /v DisabledByUser /t REG_DWORD /d 1 /f
        }
    }
}

# ============================================================
# [2] DEBLOAT
# ============================================================
$Cat_Debloat = [ordered]@{
    "Privacy and Telemetry" = {
        Write-Host "    [Telemetry OFF]" -f Cyan
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f
        Write-Host "    [Cortana OFF]" -f Cyan
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /t REG_DWORD /d 0 /f
        Write-Host "    [Error Reporting OFF]" -f Cyan
        reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v Disabled /t REG_DWORD /d 1 /f
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" /v Disabled /t REG_DWORD /d 1 /f
        Write-Host "    [Activity Feed OFF]" -f Cyan
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /t REG_DWORD /d 0 /f
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v PublishUserActivities /t REG_DWORD /d 0 /f
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v UploadUserActivities /t REG_DWORD /d 0 /f
        Write-Host "    [Windows Update]" -f Cyan
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 1 /f
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUPowerManagement /t REG_DWORD /d 0 /f
        Write-Host "    [Advertising/Location OFF]" -f Cyan
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackProgs /t REG_DWORD /d 0 /f
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v DisableLocation /t REG_DWORD /d 1 /f
    }
    "Windows Services" = {
        Write-Host "    [Disable services]" -f Cyan
        Disable-OServices @('DiagTrack','MapsBroker','XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc','Fax','RetailDemo','RemoteRegistry','WerSvc')
        Write-Host "    [Ensure critical services running]" -f Cyan
        foreach($s in @('Audiosrv','AudioEndpointBuilder','Dhcp','NlaSvc','Netman','WlanSvc','RpcSs','EventLog','PlugPlay','LanmanWorkstation','LanmanServer','WSearch')){
            Write-Host "      +-- [OK] $s" -f Green
            sc.exe config $s start= auto 2>$null | Out-Null
            sc.exe start $s 2>$null | Out-Null
        }
    }
    "Additional Services v1" = {
        Write-Host "    [Disable bloat services]" -f Cyan
        Disable-OServices @('WpnService','WaaSMedicSvc','SSDPSRV','fdPHost','FDResPub','CDPSvc','CDPUserSvc','PcaSvc','TroubleShootingSvc','DusmSvc','InstallService','PhoneSvc','TapiSrv','SEMgrSvc','SharedAccess','RemoteAccess','lmhosts','WpcMonSvc','ScDeviceEnum','SCardSvr','MessagingService','PimIndexMaintenanceSvc','OneSyncSvc','AJRouter')
    }
    "Additional Services v2" = {
        Write-Host "    [Disable more services]" -f Cyan
        Disable-OServices @('iphlpsvc','WinRM','wercplsupport','WMPNetworkSvc','UevAgentService','DsSvc','DialogBlockingService','lfsvc','wisvc','WalletService','DsRoleSvc','NcaSvc','NcdAutoSetup','icssvc')
    }
    "Misc Services" = {
        Write-Host "    [Disable misc]" -f Cyan
        Disable-OServices @('Spooler','SessionEnv','TermService')
        Write-Host "    [RDP OFF]" -f Cyan
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 1 /f
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\CDP" /v RomeSdkConsumerUserSettings /t REG_DWORD /d 0 /f
    }
    "Diagnostic Services" = {
        Write-Host "    [Disable diagnostics]" -f Cyan
        Disable-OServices @('DPS','WdiServiceHost','WdiSystemHost','diagnosticshub.standardcollector.service','diagsvc')
        Write-Host "    [WER OFF]" -f Cyan
        $wer = "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
        reg add "$wer" /v Disabled /t REG_DWORD /d 1 /f
        reg add "$wer" /v DontShowUI /t REG_DWORD /d 1 /f
        reg add "$wer" /v LoggingDisabled /t REG_DWORD /d 1 /f
        reg add "$wer" /v AutoApproveOSDumps /t REG_DWORD /d 0 /f
    }
    "Telemetry Tasks" = {
        Write-Host "    [Disable telemetry tasks]" -f Cyan
        $tList = @('\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser','\Microsoft\Windows\Application Experience\ProgramDataUpdater','\Microsoft\Windows\Customer Experience Improvement Program\Consolidator','\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip','\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector','\Microsoft\Windows\Feedback\Siuf\DmClient','\Microsoft\Windows\Maps\MapsToastTask','\Microsoft\Windows\Maps\MapsUpdateTask','\Microsoft\Windows\Windows Error Reporting\QueueReporting','\Microsoft\Windows\CloudExperienceHost\CreateObjectTask','\Microsoft\Windows\PI\Sqm-Tasks','\Microsoft\Windows\Maintenance\WinSAT','\Microsoft\Windows\Autochk\Proxy','\Microsoft\Windows\Registry\RegIdleBackup','\Microsoft\Windows\MemoryDiagnostic\ProcessMemoryDiagnosticEvents','\Microsoft\Windows\MemoryDiagnostic\RunFullMemoryDiagnostic','\Microsoft\Windows\Mobile Broadband Accounts\MNO Metadata Parser','\Microsoft\Windows\Windows Filtering Platform\BfeOnServiceStartTypeChange')
        foreach ($t in $tList) { DisTask $t }
    }
    "Scheduled Tasks v2" = {
        Write-Host "    [Disable more tasks]" -f Cyan
        $tList2 = @('\Microsoft\Windows\DiskFootprint\Diagnostics','\Microsoft\Windows\DiskFootprint\StorageSense','\Microsoft\Windows\PerfTrack\BackgroundConfigSurveyor','\Microsoft\Windows\Shell\FamilySafetyMonitor','\Microsoft\Windows\Shell\FamilySafetyRefreshTask','\Microsoft\Windows\Shell\IndexerAutomaticMaintenance','\Microsoft\Windows\Diagnosis\Scheduled','\Microsoft\Windows\Diagnosis\RecommendedTroubleshootingScanner','\Microsoft\Windows\Windows Error Reporting\QueueReporting','\Microsoft\Windows\Chkdsk\ProactiveScan','\Microsoft\Windows\Defrag\ScheduledDefrag','\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem','\Microsoft\Office\OfficeTelemetryAgentFallBack2016','\Microsoft\Office\OfficeTelemetryAgentLogOn2016','\Microsoft\Office\Office ClickToRun Service Monitor','\MicrosoftEdgeUpdateTaskMachineCore','\MicrosoftEdgeUpdateTaskMachineUA','\Microsoft\EdgeUpdate\EdgeUpdateTaskMachineCore','\Microsoft\EdgeUpdate\EdgeUpdateTaskMachineUA')
        foreach ($t in $tList2) { DisTask $t }
        Write-Host "    [Edge update services]" -f Cyan
        Disable-OServices @('edgeupdate','edgeupdatem')
    }
    "Autologger Disable" = {
        Write-Host "    [Disable autologgers]" -f Cyan
        $loggers = @('DiagLog','Diagtrack-Listener','Circular Kernel Context Logger','Microsoft-Windows-Rdp-Graphics-RdpIdd-Trace','Microsoft-Windows-Application-Experience','Microsoft-Windows-Application-Experience-Program-Inventory','Microsoft-Windows-Application-Experience-Program-Telemetry','Microsoft-Windows-Kernel-PnP','Microsoft-Windows-SetupPlatform','Microsoft-Windows-SetupQueue','NetCore','NtfsLog','UBPM','UserNotPresentTraceSession','WiFiSession','WindowsDefenderAudit')
        foreach ($l in $loggers) {
            Write-Host "      +-- $l" -f DarkYellow
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$l" /v Start /t REG_DWORD /d 0 /f
        }
        Write-Host "    [WiFi sense OFF]" -f Cyan
        reg add "HKLM\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config" /v AutoConnectAllowedOEM /t REG_DWORD /d 0 /f
        reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting" /v Value /t REG_DWORD /d 0 /f
        reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots" /v Value /t REG_DWORD /d 0 /f
    }
    "ETW Session Disable" = {
        Write-Host "    [Disable ETW sessions]" -f Cyan
        foreach ($s in @('DiagLog','Diagtrack-Listener','WiFiSession','UserNotPresentTraceSession','NtfsLog')) {
            Write-Host "      +-- $s" -f DarkYellow
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$s" /v Start /t REG_DWORD /d 0 /f
        }
    }
    "Delivery Optimization" = {
        Write-Host "    [Delivery Optimization OFF]" -f Cyan
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /t REG_DWORD /d 0 /f
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v DODownloadMode /t REG_DWORD /d 0 /f
        Write-Host "    [DoSvc]" -f Cyan
        Disable-OServices @('DoSvc')
    }
    "Network Noise" = {
        Write-Host "    [SMB1 OFF]" -f Cyan
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" /v EnableMulticast /t REG_DWORD /d 0 /f
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v DisableBandwidthThrottling /t REG_DWORD /d 1 /f
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v DisableLargeMtu /t REG_DWORD /d 0 /f
        Write-Host "      +-- Set-SmbServerConfiguration SMB1 = off" -f DarkGray
        Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -EA 0
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f
        Write-Host "    [Disable P2P discovery]" -f Cyan
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\SSDPSRV" /v Start /t REG_DWORD /d 4 /f
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\fdPHost" /v Start /t REG_DWORD /d 4 /f
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\FDResPub" /v Start /t REG_DWORD /d 4 /f
    }
    "Windows Defender" = {
        Write-Host "    [Defender realtime OFF]" -f Cyan
        try { Set-MpPreference -DisableRealtimeMonitoring $true -EA 0 } catch {}
        try { Set-MpPreference -DisableBehaviorMonitoring $true -EA 0 } catch {}
        try { Set-MpPreference -DisableIOAVProtection $true -EA 0 } catch {}
        try { Set-MpPreference -DisableScriptScanning $true -EA 0 } catch {}
        try { Set-MpPreference -SubmitSamplesConsent 2 -EA 0 } catch {}
        try { Set-MpPreference -MAPSReporting 0 -EA 0 } catch {}
        Write-Host "    [Defender policy OFF]" -f Cyan
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware /t REG_DWORD /d 1 /f
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableRealtimeMonitoring /t REG_DWORD /d 1 /f
    }
    "NVIDIA Telemetry" = {
        Write-Host "    [NVIDIA telemetry tasks]" -f Cyan
        $nvT = @('\NVIDIA\NvDriverUpdateCheckDaily{B2FE1952-0786-46D3-8684-AB2B5E2D3B0A}','\NVIDIA\NvTmRep_CrashReport1_{B2FE1952-0786-46D3-8684-AB2B5E2D3B0A}','\NVIDIA\NvTmRep_CrashReport2_{B2FE1952-0786-46D3-8684-AB2B5E2D3B0A}','\NVIDIA\NvTmRep_CrashReport3_{B2FE1952-0786-46D3-8684-AB2B5E2D3B0A}','\NVIDIA\NvTmRep_CrashReport4_{B2FE1952-0786-46D3-8684-AB2B5E2D3B0A}','\NVIDIA\NvTmMon_{B2FE1952-0786-46D3-8684-AB2B5E2D3B0A}')
        foreach ($t in $nvT) { DisTask $t }
        Write-Host "    [NVIDIA opt-out]" -f Cyan
        $nv = "HKLM:\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client"
        if (Test-Path $nv) { Set-ItemProperty -Path $nv -Name 'OptInOrOutPreference' -Value 0 -Type DWord -Force -EA 0 }
    }
    "System Restore Off" = {
        Write-Host "    [System Restore OFF]" -f Cyan
        Disable-ComputerRestore -Drive "C:\" -EA 0
        Write-Host "      +-- Delete all shadows" -f Magenta
        $vp = Start-Process vssadmin -ArgumentList "delete shadows /all /quiet" -NoNewWindow -PassThru -EA 0
        if ($vp -and -not $vp.WaitForExit(10000)) { try { $vp.Kill() } catch {} }
        if ($vp) { $vp.Dispose() }
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v RPSessionInterval /t REG_DWORD /d 0 /f
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v DisableSR /t REG_DWORD /d 1 /f
    }
}

# ============================================================
# [3] CPU TWEAKS
# ============================================================
$Cat_CPU = [ordered]@{
    "Kernel + Timer (TSC)" = {
        Write-Host "    [BCDEdit kernel]" -f Cyan
        bcdedit /deletevalue useplatformclock
        bcdedit /deletevalue useplatformtick
        bcdedit /set disabledynamictick yes
        bcdedit /set tscsyncpolicy Enhanced
        bcdedit /set nx OptOut
        Write-Host "    [DisablePagingExecutive]" -f Cyan
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v DisablePagingExecutive /t REG_DWORD /d 1 /f
    }
    "Timer Resolution" = {
        Write-Host "    [GlobalTimerResolutionRequests]" -f Cyan
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v GlobalTimerResolutionRequests /t REG_DWORD /d 1 /f
    }
    "Timer Resolution Runtime" = {
        Write-Host "    [NtSetTimerResolution max]" -f Cyan
        $timerCode = 'using System;using System.Runtime.InteropServices;public class WinTimer{[DllImport("ntdll.dll")]public static extern uint NtSetTimerResolution(uint d,bool s,out uint c);[DllImport("ntdll.dll")]public static extern uint NtQueryTimerResolution(out uint mn,out uint mx,out uint c);}'
        try { Add-Type -TypeDefinition $timerCode -EA 0 } catch {}
        $min=0; $max=0; $cur=0
        [WinTimer]::NtQueryTimerResolution([ref]$min,[ref]$max,[ref]$cur) | Out-Null
        [WinTimer]::NtSetTimerResolution($max,$true,[ref]$cur) | Out-Null
        $tv = $max
        Write-Host "      +-- Timer resolution = $tv" -f Yellow
        Write-Host "    [Scheduled task on logon]" -f Cyan
        $hp = "$env:SystemRoot\System32\Hybrid_TimerRes.ps1"
        $psBody = "try{Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public class W{[DllImport(`"ntdll.dll`")]public static extern uint NtSetTimerResolution(uint d,bool s,out uint c);}' -EA 0}catch{};`$c=0;[W]::NtSetTimerResolution($tv,`$true,[ref]`$c);while(`$true){Start-Sleep -Seconds 120}"
        [System.IO.File]::WriteAllText($hp, $psBody, [System.Text.Encoding]::Unicode)
        schtasks /Create /TN "Hybrid_TimerResolution" /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$hp`"" /SC ONLOGON /RL HIGHEST /F 2>$null | Out-Null
    }
    "Process Priority" = {
        Write-Host "    [SystemProfile]" -f Cyan
        $mm = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        $g = "$mm\Tasks\Games"
        reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v SvcHostSplitThresholdInKB /t REG_DWORD /d 33554432 /f
        reg add "$mm" /v SystemResponsiveness /t REG_DWORD /d 0 /f
        reg add "$mm" /v NetworkThrottlingIndex /t REG_DWORD /d 4294967295 /f
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Executive" /v AdditionalCriticalWorkerThreads /t REG_DWORD /d 2 /f
        Write-Host "    [Games task]" -f Cyan
        reg add "$g" /v "GPU Priority" /t REG_DWORD /d 8 /f
        reg add "$g" /v Priority /t REG_DWORD /d 6 /f
        reg add "$g" /v "Scheduling Category" /t REG_SZ /d High /f
        reg add "$g" /v "SFIO Priority" /t REG_SZ /d High /f
        reg add "$g" /v Affinity /t REG_DWORD /d 0 /f
        reg add "$g" /v "Background Only" /t REG_SZ /d False /f
        reg add "$g" /v "Clock Rate" /t REG_DWORD /d 10000 /f
        Write-Host "    [Core parking attribute]" -f Cyan
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\501a4d13-42af-4429-9fd1-a8218c268e20\ee12f2c1-98bb-455b-9e09-ae4c1e16cb45" /v Attributes /t REG_DWORD /d 2 /f
    }
    "MMCSS Deep Tuning" = {
        $mm = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        $g = "$mm\Tasks\Games"
        $dp = "$mm\Tasks\Display Post Processing"
        $pa = "$mm\Tasks\Pro Audio"
        $au = "$mm\Tasks\Audio"
        Write-Host "    [SystemProfile global]" -f Cyan
        reg add "$mm" /v AlwaysOn /t REG_DWORD /d 1 /f
        reg add "$mm" /v NoLazyMode /t REG_DWORD /d 1 /f
        Write-Host "    [Games GPU 18, Latency Sensitive]" -f Cyan
        reg add "$g" /v "GPU Priority" /t REG_DWORD /d 18 /f
        reg add "$g" /v Priority /t REG_DWORD /d 6 /f
        reg add "$g" /v "Scheduling Category" /t REG_SZ /d High /f
        reg add "$g" /v "SFIO Priority" /t REG_SZ /d High /f
        reg add "$g" /v "Clock Rate" /t REG_DWORD /d 10000 /f
        reg add "$g" /v "Background Only" /t REG_SZ /d False /f
        reg add "$g" /v Affinity /t REG_DWORD /d 0 /f
        reg add "$g" /v "Latency Sensitive" /t REG_SZ /d True /f
        Write-Host "    [Display Post Processing]" -f Cyan
        reg add "$dp" /v "GPU Priority" /t REG_DWORD /d 18 /f
        reg add "$dp" /v Priority /t REG_DWORD /d 8 /f
        reg add "$dp" /v "Scheduling Category" /t REG_SZ /d High /f
        reg add "$dp" /v "SFIO Priority" /t REG_SZ /d High /f
        reg add "$dp" /v "Clock Rate" /t REG_DWORD /d 10000 /f
        reg add "$dp" /v "Background Only" /t REG_SZ /d True /f
        reg add "$dp" /v Affinity /t REG_DWORD /d 0 /f
        reg add "$dp" /v BackgroundPriority /t REG_DWORD /d 24 /f
        reg add "$dp" /v "Latency Sensitive" /t REG_SZ /d True /f
        Write-Host "    [Pro Audio]" -f Cyan
        reg add "$pa" /v Affinity /t REG_DWORD /d 7 /f
        reg add "$pa" /v "Latency Sensitive" /t REG_SZ /d True /f
        Write-Host "    [Audio]" -f Cyan
        reg add "$au" /v Affinity /t REG_DWORD /d 7 /f
        reg add "$au" /v "Scheduling Category" /t REG_SZ /d Medium /f
    }
    "Audio Latency" = {
        Write-Host "    [Pro Audio task]" -f Cyan
        $a = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio"
        reg add "$a" /v Affinity /t REG_DWORD /d 0 /f
        reg add "$a" /v "Background Only" /t REG_SZ /d False /f
        reg add "$a" /v "Clock Rate" /t REG_DWORD /d 10000 /f
        reg add "$a" /v "GPU Priority" /t REG_DWORD /d 8 /f
        reg add "$a" /v Priority /t REG_DWORD /d 1 /f
        reg add "$a" /v "Scheduling Category" /t REG_SZ /d High /f
        reg add "$a" /v "SFIO Priority" /t REG_SZ /d High /f
    }
    "Processor Power" = {
        Write-Host "    [CPU throttle 100% min/max]" -f Cyan
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100
        powercfg /setactive SCHEME_CURRENT
        Write-Host "    [Hibernate OFF]" -f Cyan
        powercfg /hibernate off
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f
    }
    "CPU Core Parking" = {
        Write-Host "    [Core parking 100% min/max]" -f Cyan
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" /v ValueMin /t REG_DWORD /d 0 /f
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMAXCORES 100
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR HETEROCLASS1INITIALPERF 100
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR HETEROCLASS0FLOORPERF 100
        powercfg /setactive SCHEME_CURRENT
    }
    "CPU Scheduling Deep" = {
        Write-Host "    [PriorityControl]" -f Cyan
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 0xFA332A /f
        Write-Host "    [Prefetch/Superfetch]" -f Cyan
        $pp = "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
        $hasHDD = Get-PhysicalDisk | Where-Object { $_.MediaType -eq 'HDD' }
        if ($hasHDD) {
            Write-Host "      +-- HDD detected: Prefetcher=3, Superfetch=0" -f DarkGray
            reg add "$pp" /v EnablePrefetcher /t REG_DWORD /d 3 /f
            reg add "$pp" /v EnableSuperfetch /t REG_DWORD /d 0 /f
        } else {
            Write-Host "      +-- SSD only: Prefetcher=0, Superfetch=0" -f DarkGray
            reg add "$pp" /v EnablePrefetcher /t REG_DWORD /d 0 /f
            reg add "$pp" /v EnableSuperfetch /t REG_DWORD /d 0 /f
        }
    }
    "Spectre and Meltdown" = {
        Write-Host "    [Disable Spectre/Meltdown mitigations]" -f Cyan
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverride /t REG_DWORD /d 3 /f
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverrideMask /t REG_DWORD /d 3 /f
    }
    "Exploit Protection" = {
        Write-Host "    [CFG OFF]" -f Cyan
        try { Set-ProcessMitigation -System -Disable CFG -EA 0 } catch {}
        Write-Host "    [SEHOP OFF]" -f Cyan
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v DisableExceptionChainValidation /t REG_DWORD /d 1 /f
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v MoveImages /t REG_DWORD /d 0 /f
    }
}

# ============================================================
# [4] MISCELLANEOUS
# ============================================================
$Cat_Misc = [ordered]@{
    "Memory Management" = {
        Write-Host "    [Memory Management]" -f Cyan
        $mmPath = "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        reg add "$mmPath" /v SystemCacheDirtyPageThreshold /t REG_DWORD /d 0 /f
        reg add "$mmPath" /v ClearPageFileAtShutdown /t REG_DWORD /d 0 /f
        Write-Host "    [Hibernate OFF]" -f Cyan
        powercfg -h off
        Write-Host "    [OneDrive kill]" -f Cyan
        Write-Host "      +-- Kill OneDrive.exe" -f Magenta
        taskkill /f /im OneDrive.exe 2>$null | Out-Null
        reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /f 2>$null | Out-Null
    }
    "Memory Compression" = {
        Write-Host "    [Disable-MMAgent MemoryCompression]" -f Cyan
        try { Disable-MMAgent -MemoryCompression -EA 0 } catch {}
    }
    "LargeSystemCache + IoPageLockLimit" = {
        Write-Host "    [RAM-aware cache settings]" -f Cyan
        $ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem -EA 0).TotalPhysicalMemory / 1GB)
        Write-Host "      +-- RAM = ${ramGB}GB" -f DarkGray
        $lsc = if ($ramGB -ge 16) { 1 } else { 0 }
        $mmReg = "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        reg add "$mmReg" /v LargeSystemCache /t REG_DWORD /d $lsc /f
        $ramMB = [math]::Round((Get-CimInstance Win32_ComputerSystem -EA 0).TotalPhysicalMemory / 1MB)
        $iol = [math]::Round($ramMB * 0.75 * 4096)
        reg add "$mmReg" /v IoPageLockLimit /t REG_DWORD /d $iol /f
    }
    "Pagefile Optimize" = {
        Write-Host "    [Pagefile fixed 50% RAM]" -f Cyan
        $csObj = Get-CimInstance Win32_ComputerSystem -EA 0
        if ($csObj) {
            $csObj.AutomaticManagedPagefile = $false
            try { Set-CimInstance -InputObject $csObj -EA 0 } catch {}
        }
        Start-Sleep -Milliseconds 500
        $ramMB2 = [math]::Round((Get-CimInstance Win32_ComputerSystem -EA 0).TotalPhysicalMemory / 1MB)
        $pfsz = [math]::Max(4096, [math]::Round($ramMB2 * 0.5))
        Write-Host "      +-- Size = ${pfsz}MB" -f Yellow
        $pfObj = Get-CimInstance -ClassName Win32_PageFileSetting -Filter "SettingID='pagefile.sys @ C:'" -EA 0
        if ($pfObj) {
            $pfObj.InitialSize = $pfsz
            $pfObj.MaximumSize = $pfsz
            try { Set-CimInstance -InputObject $pfObj -EA 0 } catch {}
        } else {
            try {
                $pgNew = ([WMIClass]"root\cimv2:Win32_PageFileSetting").CreateInstance()
                $pgNew.Name = "C:\pagefile.sys"
                $pgNew.InitialSize = $pfsz
                $pgNew.MaximumSize = $pfsz
                $pgNew.Put() | Out-Null
            } catch {}
        }
        Write-Host "    [Non-C: indexing OFF]" -f Cyan
        Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter -and $_.DriveLetter -ne 'C' } | ForEach-Object {
            Write-Host "      +-- $($_.DriveLetter): indexing OFF" -f DarkGray
            $vObj = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter='$($_.DriveLetter):'" -EA 0
            if ($vObj) {
                $vObj.IndexingEnabled = $false
                try { Set-CimInstance -InputObject $vObj -EA 0 } catch {}
            }
        }
    }
    "Storage Optimizations" = {
        Write-Host "    [8dot3 OFF, TRIM ON]" -f Cyan
        fsutil behavior set disable8dot3 1 2>$null | Out-Null
        fsutil behavior set disabledeletenotify 0 2>$null | Out-Null
        Write-Host "    [ReTrim all volumes]" -f Cyan
        Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter } | ForEach-Object {
            Write-Host "      +-- $($_.DriveLetter): ReTrim" -f DarkGray
            Optimize-Volume -DriveLetter $_.DriveLetter -ReTrim -EA 0
        }
    }
    "NTFS Deep" = {
        Write-Host "    [NTFS tuning]" -f Cyan
        $fs = "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem"
        reg add "$fs" /v NtfsMemoryUsage /t REG_DWORD /d 2 /f
        reg add "$fs" /v NtfsDisableLastAccessUpdate /t REG_DWORD /d 2147483649 /f
        reg add "$fs" /v NtfsDisable8dot3NameCreation /t REG_DWORD /d 1 /f
        reg add "$fs" /v PathCache /t REG_DWORD /d 128 /f
        reg add "$fs" /v Win31FileSystem /t REG_DWORD /d 0 /f
        Write-Host "    [EFS OFF]" -f Cyan
        Disable-OServices @('EFS')
    }
    "NVMe Deep" = {
        Write-Host "    [NVMe idle/ASPM OFF]" -f Cyan
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" /v IdlePowerStateEnabled /t REG_DWORD /d 0 /f
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" /v NvmeDisableASPM /t REG_DWORD /d 1 /f
        Write-Host "    [NVMe IRQ affinity]" -f Cyan
        Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\PCI' -EA 0 | Where-Object {
            (Get-ItemProperty $_.PSPath -Name 'HardwareID' -EA 0).HardwareID -match 'NVMe|stornvme'
        } | ForEach-Object {
            $desc = (Get-ItemProperty $_.PSPath -Name 'DeviceDesc' -EA 0).DeviceDesc
            Write-Host "      +-- $desc -> Core 1" -f Yellow
            $aff = ($_.PSPath + '\Device Parameters\Interrupt Management\Affinity Policy')
            if (-not (Test-Path $aff)) { New-Item -Path $aff -Force -EA 0 | Out-Null }
            Set-ItemProperty -Path $aff -Name 'DevicePolicy' -Value 4 -Type DWord -Force -EA 0
            Set-ItemProperty -Path $aff -Name 'AssignmentSetOverride' -Value 0x02 -Type DWord -Force -EA 0
        }
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters" /v IoTimeoutValue /t REG_DWORD /d 255 /f
    }
    "GPU Display (HAGS OFF)" = {
        Write-Host "    [HAGS OFF]" -f Cyan
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 1 /f
        reg add "HKLM\SOFTWARE\Microsoft\DirectX\GraphicsSettings" /v HwSchMode /t REG_DWORD /d 1 /f
        Write-Host "    [TDR settings]" -f Cyan
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrLevel /t REG_DWORD /d 2 /f
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrDelay /t REG_DWORD /d 60 /f
    }
    "GPU Cache Cleanup" = {
        Write-Host "    [Delete GPU caches]" -f Cyan
        $gCaches = @("$env:LOCALAPPDATA\NVIDIA\DXCache\*","$env:LOCALAPPDATA\NVIDIA\GLCache\*","$env:LOCALAPPDATA\AMD\DxCache\*","$env:LOCALAPPDATA\D3DSCache\*","$env:WINDIR\SoftwareDistribution\DeliveryOptimization\*")
        foreach ($gc in $gCaches) {
            Write-Host "      +-- clean $gc" -f Magenta
            Remove-Item -Path $gc -Recurse -Force -EA 0
        }
    }
    "IRQ MSI Mode" = {
        Write-Host "    [Enable MSI + DevicePriority for all PCI]" -f Cyan
        Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\PCI' -EA 0 | ForEach-Object {
            $msi = ($_.PSPath + '\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties')
            if (Test-Path $msi) {
                $desc = (Get-ItemProperty $_.PSPath -Name 'DeviceDesc' -EA 0).DeviceDesc
                Write-Host "      +-- MSI: $desc" -f Yellow
                Set-ItemProperty -Path $msi -Name MSISupported -Value 1 -Type DWord -Force -EA 0
                $aff = ($_.PSPath + '\Device Parameters\Interrupt Management\Affinity Policy')
                if (-not (Test-Path $aff)) { New-Item -Path $aff -Force -EA 0 | Out-Null }
                Set-ItemProperty -Path $aff -Name DevicePriority -Value 3 -Type DWord -Force -EA 0
            }
        }
    }
    "Interrupt Affinity" = {
        Write-Host "    [Per-device IRQ affinity]" -f Cyan
        Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\PCI' -EA 0 | ForEach-Object {
            $desc = (Get-ItemProperty $_.PSPath -Name 'DeviceDesc' -EA 0).DeviceDesc
            $hwid = (Get-ItemProperty $_.PSPath -Name 'HardwareID' -EA 0).HardwareID
            $aff = ($_.PSPath + '\Device Parameters\Interrupt Management\Affinity Policy')
            if (-not (Test-Path $aff)) { New-Item -Path $aff -Force -EA 0 | Out-Null }
            if ($hwid -and ($hwid[0] -match 'VEN_10DE' -or $hwid[0] -match 'VEN_1002')) {
                Write-Host "      +-- GPU: $desc -> Core 1" -f Yellow
                Set-ItemProperty -Path $aff -Name 'DevicePolicy' -Value 4 -Type DWord -Force -EA 0
                Set-ItemProperty -Path $aff -Name 'AssignmentSetOverride' -Value 0x02 -Type DWord -Force -EA 0
            }
            if ($desc -match 'Ethernet|Network|LAN|Intel.*Connection' -or ($hwid -and ($hwid[0] -match 'VEN_8086.*DEV_15' -or $hwid[0] -match 'VEN_10EC'))) {
                Write-Host "      +-- NIC: $desc -> Core 2" -f Yellow
                Set-ItemProperty -Path $aff -Name 'DevicePolicy' -Value 4 -Type DWord -Force -EA 0
                Set-ItemProperty -Path $aff -Name 'AssignmentSetOverride' -Value 0x04 -Type DWord -Force -EA 0
            }
            if ($desc -match 'USB|xHCI|Host Controller') {
                Write-Host "      +-- USB: $desc -> Core 3" -f Yellow
                Set-ItemProperty -Path $aff -Name 'DevicePolicy' -Value 4 -Type DWord -Force -EA 0
                Set-ItemProperty -Path $aff -Name 'AssignmentSetOverride' -Value 0x08 -Type DWord -Force -EA 0
            }
        }
    }
    "Hyper-V and VBS" = {
        Write-Host "    [Hyper-V OFF]" -f Cyan
        dism /Online /Disable-Feature /FeatureName:Microsoft-Hyper-V-All /NoRestart 2>$null | Out-Null
        bcdedit /set hypervisorlaunchtype off
        Write-Host "    [VBS/HVCI OFF]" -f Cyan
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 0 /f
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v Enabled /t REG_DWORD /d 0 /f
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\LSA" /v LsaCfgFlags /t REG_DWORD /d 0 /f
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" /v Enabled /t REG_DWORD /d 0 /f
    }
    "VBS/HVCI Core Isolation" = {
        Write-Host "    [Core Isolation extra OFF]" -f Cyan
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v RequirePlatformSecurityFeatures /t REG_DWORD /d 0 /f
        bcdedit /set vsmlaunchtype Off
    }
    "PCI-E ASPM" = {
        Write-Host "    [ASPM OFF]" -f Cyan
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0
        powercfg /setactive SCHEME_CURRENT
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\PnP\Pci" /v DisableASPM /t REG_DWORD /d 1 /f
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\501a4d13-42af-4429-9fd1-a8218c268e20\ee12f2c1-98bb-455b-9e09-ae4c1e16cb45" /v Attributes /t REG_DWORD /d 2 /f
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" /v NvmeDisableASPM /t REG_DWORD /d 1 /f
    }
    "Connected Standby" = {
        Write-Host "    [Connected Standby OFF]" -f Cyan
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v CsEnabled /t REG_DWORD /d 0 /f
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v PlatformAoAcOverride /t REG_DWORD /d 0 /f
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v AwayModeEnabled /t REG_DWORD /d 0 /f
    }
    "Device Power" = {
        Write-Host "    [USB hub idle OFF]" -f Cyan
        Get-CimInstance -ClassName Win32_USBHub -EA 0 | ForEach-Object {
            Write-Host "      +-- $($_.Name)" -f DarkGray
            $r = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.PNPDeviceID)\Device Parameters\WDF"
            if (Test-Path $r) { Set-ItemProperty -Path $r -Name 'IdleInWorkingState' -Value 0 -Type DWord -Force -EA 0 }
        }
        Write-Host "    [NVMe idle power OFF]" -f Cyan
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" /v IdlePowerStateEnabled /t REG_DWORD /d 0 /f
    }
    "USB Power Deep" = {
        Write-Host "    [USB hub/controller idle OFF]" -f Cyan
        Get-CimInstance -ClassName Win32_USBHub -EA 0 | ForEach-Object {
            Write-Host "      +-- $($_.Name)" -f DarkGray
            $r = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.PNPDeviceID)\Device Parameters"
            if (Test-Path "$r\WDF") { Set-ItemProperty -Path "$r\WDF" -Name 'IdleInWorkingState' -Value 0 -Type DWord -Force -EA 0 }
            if (Test-Path "$r\USB") { Set-ItemProperty -Path "$r\USB" -Name 'DeviceIdleEnabled' -Value 0 -Type DWord -Force -EA 0 }
        }
        Get-CimInstance -ClassName Win32_USBController -EA 0 | ForEach-Object {
            Write-Host "      +-- $($_.Name)" -f DarkGray
            $r = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.PNPDeviceID)\Device Parameters\WDF"
            if (Test-Path $r) { Set-ItemProperty -Path $r -Name 'IdleInWorkingState' -Value 0 -Type DWord -Force -EA 0 }
        }
        Write-Host "    [Selective Suspend OFF]" -f Cyan
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\USB" /v DisableSelectiveSuspend /t REG_DWORD /d 1 /f
    }
}

# ============================================================
# [5] CLEAN TEMP FILES
# ============================================================
$Cat_Clean = [ordered]@{
    "Junk and Log Cleanup" = {
        Write-Host "    [Delete temp files]" -f Cyan
        $tmpPaths = @("$env:TEMP\*","$env:WINDIR\Temp\*","$env:WINDIR\Prefetch\*")
        foreach ($tp in $tmpPaths) {
            Write-Host "      +-- clean $tp" -f Magenta
            Remove-Item -Path $tp -Recurse -Force -EA 0
        }
        Write-Host "    [Windows Update cache]" -f Cyan
        Stop-Service wuauserv -Force -EA 0
        Stop-Service UsoSvc -Force -EA 0
        Write-Host "      +-- clean SoftwareDistribution\Download" -f Magenta
        Remove-Item -Path "$env:WINDIR\SoftwareDistribution\Download\*" -Recurse -Force -EA 0
        Start-Service wuauserv -EA 0
        Write-Host "    [Clear event logs]" -f Cyan
        $logNames = Get-WinEvent -ListLog * -EA 0 | Where-Object { $_.RecordCount -gt 0 -and $_.IsEnabled } | Select-Object -ExpandProperty LogName
        $logCount = 0
        foreach ($ln in $logNames) {
            $logCount++
            if ($logCount % 20 -eq 0) { Write-Host "      +-- clearing log $logCount/$($logNames.Count)..." -f DarkGray }
            $p = Start-Process wevtutil.exe -ArgumentList "cl `"$ln`"" -NoNewWindow -PassThru -EA 0
            if ($p -and -not $p.WaitForExit(3000)) { try { $p.Kill() } catch {} }
            if ($p) { $p.Dispose() }
        }
        Write-Host "      +-- $logCount logs cleared" -f Yellow
        Write-Host "    [Recycle Bin]" -f Cyan
        Clear-RecycleBin -Force -EA 0
    }
}

# ============================================================
# [6] NETWORK & NIC
# ============================================================
$Cat_Network = [ordered]@{
    "Network and DNS" = {
        $ntp = "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        $afd = "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters"
        Write-Host "    [TCP global]" -f Cyan
        netsh int tcp set global rss=enabled
        netsh int tcp set global autotuninglevel=normal
        netsh int tcp set global timestamps=disabled
        netsh int tcp set global chimney=disabled
        netsh int tcp set global rsc=disabled
        netsh int tcp set heuristics disabled
        netsh int tcp set global ecncapability=enabled
        netsh int tcp set global fastopen=enabled
        netsh int udp set global uro=disabled
        Write-Host "    [QoS]" -f Cyan
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f
        Write-Host "    [Tcpip\Parameters]" -f Cyan
        reg add "$ntp" /v TCPNoDelay /t REG_DWORD /d 1 /f
        reg add "$ntp" /v TcpAckFrequency /t REG_DWORD /d 1 /f
        reg add "$ntp" /v DefaultTTL /t REG_DWORD /d 64 /f
        reg add "$ntp" /v DisabledComponents /t REG_DWORD /d 255 /f
        reg add "$ntp" /v EnablePMTUDiscovery /t REG_DWORD /d 1 /f
        reg add "$ntp" /v EnableRSS /t REG_DWORD /d 1 /f
        reg add "$ntp" /v EnableTCPChimney /t REG_DWORD /d 0 /f
        Write-Host "    [AFD Parameters]" -f Cyan
        reg add "$afd" /v FastSendDatagramThreshold /t REG_DWORD /d 65536 /f
        reg add "$afd" /v DefaultReceiveWindow /t REG_DWORD /d 16384 /f
        reg add "$afd" /v DefaultSendWindow /t REG_DWORD /d 16384 /f
        reg add "$afd" /v FastCopyReceiveThreshold /t REG_DWORD /d 1536 /f
        Write-Host "    [DNS multicast OFF]" -f Cyan
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\QoS" /v "Do not use NLA" /t REG_SZ /d 1 /f
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" /v EnableMulticast /t REG_DWORD /d 0 /f
        Write-Host "    [NetBIOS OFF on all interfaces]" -f Cyan
        Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\services\NetBT\Parameters\Interfaces' -EA 0 | ForEach-Object {
            Set-ItemProperty -Path $_.PSPath -Name NetbiosOptions -Value 2 -EA 0
        }
        Write-Host "    [NIC: LSO OFF, InterruptModeration OFF]" -f Cyan
        Get-PhysNIC | ForEach-Object {
            Write-Host "      +-- $($_.Name)" -f DarkGray
            Disable-NetAdapterLso -Name $_.Name -EA 0
            Set-NetAdapterAdvancedProperty -Name $_.Name -RegistryKeyword '*InterruptModeration' -RegistryValue 0 -EA 0
        }
        Write-Host "    [DNS servers: 1.1.1.1, 8.8.8.8]" -f Cyan
        Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.Physical } | ForEach-Object {
            Write-Host "      +-- $($_.Name) -> 1.1.1.1, 8.8.8.8" -f Yellow
            Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses ('1.1.1.1','8.8.8.8') -EA 0
            Disable-NetAdapterPowerManagement -Name $_.Name -EA 0
        }
        Write-Host "    [flushdns]" -f Cyan
        ipconfig /flushdns 2>$null | Out-Null
    }
    "Nagle Algorithm" = {
        Write-Host "    [Per-interface Nagle OFF]" -f Cyan
        Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' -EA 0 | ForEach-Object {
            Set-ItemProperty -Path $_.PSPath -Name TcpAckFrequency -Value 1 -Type DWord -Force -EA 0
            Set-ItemProperty -Path $_.PSPath -Name TCPNoDelay -Value 1 -Type DWord -Force -EA 0
            Set-ItemProperty -Path $_.PSPath -Name TcpDelAckTicks -Value 0 -Type DWord -Force -EA 0
        }
    }
    "NIC Advanced" = {
        Write-Host "    [NIC advanced properties]" -f Cyan
        Get-PhysNIC | ForEach-Object {
            $n = $_.Name
            Write-Host "      +-- [$n]" -f White
            NicDisp $n 'Flow Control' 'Disabled'
            NicDisp $n 'Energy Efficient Ethernet' 'Disabled'
            NicDisp $n 'Green Ethernet' 'Disabled'
            NicDisp $n 'Receive Buffers' '2048'
            NicDisp $n 'Transmit Buffers' '2048'
            NicProp $n '*InterruptModeration' 0
            Write-Host "      |  +-- RSC OFF" -f DarkGray
            Disable-NetAdapterRsc -Name $n -EA 0
            Write-Host "      |  +-- WakeOnMagicPacket/Pattern OFF" -f DarkGray
            Set-NetAdapterPowerManagement -Name $n -WakeOnMagicPacket Disabled -WakeOnPattern Disabled -EA 0
        }
    }
    "NIC Flow + RSS Core" = {
        Write-Host "    [NIC Flow/RSS/IPv6]" -f Cyan
        Get-PhysNIC | ForEach-Object {
            $n = $_.Name
            Write-Host "      +-- [$n]" -f White
            NicDisp $n 'Packet Coalescing' 'Disabled'
            NicProp $n '*RssBaseProcNumber' 2
            $cores = (Get-CimInstance Win32_Processor -EA 0).NumberOfLogicalProcessors
            NicProp $n '*MaxRssProcessors' $cores
            Write-Host "      |  +-- IPv6 binding OFF" -f DarkGray
            Disable-NetAdapterBinding -Name $n -ComponentID ms_tcpip6 -EA 0
        }
    }
    "NIC Power Deep" = {
        Write-Host "    [NIC power management full OFF]" -f Cyan
        Get-PhysNIC | ForEach-Object {
            $n = $_.Name
            Write-Host "      +-- [$n]" -f White
            Disable-NetAdapterPowerManagement -Name $n -EA 0 'Disabled'
            NicDisp $n 'Wake on pattern
            NicDisp $n 'Wake on Magic Packet' match' 'Disabled'
            NicDisp $n 'Green Ethernet' 'Disabled'
            NicDisp $n 'Energy Efficient Ethernet' 'Disabled'
            NicProp $n '*AutoPowerSaveModeEnabled' 0
            NicProp $n 'SipsEnabled' 0
        }
        powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0
        powercfg /setactive SCHEME_CURRENT
    }
    "LSO + RSS Queues" = {
        Write-Host "    [LSO OFF, RSS queues]" -f Cyan
        Get-PhysNIC | ForEach-Object {
            $n = $_.Name
            Write-Host "      +-- [$n]" -f White
            Write-Host "      |  +-- LSO OFF (IPv4+IPv6)" -f DarkGray
            Disable-NetAdapterLso -Name $n -IPv4 -IPv6 -EA 0
            $mr = (Get-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*NumRssQueues' -EA 0).RegistryValue
            if ($mr) { NicProp $n '*NumRssQueues' $mr }
            NicProp $n '*ReceiveBuffers' 2048
            NicProp $n '*TransmitBuffers' 2048
        }
    }
    "TCP Window / BDP Tuning" = {
        Write-Host "    [TCP window tuning]" -f Cyan
        $ntp = "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        $afd = "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters"
        reg add "$ntp" /v Tcp1323Opts /t REG_DWORD /d 1 /f
        reg add "$ntp" /v TcpWindowSize /t REG_DWORD /d 262144 /f
        reg add "$ntp" /v MaxFreeTcbs /t REG_DWORD /d 65536 /f
        reg add "$ntp" /v MaxUserPort /t REG_DWORD /d 65534 /f
        reg add "$ntp" /v TcpTimedWaitDelay /t REG_DWORD /d 30 /f
        reg add "$ntp" /v MaxHashTableSize /t REG_DWORD /d 65536 /f
        reg add "$afd" /v DefaultReceiveWindow /t REG_DWORD /d 65536 /f
        reg add "$afd" /v DefaultSendWindow /t REG_DWORD /d 65536 /f
    }
    "TCP Congestion" = {
        Write-Host "    [Cubic congestion]" -f Cyan
        netsh int tcp set supplemental template=Internet congestionprovider=cubic
        netsh int tcp set supplemental template=Internet initialrto=1000
        netsh int tcp set supplemental template=Internet icw=10
        netsh int tcp set supplemental template=Datacenter congestionprovider=cubic
        netsh int tcp set supplemental template=Datacenter initialrto=750
        netsh int tcp set supplemental template=Datacenter icw=10
    }
    "UDP Buffer" = {
        Write-Host "    [UDP buffers]" -f Cyan
        $ntp = "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        $afd = "HKLM\SYSTEM\CurrentControlSet\Services\AFD\Parameters"
        reg add "$afd" /v DatagramSendBufferLength /t REG_DWORD /d 65536 /f
        reg add "$afd" /v DatagramReceiveBufferLength /t REG_DWORD /d 65536 /f
        netsh int udp set global uro=disabled
        reg add "$ntp" /v MaxForwardBufferMemory /t REG_DWORD /d 65536 /f
        reg add "$ntp" /v MaxNumForwardPackets /t REG_DWORD /d 65536 /f
    }
    "QoS + DSCP" = {
        Write-Host "    [QoS/DSCP]" -f Cyan
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DefaultTOSValue /t REG_DWORD /d 184 /f
    }
    "DNS Cache + Flush" = {
        Write-Host "    [DNS cache flush]" -f Cyan
        ipconfig /flushdns 2>$null | Out-Null
        nbtstat -R 2>$null | Out-Null
        nbtstat -RR 2>$null | Out-Null
        arp -d * 2>$null | Out-Null
        Write-Host "    [DNS cache tuning]" -f Cyan
        $dns = "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
        reg add "$dns" /v MaxCacheEntryTtlLimit /t REG_DWORD /d 86400 /f
        reg add "$dns" /v MaxSOACacheEntryTtlLimit /t REG_DWORD /d 120 /f
        reg add "$dns" /v NegativeCacheTime /t REG_DWORD /d 0 /f
        reg add "$dns" /v NetFailureCacheTime /t REG_DWORD /d 0 /f
        reg add "$dns" /v NegativeSOACacheTime /t REG_DWORD /d 0 /f
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" /v EnableMulticast /t REG_DWORD /d 0 /f
        Write-Host "    [NetBIOS OFF]" -f Cyan
        Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\services\NetBT\Parameters\Interfaces' -EA 0 | ForEach-Object {
            Set-ItemProperty -Path $_.PSPath -Name NetbiosOptions -Value 2 -EA 0
        }
    }
    "TCP KeepAlive + SYN Protection" = {
        Write-Host "    [KeepAlive]" -f Cyan
        $ntp = "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        reg add "$ntp" /v KeepAliveTime /t REG_DWORD /d 300000 /f
        reg add "$ntp" /v KeepAliveInterval /t REG_DWORD /d 1000 /f
        reg add "$ntp" /v TcpNumConnections /t REG_DWORD /d 16777214 /f
        Write-Host "    [SYN protection]" -f Cyan
        reg add "$ntp" /v SynAttackProtect /t REG_DWORD /d 1 /f
        reg add "$ntp" /v TcpMaxConnectResponseRetransmissions /t REG_DWORD /d 2 /f
    }
    "WiFi Optimize" = {
        Write-Host "    [WiFi adapter tuning]" -f Cyan
        Get-NetAdapter -Physical -EA 0 | Where-Object {
            $_.MediaType -eq 'Native 802.11' -or $_.InterfaceDescription -match 'Wi-Fi|Wireless|WiFi|WLAN'
        } | ForEach-Object {
            $n = $_.Name
            Write-Host "      +-- [$n]" -f White
            NicProp $n '*RoamingAggressiveness' 4
            NicProp $n '*PMARPOffload' 0
            NicProp $n '*PMNSOffload' 0
            NicProp $n '*PacketCoalescing' 0
            NicProp $n '*PreferredBand' 2
            NicProp $n '*ThroughputBooster' 0
        }
        Write-Host "    [WiFi auto-connect OFF]" -f Cyan
        reg add "HKLM\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config" /v AutoConnectAllowedOEM /t REG_DWORD /d 0 /f
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WcmSvc\GroupPolicy" /v fMinimizeConnections /t REG_DWORD /d 1 /f
    }
}

# ============================================================
# [7] NVIDIA GPU
# ============================================================
$Cat_Nvidia = [ordered]@{
    "NVIDIA Low Latency" = {
        Write-Host "    [PowerMizer + Preemption OFF]" -f Cyan
        Get-NvidiaGPU | ForEach-Object {
            $p = $_.PSPath
            $desc = (Get-ItemProperty $p -Name 'DriverDesc' -EA 0).DriverDesc
            Write-Host "      +-- [$desc]" -f White
            GpuProp $p 'PerfLevelSrc' 0x2222
            GpuProp $p 'PowerMizerEnable' 1
            GpuProp $p 'PowerMizerLevel' 1
            GpuProp $p 'PowerMizerLevelAC' 1
            GpuProp $p 'DisableDynamicPstate' 1
            GpuProp $p 'D3PCLatency' 1
            GpuProp $p 'F1TransitionLatency' 1
            GpuProp $p 'RMEnableVblankSynchronization' 0
            GpuProp $p 'EnableMidBufferPreemption' 0
            GpuProp $p 'EnableMidGfxPreemption' 0
            GpuProp $p 'EnableMidBufferPreemptionForHighTdrTimeout' 0
            GpuProp $p 'EnableCEPreemption' 0
            GpuProp $p 'EnableDeepIdlePreemption' 0
            GpuProp $p 'EnableAsyncMidBufferPreemption' 0
        }
    }
    "NVIDIA Shader + ReBAR" = {
        Write-Host "    [Shader cache + ReBAR]" -f Cyan
        Get-NvidiaGPU | ForEach-Object {
            $p = $_.PSPath
            $desc = (Get-ItemProperty $p -Name 'DriverDesc' -EA 0).DriverDesc
            Write-Host "      +-- [$desc]" -f White
            GpuProp $p 'RMEnableAppSpecificProfile' 1
            GpuProp $p 'ShaderCache' 1
            GpuProp $p 'RMFrmForceMaxFramesToRender' 1
            GpuProp $p 'RMEnableReBar' 1
        }
    }
    "NVIDIA Profile" = {
        Write-Host "    [Low latency profile]" -f Cyan
        Get-NvidiaGPU | ForEach-Object {
            $p = $_.PSPath
            $desc = (Get-ItemProperty $p -Name 'DriverDesc' -EA 0).DriverDesc
            Write-Host "      +-- [$desc]" -f White
            GpuProp $p 'RMEnableAppSpecificProfile' 1
            GpuProp $p 'LowLatencyMode' 2
            GpuProp $p 'RMFrmForceMaxFramesToRender' 1
            GpuProp $p 'TextureQuality' 0
            GpuProp $p 'PerfLevelSrc' 0x2222
            GpuProp $p 'RmEnableExtSs' 1
            GpuProp $p 'RMForceGenSpeed' 0
        }
        Write-Host "    [NVTweak PState lock]" -f Cyan
        $nvG = "HKLM:\SOFTWARE\NVIDIA Corporation\Global\NVTweak"
        if (-not (Test-Path $nvG)) { New-Item -Path $nvG -Force -EA 0 | Out-Null }
        Set-ItemProperty -Path $nvG -Name 'DisablePState' -Value 1 -Type DWord -Force -EA 0
        Set-ItemProperty -Path $nvG -Name 'DisableDynamicPstate' -Value 1 -Type DWord -Force -EA 0
        Write-Host "      +-- DisablePState = 1" -f Yellow
        Write-Host "      +-- DisableDynamicPstate = 1" -f Yellow
    }
}

# ============================================================
# MASTER TABLE
# ============================================================
$AllTweaks = [ordered]@{}
foreach ($cat in @($Cat_Windows, $Cat_Debloat, $Cat_CPU, $Cat_Misc, $Cat_Clean, $Cat_Network, $Cat_Nvidia)) {
    foreach ($key in $cat.Keys) { $AllTweaks[$key] = $cat[$key] }
}

# ============================================================
# RUN FUNCTIONS
# ============================================================
function Run-TweakCategory {
    param([string]$CategoryName, [System.Collections.Specialized.OrderedDictionary]$Tweaks)
    $total = $Tweaks.Count; $step = 0; $errors = @()
    foreach ($key in $Tweaks.Keys) {
        $step++
        Write-Host ""
        Write-Host "  +-- [$step/$total] $key" -f White
        Write-Host "  |" -f DarkGray
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try { & $Tweaks[$key] } catch {
            Write-Host "      [ERR] $($_.Exception.Message)" -f Magenta
            $errors += $key
        }
        $sw.Stop()
        Write-Host "  +-- [OK] $([math]::Round($sw.Elapsed.TotalSeconds,1))s" -f Green
    }
    Write-Host ""
    Write-Host "  =============================================" -f DarkGray
    if ($errors.Count -gt 0) {
        Write-Host "  Category done: $($errors.Count) error(s)" -f Magenta
        foreach ($e in $errors) { Write-Host "    ! $e" -f Magenta }
    } else {
        Write-Host "  Category done: all $total tweaks OK" -f Green
    }
    Write-Host "  =============================================" -f DarkGray
    Write-Host ""
    try { [Console]::Beep(1200, 300) } catch {}
    Show-RestartPopup "Category [$CategoryName] applied successfully!`n`nPlease RESTART your computer for all changes to take full effect."
    Read-Host "  Press Enter to return"
}

function Run-AllTweaks {
    param([System.Collections.Specialized.OrderedDictionary]$AllTweaks)
    $total = $AllTweaks.Count; $step = 0; $errors = @()
    $swTotal = [System.Diagnostics.Stopwatch]::StartNew()
    foreach ($key in $AllTweaks.Keys) {
        $step++
        Write-Host ""
        Write-Host "  +-- [$step/$total] $key" -f White
        Write-Host "  |" -f DarkGray
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try { & $AllTweaks[$key] } catch {
            Write-Host "      [ERR] $($_.Exception.Message)" -f Magenta
            $errors += $key
        }
        $sw.Stop()
        Write-Host "  +-- [OK] $([math]::Round($sw.Elapsed.TotalSeconds,1))s" -f Green
    }
    $swTotal.Stop()
    Write-Host ""
    Write-Host "  =============================================" -f DarkGray
    if ($errors.Count -gt 0) {
        Write-Host "  ALL DONE: $($errors.Count) error(s) " -f Magenta -NoNewline
    } else {
        Write-Host "  ALL DONE: all $total tweaks OK " -f Green -NoNewline
    }
    Write-Host "[$([math]::Round($swTotal.Elapsed.TotalSeconds,1))s total]" -f DarkGray
    Write-Host "  =============================================" -f DarkGray
    if ($errors.Count -gt 0) { foreach ($e in $errors) { Write-Host "    ! $e" -f Magenta } }
    Write-Host ""
    try { [Console]::Beep(1200, 300) } catch {}
    Show-RestartPopup "All $total tweaks applied successfully!`n`nPlease RESTART your computer for all changes to take full effect."
    Read-Host "  Press Enter to return"
}

# ============================================================
# MAIN LOOP
# ============================================================
while ($true) {
    Write-Header
    $W = $Host.UI.RawUI.WindowSize.Width
    $menuItems = @(
        @{ K="1"; L="Windows Settings";  C=$Cat_Windows.Count }
        @{ K="2"; L="Debloat";           C=$Cat_Debloat.Count }
        @{ K="3"; L="CPU Tweaks";        C=$Cat_CPU.Count }
        @{ K="4"; L="Miscellaneous";     C=$Cat_Misc.Count }
        @{ K="5"; L="Clean Temp Files";  C=$Cat_Clean.Count }
        @{ K="6"; L="Network & NIC";     C=$Cat_Network.Count }
        @{ K="7"; L="NVIDIA GPU";        C=$Cat_Nvidia.Count }
    )
    $maxLabelLen = 0
    foreach ($item in $menuItems) { if ($item.L.Length -gt $maxLabelLen) { $maxLabelLen = $item.L.Length } }
    $maxCountLen = 0
    foreach ($item in $menuItems) { $cl = "($($item.C) tweaks)".Length; if ($cl -gt $maxCountLen) { $maxCountLen = $cl } }
    $menuBlockW = 4 + $maxLabelLen + 2 + $maxCountLen
    foreach ($item in $menuItems) {
        $pad = [math]::Max(0, [math]::Floor(($W - $menuBlockW) / 2))
        $labelPad = $maxLabelLen - $item.L.Length + 2
        $countStr = "($($item.C) tweaks)"
        Write-Host (" " * $pad) -NoNewline
        Write-Host "[$($item.K)]" -f Cyan -NoNewline
        Write-Host " " -NoNewline
        Write-Host $item.L -f White -NoNewline
        Write-Host (" " * $labelPad) -NoNewline
        Write-Host $countStr -f DarkGray
    }
    Write-Host ""
    $aPad = [math]::Max(0, [math]::Floor(($W - $menuBlockW) / 2))
    $aLabelPad = $maxLabelLen - "Apply All".Length + 2
    $aCountStr = "($($AllTweaks.Count) tweaks)"
    Write-Host (" " * $aPad) -NoNewline
    Write-Host "[A]" -f Green -NoNewline
    Write-Host " " -NoNewline
    Write-Host "Apply All" -f Yellow -NoNewline
    Write-Host (" " * $aLabelPad) -NoNewline
    Write-Host $aCountStr -f DarkYellow
    $xPad = [math]::Max(0, [math]::Floor(($W - $menuBlockW) / 2))
    $xLabelPad = $maxLabelLen - "Exit".Length + 2
    Write-Host (" " * $xPad) -NoNewline
    Write-Host "[X]" -f Magenta -NoNewline
    Write-Host " " -NoNewline
    Write-Host "Exit" -f Red
    Write-Host ""
    Write-Center "-----------------------------------------------------" DarkGray
    Write-Host ""
    $promptPad = [math]::Max(0, [math]::Floor(($W - 20) / 2))
    Write-Host (" " * $promptPad) -NoNewline
    Write-Host "Choose an option: " -f Cyan -NoNewline
    $choice = (Read-Host).Trim().ToUpper()
    switch ($choice) {
        "1" { Run-TweakCategory -CategoryName "Windows Settings" -Tweaks $Cat_Windows }
        "2" { Run-TweakCategory -CategoryName "Debloat" -Tweaks $Cat_Debloat }
        "3" { Run-TweakCategory -CategoryName "CPU Tweaks" -Tweaks $Cat_CPU }
        "4" { Run-TweakCategory -CategoryName "Miscellaneous" -Tweaks $Cat_Misc }
        "5" { Run-TweakCategory -CategoryName "Clean Temp Files" -Tweaks $Cat_Clean }
        "6" { Run-TweakCategory -CategoryName "Network & NIC" -Tweaks $Cat_Network }
        "7" { Run-TweakCategory -CategoryName "NVIDIA GPU" -Tweaks $Cat_Nvidia }
        "A" { Run-AllTweaks -AllTweaks $AllTweaks }
        "X" { Write-Host ""; Write-Host "  Exiting..." -f Cyan; Start-Sleep -Milliseconds 500; exit }
        default { Write-Host "  Invalid choice." -f Magenta; Start-Sleep -Milliseconds 800 }
    }
}
