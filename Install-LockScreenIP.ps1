#Requires -Version 5.1
param(
    [string]$BaseImage = ""
)

$ErrorActionPreference = "Stop"

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "Bu kurulum Administrator olarak calistirilmalidir." -ForegroundColor Red
    exit 1
}

$SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Join-Path $env:ProgramData "LockScreenIP"
$UpdaterSource = Join-Path $SourceDir "Update-LockScreenIP.ps1"
$UpdaterDest = Join-Path $Root "Update-LockScreenIP.ps1"
$BaseDest = Join-Path $Root "base.jpg"

New-Item -Path $Root -ItemType Directory -Force | Out-Null

if (-not (Test-Path $UpdaterSource)) {
    throw "Update-LockScreenIP.ps1 ayni klasorde bulunamadi."
}

Copy-Item $UpdaterSource $UpdaterDest -Force

# Kullanici ozel bir resim vermediyse Windows'un varsayilan resimlerinden birini sec.
if ([string]::IsNullOrWhiteSpace($BaseImage)) {
    $candidates = @(
        "$env:WINDIR\Web\Screen\img100.jpg",
        "$env:WINDIR\Web\Screen\img103.jpg",
        "$env:WINDIR\Web\Wallpaper\Windows\img0.jpg"
    )
    $BaseImage = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}

if (-not $BaseImage -or -not (Test-Path $BaseImage)) {
    throw "Kullanilacak JPG bulunamadi. Ornek: .\Install-LockScreenIP.ps1 -BaseImage C:\Temp\wallpaper.jpg"
}

Copy-Item $BaseImage $BaseDest -Force

# Ilk resmi hemen olustur.
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $UpdaterDest

# SYSTEM altinda calisan gorev: PC kilitliyken de calisir.
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument ('-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $UpdaterDest)

$startup = New-ScheduledTaskTrigger -AtStartup

$repeat = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes 2) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName "LockScreenIP-Refresh" `
    -Action $action `
    -Trigger @($startup, $repeat) `
    -Settings $settings `
    -User "SYSTEM" `
    -RunLevel Highest `
    -Force | Out-Null

$edition = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").EditionID

Write-Host ""
Write-Host "LockScreenIP kuruldu." -ForegroundColor Green
Write-Host "Windows Edition : $edition"
Write-Host "Base image      : $BaseDest"
Write-Host "Updater         : $UpdaterDest"
Write-Host "Task            : LockScreenIP-Refresh"
Write-Host ""
Write-Host "Test icin Win+L yapabilirsiniz."
Write-Host "IP her 2 dakikada bir yeniden kontrol edilir."
