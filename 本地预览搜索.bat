@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo [1/3] 构建站点...
hugo
if errorlevel 1 (echo 构建失败！ & pause & exit /b 1)

echo [2/3] 生成 Pagefind 搜索索引...
npx -y pagefind
if errorlevel 1 (echo 索引生成失败！请确认已安装 Node.js & pause & exit /b 1)

echo [3/3] 启动本地静态服务器...
echo 在浏览器打开: http://localhost:8080/search/
echo 注意: 不要用 hugo server 测搜索, 它不会提供 /pagefind/ 资源
echo 按 Ctrl+C 可停止服务器
npx -y serve public -l 8080
pause
