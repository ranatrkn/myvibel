@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-maestro-smoke.ps1" %*
exit /b %ERRORLEVEL%
