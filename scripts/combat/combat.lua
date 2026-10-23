-- combat.lua — Sistema de Dano, Classes, 6 Tiers de Raridade e Reações Lunares (Marco 3 & Expansão)

-- Raças:
-- 1 = Valeriano
-- 2 = Noctari
-- 3 = Kharad
-- 4 = Varkai
-- 5 = Dhampir (Secreta)

-- Classes:
-- 1 = Espadachim (Melee: Espada & Escudo)
-- 2 = Batedor (Ranged: Arco de Caça)
-- 3 = Iniciado (Ranged: Cajado Rúnico)
-- 4 = Acólito (Híbrido: Maça & Talismã)
-- 5 = Ferreiro (Melee Pesado: Martelo de Forja)
-- 6 = Alquimista (Ranged Químico: Frascos Explosivos)
-- 7 = Ceifador do Eclipse (Melee Sombrio: Foice Colossal)
-- 8 = Artífice Rúnico (Híbrido Mecânico: Martelo-Canhão)
-- 9 = Criador de Homúnculos (Ranged Alquímico: Elixires Abissais)

-- Tiers de Raridade (1 a 6):
-- 1 = Comum (1.0x)
-- 2 = Incomum (1.20x)
-- 3 = Rara (1.45x)
-- 4 = Épica (1.75x)
-- 5 = Única (2.15x)
-- 6 = Lendária (2.60x)

-- Ações de Combate (0x31):
-- 1 = Ataque Básico (Clique Esquerdo)
-- 2 = Esquiva (Dodge Roll - Tecla Shift)
-- 3 = Habilidade 1 [Tecla Q] (1.75x dano)
-- 4 = Habilidade 2 [Tecla R] (1.90x dano)
-- 5 = Habilidade 3 [Tecla F] (2.40x dano - Ultimate)

-- Fases da Lua (0 a 9):
-- 0 = Lua Nova
-- 1 = Lua Crescente
-- 2 = Quarto Crescente
-- 3 = Gibosa Crescente
-- 4 = Lua Cheia
-- 5 = Gibosa Minguante
-- 6 = Quarto Minguante
-- 7 = Lua Minguante
-- 8 = Lua de Sangue (Blood Moon - Evento Especial)
-- 9 = Eclipse Total (Cataclismo)

