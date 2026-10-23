-- aurelius.lua — Script de Comportamento para Mestre Aurelius, o Arquimago (ID 108)
-- Localização: Torre Arcana em (20.0, 0.0, -18.0)
-- Ensina a classe Iniciado (ClassID = 3) e comenta sobre as fases da lua e anomalias arcanas.

local current_routine = "in_tower"

function OnTick(world_hour, npc_id, pos_x, pos_z)
    npc_set_active(true)
    if world_hour >= 6 and world_hour < 18 then
        -- Horário Diurno (06h às 17h59): Dentro da Torre Arcana (ZoneID 6 em 0.0, 15.0)
        current_routine = "day_study"
        if npc_get_zone() ~= 6 then
            npc_set_zone(6)
            npc_teleport(0.0, 0.0, 15.0)
        end
    else
        -- Horário Noturno (18h às 05h59): Usa o portal para observar as estrelas no pátio da Torre (ZoneID 0 em 50.0, -38.0)
        current_routine = "night_astronomy"
        if npc_get_zone() ~= 0 then
            npc_set_zone(0)
            npc_teleport(50.0, 0.0, -38.0)
        end
    end
end

function OnPlayerApproach(player_id, distance, player_race)
    local hour = get_world_hour()
    local moon = get_moon_phase()

    if moon == 8 then
        npc_say("Fascinante e aterrorizante! A Lua de Sangue gera uma refração no éter que duplica o poder dos rituais necromânticos!")
        return
    elseif moon == 9 then
        npc_say("O Sol Negro eclipsado! O equilíbrio gravitacional do mana está entrando em colapso cósmico!")
        return
    end

    if hour >= 6 and hour < 18 then
        npc_say("Aproxime-se, buscador do saber. Os cristais ciano ressoam com intensidade nesta hora do dia.")
    else
        npc_say("Uma noite estelar perfeita para contemplar o movimento orbital das luas de Lunaria.")
    end
end

function OnPlayerInteract(player_id, world_hour, player_race, player_class, player_mas, friendship_level)
    local f_level = friendship_level or 0
    local moon = get_moon_phase()

    -- Viajante Sem Classe (ClassID == 0): Iniciação como Arcanista Iniciado
    if player_class == 0 then
        npc_say("Deseja decifrar as equações místicas da realidade? Se você possui uma mente disciplinada e sede de conhecimento, posso lhe ensinar a canalizar o mana como um Iniciado (Tier 1)!")
        return
    end

    -- Colega de Magia: Iniciado / Arquimago (Classe 3)
    if player_class == 3 then
        if f_level >= 3 then
            npc_say("Você compreende as complexidades do fluxo planar como poucos, meu pupilo. Tome este Cristal de Foco Arcano. Que a Supernova Lunar e o Cometa Elemental obedeçam à sua vontade estelar!")
            return
        else
            npc_say("Saudações, colega da arte arcana! Sente a oscilação do mana ambiente? As runas do topo da torre estão carregadas. Precisa de cristais de recarga ou deseja discutir a geometria astral?")
            return
        end
    end

    -- Comentários Astronômicos Ricos sobre Fases Lunares para qualquer classe:
    if moon == 1 then
        npc_say("Estamos sob a Lua Crescente. O mana flui de maneira suave e constante, excelente para estudos preparatórios e foco regenerativo.")
    elseif moon == 4 then
        npc_say("A Lua Cheia está no zênite! O poder bruto de todas as magias atinge seu ápice neste período. Até as mentes não-arcanas sentem a eletricidade estática no ar.")
    elseif moon == 8 then
        npc_say("A Lua de Sangue perturba a tessitura do espaço. Feitiços de dano crítico têm sua ressonância ampliada, mas a mente é posta à prova contra alucinações.")
    elseif moon == 9 then
        npc_say("O Grande Eclipse! O vórtice do Sol Negro cria uma anomalia cósmica incomparável. Se você adentrar o Santuário ao Noroeste, prepare-se para encarar aberrações que desafiam as leis naturais.")
    else
        npc_say("Saudações, viajante. A sabedoria arcana acolhe todas as vocações. Quer você empunhe aço ou feitiçaria, o estudo das marés mágicas garantirá sua sobrevivência em Lunaria.")
    end
end
