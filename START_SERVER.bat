@echo off
title RCDO Rwanda - Data Platform Server
color 0A
echo.
echo  ============================================================
echo   RWANDA COMMUNITY DEVELOPMENT ORGANIZATION (RCDO)
echo   Data Management and Analytics Platform
echo  ============================================================
echo.
echo  Starting backend server...
echo  The website will be available at: http://localhost:8000
echo  Staff Dashboard: http://localhost:8000/dashboard
echo  API Documentation: http://localhost:8000/docs
echo.
echo  Press CTRL+C to stop the server.
echo  ============================================================
echo.

cd /d "%~dp0"
python -m uvicorn backend.app.main:app --host 0.0.0.0 --port 8000 --reload

pause