function CalculateDamage(race_id, class_id, action_type, hp_pct, world_hour, moon_phase, weather_type, class_tier, level, buff_active, stat_str, stat_dex, stat_int, stat_spi, stat_mas, stat_lck)
    local tier = tonumber(class_tier) or 1
    local lvl = tonumber(level) or 1
    local buff = tonumber(buff_active) or 0
    local str = tonumber(stat_str) or 5
    local dex = tonumber(stat_dex) or 5
    local int_stat = tonumber(stat_int) or 5
    local spi = tonumber(stat_spi) or 5
    local mas = tonumber(stat_mas) or 5
    local lck = tonumber(stat_lck) or 5

    -- 1. Dano Base por Classe (1 a 12 Básicas e 13 a 21 Secretas)
    local damage = 20
    if class_id == 0 then
        damage = 18 -- Viajante / Sem Classe (Tier 0)
    -- As 6 Classes Básicas de Combate (IDs 1 a 6)
    elseif class_id == 1 then
        damage = 28 -- Guerreiro (Espada)
    elseif class_id == 2 then
        damage = 32 -- Mago (Cajado / Orbe Arcano)
    elseif class_id == 3 then
        damage = 26 -- Arqueiro (Arco)
    elseif class_id == 4 then
        damage = 29 -- Assassino (Duas Adagas)
    elseif class_id == 5 then
        damage = 31 -- Lutador (Manoplas Pesadas)
    elseif class_id == 6 then
        damage = 25 -- Escudeiro (Escudo Colossal + Maça Curta)
    -- As 6 Classes Básicas de Produção Combatentes (IDs 7 a 12)
    elseif class_id == 7 then
        damage = 30 -- Ferreiro (Martelo de Forja)
    elseif class_id == 8 then
        damage = 26 -- Alquimista (Catalisador & Frascos Químicos)
    elseif class_id == 9 then
        damage = 28 -- Escultor (Cinzel & Adaga do Luar)
    elseif class_id == 10 then
        damage = 27 -- Domador (Chicote Bestial)
    elseif class_id == 11 then
        damage = 27 -- Alfaiate de Guerra (Fios de Aço & Agulhas)
    elseif class_id == 12 then
        damage = 30 -- Chef de Caça (Cutelo Gigante & Wok de Ferro)
    -- Classes Secretas Variantes (13 a 18, Tier 3 a 4)
    elseif class_id == 13 then
        damage = 34 -- Espadachim Rúnico (Spellblade)
    elseif class_id == 14 then
        damage = 33 -- Caçador de Vampiros (Inquisidor de Prata)
    elseif class_id == 15 then
        damage = 33 -- Valquíria da Égide (Lanceiro Celeste)
    elseif class_id == 16 then
        damage = 35 -- Monge das Sombras (Punho Silencioso)
    elseif class_id == 17 then
        damage = 34 -- Forjador de Armas Amaldiçoadas
    elseif class_id == 18 then
        damage = 31 -- Médico da Peste (Doutor Corvo)
    -- Classes Secretas ÚNICAS (Tier 5): exclusivas de raça 19-26, gerais 27-30 e 35-39
    elseif class_id == 19 then
        damage = 41 -- Carrasco do Veneno Vorpal
    elseif class_id == 20 then
        damage = 40 -- Soberano da Teia Carmesim
    elseif class_id == 21 then
        damage = 43 -- Rei-Fera da Alcateia de Sangue
    elseif class_id == 22 then
        damage = 42 -- Runomante da Montanha Eterna
    elseif class_id == 23 then
        damage = 38 -- Bastião do Mundo
    elseif class_id == 24 then
        damage = 40 -- Arquifada da Árvore do Mundo
    elseif class_id == 25 then
        damage = 42 -- Aristocrata Carmesim
    elseif class_id == 26 then
        damage = 41 -- Barão da Sucata
    elseif class_id == 27 then
        damage = 42 -- Ceifador do Eclipse
    elseif class_id == 28 then
        damage = 40 -- Dançarino Astral
    elseif class_id == 29 then
        damage = 38 -- Inquisidor das Cinzas
    elseif class_id == 30 then
        damage = 36 -- Necromante de Ossos
    elseif class_id == 35 then
        damage = 40 -- Artífice Rúnico
    elseif class_id == 36 then
        damage = 38 -- Criador de Homúnculos
    elseif class_id == 37 then
        damage = 41 -- Domador Primordial
    elseif class_id == 38 then
        damage = 44 -- Cavaleiro da Ruptura
    elseif class_id == 39 then
        damage = 38 -- Arauto da Tempestade
    -- Classes Secretas LENDÁRIAS (Tier 6): 31-34
    elseif class_id == 31 then
        damage = 50 -- Descendente de Pagma
    elseif class_id == 32 then
        damage = 48 -- Escultor do Luar Lendário
    elseif class_id == 33 then
        damage = 52 -- Monarca dos Dragões
    elseif class_id == 34 then
        damage = 52 -- Imperador do Sol Negro
    end

    -- 2. Multiplicador de Ação (ActionType)
    if action_type == 2 then
        return 0, 0 -- Esquiva não causa dano
    elseif action_type == 3 then
        -- Habilidade 1 [Tecla Q]
        if class_id == 1 then
            damage = damage * 1.80 -- Guerreiro: Corte Duplo (1.8x)
        elseif class_id == 2 then
            damage = damage * 1.90 -- Mago: Orbe de Magma (1.9x)
        elseif class_id == 3 then
            damage = damage * 1.85 -- Arqueiro: Tiro Perfurante (1.85x)
        elseif class_id == 4 then
            damage = damage * 1.90 -- Assassino: Passo das Sombras (1.9x)
        elseif class_id == 5 then
            damage = damage * 1.85 -- Lutador: Gancho Demolidor (1.85x)
        elseif class_id == 6 then
            damage = damage * 1.70 -- Escudeiro: Esmagamento de Bastião (1.7x)
        elseif class_id == 7 then
            damage = damage * 1.85 -- Ferreiro: Golpe da Bigorna Incandescente (1.85x)
        elseif class_id == 8 then
            damage = damage * 1.80 -- Alquimista: Frasco de Fogo Grego & Cura (1.8x)
        elseif class_id == 9 then
            damage = damage * 1.90 -- Escultor: Entalhe em Velocidade (1.9x)
        elseif class_id == 10 then
            damage = damage * 1.90 -- Domador: Estalo do Chicote (1.9x)
        elseif class_id == 11 then
            damage = damage * 1.85 -- Alfaiate de Guerra: Teia de Fios Retalhadores (1.85x)
        elseif class_id == 12 then
            damage = damage * 1.90 -- Chef de Caça: Desossar a Vivo! (1.9x)
        elseif class_id == 13 then
            damage = damage * 2.00 -- Espadachim Rúnico: Corte Flamígero/Glacial (2.0x)
        elseif class_id == 14 then
            damage = damage * 1.90 -- Caçador de Vampiros: Virote de Prata (1.9x)
        elseif class_id == 15 then
            damage = damage * 2.00 -- Valquíria da Égide: Estocada do Trovão (2.0x)
        elseif class_id == 16 then
            damage = damage * 2.00 -- Monge das Sombras: Palma das Sombras (2.0x)
        elseif class_id == 17 then
            damage = damage * 2.00 -- Forjador Amaldiçoado: Martelo Hemorrágico (2.0x)
        elseif class_id == 18 then
            damage = damage * 1.90 -- Médico da Peste: Bisturi Cirúrgico (1.9x)
        elseif class_id == 19 then
            damage = damage * 2.50 -- Carrasco do Veneno Vorpal: Ferrão Duplo Vorpal (2.5x)
        elseif class_id == 20 then
            damage = damage * 2.40 -- Soberano da Teia Carmesim: Fios de Seda Cortante (2.4x)
        elseif class_id == 21 then
            damage = damage * 2.50 -- Rei-Fera da Alcateia de Sangue: Frenesi de Mordidas Sincronizadas (2.5x)
        elseif class_id == 22 then
            damage = damage * 2.50 -- Runomante da Montanha Eterna: Martelo Trovão da Montanha (2.5x)
        elseif class_id == 23 then
            damage = damage * 2.40 -- Bastião do Mundo: Giro de Carapaça Demolidora (2.4x)
        elseif class_id == 24 then
            damage = damage * 2.50 -- Arquifada da Árvore do Mundo: Rajada de Pó Estelar (2.5x)
        elseif class_id == 25 then
            damage = damage * 2.50 -- Aristocrata Carmesim: Lança de Sangue Congelado (2.5x)
        elseif class_id == 26 then
            damage = damage * 2.40 -- Barão da Sucata: Canhão de Moedas & Metralha (2.4x)
        elseif class_id == 27 then
            damage = damage * 2.50 -- Ceifador do Eclipse: Colheita Noturna (2.5x)
        elseif class_id == 28 then
            damage = damage * 2.60 -- Dançarino Astral: Corte Cadente (2.6x)
        elseif class_id == 29 then
            damage = damage * 2.60 -- Inquisidor das Cinzas: Chicote de Penitência (2.6x)
        elseif class_id == 30 then
            damage = damage * 2.50 -- Necromante de Ossos: Lança de Fêmur (2.5x)
        elseif class_id == 35 then
            damage = damage * 2.40 -- Artífice Rúnico: Salva Rúnica (2.4x)
        elseif class_id == 36 then
            damage = damage * 2.40 -- Criador de Homúnculos: Frasco Quimérico (2.4x)
        elseif class_id == 37 then
            damage = damage * 2.50 -- Domador Primordial: Investida do Alfa (2.5x)
        elseif class_id == 38 then
            damage = damage * 2.40 -- Cavaleiro da Ruptura: Esmagamento Gravitacional (2.4x)
        elseif class_id == 39 then
            damage = damage * 2.60 -- Arauto da Tempestade: Lança do Trovão (2.6x)
        elseif class_id == 31 then
            damage = damage * 3.80 -- Descendente de Pagma: Dança da Espada: Onda (3.8x)
        elseif class_id == 32 then
            damage = damage * 3.80 -- Escultor do Luar Lendário: Lâmina da Lua Radiante (3.8x)
        elseif class_id == 33 then
            damage = damage * 3.90 -- Monarca dos Dragões: Garra do Monarca (3.9x)
        elseif class_id == 34 then
            damage = damage * 4.00 -- Imperador do Sol Negro: Corte do Horizonte de Eventos (4.0x)
        else
            damage = damage * 1.75 -- Base Q
        end
    elseif action_type == 4 then
        -- Habilidade 2 [Tecla R]
        if class_id == 1 then
            damage = damage * 1.90 -- Guerreiro: Investida Imparável (Dash)
        elseif class_id == 2 then
            damage = damage * 1.70 -- Mago: Prisão Glacial
        elseif class_id == 3 then
            damage = damage * 1.60 -- Arqueiro: Salto Acrobático
        elseif class_id == 4 then
            damage = damage * 1.40 -- Assassino: Cortina de Fumaça
        elseif class_id == 5 then
            damage = damage * 1.40 -- Lutador: Postura do Lótus Marcial
        elseif class_id == 6 then
            damage = damage * 1.30 -- Escudeiro: Formação Impenetrável
        elseif class_id == 7 then
            damage = damage * 1.50 -- Ferreiro: Afiação & Têmpera em Campo
        elseif class_id == 8 then
            damage = damage * 1.60 -- Alquimista: Bomba de Ácido Corrosivo
        elseif class_id == 9 then
            damage = damage * 1.70 -- Escultor: Estátua Explosiva / Pele de Mármore
        elseif class_id == 10 then
            damage = damage * 1.50 -- Domador: Fusão & Uivo Bestial
        elseif class_id == 11 then
            damage = damage * 1.60 -- Alfaiate de Guerra: Costurar Sombras
        elseif class_id == 12 then
            damage = damage * 1.40 -- Chef de Caça: Banquete na Wok Flamejante
        elseif class_id == 14 then
            damage = damage * 1.70 -- Caçador de Vampiros: Corrente de Exorcismo
        elseif class_id == 15 then
            damage = damage * 1.80 -- Valquíria da Égide: Salto da Valquíria
        elseif class_id == 16 then
            damage = damage * 1.60 -- Monge das Sombras: Passo Fantasma
        elseif class_id == 19 then
            damage = damage * 2.40 -- Carrasco do Veneno Vorpal: Ecdise Ácida (2.4x)
        elseif class_id == 20 then
            damage = damage * 2.40 -- Soberano da Teia Carmesim: Casulo de Drenagem (2.4x)
        elseif class_id == 21 then
            damage = damage * 2.40 -- Rei-Fera da Alcateia de Sangue: Uivo do Eclipse Lupino (2.4x)
        elseif class_id == 22 then
            damage = damage * 2.40 -- Runomante da Montanha Eterna: Bigorna Ancestral Viva (2.4x)
        elseif class_id == 23 then
            damage = damage * 2.40 -- Bastião do Mundo: Fortaleza Hidráulica (2.4x)
        elseif class_id == 24 then
            damage = damage * 2.40 -- Arquifada da Árvore do Mundo: Anel de Cogumelos Mágicos (2.4x)
        elseif class_id == 25 then
            damage = damage * 2.50 -- Aristocrata Carmesim: Enxame da Noite (2.5x)
        elseif class_id == 26 then
            damage = damage * 2.40 -- Barão da Sucata: Propulsor Turbo (2.4x)
        elseif class_id == 27 then
            damage = damage * 2.40 -- Ceifador do Eclipse: Drenagem Abissal (2.4x)
        elseif class_id == 28 then
            damage = damage * 2.40 -- Dançarino Astral: Valsa dos Espelhos (2.4x)
        elseif class_id == 29 then
            damage = damage * 2.40 -- Inquisidor das Cinzas: Selo de Excomunhão (2.4x)
        elseif class_id == 30 then
            damage = damage * 2.50 -- Necromante de Ossos: Explosão Óssea (2.5x)
        elseif class_id == 35 then
            damage = damage * 2.40 -- Artífice Rúnico: Têmpera Rúnica (2.4x)
        elseif class_id == 36 then
            damage = damage * 2.40 -- Criador de Homúnculos: Elixir do Homúnculo (2.4x)
        elseif class_id == 37 then
            damage = damage * 2.40 -- Domador Primordial: Uivo da Alcateia (2.4x)
        elseif class_id == 38 then
            damage = damage * 2.60 -- Cavaleiro da Ruptura: Singularidade Reversa (2.6x)
        elseif class_id == 39 then
            damage = damage * 2.50 -- Arauto da Tempestade: Passo de Relâmpago (2.5x)
        elseif class_id == 31 then
            damage = damage * 3.60 -- Descendente de Pagma: Transcendência de 6 Espadas (3.6x)
        elseif class_id == 32 then
            damage = damage * 3.60 -- Escultor do Luar Lendário: Destruição Escultural (3.6x)
        elseif class_id == 33 then
            damage = damage * 3.70 -- Monarca dos Dragões: Rugido de Subjugação (3.7x)
        elseif class_id == 34 then
            damage = damage * 3.80 -- Imperador do Sol Negro: Égide da Aurora e Abismo (3.8x)
        else
            damage = damage * 1.60 -- Base R
        end
    elseif action_type == 5 then
        -- Habilidade 3 [Tecla F] - Ultimate
        if class_id == 1 then
            damage = damage * 2.60 -- Guerreiro: Julgamento da Espada (2.6x; +40% em alvos com <35% HP, aplicado por alvo no servidor)
        elseif class_id == 2 then
            damage = damage * 2.80 -- Mago: Chuva de Meteoros (2.8x)
        elseif class_id == 3 then
            damage = damage * 2.60 -- Arqueiro: Tempestade de Mil Flechas (2.6x)
        elseif class_id == 4 then
            damage = damage * 2.70 -- Assassino: Lótus de Sangue (2.7x)
        elseif class_id == 5 then
            damage = damage * 2.75 -- Lutador: Meteoro de Um Punho (2.75x)
        elseif class_id == 6 then
            damage = damage * 2.20 -- Escudeiro: Cidadela Inabalável (2.2x)
        elseif class_id == 7 then
            damage = damage * 2.70 -- Ferreiro: Dança do Arsenal Forjado (2.7x)
        elseif class_id == 8 then
            damage = damage * 2.60 -- Alquimista: Transmutação do Behemoth Químico (2.6x)
        elseif class_id == 9 then
            damage = damage * 2.80 -- Escultor: Técnica Secreta: Escultura do Luar (2.8x Dano Verdadeiro)
        elseif class_id == 10 then
            damage = damage * 2.80 -- Domador: Debandada das Feras Primordiais (2.8x)
        elseif class_id == 11 then
            damage = damage * 2.70 -- Alfaiate de Guerra: Gaiola de Fios Carmesins (2.7x)
        elseif class_id == 12 then
            damage = damage * 2.80 -- Chef de Caça: Trinchar o Behemoth (2.8x)
        elseif class_id == 13 then
            damage = damage * 2.80 -- Espadachim Rúnico: Cometa da Espada Arcana (2.8x)
        elseif class_id == 14 then
            damage = damage * 2.80 -- Caçador de Vampiros: Julgamento da Cruz Solar (2.8x)
        elseif class_id == 15 then
            damage = damage * 2.80 -- Valquíria da Égide: Chuva de Lanças Douradas (2.8x)
        elseif class_id == 16 then
            damage = damage * 3.00 -- Monge das Sombras: Toque da Morte de Cinco Passos (3.0x + explosão em 5s)
        elseif class_id == 17 then
            damage = damage * 2.90 -- Forjador Amaldiçoado: Despertar da Espada Demoníaca (2.9x)
        elseif class_id == 18 then
            damage = damage * 2.60 -- Médico da Peste: Nuvem da Peste Negra (2.6x + peste)
        elseif class_id == 19 then
            damage = damage * 4.00 -- Carrasco do Veneno Vorpal: Execução da Terceira Dose Letal (4.0x)
        elseif class_id == 20 then
            damage = damage * 3.50 -- Soberano da Teia Carmesim: Domínio da Viúva Negra (3.5x)
        elseif class_id == 21 then
            damage = damage * 3.60 -- Rei-Fera da Alcateia de Sangue: Caçada Selvagem da Alcateia (3.6x)
        elseif class_id == 22 then
            damage = damage * 3.60 -- Runomante da Montanha Eterna: Forja do Ragnarok (3.6x)
        elseif class_id == 23 then
            damage = damage * 3.50 -- Bastião do Mundo: Peso do Oceano Profundo (3.5x)
        elseif class_id == 24 then
            damage = damage * 3.50 -- Arquifada da Árvore do Mundo: Despertar de Titânia (3.5x)
        elseif class_id == 25 then
            damage = damage * 3.60 -- Aristocrata Carmesim: Trono de Sangue (3.6x)
        elseif class_id == 26 then
            damage = damage * 3.80 -- Barão da Sucata: Autodestruição Nuclear Goblin (3.8x)
        elseif class_id == 27 then
            damage = damage * 3.20 -- Ceifador do Eclipse: Dança do Eclipse Total (3.2x)
        elseif class_id == 28 then
            damage = damage * 3.40 -- Dançarino Astral: Constelação de Mil Lâminas (3.4x)
        elseif class_id == 29 then
            damage = damage * 3.40 -- Inquisidor das Cinzas: Crucificação de Cinzas (3.4x)
        elseif class_id == 30 then
            damage = damage * 3.30 -- Necromante de Ossos: Legião do Ossuário (3.3x)
        elseif class_id == 35 then
            damage = damage * 3.20 -- Artífice Rúnico: Bombardeio Estelar (3.2x)
        elseif class_id == 36 then
            damage = damage * 3.20 -- Criador de Homúnculos: Magnum Opus (3.2x)
        elseif class_id == 37 then
            damage = damage * 3.40 -- Domador Primordial: Fúria do Behemoth (3.4x)
        elseif class_id == 38 then
            damage = damage * 3.30 -- Cavaleiro da Ruptura: Colapso Estelar (3.3x)
        elseif class_id == 39 then
            damage = damage * 3.40 -- Arauto da Tempestade: Ira dos Céus (3.4x)
        elseif class_id == 31 then
            damage = damage * 4.80 -- Descendente de Pagma: Queda do Deus da Forja (4.8x)
        elseif class_id == 32 then
            damage = damage * 4.60 -- Escultor do Luar Lendário: Legião Imperial do Luar (4.6x)
        elseif class_id == 33 then
            damage = damage * 5.00 -- Monarca dos Dragões: Cataclismo do Rei Dragão (5.0x)
        elseif class_id == 34 then
            damage = damage * 5.00 -- Imperador do Sol Negro: Apocalipse do Sol Negro (5.0x)
        else
            damage = damage * 2.50 -- Base Ultimate
        end
    elseif action_type == 6 then
        damage = damage * 2.20 -- Habilidade Racial Ativa [Tecla Z]
    end

    -- 3. Multiplicador do Tier de Raridade (0 a 6)
    local tier_multiplier = 1.0
    if tier == 2 then
        tier_multiplier = 1.20 -- Incomum
    elseif tier == 3 then
        tier_multiplier = 1.45 -- Rara
    elseif tier == 4 then
        tier_multiplier = 1.75 -- Épica
    elseif tier == 5 then
        tier_multiplier = 2.15 -- Única
    elseif tier >= 6 then
        tier_multiplier = 2.60 -- Lendária
    end
    damage = damage * tier_multiplier

    -- 4. Escala por Nível (+4% de dano por nível acima do 1) e Árvore de Passivas de Marco (Lv 10, 25, 45, 50)
    if lvl > 1 then
        local level_bonus = 1.0 + (lvl - 1) * 0.04
        -- Desbloqueio de Marcos de Passivas
        if lvl >= 50 then
            level_bonus = level_bonus + 0.35 -- Despertar Lendário Nv. 50 (+35% dano final)
        elseif lvl >= 45 then
            level_bonus = level_bonus + 0.20 -- Poder Transcendental Nv. 45 (+20% dano)
        elseif lvl >= 25 then
            level_bonus = level_bonus + 0.15 -- Maestria Avançada de Caminho Nv. 25 (+15% dano)
        elseif lvl >= 10 then
            level_bonus = level_bonus + 0.10 -- Especialização de Caminho Nv. 10 (+10% dano)
        end
        damage = damage * level_bonus
    end

    -- 5. Escala pelos 8 Atributos Alocáveis (STR, DEX, INT, SPI, MAS, LCK)
    -- STR aumenta dano físico/pesado
    if str > 5 and (class_id == 21 or class_id == 22 or class_id == 23 or class_id == 31 or class_id == 33 or class_id == 34 or class_id == 1 or class_id == 5 or class_id == 6 or class_id == 7 or class_id == 12 or class_id == 27 or class_id == 35 or class_id == 37 or class_id == 38) then
        damage = damage * (1.0 + (str - 5) * 0.03)
    end

    -- DEX aumenta dano de precisão / crítico / longo alcance
    if dex > 5 and (class_id == 19 or class_id == 20 or class_id == 25 or class_id == 26 or class_id == 32 or class_id == 34 or class_id == 3 or class_id == 4 or class_id == 9 or class_id == 10 or class_id == 11 or class_id == 28) then
        damage = damage * (1.0 + (dex - 5) * 0.03)
    end

    -- INT aumenta dano mágico / alquímico / rúnico
    if int_stat > 5 and (class_id == 20 or class_id == 24 or class_id == 25 or class_id == 32 or class_id == 34 or class_id == 2 or class_id == 8 or class_id == 9 or class_id == 11 or class_id == 35 or class_id == 36 or class_id == 29 or class_id == 30 or class_id == 39) then
        damage = damage * (1.0 + (int_stat - 5) * 0.03)
    end

    -- SPI aumenta dano/eficácia de classes divinas/espirituais/fera
    if spi > 5 and (class_id == 24 or class_id == 33 or class_id == 34 or class_id == 2 or class_id == 6 or class_id == 10 or class_id == 36 or class_id == 29 or class_id == 37) then
        damage = damage * (1.0 + (spi - 5) * 0.03)
    end

    -- 6. Bônus de Dano, Buff e Crítico
    local damage_bonus = 1.0
    local crit_chance = 0.10
    local crit_multiplier = 1.50

    -- Passivas das 12 Classes Básicas:
    -- ID 1 Guerreiro: Sangue de Batalha (+10% Dano com Espadas)
    if class_id == 1 then
        damage_bonus = damage_bonus + 0.10
    end
    -- ID 2 Mago: Ressonância Arcana (+20% Dano Mágico)
    if class_id == 2 then
        damage_bonus = damage_bonus + 0.20
    end
    -- ID 3 Arqueiro: Olho de Falcão (+20% Taxa Crítica à distância)
    if class_id == 3 then
        crit_chance = crit_chance + 0.20
    end
    -- ID 4 Assassino: Lâmina Silenciosa (+35% Dano Crítico ao atacar)
    if class_id == 4 then
        crit_multiplier = crit_multiplier + 0.35
    end
    -- ID 5 Lutador: Punhos de Ferro & Chi (ignora armadura / +15% dano base)
    if class_id == 5 then
        damage_bonus = damage_bonus + 0.15
    end
    -- ID 6 Escudeiro: Fortaleza Viva (converte defesa em ataque)
    if class_id == 6 then
        damage_bonus = damage_bonus + 0.10
    end
    -- ID 7 Ferreiro: Orgulho do Criador (+25% dano com armas forjadas)
    if class_id == 7 then
        damage_bonus = damage_bonus + 0.25
    end
    -- ID 8 Alquimista: Reação Sintética (+20% potência química)
    if class_id == 8 then
        damage_bonus = damage_bonus + 0.20
    end
    -- ID 9 Escultor: Olho da Escultura (+25% Dano Crítico)
    if class_id == 9 then
        crit_multiplier = crit_multiplier + 0.25
    end
    -- ID 10 Domador: Senhor da Matilha (+20% dano feroz)
    if class_id == 10 then
        damage_bonus = damage_bonus + 0.20
    end
    -- ID 11 Alfaiate de Guerra: Fios Monofilamento (+15% dano)
    if class_id == 11 then
        damage_bonus = damage_bonus + 0.15
    end
    -- ID 12 Chef de Caça: Células Gourmet (+15% dano, +30% se com buff)
    if class_id == 12 then
        damage_bonus = damage_bonus + (buff == 1 and 0.30 or 0.15)
    end

    -- Passivas das Variantes Secretas (13 a 18); as que dependem do alvo ficam no servidor
    -- ID 13 Espadachim Rúnico: Lâmina Elemental (+15% dano; golpes gelam o alvo no servidor)
    if class_id == 13 then
        damage_bonus = damage_bonus + 0.15
    end
    -- ID 15 Valquíria da Égide: Voo da Valquíria (+10% dano; esquiva custa metade da stamina no servidor)
    if class_id == 15 then
        damage_bonus = damage_bonus + 0.10
    end
    -- ID 16 Monge das Sombras: Golpe do Ponto Vital Furtivo (+30% chance crítica, +20% dano crítico)
    if class_id == 16 then
        crit_chance = crit_chance + 0.30
        crit_multiplier = crit_multiplier + 0.20
    end
    -- ID 17 Forjador de Armas Amaldiçoadas: Têmpera de Sangue (+10% dano; 25% de roubo de vida no servidor)
    if class_id == 17 then
        damage_bonus = damage_bonus + 0.10
    end

    -- Passivas das Classes Secretas:
    -- Rei-Fera (21): Presas de Prata Negra (+20% dano)
    if class_id == 21 then
        damage_bonus = damage_bonus + 0.20
    end
    -- Bastião do Mundo (23): Casco Continental converte 50% da Defesa em Ataque (+25% dano)
    if class_id == 23 then
        damage_bonus = damage_bonus + 0.25
    end
    -- Aristocrata Carmesim (25): Domínio da Noite (+40% à noite)
    if class_id == 25 and (world_hour >= 18 or world_hour < 6) then
        damage_bonus = damage_bonus + 0.40
    end
    -- Barão da Sucata (26): Ganância Explosiva (+15% chance crítica)
    if class_id == 26 then
        crit_chance = crit_chance + 0.15
    end
    -- Escultor do Luar Lendário (32): Destruição Escultural eleva o buff a +80% de ATK
    if class_id == 32 and buff == 1 then
        damage_bonus = damage_bonus + 0.55
    end
    -- Dançarino Astral (ClassID = 28): Passiva +25% de chance crítica permanente
    if class_id == 28 then
        crit_chance = crit_chance + 0.25
    end

    -- Domador Primordial (ClassID = 37): Passiva Espírito Alfa concede +25% de dano feroz constante
    if class_id == 37 then
        damage_bonus = damage_bonus + 0.25
    end

    -- Arauto da Tempestade (ClassID = 39): Passiva +35% de dano elétrico durante chuva (Weather == 1)
    if class_id == 39 and weather_type == 1 then
        damage_bonus = damage_bonus + 0.35
    end

    -- DEX e LCK aumentam a chance de crítico
    if dex > 5 then
        crit_chance = crit_chance + (dex - 5) * 0.005
    end
    if lck > 5 then
        crit_chance = crit_chance + (lck - 5) * 0.010
    end

    -- MAS aumenta o multiplicador de dano crítico (+4% por ponto)
    if mas > 5 then
        crit_multiplier = crit_multiplier + (mas - 5) * 0.04
    end

    -- Licantropo Primordial (RaceID = 6): +30% de dano físico permanente
    if race_id == 6 then
        damage_bonus = damage_bonus + 0.30
    end

    -- Condição de noite: 18:00 às 05:59
    local is_night = (world_hour >= 18 or world_hour < 6)

    -- Amaldiçoado das Cinzas / Revenant (RaceID = 7): +25% de dano noturno
    if race_id == 7 and is_night then
        damage_bonus = damage_bonus + 0.25
    end

    -- Sylvari (RaceID = 19): +15% de dano de Dia ou na Chuva
    local is_day = (world_hour >= 6 and world_hour < 18)
    if race_id == 19 and (is_day or weather_type == 1) then
        damage_bonus = damage_bonus + 0.15
    end

    -- Boreal (RaceID = 24): Ataques criogênicos (+10% dano frio)
    if race_id == 24 then
        damage_bonus = damage_bonus + 0.10
    end

    -- Thalassiano (RaceID = 25): +25% de dano total na Chuva (Weather == 1)
    if race_id == 25 and weather_type == 1 then
        damage_bonus = damage_bonus + 0.25
    end

    -- Cambion (RaceID = 26): Sangue de Enxofre (+15% a +35% de dano em combate)
    if race_id == 26 then
        damage_bonus = damage_bonus + 0.15
    end

    -- Nephilim (RaceID = 27): De Noite causa +20% de dano sombrio
    if race_id == 27 and is_night then
        damage_bonus = damage_bonus + 0.20
    end

    -- Quadrante 5: Passivas das 18 Novas Raças (29 a 46)
    -- Meio-Celestial (RaceID = 29): Passiva Ser de Luz (+100% dano durante Eclipse, Lua de Sangue ou contra Trevas)
    if race_id == 29 and (moon_phase == 8 or moon_phase == 9 or is_night) then
        damage_bonus = damage_bonus + 1.00
    end

    -- Pyromante (RaceID = 30): Passiva Fulgor (+25% dano base de fogo, dobra dano se buff ativo sob Combustão)
    if race_id == 30 then
        if buff == 1 then
            damage_bonus = damage_bonus + 1.00
        else
            damage_bonus = damage_bonus + 0.25
        end
    end

    -- Gigante de Gelo (RaceID = 31): Passiva Pele Gélida (+25% de dano criogênico no frio/neblina)
    if race_id == 31 and (weather_type == 2 or weather_type == 3) then
        damage_bonus = damage_bonus + 0.25
    end

    -- Drago Terra (RaceID = 32): Passiva Couraça Ancestral (+15% dano sísmico)
    if race_id == 32 then
        damage_bonus = damage_bonus + 0.15
    end

    -- Drago Água (RaceID = 33): Passiva Lima da Água (+25% dano com armas brancas e na chuva/água)
    if race_id == 33 and weather_type == 1 then
        damage_bonus = damage_bonus + 0.25
    end

    -- Drago Raio (RaceID = 34): Passiva Para-Raios (+20% de esquiva e +20% crítico de choque)
    if race_id == 34 then
        crit_chance = crit_chance + 0.20
    end

    -- Drago Místico (RaceID = 35): Passiva Sangue Místico (+30% Poder Mágico)
    if race_id == 35 then
        damage_bonus = damage_bonus + 0.30
    end

    -- Orc (RaceID = 36): Passiva Músculos de Aço (+25% dano físico corpo a corpo)
    if race_id == 36 then
        damage_bonus = damage_bonus + 0.25
    end

    -- Anão (RaceID = 37): Passiva Ímpeto da Forja (+15% dano em golpes pesados)
    if race_id == 37 then
        damage_bonus = damage_bonus + 0.15
    end

    -- Elfo (RaceID = 38): Passiva Pés Velozes & Corpo Esguio (+15% precisão/magia e velocidade)
    if race_id == 38 then
        damage_bonus = damage_bonus + 0.15
        crit_chance = crit_chance + 0.15
    end

    -- Elfo Solar (RaceID = 39): Passiva Caminho Solar (+25% dano de dia)
    if race_id == 39 and is_day then
        damage_bonus = damage_bonus + 0.25
    end

    -- Elfo Lunar (RaceID = 40): Passiva Visão nas Trevas (+25% dano à noite)
    if race_id == 40 and is_night then
        damage_bonus = damage_bonus + 0.25
    end

    -- Fadinha (RaceID = 41): Passiva Espírito da Natureza (+15% poder arcano elemental)
    if race_id == 41 then
        damage_bonus = damage_bonus + 0.15
    end

    -- Goblin (RaceID = 42): Passiva Cleptomancia (+20% chance de acerto crítico)
    if race_id == 42 then
        crit_chance = crit_chance + 0.20
    end

    -- Demi-Humano Escorpião (RaceID = 43): Passiva Sangue Ruim (+25% dano venenoso/perfurante)
    if race_id == 43 then
        damage_bonus = damage_bonus + 0.25
    end

    -- Demi-Humano Tartaruga (RaceID = 44): Passiva Armadura Orgânica (+20% dano de retaliação pesada)
    if race_id == 44 then
        damage_bonus = damage_bonus + 0.20
    end

    -- Meio-Demônio / Succubus (RaceID = 45): Passiva Aparência Inofensiva (+25% dano arcano/sedução)
    if race_id == 45 then
        damage_bonus = damage_bonus + 0.25
    end

    -- Demi-Humano Lobo (RaceID = 46): Passiva Olfato & Instinto (+30% dano bestial constante)
    if race_id == 46 then
        damage_bonus = damage_bonus + 0.30
    end

    -- Manamante (RaceID = 47): Afinidade Mágica (+18% dano, conjura com a própria Vida)
    if race_id == 47 then
        damage_bonus = damage_bonus + 0.18
    end

    -- Buff do Ferreiro (Afiação de Combate) e Poção de Sangue Lupino (+20% Crítico)
    if buff == 1 then
        damage_bonus = damage_bonus + 0.25
        crit_chance = crit_chance + 0.20
    end

    -- Normaliza porcentagem de HP (suporta 0.0 - 1.0 ou 0 - 100)
    local current_hp_pct = (hp_pct or 1.0)
    if current_hp_pct > 1.0 then
        current_hp_pct = current_hp_pct / 100.0
    end

    -- Passiva Varkai: +20% de dano feroz quando HP <= 35%
    if (race_id == 4 or race_id == 6) and current_hp_pct <= 0.35 then
        damage_bonus = damage_bonus + 0.20
    end

    -- Passiva Inquisidor das Cinzas (ClassID = 29): até +60% de dano com vida baixa
    if class_id == 29 then
        local missing_hp = 1.0 - current_hp_pct
        if missing_hp < 0 then
            missing_hp = 0
        end
        damage_bonus = damage_bonus + (missing_hp * 0.60)
    end

    -- Condição de empoderamento lunar: Noite (18:00 às 05:59) ou Eclipse Total (fase 9)
    local is_night = (world_hour >= 18 or world_hour < 6)
    local is_lunar = is_night or (moon_phase == 9)

    if is_lunar then
        if moon_phase == 0 then
            -- Lua Nova: Batedor (2) e Noctari (2) ganham +25% de chance crítica nas sombras
            if class_id == 2 or race_id == 2 then
                crit_chance = crit_chance + 0.25
            end
        elseif moon_phase == 2 then
            -- Quarto Crescente: +10% de dano nos ataques básicos
            if action_type == 1 then
                damage_bonus = damage_bonus + 0.10
            end
        elseif moon_phase == 3 then
            -- Gibosa Crescente: +15% de dano em Skills (Q, R, F) e para Iniciado
            if action_type >= 3 or class_id == 3 then
                damage_bonus = damage_bonus + 0.15
            end
        elseif moon_phase == 4 then
            -- Lua Cheia: Noctari ganha +25% de dano lunar e +25% de chance crítica
            if race_id == 2 then
                damage_bonus = damage_bonus + 0.25
                crit_chance = crit_chance + 0.25
            end
        elseif moon_phase == 5 then
            -- Gibosa Minguante: Espadachim (1), Ferreiro (5), Artífice (8) e Kharad (3) ganham +15% de dano pesado
            if class_id == 1 or class_id == 5 or class_id == 8 or race_id == 3 then
                damage_bonus = damage_bonus + 0.15
            end
        elseif moon_phase == 6 then
            -- Quarto Minguante: Acólito (4) ganha +20% de bônus de dano sagrado
            if class_id == 4 then
                damage_bonus = damage_bonus + 0.20
            end
        elseif moon_phase == 7 then
            -- Lua Minguante: Varkai (4), Dhampir (5) e Ceifador (7) ganham +15% de dano feroz
            if race_id == 4 or race_id == 5 or class_id == 7 then
                damage_bonus = damage_bonus + 0.15
            end
        elseif moon_phase == 8 then
            -- Lua de Sangue: +25% de dano global, +40% para Dhampir (5) ou Ceifador (7)
            damage_bonus = damage_bonus + 0.25
            if race_id == 5 or class_id == 7 then
                damage_bonus = damage_bonus + 0.40
            end
        elseif moon_phase == 9 then
            -- Eclipse Total: +30% de dano crítico para todas as classes; Ceifador ganha +20% extra
            crit_multiplier = crit_multiplier + 0.30
            if class_id == 7 then
                damage_bonus = damage_bonus + 0.20
            end
        end
    end

    damage = damage * damage_bonus

    -- Rolagem de Acerto Crítico
    local is_crit = 0
    if math.random() < crit_chance then
        is_crit = 1
        damage = damage * crit_multiplier
    end

    return math.floor(damage + 0.5), is_crit
end
