-- guard.lua — Comportamento dos Guardas da Patrulha Real (IDs 105 e 106)

-- OnTick é chamado a cada segundo pelo servidor autoritativo
function OnTick(world_hour, npc_id, pos_x, pos_z)
    -- 1. Defesa Perimetral: Verifica se há algum mob próximo ao guarda
    local mob_id, mob_type, dist, mx, mz = get_nearby_mob(7.0)
    if mob_id and mob_id > 0 then
        npc_say("Pela Guarda Real! Em guarda, monstro!")
        npc_attack_mob(mob_id, 70)
        return
    end

    -- Nota: A rota contínua de patrulha por waypoints com inspeção de 3.0s (<= 0.4m)
    -- é gerenciada a 30 Hz pelo servidor Go de forma suave e contínua.
end

-- OnPlayerApproach é disparado quando o jogador chega a menos de 4.0m
function OnPlayerApproach(player_id, distance, player_race, is_armed)
    -- Se o jogador se aproximar portando arma em riste ou se for da raça Varkai (4), Dhampir (5) ou Licantropo (6)
    if is_armed or player_race == 4 or player_race == 5 or player_race == 6 then
        npc_say("Mantenha a linha, viajante. Sem problemas na nossa vila.")
        return
    end

    if player_race == 7 then
        npc_say("Mantenha a linha, viajante. Sinto um frio sepulcral em seus passos... Sem problemas na nossa vila.")
        return
    end

    npc_say("Vila sob proteção da Guarda Real. Mantenha a ordem e aproveite sua estadia.")
end

-- OnPlayerInteract é disparado ao pressionar a tecla de interação
function OnPlayerInteract(player_id, world_hour, player_race, player_class, player_mas)
    if player_class == 0 then
        npc_say("Um viajante sem treinamento militar? Posso ensiná-lo as táticas de lâmina e escudo da Guarda Real! Agora você marchará como um Espadachim (Tier 1)!")
        return
    end

    if player_race == 4 or player_race == 5 or player_race == 6 then
        npc_say("Mantenha a linha, viajante. Sem problemas na nossa vila. Nossos olhos e espadas estão vigilantes.")
        return
    end

    npc_say("Fazemos a ronda dia e noite entre o Portão e a Forja para manter as feras e saqueadores longe dos cidadãos.")
end

-- OnMobAttackNearby é disparado pelo servidor se um mob atacar nas proximidades do guarda
function OnMobAttackNearby(mob_id, mob_type, dist)
    npc_say("Pela Guarda Real! Afaste-se da vila, criatura!")
    npc_attack_mob(mob_id, 75)
end
