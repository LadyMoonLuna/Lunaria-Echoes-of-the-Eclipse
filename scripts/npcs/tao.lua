-- tao.lua — Mestre Tao Ferroventre, Grão-Mestre do Punho Celeste (ID 112)
-- Local: clareira de treino na entrada do Bosque Sussurrante (25, 0, 240), Zona Floresta.
-- História: monge Kharad que escalou o Pico das Nove Luas e lutou com um Jotunar por sete
-- dias sem armas. Perdeu dois dedos e ganhou a "Palma do Vento". Vive de chá, arroz e paciência.
-- Pessoal: 64 anos, ri alto, ronca mais alto. Presente favorito: Pele de Lobo Alfa (para o tatame).

function OnTick(world_hour, npc_id, pos_x, pos_z)
    npc_set_active(true)
end

function OnPlayerApproach(player_id, distance, player_race)
    local hour = get_world_hour()
    if hour >= 5 and hour < 8 then
        npc_say("Bom dia! Cem socos antes do sol nascer! Quer se juntar? Ha-ha!")
    elseif hour >= 22 or hour < 5 then
        npc_say("Zzz... hm? Ah, um visitante. Até o punho precisa dormir, jovem.")
    else
        npc_say("A cachoeira bate na pedra mil vezes por dia. Um dia a pedra cede. Assim é o treino.")
    end
end

function OnPlayerInteract(player_id, world_hour, player_race, player_class, player_mas, friendship_level)
    local f = friendship_level or 0
    if player_class == 5 then
        if f >= 3 then
            npc_say("Desafio do Vento: enfrente o Lobo Alfa só com os punhos. Se voltar vivo, traga a pele dele — meu tatame anda gasto. Ha-ha!")
        else
            npc_say("Cada três socos seguidos endurecem o seu corpo como um escudo. Não pare de bater e o inimigo não conseguirá te ferir!")
        end
        return
    end
    npc_say("Armas quebram, armaduras enferrujam. O corpo treinado é a única arma que você leva para o túmulo. Ha-ha! Um chá?")
end
