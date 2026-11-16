#Requires -Version 5.1
$ErrorActionPreference = "SilentlyContinue"

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "Administrator olarak calistirin." -ForegroundColor Red
    exit 1
}

Unregister-ScheduledTask -TaskName "LockScreenIP-Refresh" -Confirm:$false

$policyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
Remove-ItemProperty -Path $policyKey -Name "LockScreenImage" -ErrorAction SilentlyContinue

$cspKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
Remove-ItemProperty -Path $cspKey -Name "LockScreenImagePath" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $cspKey -Name "LockScreenImageUrl" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $cspKey -Name "LockScreenImageStatus" -ErrorAction SilentlyContinue

Remove-Item (Join-Path $env:ProgramData "LockScreenIP") -Recurse -Force

Write-Host "LockScreenIP kaldirildi." -ForegroundColor Green
