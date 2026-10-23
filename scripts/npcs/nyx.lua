-- nyx.lua — Nyx Sombraveloz, Mestra das Lâminas Silentes (ID 111)
-- Local: beco atrás do Mercado Negro (-58, 0, 52), Vila. Só aparece à noite (18h às 06h).
-- História: ex-lâmina da Irmandade do Sol Negro. Fugiu quando a guilda tentou assassinar
-- uma criança Selenarca durante o último Eclipse. Hoje caça os antigos irmãos e ensina
-- quem tiver mãos leves e consciência pesada.
-- Pessoal: 31 anos, Umbryss, adora chá de jasmim e odeia sinos. Presente favorito: Glândula de Veneno.

function OnTick(world_hour, npc_id, pos_x, pos_z)
    npc_set_active(world_hour >= 18 or world_hour < 6)
end

function OnPlayerApproach(player_id, distance, player_race)
    local moon = get_moon_phase()
    if moon == 0 then
        npc_say("Lua Nova... a melhor noite para não ser vista. E mesmo assim você me viu. Interessante.")
    else
        npc_say("Shh. Passos mais leves, estranho. As sombras têm ouvidos.")
    end
end

function OnPlayerInteract(player_id, world_hour, player_race, player_class, player_mas, friendship_level)
    local f = friendship_level or 0
    if player_class == 4 then
        if f >= 3 then
            npc_say("Rumor da Irmandade: assassinos do Sol Negro se disfarçam entre os Saqueadores das Ruínas. Se for até lá, ataque primeiro e não deixe que te vejam chegando.")
        else
            npc_say("Lição de hoje: o primeiro golpe pelas costas vale por três de frente. Fique fora da vista dos monstros e ataque quando eles virarem.")
        end
        return
    end
    if f >= 4 then
        npc_say("Quer saber um segredo? Eu nasci em Lunarin, não aqui. Os sinos da minha cidade tocavam a cada morte. Por isso odeio sinos.")
    else
        npc_say("Vendo bombas de fumaça e lâminas envenenadas. Perguntas custam caro; respostas, mais ainda.")
    end
end
