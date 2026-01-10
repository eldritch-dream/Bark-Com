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
$PatchNotesFile = "release_$Version.md"
$PatchNotes | Out-File $PatchNotesFile -Encoding UTF8
Write-Host "   Notes saved to $PatchNotesFile" -ForegroundColor Green

# -------------------------------------------------------------------------
# 2. Test Suite
# -------------------------------------------------------------------------
Write-Host "`n[2/4] Running Test Suite..." -ForegroundColor Yellow

# Find all test runner scenes automatically
$TestScenes = Get-ChildItem -Path "tests" -Filter "*.tscn" -Recurse

if ($TestScenes.Count -eq 0) {
    Write-Host "   [WARN] No tests found in tests/ folder." -ForegroundColor Yellow
}

foreach ($Scene in $TestScenes) {
    # RelPath for display and argument (e.g. tests/test_combat_runner.tscn)
    # Get-ChildItem returns full objects, we need relative path for Godot sometimes, 
    # but absolute path works too. Let's use relative for cleanliness.
    $RelPath = "tests/" + $Scene.Name
    
    Write-Host "   Executing $RelPath..." -NoNewline
    
    # Run the test scene headlessly
    $TestCmd = Start-Process -FilePath $GodotPath -ArgumentList "--headless --path . $RelPath" -Wait -PassThru -NoNewWindow
    
    if ($TestCmd.ExitCode -eq 0) {
        Write-Host " [PASS]" -ForegroundColor Green
    } else {
        Write-Host " [FAIL]" -ForegroundColor Red
        Write-Host "   !!! Pipeline FAILED at $RelPath (Exit Code $($TestCmd.ExitCode)). Aborting Release." -ForegroundColor Red
        exit 1
    }
}
Write-Host "   All Found Tests Passed!" -ForegroundColor Green

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
    Write-Host "`n[DRY RUN] Skipping Upload and Tagging." -ForegroundColor Magenta
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
    
    # -------------------------------------------------------------------------
    # 5. Git Tag
    # -------------------------------------------------------------------------
    Write-Host "`n[5/5] Creating Git Tag v$Version..." -ForegroundColor Yellow
    
    $TagName = "v$Version"
    $TagExists = git tag -l $TagName
    
    if ($TagExists) {
        Write-Host "   [INFO] Tag $TagName already exists. Skipping." -ForegroundColor Gray
    } else {
        git tag -a $TagName -m "Release $TagName"
        Write-Host "   [SUCCESS] Tag $TagName created." -ForegroundColor Green
        
        # Push tag
        git push origin $TagName
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   [SUCCESS] Tag $TagName pushed to remote." -ForegroundColor Green
        } else {
            Write-Host "   [WARN] Failed to push tag. Run 'git push origin $TagName' manually." -ForegroundColor Yellow
        }
    }

    Write-Host "`n>>> Release v$Version Deployed Successfully!" -ForegroundColor Green
}
