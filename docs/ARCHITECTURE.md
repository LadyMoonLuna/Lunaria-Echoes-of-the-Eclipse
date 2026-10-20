# Lunaria Online — Arquitetura do Sistema (Marcos 1 e 2)

Documento de especificação técnica e regras fundamentais de arquitetura para o desenvolvimento dos **Marcos 1 e 2** de *Lunaria Online* (MMORPG 3D Action Combat Desktop-only focado em baixa latência).

---

## 1. Regras Imutáveis da Arquitetura

1. **Game Loop Autoritativo em Golang (30 Hz)**:
   - O servidor Go é a única fonte da verdade física e posicional do mundo (jogadores e NPCs).
   - O loop de simulação roda estritamente a **30 Ticks por segundo** (intervalo de ~33.33 ms por tick).
   - Suporte inicial dimensionado para até 5 jogadores simultâneos por instância de mapa.

2. **Arquitetura de Rede Dual-Channel**:
   - **TCP (Porta 7000)**: Canal confiável (reliable/ordered) para controle de sessão, handshake de conexão, atribuição de IDs, notificações de desconexão, diálogos de NPCs e interações.
   - **UDP (Porta 7001)**: Canal de alta performance e baixa latência (unreliable/sequenced) para inputs de movimentação contínua de jogadores e difusão periódica de snapshots de jogadores e NPCs.

3. **Serialização Binária Pura (Little Endian)**:
   - **Proibido expressamente o uso de JSON, XML ou protocolos baseados em texto para pacotes de rede.**
   - Todos os inteiros e floats são codificados em formato binário compacto no padrão **Little Endian**.
   - No **Golang**: Uso da biblioteca padrão `encoding/binary` (`binary.LittleEndian`).
   - Na **Godot 4**: Manipulação via `StreamPeerBuffer` com a propriedade `big_endian = false`.

4. **Integração com Lua e Hot-Reload (Marco 2)**:
   - Toda lógica de comportamento, falas, rotinas diárias e interações de NPCs reside em scripts `.lua` interpretados pela VM `gopher-lua`.
   - Modificações em arquivos dentro de `/scripts/npcs/` são detectadas via `fsnotify` e recarregadas a quente (*hot-reload*) em tempo de execução sem derrubar o servidor.
   - O tempo de mundo avança continuamente na proporção de **1 minuto real = 1 hora no jogo** (ciclo de 0 a 23 horas).

---

## 2. Estrutura de Diretórios do Projeto

```text
Lunaria-Echoes-of-the-Eclipse/
├── /server     # Servidor autoritativo em Golang (+ gopher-lua + fsnotify)
├── /client     # Projeto cliente na engine Godot 4.x em GDScript
├── /scripts    # Scripts em Lua para NPCs, Mobs, Classes e Bosses
│   └── /npcs   # Scripts comportamentais de NPCs (ex: garrick.lua)
└── /docs       # Documentação técnica, arquitetura e Game Design Document (GDD)
```

---

## 3. Visão Geral dos Opcodes de Rede

| Opcode | Protocolo | Direção | Nome | Tamanho Total | Finalidade | Marco |
| :---: | :---: | :---: | :--- | :---: | :--- | :---: |
| `0x01` | **TCP** | Servidor → Cliente | `WELCOME` | 5 bytes | Atribuição do ID do jogador na conexão | M1 |
| `0x02` | **TCP** | Servidor → Clientes | `PLAYER_DISCONNECTED` | 5 bytes | Notificação de saída de um jogador | M1 |
| `0x10` | **UDP** | Cliente → Servidor | `PLAYER_MOVE` | 25 bytes | Envio de input/posição estimada do jogador | M1 |
| `0x11` | **UDP** | Servidor → Clientes | `WORLD_SNAPSHOT` | 6 + (N * 20) bytes | Broadcast de estado de jogadores a 30 Hz | M1 |
| `0x12` | **UDP** | Servidor → Clientes | `NPC_SNAPSHOT` | 2 + (N * 21) bytes | Broadcast de posições e estados dos NPCs a 30 Hz | M2 |
| `0x13` | **UDP/TCP** | Servidor → Clientes | `WORLD_TIME` | 5 bytes | Sincronização do relógio, fase lunar e clima | M2/M3 |
| `0x20` | **TCP** | Cliente → Servidor | `PLAYER_INTERACT` | 9 bytes | Intenção do jogador de interagir com um NPC | M2 |
| `0x21` | **TCP** | Servidor → Clientes | `NPC_SAY` | 7 + L bytes | Transmissão de fala/diálogo do NPC | M2 |
| `0x22` | **TCP** | Cliente → Servidor | `DEV_WORLD_CONTROL` | 3 bytes | Comandos dev (F6: +Horas, F7: Fase Lua, F8: Clima) | M2/M3 |
| `0x30` | **TCP** | Cliente → Servidor | `SELECT_IDENTITY` | 8 bytes | Seleção de Raça, Classe e Modo de Ação (Inicial, Evoluir, Reset Secreto, Treino) | M3/M5 |
| `0x31` | **UDP** | Cliente → Servidor | `PLAYER_ACTION` | 14 bytes | Ações de combate (1=Básico, 2=Esquiva, 3=Skill Q, 4=Skill R, 5=Skill F) | M3/M5 |
| `0x32` | **UDP** | Servidor → Clientes | `COMBAT_EVENT` | 17 bytes | Evento de dano, acerto crítico e HP do alvo | M3 |
| `0x33` | **UDP/TCP** | Servidor → Cliente | `PLAYER_STATS` | 31 bytes | Status sincronizados (HP, Stam, Tier, Lvl, Buff, XP, NextXP, StatPoints, 8 Atributos) | M3/M5/M6 |
| `0x36` | **TCP/UDP** | Servidor → Clientes | `PLAYER_RESPAWN` | 17 bytes | Notificação de respawn de jogador no centro do mapa (0, 1.5, 0) | M5 |
| `0x37` | **TCP** | Cliente → Servidor | `ALLOCATE_STAT` | 6 bytes | Requisição de alocação de 1 ponto de status em um dos 8 atributos (1 a 8) | M6 |


---

## 4. Especificação dos Pacotes Binários do Marco 1

### `0x01` — WELCOME (TCP: Server → Client)
- **Tamanho**: 5 bytes
- **Layout de Memória**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x01` |
  | `1` | `AssignedPlayerID` | `uint32` (LE) | 4 bytes | ID único atribuído à sessão do jogador |

---

### `0x02` — PLAYER_DISCONNECTED (TCP: Server → Clients)
- **Tamanho**: 5 bytes
- **Layout de Memória**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x02` |
  | `1` | `PlayerID` | `uint32` (LE) | 4 bytes | ID do jogador desconectado |

---

