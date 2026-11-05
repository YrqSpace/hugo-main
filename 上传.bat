@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

echo ============================================
echo  Push source to hugo-main
echo  GitHub Actions will build and publish.
echo ============================================
echo.

git add -A
git commit -m "site update"
echo.

echo Pushing...
git push
if errorlevel 1 (
    echo.
    echo [ERROR] Push failed.
    echo   1. Start your accelerator ^(Watt hosts mode recommended^)
    echo   2. Run this file again
    echo.
    pause
    exit /b 1
)

echo.
echo Done.
echo Build log: https://github.com/YrqSpace/hugo-main/actions
echo Site:      https://tinkerlog.dpdns.org/
echo.
pause
