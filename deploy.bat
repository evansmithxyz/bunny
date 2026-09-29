@echo off
rem Double-click to build Bunny Hop and install it on the connected phone.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy.ps1" %*
pause
