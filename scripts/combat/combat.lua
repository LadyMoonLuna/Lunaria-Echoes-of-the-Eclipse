-- combat.lua — Sistema de Dano e Reações Lunares (Marco 3)

-- Raças:
-- 1 = Valeriano
-- 2 = Noctari
-- 3 = Kharad
-- 4 = Varkai
-- 5 = Dhampir (Secreta)

-- Classes:
-- 1 = Espadachim
-- 2 = Batedor
-- 3 = Iniciado
-- 4 = Acólito

-- Ações:
-- 1 = Ataque Básico
-- 2 = Esquiva (Dodge Roll)
-- 3 = Habilidade Especial (Tecla Q)

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

function CalculateDamage(race_id, class_id, action_type, hp_pct, world_hour, moon_phase, weather_type)
    -- 1. Dano Base por Classe
    local damage = 20
    if class_id == 1 then
        damage = 28 -- Espadachim
    elseif class_id == 2 then
        damage = 24 -- Batedor
    elseif class_id == 3 then
        damage = 35 -- Iniciado
    elseif class_id == 4 then
        damage = 22 -- Acólito
    end

    -- Multiplicador da Skill Especial (Q)
    if action_type == 3 then
        damage = damage * 1.75
    end

    -- Bônus de Dano e Crítico
    local damage_bonus = 1.0
    local crit_chance = 0.10
    local crit_multiplier = 1.50

    -- Normaliza porcentagem de HP (suporta 0.0 - 1.0 ou 0 - 100)
    local current_hp_pct = (hp_pct or 1.0)
    if current_hp_pct > 1.0 then
        current_hp_pct = current_hp_pct / 100.0
    end

    -- Passiva Varkai: +20% de dano feroz quando HP <= 35%
    if race_id == 4 and current_hp_pct <= 0.35 then
        damage_bonus = damage_bonus + 0.20
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
            -- Gibosa Crescente: +15% de dano em Skills e para Iniciado
            if action_type == 3 or class_id == 3 then
                damage_bonus = damage_bonus + 0.15
            end
        elseif moon_phase == 4 then
            -- Lua Cheia: Noctari ganha +25% de dano lunar e +25% de chance crítica
            if race_id == 2 then
                damage_bonus = damage_bonus + 0.25
                crit_chance = crit_chance + 0.25
            end
        elseif moon_phase == 5 then
            -- Gibosa Minguante: Espadachim e Kharad ganham +15% de dano pesado
            if class_id == 1 or race_id == 3 then
                damage_bonus = damage_bonus + 0.15
            end
        elseif moon_phase == 6 then
            -- Quarto Minguante: Acólito ganha +20% de bônus de dano sagrado
            if class_id == 4 then
                damage_bonus = damage_bonus + 0.20
            end
        elseif moon_phase == 7 then
            -- Lua Minguante: Varkai e Dhampir ganham +15% de dano feroz
            if race_id == 4 or race_id == 5 then
                damage_bonus = damage_bonus + 0.15
            end
        elseif moon_phase == 8 then
            -- Lua de Sangue: +25% de dano global e +40% se for Dhampir
            damage_bonus = damage_bonus + 0.25
            if race_id == 5 then
                damage_bonus = damage_bonus + 0.40
            end
        elseif moon_phase == 9 then
            -- Eclipse Total: +30% de dano crítico para todas as classes
            crit_multiplier = crit_multiplier + 0.30
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
