# 📜 Changelog do Projeto: Lunaria - Echoes of the Eclipse

Todas as alterações notáveis, arquiteturas e sistemas desenvolvidos desde o marco zero do projeto estão documentados neste arquivo.

---

## [Marco 1] — Arquitetura de Rede Híbrida & Sincronização Multiplayer 3D

- **Protocolo Binário Customizado de Baixa Latência (Little Endian):**
  - Implementação de serialização e deserialização pura em Go e GDScript (`StreamPeerBuffer`) eliminando overhead de JSON/strings na rede.
  - Separação em dois canais de comunicação:
    - **TCP (Porta 7000):** Eventos confiáveis, autenticação e transições de estado crítico.
      - `0x01` `WELCOME` (5 bytes): Envio do ID exclusivo do jogador pelo servidor.
      - `0x02` `PLAYER_DISCONNECTED` (5 bytes): Notificação de saída de jogadores para remoção limpa de nós.
    - **UDP (Porta 7001):** Fluxo contínuo de alta frequência com carimbo de sequência.
      - `0x10` `PLAYER_MOVE` (25 bytes): Envio da posição `(X, Y, Z)` e rotação `Y` pelo cliente a 20 Hz.
      - `0x11` `WORLD_SNAPSHOT` (6 bytes de cabeçalho + 20 bytes por jogador): Transmissão do estado de todos os jogadores conectados a 30 Hz.
- **Cliente Godot 4.3 3D:**
  - Configuração do `NetworkManager.gd` como Autoload com reconexão automática e polling não-bloqueante.
  - Implementação do nó `LocalPlayer` com movimentação em terceira pessoa, colisão por `CharacterBody3D`, suporte a câmera orbital com `SpringArm3D` e suavização.
  - Implementação de `RemotePlayer` com interpolação linear suave a `15x delta` eliminando micro-travamentos (*jitter*).
  - Scripts facilitadores para Windows: `start_server.bat` e `start_test_multiplayer.bat` (inicia servidor e duas instâncias de clientes).

---

## [Marco 2] — Motor de Scripting Lua, Hot-Reload & NPC Vivo (Garrick)

- **Integração com Gopher-Lua (`/server/internal/luaengine`):**
  - Incorporação do interpretador Lua em Go para governar comportamentos sem necessidade de recompilar o executável.
  - Sistema de **Hot-Reload:** Detecção de modificações em disco nos arquivos `.lua` e recarga transparente em tempo de execução com `sync.RWMutex`.
- **Protocolo de NPCs & Diálogos:**
  - `0x12` [UDP] `NPC_SNAPSHOT` (2 bytes + 17 bytes por NPC): Sincronização da posição, rotação e estado de animação/rotina a 30 Hz.
  - `0x20` [TCP] `PLAYER_INTERACT` (9 bytes): Envio de interação do jogador com um NPC via tecla `E`.
  - `0x21` [TCP] `NPC_SAY` (7 bytes + UTF-8 payload): Envio de falas e diálogos dinâmicos do NPC aos clientes.
- **NPC Garrick, o Ferreiro (`scripts/npcs/garrick.lua`):**
  - Rotina de patrulha e pontos de interesse (Forja da Vila e Taverna do Luar).
  - Máquina de estados com paradas para martelar bigorna, descanso e caminhada.
  - Detecção contínua de proximidade no raio de 4.0 metros com saudações contextuais.
  - Estruturas 3D procedurais da Vila: Forja com forno de pedra e labaredas emissivas, e Taverna com paredes rústicas e janelas iluminadas.

---

## [Marco 3] — Relógio Assimétrico, 10 Fases da Lua, Clima Dinâmico & Action Combat

