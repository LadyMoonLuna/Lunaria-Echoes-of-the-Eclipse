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
| `0x30` | **TCP** | Cliente → Servidor | `SELECT_IDENTITY` | 7 bytes | Seleção de Raça e Classe do jogador | M3 |
| `0x31` | **UDP** | Cliente → Servidor | `PLAYER_ACTION` | 14 bytes | Ação de combate (Ataque, Esquiva, Skill Q) | M3 |
| `0x32` | **UDP** | Servidor → Clientes | `COMBAT_EVENT` | 17 bytes | Evento de dano, acerto crítico e HP do alvo | M3 |
| `0x33` | **UDP** | Servidor → Cliente | `PLAYER_STATS` | 15 bytes | Status sincronizados (HP, MaxHP, Stamina, MaxStamina) | M3 |


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
Enviado pelo cliente na conexão ou seleção de personagem para definir sua Raça e Classe.

- **Tamanho**: 7 bytes
- **Layout de Memória**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x30` |
  | `1` | `PlayerID` | `uint32` (LE) | 4 bytes | ID do jogador autenticado |
  | `5` | `RaceID` | `uint8` | 1 byte | `1`=Valeriano, `2`=Noctari, `3`=Kharad, `4`=Varkai, `5`=Dhampir |
  | `6` | `ClassID` | `uint8` | 1 byte | `1`=Espadachim, `2`=Batedor, `3`=Iniciado, `4`=Acólito |

---

### `0x31` — PLAYER_ACTION (UDP: Client → Server)
Enviado pelo cliente ao executar uma ação de combate físico em direção a um vetor de mira.

- **Tamanho**: 14 bytes
- **Layout de Memória**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x31` |
  | `1` | `PlayerID` | `uint32` (LE) | 4 bytes | ID do autor da ação |
  | `5` | `ActionType` | `uint8` | 1 byte | `1`=Ataque Básico, `2`=Esquiva (Dodge Roll), `3`=Habilidade Especial (Q) |
  | `6` | `AimDirX` | `float32` (LE) | 4 bytes | Vetor direcional X da mira |
  | `10` | `AimDirZ` | `float32` (LE) | 4 bytes | Vetor direcional Z da mira |

---

### `0x32` — COMBAT_EVENT (UDP: Server → Clients)
Difundido pelo servidor para notificar eventos de combate autoritativos, impacto de dano, críticos e HP atualizado do alvo.

- **Tamanho**: 17 bytes
- **Layout de Memória**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x32` |
  | `1` | `AttackerID` | `uint32` (LE) | 4 bytes | ID do atacante (Jogador ou Monstro) |
  | `5` | `TargetID` | `uint32` (LE) | 4 bytes | ID do alvo atingido (ex: `101`, `102` para Bonecos de Treino) |
  | `9` | `ActionType` | `uint8` | 1 byte | Tipo de ação causadora do dano |
  | `10` | `Damage` | `uint16` (LE) | 2 bytes | Quantidade final de dano calculada |
  | `12` | `IsCrit` | `uint8` | 1 byte | `1` se foi acerto crítico, `0` caso contrário |
  | `13` | `TargetHP` | `uint16` (LE) | 2 bytes | Vida restante do alvo após o dano |
  | `15` | `TargetMaxHP` | `uint16` (LE) | 2 bytes | Vida máxima do alvo atingido |

---

### `0x33` — PLAYER_STATS (UDP: Server → Client)
Transmitido autoritativamente para o cliente proprietário contendo seus status sincronizados de sobrevivência e combate.

- **Tamanho**: 15 bytes
- **Layout de Memória**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x33` |
  | `1` | `PlayerID` | `uint32` (LE) | 4 bytes | ID do jogador proprietário |
  | `5` | `RaceID` | `uint8` | 1 byte | Raça ativa |
  | `6` | `ClassID` | `uint8` | 1 byte | Classe ativa |
  | `7` | `HP` | `uint16` (LE) | 2 bytes | Vida atual |
  | `9` | `MaxHP` | `uint16` (LE) | 2 bytes | Vida máxima |
  | `11` | `Stamina` | `uint16` (LE) | 2 bytes | Estamina atual |
  | `13` | `MaxStamina` | `uint16` (LE) | 2 bytes | Estamina máxima |

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
Transmitido autoritativamente para todos os clientes exibirem o círculo de perigo telegrafado no chão antes de um golpe em área massivo (ex: martelo do Executor de Ferro).

- **Tamanho**: 19 bytes
- **Layout de Memória**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x34` |
  | `1` | `SourceID` | `uint32` (LE) | 4 bytes | ID da fonte do golpe (ex: Mob ID `206`) |
  | `5` | `PosX` | `float32` (LE) | 4 bytes | Centro do círculo X no mundo |
  | `9` | `PosZ` | `float32` (LE) | 4 bytes | Centro do círculo Z no mundo |
  | `13` | `Radius` | `float32` (LE) | 4 bytes | Raio da área de perigo em metros (ex: `4.0`) |
  | `17` | `DurationMs` | `uint16` (LE) | 2 bytes | Tempo até a detonação em milissegundos (ex: `1500`) |

---

## 8. Especificação dos Pacotes Binários do Sistema de Projéteis 3D

### `0x35` — PROJECTILE_SPAWN (UDP: Server → Clients)
Transmitido via UDP quando um jogador de classe à distância (Batedor ou Iniciado) dispara um ataque básico ou habilidade especial. Permite aos clientes renderizarem a trajetória 3D do projétil no espaço.

- **Tamanho**: 38 bytes
- **Layout de Memória**:
  | Offset | Campo | Tipo | Tamanho | Descrição |
  | :--- | :--- | :--- | :---: | :--- |
  | `0` | `PacketType` | `uint8` | 1 byte | Fixo: `0x35` |
  | `1` | `ProjectileID` | `uint32` (LE) | 4 bytes | ID sequencial único do projétil |
  | `5` | `OwnerID` | `uint32` (LE) | 4 bytes | ID do jogador atirador |
  | `9` | `ProjType` | `uint8` | 1 byte | `1`=Flecha, `2`=Flecha Perfurante, `3`=Orbe Arcano, `4`=Cometa Elemental |
  | `10` | `StartX` | `float32` (LE) | 4 bytes | Posição inicial no eixo X |
  | `14` | `StartY` | `float32` (LE) | 4 bytes | Posição inicial no eixo Y |
  | `18` | `StartZ` | `float32` (LE) | 4 bytes | Posição inicial no eixo Z |
  | `22` | `DirX` | `float32` (LE) | 4 bytes | Vetor de direção normalizado X |
  | `26` | `DirZ` | `float32` (LE) | 4 bytes | Vetor de direção normalizado Z |
  | `30` | `Speed` | `float32` (LE) | 4 bytes | Velocidade de deslocamento em m/s |
  | `34` | `MaxRange` | `float32` (LE) | 4 bytes | Alcance máximo em metros antes de dissipar |


