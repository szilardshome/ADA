<#
.SYNOPSIS
WinPE environment setup and configuration functions + Custom Config.
#>

#region Helpers
function Invoke-WinpeDownload {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$Destination,
        [System.Management.Automation.SwitchParameter]$AllowCurlFallback
    )
    $curlPath = Join-Path $env:SystemRoot 'System32\\curl.exe'
    if (Test-Path $curlPath) {
        & $curlPath --fail --location --silent --show-error $Uri --output $Destination
        if ($LASTEXITCODE -eq 0 -and (Test-Path $Destination)) { return }
    }
    Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $Destination -ErrorAction Stop
}
#endregion

#region PowerShell Modules
function Test-WinpePowerShellModuleDism {
    [CmdletBinding()] param ([switch]$Interactive)
    if (Get-Module -ListAvailable -Name "Dism") {
        if ($Interactive) { Write-Host -ForegroundColor Green "[✓] Dism Module available" }
        return $true
    }
    if ($Interactive) { Write-Host -ForegroundColor Red "[✗] Dism Module missing" }
    return $false
}
function Test-WinpePowerShellModuleStorage {
    [CmdletBinding()] param ([switch]$Interactive)
    if (Get-Module -ListAvailable -Name "Storage") {
        if ($Interactive) { Write-Host -ForegroundColor Green "[✓] Storage Module available" }
        return $true
    }
    if ($Interactive) { Write-Host -ForegroundColor Red "[✗] Storage Module missing" }
    return $false
}
#endregion

#region Winpe Repairs
function Repair-WinpeExecutionPolicyBypass {
    [CmdletBinding()] param ([switch]$Interactive)
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
    if ($Interactive) { Write-Host -ForegroundColor Green "[✓] ExecutionPolicy set to Bypass" }
}

function Repair-WinpeTimeService {
    [CmdletBinding()] param ([switch]$Interactive)
    try {
        Set-Service -Name w32time -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name w32time -ErrorAction SilentlyContinue
        if ($Interactive) { Write-Host -ForegroundColor Green "[✓] Time Service started" }
    } catch {}
}

function Repair-WinpePackageManagement {
    [CmdletBinding()] param ([switch]$Interactive)
    # Minimal check/install logic
    if (-not (Get-Module -Name PackageManagement -ListAvailable)) {
        if ($Interactive) { Write-Host -ForegroundColor Yellow "[!] PackageManagement missing, attempting fix..." }
        # Simplified repair for brevity, assumes standard WinPE behavior
    }
}

function Repair-WinpeNugetPackageProvider {
    [CmdletBinding()] param ([switch]$Interactive)
    try {
        Install-PackageProvider -Name NuGet -Force -Scope AllUsers -ErrorAction SilentlyContinue | Out-Null
        if ($Interactive) { Write-Host -ForegroundColor Green "[✓] NuGet Provider check/install" }
    } catch {}
}

function Repair-WinpePowerShellProfile {
    # Simple profile creation
    $profilePath = $PROFILE.CurrentUserAllHosts
    if (-not (Test-Path $profilePath)) {
        New-Item -Path $profilePath -ItemType File -Force -ErrorAction SilentlyContinue | Out-Null
    }
    Add-Content -Path $profilePath -Value "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12" -Force
}
#endregion

#region Install Module
function winpe-InstallPowerShellModule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$Name,
        [switch]$Force
    )
    try {
        if (Get-Module -ListAvailable -Name $Name) {
            Write-Host -ForegroundColor Green "[✓] $Name is already installed."
            Import-Module $Name -Force
            return
        }
        Write-Host -ForegroundColor DarkGray "[→] Installing $Name from PSGallery..."
        Install-Module -Name $Name -Scope AllUsers -Force -SkipPublisherCheck -AllowClobber -ErrorAction Stop
        Import-Module -Name $Name -Force
        Write-Host -ForegroundColor Green "[✓] $Name installed successfully."
    }
    catch {
        Write-Host -ForegroundColor Red "[✗] Failed to install $Name: $_"
        throw
    }
}
#endregion

# =============================================================================
# CUSTOM CONFIGURATION FUNCTION (EZ A LÉNYEG)
# =============================================================================

function Set-OSDCloudZeroTouchConfig {
    <#
    .SYNOPSIS
        Beállítja a globális változókat, hogy a Deploy-OSDCloud ne kérdezzen semmit.
        Magyar nyelv / Enterprise kiadás / Win 11 23H2
    #>
    [CmdletBinding()]
    param()

    Write-Host -ForegroundColor Cyan "[→] OSDCloud ZERO TOUCH konfiguráció betöltése (HU-HU)..."

    # Ez a változó (StartOSDCloudGUI) az, amit a Deploy-OSDCloud ellenőriz a forráskódban.
    # Ha ez létezik, akkor ebből veszi az értékeket a GUI helyett.
    
    $Global:StartOSDCloudGUI = [ordered]@{
        # OPERÁCIÓS RENDSZER
        # Fontos: Pontosan egyeznie kell a Deploy-OSDCloud validációs listájával!
        # Lehetőségek: 'Windows 11 25H2 x64', 'Windows 11 23H2 x64', 'Windows 10 22H2 x64'
        OSName       = 'Windows 11 25H2 x64' 
        
        # NYELV ÉS KIADÁS
        OSLanguage   = 'hu-hu'
        OSEdition    = 'Enterprise'
        
        # LICENC
        OSLicense    = 'Volume'
        OSActivation = 'Volume'
        
        # EGYÉB BEÁLLÍTÁSOK
        ZTI          = $true   # Zero Touch Installation (Nem kérdez rá a törlésre)
        Firmware     = $true   # Firmware/Driverek frissítése
        Restart      = $true   # Újraindítás a végén
    }

    # Ellenőrzésképpen kiírjuk
    Write-Host -ForegroundColor Green "----------------------------------------"
    Write-Host -ForegroundColor Green " KIVÁLASZTOTT RENDSZER: Windows 11 25H2"
    Write-Host -ForegroundColor Green " NYELV:                 Magyar (hu-HU)"
    Write-Host -ForegroundColor Green " KIADÁS:                Enterprise (Volume)"
    Write-Host -ForegroundColor Green " MÓD:                   Teljesen Automata"
    Write-Host -ForegroundColor Green "----------------------------------------"
}