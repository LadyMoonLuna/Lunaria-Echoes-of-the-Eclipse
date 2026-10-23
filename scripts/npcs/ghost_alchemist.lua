-- ghost_alchemist.lua — Script de Comportamento para O Alquimista Esquecido (ID 110)
-- Localização: Entrada Secreta dos Esgotos em (-21.0, 0.0, -21.0)
-- Ativo durante a madrugada (00h às 04h, especialmente às 03h).
-- Conversa com quem ouviu a história da Lyra e ensina segredos proibidos.

local current_routine = "asleep_in_sewers"

function OnTick(world_hour, npc_id, pos_x, pos_z)
    -- Só surge como espírito etéreo entre 00h e 04h da madrugada nos Esgotos Antigos (ZoneID 8 em -110.0, 110.0)
    if world_hour >= 0 and world_hour <= 4 then
        npc_set_zone(8)
        npc_set_active(true)
        if pos_x ~= -110.0 or pos_z ~= 110.0 then
            npc_teleport(-110.0, 0.0, 110.0)
        end
        current_routine = "manifested_spirit"
    else
        -- Durante as demais horas (05h às 23h), fica adormecido e invisível nas profundezas dos esgotos
        npc_set_active(false)
        current_routine = "asleep_in_sewers"
    end
end

function OnPlayerApproach(player_id, distance, player_race)
    local hour = get_world_hour()
    if hour < 0 or hour > 4 then
        return
    end

    if hour == 3 then
        npc_say("... Sussurros no vapor esmeralda... A hora da traição soou... Às três badaladas, as correntes se partem...")
    else
        npc_say("... Quem perturba o lamento do alquimista esquecido sob as pedras da vila?...")
    end
end

function OnPlayerInteract(player_id, world_hour, player_race, player_class, player_mas, friendship_level)
    if world_hour < 0 or world_hour > 4 then
        return
    end

    local f_level = friendship_level or 0

    -- Conexão Emocional com Lyra
    if f_level >= 2 then
        npc_say("... Você... Você traz o perfume de lírios e lavanda alquímica... É o cheiro do laboratório da minha aluna, Lyra! Então ela sobreviveu à purga do conselho e ainda se lembra do velho mestre? Que bênção para esta alma penada...")
        return
    end

    -- Se for Alquimista ou tiver alta Maestria Anatômica/Alquímica
    if player_class == 6 or (player_mas and player_mas >= 10) then
        npc_say("... Vejo que você conhece a arte dos frascos e da dissecação. O conselho me jogou aqui por tentar fundir a essência das feras do Eclipse ao sangue humano. Tome esta fórmula proibida... Use os órgãos extraídos de monstros raros para destilar poções que nenhum alquimista vivo ousaria sonhar...")
        return
    end

    -- Diálogo geral na calada da noite
    if world_hour == 3 then
        npc_say("... Foi exatamente às 03:00 da manhã que os guardas do antigo conselho arrombaram minhas portas, confiscaram meus tomos e me atiraram neste fosso subterrâneo. Mas meu conhecimento não morreu... Ele se tornou eterno nas trevas. Traga-me néctar das feras sombrias e revelarei as transmutações proibidas de Lunaria...")
    else
        npc_say("... O tempo é efêmero, viajante. Entre a meia-noite e a alvorada, os véus entre o laboratório físico e o plano espectral se dissolvem. Ouça o aviso: não confie cegamente nos governantes da superfície...")
    end
end
