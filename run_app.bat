@echo off
echo Starting Abhaya on Android Emulator...
echo.

set ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe
set EMULATOR=%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe

echo [1/3] Launching Android Emulator...
start "" "%EMULATOR%" -avd Pixel_8_API_34 -no-snapshot-load

echo [2/3] Waiting 90 seconds for emulator to boot...
timeout /t 90 /nobreak

echo [3/3] Running Flutter app...
cd /d "%~dp0"
flutter run -d emulator-5554 --no-pub

pause
