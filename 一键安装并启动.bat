@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title Video TalkCraft 一键安装并启动
cd /d "%~dp0"
set "ROOT=%CD%"
set "WINGET_LINKS=%LOCALAPPDATA%\Microsoft\WinGet\Links"
if exist "%WINGET_LINKS%" set "PATH=%WINGET_LINKS%;%PATH%"

echo ============================================================
echo   Video TalkCraft - Windows 一键安装并启动
echo   第一次运行会自动安装依赖，之后双击会直接启动工作台。
echo ============================================================
echo.

where winget >nul 2>nul
if errorlevel 1 (
  echo [错误] 未检测到 winget。请先安装/更新 Microsoft App Installer 后再运行。
  pause
  exit /b 1
)

call :EnsureNode || exit /b 1
call :EnsurePython || exit /b 1
call :EnsureFFmpeg || exit /b 1

echo.
echo [1/5] 安装 Python 依赖...
%PY_CMD% -m pip install --upgrade pip
if errorlevel 1 goto :fail
%PY_CMD% -m pip install zhconv pypinyin sherpa-onnx soundfile numpy requests python-dotenv
if errorlevel 1 goto :fail

echo.
echo [2/5] 安装 Remotion / React / 工作台依赖...
pushd "%ROOT%\runtime"
if exist package-lock.json (
  call npm ci --no-audit --no-fund
) else (
  call npm install --no-audit --no-fund
)
if errorlevel 1 (
  popd
  goto :fail
)

echo.
echo [3/5] 准备 Remotion 无头浏览器...
call npx remotion browser ensure
if errorlevel 1 (
  popd
  goto :fail
)
popd

echo.
echo [4/5] 连接工作台共享依赖，并注册 Codex / Claude Skill...
if exist "%ROOT%\workbench\node_modules" rmdir /s /q "%ROOT%\workbench\node_modules" >nul 2>nul
mklink /J "%ROOT%\workbench\node_modules" "%ROOT%\runtime\node_modules" >nul 2>nul
if errorlevel 1 (
  echo [警告] workbench\node_modules 创建目录联接失败，将改为独立安装。
  pushd "%ROOT%\workbench"
  call npm install --no-audit --no-fund
  if errorlevel 1 (
    popd
    goto :fail
  )
  popd
)

if not exist "%USERPROFILE%\.codex\skills" mkdir "%USERPROFILE%\.codex\skills" >nul 2>nul
if not exist "%USERPROFILE%\.claude\skills" mkdir "%USERPROFILE%\.claude\skills" >nul 2>nul

if exist "%USERPROFILE%\.codex\skills\video-talkcraft" rmdir "%USERPROFILE%\.codex\skills\video-talkcraft" >nul 2>nul
mklink /J "%USERPROFILE%\.codex\skills\video-talkcraft" "%ROOT%" >nul 2>nul

if exist "%USERPROFILE%\.claude\skills\video-talkcraft" rmdir "%USERPROFILE%\.claude\skills\video-talkcraft" >nul 2>nul
mklink /J "%USERPROFILE%\.claude\skills\video-talkcraft" "%ROOT%" >nul 2>nul

echo.
echo [5/5] 启动 TalkCraft 动效工作台...
start "TalkCraft Workbench" cmd /k "cd /d ""%ROOT%\workbench"" && npm run dev -- --host 127.0.0.1"
timeout /t 4 /nobreak >nul
start "" "http://127.0.0.1:5199"

echo.
echo ============================================================
echo   已完成。
echo   工作台地址: http://127.0.0.1:5199
echo.
echo   在 Codex / Claude Code 里直接说：
echo   “用 video-talkcraft 把这份口播稿 + 配音做成知识讲解视频”
echo.
echo   提示：首次做字级时间戳时，FireRedASR2 模型会额外下载约 767MB。
echo ============================================================
echo.
pause
exit /b 0

:EnsureNode
where node >nul 2>nul
if not errorlevel 1 exit /b 0
echo [准备] 未检测到 Node.js，正在安装 Node.js LTS...
winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements
set "PATH=%ProgramFiles%\nodejs;%WINGET_LINKS%;%PATH%"
where node >nul 2>nul
if errorlevel 1 (
  echo [错误] Node.js 安装后当前窗口仍无法找到，请关闭本窗口后再次双击本 BAT。
  pause
  exit /b 1
)
exit /b 0

:EnsurePython
set "PY_CMD=python"
where python >nul 2>nul
if not errorlevel 1 exit /b 0
where py >nul 2>nul
if not errorlevel 1 (
  set "PY_CMD=py -3"
  exit /b 0
)
echo [准备] 未检测到 Python，正在安装 Python 3.12...
winget install --id Python.Python.3.12 -e --accept-package-agreements --accept-source-agreements
set "PATH=%LOCALAPPDATA%\Programs\Python\Python312;%LOCALAPPDATA%\Programs\Python\Python312\Scripts;%PATH%"
where python >nul 2>nul
if errorlevel 1 (
  where py >nul 2>nul
  if errorlevel 1 (
    echo [错误] Python 安装后当前窗口仍无法找到，请关闭本窗口后再次双击本 BAT。
    pause
    exit /b 1
  )
  set "PY_CMD=py -3"
)
exit /b 0

:EnsureFFmpeg
where ffmpeg >nul 2>nul
if not errorlevel 1 exit /b 0
echo [准备] 未检测到 FFmpeg，正在安装...
winget install --id Gyan.FFmpeg -e --accept-package-agreements --accept-source-agreements
set "PATH=%WINGET_LINKS%;%PATH%"
where ffmpeg >nul 2>nul
if errorlevel 1 (
  echo [警告] FFmpeg 已请求安装，但当前窗口暂时未识别。若后续提示缺 FFmpeg，重新双击本 BAT 即可。
)
exit /b 0

:fail
echo.
echo [失败] 安装或启动过程中出现错误。请把本窗口最后 30 行截图发给我，我可以继续定位。
pause
exit /b 1
