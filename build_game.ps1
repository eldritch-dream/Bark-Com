# Build Script for Bark-Com
# Usage: .\build_game.ps1 -Version "1.0.0"

param (
    [string]$Version = "1.0.0"
)

$GodotPath = "C:\Users\smili\Documents\Godot\Installs\Godot_v4.5.1-stable_win64.exe"
# IMPORTANT: If the above fails, replace "godot" with the full path to your Godot executable.
# Example: $GodotPath = "C:\Godot\Godot_v4.2-stable_win64.exe"
$PresetWeb = "Web"
$PresetWin = "Windows Desktop"

$BuildDir = "builds"
$WebDir = "$BuildDir\web\$Version"
$WinDir = "$BuildDir\windows\$Version"
$DistDir = "$BuildDir\dist"

# 1. Prepare Directories
Write-Host "Creating build directories..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $WebDir | Out-Null
New-Item -ItemType Directory -Force -Path $WinDir | Out-Null
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

# 2. Export Web
Write-Host "Exporting Web Build ($PresetWeb)..." -ForegroundColor Yellow
$WebResult = Start-Process -FilePath $GodotPath -ArgumentList "--headless --export-release `"$PresetWeb`" `"$WebDir\index.html`"" -Wait -PassThru -NoNewWindow
if ($WebResult.ExitCode -ne 0) {
    Write-Host "Error exporting Web build. Check if preset '$PresetWeb' exists." -ForegroundColor Red
} else {
    Write-Host "Web Build Success!" -ForegroundColor Green
    
    # Zip for Itch.io (index.html must be at root)
    $ZipPath = "$DistDir\BarkCom_Web_v$Version.zip"
    Write-Host "Zipping Web build to $ZipPath..." -ForegroundColor Cyan
    if (Test-Path $ZipPath) { Remove-Item $ZipPath }
    Compress-Archive -Path "$WebDir\*" -DestinationPath $ZipPath
}

# 3. Export Windows
Write-Host "Exporting Windows Build ($PresetWin)..." -ForegroundColor Yellow
$WinResult = Start-Process -FilePath $GodotPath -ArgumentList "--headless --export-release `"$PresetWin`" `"$WinDir\Bark.exe`"" -Wait -PassThru -NoNewWindow
if ($WinResult.ExitCode -ne 0) {
    Write-Host "Error exporting Windows build. Check if preset '$PresetWin' exists." -ForegroundColor Red
} else {
    Write-Host "Windows Build Success!" -ForegroundColor Green

    # Zip for Distribution
    $ZipPath = "$DistDir\BarkCom_Win_v$Version.zip"
    Write-Host "Zipping Windows build to $ZipPath..." -ForegroundColor Cyan
    if (Test-Path $ZipPath) { Remove-Item $ZipPath }
    Compress-Archive -Path "$WinDir\*" -DestinationPath $ZipPath
}

Write-Host "Build process finished. Artifacts in '$DistDir'." -ForegroundColor Cyan
