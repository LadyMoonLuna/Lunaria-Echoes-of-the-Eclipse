# Raças propostas — análise e balanceamento

Proposta de adaptação das raças do RPG de mesa do autor para Lunaria (MMO de ação em tempo real).
Nada aqui está implementado ainda: é a base para decidirmos o que entra no jogo.

## 1. Régua usada (igual às raças que já existem)

Atributos do jogo: **FOR, DES, CON, AGI, INT, ESP (Espírito), PER (Perícia/Maestria), SOR (Sorte)**.
O Carisma do RPG de mesa não existe no jogo; ele foi distribuído entre SOR (sorte, preços, charme) e ESP.

| Tipo de raça | Soma dos 8 atributos | Bônus de Vida + Mana + Stamina | Desvantagem obrigatória |
| :--- | :---: | :---: | :--- |
| Base (escolhida na criação) | 50 | ~40 | leve |
| Secreta (desbloqueada por item, evento ou missão) | 58 | ~70 | real e visível |
| Evolução (Ordem/Caos, nível 10+) | 70 | ~100 | — |

Os bônus de Vida/Mana/Stamina somam-se à base da classe (ex.: Espadachim 140 Vida). Hoje o jogo tem só
**Stamina**; a coluna **Mana** pressupõe a nova barra de Mana (ver seção 4).

### Regras de tradução de mesa → MMO

- **Turnos viram segundos**: "por turno" = a cada 2 s; "por cena" = recarga de 30–60 s; "1x por dia" = recarga de 10–20 min.
- **Dados viram porcentagens**: 1d8 de dano extra ≈ +35–40% de dano no golpe; 2d4 de cura ≈ 10–12% da vida.
- **Multiplicadores têm teto**: nenhum efeito de raça dá mais que **±50%** de dano (nada de 2x/3x) nem **imunidade total**
  a um elemento comum (máximo −60%). Imunidade só a algo de nicho (ex.: veneno).
- **Nada de perda permanente**: perder nível, memória, raça ou destruir equipamento não funciona num MMO.
- **Nada decidido pelo "mestre"** nem por d20 na criação: sorte na criação vira **escolha** do jogador.
- **Controle sobre jogadores é curto** (no máximo 1–2 s) e nunca funciona em chefes.
- **Tamanho afeta a hitbox**: Minúsculo e Enorme são ruins para PvP e para portas/casas da vila; usamos no máximo
  Pequeno e Grande, com o tamanho visual podendo variar um pouco.
- **Uma habilidade racial ativa (tecla Z)** por raça, como já existe no jogo; o resto vira passiva.

## 2. Tabela resumo