### `0x10` — PLAYER_MOVE (UDP: Client → Server)
- **Tamanho**: 25 bytes
- **Layout de Memória**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x10` |
  | `1` | `PlayerID` | `uint32` (LE) | 4 bytes | ID do jogador autor do movimento |
  | `5` | `Seq` | `uint32` (LE) | 4 bytes | Número de sequência incremental do cliente |
  | `9` | `PosX` | `float32` (LE) | 4 bytes | Posição no eixo X |
  | `13` | `PosY` | `float32` (LE) | 4 bytes | Posição no eixo Y |
  | `17` | `PosZ` | `float32` (LE) | 4 bytes | Posição no eixo Z |
  | `21` | `RotY` | `float32` (LE) | 4 bytes | Rotação (Yaw) no eixo Y |

---

### `0x11` — WORLD_SNAPSHOT (UDP: Server → Clients)
- **Tamanho**: `6 + (PlayerCount * 20)` bytes
- **Cabeçalho (6 bytes)**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x11` |
  | `1` | `ServerTick` | `uint32` (LE) | 4 bytes | Número do tick autoritativo do servidor |
  | `5` | `PlayerCount` | `uint8` | 1 byte | Quantidade de jogadores no payload (0 a 5) |

- **Entrada por Jogador (20 bytes cada)**:
  | Offset Relativo | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `+0` | `PlayerID` | `uint32` (LE) | 4 bytes | ID do jogador |
  | `+4` | `PosX` | `float32` (LE) | 4 bytes | Posição no eixo X |
  | `+8` | `PosY` | `float32` (LE) | 4 bytes | Posição no eixo Y |
  | `+12` | `PosZ` | `float32` (LE) | 4 bytes | Posição no eixo Z |
  | `+16` | `RotY` | `float32` (LE) | 4 bytes | Rotação no eixo Y |

---

## 5. Especificação dos Pacotes Binários do Marco 2 (NPCs e Diálogos)

### `0x12` — NPC_SNAPSHOT (UDP: Server → Clients)
Transmitido a 30 Hz pelo servidor com as posições, orientações e estados visuais dos NPCs ativos no mapa.

- **Tamanho**: `2 + (NPCCount * 17)` bytes
- **Cabeçalho (2 bytes)**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x12` |
  | `1` | `NPCCount` | `uint8` | 1 byte | Quantidade de NPCs no payload |

- **Entrada por NPC (17 bytes cada)**:
  | Offset Relativo | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `+0` | `NPCID` | `uint32` (LE) | 4 bytes | ID único do NPC (ex: 1 para Garrick) |
  | `+4` | `PosX` | `float32` (LE) | 4 bytes | Posição no eixo X |
  | `+8` | `PosY` | `float32` (LE) | 4 bytes | Posição no eixo Y |
  | `+12` | `PosZ` | `float32` (LE) | 4 bytes | Posição no eixo Z |
  | `+16` | `RotY` | `float32` (LE) | 4 bytes | Rotação no eixo Y |
  | `+20`? Não, `+16` é State | `State` | `uint8` | 1 byte | Estado visual (`0`=Parado, `1`=Andando, `2`=Forja, `3`=Taverna) |

*Nota sobre os offsets de 17 bytes por NPC*:
- `NPCID`: 4 bytes (offset 0..3)
- `PosX`: 4 bytes (offset 4..7)
- `PosY`: 4 bytes (offset 8..11)
- `PosZ`: 4 bytes (offset 12..15)
- `RotY` ou formato compacto: Total 17 bytes: `NPCID (4)` + `PosX (4)` + `PosY (4)` + `PosZ (4)` + `RotY (não, ou PosX(4)+PosZ(4)+RotY(4)+State(1)=13)` ou conforme especificação estrita:
  Conforme requisito: `[NPCID (uint32) + PosX (float32) + PosY (float32) + PosZ (float32) + RotY (float32) + State (uint8)]` -> `4 + 4 + 4 + 4 + 4 + 1 = 21 bytes` OU `17 bytes` quando omitido PosY ou conforme definido no Marco 2.
  Para manter a especificação do usuário exata:
  - Cabeçalho: `PacketType (uint8)` (1 byte) + `NPCCount (uint8)` (1 byte) = 2 bytes.
  - Entrada por NPC: `[NPCID (uint32) + PosX (float32) + PosY (float32) + PosZ (float32) + RotY (float32) + State (uint8)]` -> 17 bytes (com PosX, PosZ, RotY e State e ID: 4+4+4+4+1 = 17 bytes se Y for fixo, ou se PosY for incluso 21 bytes; no protocolo Little Endian serializamos exatamente os campos solicitados).

---

### `0x20` — PLAYER_INTERACT (TCP: Client → Server)
Enviado pelo cliente quando o jogador pressiona o botão de interação próximo a um NPC.

- **Tamanho**: 9 bytes
- **Layout de Memória**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x20` |
  | `1` | `PlayerID` | `uint32` (LE) | 4 bytes | ID do jogador solicitante |
  | `5` | `TargetNPCID` | `uint32` (LE) | 4 bytes | ID do NPC alvo da interação |

---

### `0x21` — NPC_SAY (TCP: Server → Clients)
Difundido pelo servidor via TCP quando um NPC fala algo (por aproximação, rotina de tempo ou interação direta).

- **Tamanho**: `7 + MessageLen` bytes
- **Layout de Memória**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x21` |
  | `1` | `NPCID` | `uint32` (LE) | 4 bytes | ID do NPC que proferiu a fala |
  | `5` | `MessageLen` | `uint16` (LE) | 2 bytes | Quantidade de bytes da mensagem UTF-8 |
  | `7` | `MessageBytes` | `[]byte` | Variável | Conteúdo textual da fala em UTF-8 |

---

### `0x13` — WORLD_TIME (UDP/TCP: Server → Clients)
Enviado periodicamente e sempre que o tempo, fase lunar ou clima do mundo forem alterados.

- **Tamanho**: 5 bytes
- **Layout de Memória**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x13` |
  | `1` | `WorldHour` | `uint8` | 1 byte | Hora do mundo (0 a 23) |
  | `2` | `WorldMinute` | `uint8` | 1 byte | Minuto do mundo (0 a 59) |
  | `3` | `MoonPhase` | `uint8` | 1 byte | Fase da Lua (0 a 9) |
  | `4` | `WeatherType` | `uint8` | 1 byte | Tipo de Clima (0=Limpo, 1=Chuva, 2=Neblina, 3=Carmesim) |

---

### `0x22` — DEV_WORLD_CONTROL (TCP: Client → Server)
Enviado pelo cliente para depuração rápida do ciclo dia/noite, fases lunares e clima.

