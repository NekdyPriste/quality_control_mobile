@echo off
echo =================================
echo ATQ Quality Control - APK Build
echo =================================
echo.

echo Navigating to project directory...
cd /d "C:\Users\Roman Pribyl\Documents\Claude\quality_control_mobile"

echo.
echo Getting Flutter dependencies...
"C:\flutter\flutter\bin\flutter.bat" pub get

echo.
echo Building APK for release...
"C:\flutter\flutter\bin\flutter.bat" build apk --release

echo.
if %ERRORLEVEL% EQU 0 (
    echo ✅ APK successfully built!
    echo Location: build\app\outputs\flutter-apk\app-release.apk
    explorer build\app\outputs\flutter-apk\
) else (
    echo ❌ APK build failed!
)

echo.
pause