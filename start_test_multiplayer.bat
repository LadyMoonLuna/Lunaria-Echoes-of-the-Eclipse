@echo off
title Lunaria Online - Teste Multiplayer Local (Marco 3)
color 0A

echo ============================================================
echo   Lunaria Online - Inicializador de Teste Multiplayer (M3)
echo   Action Combat, 10 Fases da Lua & Relogio Assimetrico
echo ============================================================

:: 1. Encerra qualquer instancia anterior do servidor presa em segundo plano
echo [1/5] Encerrando instancias antigas do servidor...
taskkill /F /IM server.exe /T 2>nul

:: 2. Configura variaveis de ambiente
set "PATH=C:\Program Files\Go\bin;C:\Users\Lillyanne_Luna\AppData\Local\Programs\Godot;%PATH%"

set "GODOT_EXE=C:\Users\Lillyanne_Luna\AppData\Local\Programs\Godot\godot.exe"
if not exist "%GODOT_EXE%" (
    set "GODOT_EXE=godot"
)

:: 3. Recompila o executavel com o codigo mais recente
echo [2/5] Compilando versao mais recente de server.exe...
cd /d "%~dp0server"
go build -o server.exe ./cmd/server/main.go
if %ERRORLEVEL% neq 0 (
    echo [ERRO] Falha ao compilar server.exe. Abortando.
    pause
    exit /b %ERRORLEVEL%
)
cd /d "%~dp0"

:: 4. Inicia o servidor em janela de terminal visivel para exibir logs e Hot-Reload
echo [3/5] Iniciando Servidor Go em janela separada com logs ativos...
start "Lunaria Server (TCP:7000 / UDP:7001)" cmd /k "cd /d "%~dp0server" && server.exe"

:: 5. Aguarda 2 segundos para o servidor abrir as portas de rede
echo [4/5] Aguardando inicializacao dos sockets de rede (2s)...
timeout /t 2 /nobreak >nul

:: 6. Inicia 2 clientes Godot lado a lado (800x600 cada)
echo [5/5] Iniciando 2 instancias do Cliente Godot 4 lado a lado...
start "Lunaria Client 1" "%GODOT_EXE%" --path "%~dp0client" --windowed --resolution 800x600 --position 40,60
timeout /t 1 /nobreak >nul
start "Lunaria Client 2" "%GODOT_EXE%" --path "%~dp0client" --windowed --resolution 800x600 --position 860,60

echo ============================================================
echo   Ambiente pronto para testes do Marco 3!
echo   - LMB (Botao Esquerdo) = Ataque Basico autoritativo
echo   - Tecla Q = Habilidade Especial (1.75x dano)
echo   - 2 Bonecos de Treino (IDs 100 e 101) em (4, 4) e (4, 1)
echo   - Novos NPCs Vivos: Lyra (102), Varis (103) e Guardas da Patrulha Real (104, 105)
echo   - Tecla F6 = Avancar +6 Horas no Relogio Assimetrico
echo   - Tecla F7 = Ciclar 10 Fases da Lua (Nova -> Eclipse)
echo   - Tecla F8 = Ciclar 4 Climas (Limpo, Chuva, Neblina, Nevoa)
echo   - Tecla E = Falar com NPCs (Garrick, Lyra, Varis, Guardas)
echo   - Tecla K = Menu de Atributos | Tecla I = Inventario Anatômico
echo ============================================================
timeout /t 5 >nul