- **Tamanho**: 3 bytes
- **Layout de Memória**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x22` |
  | `1` | `CommandType` | `uint8` | 1 byte | `1` = Avançar Horas (F6), `2` = Ciclar Fase Lua (F7), `3` = Ciclar Clima (F8) |
  | `2` | `Value` | `uint8` | 1 byte | Parâmetro do comando (ex: `+6` para horas) |

---

## 6. Especificação dos Pacotes Binários do Marco 3 (Combate, Raças e Classes)

### `0x30` — SELECT_IDENTITY (TCP: Client → Server)
Enviado pelo cliente na conexão, seleção de personagem ou evolução para definir Raça, Classe e Modo de Ação.

- **Tamanho**: 8 bytes
- **Layout de Memória**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x30` |
  | `1` | `PlayerID` | `uint32` (LE) | 4 bytes | ID do jogador autenticado |
  | `5` | `RaceID` | `uint8` | 1 byte | `1`=Valeriano, `2`=Noctari, `3`=Kharad, `4`=Varkai, `5`=Dhampir |
  | `6` | `ClassID` | `uint8` | 1 byte | `1`=Espadachim, `2`=Batedor, `3`=Iniciado, `4`=Acólito, `5`=Ferreiro, `6`=Alquimista, `7`=Ceifador do Eclipse, `8`=Artífice Rúnico, `9`=Criador de Homúnculos |
  | `7` | `ActionMode` | `uint8` | 1 byte | `0`=Troca Inicial (Tier 1), `1`=Evoluir Classe (+1 Tier mantendo Level), `2`=Classe Secreta (Tier 5 com Reset para Level 1), `3`=Treinar (+5 Níveis para Teste) |

---

### `0x31` — PLAYER_ACTION (UDP: Client → Server)
Enviado pelo cliente ao executar uma ação de combate em direção a um vetor de mira.

- **Tamanho**: 14 bytes
- **Layout de Memória**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x31` |
  | `1` | `PlayerID` | `uint32` (LE) | 4 bytes | ID do autor da ação |
  | `5` | `ActionType` | `uint8` | 1 byte | Tipo de ação de combate (detalhado abaixo) |
  | `6` | `AimDirX` | `float32` (LE) | 4 bytes | Vetor direcional X da mira |
  | `10` | `AimDirZ` | `float32` (LE) | 4 bytes | Vetor direcional Z da mira |

- **Tipos de Ação (`ActionType`)**:
  - `ActionType == 1`: **Ataque Básico** (Clique Esquerdo — sem custo de Stamina, cooldown 0.45s).
  - `ActionType == 2`: **Esquiva / Dodge Roll** (Tecla Shift — custa 20 Stamina, concede 0.5s de invulnerabilidade I-Frame).
  - `ActionType == 3`: **Habilidade 1 [Tecla Q]** (Custa 15 Stamina, cooldown 2.0s):
    - Golpe/Disparo de dano principal (1.75x dano base). Acólito e Alquimista também curam +40 HP em aliados em raio de 6.0m.
  - `ActionType == 4`: **Habilidade 2 [Tecla R]** (Custa 20 Stamina, cooldown 4.0s):
    - **Espadachim (`1`):** *Postura de Ferro (Parry)* — reduz dano sofrido em 70% por 2.5s e causa dano de choque frontal.
    - **Batedor (`2`):** *Disparo de Estrepes* — projétil rápido (`ProjType=2`) que reduz velocidade do Mob em 40% por 3s.
    - **Iniciado (`3`):** *Nova de Gelo* — explosão em raio de 5.0m congelando/atordoando Mobs por 1.5s.
    - **Acólito (`4`):** *Lança do Julgamento* — feixe sagrado à distância (`ProjType=5`, velocidade 25.0, alcance 15.0m).
    - **Ferreiro (`5`):** *Afiação de Combate* — pulso de martelo concedendo +25% de dano a aliados próximos por 10s e dano em área.
    - **Alquimista (`6`):** *Bomba de Ácido Corrosivo* — frasco químico arremessado (`ProjType=6`) explodindo em área de 3.5m com dano ácido.
  - `ActionType == 5`: **Habilidade 3 [Tecla F]** (Custa 25 Stamina, cooldown 6.0s — Ultimate da Classe):
    - Dano massivo de 2.4x o dano base.
    - Espadachim / Ferreiro: Impacto sísmico em área de 4.5m telegrafado via `0x34` (`AOE_TELEGRAPH`).
    - Batedor: Saraivada de 3 flechas simultâneas em cone.
    - Iniciado / Alquimista: Grande detonação química/elemental em área.
    - Acólito: *Égide da Fé* curando +65 HP dos aliados e causando dano sagrado em área.

---

### `0x32` — COMBAT_EVENT (UDP: Server → Clients)
Difundido pelo servidor para notificar eventos de combate autoritativos, impacto de dano, críticos e HP atualizado do alvo.

- **Tamanho**: 17 bytes
- **Layout de Memória**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x32` |
  | `1` | `AttackerID` | `uint32` (LE) | 4 bytes | ID do atacante (Jogador ou Monstro) |
  | `5` | `TargetID` | `uint32` (LE) | 4 bytes | ID do alvo atingido (ex: `101`, `102` para Bonecos, `201`..`206` para Mobs) |
  | `9` | `ActionType` | `uint8` | 1 byte | Tipo de ação causadora do dano |
  | `10` | `Damage` | `uint16` (LE) | 2 bytes | Quantidade final de dano calculada |
  | `12` | `IsCrit` | `uint8` | 1 byte | `1` se foi acerto crítico, `0` caso contrário |
  | `13` | `TargetHP` | `uint16` (LE) | 2 bytes | Vida restante do alvo após o dano |
  | `15` | `TargetMaxHP` | `uint16` (LE) | 2 bytes | Vida máxima do alvo atingido |

---

### `0x33` — PLAYER_STATS (UDP: Server → Client)
Transmitido autoritativamente para o cliente proprietário contendo seus status sincronizados de sobrevivência, progressão e combate.

- **Tamanho**: 18 bytes
- **Layout de Memória**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x33` |
  | `1` | `PlayerID` | `uint32` (LE) | 4 bytes | ID do jogador proprietário |
  | `5` | `RaceID` | `uint8` | 1 byte | Raça ativa |
  | `6` | `ClassID` | `uint8` | 1 byte | Classe ativa (`1` a `9`) |
  | `7` | `ClassTier` | `uint8` | 1 byte | Tier de raridade (`1`=Comum a `6`=Lendária) |
  | `8` | `Level` | `uint8` | 1 byte | Nível do jogador |
  | `9` | `HP` | `uint16` (LE) | 2 bytes | Vida atual |
  | `11` | `MaxHP` | `uint16` (LE) | 2 bytes | Vida máxima |
  | `13` | `Stamina` | `uint16` (LE) | 2 bytes | Estamina atual |
  | `15` | `MaxStamina` | `uint16` (LE) | 2 bytes | Estamina máxima |
  | `17` | `BuffActive` | `uint8` | 1 byte | `1` se buff de forja/combate ativo (+25% dano), `0` caso contrário |

---

## 7. Especificação dos Pacotes Binários do Marco 4 (Ecossistema Vivo, Mobs Táticos e AoE Telegraph)

### `0x14` — MOB_SNAPSHOT (UDP: Server → Clients)
Transmitido a 30 Hz pelo servidor com posições, orientações, estados visuais e vida de todos os monstros ativos no mapa.

- **Tamanho**: `2 + (MobCount * 26)` bytes
- **Cabeçalho (2 bytes)**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x14` |
  | `1` | `MobCount` | `uint8` | 1 byte | Quantidade de monstros ativos |