| Raça | Tipo sugerido | Tamanho | Vida | Mana | Stamina | FOR | DES | CON | AGI | INT | ESP | PER | SOR | Veredito |
| :--- | :--- | :---: | ---: | ---: | ---: | --: | --: | --: | --: | --: | --: | --: | --: | :--- |
| Meio-Celestial | Secreta (antes do Celestino) | Médio | +20 | +40 | +10 | 6 | 6 | 7 | 7 | 8 | 12 | 6 | 6 | **Implementar**, ligado ao Celestino |
| Pyromante | Secreta | Médio | +10 | +45 | +15 | 6 | 7 | 6 | 7 | 11 | 9 | 6 | 6 | **Implementar** |
| Gigante de Gelo | Evolução do Boreal | Grande (3 estágios) | +80 | +0 | +20 | 14 | 5 | 16 | 4 | 5 | 8 | 10 | 8 | **Implementar como evolução** |
| Drago — Terra | Secreta (linhagem) | Grande | +55 | +5 | +10 | 11 | 4 | 13 | 4 | 3 | 6 | 9 | 8 | **Implementar** (raça Drago com 4 linhagens) |
| Drago — Água | Secreta (linhagem) | Grande | +30 | +15 | +25 | 8 | 10 | 9 | 8 | 6 | 7 | 6 | 4 | **Implementar** |
| Drago — Raio | Secreta (linhagem) | Grande | +20 | +25 | +25 | 5 | 11 | 6 | 11 | 9 | 6 | 5 | 5 | **Implementar** |
| Drago — Místico | Secreta (linhagem) | Grande | +5 | +60 | +5 | 3 | 5 | 5 | 6 | 13 | 12 | 8 | 6 | **Implementar** |
| Orc | **Base** | Grande | +25 | +0 | +15 | 10 | 5 | 9 | 5 | 3 | 5 | 7 | 6 | **Implementar** |
| Anão | Fundir no Kharad | Pequeno | +30 | +5 | +5 | 8 | 5 | 11 | 3 | 6 | 5 | 7 | 5 | **Fundir** (o Kharad já é o "anão" de Lunaria) |
| Elfo | **Base** | Médio | +5 | +20 | +15 | 4 | 9 | 5 | 9 | 8 | 6 | 5 | 4 | **Implementar** |
| Elfo Solar | Evolução de Ordem do Elfo | Médio | +45 | +30 | +25 | 11 | 10 | 8 | 10 | 7 | 9 | 8 | 7 | **Implementar** |
| Elfo Lunar | Evolução de Caos do Elfo | Médio | +30 | +35 | +35 | 8 | 13 | 6 | 13 | 9 | 7 | 8 | 6 | **Implementar** |
| Fadinha | Secreta | Pequeno (visual menor) | -10 | +60 | +20 | 2 | 9 | 3 | 11 | 13 | 11 | 4 | 5 | **Implementar com ressalvas** |
| Goblin | **Base** | Pequeno | +5 | +5 | +30 | 4 | 10 | 5 | 10 | 4 | 4 | 5 | 8 | **Implementar** |
| Demi-humano Escorpião | Secreta | Médio | +25 | +20 | +25 | 7 | 11 | 8 | 10 | 4 | 4 | 9 | 5 | **Implementar** |
| Demi-humano Tartaruga | Secreta | Grande | +65 | +5 | +0 | 8 | 3 | 15 | 3 | 5 | 8 | 10 | 6 | **Implementar** |
| Meio-Demônio (Súcubo/Íncubo) | Evolução de Caos do Cambion | Médio | +25 | +50 | +25 | 6 | 11 | 7 | 11 | 11 | 7 | 6 | 11 | **Implementar como evolução** |
| Demi-humano Lobo | Fundir no Varkai | Médio | +15 | +5 | +20 | 9 | 8 | 7 | 9 | 3 | 4 | 6 | 4 | **Fundir** (Varkai + Licantropo já cobrem) |
| Manamante | Secreta | Médio | (+60)* | (unida) | +10 | 3 | 6 | 8 | 6 | 13 | 11 | 7 | 4 | **Implementar** (depende da barra de Mana) |

\* Manamante: Vida e Mana viram uma reserva só (+60 na reserva).

Somas conferidas: atributos = 50 (base), 58 (secreta), 70 (evolução); Vida + Mana + Stamina = 40 (base) / 70 (secreta) / 100 (evolução).

## 3. Raça por raça

### Meio-Celestial — Secreta (desbloqueio: rezar no Santuário durante o Eclipse Total)
- **Ser de Luz (passiva):** o ataque básico causa dano do elemento Luz. *Juramento:* não pode ser PK; matar um jogador
  fora de duelo ou guerra desliga as passivas da raça por 30 min. (Substitui "não pode matar rendidos/inocentes".)
- **Aversão às Trevas (passiva):** +25% de dano contra criaturas das trevas (mortos-vivos, cultistas, Abissais, Malakor);
  −20% de dano de trevas recebido. *Desvantagem:* +20% de dano de trevas recebido de inimigos de nível maior.
  (O original de 2x/0,5x por nível é explorável.)
- **Sorte Celestial (passiva):** cada acerto seguido no mini-game de autópsia alarga a zona de acerto em 5% (até 3x); erra, zera.
- **Revitalizar (passiva):** em zonas sagradas (Santuário, Cristal de Renascimento) a regeneração fora de combate é triplicada;
  em combate, recupera 1,5% da vida a cada 2 s. (O original "20 + metade do PM por turno" é cura infinita.)
- **Presente dos Céus (ativa secundária):** 15 Mana, asas de luz por 6 s: flutua, ignora armadilhas de chão e queda. Recarga 30 s.
- **Z — Brasão Estelar:** gasta 40% da Mana atual; +12% em todos os atributos para você e aliados em 10 m por 12 s. Recarga 60 s.
- *Sugestão:* o **Celestino (8)** passa a ser a evolução de Ordem do Meio-Celestial; o **Nephilim (27)** continua sendo o híbrido raro.

