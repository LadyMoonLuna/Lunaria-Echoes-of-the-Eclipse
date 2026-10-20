-- autopsy.lua — Sistema Autoritativo de Desmantelamento Anatômico (Autópsia)
-- Calcula a precisão do corte anatômico, margem da Zona Verde via Perícia (MAS) e bônus de Sorte (LCK).

-- Tiers de Qualidade:
-- 1 = Perfeito (Durabilidade máxima, integridade anatômica impecável)
-- 2 = Comum (Qualidade padrão / Rasgado)
-- 3 = Destruído (Lixo Orgânico / Descarte)

-- Tipos de Órgãos Vitais:
-- 1 = Pele / Couro
-- 2 = Presas / Garras
-- 3 = Glândula de Veneno (Delicado)
-- 4 = Sangue / Fluidos Vitais
-- 5 = Coração / Relíquia Arcana (Cirúrgico)

function CalculateAutopsyResult(player_mas_stat, player_luck_stat, organ_type, player_click_accuracy, player_race_id)
    local mas = tonumber(player_mas_stat) or 0
    local lck = tonumber(player_luck_stat) or 0
    local organ = tonumber(organ_type) or 1
    local acc = tonumber(player_click_accuracy) or 0.0
    local race = tonumber(player_race_id) or 0

    -- Normaliza para escala 0.0 a 1.0 se passado como percentual (0 a 100)
    if acc > 1.0 then
        acc = acc / 100.0
    end

    -- Se o tempo expirou ou o clique foi fora da barra (acc <= 0)
    if acc <= 0.0 then
        return 3
    end

    -- Dificuldade base do órgão (limiar mínimo de precisão para Zona Verde e Zona Amarela)
    local base_green_threshold = 0.85
    local base_yellow_threshold = 0.50

    if organ == 3 then
        -- Glândula de Veneno: Muito frágil, risco de romper
        base_green_threshold = 0.88
        base_yellow_threshold = 0.55
    elseif organ == 5 then
        -- Coração / Relíquia Arcana: Requer precisão cirúrgica
        base_green_threshold = 0.90
        base_yellow_threshold = 0.60
    end

    -- Perícia (MAS): Cada ponto amplia a margem de erro da Zona Verde em +2.5% (+0.025)
    -- Isso diminui a precisão mínima exigida para alcançar a Zona Verde.
    local mas_bonus = mas * 0.025

    -- Passiva Aracne (Raça 21): Tecelão anatômico amplia a Zona Verde em +35% (+0.12 na tolerância)
    if race == 21 then
        mas_bonus = mas_bonus + 0.12
    end

    local green_threshold = base_green_threshold - mas_bonus
    if green_threshold < 0.25 then
        green_threshold = 0.25 -- Limite mínimo da Zona Verde
    end

    -- Zona Amarela também expande proporcionalmente com a Perícia
    local yellow_threshold = base_yellow_threshold - (mas * 0.015)
    if yellow_threshold < 0.15 then
        yellow_threshold = 0.15
    end

    -- 1. Zona Verde: Acerto Perfeito
    if acc >= green_threshold then
        return 1
    end

    -- 2. Zona Amarela: Acerto Comum com chance de sorte
    if acc >= yellow_threshold then
        -- Sorte (LCK): Concede chance passiva de elevar um acerto comum para perfeito (+1.5% por ponto)
        local luck_chance = lck * 0.015
        if luck_chance > 0.40 then
            luck_chance = 0.40 -- Teto máximo de 40% de salvamento por sorte
        end

        if math.random() < luck_chance then
            return 1 -- Elevado para Perfeito pela Sorte!
        end

        return 2 -- Qualidade Comum / Rasgado
    end

    -- 3. Zona Vermelha ou Erro de Tempo: Destruído
    return 3
end
