@echo off
echo ============================================
echo  FlowPath AI - One-Click Setup
echo ============================================
echo.

REM Check Docker is running
docker info >nul 2>&1
if errorlevel 1 (
  echo ERROR: Docker Desktop is not running.
  echo Please start Docker Desktop first, then run this script again.
  pause
  exit /b 1
)

echo [1/4] Stopping any old containers...
docker-compose -f docker\docker-compose.yml down 2>nul

echo [2/4] Building and starting all services...
echo This takes 3-5 minutes on first run (downloading images)...
docker-compose -f docker\docker-compose.yml up --build -d

echo [3/4] Waiting for services to be healthy...
timeout /t 45 /nobreak >nul

echo [4/4] Checking API health...
curl -s http://localhost:3000/health
if errorlevel 1 (
  echo.
  echo Waiting a bit more...
  timeout /t 20 /nobreak >nul
  curl -s http://localhost:3000/health
)

echo.
echo ============================================
echo  FlowPath AI is running!
echo  API:       http://localhost:3000/health
echo  AI Engine: http://localhost:8000/docs
echo  Dashboard: http://localhost:3001
echo ============================================
pause
