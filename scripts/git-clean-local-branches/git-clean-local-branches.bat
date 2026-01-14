@echo off
REM Windows wrapper for `git-clean-local-branches.sh`
REM Finds Git Bash, changes to script dir, runs the bash script with all args

setlocal

REM Try to find Git Bash
set "GITBASH="
if exist "C:\Program Files\Git\bin\bash.exe" set "GITBASH=C:\Program Files\Git\bin\bash.exe"
if exist "C:\Program Files (x86)\Git\bin\bash.exe" set "GITBASH=C:\Program Files (x86)\Git\bin\bash.exe"
if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" set "GITBASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"

if "%GITBASH%"=="" (
    echo Error: Git Bash not found. Please install Git for Windows.
    echo Download from: https://git-scm.com/download/win
    pause
    exit /b 1
)

REM Get the directory where this batch file is located
set "SCRIPT_DIR=%~dp0"

REM Change to script directory (handles spaces) and run the bash script
pushd "%SCRIPT_DIR%" >nul 2>&1 || (
    echo Error: cannot change to script directory %SCRIPT_DIR%
    pause
    exit /b 1
)

REM Run the bash script with all original arguments
"%GITBASH%" "./git-clean-local-branches.sh" %*

REM Return to original directory
popd >nul 2>&1
endlocal
