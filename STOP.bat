@echo off
echo Stopping FlowPath AI...
docker-compose -f docker\docker-compose.yml down
echo All services stopped.
pause
