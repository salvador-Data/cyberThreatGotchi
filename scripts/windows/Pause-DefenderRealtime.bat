@echo off
REM CyberThreatGotchi - pause/resume Defender real-time (UAC elevation)
REM Double-click toggles pause/resume. For -Pause/-Resume/-Status use Admin PowerShell (README).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-AsAdmin.ps1" -TargetScript "%~dp0Pause-DefenderRealtime.ps1"
exit /b %ERRORLEVEL%
