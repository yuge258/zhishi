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
echo   首次自动配环境；以后双击直接启动工作台。
echo ============================================================
echo.

call :EnsureNode || exit /b 1
call :EnsurePython || exit /b 1
call :EnsureFFmpeg || exit /b 1

echo.
echo [1/5] 检查 Python 依赖...
%PY_CMD% -c "import zhconv,pypinyin,sherpa_onnx,soundfile,numpy,requests,dotenv" >nul 2>nul
if errorlevel 1 (
  echo     缺少依赖，开始安装...
  %PY_CMD% -m pip install --upgrade pip
  if errorlevel 1 goto :fail
  %PY_CMD% -m pip install zhconv pypinyin sherpa-onnx soundfile numpy requests python-dotenv
  if errorlevel 1 goto :fail
) else (
  echo     Python 依赖已就绪。
)

echo.
echo [2/5] 检查 Remotion / React 统一依赖...
if not exist "%ROOT%\runtime\node_modules\.package-lock.json" (
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
  popd
) else (
  echo     Node 依赖已就绪。
)

echo.
echo [3/5] 检查 Remotion 无头浏览器...
if not exist "%ROOT%\runtime\node_modules\.remotion\chrome-headless-shell" (
  pushd "%ROOT%\runtime"
  call npx remotion browser ensure
  if errorlevel 1 (
    popd
    goto :fail
  )
  popd
) else (
  echo     Remotion 浏览器已就绪。
)

echo.
echo [4/5] 修复 Windows 目录联接并注册 Codex / Claude Skill...
if not exist "%ROOT%\gallery\media" mkdir "%ROOT%\gallery\media" >nul 2>nul

call :MakeJunction "%ROOT%\workbench\node_modules" "%ROOT%\runtime\node_modules"
if errorlevel 1 goto :fail
call :MakeJunction "%ROOT%\workbench\public\cardpreviews" "%ROOT%\gallery\media"
if errorlevel 1 goto :fail
call :MakeJunction "%ROOT%\workbench\public\cardthumbs" "%ROOT%\gallery\thumbs"
if errorlevel 1 goto :fail
call :MakeJunction "%ROOT%\workbench\tplcards" "%ROOT%\template\cards"
if errorlevel 1 goto :fail

if not exist "%USERPROFILE%\.codex\skills" mkdir "%USERPROFILE%\.codex\skills" >nul 2>nul
if not exist "%USERPROFILE%\.claude\skills" mkdir "%USERPROFILE%\.claude\skills" >nul 2>nul
call :MakeJunction "%USERPROFILE%\.codex\skills\video-talkcraft" "%ROOT%"
call :MakeJunction "%USERPROFILE%\.claude\skills\video-talkcraft" "%ROOT%"

echo.
echo [5/5] 启动 TalkCraft 动效工作台...
start "TalkCraft Workbench" cmd /k "cd /d ""%ROOT%\workbench"" && npm run dev -- --host 127.0.0.1"
timeout /t 4 /nobreak >nul
start "" "http://127.0.0.1:5199"

echo.
echo ============================================================
echo   启动完成
echo   工作台: http://127.0.0.1:5199
echo.
echo   在 Codex / Claude Code 里可以直接说：
echo   “用 video-talkcraft 把这份口播稿 + 配音做成知识讲解视频”
echo.
echo   首次使用 FireRedASR2 字级时间戳时，模型还会下载约 767MB。
echo ============================================================
echo.
pause
exit /b 0

:EnsureWinget
where winget >nul 2>nul
if not errorlevel 1 exit /b 0
echo [错误] 需要自动安装系统组件，但当前电脑没有 winget。
echo 请先在 Microsoft Store 安装/更新“应用安装程序 App Installer”，然后重新双击本 BAT。
pause
exit /b 1

:EnsureNode
where node >nul 2>nul
if not errorlevel 1 (
  for /f "tokens=1 delims=." %%V in ('node -p "process.versions.node"') do set "NODE_MAJOR=%%V"
  if !NODE_MAJOR! GEQ 18 exit /b 0
  echo [准备] 当前 Node.js 版本低于 18，升级到 LTS...
) else (
  echo [准备] 未检测到 Node.js，安装 Node.js LTS...
)
call :EnsureWinget || exit /b 1
winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements
set "PATH=%ProgramFiles%\nodejs;%WINGET_LINKS%;%PATH%"
where node >nul 2>nul
if errorlevel 1 (
  echo [错误] Node.js 已安装但当前窗口尚未识别。请关闭本窗口后重新双击本 BAT。
  pause
  exit /b 1
)
exit /b 0

:EnsurePython
set "PY_CMD=python"
where py >nul 2>nul
if not errorlevel 1 (
  py -3.11 --version >nul 2>nul
  if not errorlevel 1 (
    set "PY_CMD=py -3.11"
    exit /b 0
  )
)
where python >nul 2>nul
if not errorlevel 1 (
  python -c "import sys; raise SystemExit(0 if sys.version_info >= (3,10) else 1)" >nul 2>nul
  if not errorlevel 1 exit /b 0
)
echo [准备] 未检测到合适的 Python，安装 Python 3.11...
call :EnsureWinget || exit /b 1
winget install --id Python.Python.3.11 -e --accept-package-agreements --accept-source-agreements
set "PATH=%LOCALAPPDATA%\Programs\Python\Python311;%LOCALAPPDATA%\Programs\Python\Python311\Scripts;%PATH%"
where py >nul 2>nul
if not errorlevel 1 (
  py -3.11 --version >nul 2>nul
  if not errorlevel 1 (
    set "PY_CMD=py -3.11"
    exit /b 0
  )
)
where python >nul 2>nul
if errorlevel 1 (
  echo [错误] Python 已安装但当前窗口尚未识别。请关闭本窗口后重新双击本 BAT。
  pause
  exit /b 1
)
set "PY_CMD=python"
exit /b 0

:EnsureFFmpeg
where ffmpeg >nul 2>nul
if not errorlevel 1 exit /b 0
echo [准备] 未检测到 FFmpeg，开始安装...
call :EnsureWinget || exit /b 1
winget install --id Gyan.FFmpeg -e --accept-package-agreements --accept-source-agreements
set "PATH=%WINGET_LINKS%;%PATH%"
where ffmpeg >nul 2>nul
if errorlevel 1 (
  echo [警告] FFmpeg 已请求安装，但当前窗口暂未识别。
  echo 如果后面仍提示缺 FFmpeg，关闭窗口后重新双击本 BAT 即可。
)
exit /b 0

:RemovePath
set "RP=%~1"
if exist "%RP%\NUL" rmdir /s /q "%RP%" >nul 2>nul
if exist "%RP%" del /f /q "%RP%" >nul 2>nul
if exist "%RP%" rmdir /s /q "%RP%" >nul 2>nul
exit /b 0

:MakeJunction
set "LINK=%~1"
set "TARGET=%~2"
call :RemovePath "%LINK%"
mklink /J "%LINK%" "%TARGET%" >nul 2>nul
if errorlevel 1 (
  echo [错误] 无法创建目录联接：
  echo        %LINK%
  echo     到 %TARGET%
  echo 请确认当前目录可写，然后把本窗口截图发给我。
  exit /b 1
)
exit /b 0

:fail
echo.
echo [失败] 安装或启动过程中出现错误。
echo 请把本窗口最后 30 行截图发给我，我可以继续定位。
pause
exit /b 1
