@echo off
title Lunaria Online - Servidor Autoritativo (Marco 3)
color 0B

echo ============================================================
echo   Lunaria Online - Servidor Autoritativo (Marco 3)
echo   Action Combat, 10 Fases da Lua & Relogio Assimetrico
echo   Portas: 7000 (TCP) e 7001 (UDP)
echo ============================================================

:: 1. Encerra qualquer instancia anterior do servidor
taskkill /F /IM server.exe /T 2>nul

:: 2. Configura o PATH da sessao
set "PATH=C:\Program Files\Go\bin;%PATH%"

:: 3. Entra na pasta do servidor e recompila com a versao mais recente
cd /d "%~dp0server"
echo [BUILD] Compilando versao mais recente do server.exe...
go build -o server.exe ./cmd/server/main.go
if %ERRORLEVEL% neq 0 (
    echo [ERRO] Falha ao compilar server.exe.
    pause
    exit /b %ERRORLEVEL%
)

:: 4. Executa o servidor autoritativo
echo [START] Executando servidor autoritativo...
server.exe

pause
