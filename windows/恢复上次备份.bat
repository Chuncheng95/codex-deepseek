@echo off
chcp 65001 >nul
title Codex Switch - Restore
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CodexSwitch.ps1" -Mode restore
