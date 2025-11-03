@echo off
title Git Auto Update - Admin Project
echo ==========================================
echo         CodeXHub Admin Auto Update
echo ==========================================
echo.

:: Go to the directory of this script (just in case you run it elsewhere)
cd /d "%~dp0"

:: Check if .git folder exists
if not exist ".git" (
    echo ❌ This folder is not a git repository.
    echo Please run: git init && git remote add origin https://github.com/kinglordz07/admin.git
    pause
    exit /b
)

:: Add all changes
git add .

:: Ask for commit message (optional)
set /p msg="Enter commit message (leave empty for 'Auto update'): "
if "%msg%"=="" set msg=Auto update

:: Commit changes
git commit -m "%msg%"

:: Detect current branch automatically
for /f "tokens=*" %%b in ('git branch --show-current') do set branch=%%b

:: Push to current branch
git push origin %branch%

echo.
echo ==========================================
echo ✅ Successfully pushed to branch: %branch%
echo ==========================================
pause
