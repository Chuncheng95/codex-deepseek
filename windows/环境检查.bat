@echo off
chcp 65001 >nul
title Codex Switch - Environment Check
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Check-Env.ps1"
echo.
pause
