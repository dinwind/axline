@echo off
setlocal EnableDelayedExpansion

REM ============================================================================
REM AxLine VS Code Build Script - Windows x64
REM Prerequisites: Node.js 24.18.0+, VS 2026/2022 C++ tools, Python 3.x
REM
REM Usage:
REM   scripts\build.bat [install|compile|rebuild|run|watch|clean|sync-axline|check]
REM
REM Sub-commands:
REM   run         foreground mode — keeps Electron attached to console so errors
REM               are visible.  Ctrl+C quits.
REM   run-bg      background mode (old behaviour) — detaches via `start`, silent
REM               on errors.  Use `check` first when something goes wrong.
REM   check       verify compiled output, Electron version, and Axline extension
REM               integrity before launching (fast, ~1 s).
REM ============================================================================

set "PROJECT_ROOT=%~dp0.."
cd /d "%PROJECT_ROOT%"

REM --- Locate Visual Studio vcvars64.bat ---
set "VCVARS="
for %%e in (
    "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
    "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat"
    "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
    "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
) do (
    if exist %%e set "VCVARS=%%e" && goto :vcvars_found
)
echo [ERROR] Visual Studio or Build Tools not found.
exit /b 1

:vcvars_found
set "VCVARS=!VCVARS:"=!"
echo [INFO] VS: !VCVARS!
call "!VCVARS!" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] vcvars64.bat failed.
    exit /b 1
)
echo [INFO] MSVC 64-bit toolchain loaded.

REM Derive VS install root for preinstall.ts C++ detection
for %%p in ("!VCVARS!") do set "VS_ROOT=%%~dpp..\..\..\.."
for %%p in ("!VS_ROOT!") do set "VS_ROOT=%%~fp"
set "vs2022_install=!VS_ROOT!"
echo [INFO] vs2022_install=!vs2022_install!

where node.exe >nul 2>&1 || (echo [ERROR] Node.js not found & exit /b 1)
for /f "tokens=*" %%v in ('node -v') do echo [INFO] Node: %%v

REM --- Dispatch ---
if /i "%~1"=="sync-axline" goto :sync_axline
if /i "%~1"==""        goto :full_build
if /i "%~1"=="rebuild" goto :rebuild
if /i "%~1"=="install" goto :install
if /i "%~1"=="compile" goto :compile
if /i "%~1"=="run"     goto :run
if /i "%~1"=="run-bg"  goto :run_bg
if /i "%~1"=="check"   goto :check
if /i "%~1"=="watch"   goto :watch
if /i "%~1"=="clean"   goto :clean
if /i "%~1"=="-h"      goto :help
if /i "%~1"=="--help"  goto :help
echo [ERROR] Unknown: %~1
:help
echo Usage: scripts\build.bat [install^|compile^|rebuild^|run^|run-bg^|watch^|clean^|sync-axline^|check]
exit /b 0

REM =====================================================================
:clean
echo [CLEAN] Removing build artifacts...
if exist node_modules (rmdir /s /q node_modules 2>nul & echo   node_modules)
if exist .build (rmdir /s /q .build 2>nul & echo   .build)
if exist out (rmdir /s /q out 2>nul & echo   out)
if exist out-build (rmdir /s /q out-build 2>nul & echo   out-build)
echo [CLEAN] Done.
goto :eof

REM =====================================================================
:install
echo [INSTALL] Installing npm deps (10-30 min)...
call :sync_axline || exit /b 1
call npm install
if errorlevel 1 (
    echo [ERROR] npm install failed.
    exit /b 1
)
echo [INSTALL] Done.
goto :eof

REM =====================================================================
:compile
echo [COMPILE] Building VS Code...
call :sync_axline || exit /b 1
if not exist node_modules (echo [ERROR] Run install first & exit /b 1)
call npm run gulp compile -- --no-typecheck
if errorlevel 1 (
    echo [ERROR] Compile failed.
    exit /b 1
)
echo [COMPILE] Done.
goto :eof

REM =====================================================================
:full_build
echo [BUILD] Full build...
if not exist node_modules goto :do_install
if not exist out goto :do_compile
echo [BUILD] Existing build - use rebuild for clean build.
goto :do_compile
:do_install
call :install || exit /b 1
:do_compile
call :compile || exit /b 1
echo [BUILD] Success. Run: scripts\build.bat run
goto :eof

REM =====================================================================
:rebuild
echo [REBUILD] Clean + full build...
call :clean
echo.
call :full_build
goto :eof

REM =====================================================================
:run
echo [RUN] Build ^& launch VS Code (foreground)...
call :sync_axline || exit /b 1
if not exist node_modules (call :install || exit /b 1)
if not exist out (call :compile || exit /b 1)
echo [RUN] Pre-launch setup...
node build\lib\preLaunch.ts
if errorlevel 1 (
    echo [ERROR] preLaunch failed.
    exit /b 1
)
for /f "tokens=2 delims=:," %%a in ('findstr /R /C:"\"nameShort\".*" product.json') do set "EXE=%%~a.exe"
set "EXE=!EXE: "=!"
set "EXE=!EXE:"=!"
set "CODE=.build\electron\!EXE!"
if not exist "!CODE!" (
    echo [ERROR] Electron not found: !CODE!
    exit /b 1
)
set NODE_ENV=development
set VSCODE_DEV=1
set VSCODE_CLI=1
REM --- Patch Electron 42 ESM compatibility (Menu export) ---------------
call :patch_main_js_menu
REM ---------------------------------------------------------------------
echo [RUN] Launching Electron (errors will appear here)...
"!CODE!" . --disable-extension=vscode.vscode-api-tests
goto :eof