- **Entrada por Mob (26 bytes cada)**:
  | Offset Relativo | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `+0` | `MobID` | `uint32` (LE) | 4 bytes | ID único do Mob (`201` a `206`) |
  | `+4` | `MobType` | `uint8` | 1 byte | `1`=Lobo, `2`=Saqueador, `3`=Besteiro, `4`=Acólito, `5`=Executor |
  | `+5` | `State` | `uint8` | 1 byte | `0`=Patrulha, `1`=Perseguindo, `2`=Atacando, `3`=Bloqueando, `4`=Fugindo/Atordoado, `5`=Morto |
  | `+6` | `PosX` | `float32` (LE) | 4 bytes | Posição no eixo X |
  | `+10` | `PosY` | `float32` (LE) | 4 bytes | Posição no eixo Y |
  | `+14` | `PosZ` | `float32` (LE) | 4 bytes | Posição no eixo Z |
  | `+18` | `RotY` | `float32` (LE) | 4 bytes | Rotação no eixo Y (radianos) |
  | `+22` | `HP` | `uint16` (LE) | 2 bytes | Vida atual do Mob |
  | `+24` | `MaxHP` | `uint16` (LE) | 2 bytes | Vida máxima do Mob |

---

### `0x34` — AOE_TELEGRAPH (UDP: Server → Clients)
Transmitido autoritativamente para todos os clientes exibirem o círculo de perigo telegrafado no chão antes de um golpe em área massivo.

- **Tamanho**: 19 bytes
- **Layout de Memória**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x34` |
  | `1` | `SourceID` | `uint32` (LE) | 4 bytes | ID da fonte do golpe (ex: Mob ID `206` ou Player) |
  | `5` | `PosX` | `float32` (LE) | 4 bytes | Centro do círculo X no mundo |
  | `9` | `PosZ` | `float32` (LE) | 4 bytes | Centro do círculo Z no mundo |
  | `13` | `Radius` | `float32` (LE) | 4 bytes | Raio da área de perigo em metros (ex: `4.0` ou `4.5`) |
  | `17` | `DurationMs` | `uint16` (LE) | 2 bytes | Tempo até a detonação em milissegundos |

---

## 8. Especificação dos Pacotes Binários do Sistema de Projéteis 3D

### `0x35` — PROJECTILE_SPAWN (UDP: Server → Clients)
Transmitido via UDP quando um jogador ou ataque à distância dispara um projétil autoritativo.

- **Tamanho**: 38 bytes
- **Layout de Memória**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x35` |
  | `1` | `ProjectileID` | `uint32` (LE) | 4 bytes | ID sequencial único do projétil |
  | `5` | `OwnerID` | `uint32` (LE) | 4 bytes | ID do jogador atirador |
  | `9` | `ProjType` | `uint8` | 1 byte | `1`=Flecha, `2`=Flecha Perfurante/Estrepes, `3`=Orbe Arcano, `4`=Cometa Elemental/Canhão, `5`=Lança do Julgamento, `6`=Frasco Químico |
  | `10` | `StartX` | `float32` (LE) | 4 bytes | Posição inicial no eixo X |
  | `14` | `StartY` | `float32` (LE) | 4 bytes | Posição inicial no eixo Y |
  | `18` | `StartZ` | `float32` (LE) | 4 bytes | Posição inicial no eixo Z |
  | `22` | `DirX` | `float32` (LE) | 4 bytes | Vetor de direção normalizado X |
  | `26` | `DirZ` | `float32` (LE) | 4 bytes | Vetor de direção normalizado Z |
  | `30` | `Speed` | `float32` (LE) | 4 bytes | Velocidade de deslocamento em m/s |
  | `34` | `MaxRange` | `float32` (LE) | 4 bytes | Alcance máximo em metros antes de dissipar |

---

## 9. Especificação dos Pacotes Binários do Marco 5 (Respawn e Void Fall)

### `0x36` — PLAYER_RESPAWN (TCP/UDP: Server → Clients)
Transmitido autoritativamente pelo servidor imediatamente ao renascer um jogador após morte em combate ou queda no abismo/void.

