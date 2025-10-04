@echo off
REM Quick open script for Windows users
REM Opens NeurospLIT project in Xcode (if available on Windows/WSL)

echo Opening NeurospLIT project...

if exist "NeurospLIT.xcodeproj" (
    echo Project found at: %CD%\NeurospLIT.xcodeproj
    
    REM Try to open with default application
    start "" "NeurospLIT.xcodeproj"
    
    echo.
    echo If Xcode didn't open, please:
    echo 1. Transfer this project to a Mac
    echo 2. Run: open NeurospLIT.xcodeproj
    echo    OR
    echo 3. Use GitHub's "Open with Xcode" feature
) else (
    echo Error: NeurospLIT.xcodeproj not found!
    echo Please run this script from the project root directory.
)

pause
