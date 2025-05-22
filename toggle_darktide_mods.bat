@echo off
setlocal
set SCRIPT_EXIT_CODE=0
set DARKTIDE_DIR=

echo Starting Darktide patcher from %~dp0...

echo Locating Warhammer 40,000: Darktide please wait...

rem Define potential base Steam library paths or full game paths
rem Add more paths here if needed (e.g., other drives, custom Steam library locations)
rem Note: Batch arrays are cumbersome, using indexed variables instead
set "SCAN_PATH_1=C:\Program Files (x86)\Steam"
set "SCAN_PATH_2=D:\SteamLibrary"
set "SCAN_PATH_3=E:\SteamLibrary"
rem Add a check for the current directory as a fallback/primary check
set "SCAN_PATH_4=%~dp0"

rem Loop through potential paths
set "i=1"
:check_next_path
set "CURRENT_BASE_PATH="
call set "CURRENT_BASE_PATH=%%SCAN_PATH_%i%%%"

rem Check if the variable is empty (end of list)
if "%CURRENT_BASE_PATH%"=="" goto end_scan_loop

rem Construct the potential full game path
set "POTENTIAL_GAME_PATH="
if "%CURRENT_BASE_PATH%"=="%~dp0" (
    rem If checking the script's own directory, assume it *is* the game directory
    set "POTENTIAL_GAME_PATH=%~dp0"
) else (
    rem For other paths, assume it's a Steam library base path and look in steamapps\common
    set "POTENTIAL_GAME_PATH=%CURRENT_BASE_PATH%\steamapps\common\Warhammer 40,000 DARKTIDE"
)

rem Check if the potential game path exists as a directory
if exist "%POTENTIAL_GAME_PATH%\" (
    set "DARKTIDE_DIR=%POTENTIAL_GAME_PATH%"
    echo Found Darktide in %DARKTIDE_DIR%.
    goto found_darktide
)

rem Increment counter and check next path
set /a i+=1
goto check_next_path

:end_scan_loop
rem Darktide directory not found in predefined paths
echo All checks failed to locate Warhammer 40,000: Darktide in common locations.
set SCRIPT_EXIT_CODE=1
goto end_script

:found_darktide
rem Change directory to the found location
cd /d "%DARKTIDE_DIR%" || (
    echo Error: Unable to change directory to '%DARKTIDE_DIR%', exiting.
    set SCRIPT_EXIT_CODE=1
    goto end_script
)

rem Now proceed with the patcher logic, which assumes we are in the game directory
rem Check for required files and directories relative to the current directory
if not exist ".\tools\dtkit-patch.exe" (
    echo Error: Patcher executable ".\tools\dtkit-patch.exe" not found in %~dp0tools\
    set SCRIPT_EXIT_CODE=1
    goto end_script
)

if not exist ".\bundle" (
    echo Error: Bundle directory ".\bundle" not found in %~dp0
    set SCRIPT_EXIT_CODE=1
    goto end_script
)

rem Note: Batch cannot easily capture stdout/stderr and parse it like Bash readarray
rem We rely on the patcher's own output and exit code
echo Running patcher...
".\tools\dtkit-patch.exe" --toggle ".\bundle"
set "PATCHER_EXIT_CODE=%ERRORLEVEL%"

if %PATCHER_EXIT_CODE% NEQ 0 (
    rem The patcher itself reported an error (non-zero exit code)
    echo Error patching the Darktide bundle database. Patcher exit code: %PATCHER_EXIT_CODE%. See patcher output/logs.
    set SCRIPT_EXIT_CODE=%PATCHER_EXIT_CODE%
) else (
    echo Patcher completed successfully.
)

:end_script
pause
endlocal
exit /b %SCRIPT_EXIT_CODE%