REM =====================================================================
:run_bg
echo [RUN] Build ^& launch VS Code (background)...
call :sync_axline || exit /b 1
if not exist node_modules (call :install || exit /b 1)
if not exist out (call :compile || exit /b 1)
echo [RUN] Pre-launch setup...
node build\lib\preLaunch.ts
if errorlevel 1 (
    echo [ERROR] preLaunch failed.
    exit /b 1
)
for /f "tokens=2 delims=:," %%a in ('findstr /R /C:"\"nameShort\".*" product.json') do set "EXE=%%~a.exe"
set "EXE=!EXE: "=!"
set "EXE=!EXE:"=!"
set "CODE=.build\electron\!EXE!"
if not exist "!CODE!" (
    echo [ERROR] Electron not found: !CODE!
    exit /b 1
)
set NODE_ENV=development
set VSCODE_DEV=1
set VSCODE_CLI=1
call :patch_main_js_menu
start "" "!CODE!" . --disable-extension=vscode.vscode-api-tests
echo [RUN] VS Code launched (detached — use `check` if window doesn't appear).
goto :eof

REM =====================================================================
REM Quick integrity check: compiled output, Electron version, Axline ext.
REM =====================================================================
:check
echo [CHECK] Verifying build integrity...
set OK=1

REM 1 — compiled output
if not exist out\main.js (
    echo [CHECK] FAIL: out\main.js missing — run scripts\build.bat compile
    set OK=0
) else (
    echo [CHECK] PASS: out\main.js present
)

REM 2 — Electron binary
for /f "tokens=2 delims=:," %%a in ('findstr /R /C:"\"nameShort\".*" product.json') do set "EXE=%%~a.exe"
set "EXE=!EXE: "=!"
set "EXE=!EXE:"=!"
set "CODE=.build\electron\!EXE!"
if not exist "!CODE!" (
    echo [CHECK] FAIL: Electron binary not found — run scripts\build.bat compile
    set OK=0
) else (
    echo [CHECK] PASS: Electron binary !CODE!
)

REM 3 — Electron version compatibility
if exist .build\electron\version (
    for /f %%v in (.build\electron\version) do set "EVER=%%v"
    echo [CHECK] INFO: Electron !EVER!
)

REM 4 — Node.js compatibility
for /f "tokens=*" %%v in ('node -v') do echo [CHECK] INFO: Node %%v

REM 5 — Axline extension
if exist .build\builtInExtensions\axline.axline\package.json (
    powershell -NoProfile -Command "$v=(Get-Content '.build\builtInExtensions\axline.axline\package.json'|ConvertFrom-Json).version; Write-Host \"[CHECK] PASS: Axline extension $v\""
) else (
    echo [CHECK] FAIL: Axline extension not extracted — run scripts\build.bat compile
    set OK=0
)

REM 6 — menu patch status
findstr /C:"Menu?.setApplicationMenu" out\main.js >nul 2>&1
if errorlevel 1 (
    echo [CHECK] WARN: main.js Menu patch not detected — run may fail on Electron 42
) else (
    echo [CHECK] PASS: main.js Electron 42 Menu compatibility patch applied
)

if !OK!==0 (
    echo [CHECK] Some checks FAILed.  Run: scripts\build.bat compile
    exit /b 1
)
echo [CHECK] All checks passed.
goto :eof

REM =====================================================================
REM Patch out\main.js for Electron 42 ESM compatibility.
REM Electron 42 does not export `Menu` via named ESM import.
REM We rewrite `import { ..., Menu, ... } from "electron"` to a CJS
REM require so `Menu.setApplicationMenu(null)` still works.
REM =====================================================================
:patch_main_js_menu
if not exist out\main.js goto :eof
findstr /C:"Menu?.setApplicationMenu" out\main.js >nul 2>&1
if not errorlevel 1 goto :eof
echo [RUN] Patching out\main.js for Electron 42 Menu compatibility...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$c = [System.IO.File]::ReadAllText('out\main.js'); ^
   $old = 'import { app, protocol, crashReporter, Menu, contentTracing } from \"electron\";'; ^
   $new = 'import { app, protocol, crashReporter, contentTracing } from \"electron\";'\"`r`n\"'let Menu;'\"`r`n\"'try { Menu = require(\"electron\").Menu; } catch { }'; ^
   $c = $c.Replace($old, $new); ^
   $c = $c -replace 'Menu\.setApplicationMenu\(null\);', 'Menu?.setApplicationMenu(null);'; ^
   [System.IO.File]::WriteAllText('out\main.js', $c)"
goto :eof

REM =====================================================================
:watch
echo [WATCH] Starting dev watch mode...
if not exist node_modules (call :install || exit /b 1)
npm run watch
goto :eof

REM =====================================================================
REM Sync the embedded Axline extension (.vsix) from AuthNexus before building.
REM Runs the PowerShell worker with -UpdateProductJson so product.json stays
REM in lock-step with the downloaded artifact (version + sha256).
REM =====================================================================
:sync_axline
echo [SYNC-AXLINE] Checking for latest Axline extension...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync-axline-vsix.ps1" -UpdateProductJson
if errorlevel 1 (
    echo [ERROR] Axline .vsix sync failed.
    exit /b 1
)
echo [SYNC-AXLINE] Done.
goto :eof