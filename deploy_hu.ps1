<#PSScriptInfo
.VERSION 26.02.16
.AUTHOR Custom OSDCloud Setup (Merged Version)
.DESCRIPTION
    Zero Touch indító script: Windows 11 23H2 | hu-HU | Enterprise
    Tartalmazza az összes szükséges függvényt egyben.
#>
[CmdletBinding()]
param()
$startTime = Get-Date
$scriptName = 'deploy.osdcloud.live'

#=================================================
# 1. NAPLÓZÁS ÉS INIT
#=================================================
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-$scriptName.log"
$null = Start-Transcript -Path (Join-Path "$env:SystemRoot\Temp" $Transcript) -ErrorAction Ignore

# Fázis detektálása
if ($env:SystemDrive -eq 'X:') { $deploymentPhase = 'WinPE' } else { $deploymentPhase = 'Windows' }

# !!! FONTOS: TLS 1.2 KÉNYSZERÍTÉSE AZONNAL !!!
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

Write-Host -ForegroundColor Cyan ">>> OSDCloud Custom Deploy: $deploymentPhase <<<"

#=================================================
# 2. BEÉPÍTETT FÜGGVÉNYEK (Nem kell letölteni őket)
#=================================================

# --- Konfigurációs Függvény (EZT KERESTÜK) ---
function Set-OSDCloudZeroTouchConfig {
    Write-Host -ForegroundColor Cyan "[→] OSDCloud ZERO TOUCH konfiguráció betöltése (HU-HU)..."
    $Global:StartOSDCloudGUI = [ordered]@{
        OSName       = 'Windows 11 23H2 x64' 
        OSLanguage   = 'hu-hu'
        OSEdition    = 'Enterprise'
        OSLicense    = 'Volume'
        OSActivation = 'Volume'
        ZTI          = $true
        Firmware     = $true
        Restart      = $true
    }
    Write-Host -ForegroundColor Green "[✓] Konfiguráció: Win 11 23H2 | HU | Enterprise | Auto"
}

# --- Segédfüggvények (Eredetileg a functions.psm1-ben voltak) ---
function Test-WinpePowerShellModuleDism {
    [CmdletBinding()] param ([switch]$Interactive)
    if (Get-Module -ListAvailable -Name "Dism") { return $true }
    if ($Interactive) { Write-Host -ForegroundColor Red "[✗] Dism Module missing" }
    return $false
}
function Test-WinpePowerShellModuleStorage {
    [CmdletBinding()] param ([switch]$Interactive)
    if (Get-Module -ListAvailable -Name "Storage") { return $true }
    if ($Interactive) { Write-Host -ForegroundColor Red "[✗] Storage Module missing" }
    return $false
}
function Repair-WinpeExecutionPolicyBypass {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
    Write-Host -ForegroundColor Green "[✓] ExecutionPolicy: Bypass"
}
function Repair-WinpeTimeService {
    try {
        Set-Service -Name w32time -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name w32time -ErrorAction SilentlyContinue
        Write-Host -ForegroundColor Green "[✓] Time Service: Started"
    } catch {}
}
function Repair-WinpePackageManagement {
    if (-not (Get-Module -Name PackageManagement -ListAvailable)) {
        Write-Host -ForegroundColor Yellow "[!] PackageManagement hiányzik, de folytatjuk..."
    }
}
function Repair-WinpeNugetPackageProvider {
    try {
        Install-PackageProvider -Name NuGet -Force -Scope AllUsers -ErrorAction SilentlyContinue | Out-Null
        Write-Host -ForegroundColor Green "[✓] NuGet Provider: OK"
    } catch {}
}
function winpe-InstallPowerShellModule {
    [CmdletBinding()]
    param ([string]$Name)
    try {
        if (Get-Module -ListAvailable -Name $Name) {
            Write-Host -ForegroundColor Green "[✓] $Name már telepítve van."
            Import-Module $Name -Force; return
        }
        Write-Host -ForegroundColor DarkGray "[→] $Name telepítése PSGallery-ből..."
        Install-Module -Name $Name -Scope AllUsers -Force -SkipPublisherCheck -AllowClobber -ErrorAction Stop
        Import-Module -Name $Name -Force
        Write-Host -ForegroundColor Green "[✓] $Name telepítése sikeres."
    }
    catch {
        Write-Host -ForegroundColor Red "[✗] Hiba a $Name telepítésekor: $_"
        throw
    }
}

#=================================================
# 3. WINPE FÁZIS - VÉGREHAJTÁS
#=================================================
if ($deploymentPhase -eq 'WinPE') {
    
    # Környezet ellenőrzése
    $Dism = Test-WinpePowerShellModuleDism
    $Storage = Test-WinpePowerShellModuleStorage
    if ($Dism -ne $true -or $Storage -ne $true) { 
        Write-Host -ForegroundColor Red "[HIBA] Hiányzó WinPE modulok."
        Break 
    }

    # Javítások futtatása (Most már helyben vannak a függvények)
    Repair-WinpeExecutionPolicyBypass
    Repair-WinpeTimeService
    Repair-WinpePackageManagement
    Repair-WinpeNugetPackageProvider
    
    # OSDCloud Modul telepítése
    winpe-InstallPowerShellModule -Name OSDCloud
    
    # -----------------------------------------------------------------------
    # KONFIGURÁCIÓ INJEKTÁLÁSA
    # -----------------------------------------------------------------------
    Set-OSDCloudZeroTouchConfig
    
    # -----------------------------------------------------------------------
    # INDÍTÁS
    # -----------------------------------------------------------------------
    Write-Host -ForegroundColor Green ">>> Deploy-OSDCloud indítása (Automata mód)..."
    Deploy-OSDCloud
}

#=================================================
# 4. EGYÉB FÁZISOK
#=================================================
if ($deploymentPhase -eq 'OOBE') {
    Invoke-Expression -Command (Invoke-RestMethod -Uri https://raw.githubusercontent.com/OSDeploy/osdcloud.live/main/modules/oobe/functions.psm1)
}
if ($deploymentPhase -eq 'Windows') {
    Invoke-Expression -Command (Invoke-RestMethod -Uri https://raw.githubusercontent.com/OSDeploy/osdcloud.live/main/windows/functions.ps1)
}

Stop-Transcript -ErrorAction Ignore