@echo off
setlocal EnableDelayedExpansion

if "%1"=="full" (
    echo Starting full deployment...
) else (
    set "msg=Starting partial deployment... (backend run on host), use "full" to run all services in containers"
    echo !msg!
)

openssl rand -hex 32 >nul 2>&1
if %ERRORLEVEL% == 0 (
    for /f %%i in ('openssl rand -hex 32') do set SEARXNG_SECRET_KEY=%%i
    goto :key_generated
)

python --version >nul 2>&1
if %ERRORLEVEL% == 0 (
    for /f %%i in ('python -c "import secrets; print(secrets.token_hex(32))"') do set SEARXNG_SECRET_KEY=%%i
    goto :key_generated
)

py --version >nul 2>&1
if %ERRORLEVEL% == 0 (
    for /f %%i in ('py -c "import secrets; print(secrets.token_hex(32))"') do set SEARXNG_SECRET_KEY=%%i
    goto :key_generated
)

echo Error: Neither openssl nor python is available to generate a secret key.
echo Please install Python from https://python.org or OpenSSL
exit /b 2

:key_generated
echo Secret key generated successfully

call :ensure_docker
if not !ERRORLEVEL! == 0 (
    echo Error: Docker engine is not accessible from this shell.
    echo Please start Rancher Desktop or Docker Desktop and re-run this script.
    exit /b 3
)

if "%1"=="full" (
    docker compose up -d backend
    powershell -NoProfile -Command "Start-Sleep -Seconds 5" >nul 2>&1
    docker compose --profile full up
) else (
    docker compose --profile core up
)

exit /b 0

:ensure_docker
docker info >nul 2>&1
if %ERRORLEVEL% == 0 exit /b 0

call :start_container_engine
if not !ERRORLEVEL! == 0 exit /b 1

set "retries=120"
:wait_for_docker
docker info >nul 2>&1
if %ERRORLEVEL% == 0 exit /b 0
set /a retries-=1
if !retries! LEQ 0 exit /b 1
powershell -NoProfile -Command "Start-Sleep -Seconds 2" >nul 2>&1
goto :wait_for_docker

:start_container_engine
where rdctl >nul 2>&1
if %ERRORLEVEL% == 0 (
    echo Starting Rancher Desktop via rdctl...
    rdctl start >nul 2>&1
    if %ERRORLEVEL% == 0 exit /b 0
)

set "rancher_desktop="
if exist "%ProgramFiles%\Rancher Desktop\Rancher Desktop.exe" set "rancher_desktop=%ProgramFiles%\Rancher Desktop\Rancher Desktop.exe"
if not defined rancher_desktop if exist "%ProgramFiles(x86)%\Rancher Desktop\Rancher Desktop.exe" set "rancher_desktop=%ProgramFiles(x86)%\Rancher Desktop\Rancher Desktop.exe"
if defined rancher_desktop (
    echo Starting Rancher Desktop...
    start "" "%rancher_desktop%"
    exit /b 0
)

set "docker_desktop="
if exist "%ProgramFiles%\Docker\Docker\Docker Desktop.exe" set "docker_desktop=%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
if not defined docker_desktop if exist "%ProgramFiles(x86)%\Docker\Docker\Docker Desktop.exe" set "docker_desktop=%ProgramFiles(x86)%\Docker\Docker\Docker Desktop.exe"
if defined docker_desktop (
    echo Starting Docker Desktop...
    start "" "%docker_desktop%"
    exit /b 0
)

echo Rancher Desktop not found. Please install Rancher Desktop from https://rancherdesktop.io/
echo Docker Desktop not found. Please install Docker Desktop from https://www.docker.com/products/docker-desktop/
exit /b 1
