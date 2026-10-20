-- lyra.lua — Comportamento de Lyra, a Alquimista (ID 103)

local current_routine = ""
local walk_timer = 0
local walk_step = 0
local waypoints = {}
local waypoint_index = 1

local function dist(x1, z1, x2, z2)
    local dx = x1 - x2
    local dz = z1 - z2
    return math.sqrt(dx * dx + dz * dz)
end

-- Estados Visuais:
-- 0 = Parado
-- 1 = Andando

-- OnTick é invocado a cada segundo informando a hora atual do mundo (0 a 23)
function OnTick(world_hour, npc_id, pos_x, pos_z)
    if world_hour >= 7 and world_hour < 19 then
        -- Rotina Diurna (07h às 18h): Laboratório de Alquimia a Sudeste
        if current_routine ~= "to_lab" and current_routine ~= "in_lab" then
            current_routine = "to_lab"
            waypoints = {
                { x = 14.0, z = -18.0 }, -- Sai pela porta norte de sua casa para a viela
                { x = 10.0, z = -18.0 }, -- Caminha pela viela até a avenida
                { x = 10.0, z = -6.5 }   -- Chega ao balcão do laboratório
            }
            waypoint_index = 1
            npc_say("O sol já brilha sobre Lunaria! Hora de abrir o laboratório e destilar novas essências.")
        end

        if current_routine == "to_lab" then
            local target = waypoints[waypoint_index]
            if target then
                npc_move_to(target.x, target.z, 2.3)
                if dist(pos_x, pos_z, target.x, target.z) <= 0.8 then
                    waypoint_index = waypoint_index + 1
                    if waypoint_index > #waypoints then
                        current_routine = "in_lab"
                        walk_timer = 0
                        walk_step = 0
                    end
                end
            end
        elseif current_routine == "in_lab" then
            walk_timer = walk_timer + 1
            if walk_timer >= 14 then
                walk_timer = 0
                walk_step = (walk_step + 1) % 3
                if walk_step == 0 then
                    npc_move_to(10.0, -6.5, 1.6) -- Mesa de poções
                elseif walk_step == 1 then
                    npc_move_to(12.0, -6.5, 1.6) -- Estante de reagentes
                else
                    npc_move_to(8.5, -6.5, 1.6)  -- Frente da tenda na rua
                end
            end
        end
    else
        -- Rotina Noturna (19h às 06h): Casa Residencial
        if current_routine ~= "to_home" and current_routine ~= "in_home" then
            current_routine = "to_home"
            waypoints = {
                { x = 10.0, z = -18.0 }, -- Caminha pela rua até a viela residencial
                { x = 14.0, z = -18.0 }, -- Chega em frente à porta de sua casa
                { x = 14.0, z = -20.5 }  -- Entra de verdade pela porta residencial
            }
            waypoint_index = 1
            npc_say("A noite cai sobre a vila... Hora de recolher os frascos e retornar para casa.")
        end

        if current_routine == "to_home" then
            local target = waypoints[waypoint_index]
            if target then
                npc_move_to(target.x, target.z, 2.3)
                if dist(pos_x, pos_z, target.x, target.z) <= 0.8 then
                    waypoint_index = waypoint_index + 1
                    if waypoint_index > #waypoints then
                        current_routine = "in_home"
                        npc_say("Cheguei em casa. Hora de descansar e estudar novas receitas alquímicas.")
                    end
                end
            end
        end
    end
end

-- OnPlayerApproach é disparado quando um jogador entra no raio de 4.0 metros
function OnPlayerApproach(player_id, distance, player_race)
    local hour = get_world_hour()
    if hour >= 7 and hour < 19 then
        npc_say("Bem-vindo à Tenda de Alquimia! Procura poções revigorantes ou frascos para coleta?")
    else
        npc_say("Boa noite, viajante. Minha casa está calma, mas meus cadinhos continuam fumegando.")
    end
end

-- OnPlayerInteract é disparado ao pressionar a tecla de interação a menos de 5.0m
function OnPlayerInteract(player_id, world_hour, player_race, player_class, player_mas, friendship_level)
    local f_level = friendship_level or 0

    -- Restrição Rígida para Ferreiros (Classe 5):
    -- Fecha o comércio a menos que a Afiança ultrapasse o Nível 2 (Nível 3+)
    if player_class == 5 and f_level <= 2 then
        npc_say("Tire essas luvas sujas de fuligem e ferro de perto dos meus frascos de vidro cristalino! Ferreiros brutos só sabem quebrar vidrarias finas. Não tenho nada para negociar com você até que aprenda a ter delicadeza!")
        return
    end

    -- História Orgânica do Mestre Traído nos Esgotos às 03:00 (Afiança Nível 3+)
    if f_level >= 3 then
        npc_say("Você conquistou minha total confiança... Deixe-me contar um segredo guardado a sete chaves: às 03:00 da manhã, meu antigo mestre alquimista foi traído pelo conselho e jogado nos esgotos da vila para ser silenciado. Mas eu sei que ele sobreviveu nas sombras... Procure pelas passagens subterrâneas na calada da noite se quiser encontrar a verdade.")
        return
    end

    -- Viajante Sem Classe (Classe 0): Ensina a arte da Alquimia
    if player_class == 0 then
        npc_say("Um viajante curioso? A alquimia é a ciência da vida e da matéria! Posso lhe ensinar a arte de destilar frascos e arremessar elixires elementais como uma Alquimista (Tier 1)!")
        return
    end

    -- Reatividade: Alquimista (Classe 6) ou Alta Perícia (MAS >= 12)
    local mas_val = player_mas or 5
    if player_class == 6 or mas_val >= 12 then
        npc_say("Impressionante! Reconheço o olhar apurado de quem domina a transmutação. Se você tiver Sangue Lupino Fresco e um Frasco Vazio, ofereço a receita e o preparo da formidável Poção de Sangue Lupino (+20% Velocidade e Crítico por 20s)!")
        return
    end

    -- Ferreiro com Afiança > 2 (Nível 3+) que já ouviu a história ou diálogo neutro
    if player_class == 5 then
        npc_say("Vejo que mesmo com essas mãos acostumadas à bigorna, você aprendeu a manusear frascos sem trincá-los. Aceito negociar com você!")
        return
    end

    -- Diálogo diurno geral
    if world_hour >= 7 and world_hour < 19 then
        npc_say("Saudações! Venha conferir minhas poções ou vender frascos de sangue e venenos coletados dos monstros da floresta. Lembre-se de sempre carregar Frascos Vazios para coletar reagentes anatômicos das feras abatidas!")
    else
        -- Diálogo noturno em sua residência
        local moon = get_moon_phase()
        if moon == 8 then
            npc_say("Sob esta Lua de Sangue, as reações químicas ficam instáveis... O sangue ferve até dentro dos frascos de vidro!")
        elseif moon == 4 then
            npc_say("A Lua Cheia potencializa o Sangue Lupino colhido nas matas. Traga-o de dia na minha tenda!")
        else
            npc_say("Estou organizando minhas poções e pergaminhos para o amanhecer. Durante o dia, encontre-me na Tenda de Alquimia perto da praça!")
        end
    end
end
