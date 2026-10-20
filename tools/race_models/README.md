# Modelos 3D de Lunaria

Todos os modelos seguem o **Guia de Direção de Arte (Art Bible)** e são low-poly e procedurais: cada um é descrito
em Python como um conjunto de primitivas com pivôs animáveis. Um único build gera três saídas idênticas entre si:

| Saída | Uso |
| :--- | :--- |
| `client/scripts/models/LunariaModelData.gd` | Dados lidos por `LunariaModel.gd`. O jogo monta tudo em tempo de execução, sem importar assets |
| `client/assets/models/**/*.glb` | glTF binário para Blender, Mixamo ou importação direta no Godot (inclui os 20 clipes) |
| `docs/previews/racas_3d_preview.html` | Preview web interativo |

## O que existe

| Tipo | Quantidade | Fonte |
| :--- | :--- | :--- |
| Raças 1–18 (base, evoluções e secretas) | 18 | `races_base.py` |
| Raças lendárias 19–28 | 10 | `races.py` |
| NPCs (Garrick 100, Lyra 103, Varis 104, Randel 105, Valen 106, Alquimista Fantasma 107) | 6 | `npcs.py` |
| Armas (pivô na empunhadura, +Y ao longo da lâmina) + Mini-Homúnculo | 16 + 1 | `gear.py` |
| Trajes das classes 0–9 | 10 | `gear.py` |
| Clipes de animação | 20 | `clips.py` |

Os números de raça seguem os IDs do servidor (`server/internal/protocol/packets.go`): no Art Bible o Sylvari aparece
como “11”, mas no jogo ele é a raça 19, e assim por diante até o Cronomante (28).

## Regerar depois de editar

```bash
python3 tools/race_models/build.py          # tudo
python3 tools/race_models/build.py --no-glb # só dados do jogo e preview (mais rápido)
```

## Usar no Godot

`LocalPlayer`, `RemotePlayer` e `NPCEntity` já usam os modelos: a cápsula é trocada pelo corpo da raça (ou do NPC),
a classe veste o traje e coloca as armas nas mãos, e as ações tocam os clipes (ataque, esquiva, Q, R, F e Z).

```gdscript
const LunariaModel = preload("res://scripts/models/LunariaModel.gd")

var heroi := LunariaModel.create_race(22, 1)   # Draconato de Cinzas, Espadachim
add_child(heroi)                               # pés na origem, olhando para -Z
heroi.set_move_speed(velocity.length())        # idle / walk / run misturados pela velocidade
heroi.play_action(1)                           # 1=básico 2=esquiva 3=Q 4=R 5=F 6=Z
heroi.play("kneel_autopsy")                    # clipe em loop até stop_override()
heroi.play("death_fall", true)                 # mantém o último quadro (cadáver)

var garrick := LunariaModel.create_npc(100)
var espada := LunariaModel.create("weapon_knight_longsword")
heroi.get_anchor("hand_r").add_child(espada)   # âncoras: hand_r, hand_l, back
```

A vitrine `client/scenes/RacePreview.tscn` (F6) mostra raças, NPCs e armas, troca a classe (C) e toca os clipes (A).

## Convenções

- Y para cima, frente em −Z, lado direito do personagem = +X, pés em Y = 0, rotações em graus (Euler YXZ).
- Pivôs do esqueleto: `pose` (corpo inteiro, a 0,6 m), `torso` (quadril), `arm_l/arm_r` (ombros), `leg_l/leg_r` (quadril).
- Trajes são escritos para um corpo de largura 1,0; o cliente escala o eixo X pela `body_w` de cada raça.
- Animações de pivô: `spin`, `sway`, `bob`, `pulse`. Animações de material: `glow`, `flicker`.

## Clipes

`idle`, `walk`, `run`, `dodge_roll`, `attack_1h`, `attack_2h_heavy`, `attack_2h_sweep`, `attack_bow`, `attack_cast`,
`attack_throw`, `skill_q`, `skill_q_support`, `skill_r_shield`, `skill_r_sharpen`, `skill_r_backflip`, `skill_f_spin`,
`skill_f_slam`, `skill_z`, `kneel_autopsy`, `death_fall`. Cada classe mapeia suas ações para eles em `LOADOUTS` (`gear.py`).