### Pyromante — Secreta (desbloqueio: sobreviver à Fornalha Ardente da Forja de Garrick durante a Lua de Sangue)
- **Chama da Vida → Renascer das Cinzas (passiva):** ao morrer, vira uma chama por 15 s. Um aliado pode "alimentar" a chama
  (interagir 3 s) para reviver você com 40% de vida; sem ajuda, revive sozinho com 20%. Recarga 20 min.
  (Removido: perder memória, metade do nível e das habilidades.)
- **Fulgor (passiva):** 50% do dano de fogo recebido vira **Brasa**, um escudo de até 15% da vida máxima; com Brasa ativa,
  seu próximo golpe de fogo causa +20% de dano e você não regenera vida. *Desvantagem:* +25% de dano de gelo e água;
  sob chuva (o clima do jogo já tem chuva), −20% de dano de fogo.
- **Ancestral da Fênix (ativa secundária):** gasta 15% da própria vida para curar 25% da vida de um aliado. Não funciona em si mesmo. Recarga 90 s.
- **Z — Combustão:** perde 40% da vida atual; +30% no atributo mais alto e −20% nos outros por 15 s. Recarga 120 s.

### Gigante de Gelo — Evolução do Boreal (24)
O Boreal já é o guardião do gelo eterno; o Gigante de Gelo é o que ele vira ao amadurecer. Tamanho em **3 estágios**
(níveis 10, 25 e 40: 1,15x → 1,3x → 1,45x), em vez de crescer sem limite, para não quebrar portas, câmera e hitbox.
- **Adaptabilidade Climática:** em neve ou nevasca, escudo de 15% da vida máxima que se renova fora de combate;
  em zonas quentes (forja, vulcão), −15% de vida máxima. (Original: vida dobrada ou cortada pela metade.)
- **Pele Gélida:** −50% de dano de gelo, −25% de água; +30% de dano de fogo recebido.
- **Regeneração Climática:** em neve, regeneração dobrada e ataques de água te curam 20% do dano; no calor, a cura recebida cai 40%.
- **Z — Memória Molecular:** cria a versão de gelo da arma equipada por 30 s (+10% de dano físico, golpes deixam lento). Recarga 45 s.
  *Desvantagem:* magias custam +50% de Mana. (Original: incapaz de usar magia, o que inutilizaria Iniciado e Acólito.)

### Drago — Secreta com 4 linhagens (escolha no despertar)
Uma raça só, como o Elfo com seus caminhos: o jogador escolhe Terra, Água, Raio ou Místico ao despertar.
Tamanho Grande. Desbloqueio sugerido: escama de dragão rara dropada pelo chefe vulcânico.

Comum às 4 linhagens:
- **Couraça Ancestral:** defesa natural = 3 + nível/2 + (atributo da linhagem)/2. Terra soma CON e funciona com armadura;
  Água (CON), Raio (DES) e Místico (INT, como potência mágica) só funcionam sem armadura pesada.
- **Último Fôlego (substitui Regressão de Raça):** ao chegar a 0 de vida, revive com 15% e perde as passivas por 5 min. Recarga 30 min.
  (Virar humano para sempre não funciona num MMO.)

| Linhagem | Passivas | Z (ativa) |
| :--- | :--- | :--- |
| **Terra** | Sangue Sujo: −30% de dano físico, +30% de dano mágico recebido. Mão Pesada: arma de 2 mãos + escudo, com −15% de velocidade de ataque. | **Insulto:** provoca todos os inimigos em 12 m por 4 s e ganha escudo de 15% da vida. Recarga 30 s. |
| **Água** | Lâmina d'Água: +15% de dano de arma, −15% de dano mágico. Bênção de Netuno: nado 2x e respira debaixo d'água. | **Sangue Limpo:** 10 Mana, cura 12% da vida; só perto de água ou na chuva. Recarga 8 s. |
| **Raio** | Para-raios: −50% de dano elétrico, e 25% do dano elétrico recebido vira cura. | **Sangue Energizado:** 20 Mana, +25% de velocidade de ataque por 6 s. **Descarga** (secundária): 8% da vida, raio a 12 m, +40% contra quem usa armadura de metal. |
| **Místico** | Sangue Místico: +4 de Mana por nível. Infusão Analógica: 15% de chance de converter 30% do dano mágico recebido em vida e Mana. Lado Místico: enxerga inimigos invisíveis e lê runas e inscrições. | **Couraça Arcana:** +10% de potência mágica e +15% de resistência mágica por 12 s. Recarga 40 s. |