- **Relógio Assimétrico do Mundo (80 min Dia / 40 min Noite):**
  - **Dia (06:00 às 17:59):** 80 minutos reais (1 hora do jogo = 400 segundos).
  - **Noite (18:00 às 05:59):** 40 minutos reais (1 hora do jogo = 200 segundos).
  - `0x13` [UDP/TCP] `WORLD_TIME` (5 bytes): Sincronização contínua de hora, minuto, fase lunar e tipo de clima.
  - `0x22` [TCP] `DEV_SKIP_TIME` (3 bytes): Atalhos de desenvolvedor para acelerar testes:
    - `F6`: Avança o relógio em +6 horas.
    - `F7`: Alterna sequencialmente entre as 10 Fases da Lua.
    - `F8`: Alterna entre os 4 Tipos de Clima.
- **Ciclo Completo de 10 Fases da Lua:**
  - 0: Lua Nova | 1: Lua Crescente | 2: Quarto Crescente | 3: Gibosa Crescente | 4: Lua Cheia
  - 5: Gibosa Minguante | 6: Quarto Minguante | 7: Lua Minguante | 8: LUA DE SANGUE | 9: ECLIPSE TOTAL
  - Iluminação dinâmica e shaders no Godot: Céu procedural, luz direcional com cor e energia adaptativas (azulado suave na lua cheia, carmesim profundo na lua de sangue e escuridão com névoa densa no eclipse).
- **Clima Dinâmico e Atmosférico:**
  - 0: Limpo | 1: Chuva (com partículas 3D no cliente) | 2: Neblina Densa | 3: Névoa Carmesim.
- **Action Combat System Governado por Lua (`scripts/combat/combat.lua`):**
  - Pacote `0x30` [TCP] `SELECT_IDENTITY`: Seleção de Raça e Classe.
  - Pacote `0x31` [UDP] `PLAYER_ACTION`: Despacho de Ataque Básico (LMB), Rolamento de Esquiva (Shift com i-frames) ou Habilidade Especial (Tecla Q).
  - Pacote `0x32` [UDP] `COMBAT_EVENT`: Transmissão de dano, status de acerto crítico, HP e MaxHP atualizados.
  - Pacote `0x33` [UDP] `PLAYER_STATS`: Sincronização de atributos em tempo real.
  - Bonecos de Treino (`Dummy 101` e `Dummy 102`) com exibição de dano flutuante e feedback de impacto.

---

## [Marco 4] — Ecossistema Vivo: 5 Mobs Táticos & Telegrafia de Área (AoE Telegraph)

- **IA Tática dos Mobs em Lua (`scripts/mobs/mobs_ai.lua`):**
  1. **Lobo da Bruma (`MobType = 1`):** Caçador veloz em matilha, salta no alvo e ganha bônus de ferocidade sob Lua Cheia ou Lua de Sangue.
  2. **Saqueador Deserdado (`MobType = 2`):** Guerreiro com postura defensiva de escudo (bloqueia 50% de todo dano frontal).
  3. **Besteiro da Vigília (`MobType = 3`):** Atirador tático de longo alcance (15m) que recua (*kite*) quando o jogador se aproxima a menos de 4m.
  4. **Acólito do Eclipse (`MobType = 4`):** Suporte sombrio que cura periodicamente outros mobs feridos no raio de 12m com canalização mágica.
  5. **Executor de Ferro (`MobType = 5`):** Mini-boss pesado que carrega um golpe sísmico por 1.5s, cria área de dano telegrafada no chão e fica vulnerável por 2.0s com a maça presa ao solo.
- **Rede & Telegrafia de Área:**
  - `0x14` [UDP] `MOB_SNAPSHOT` (2 bytes + 26 bytes por Mob vivo): Sincronização completa de posição, HP, estado e rotação a 30 Hz.
  - `0x34` [UDP] `AOE_TELEGRAPH` (19 bytes): Transmissão de círculos vermelhos de perigo projetados no solo com interpolação de expansão e duração precisa.
- **Comportamento Sistêmico de Defesa da Vila:**
  - O ferreiro Garrick agora empunha seu martelo de guerra e ataca ativamente mobs invasores que se aproximam da Vila, retornando à sua forja após neutralizar a ameaça.
  - Sistema de morte, respawn automático em 10 segundos e regeneração de vida ao retornar ao spawn.

