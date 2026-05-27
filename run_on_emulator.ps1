# ════════════════════════════════════════════════════════════════════════════
#   EXE AI-Planner - Quick Start Script for Android Emulator (PowerShell)
# ════════════════════════════════════════════════════════════════════════════

Write-Host "`n"
Write-Host "╔═════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  EXE AI-Planner - Google Login with Android Emulator            ║" -ForegroundColor Cyan
Write-Host "╚═════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "`n"

# Check if Flutter is installed
try {
    flutter --version | Out-Null
    Write-Host "✅ Flutter is installed" -ForegroundColor Green
}
catch {
    Write-Host "❌ ERROR: Flutter is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Flutter first: https://flutter.dev/docs/get-started/install" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "`n"

# Change to project directory
$projectPath = "C:\Users\ADMIN\Desktop\GAME CODE\EXE_AI-Planer"
if (-not (Test-Path $projectPath)) {
    Write-Host "❌ ERROR: Could not find project directory" -ForegroundColor Red
    Write-Host "Expected path: $projectPath" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Set-Location $projectPath
Write-Host "✅ Project directory found: $projectPath" -ForegroundColor Green
Write-Host "`n"

# Check for emulator
Write-Host "Checking for connected Android emulator..." -ForegroundColor Yellow
$devices = flutter devices 2>&1
if ($devices -match "emulator.*android") {
    Write-Host "✅ Android emulator detected" -ForegroundColor Green
}
else {
    Write-Host "`n"
    Write-Host "⚠️  WARNING: No Android emulator detected!" -ForegroundColor Yellow
    Write-Host "`n"
    Write-Host "Please:" -ForegroundColor Yellow
    Write-Host "  1. Open Android Studio" -ForegroundColor White
    Write-Host "  2. Go to Tools → Device Manager" -ForegroundColor White
    Write-Host "  3. Start an emulator (API 33+ recommended)" -ForegroundColor White
    Write-Host "  4. Run this script again" -ForegroundColor White
    Write-Host "`n"
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "`n"

# Install dependencies
Write-Host "Installing dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ ERROR: Failed to get dependencies" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "✅ Dependencies installed" -ForegroundColor Green
Write-Host "`n"

# Run the app
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "🚀 Starting app on Android emulator..." -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "`n"

flutter run

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n"
    Write-Host "❌ ERROR: Failed to run the app" -ForegroundColor Red
    Write-Host "Check the error messages above" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Read-Host "Press Enter to exit"
