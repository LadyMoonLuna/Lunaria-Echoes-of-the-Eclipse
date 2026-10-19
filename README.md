# 🌙 Lunaria: Echoes of the Eclipse

> **MMORPG 3D de Ação Multiplayer** com arquitetura de servidor de alto desempenho em **Golang**, cliente em **Godot 4**, motor de lógica e balanceamento em **Lua**, e combate dinâmico influenciado pelas **10 Fases da Lua e Clima**.

---

## 🌟 Visão Geral da Arquitetura

O projeto foi construído do zero com foco em desempenho, separação estrita de responsabilidades e hot-reload de lógica de jogo:

```
[ Cliente Godot 4.3 ]
     │ (TCP: 7000) ── Handshake, Diálogos, Identidade, Eventos Confiáveis
     │ (UDP: 7001) ── Snapshots 30 Hz (Players, Mobs, Projéteis, AoE Telegraphs)
     ▼
[ Servidor Golang ]
     ├── World Engine (Game Loop 30 Hz, Relógio Assimétrico, Simulação Física de Projéteis)
     ├── Protocol (Serialização Binária Little Endian de Baixa Latência)
     └── Lua Engine (Gopher-Lua: IA de Mobs, Comportamento de NPCs e Fórmulas de Combate com Hot-Reload)
```

---

## ⚔️ Funcionalidades Principais

- **Rede Híbrida de Baixa Latência (Little Endian):** Pacotes binários puros sem overhead de JSON, com interpolação suave a 15x delta no cliente.
- **Relógio Assimétrico do Mundo:** 80 minutos reais de Dia (06:00 às 17:59) e 40 minutos de Noite (18:00 às 05:59).
- **Ciclo Completo de 10 Fases da Lua & Clima Dinâmico:** Da Lua Nova ao Cataclismo do Eclipse Total e Lua de Sangue, impactando diretamente o dano, críticos e poderes arcanos.
- **Action Combat Dinâmico & Projéteis 3D Reais:**
  - Espadachim (Espada & Escudo) e Acólito (Maça & Talismã) com ataques instantâneos em arco.
  - Batedor (Arco de Caça) e Iniciado (Cajado Rúnico) com projéteis físicos simulados a 30 Hz no servidor (flechas perfurantes e cometas mágicos com explosão em área).
- **5 Raças e 4 Classes Jogáveis:** Valeriano, Noctari, Kharad, Varkai e Dhampir (secreta), cada uma com passivas, atributos de HP/Stamina e estilo de jogo únicos.
- **Ecossistema Vivo e Mobs Táticos:** Mobs com IA comportamental via Lua (matilha de lobos, saqueadores com bloqueio de escudo, besteiros com kite, acólitos curandeiros e o temível Executor de Ferro com ataques sísmicos telegrafados no solo).
- **NPCs Vivos e Reatividade Racial:** Garrick, o Ferreiro patrulha a vila, defende o vilarejo de invasores e altera suas falas e relações de acordo com a raça e classe de cada aventureiro.
- **Menu Visual de Identidade (Tecla `C` ou `Tab`):** Interface modal medieval com seleção interativa de linhagem e vocação.

---

## 🎮 Controles do Jogo

| Tecla / Ação | Função |
| :--- | :--- |
| **W, A, S, D** | Movimentação 3D do personagem |
| **Mouse (Girar)** | Rotação orbital da câmera em terceira pessoa |
| **Botão Esquerdo (LMB)** | Ataque Básico (Espada, Arco, Orbe ou Maça) |
| **Tecla Q** | Habilidade Especial de Classe |
| **Shift** | Rolamento de Esquiva (Dodge Roll com i-frames) |
| **Barra de Espaço** | Pulo |
| **Tecla E** | Interagir / Conversar com NPCs próximos |
| **Tecla C ou Tab** | Abrir/Fechar Menu Visual de Seleção de Raça e Classe |
| **Teclas 1 a 4** | Atalho rápido de troca de Classe |
| **Teclas F1 a F5** | Atalho rápido de troca de Raça |
| **Tecla F6** | Avançar tempo do mundo em +6 horas (Dev Control) |
| **Tecla F7** | Ciclar entre as 10 Fases da Lua (Dev Control) |
| **Tecla F8** | Ciclar entre os 4 Tipos de Clima (Dev Control) |
| **ESC** | Liberar / Capturar cursor do mouse |

---

## 🚀 Como Executar

### 1. Iniciar o Servidor
Execute na raiz do projeto:
```cmd
start_server.bat
```
*(Ou acesse `/server` e execute `go run ./cmd/server/main.go`)*

### 2. Iniciar o Cliente
Abra o projeto da pasta `/client` na **Godot 4.3** e aperte F5.

Para testar **dois jogadores simultâneos no mesmo computador**, execute na raiz:
```cmd
start_test_multiplayer.bat
```

---

## 📚 Documentação Adicional
- [Documento de Arquitetura de Rede e Protocolo](docs/ARCHITECTURE.md)
- [Changelog Completo de Desenvolvimento](CHANGELOG.md)
