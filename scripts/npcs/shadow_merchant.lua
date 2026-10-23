-- shadow_merchant.lua — Comportamento de Varis, o Contrabandista (ID 104)

-- OnTick é chamado a cada segundo para alternar o ciclo de atividade noturna
function OnTick(world_hour, npc_id, pos_x, pos_z)
    if world_hour >= 18 or world_hour < 6 then
        -- Ativo à noite (18h às 05h59): Abre loja dentro do Mercado Negro (ZoneID 7 em 0.0, 10.0)
        npc_set_zone(7)
        npc_set_active(true)
        npc_set_shop_open(true)
        npc_set_state(2) -- Atendendo na tenda sombria
        if pos_x ~= 0.0 or pos_z ~= 10.0 then
            npc_teleport(0.0, 0.0, 10.0)
        end
    else
        -- De dia (06h às 17h59): Fora de serviço e escondido
        npc_set_zone(0)
        npc_set_shop_open(false)
        npc_set_active(false)
        npc_set_state(255)
        npc_teleport(-50.0, 0.0, 48.0)
    end
end

-- OnPlayerApproach é disparado na aproximação a menos de 4.0m
function OnPlayerApproach(player_id, distance, player_race)
    local hour = get_world_hour()
    -- Só responde se for noite
    if hour >= 6 and hour < 18 then
        return
    end

    -- Reatividade especial na aproximação para Dhampir (5), Licantropo (6) ou Revenant (7)
    if player_race == 5 or player_race == 6 or player_race == 7 then
        npc_say("Pssiu... Sinto o cheiro da noite e das cinzas em você. Aproxime-se, criatura das trevas...")
    else
        npc_say("Pssiu... O que brilha na escuridão me interessa.")
    end
end

-- OnPlayerInteract é disparado quando o jogador aperta a tecla de interação
function OnPlayerInteract(player_id, world_hour, player_race, player_class, player_mas)
    -- Só responde se world_hour >= 18 or world_hour < 6
    if world_hour >= 6 and world_hour < 18 then
        return
    end

    -- Cumprimento sombrio para raças secretas Dhampir (5) ou Revenant (7)
    if player_race == 5 or player_race == 7 then
        npc_say("Pssiu... Saudações das trevas, viajante do crepúsculo. Reconheço o sangue frio e o olhar sem vida de um " .. (player_race == 5 and "Dhampir" or "Revenant") .. ". Os tolos da vila temem a noite, mas nós conhecemos seus segredos. Traga-me glândulas venenosas e garras de feras; guardo cálices de almas esquecidas e relíquias que você saberá bem como usar.")
        return
    elseif player_race == 6 then
        npc_say("Pssiu... Esse poder bestial primitivo... Um Licantropo Primordial nas sombras da taverna! Mantenha a guarda baixa perto de mim e seus segredos estarão seguros.")
        return
    end

    -- Diálogo padrão para viajantes comuns à noite
    npc_say("Pssiu... O que brilha na escuridão me interessa. Não faça perguntas aos guardas sobre minha presença aqui. Se você trouxer materiais perigosos da floresta escura, tenho itens raros e recipientes arcanos que nenhum lojista comum ousaria vender.")
end
