@echo off
title Trade AI STOP
echo Eski serverlar to'xtatilmoqda...
for %%p in (8000 8001 5173 5174) do (
  for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%%p " ^| findstr LISTENING') do (
    taskkill /F /PID %%a 2>nul
  )
)
taskkill /F /IM node.exe /T 2>nul
echo Tayyor. Endi ISHGA-TUSHIR.bat bosing.
pause
