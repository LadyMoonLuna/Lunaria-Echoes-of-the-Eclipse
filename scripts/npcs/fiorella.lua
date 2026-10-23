-- fiorella.lua — Madame Fiorella Agulhadouro, Tecelã Carmesim (ID 114)
-- Local: Ateliê Carmesim (40, 0, 35), Vila. Loja aberta das 08h às 20h.
-- História: costureira da corte de Aurelith que descobriu que fios de aço encantados cortam
-- melhor que espadas. Fugiu de um casamento arranjado costurando o noivo na cortina.
-- Pessoal: 45 anos, Cambion, chama todos de "darling", coleciona botões raros.
-- Presente favorito: Amuleto de Prata da Lua.

function OnTick(world_hour, npc_id, pos_x, pos_z)
    npc_set_active(true)
end

function OnPlayerApproach(player_id, distance, player_race)
    local hour = get_world_hour()
    if hour >= 8 and hour < 20 then
        npc_say("Entre, darling, entre! Esse traje de viagem está implorando por um conserto!")
    else
        npc_say("O Ateliê está fechado, darling. Mas pode admirar a vitrine à vontade.")
    end
end

function OnPlayerInteract(player_id, world_hour, player_race, player_class, player_mas, friendship_level)
    local f = friendship_level or 0
    if player_class == 11 then
        if f >= 3 then
            npc_say("Segredo de ateliê: a prata da lua deixa o fio mais firme. Se achar um Amuleto de Prata da Lua, traga para mim, darling.")
        else
            npc_say("Seus fios alcançam dez metros, darling — longe o bastante para costurar um lobo antes que ele chegue perto do seu sapato.")
        end
        return
    end
    if f >= 4 then
        npc_say("Quer uma fofoca? O Capitão Randel usa ceroulas bordadas com coraçõezinhos. Fui eu que bordei. Shhh!")
    else
        npc_say("Mantos, luvas, carretéis de aço... e para os corajosos, agulhas rúnicas. Escolha com o coração, pague com o ouro.")
    end
end
