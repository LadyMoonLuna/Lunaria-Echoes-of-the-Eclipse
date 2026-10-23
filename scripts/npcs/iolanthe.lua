-- iolanthe.lua — Iolanthe Mármore-Lunar, Escultora de Almas (ID 113)
-- Local: pátio das estátuas nas Ruínas da Vigília (-30, 0, -235), Zona Ruínas.
-- História: aprendiz do lendário Mestre Escultor do Luar. Quando a Vigília caiu, ela
-- esculpiu os guardiões que ainda protegem as ruínas — cada estátua guarda a alma de um
-- soldado que pediu para continuar de vigia. Ela conversa com elas todas as noites.
-- Pessoal: 27 anos, Elarin, fala baixo e cantarola. Presente favorito: Anel de Luz Estelar.

function OnTick(world_hour, npc_id, pos_x, pos_z)
    npc_set_active(true)
end

function OnPlayerApproach(player_id, distance, player_race)
    local moon = get_moon_phase()
    if moon == 4 then
        npc_say("Lua Cheia... ouça, as estátuas estão cantando. Elas sempre cantam quando a lua está inteira.")
    else
        npc_say("Cuidado onde pisa, viajante. Alguns destes escombros já foram pessoas.")
    end
end

function OnPlayerInteract(player_id, world_hour, player_race, player_class, player_mas, friendship_level)
    local f = friendship_level or 0
    if player_class == 9 then
        if f >= 3 then
            npc_say("Conselho da Oficina: estátuas lutam melhor perto de pedra antiga. As Ruínas são o melhor lugar para treinar com o seu Guardião.")
        else
            npc_say("Seu Guardião não é uma ferramenta, é um companheiro. Ele ataca quem você ataca — cuide bem dele.")
        end
        return
    end
    if f >= 4 then
        npc_say("A estátua com a espada quebrada era meu irmão, Corvin. Ele ainda vigia o portão. Às vezes eu juro que ele acena.")
    else
        npc_say("Vendo cinzéis, pó lunar e pequenas estatuetas de proteção. Cada uma tem um pedacinho de luz dentro.")
    end
end