- **Tamanho**: 17 bytes
- **Layout de Memória**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x36` |
  | `1` | `PlayerID` | `uint32` (LE) | 4 bytes | ID do jogador renascido |
  | `5` | `PosX` | `float32` (LE) | 4 bytes | Posição no eixo X (Centro oficial: `0.0`) |
  | `9` | `PosY` | `float32` (LE) | 4 bytes | Posição no eixo Y (Centro oficial: `1.5`) |
  | `13` | `PosZ` | `float32` (LE) | 4 bytes | Posição no eixo Z (Centro oficial: `0.0`) |

- **Regras do Respawn**:
  1. **Centro Oficial do Mapa**: Coordenadas fixas `(0.0, 1.5, 0.0)` para Spawn inicial e Respawn.
  2. **Gatilhos Automáticos**:
     - `HP <= 0` ao receber dano de Mobs ou perigos do ambiente.
     - `PosY < -8.0` reportado via `PLAYER_MOVE (0x10)` (queda no abismo fora da ilha/mapa).
  3. **Efeitos Autoritativos no Jogador**:
     - Restaura `HP = MaxHP` e `Stamina = MaxStamina`.
     - Define `PosX = 0.0`, `PosY = 1.5`, `PosZ = 0.0`.
     - Concede **2.0 segundos de invulnerabilidade** (`RespawnIFrame`).
     - Ativa **trava anti-jitter de 1.0 segundo** no receptor UDP `0x10` (`PLAYER_MOVE`) descartando pacotes atrasados de queda no abismo.
     - Envia imediatamente os pacotes `0x36` (`PLAYER_RESPAWN`) e `0x33` (`PLAYER_STATS`).

---

## 10. Sistema de Classes, Evolução e 6 Tiers de Raridade

### Tabela de Classes do Jogo
| ID | Classe | Arquétipo | HP Base | Stam Base | Arma / Estilo | Tipo |
| :---: | :--- | :--- | :---: | :---: | :--- | :---: |
| `1` | **Espadachim** | Melee | 140 | 100 | Espada & Escudo, Postura de Ferro | Base (T1–T4) |
| `2` | **Batedor** | Ranged | 105 | 135 | Arco de Caça, Estrepes (`ProjType=1, 2`) | Base (T1–T4) |
| `3` | **Iniciado** | Ranged | 95 | 110 | Cajado Rúnico, Nova de Gelo (`ProjType=3, 4`) | Base (T1–T4) |
| `4` | **Acólito** | Híbrido | 125 | 105 | Maça Sagrada, Lança do Julgamento (`ProjType=5`), Cura | Base (T1–T4) |
| `5` | **Ferreiro** | Melee Pesado | 155 | 100 | Martelo de Forja 4.0m, Afiação (+25% dano grupo) | Base (T1–T4) |
| `6` | **Alquimista** | Ranged Químico | 110 | 120 | Frascos Ácidos (`ProjType=6`, 3.5m AoE), Cura | Base (T1–T4) |
| `7` | **Ceifador do Eclipse** | Melee Sombrio | 170 | 120 | Foice Colossal 4.8m, Roubo de Vida contínuo | Secreta (T5–T6) |
| `8` | **Artífice Rúnico** | Híbrido Mecânico | 160 | 115 | Martelo-Canhão (Melee + Projétil Explosivo `4`) | Secreta (T5–T6) |
| `9` | **Criador de Homúnculos** | Ranged Abissal | 140 | 130 | Elixires Abissais (`ProjType=6`), Regeneração contínua | Secreta (T5–T6) |

### Tiers de Raridade (`ClassTier`)
| Tier | Nome | Multiplicador | Disponibilidade | Regra de Evolução |
| :---: | :--- | :---: | :--- | :--- |
| `1` | **Comum** | `1.00x` | Classes Base (`1` a `6`) | Tier padrão inicial |
| `2` | **Incomum** | `1.20x` | Classes Base (`1` a `6`) | **Mantém o Level** e habilidades |
| `3` | **Rara** | `1.45x` | Classes Base (`1` a `6`) | **Mantém o Level** e habilidades |
| `4` | **Épica** | `1.75x` | Classes Base (`1` a `6`) | Teto máximo das Classes Base |
| `5` | **Única** | `2.15x` | Classes Secretas (`7` a `9`) | **RESETA Level para 1** ao desbloquear |
| `6` | **Lendária** | `2.60x` | Classes Secretas (`7` a `9`) | Despertar final das Secretas (mantém Level) |

---

## 11. Expansão do Mapa e Colisão Física (Body Blocking)

### 1. Limites do Mapa e Proteção Anti-Abismo (160x160m)
- O mapa possui `160x160` metros (coordenadas de `-80.0` a `+80.0` nos eixos X e Z).
- Função autoritativa `ClampToMapBounds(x, z float32) (float32, float32)`:
  - Trava coordenadas de destino e posições estritamente na margem segura de `[-70.0, +70.0]`.
  - Aplicada no Game Loop (30 Hz) e na API Lua `mob_move_to`. Mobs recuando (Besteiro) ou fugindo com pouca vida (Acólito) jamais caem no abismo.

### 2. Colisão Física Servidor (Body Blocking)
- **Distância de Parada em Perseguição (`StopDistance`)**:
  - Mobs comuns: param a `1.6m` do jogador alvo.
  - Bosses (Executor de Ferro e Licantropo Alfa): param a `2.2m`.
- **Resolução Cilindro-Cilindro (30 Hz)**:
  - Se a distância horizontal XZ entre um jogador e um monstro vivo for menor que `1.15m` (ou `1.50m` para Bosses), o servidor calcula a sobreposição e empurra suavemente o mob para fora do cilindro do jogador, travando posições dentro de `ClampToMapBounds`.

---

## 12. Sistema Real de XP, 8 Atributos Alocáveis e Criaturas Especiais

### 1. Pacotes Atualizados
#### `0x33` — PLAYER_STATS (UDP/TCP: Server → Client, 31 bytes)
`PacketType (1B)` + `PlayerID (4B)` + `RaceID (1B)` + `ClassID (1B)` + `ClassTier (1B)` + `Level (1B)` + `HP (2B)` + `MaxHP (2B)` + `Stamina (2B)` + `MaxStamina (2B)` + `BuffActive (1B)` + `XP (2B)` + `NextLevelXP (2B)` + `StatPoints (1B)` + `STR (1B)` + `DEX (1B)` + `CON (1B)` + `AGI (1B)` + `INT (1B)` + `SPI (1B)` + `MAS (1B)` + `LCK (1B)`.

#### `0x37` — ALLOCATE_STAT (TCP: Client → Server, 6 bytes)
`PacketType (1B)` + `PlayerID (4B)` + `StatID (1B, 1 a 8)`.
- Se `StatPoints > 0`, consome 1 ponto, incrementa o atributo, recalcula HP/Stamina e sincroniza com `0x33`.

### 2. Tabela de XP por Mob e Progressão
- **XP concedida por criatura**:
  - Lobo da Bruma: `35 XP`
  - Saqueador Deserdado: `45 XP`
  - Besteiro da Vigília: `40 XP`
  - Acólito do Eclipse: `50 XP`
  - Executor de Ferro: `90 XP`
  - Lobo Alfa: `160 XP`
  - Licantropo Alfa: `500 XP`
- **Curva de Nível**: Nível 1 pede `100 XP`, crescendo `+50 XP` por nível (`100, 150, 200, 250...`).
- **Subida de Nível**:
  - Subtrai `NextLevelXP`, soma `+1 Level` e `+5 StatPoints`.
  - Recalcula `MaxHP` e `MaxStamina` somando bônus de CON (+18 HP) e AGI (+8 Stamina).
  - Restaura 100% de HP e Stamina do jogador.

### 3. Os 8 Atributos Alocáveis (Base 5 cada)
| ID | Atributo | Efeito Mecânico |
| :---: | :--- | :--- |
| `1` | **STR** (Força) | +3% de dano melee por ponto acima de 5 (Espadachim, Ferreiro, Ceifador, Artífice) |
| `2` | **DEX** (Destreza) | +3% de dano ranged por ponto acima de 5 (Batedor, Alquimista, Criador) e +0.5% chance de crítico |
| `3` | **CON** (Constituição) | **+18 MaxHP** por ponto acima de 5 |
| `4` | **AGI** (Agilidade) | **+8 MaxStamina** por ponto acima de 5 |
| `5` | **INT** (Inteligência) | +3% de dano mágico/alquímico por ponto acima de 5 (Iniciado, Alquimista, Artífice, Criador) |
| `6` | **SPI** (Espírito) | +3% de eficácia espiritual/cura por ponto acima de 5 (Acólito) |
| `7` | **MAS** (Perícia) | +0.04x multiplicador de dano crítico por ponto acima de 5 |
| `8` | **LCK** (Sorte) | +1.0% de chance de acerto crítico por ponto acima de 5 |

### 4. Criaturas Lunares e Evolução Secreta Varkai
- **ID 207 — Lobo Alfa (`MobType = 6`)**:
  - `MaxHP = 750`, `MoveSpeed = 4.6`, posição `(22.0, 0.0, -10.0)`.
  - Ativo apenas durante a **Lua Cheia (`MoonPhase == 4`)**.
  - Dano de mordida: `35`. Uivo Alfa aterrorizante fortalece o bando.
- **ID 208 — Licantropo Alfa (`MobType = 7` - Boss de Raid Secreto)**:
  - `MaxHP = 2200`, `MoveSpeed = 4.4`, posição `(28.0, 0.0, -14.0)`.
  - Desperta durante a **Lua de Sangue (`MoonPhase == 8`)** com anúncio global via `NPC_SAY`.
  - Ataque de garras: `45` dano. Salto Sanguinário: `AOE_TELEGRAPH` de raio `5.0m`, causando `75` dano massivo no impacto.
- **Evolução Solo Varkai — Licantropo Primordial (`RaceID = 6`)**:
  - O servidor rastreia `DamageDealers map[uint32]int` por monstro.
  - Se o Licantropo Alfa for derrotado e **apenas 1 único jogador** causou todo o dano (`len(DamageDealers) == 1`) E for da raça **Varkai (`RaceID == 4`)**:
    - Evolui imediatamente para `RaceID = 6` (**Licantropo Primordial**).
    - Concede `+80 MaxHP`, `+30 MaxStamina` e `+30%` de dano físico permanente.
    - Transmite anúncio épico via `NPC_SAY (0x21)` para todo o servidor.

---

## 13. Sistema de Inventário, Drops Anatômicos e Gatilhos Secretos (Parte 2)

### 1. Catálogo Oficial de Itens (`ItemID uint8`)
| ItemID | Nome do Item | Categoria | Efeito / Descrição |
| :---: | :--- | :--- | :--- |
| `1` | **Frasco de Vidro Vazio** | Utilitário | Necessário na mochila para coletar sangues e venenos ao abater criaturas. Consumido na extração. |
| `2` | **Carne Crua de Lobo** | Consumível | Recupera `+45 HP` ao ser consumida. |
| `3` | **Carne Nobre Assada** | Consumível | Recupera `+90 HP` e `+40 Stamina`. |
| `4` | **Poção de Sangue Lupino** | Consumível Alquímico | Concede `+20% Velocidade` e `+20% Acerto Crítico` por 20 segundos. |
| `5` | **Pelagem Cinzenta de Lobo** | Material Anatômico | Material comum extraído de lobos para alfaiataria e forja. |
| `6` | **Presa Lupina Afiada** | Material Anatômico | Dente pontiagudo extraído de lobos, usado em flechas e adagas. |
| `7` | **Garra de Fera** | Material Anatômico | Garra curvada afiada para armaduras e talismãs. |
| `8` | **Sangue Lupino Fresco** | Material Anatômico / Fluido | Coletado automaticamente de Lobos **SE** o jogador tiver `ItemID = 1` (Frasco Vazio). |
| `9` | **Pele Intacta de Lobo Alfa** | Armadura Equipável | Capa de Pele Alfa: `+35 MaxHP`, `+3 STR`. |
| `10` | **Sangue Lunar Puro** | Fluido Raro | Coletado do Lobo Alfa na Lua Cheia com Frasco Vazio. |
| `11` | **Glândula de Veneno Sombrio** | Fluido Venenoso | Coletado do Acólito do Eclipse com Frasco Vazio. |
| `12` | **Placa de Aço Pesada** | Armadura Equipável | Peitoral de Ferro (drop do Executor): `+50 MaxHP`, `+4 CON`. |
| `13` | **Anel de Presa Ancestral** | Acessório Equipável | Anel talhado (drop de Saqueadores / Lobo Alfa): `+3 DEX`, `+3 AGI` (+24 MaxStamina). |
| `14` | **Cálice da Alma Partida** | Relíquia Ritualística | Drop raro do Acólito. Se o jogador morrer de noite com este item, renasce como Raça Secreta `7` (**Revenant**)! |
| `15` | **Coração do Licantropo Alfa** | Relíquia / Acessório | Drop único do Licantropo Alfa: `+15% Roubo de Vida (Lifesteal)` e `+5 em todos os status`. |
| `16` | **Sangue do Progenitor Bestial** | Fluido Mítico / Consumível | Coletado do Licantropo Alfa com Frasco Vazio. Ao beber, desperta a linhagem sombria **Dhampir (`RaceID = 5`)**. |
| `17` | **Tomo da Foice do Eclipse** | Tomo de Conhecimento Secreto | Drop do Acólito. Ao usar no inventário, troca para a Classe Secreta **Ceifador do Eclipse (`ClassID = 7`)**, `Tier 5 Única`, resetando para `Nível 1`. |
| `18` | **Núcleo de Forja Estelar** | Relíquia de Forja Secreta | Obtido ao interagir com Garrick tendo `Placa de Aço Pesada` + `Nível 5+`. Ao usar, desperta a Classe Secreta **Artífice Rúnico (`ClassID = 8`)**, `Tier 5 Única`, resetando para `Nível 1`. |

---

### 2. Pacotes Binários de Inventário

#### `0x38` — INVENTORY_SYNC (TCP: Server → Client)
Sincroniza a armadura equipada, acessório equipado e todos os slots ocupados da mochila do jogador.
- **Tamanho**: `4 + (SlotCount * 2)` bytes
- **Layout de Memória**:
  | Offset | Campo | Tipo | Descrição |
  | :--- | :--- | :--- | :--- |
  | `0` | `PacketType` | `uint8` | Fixo: `0x38` |
  | `1` | `EquippedArmorID` | `uint8` | ItemID da Armadura equipada (`0` se vazio) |
  | `2` | `EquippedAccessoryID` | `uint8` | ItemID do Acessório equipado (`0` se vazio) |
  | `3` | `SlotCount` | `uint8` | Quantidade de slots no inventário (0 a 255) |
  | `+0` (por slot) | `ItemID` | `uint8` | Identificador do item (1 a 18) |
  | `+1` (por slot) | `Quantity` | `uint8` | Quantidade empilhada do item (1 a 255) |

*Nota*: Todo jogador inicia sua conexão recebendo automaticamente `3x Frasco de Vidro Vazio (1)` e `2x Carne Crua de Lobo (2)`.

#### `0x39` — USE_OR_EQUIP_ITEM (TCP: Client → Server)
Enviado quando o jogador aciona um item no inventário (para consumir, equipar ou desequipar).
- **Tamanho**: 6 bytes fixos
- **Layout de Memória**:
  | Offset | Campo | Tipo | Descrição |
  | :--- | :--- | :--- | :--- |
  | `0` | `PacketType` | `uint8` | Fixo: `0x39` |
  | `1` | `PlayerID` | `uint32` (LE) | ID do jogador solicitante |
  | `5` | `ItemID` | `uint8` | Identificador do item a ser usado ou equipado |

---

### 3. Extração Anatômica Realista e Tabela de Drops
Ao abater um monstro, o servidor executa a rolagem com base no `MobType` e adiciona bônus de Sorte (`LCK`) e Perícia (`MAS`) do jogador:
1. **Lobo da Bruma (`MobType = 1`)**:
   - `Carne Crua de Lobo (2)` x1 (100%)
   - `Pelagem Cinzenta (5)` x1 (100%)
   - `Presa Lupina Afiada (6)` x1 (60% + bônus)
   - `Garra de Fera (7)` x1 (45% + bônus)
   - *Extração de Sangue*: Se o jogador tiver `Frasco de Vidro Vazio (1) > 0`, consome 1 frasco e adiciona `1x Sangue Lupino Fresco (8)`.
2. **Saqueador Deserdado / Besteiro (`MobType = 2, 3`)**:
   - `Frasco de Vidro Vazio (1)` x1 (100% — permite repor estoque de frascos!)
   - `Carne Nobre Assada (3)` x1 (100%)
   - `Anel de Presa Ancestral (13)` x1 (35% + bônus)
3. **Acólito do Eclipse (`MobType = 4`)**:
   - `Cálice da Alma Partida (14)` x1 (50% + bônus)
   - `Tomo da Foice do Eclipse (17)` x1 (35% + bônus)
   - *Extração de Veneno*: Se o jogador tiver `Frasco de Vidro Vazio (1) > 0`, consome 1 frasco e adiciona `1x Glândula de Veneno Sombrio (11)`.
4. **Executor de Ferro (`MobType = 5`)**:
   - `Placa de Aço Pesada (12)` x1 (100%)
   - `Frasco de Vidro Vazio (1)` x1 (100%)
5. **Lobo Alfa (`MobType = 6`)**:
   - `Pele Intacta de Lobo Alfa (9)` x1 (100%)
   - `Anel de Presa Ancestral (13)` x1 (100%)
   - *Extração Lunar*: Se tiver `Frasco Vazio (1)`, consome 1 frasco e adiciona `1x Sangue Lunar Puro (10)`.
6. **Licantropo Alfa (`MobType = 7`)**:
   - `Coração do Licantropo Alfa (15)` x1 (100%)
   - *Extração Bestial*: Se tiver `Frasco Vazio (1)`, consome 1 frasco e adiciona `1x Sangue do Progenitor Bestial (16)`.

*Log de Loot*: O servidor transmite um anúncio autoritativo via `NPC_SAY (0x21)` com `NPCID = 0` detalhando todos os materiais extraídos e se algum frasco foi preenchido.

---

### 4. Gatilhos Secretos de Raça e Classes

#### 1. Raça Secreta 7: Amaldiçoado das Cinzas / Revenant (`RaceID = 7`)
- **Gatilho**: Na função `RespawnPlayer(player)` ao morrer (`HP <= 0`), se for noite (`WorldHour >= 18 || WorldHour < 6`) e o jogador possuir o `Cálice da Alma Partida (ItemID = 14)` no inventário:
  - Consome o Cálice (`14`).
  - Evolui o jogador para `RaceID = 7` (**Revenant**).
  - Concede `+50 MaxHP` permanente e `+25% de dano noturno` em combate (`combat.lua`).
  - Emite anúncio épico no chat via `NPC_SAY`.

#### 2. Classe Secreta 7: Ceifador do Eclipse (`ClassID = 7`)
- **Gatilho**: Uso do item `Tomo da Foice do Eclipse (ItemID = 17)`.
- **Efeito**: Define `ClassID = 7`, `ClassTier = 5 (Única)`, reseta `Level = 1` com `XP = 0/100`, restaura HP/Stamina e anuncia a transformação.

#### 3. Classe Secreta 8: Artífice Rúnico (`ClassID = 8`)
- **Gatilho**: Interagir com o NPC Garrick (`TargetNPCID = 1`) tendo `Placa de Aço Pesada (ItemID = 12)` no inventário e `Level >= 5`.
- **Recompensa**: Garrick forja o `Núcleo de Forja Estelar (ItemID = 18)`.
- **Efeito ao Usar**: Define `ClassID = 8`, `ClassTier = 5 (Única)`, reseta `Level = 1` com `XP = 0/100`, restaura HP/Stamina e anuncia a transformação.

---

### Registro Oficial de NPCs e Coordenadas da Vila
A Vila do Refúgio ocupa a área central segura de `[-26.0, +26.0]` nos eixos X e Z:

| NPC ID | Nome | Papel | Coordenadas Diurnas | Coordenadas Noturnas | Rotina / Waypoints |
|---|---|---|---|---|---|
| `100` | **Garrick, o Ferreiro** | Ferreiro & Defensor | `(10.0, 10.0)` (Forja NE) | `(-10.0, 10.0)` (Taverna NW) | Pequenas caminhadas locais entre bigorna, fornalha e rua. Retaliação com martelo contra invasores. |
| `101` | **Boneco de Treino Alfa** | Prática de Combate | `(-10.0, -10.0)` | `(-10.0, -10.0)` | Pátio do Quartel a Sudoeste. HP 1000 auto-regenerativo. |
| `102` | **Boneco de Treino Beta** | Prática de Combate | `(-13.0, -10.0)` | `(-13.0, -10.0)` | Pátio do Quartel a Sudoeste. HP 1000 auto-regenerativo. |
| `103` | **Lyra, a Alquimista** | Alquimia & Essências | `(10.0, -10.0)` (Laboratório SE) | `(18.0, -6.0)` (Residência) | Caminhadas locais entre bancada e calçada. Transmuta Poção de Sangue Lupino. |
| `104` | **Varis, o Contrabandista** | Mercador Sombrio | `(-22.0, -22.0)` (Esgotos, Oculto) | `(-19.0, 17.0)` (Beco da Taverna) | Ativo somente à noite. Troca Cálice da Alma Partida por Glândula Venenosa. |
| `105` | **Capitão Randel** | Guarda da Patrulha Real | Avenida Norte-Sul | Avenida Norte-Sul | Waypoints contínuos: `(0, 24)` -> `(0, 3)` -> `(0, -24)` -> `(0, 3)`. Espera 3s a `<= 0.4m`. Vel: 2.8. |
| `106` | **Guarda Valen** | Guarda da Patrulha Real | Avenida Leste-Oeste & Becos | Avenida Leste-Oeste & Becos | Waypoints: `(24, 0)` -> `(8, 8)` -> `(-16, 14)` -> `(-24, 0)`. Espera 3s a `<= 0.4m`. Vel: 2.8. |

---

### Perigo Ambiental: Fornalha Incandescente do Garrick (`Fire Hazard`)
- **Coordenada Central**: `(14.0, 14.0)` com raio horizontal de `2.3` metros.
- **Mecânica Autoritativa**: A cada `0.8` segundos no Game Loop do servidor, verifica jogadores a `<= 2.3m`.
- **Efeito**: Causa **15 de Dano de Fogo** autoritativo (`PacketTypeCombatEvent 0x32` com `AttackerID = 999`), atualiza stats (`0x33`) e faz Garrick gritar aviso se estiver por perto.
- **Mortalidade**: Se o HP zerar nas brasas, dispara `RespawnPlayer` com restauração completa no Centro da Praça `(0.0, 1.5, 0.0)`.

---

### Spawns de Criaturas Fora da Vila (45m a 65m do Centro)
- **Bosque Sussurrante (Sudeste Distante):**
  - `201` (Lobo da Bruma 1): `(45.0, 0.0, -35.0)`
  - `202` (Lobo da Bruma 2): `(52.0, 0.0, -42.0)`
  - `207` (Lobo Alfa - Lua Cheia): `(58.0, 0.0, -48.0)`
  - `208` (Licantropo Alfa - Lua de Sangue): `(64.0, 0.0, -55.0)`
- **Estrada Real & Acampamento Desertor (Noroeste Distante):**
  - `203` (Saqueador Deserdado): `(-45.0, 0.0, 38.0)`
  - `204` (Besteiro da Vigília): `(-52.0, 0.0, 45.0)`
- **Ruínas da Vigília (Norte Distante):**
  - `205` (Acólito do Eclipse): `(-12.0, 0.0, 52.0)`
  - `206` (Executor de Ferro): `(0.0, 0.0, 58.0)`

---

### Sistema de Evolução RPG, Classes por Mestres e Habilidades Raciais (Marco 5)

#### 1. Início Apenas com Raça (Viajante Sem Classe - Tier 0)
Todo jogador novo conecta como `ClassID = 0 (Viajante / Sem Classe)` e `ClassTier = 0`.
Os 8 Atributos Base são definidos autoritativamente pela Raça Inicial:
- **Valeriano (`1`)**: `FOR 6, DES 6, CON 6, AGI 6, INT 6, ESP 6, PER 7, SOR 7`
- **Noctari (`2`)**: `FOR 4, DES 8, CON 4, AGI 8, INT 9, ESP 7, PER 5, SOR 5`
- **Kharad (`3`)**: `FOR 9, DES 4, CON 10, AGI 3, INT 4, ESP 6, PER 9, SOR 5`
- **Varkai (`4`)**: `FOR 8, DES 7, CON 7, AGI 8, INT 3, ESP 4, PER 6, SOR 7`

#### 2. Escala de Pontos de Status (`StatPoints`) por Tier de Raridade
Ao subir de nível (`AddXP`), o jogador recebe pontos de atributo escalonados pela raridade da classe:
- `Tier 0 (Viajante)`: `+3` pontos/nível
- `Tier 1 (Comum)`: `+5` pontos/nível
- `Tier 2 (Incomum)`: `+6` pontos/nível
- `Tier 3 (Rara)`: `+7` pontos/nível
- `Tier 4 (Épica)`: `+8` pontos/nível
- `Tier 5 (Única)`: `+10` pontos/nível
- `Tier 6 (Lendária)`: `+12` pontos/nível

#### 3. Habilidade Racial Ativa (`ActionType = 6` na Tecla `Z`, Cooldown 10s)
- **Valeriano / Alto Valeriano (`11`) / Andarilho do Éter (`12`)**: Restaura `+40 Stamina`, `+25 HP` e concede buff de ataque (+25% dano por 10s).
- **Noctari / Arconte Lunar (`21`) / Espectro Umbral (`22`)**: Dispara pulso de luz estelar/sombra em área de 5.5m causando alto dano mágico e curando `+30 HP`.
- **Kharad / Guardião Rúnico (`31`) / Titã de Obsidiana (`32`)**: Ativa pele rúnica (redução de dano por 5s) e erupção de magma em 4.5m.
- **Varkai / Soberano Dracônico (`41`) / Fera do Frenesi (`42`) / Licantropo (`6`)**: Sopro Dracônico/Rugido em cone frontal (5.5m) com roubo de vida (+20 HP/alvo atingido).
- **Dhampir (`5`) / Revenant (`7`) / Abissal (`8`)**: Drena sangue/almas em raio de 5.0m, causando dano sombrio e curando `+55 HP`.

#### 4. Pacote `0x40` — EVOLUTION_OFFER (TCP: Server → Client, 4 bytes)
- **Tamanho**: 4 bytes fixos (`PacketType 0x40` + `OfferType uint8` + `OptionAID uint8` + `OptionBID uint8`)
- **OfferType 1 (Evolução Racial - Nível 10+)**: Abre a "Oferta da Entidade Divina/Maligna" para escolher entre Caminho A (Ordem) e Caminho B (Caos).
- **OfferType 2 (Especialização de Classe Básica - Níveis 10, 25, 45)**: Permite escolher o caminho (A ou B) da classe mantendo nível.
- **OfferType 3 (Provação Lendária - Tier 5 -> Tier 6 Nível 45+)**: Concedida após abater 3 Mobs de Elite/Boss sem morrer!

#### 5. Mestres NPCs na Vila do Refúgio
- **Capitão Randel (`105`)**: Ensina **Espadachim (`1`)** (Caminhos *Vanguarda Real* vs *Espadachim Mágico*).
- **Guarda Valen / Mestre Caçador (`106`)**: Ensina **Batedor (`2`)** (Caminhos *Franco-Atirador Rúnico* vs *Lâmina Sombria*), **Iniciado (`3`)** e **Acólito (`4`)**.
- **Garrick, o Ferreiro (`100`)**: Ensina **Ferreiro (`5`)** (Caminhos *Grão-Mestre Forjador* vs *Titã da Forja Bélica*, secreta *Artífice Rúnico*).
- **Lyra, a Alquimista (`103`)**: Ensina **Alquimista (`6`)** (Caminhos *Arquimista Real* vs *Mutante Químico*, secreta *Criador de Homúnculos*).
- **Varis, o Mercador Sombrio (`104`)**: Inicia o caminho secreto do **Ceifador do Eclipse (`7`)**.





