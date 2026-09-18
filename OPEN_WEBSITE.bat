@echo off
title RCDO Rwanda - Opening Platform
color 0B
echo.
echo  ============================================================
echo   RWANDA COMMUNITY DEVELOPMENT ORGANIZATION (RCDO)
echo   Opening Platform & Website in your default browser...
echo  ============================================================
echo.

:: Check if server is already running on port 8000
netstat -ano | findstr ":8000" > nul
if %errorlevel% neq 0 (
    echo  Backend server is not running yet.
    echo  Starting START_SERVER.bat in a background window...
    start "RCDO Server" "%~dp0START_SERVER.bat"
    echo  Waiting 3 seconds for server to initialize...
    timeout /t 3 /nobreak > nul
) else (
    echo  Backend server is already running on http://localhost:8000
)

echo.
echo  Launching browser at: http://localhost:8000
start "" "http://localhost:8000"

echo.
echo  ============================================================
echo   Website & Platform successfully opened!
echo   Public Website:  http://localhost:8000
echo   Staff Dashboard: http://localhost:8000/dashboard
echo   API Docs:        http://localhost:8000/docs
echo  ============================================================
echo.
echo  Press any key to close this launcher.
pause > nul
