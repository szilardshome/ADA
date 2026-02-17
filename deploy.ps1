[CmdletBinding()]
param()
$startTime = Get-Date
$scriptName = 'deploy.szilardshome.com'
$scriptVersion = '26.02.06'
$eventName = 'ADA OS Deployment'
Write-Host ""
#=================================================
#region Initialize
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-$scriptName.log"
$null = Start-Transcript -Path (Join-Path "$env:SystemRoot\Temp" $Transcript) -ErrorAction Ignore
if ($env:SystemDrive -eq 'X:') {
    $deploymentPhase = 'WinPE'
}
else {
    $ImageState = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State' -ErrorAction Ignore).ImageState
    if ($env:UserName -eq 'defaultuser0') {$deploymentPhase = 'OOBE'}
    elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_OOBE') {$deploymentPhase = 'Specialize'}
    elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_AUDIT') {$deploymentPhase = 'AuditMode'}
    else {$deploymentPhase = 'Windows'}
}
$whoiam = [system.security.principal.windowsidentity]::getcurrent().name
$isElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Write-Host -ForegroundColor DarkGray "OSDCloud ADA Deployment [$deploymentPhase]"
#endregion
#region WinPE
if ($deploymentPhase -eq 'WinPE') {
    Invoke-Expression -Command (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/OSDeploy/osdcloud.live/main/modules/winpe/functions.psm1')
    # winpe-RepairTls
    $Dism = Test-WinpePowerShellModuleDism
    if ($Dism -ne $true) {
        Write-Host -ForegroundColor Red "[!] OSDCloud deployment cannot continue without the DISM PowerShell module."
    }
    $Storage = Test-WinpePowerShellModuleStorage
    if ($Storage -ne $true) {
        Write-Host -ForegroundColor Red "[!] OSDCloud deployment cannot continue without the Storage PowerShell module."
    }
    if ($Dism -ne $true -or $Storage -ne $true) {
        $EndTime = Get-Date
        $TotalSeconds = [math]::Round(($EndTime - $StartTime).TotalSeconds, 2)
        Write-Host -ForegroundColor DarkGray "[i] Finished in $TotalSeconds seconds"
        $null = Stop-Transcript -ErrorAction Ignore
        Break
    }
    Repair-WinpeExecutionPolicyBypass -Interactive
    Repair-WinpeUserShellFolders -Interactive
    Repair-WinpeRegistryEnvironment -Interactive
    Repair-WinpeSessionEnvironment -Interactive
    Repair-WinpePowerShellProfilePaths -Interactive
    Repair-WinpePowerShellProfile -Interactive
    Repair-WinpeRealTimeClockUTC -Interactive
    Repair-WinpeTimeService -Interactive
    Repair-WinpeFileCurlExe -Interactive
    Repair-WinpePackageManagement -Interactive
    Repair-WinpeNugetPackageProvider -Interactive
    Repair-WinpeFileNugetExe -Interactive
    Update-WinpePackageManagementVersion -Interactive
    Update-WinpePowerShellGetVersion -Interactive
    Repair-WinpePSGalleryTrust -Interactive
    Repair-WinpeFileAzcopyExe -Interactive
    winpe-InstallPowerShellModule -Name OSDCloud
    $EndTime = Get-Date
    $TotalSeconds = [math]::Round(($EndTime - $StartTime).TotalSeconds, 2)
    Write-Host -ForegroundColor DarkGray "[i] Finished in $TotalSeconds seconds"
    $null = Stop-Transcript -ErrorAction Ignore
    Deploy-OSDCloud
}
#endregion

#region Specialize
if ($deploymentPhase -eq 'Specialize') {
    Invoke-Expression -Command (Invoke-RestMethod -Uri https://raw.githubusercontent.com/OSDeploy/osdcloud.live/main/specialize/functions.ps1)
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion

#region AuditMode
if ($deploymentPhase -eq 'AuditMode') {
    Invoke-Expression -Command (Invoke-RestMethod -Uri https://raw.githubusercontent.com/OSDeploy/osdcloud.live/main/auditmode/functions.ps1)
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion

#region OOBE
if ($deploymentPhase -eq 'OOBE') {
    if ($isElevated) {
        Write-Host -ForegroundColor Green "[✓] Running as $whoiam (Admin Elevated)"
    }
    else {
        Write-Host -ForegroundColor Red "[!] Running as $whoiam (NOT Admin Elevated)"
    }
    Invoke-Expression -Command (Invoke-RestMethod -Uri https://raw.githubusercontent.com/OSDeploy/osdcloud.live/main/modules/oobe/functions.psm1)
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion

#region Windows
if ($deploymentPhase -eq 'Windows') {
    if ($isElevated) {
        Write-Host -ForegroundColor Green "[✓] Running as $whoiam (Admin Elevated)"
    }
    else {
        Write-Host -ForegroundColor Red "[!] Running as $whoiam (NOT Admin Elevated)"
        Break
    }
    Invoke-Expression -Command (Invoke-RestMethod -Uri https://raw.githubusercontent.com/OSDeploy/osdcloud.live/main/windows/functions.ps1)
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion

$EndTime = Get-Date
$TotalSeconds = [math]::Round(($EndTime - $StartTime).TotalSeconds, 2)