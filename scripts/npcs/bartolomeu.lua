-- bartolomeu.lua — Chef Bartolomeu Brasa-Alta, Mestre do Banquete (ID 115)
-- Local: cozinha da Taverna (-38, 0, 22), Vila. Cozinha aberta das 10h às 02h.
-- História: ex-cozinheiro de navio Thalassiano. Naufragou numa ilha de monstros e sobreviveu
-- três anos cozinhando tudo que tentava devorá-lo. Voltou com um cutelo gigante e um wok de ferro.
-- Pessoal: 52 anos, Orkhan, bigode trançado, chora cortando cebola e diz que é "o vapor".
-- Presente favorito: Sangue Lupino Fresco.

function OnTick(world_hour, npc_id, pos_x, pos_z)
    npc_set_active(true)
end

function OnPlayerApproach(player_id, distance, player_race)
    local hour = get_world_hour()
    if hour >= 11 and hour < 14 then
        npc_say("Hora do almoço! Ensopado de javali com cogumelos do Bosque! Sente-se, sente-se!")
    elseif hour >= 18 and hour < 23 then
        npc_say("A taverna está cheia hoje! Cuidado com a sopa, está pelando!")
    else
        npc_say("Ah, um cliente com cara de fome. Conheço essa cara — eu tive essa cara por três anos naquela ilha.")
    end
end

function OnPlayerInteract(player_id, world_hour, player_race, player_class, player_mas, friendship_level)
    local f = friendship_level or 0
    if player_class == 12 then
        if f >= 3 then
            npc_say("Dica do chef: sangue de lobo fresco é o segredo do meu chouriço. Colete com um Frasco Vazio e traga para a cozinha!")
        else
            npc_say("Na autópsia, corte com calma: um chef do Banquete enxerga cortes perfeitos onde os outros só veem bagunça.")
        end
        return
    end
    if f >= 4 then
        npc_say("Sabe por que meu wok é tão preto? Foi na barriga de uma Hidra. Ela me engoliu, eu cozinhei ela por dentro. História real!")
    else
        npc_say("Comida boa é a melhor magia que existe. Sente-se e conte suas aventuras enquanto o ensopado ferve.")
    end
end