### Orc — Base
- **Ataque Devastador:** 5 Mana (ou 10 Stamina): o próximo golpe corpo a corpo causa +40% de dano. Recarga 6 s. Não vale para armas à distância.
- **Barriga de Ferro:** imune a envenenamento e doença por comida; pode comer comida estragada e "Lixo Orgânico".
  (Hoje só o Myconid come Lixo Orgânico; sugiro dar ao Orc só a imunidade e deixar o Lixo exclusivo do Myconid.)
- **Músculos de Aço:** −12% de dano contundente, −5% de cortante; sem penalidade de velocidade por armadura ou carga.
- **Z — Sangue Fervente:** se recebeu dano nos últimos 5 s, cura 15% da vida. Recarga 25 s.

### Anão — Fundir no Kharad
O Kharad (baixo, largo, ligado à forja) já é o "anão" de Lunaria. Duas raças quase iguais dividem os jogadores.
Sugestão: o Kharad ganha as habilidades de ofício do Anão:
- **Herança da Forja:** escolhe Armeiro ou Artesão. Bônus de criação por faixa de nível
  (1 / 10 / 20 / 30 / 40 → libera Incomum / Raro / Lendário / Místico / diagrama de Artefato).
  Resistência a fogo de −10% / −20% / −30% / −40% / −50% (sem imunidade).
- **Devagar e Sempre:** −10% de velocidade, sem penalidade por armadura ou carga.
- **Olho do Artesão:** 10% de desconto e 10% de lucro com Garrick e outros ferreiros; visão no escuro.

### Elfo (Base) → Elfo Solar (Ordem) / Elfo Lunar (Caos)
Encaixa no sistema de evoluções que o jogo já tem. Para não repetir o Noctari: o **Noctari** é o elfo da lua de Lunaria
(magia astral); o **Elfo Lunar** é o devoto das sombras (furtividade, noite).
- **Elfo:** Pés Velozes (+8% de velocidade), Corpo Esguio (+5% de esquiva), Caminho Élfico na criação: Pontaria
  (+8% de dano à distância) **ou** Misticismo (+8% de dano mágico).
- **Elfo Solar:** +10% de velocidade, Corpo Esguio, luzes que você cria iluminam o dobro.
  **Z — Espada Solar:** 15 Mana, arma de corte causa +20% de dano de fogo por 20 s. Recarga 40 s.
- **Elfo Lunar:** +12% de velocidade à noite (a noite de 40 min combina muito com isso), sem penalidade de visão no escuro.
  **Z — Escuridão:** nuvem de 6 m por 6 s; inimigos dentro ficam com −30% de precisão. Recarga 35 s.
- *Atenção:* **Azgher** e **Tenebra** são deuses do cenário Tormenta (Jambô). Para um jogo comercial, troque pelos deuses de
  Lunaria (ex.: o Trono Solar e a Corte do Eclipse, que já aparecem na história do Nephilim).

### Fadinha — Secreta (desbloqueio: libertar a Árvore-Mãe no Bosque Sussurrante)
- Tamanho **visual** minúsculo, mas **hitbox de Pequeno**; uma hitbox minúscula seria quase impossível de acertar no PvP.
- **Essência da Magia:** +3 de Mana por nível.
- **Espírito da Natureza:** animais (lobos) de nível menor que o seu não atacam primeiro.
- **Moradia Florestal:** +15% de velocidade e regeneração em florestas.
- **Asas de Borboleta (passiva):** flutua; sem dano de queda e ignora armadilhas de chão.
- **Z — Pó de Fada:** área de 5 m: cura aliados em 10% e deixa inimigos lentos por 3 s. Recarga 30 s.
- *Desvantagem:* -10 de vida, +20% de dano crítico recebido e não usa armas de duas mãos.

### Goblin — Base
- **Cleptomancia:** +15% de ouro dropado por mobs.
- **Treinamento Goblin:** abre fechaduras e baús trancados sem ferramenta; desarma armadilhas.
- **Peste Esguia:** hitbox Pequena com velocidade normal.
- **Z — Fuga Goblin** (nova): bomba de fumaça, +40% de velocidade por 3 s e quebra a mira dos inimigos. Recarga 30 s.

