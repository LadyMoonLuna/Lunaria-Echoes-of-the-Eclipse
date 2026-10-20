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

    -- 1. Dano Base por Classe (1 a 15)
    local damage = 20
    if class_id == 0 then
        damage = 18 -- Viajante / Sem Classe (Tier 0)
    elseif class_id == 1 then
        damage = 28 -- Espadachim
    elseif class_id == 2 then
        damage = 24 -- Batedor
    elseif class_id == 3 then
        damage = 35 -- Iniciado
    elseif class_id == 4 then
        damage = 22 -- Acólito
    elseif class_id == 5 then
        damage = 32 -- Ferreiro (Profissão de Combate)
    elseif class_id == 6 then
        damage = 26 -- Alquimista (Profissão de Combate)
    elseif class_id == 7 then
        damage = 42 -- Ceifador do Eclipse (Classe Secreta)
    elseif class_id == 8 then
        damage = 38 -- Artífice Rúnico (Classe Secreta)
    elseif class_id == 9 then
        damage = 36 -- Criador de Homúnculos (Classe Secreta)
    elseif class_id == 10 then
        damage = 40 -- Dançarino Astral (Classe Secreta)
    elseif class_id == 11 then
        damage = 38 -- Inquisidor das Cinzas (Classe Secreta)
    elseif class_id == 12 then
        damage = 34 -- Necromante de Ossos (Classe Secreta)
    elseif class_id == 13 then
        damage = 39 -- Domador Primordial (Classe Secreta)
    elseif class_id == 14 then
        damage = 44 -- Cavaleiro da Ruptura (Classe Secreta)
    elseif class_id == 15 then
        damage = 36 -- Arauto da Tempestade (Classe Secreta)
    end

    -- 2. Multiplicador de Ação (ActionType)
    if action_type == 2 then
        return 0, 0 -- Esquiva não causa dano
    elseif action_type == 3 then
        -- Habilidade 1 [Tecla Q]
        if class_id == 10 then
            damage = damage * 2.00 -- Dançarino: Corte Cadente (2.0x)
        elseif class_id == 11 then
            damage = damage * 2.20 -- Inquisidor: Chicote de Penitência (2.2x)
        elseif class_id == 12 then
            damage = damage * 2.00 -- Necromante: Lança de Fêmur (2.0x)
        elseif class_id == 13 then
            damage = damage * 2.10 -- Domador: Investida do Alfa (2.1x)
        elseif class_id == 14 then
            damage = damage * 1.90 -- Cavaleiro: Esmagamento Gravitacional (1.9x)
        elseif class_id == 15 then
            damage = damage * 2.10 -- Arauto: Lança do Trovão (2.1x)
        else
            damage = damage * 1.75 -- Base Q
        end
    elseif action_type == 4 then
        -- Habilidade 2 [Tecla R]
        if class_id == 10 then
            damage = damage * 1.80 -- Dançarino: Valsa dos Espelhos
        elseif class_id == 11 then
            damage = damage * 1.75 -- Inquisidor: Selo de Excomunhão
        elseif class_id == 12 then
            damage = damage * 1.80 -- Necromante: Explosão Óssea
        elseif class_id == 13 then
            damage = damage * 1.60 -- Domador: Uivo da Alcateia
        elseif class_id == 14 then
            damage = damage * 2.00 -- Cavaleiro: Singularidade Reversa
        elseif class_id == 15 then
            damage = damage * 1.75 -- Arauto: Passo de Relâmpago
        else
            damage = damage * 1.90 -- Base R
        end
    elseif action_type == 5 then
        -- Habilidade 3 [Tecla F] - Ultimate
        if class_id == 10 then
            damage = damage * 3.00 -- Dançarino: Constelação de Mil Lâminas (3.0x)
        elseif class_id == 11 then
            damage = damage * 3.20 -- Inquisidor: Crucificação de Cinzas (3.2x)
        elseif class_id == 12 then
            damage = damage * 3.00 -- Necromante: Legião do Ossuário (3.0x)
        elseif class_id == 13 then
            damage = damage * 3.00 -- Domador: Fúria do Behemoth (3.0x)
        elseif class_id == 14 then
            damage = damage * 2.80 -- Cavaleiro: Colapso Estelar (2.8x)
        elseif class_id == 15 then
            damage = damage * 3.10 -- Arauto: Ira dos Céus (3.1x)
        else
            damage = damage * 2.40 -- Base Ultimate
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
    -- STR aumenta dano melee (Espadachim, Ferreiro, Ceifador, Artífice, Domador, Cavaleiro da Ruptura)
    if str > 5 and (class_id == 1 or class_id == 5 or class_id == 7 or class_id == 8 or class_id == 13 or class_id == 14) then
        damage = damage * (1.0 + (str - 5) * 0.03)
    end

    -- DEX aumenta dano ranged / agilidade (Batedor, Alquimista, Criador, Dançarino Astral)
    if dex > 5 and (class_id == 2 or class_id == 6 or class_id == 9 or class_id == 10) then
        damage = damage * (1.0 + (dex - 5) * 0.03)
    end

    -- INT aumenta dano mágico/alquímico (Iniciado, Alquimista, Artífice, Criador, Inquisidor, Necromante, Arauto)
    if int_stat > 5 and (class_id == 3 or class_id == 6 or class_id == 8 or class_id == 9 or class_id == 11 or class_id == 12 or class_id == 15) then
        damage = damage * (1.0 + (int_stat - 5) * 0.03)
    end

    -- SPI aumenta dano/eficácia de classes divinas/espirituais (Acólito, Inquisidor, Domador)
    if spi > 5 and (class_id == 4 or class_id == 11 or class_id == 13) then
        damage = damage * (1.0 + (spi - 5) * 0.03)
    end

    -- 6. Bônus de Dano, Buff e Crítico
    local damage_bonus = 1.0
    local crit_chance = 0.10
    local crit_multiplier = 1.50

    -- Dançarino Astral (ClassID = 10): Passiva +25% de chance crítica permanente
    if class_id == 10 then
        crit_chance = crit_chance + 0.25
    end

    -- Domador Primordial (ClassID = 13): Passiva Espírito Alfa concede +25% de dano feroz constante
    if class_id == 13 then
        damage_bonus = damage_bonus + 0.25
    end

    -- Arauto da Tempestade (ClassID = 15): Passiva +35% de dano elétrico durante chuva (Weather == 1)
    if class_id == 15 and weather_type == 1 then
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

    -- Passiva Inquisidor das Cinzas (ClassID = 11): até +60% de dano com vida baixa
    if class_id == 11 then
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
