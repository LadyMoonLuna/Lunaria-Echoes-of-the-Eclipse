-- seraphina.lua — Script de Comportamento para Irmã Seraphina, Mestra Acólita (ID 107)
-- Localização: Igreja da Luz Sagrada em (-20.0, 0.0, -18.0)
-- Ensina a classe Acólito (ClassID = 4), vende bênçãos e conversa sobre fé solar/lunar.

local current_routine = "in_church"

function OnTick(world_hour, npc_id, pos_x, pos_z)
    npc_set_active(true)
    if world_hour >= 6 and world_hour < 18 then
        -- Horário Diurno (06h às 17h59): Oração diante do Altar Solar dentro da Igreja (ZoneID 5 em 0.0, 15.0)
        current_routine = "day_prayer"
        if npc_get_zone() ~= 5 then
            npc_set_zone(5)
            npc_teleport(0.0, 0.0, 15.0)
        end
    else
        -- Ao Entardecer e Noite (18h às 05h59): Usa o portal e fica na porta da Igreja na Vila (ZoneID 0 em -50.0, -36.0)
        current_routine = "night_vigil"
        if npc_get_zone() ~= 0 then
            npc_set_zone(0)
            npc_teleport(-50.0, 0.0, -36.0)
        end
    end
end

function OnPlayerApproach(player_id, distance, player_race)
    local hour = get_world_hour()
    if player_race == 5 or player_race == 7 then
        npc_say("Sinto a frieza do além em sua alma... Que a Luz Sagrada traga paz e redenção ao seu espírito atormentado.")
        return
    end

    if hour >= 6 and hour < 18 then
        npc_say("Abençoado seja seu dia, viajante. Que a radiância do Sol Sagrado ilumine seu caminho em Lunaria.")
    else
        local moon = get_moon_phase()
        if moon == 8 then
            npc_say("O céu chora sangue... Ajoelhe-se e busque o abrigo da Luz Sagrada contra a tentação das sombras!")
        elseif moon == 9 then
            npc_say("O Sol e a Lua foram devorados... Mas enquanto acendermos esta chama sagrada, as trevas não nos consumirão!")
        else
            npc_say("Boa noite, peregrino. As portas da Igreja estão sempre abertas para quem busca consolo e proteção.")
        end
    end
end

function OnPlayerInteract(player_id, world_hour, player_race, player_class, player_mas, friendship_level)
    local f_level = friendship_level or 0

    -- Viajante Sem Classe (ClassID == 0): Iniciação como Acólito
    if player_class == 0 then
        npc_say("Um coração puro buscando propósito? A Luz Divina acolhe a todos! Se você deseja canalizar energias sagradas para curar aliados e punir a heresia com lanças de fé, eu a consagro como Acólito (Tier 1)!")
        return
    end

    -- Colega de Fé: Acólito (Classe 4)
    if player_class == 4 then
        if f_level >= 3 then
            npc_say("Irmão na fé, sua devoção tocou os céus. Tome esta Frasco de Água Benta Purificada. Que o Julgamento Celestial e a Bênção Divina fortaleçam seu espírito em todas as provações!")
            return
        else
            npc_say("Paz esteja convosco, nobre Acólito! Nossas preces mantêm a barreira da vila contra o mal do Eclipse. Precisa de água benta, orações ou quer trocar conhecimentos litúrgicos?")
            return
        end
    end

    -- Reatividade com outras classes: Seraphina é acolhedora com todas as classes
    if player_class == 1 then
        npc_say("Um honrado Espadachim! Que sua lâmina seja o braço da justiça e a fé seja o seu escudo impenetrável.")
    elseif player_class == 2 then
        npc_say("Saudações, Batedor da floresta. Que a luz filtre através das copas das árvores e guie com retidão cada uma de suas flechas.")
    elseif player_class == 3 then
        npc_say("Um Arcanista do Cosmos... A magia arcana e a luz divina nasceram da mesma centelha primordial da criação.")
    elseif player_class == 5 then
        npc_say("Um nobre Forjador de Estrelas! Cada martelada honesta em sua bigorna é uma prece de trabalho e perseverança aos céus.")
    elseif player_class == 6 then
        npc_say("Transmutador, a cura dos enfermos através da matéria é uma das mais belas manifestações da misericórdia divina.")
    elseif player_class == 7 then
        npc_say("Um Ceifador da Lua Negra... Mesmo aquele que caminha no abismo pode encontrar a redenção se sua alma desejar a luz.")
    else
        npc_say("Seja bem-vindo à Casa da Luz Sagrada. Tome um momento de silêncio para purificar seus pensamentos do fardo da batalha.")
    end
end