### Demi-humano Escorpião — Secreta (desbloqueio: sobreviver ao veneno do Varis sem antídoto)
- **Cauda Venenosa:** a cada 3º golpe, a cauda ataca sozinha (30% do dano da arma).
- **Toxinas Vorpais:** golpes da cauda acumulam toxina no alvo: 1ª carga envenena (dano contínuo); 2ª deixa abalado
  (−20% de dano por 5 s); 3ª dispara a **Toxina Letal** (15% da vida máxima do alvo; em chefes, 3%). Sem morte instantânea.
- **Sangue Ruim:** imune a veneno (exceção permitida: é um elemento de nicho).
- **Sangue Frio:** inimigos percebem você a 30% menos distância; +10% de dano em alvos desprevenidos.
- **Espreitador dos Becos:** −50% de lentidão em terreno difícil; +10% de esquiva.
- **Z — Sangue Tóxico:** gasta 20% da vida; nuvem corrosiva de 4 m por 6 s (dano contínuo e −15% de armadura dos inimigos).
  Recarga 60 s. (Removido: arma inutilizada depois de 2 usos.)

### Demi-humano Tartaruga — Secreta (desbloqueio: Thalassia ou um evento de praia)
- Tamanho **Grande** em vez de Enorme (portas e casas da vila). −25% de velocidade.
- **Armadura Orgânica:** não usa armadura de peito; defesa natural = 5 + CON/2 + nível/2.
- **Z — Carapaça:** recolhe-se por até 6 s: −60% de dano (exceto contundente, que causa +50%), recupera 3% da vida por segundo,
  não ataca nem segura itens. Recarga 20 s. (Original: dano contundente 3x e quebra a carapaça.)
- **Animal Aquático:** respira debaixo d'água; nado 2x.

### Meio-Demônio (Súcubo / Íncubo) — Evolução de Caos do Cambion (26)
O Cambion já é meio-demônio; o Súcubo/Íncubo é o caminho do charme. Funciona para os dois gêneros. Sugiro manter o tom
"charme e encanto" (sem conteúdo explícito), que é mais seguro para a classificação indicativa do jogo.
- **Aparência Inofensiva:** o primeiro inimigo que atacar você no combate fica atordoado por 1 s. Recarga 30 s; não funciona em chefes.
- **Atraente:** −10% de preço com NPCs; diálogos extras com alguns NPCs.
- **Marca do Encanto:** marca 1 inimigo por 20 s: ele causa −15% de dano em você e recebe +10% do seu dano.
  (Substitui "suscetível a sugestões", que seria controle mental sobre jogadores.)
- **Z — Dreno Vital:** rouba 8% da vida máxima (ou da Mana, o que for maior) do alvo e cura você. Recarga 45 s.
  No PvP, o alvo fica **Enfurecido** (+15% de dano contra você por 10 s). Gancho de história: os guardas do Capitão Randel
  ficam hostis a quem usa o Dreno na vila. (Original: roubar metade da vida máxima, que é desbalanceado.)

### Demi-humano Lobo — Fundir no Varkai (4)
O Varkai (sangue-feral lupino), a Fera do Frenesi (18) e o Licantropo Primordial (6) já formam essa linha.
Sugestão: o Varkai ganha a parte social e de rastreio, e o Licantropo vira a "Forma Bestial":
- **Olfato:** destaca rastros de mobs e jogadores próximos (+raio de detecção).
- **Presença:** não pode ser pego de surpresa (imune ao bônus de ataque pelas costas).
- **Despertar Bestial:** a primeira transformação é desbloqueada na **Lua de Sangue** ou ao derrotar um **Dhampir**
  (o jogo já tem as 10 fases da lua e o Dhampir como raça).
- **Hierarquia escolhida (não sorteada):** Alfa (+Vida, +FOR, tanque e dano), Beta (equilíbrio), Ômega (+velocidade, cura de matilha).
  Estar em grupo com outros lobos dá +5% de atributos ao grupo.
- **Z — Forma Bestial:** 30 Mana + 2 por nível; grátis na Lua Cheia. Durante a forma: +60% de velocidade de ataque, sem
  habilidades de classe (o antigo Irracional). Prata causa +50% de dano; outros danos físicos −10%.

### Manamante — Secreta (desbloqueio: absorver um Cristal de Renascimento corrompido no Santuário)
Raça de "canhão de vidro" mágico: muito poder, mas cada magia gasta a própria vida.
- **Coração de Mana:** não existe barra de Vida. Vida e Mana viram uma **reserva única**:
  reserva = (Vida da classe + Mana da classe) × 0,9 + 60 + CON × 10. Poções de vida e de mana e escudos de vida
  temporária enchem a reserva. Magias gastam a reserva. **Trava de segurança:** nenhuma magia pode ser lançada
  com a reserva abaixo de 15% (evita morrer lançando a própria magia sem querer).
