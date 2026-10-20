# Arte 3D de Lunaria — do prompt ao jogo

O estilo-alvo é **anime heroico de fantasia sombria** (inspirado em *Sword Art Online* e na série *Fate*):
traços expressivos, texturas detalhadas, cel-shading e iluminação de alto nível.

O jogo já roda com modelos procedurais (montados por código) em estilo anime: sombra em faixas, luz de
recorte, contorno de tinta, texturas PBR, pelagem em tufos e asas de penas e membranas. Eles servem de
base jogável. Os modelos **detalhados de verdade** (rosto, cabelo esculpido, dobras de roupa) vêm de
geradores 3D a partir dos prompts deste projeto e entram no jogo sozinhos, sem mudar código.

## 1. Gerar o modelo

1. Abra `docs/art/prompts_3d.md` (ou a página `docs/previews/prompts_3d.html`, que tem busca e botão de copiar).
2. Copie o prompt do personagem, criatura ou item.
3. Gere no Meshy, Tripo3D, Rodin ou CSM (texto → 3D, ou texto → imagem → 3D).
   - Personagens e criaturas: peça **A-pose**, pés em Y = 0, olhando para −Z, **sem armas nas mãos**.
   - Armas: o pivô (origem) deve ficar **na empunhadura**, com a lâmina ou haste apontando para +Y.
   - Texturas PBR: Albedo, Roughness, Metallic e **Emission** (olhos, runas, magma, poções).

## 2. Rig e animações (Mixamo)

1. Envie o modelo humanoide ao Mixamo e faça o auto-rig.
2. Baixe as animações e renomeie-as no Blender com estes nomes (o jogo procura por eles):

| Nome no arquivo | Uso no jogo |
| :--- | :--- |
| `Idle`, `Walk`, `Run` | Locomoção (misturadas pela velocidade) |
| `Dodge_Roll` | Esquiva [Shift] |
| `Attack_Melee_1H`, `Attack_Melee_2H_Heavy`, `Attack_Bow_Shoot`, `Attack_Cast_Throw` | Ataque básico por classe |
| `Skill_Q_Strike`, `Skill_R_Tactical`, `Skill_F_Ultimate`, `Skill_Z_Racial` | Habilidades Q, R, F e Z |
| `Interact_Autopsy_Kneel` | Mini-game de autópsia |
| `Death_Fall` | Morte (fica no último quadro para virar cadáver) |
| `Attack`, `Death` | Nomes genéricos aceitos para criaturas |

3. Exporte tudo num único `.glb` (malha + esqueleto + animações).

## 3. Colocar no jogo

Salve como `client/assets/models/hd/<arquivo>.glb`, com o nome indicado em cada prompt:

- Raças: `race_19_m.glb`, `race_19_f.glb`, ... (sem sufixo também vale: `race_19.glb`)
- NPCs: `npc_100.glb` (Garrick), `npc_103.glb` (Lyra), ...
- Criaturas: `mob_1.glb` (Lobo da Bruma), `mob_14.glb` (Malakor), ...
- Armas: `weapon_knight_longsword.glb`, `weapon_eclipse_scythe.glb`, ...

Ao abrir o projeto no Godot, o arquivo é importado e, a partir daí:

- o jogo usa o `.glb` no lugar do modelo procedural (personagem local, outros jogadores, NPCs, mobs e cadáveres);
- a altura é ajustada para ~1,85 m × a escala da raça;
- as armas da classe são presas nos ossos das mãos (`mixamorig:RightHand` / `LeftHand`);
- os clipes acima tocam nas mesmas ações do modelo procedural.

Para voltar ao modelo procedural, apague ou renomeie o arquivo, ou use `LunariaModel.use_hd = false`.

> Com um modelo HD, os trajes de classe procedurais não são vestidos por cima: a roupa vem no próprio
> `.glb`. Para trocar de visual por classe, gere uma variante por classe ou use o sistema de equipamentos.
