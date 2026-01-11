# Run Tests Locally (Timeout Protected)
# Usage: .\tests\run_tests.ps1

$GodotPath = "C:\Users\smili\Documents\Godot\Installs\Godot_v4.5.1-stable_win64.exe"
$TimeoutSeconds = 60
$LogFile = "test_log.txt"

Start-Transcript -Path $LogFile -Force

Write-Host "Searching for Tests..." -ForegroundColor Cyan

$TestScenes = Get-ChildItem -Path "tests" -Filter "*.tscn" -Recurse
$TestScripts = Get-ChildItem -Path "tests" -Filter "*.gd" -Recurse

$GlobalExitCode = 0

function Run-GodotTest {
    param($Name, $Arguments)
    
    Write-Host "Running: $Name" -ForegroundColor Yellow
    
    try {
        $Process = Start-Process -FilePath $GodotPath -ArgumentList $Arguments -PassThru -NoNewWindow
        
        $Process | Wait-Process -Timeout $TimeoutSeconds
        
        if ($Process.ExitCode -ne 0) {
            Write-Host "FAILURE in $Name (Exit Code: $($Process.ExitCode))" -ForegroundColor Red
            return 1
        }
    }
    catch {
        Write-Host "ERROR/TIMEOUT in $Name : $($_.Exception.Message)" -ForegroundColor Red
        if ($null -ne $Process) {
            $Process | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        return 1
    }
    return 0
}

# 1. Run Scenes
foreach ($scene in $TestScenes) {
    $result = Run-GodotTest -Name $scene.Name -Arguments "--headless --path . `"$($scene.FullName)`""
    if ($result -ne 0) { $GlobalExitCode = 1 }
}

# 2. Run Scripts
foreach ($script in $TestScripts) {
    # Check if script is a test runner (extends SceneTree/MainLoop)
    $Content = Get-Content $script.FullName -Raw
    if ($Content -match "extends\s+(SceneTree|MainLoop)") {
        $result = Run-GodotTest -Name $script.Name -Arguments "--headless -s `"$($script.FullName)`""
        if ($result -ne 0) { $GlobalExitCode = 1 }
    }
}

if ($GlobalExitCode -eq 0) {
    Write-Host "ALL TESTS PASSED" -ForegroundColor Green
} else {
    Write-Host "TESTS FAILED" -ForegroundColor Red
}

Stop-Transcript
exit $GlobalExitCode
