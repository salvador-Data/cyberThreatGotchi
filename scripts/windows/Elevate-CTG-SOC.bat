@echo off
REM CyberThreatGotchi - elevate SOC one-shot (UAC prompt)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-AsAdmin.ps1"
exit /b %ERRORLEVEL%