- **Afinidade Mágica:** escolhe uma escola no despertar (Fogo, Gelo, Raio, Luz, Trevas ou Arcano):
  +15% de dano nessa escola e −10% de resistência dos inimigos contra ela. (Original: +1 dado e desvantagem nos testes.)
- **Sangue Azul:** +6 na reserva por nível (as outras raças ganham +5 de Vida e um pouco de Mana).
  O limite de 3 PM por magia no nível 1 não faz sentido em tempo real; vira a trava de 15% acima.
- *Desvantagem:* efeitos que drenam ou queimam Mana (Dreno do Súcubo, magias anti-mago) atingem a reserva inteira
  e causam +25% de efeito. Silêncio também interrompe a regeneração da reserva.
- **Karma (escolha permanente no despertar; pode ser trocada por uma missão difícil):**

| Karma Ativo — Guardião de Mana | Karma Passivo — Forja de Mana |
| :--- | :--- |
| **Z:** gasta 40% da reserva para invocar uma armadura viva de mana, com vida = 50% do gasto. | **Z (escudo):** gasta até 30% da reserva; cria escudo com o dobro do gasto em vida, até 9 m (pode proteger aliados). |
| Ela absorve o dano antes de você e ataca sozinha. Na escolha, o jogador define o estilo: **Guerreiro** (golpes corpo a corpo) ou **Bruxo** (projéteis). | **Arma de Mana** (secundária): +10% de dano por cada 10% da reserva gasta (máx. +30%) por 20 s. |
| **Traço exótico** (escolhido no despertar, não pelo mestre): Espinhos (reflete 15% do dano), Espelho (bloqueia 1 magia a cada 20 s), Vínculo (20% do dano que você cura vira vida do Guardião) ou Fúria (+25% de velocidade dele). | **Cópia de Objeto** (fora de combate): copia um item comum que você já viu. A cópia dura 1 h, não pode ser vendida, trocada nem usada em criação (evita duplicar itens e quebrar a economia). |
| Ao chegar a 0, o Guardião volta à marca; recarga 90 s. Golpes críticos recebidos por você ferem a marca (−10% da vida dele). Sem perda permanente. | Poções copiadas dão só Mana temporária (+5%), não empilham, e não funcionam em outro Manamante. |

- *Por que é secreta:* sem barra de vida separada, ela é a raça mais forte e a mais frágil ao mesmo tempo; precisa ser testada
  isolada antes de ser liberada.

## 4. Mana no jogo

As raças acima usam **Mana**, mas o jogo hoje só tem **Stamina**. Proposta:
- **Stamina:** esquiva, corrida e golpes físicos especiais (como hoje).
- **Mana:** magias, habilidades de classe mágicas e a tecla Z das raças mágicas.
- Base de Mana por classe: Iniciado 120, Acólito 110, Alquimista 90, Criador de Homúnculos 100, Artífice 70,
  Batedor 50, Espadachim 40, Ferreiro 30, Ceifador 60, Viajante 50 (+3 por nível). A Mana da raça soma a isso.
- No servidor: um campo `MaxMana`/`Mana` no `Player`, regeneração de 1,5% por segundo fora de combate e
  0,5% em combate, mais um pacote de status com a Mana.

## 5. Recomendação de ordem

1. **Agora (raças base):** Orc, Goblin e Elfo (com Solar e Lunar como evoluções). São simples e preenchem espaços vazios.
2. **Depois (secretas):** Drago com 4 linhagens, Pyromante, Escorpião e Tartaruga.
3. **Ligadas a raças existentes:** Meio-Celestial (antes do Celestino), Gigante de Gelo (Boreal), Súcubo/Íncubo (Cambion).
4. **Fundir, sem raça nova:** Anão → Kharad e Demi-humano Lobo → Varkai/Licantropo.
5. **Manamante:** logo depois da barra de Mana, já que ela é a raça que mais depende dela.
6. **Fadinha:** só depois de testar a hitbox e a câmera de personagens pequenos.

Com isso o jogo passa de 28 para cerca de 41 raças. Se a lista ficar grande demais para a tela de seleção, as secretas podem
aparecer só depois de desbloqueadas.
