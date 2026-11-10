@echo off
cd /d "%~dp0"
if exist "D:\CodexDownloads\娱乐\Godot\Godot_v4.7.2-stable_win64.exe" (
  start "Sea Drifter" "D:\CodexDownloads\娱乐\Godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0."
) else (
  godot --path "%~dp0."
  if errorlevel 1 pause
)
