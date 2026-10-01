@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"

set "ROOT=%CD%"
set "HF=%ROOT%\hyperframes"
set "LOGDIR=%ROOT%\diagnostics"
set "REMOTE=https://github.com/yuge258/zhishi.git"
set "BRANCH=main"

if not exist "%LOGDIR%" mkdir "%LOGDIR%"

echo.
echo ========================================================
echo   HyperFrames 一键收集并同步日志
echo ========================================================
echo.

where git >nul 2>&1 || (
  echo [错误] 没有找到 Git。请先运行“一键启动HyperFrames.bat”。
  pause
  exit /b 1
)

git rev-parse --is-inside-work-tree >nul 2>&1 || (
  echo [错误] 当前文件夹不是 Git Clone 出来的仓库。
  echo 请从 %REMOTE% Clone 后再使用日志同步。
  pause
  exit /b 1
)

for /f "delims=" %%U in ('git remote get-url origin 2^>nul') do set "ORIGIN=%%U"
if not defined ORIGIN git remote add origin "%REMOTE%"

for /f "delims=" %%B in ('git branch --show-current') do set "CURRENT=%%B"
if /I not "%CURRENT%"=="%BRANCH%" (
  git switch %BRANCH%
  if errorlevel 1 goto :FAIL
)

git config user.name >nul 2>&1 || git config user.name "yuge258"
git config user.email >nul 2>&1 || git config user.email "yuge258@users.noreply.github.com"

echo [1/4] 先同步 GitHub 最新状态...
git fetch origin %BRANCH%
if errorlevel 1 goto :NETWORK_FAIL
git pull --rebase --autostash origin %BRANCH%
if errorlevel 1 goto :CONFLICT

echo [2/4] 收集环境与 Git 状态...
> "%LOGDIR%\system-latest.txt" echo ===== HyperFrames Diagnostics %date% %time% =====
>>"%LOGDIR%\system-latest.txt" echo.
>>"%LOGDIR%\system-latest.txt" echo [Windows]
ver >>"%LOGDIR%\system-latest.txt" 2>&1
>>"%LOGDIR%\system-latest.txt" echo.
>>"%LOGDIR%\system-latest.txt" echo [Git]
git --version >>"%LOGDIR%\system-latest.txt" 2>&1
git rev-parse HEAD >>"%LOGDIR%\system-latest.txt" 2>&1
git status --short >>"%LOGDIR%\system-latest.txt" 2>&1
>>"%LOGDIR%\system-latest.txt" echo.
>>"%LOGDIR%\system-latest.txt" echo [Node]
node --version >>"%LOGDIR%\system-latest.txt" 2>&1
>>"%LOGDIR%\system-latest.txt" echo [Bun]
bun --version >>"%LOGDIR%\system-latest.txt" 2>&1
>>"%LOGDIR%\system-latest.txt" echo [FFmpeg]
ffmpeg -version >>"%LOGDIR%\system-latest.txt" 2>&1

> "%LOGDIR%\git-recent.txt" echo ===== Recent commits =====
git log -30 --oneline --decorate >>"%LOGDIR%\git-recent.txt" 2>&1
>>"%LOGDIR%\git-recent.txt" echo.
>>"%LOGDIR%\git-recent.txt" echo ===== Status =====
git status >>"%LOGDIR%\git-recent.txt" 2>&1

echo [3/4] 运行 HyperFrames 官方 doctor...
where npx >nul 2>&1
if errorlevel 1 (
  > "%LOGDIR%\doctor-latest.txt" echo npx 不可用，无法运行 hyperframes doctor。
) else (
  pushd "%HF%"
  call npx --yes hyperframes doctor > "%LOGDIR%\doctor-latest.txt" 2>&1
  popd
)

echo [4/4] 提交 diagnostics 到 GitHub...
git add -f diagnostics
git diff --cached --quiet
if errorlevel 1 (
  set "STAMP=%date% %time%"
  git commit -m "Sync HyperFrames diagnostics !STAMP!"
  if errorlevel 1 goto :FAIL
) else (
  echo 日志内容没有变化，无需新建提交。
)

git fetch origin %BRANCH%
if errorlevel 1 goto :NETWORK_FAIL
git rebase origin/%BRANCH%
if errorlevel 1 goto :CONFLICT
git push origin %BRANCH%
if errorlevel 1 goto :PUSH_FAIL

echo.
echo ========================================================
echo [完成] 日志已经同步到 GitHub 的 diagnostics 目录。
echo 主要文件：
echo   diagnostics\studio-latest.log
echo   diagnostics\system-latest.txt
echo   diagnostics\doctor-latest.txt
echo   diagnostics\git-recent.txt
echo ========================================================
pause
exit /b 0

:CONFLICT
echo.
echo [保护停止] 仓库存在冲突，没有强制覆盖文件。
pause
exit /b 2

:NETWORK_FAIL
echo.
echo [失败] 无法连接 GitHub，请检查网络或登录状态。
pause
exit /b 3

:PUSH_FAIL
echo.
echo [失败] 日志已经在本地生成，但推送 GitHub 失败。
echo 第一次推送可能需要 Git Credential Manager 登录 GitHub。
pause
exit /b 4

:FAIL
echo.
echo [失败] 日志同步没有完成。
pause
exit /b 5
