@echo off

echo Starting Darktide patcher from %~dp0...
cd /d "%~dp0"
".\tools\dtkit-patch" --toggle ".\bundle"
if errorlevel 1 goto failure
goto leave

:failure
echo Error patching the Darktide bundle database. See logs.
goto leave

:leave
pause
exit
