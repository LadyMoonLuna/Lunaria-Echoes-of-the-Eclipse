# Modelos 3D das Raças

Modelos low-poly procedurais das raças lendárias (IDs 19–28), montados com primitivas do Godot.
Nenhum asset precisa ser importado: o cliente constrói o personagem em tempo de execução.

| Arquivo | Função |
| :--- | :--- |
| `tools/race_models/races.py` | **Fonte** dos modelos (uma função por raça) |
| `tools/race_models/modelkit.py` | Kit de modelagem: primitivas, espelhamento, correntes, pivôs animados |
| `tools/race_models/build.py` | Gera os dados para o Godot e o preview web |
| `client/scripts/models/RaceModelData.gd` | Dados gerados (não editar à mão) |
| `client/scripts/models/RaceModel.gd` | Construtor e animação em tempo real (Godot) |
| `client/scenes/RacePreview.tscn` | Vitrine das raças dentro do Godot (F6) |
| `docs/previews/racas_3d_preview.html` | Preview web interativo com os mesmos dados |

## Regerar após editar

```bash
python3 tools/race_models/build.py
```

## Usar no jogo

`LocalPlayer` e `RemotePlayer` já trocam a cápsula pelo modelo quando a raça tem um modelo.
Para usar em outro lugar (NPC, tela de seleção):

```gdscript
const RaceModel = preload("res://scripts/models/RaceModel.gd")

var modelo := RaceModel.create(22) as RaceModel   # Draconato de Cinzas
add_child(modelo)                                 # pés na origem, olhando para -Z
modelo.set_move_speed(velocity.length())          # balanço de caminhada
```

## Convenções

- Y para cima, frente em −Z, lado direito do personagem = +X, rotações em graus (Euler YXZ).
- Grupos `leg_l/leg_r/arm_l/arm_r` recebem a animação de caminhada.
- Animações de grupo: `spin`, `sway`, `bob`, `pulse`. Animações de material: `glow`, `flicker`.
