@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"

set "ROOT=%CD%"
set "HF=%ROOT%\hyperframes"
set "LOGDIR=%ROOT%\diagnostics"
set "LOG=%LOGDIR%\studio-latest.log"

if not exist "%HF%\package.json" (
  echo [错误] 没有找到 hyperframes\package.json。
  echo 请确认你是完整 Clone 的 zhishi 仓库，而不是只下载了单个 BAT。
  pause
  exit /b 1
)

if not exist "%LOGDIR%" mkdir "%LOGDIR%"
>"%LOG%" echo ===== HyperFrames Studio 启动日志 %date% %time% =====

echo.
echo ========================================================
echo   HyperFrames 官方原版 - 一键启动
echo   原版源码目录：hyperframes\
echo   本脚本不会修改官方源码文件
echo ========================================================
echo.

call :EnsureGit || goto :FAIL
call :EnsureNode || goto :FAIL
call :EnsureBun || goto :FAIL
call :EnsureFFmpeg || goto :FAIL

echo [1/3] 环境检查完成。
(
  echo Git:
  git --version
  echo Node:
  node --version
  echo Bun:
  bun --version
  echo FFmpeg:
  ffmpeg -version 2^>nul | findstr /B /C:"ffmpeg version"
) >> "%LOG%" 2>&1

echo [2/3] 检查官方源码依赖...
cd /d "%HF%"
bun install --frozen-lockfile >> "%LOG%" 2>&1
if errorlevel 1 (
  echo 固定锁文件安装失败，尝试普通 bun install...
  bun install >> "%LOG%" 2>&1
  if errorlevel 1 goto :FAIL
)

echo [3/3] 启动 HyperFrames Studio...
echo 浏览器地址：http://127.0.0.1:5173
echo 这个黑色窗口不要关；关闭它就会停止 Studio。
echo.

start "" powershell -NoProfile -WindowStyle Hidden -Command "Start-Sleep -Seconds 4; Start-Process 'http://127.0.0.1:5173'"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { bun run dev 2>&1 | Tee-Object -FilePath '%LOG%' -Append }"
exit /b %errorlevel%

:EnsureGit
where git >nul 2>&1 && exit /b 0
echo 正在安装 Git for Windows...
where winget >nul 2>&1 || (
  echo [错误] 未找到 winget，无法自动安装 Git。
  exit /b 1
)
winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
set "PATH=%ProgramFiles%\Git\cmd;%PATH%"
where git >nul 2>&1 || exit /b 1
exit /b 0

:EnsureNode
set "NEED_NODE=0"
where node >nul 2>&1 || set "NEED_NODE=1"
if "%NEED_NODE%"=="0" (
  for /f "delims=" %%V in ('node -p "Number(process.versions.node.split('.')[0])" 2^>nul') do set "NODE_MAJOR=%%V"
  if not defined NODE_MAJOR set "NEED_NODE=1"
  if defined NODE_MAJOR if !NODE_MAJOR! LSS 22 set "NEED_NODE=1"
)
if "%NEED_NODE%"=="0" exit /b 0

echo 正在安装/升级 Node.js LTS（HyperFrames CLI 要求 Node 22+）...
where winget >nul 2>&1 || (
  echo [错误] 未找到 winget，无法自动安装 Node.js。
  exit /b 1
)
winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements
set "PATH=%ProgramFiles%\nodejs;%PATH%"
where node >nul 2>&1 || exit /b 1
for /f "delims=" %%V in ('node -p "Number(process.versions.node.split('.')[0])" 2^>nul') do set "NODE_MAJOR=%%V"
if not defined NODE_MAJOR exit /b 1
if !NODE_MAJOR! LSS 22 (
  echo [错误] Node.js 版本仍低于 22，请重启电脑后再次运行本脚本。
  exit /b 1
)
exit /b 0

:EnsureBun
set "PATH=%USERPROFILE%\.bun\bin;%PATH%"
where bun >nul 2>&1 && exit /b 0
echo 正在安装 Bun...
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://bun.sh/install.ps1 | iex"
set "PATH=%USERPROFILE%\.bun\bin;%PATH%"
where bun >nul 2>&1 || exit /b 1
exit /b 0

:EnsureFFmpeg
set "PATH=%LOCALAPPDATA%\Microsoft\WinGet\Links;%PATH%"
where ffmpeg >nul 2>&1 && exit /b 0
echo 正在安装 FFmpeg...
where winget >nul 2>&1 || (
  echo [错误] 未找到 winget，无法自动安装 FFmpeg。
  exit /b 1
)
winget install --id Gyan.FFmpeg -e --accept-package-agreements --accept-source-agreements
set "PATH=%LOCALAPPDATA%\Microsoft\WinGet\Links;%PATH%"
where ffmpeg >nul 2>&1 || (
  echo [提示] FFmpeg 已请求安装，但当前窗口暂时找不到它。请关闭窗口再双击一次 BAT。
  exit /b 1
)
exit /b 0

:FAIL
echo.
echo ========================================================
echo [失败] 启动没有完成。
echo 日志位置：%LOG%
echo 你可以双击“一键同步日志到仓库.bat”把日志传到 GitHub。
echo ========================================================
pause
exit /b 1
