#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$Root = Join-Path $env:ProgramData "LockScreenIP"
$BaseImage = Join-Path $Root "base.jpg"
$LogFile = Join-Path $Root "LockScreenIP.log"

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Get-PrimaryIPv4 {
    try {
        $routes = Get-NetRoute -AddressFamily IPv4 -DestinationPrefix "0.0.0.0/0" -ErrorAction Stop |
            Where-Object { $_.NextHop -ne "0.0.0.0" } |
            Sort-Object RouteMetric, InterfaceMetric

        foreach ($route in $routes) {
            $ip = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $route.InterfaceIndex -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.IPAddress -notmatch '^127\.' -and
                    $_.IPAddress -notmatch '^169\.254\.' -and
                    $_.IPAddress -ne "0.0.0.0"
                } |
                Select-Object -First 1

            if ($ip) {
                return $ip.IPAddress
            }
        }
    }
    catch {}

    $fallback = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notmatch '^127\.' -and
            $_.IPAddress -notmatch '^169\.254\.' -and
            $_.IPAddress -ne "0.0.0.0"
        } |
        Select-Object -First 1

    if ($fallback) { return $fallback.IPAddress }
    return "IP YOK"
}

function Set-LockScreenPolicy {
    param([Parameter(Mandatory=$true)][string]$ImagePath)

    # GPO-backed policy. Windows Enterprise/Education'da standart yontem.
    $policyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
    New-Item -Path $policyKey -Force | Out-Null
    New-ItemProperty -Path $policyKey -Name "LockScreenImage" -Value $ImagePath -PropertyType String -Force | Out-Null

    # PersonalizationCSP degerleri de yazilir. Bu, bazi yonetilen Windows kurulumlarinda
    # kilit ekrani guncellemesinin daha tutarli uygulanmasina yardimci olur.
    $cspKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
    New-Item -Path $cspKey -Force | Out-Null
    New-ItemProperty -Path $cspKey -Name "LockScreenImagePath" -Value $ImagePath -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $cspKey -Name "LockScreenImageUrl" -Value $ImagePath -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $cspKey -Name "LockScreenImageStatus" -Value 1 -PropertyType DWord -Force | Out-Null
}

try {
    New-Item -Path $Root -ItemType Directory -Force | Out-Null

    if (-not (Test-Path $BaseImage)) {
        throw "Base image bulunamadi: $BaseImage"
    }

    $ip = Get-PrimaryIPv4
    $hostName = $env:COMPUTERNAME
    $safeIp = ($ip -replace '[^0-9A-Za-z_-]', '_')
    $output = Join-Path $Root ("lockscreen-{0}.jpg" -f $safeIp)

    Add-Type -AssemblyName System.Drawing

    $src = [System.Drawing.Image]::FromFile($BaseImage)
    try {
        $bmp = New-Object System.Drawing.Bitmap($src.Width, $src.Height)
        try {
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            try {
                $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
                $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $g.DrawImage($src, 0, 0, $bmp.Width, $bmp.Height)

                $scale = [Math]::Max(1.0, $bmp.Width / 1920.0)
                $ipSize = [single](42 * $scale)
                $hostSize = [single](22 * $scale)
                $smallSize = [single](15 * $scale)
                $margin = [single](45 * $scale)
                $pad = [single](22 * $scale)

                $fontIp = New-Object System.Drawing.Font("Segoe UI", $ipSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
                $fontHost = New-Object System.Drawing.Font("Segoe UI", $hostSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
                $fontSmall = New-Object System.Drawing.Font("Segoe UI", $smallSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)

                try {
                    $line1 = "IP: $ip"
                    $line2 = "PC: $hostName"
                    $line3 = "Guncelleme: " + (Get-Date -Format "dd.MM.yyyy HH:mm")

                    $s1 = $g.MeasureString($line1, $fontIp)
                    $s2 = $g.MeasureString($line2, $fontHost)
                    $s3 = $g.MeasureString($line3, $fontSmall)

                    $boxW = [Math]::Max($s1.Width, [Math]::Max($s2.Width, $s3.Width)) + ($pad * 2)
                    $boxH = $s1.Height + $s2.Height + $s3.Height + ($pad * 2) + (12 * $scale)

                    # Sol alt: Windows saat/tarih alanindan uzak ve kolay okunur.
                    $x = $margin
                    $y = $bmp.Height - $boxH - $margin

                    $bg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(170, 0, 0, 0))
                    $fg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
                    $fg2 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Gainsboro)

                    try {
                        $g.FillRectangle($bg, $x, $y, $boxW, $boxH)

                        $tx = $x + $pad
                        $ty = $y + $pad
                        $g.DrawString($line1, $fontIp, $fg, $tx, $ty)
                        $ty += $s1.Height + (4 * $scale)
                        $g.DrawString($line2, $fontHost, $fg2, $tx, $ty)
                        $ty += $s2.Height + (4 * $scale)
                        $g.DrawString($line3, $fontSmall, $fg2, $tx, $ty)
                    }
                    finally {
                        $bg.Dispose()
                        $fg.Dispose()
                        $fg2.Dispose()
                    }
                }
                finally {
                    $fontIp.Dispose()
                    $fontHost.Dispose()
                    $fontSmall.Dispose()
                }
            }
            finally {
                $g.Dispose()
            }

            # Once temp dosyaya yaz, sonra atomik olarak hedefe tasi.
            $tmp = Join-Path $Root ("tmp-{0}.jpg" -f ([guid]::NewGuid().ToString("N")))
            $bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Jpeg)

            if (Test-Path $output) { Remove-Item $output -Force }
            Move-Item $tmp $output -Force
        }
        finally {
            $bmp.Dispose()
        }
    }
    finally {
        $src.Dispose()
    }

    Set-LockScreenPolicy -ImagePath $output

    # Eski dinamik resimleri temizle; mevcut IP dosyasi kalsin.
    Get-ChildItem $Root -Filter "lockscreen-*.jpg" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -ne $output } |
        Remove-Item -Force -ErrorAction SilentlyContinue

    Write-Log "OK - IP=$ip Image=$output"
}
catch {
    Write-Log ("ERROR - " + $_.Exception.Message)
    exit 1
}
