# Bark-Com Release Pipeline
# Usage: .\release.ps1 -Version "0.4.0" [-DryRun]

param (
    [Parameter(Mandatory=$true)][string]$Version,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ProjectID = "eldritch-dream/bark-com"
$GodotPath = "C:\Users\smili\Documents\Godot\Installs\Godot_v4.5.1-stable_win64.exe"
$SmokeTestScene = "res://tests/SmokeTest.tscn"

Write-Host ">>> Starting Release Pipeline for v$Version..." -ForegroundColor Cyan

# -------------------------------------------------------------------------
# 1. Generate Patch Notes
# -------------------------------------------------------------------------
Write-Host "`n[1/4] Generating Patch Notes..." -ForegroundColor Yellow
# Try to get logs since the last tag. If no tags, getting last 20 commits.
$Tags = git tag
if ($Tags) {
    $LastTag = git describe --tags --abbrev=0
    Write-Host "   Fetching commits from $LastTag to HEAD..." -ForegroundColor Gray
    $GitLog = git log "$LastTag..HEAD" --pretty=format:"- %s"
} else {
    Write-Host "   No tags found, fetching last 20 commits..." -ForegroundColor Gray
    $GitLog = git log -n 20 --pretty=format:"- %s"
}

$PatchNotes = "# Patch Notes v$Version`n`n" + ($GitLog -join "`n")
$PatchNotesFile = "release_notes.md"
$PatchNotes | Out-File $PatchNotesFile -Encoding UTF8
Write-Host "   Notes saved to $PatchNotesFile" -ForegroundColor Green

# -------------------------------------------------------------------------
# 2. Smoke Test
# -------------------------------------------------------------------------
Write-Host "`n[2/4] Running Smoke Test..." -ForegroundColor Yellow
# Run the smoke test script scene headlessly
$SmokeCmd = Start-Process -FilePath $GodotPath -ArgumentList "--headless `"$SmokeTestScene`"" -Wait -PassThru -NoNewWindow

if ($SmokeCmd.ExitCode -eq 0) {
    Write-Host "   [PASS] Smoke Test Passed!" -ForegroundColor Green
} else {
    Write-Host "   [FAIL] Smoke Test FAILED (Exit Code $($SmokeCmd.ExitCode)). Aborting Release." -ForegroundColor Red
    exit 1
}

# -------------------------------------------------------------------------
# 3. Build
# -------------------------------------------------------------------------
Write-Host "`n[3/4] Building Game Artifacts..." -ForegroundColor Yellow
# Call the existing build script
.\build_game.ps1 -Version $Version

# -------------------------------------------------------------------------
# 4. Deploy (Itch.io)
# -------------------------------------------------------------------------
if ($DryRun) {
    Write-Host "`n[DRY RUN] Skipping Upload." -ForegroundColor Magenta
    Write-Host "   Command would be: butler push builds/dist/BarkCom_Web_v$Version.zip ${ProjectID}:web --userversion $Version"
} else {
    Write-Host "`n[4/4] Deploying to Itch.io ($ProjectID)..." -ForegroundColor Yellow
    
    # Web Channel
    $WebZip = "builds\dist\BarkCom_Web_v$Version.zip"
    if (Test-Path $WebZip) {
        Write-Host "   Pushing WEB build..." -ForegroundColor Cyan
        butler push $WebZip "${ProjectID}:web" --userversion $Version
    } else {
        Write-Host "   [ERROR] Web zip not found: $WebZip" -ForegroundColor Red
    }

    # Windows Channel
    $WinZip = "builds\dist\BarkCom_Win_v$Version.zip"
    if (Test-Path $WinZip) {
        Write-Host "   Pushing WINDOWS build..." -ForegroundColor Cyan
        butler push $WinZip "${ProjectID}:windows" --userversion $Version
    } else {
        Write-Host "   [ERROR] Windows zip not found: $WinZip" -ForegroundColor Red
    }
    
    Write-Host "`n>>> Release v$Version Deployed Successfully!" -ForegroundColor Green
}