---

## [Marco 5] — Armas à Distância, Projéteis 3D Reais, Atributos Raciais & Menu de Identidade

- **Simulação Física de Projéteis 3D no Servidor (30 Hz):**
  - Implementação de `ProjectileManager` em Go com verificação de colisão esférica contínua contra Bonecos de Treino e Mobs no raio de 1.1m.
  - `0x35` [UDP] `PROJECTILE_SPAWN` (38 bytes): Transmissão do projétil, velocidade, direção e alcance máximo para todos os clientes renderizarem trajetórias fluidas.
  - **Flecha Física (Batedor - Ataque Básico):** Velocidade 24 m/s, alcance 16m.
  - **Flecha Perfurante (Batedor - Skill Q):** Velocidade 30 m/s, alcance 22m, **atravessa múltiplos inimigos** sem ser consumida.
  - **Orbe Arcano (Iniciado - Ataque Básico):** Velocidade 18 m/s, alcance 14m, projétil luminoso de energia arcana.
  - **Cometa Elemental (Iniciado - Skill Q):** Velocidade 20 m/s, alcance 16m, detona ao colidir gerando **onda de choque em área de 2.8m de raio**.
- **Modelos Visuais de Armas Diferenciados:**
  - **Espadachim:** Espada longa de aço prateado com brilho ciano + Escudo kite com brasão azul e borda dourada.
  - **Batedor:** Arco de Caça recurvo animado com puxada elástica da corda e recuo de disparo.
  - **Iniciado:** Cajado rúnico de madeira nobre com orbe cristalino pulsante e luz dinâmica.
  - **Acólito:** Maça flangeada pesada de ouro maciço + Talismã sagrado luminoso flutuando na mão esquerda.
- **Mira Precisa e Crosshair (`LocalPlayer.gd`):**
  - Cálculo de mira ótica projetando a direção da câmera no plano XZ com rotação instantânea do personagem ao atacar.
  - Crosshair discreto (`+`) centralizado na tela ativado durante a captura do cursor.
- **Atributos Calibrados por Raça e Classe:**
  - **Classes Base:**
    - Espadachim: `HP = 140`, `Stamina = 100` (Corpo-a-corpo 3.8m).
    - Batedor: `HP = 105`, `Stamina = 135` (À distância 16.0m).
    - Iniciado: `HP = 95`, `Stamina = 110` (Mágico 14.0m).
    - Acólito: `HP = 125`, `Stamina = 105` (Médio alcance 4.5m + Cura de +40 HP no Q).
  - **Modificadores Raciais:**
    - Valeriano: `+10 HP`, `+10 Stamina`, `+15%` de regeneração de stamina.
    - Noctari: `+0 HP`, `+20 Stamina`, bônus lunares de crítico e dano.
    - Kharad: `+30 HP`, `+0 Stamina`, reduz 20% de todo dano recebido de mobs (*Postura de Rocha*).
    - Varkai: `+15 HP`, `+10 Stamina`, `+20%` de dano quando HP <= 35% (*Sangue Fervilhante*).
    - Dhampir: `+10 HP`, `+15 Stamina`, cura `+8 HP` por golpe com lifesteal.
- **Reatividade Racial nos Diálogos do NPC Garrick:**
  - Garrick reconhece a raça e classe de cada jogador ao interagir (oferece desconto a irmãos Kharad, demonstra fascínio pelos Noctari, adverte a agressividade de Varkais e recua com aversão perante o sangue dos Dhampirs).
- **Menu Visual de Seleção de Raça e Classe (`CharacterSelectUI.gd`):**
  - Interface rica com bordas douradas e estilo medieval escuro.
  - Abre automaticamente ao iniciar a sessão e pode ser aberto/fechado a qualquer momento com as teclas **`C` ou `Tab`**.
  - Duas colunas com cartões interativos, painel de resumo dinâmico das estatísticas totais combinadas e botão de confirmação que transmite a identidade ao servidor.
