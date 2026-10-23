-- thorne.lua — Thorne, o Eremita das Feras (ID 116) — MESTRE SECRETO do Senhor das Feras
-- Local: coração do Bosque Sussurrante (-120, 0, 60), Zona Floresta.
-- História: antigo caçador da guarda que, numa Lua Cheia, poupou uma loba ferida em vez de
-- matá-la. A matilha o adotou. Há vinte anos não volta à vila e ensina o vínculo com as feras
-- apenas a quem prova respeito pelos lobos.
-- Pessoal: 58 anos, Ulvar, fala pouco, tem uma loba cinzenta chamada Cinza.
-- Missão secreta: entregar presas (+15) e peles de Alfa (+25) até 60 de Confiança e voltar
-- numa noite de Lua Cheia ou de Noite de Vaga-lumes.

function OnTick(world_hour, npc_id, pos_x, pos_z)
    npc_set_active(true)
end

function OnPlayerApproach(player_id, distance, player_race)
    local moon = get_moon_phase()
    if moon == 4 then
        npc_say("A lua está inteira. A matilha canta. Você ouve?")
    elseif player_race == 46 or player_race == 6 then
        npc_say("...Sangue de lobo corre em você. Cinza percebeu antes de mim.")
    else
        npc_say("Pare. Mãos longe da arma. Cinza não gosta de estranhos.")
    end
end

function OnPlayerInteract(player_id, world_hour, player_race, player_class, player_mas, friendship_level)
    if player_class == 10 then
        npc_say("A fera ao seu lado luta por você. Lute por ela também.")
        return
    end
    npc_say("Os lobos lembram de quem os respeita.")
end
