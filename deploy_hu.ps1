<#PSScriptInfo
.VERSION 26.02.16
.AUTHOR Custom OSDCloud Setup (Zero Touch Force)
.DESCRIPTION
    Zero Touch indító script: Windows 11 23H2 | hu-HU | Enterprise
#>
[CmdletBinding()]
param()
$startTime = Get-Date
$scriptName = 'deploy.osdcloud.live'

# 1. NAPLÓZÁS
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-$scriptName.log"
$null = Start-Transcript -Path (Join-Path "$env:SystemRoot\Temp" $Transcript) -ErrorAction Ignore

# Fázis
if ($env:SystemDrive -eq 'X:') { $deploymentPhase = 'WinPE' } else { $deploymentPhase = 'Windows' }

# TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

Write-Host -ForegroundColor Cyan ">>> OSDCloud Custom Deploy: $deploymentPhase <<<"

# =============================================================================
# WINPE FÁZIS
# =============================================================================
if ($deploymentPhase -eq 'WinPE') {

    # -------------------------------------------------------------------------
    # 1. KÖRNYEZET ELŐKÉSZÍTÉSE (Közvetlenül itt, nem kell letölteni)
    # -------------------------------------------------------------------------
    
    # Execution Policy Bypass
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
    
    # Time Service
    try { Start-Service -Name w32time -ErrorAction SilentlyContinue } catch {}
    
    # NuGet
    if (-not (Get-PackageProvider -ListAvailable -Name NuGet)) {
        Install-PackageProvider -Name NuGet -Force -Scope AllUsers -ErrorAction SilentlyContinue | Out-Null
    }

    # -------------------------------------------------------------------------
    # 2. OSDCloud MODUL TELEPÍTÉSE
    # -------------------------------------------------------------------------
    Write-Host -ForegroundColor Yellow "OSDCloud modul telepítése..."
    if (-not (Get-Module -ListAvailable -Name OSDCloud)) {
        Install-Module -Name OSDCloud -Scope AllUsers -Force -SkipPublisherCheck -AllowClobber -ErrorAction Stop
    }
    Import-Module -Name OSDCloud -Force

    # -------------------------------------------------------------------------
    # 3. ZERO TOUCH KONFIGURÁCIÓ (MINDEN VARIÁCIÓ)
    # Beállítjuk az összes lehetséges változót, hogy biztosan elkapja valamelyiket.
    # -------------------------------------------------------------------------
    Write-Host -ForegroundColor Cyan "[→] Konfiguráció injektálása..."

    $OSDConfig = [ordered]@{
        OSName       = 'Windows 11 25H2 x64'
        OSVersion    = 'Windows 11'
        OSBuild      = '25H2'
        OSLanguage   = 'hu-hu'
        OSEdition    = 'Enterprise'
        OSLicense    = 'Volume'
        OSActivation = 'Volume'
        ZTI          = $true
        Firmware     = $true
        Restart      = $true
    }

    # Variáció 1: A legújabb (amit a kódod mutatott)
    $Global:StartOSDCloudGUI = $OSDConfig

    # Variáció 2: A régebbi szabvány
    $Global:OSDCloud = $OSDConfig
    
    # Variáció 3: GUI specifikus régebbi
    $Global:OSDCloudGUI = $OSDConfig

    # Debug: Kiírjuk, hogy lássuk, létezik-e
    Write-Host -ForegroundColor Green "[✓] Változók beállítva. Indítás..."

    # -------------------------------------------------------------------------
    # 4. INDÍTÁS
    # -------------------------------------------------------------------------
    # Ha a ZTI változó be van állítva a globális térben, a Deploy-OSDCloud-nak
    # kötelessége átugrani a menüket.
    
    Deploy-OSDCloud
}

# =============================================================================
# EGYÉB FÁZISOK
# =============================================================================
if ($deploymentPhase -eq 'OOBE') {
    Invoke-Expression -Command (Invoke-RestMethod -Uri https://raw.githubusercontent.com/OSDeploy/osdcloud.live/main/modules/oobe/functions.psm1)
}
if ($deploymentPhase -eq 'Windows') {
    Invoke-Expression -Command (Invoke-RestMethod -Uri https://raw.githubusercontent.com/OSDeploy/osdcloud.live/main/windows/functions.ps1)
}

Stop-Transcript -ErrorAction Ignore