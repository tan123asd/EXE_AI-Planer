@echo off
REM =================================================================
REM  EXE AI-Planner - Quick Start Script for Android Emulator
REM =================================================================

echo.
echo ╔═══════════════════════════════════════════════════════════════╗
echo ║   EXE AI-Planner - Google Login with Android Emulator         ║
echo ╚═══════════════════════════════════════════════════════════════╝
echo.

REM Check if Flutter is installed
flutter --version >nul 2>&1
if errorlevel 1 (
    echo ❌ ERROR: Flutter is not installed or not in PATH
    echo Please install Flutter first: https://flutter.dev/docs/get-started/install
    pause
    exit /b 1
)

echo ✅ Flutter is installed
echo.

REM Change to project directory
cd /d "C:\Users\ADMIN\Desktop\GAME CODE\EXE_AI-Planer"
if errorlevel 1 (
    echo ❌ ERROR: Could not find project directory
    pause
    exit /b 1
)

echo ✅ Project directory found
echo.

REM Check for devices
echo Checking for connected devices...
flutter devices >temp_devices.txt 2>&1
findstr /r "emulator.*android" temp_devices.txt >nul 2>&1

if errorlevel 1 (
    echo.
    echo ⚠️  WARNING: No Android emulator detected!
    echo.
    echo Please:
    echo 1. Open Android Studio
    echo 2. Go to Tools ^→ Device Manager
    echo 3. Start an emulator (API 33+ recommended)
    echo 4. Run this script again
    echo.
    pause
    del temp_devices.txt
    exit /b 1
)

del temp_devices.txt
echo ✅ Android emulator detected
echo.

REM Get dependencies
echo Installing dependencies...
call flutter pub get
if errorlevel 1 (
    echo ❌ ERROR: Failed to get dependencies
    pause
    exit /b 1
)

echo ✅ Dependencies installed
echo.

REM Run the app
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo 🚀 Starting app on Android emulator...
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo.

flutter run

if errorlevel 1 (
    echo.
    echo ❌ ERROR: Failed to run the app
    echo Check the error messages above
    pause
    exit /b 1
)

pause
