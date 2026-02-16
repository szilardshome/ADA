<#PSScriptInfo
.VERSION 26.02.16
.AUTHOR Custom OSDCloud Setup
.DESCRIPTION
    Zero Touch indító script: Windows 11 23H2 | hu-HU | Enterprise
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

# Biztonsági protokoll
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

Write-Host -ForegroundColor Cyan ">>> OSDCloud Custom Deploy: $deploymentPhase <<<"

#=================================================
# 2. WINPE FÁZIS (TELEPÍTÉS)
#=================================================
if ($deploymentPhase -eq 'WinPE') {
    
    # -----------------------------------------------------------------------
    # A. SAJÁT SEGÉD SCRIPT BETÖLTÉSE
    # !!! FONTOS: IDE ÍRD BE A SAJÁT GITHUB LINKEDET !!!
    # -----------------------------------------------------------------------
    $FunctionsUrl = 'https://raw.githubusercontent.com/szilardshome/ADA/refs/heads/main/functions.psm1'
    
    Write-Host -ForegroundColor Yellow "Segédfüggvények betöltése innen: $FunctionsUrl"
    try {
        Invoke-Expression -Command (Invoke-RestMethod -Uri $FunctionsUrl -ErrorAction Stop)
    }
    catch {
        Write-Host -ForegroundColor Red "[HIBA] Nem sikerült letölteni a functions.psm1-et! Ellenőrizd a linket."
        Break
    }

    # -----------------------------------------------------------------------
    # B. KÖRNYEZET ELŐKÉSZÍTÉSE (Standard OSDCloud lépések)
    # -----------------------------------------------------------------------
    $Dism = Test-WinpePowerShellModuleDism
    $Storage = Test-WinpePowerShellModuleStorage
    if ($Dism -ne $true -or $Storage -ne $true) { 
        Write-Host -ForegroundColor Red "[HIBA] Hiányzó WinPE modulok."
        Break 
    }

    Repair-WinpeExecutionPolicyBypass -Interactive
    Repair-WinpeTimeService -Interactive
    Repair-WinpePackageManagement -Interactive
    Repair-WinpeNugetPackageProvider -Interactive
    
    # OSDCloud Modul telepítése
    winpe-InstallPowerShellModule -Name OSDCloud
    
    # -----------------------------------------------------------------------
    # C. "ZERO TOUCH" KONFIGURÁCIÓ INJEKTÁLÁSA
    # Ez a függvény a functions.psm1-ben van definiálva!
    # Ez tölti fel a változókat, hogy a Deploy-OSDCloud ne kérdezzen semmit.
    # -----------------------------------------------------------------------
    Set-OSDCloudZeroTouchConfig
    
    # -----------------------------------------------------------------------
    # D. INDÍTÁS
    # Most meghívjuk az eredeti Deploy-OSDCloud parancsot paraméterek nélkül.
    # -----------------------------------------------------------------------
    Write-Host -ForegroundColor Green ">>> Deploy-OSDCloud indítása (Automata mód)..."
    Deploy-OSDCloud
}

#=================================================
# 3. EGYÉB FÁZISOK (OOBE / Windows)
#=================================================
if ($deploymentPhase -eq 'OOBE') {
    Invoke-Expression -Command (Invoke-RestMethod -Uri https://raw.githubusercontent.com/OSDeploy/osdcloud.live/main/modules/oobe/functions.psm1)
}
if ($deploymentPhase -eq 'Windows') {
    Invoke-Expression -Command (Invoke-RestMethod -Uri https://raw.githubusercontent.com/OSDeploy/osdcloud.live/main/windows/functions.ps1)
}

Stop-Transcript -ErrorAction Ignore