@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"

set "REMOTE=https://github.com/yuge258/zhishi.git"
set "BRANCH=main"

echo.
echo ========================================================
echo   zhishi 一键双向同步代码
echo   远端有新内容：先同步到本地
echo   本地有新内容：自动提交并同步到远端
echo   真正冲突：停止，不强制覆盖任何一边
echo ========================================================
echo.

where git >nul 2>&1 || (
  echo [错误] 没有找到 Git。请先运行“一键启动HyperFrames.bat”，它会自动安装 Git。
  pause
  exit /b 1
)

git rev-parse --is-inside-work-tree >nul 2>&1 || (
  echo [错误] 当前文件夹不是 Git Clone 出来的仓库。
  echo 请用下面地址 Clone，而不是只下载 ZIP：
  echo %REMOTE%
  pause
  exit /b 1
)

for /f "delims=" %%U in ('git remote get-url origin 2^>nul') do set "ORIGIN=%%U"
if not defined ORIGIN git remote add origin "%REMOTE%"

for /f "delims=" %%B in ('git branch --show-current') do set "CURRENT=%%B"
if /I not "%CURRENT%"=="%BRANCH%" (
  echo 当前分支是 %CURRENT%，正在切换到 %BRANCH%...
  git switch %BRANCH%
  if errorlevel 1 goto :CONFLICT
)

call :GitIdentity

echo [1/4] 获取 GitHub 最新状态...
git fetch origin %BRANCH%
if errorlevel 1 goto :NETWORK_FAIL

echo [2/4] 把远端新代码安全合并到本地...
git pull --rebase --autostash origin %BRANCH%
if errorlevel 1 goto :CONFLICT

echo [3/4] 检查本地修改...
git add -A
git diff --cached --quiet
if errorlevel 1 (
  set "STAMP=%date% %time%"
  git commit -m "Local sync !STAMP!"
  if errorlevel 1 goto :FAIL
) else (
  echo 本地没有新的未提交修改。
)

echo [4/4] 再确认远端状态并推送...
git fetch origin %BRANCH%
if errorlevel 1 goto :NETWORK_FAIL
git rebase origin/%BRANCH%
if errorlevel 1 goto :CONFLICT
git push origin %BRANCH%
if errorlevel 1 goto :PUSH_FAIL

echo.
echo ========================================================
echo [完成] 本地与 GitHub 已同步到同一版本。
echo ========================================================
pause
exit /b 0

:GitIdentity
git config user.name >nul 2>&1 || git config user.name "yuge258"
git config user.email >nul 2>&1 || git config user.email "yuge258@users.noreply.github.com"
exit /b 0

:CONFLICT
echo.
echo ========================================================
echo [保护停止] 本地和 GitHub 存在无法自动处理的冲突。
echo 脚本没有强制覆盖任何文件。
echo 请把这个窗口截图或运行“一键同步日志到仓库.bat”后发给我排查。
echo ========================================================
pause
exit /b 2

:NETWORK_FAIL
echo.
echo [失败] 无法从 GitHub 获取最新代码，请检查网络和 GitHub 登录状态。
pause
exit /b 3

:PUSH_FAIL
echo.
echo [失败] 本地已整理好，但推送 GitHub 失败。
echo 第一次使用 HTTPS Clone 时，Git Credential Manager 可能会要求你登录 GitHub。
pause
exit /b 4

:FAIL
echo.
echo [失败] 同步过程中发生错误，为避免覆盖文件已经停止。
pause
exit /b 5
