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
    if world_hour >= 6 and world_hour < 18 then
        -- Rotina Diurna (06h às 17h59): Laboratório de Alquimia (30.0, -20.0) - Loja ABERTA
        npc_set_shop_open(true)
        if current_routine ~= "to_lab" and current_routine ~= "in_lab" then
            current_routine = "to_lab"
            waypoints = {
                { x = -15.0, z = 10.0 }, -- Sai da calçada
                { x = 0.0, z = 0.0 },    -- Cruza a praça central
                { x = 20.0, z = -15.0 }, -- Segue pela avenida sudeste
                { x = 30.0, z = -20.0 }  -- Chega ao balcão do laboratório
            }
            waypoint_index = 1
            npc_say("O sol já brilha sobre Lunaria! Hora de abrir o laboratório e destilar novos elixires.")
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
                        npc_set_state(2) -- Trabalhando
                    end
                end
            end
        elseif current_routine == "in_lab" then
            walk_timer = walk_timer + 1
            if walk_timer >= 14 then
                walk_timer = 0
                walk_step = (walk_step + 1) % 2
                if walk_step == 0 then
                    npc_move_to(30.0, -20.0, 1.6) -- Mesa de poções
                else
                    npc_move_to(32.0, -20.0, 1.6) -- Estante de reagentes
                end
            end
        end
    elseif world_hour >= 18 and world_hour < 24 then
        -- Rotina da Noite (18h às 23h59): Taverna do Javali Dourado (-30.0, 25.0) - Loja FECHADA
        npc_set_shop_open(false)
        if current_routine ~= "to_tavern" and current_routine ~= "in_tavern" then
            current_routine = "to_tavern"
            waypoints = {
                { x = 20.0, z = -10.0 }, -- Sai do laboratório para a avenida
                { x = 0.0, z = 5.0 },    -- Passa pela praça central
                { x = -20.0, z = 15.0 }, -- Segue em direção à taverna
                { x = -30.0, z = 25.0 }  -- Entra na Taverna do Javali Dourado
            }
            waypoint_index = 1
            npc_say("Expediente encerrado por hoje! Vou até a Taverna encontrar o Garrick e descansar dos vapores dos cadinhos.")
        end

        if current_routine == "to_tavern" then
            local target = waypoints[waypoint_index]
            if target then
                npc_move_to(target.x, target.z, 2.3)
                if dist(pos_x, pos_z, target.x, target.z) <= 0.8 then
                    waypoint_index = waypoint_index + 1
                    if waypoint_index > #waypoints then
                        current_routine = "in_tavern"
                        npc_set_state(3) -- Descansando na Taverna
                        npc_say("Que alívio respirar o ar quente da taverna... Uma tisana quente é tudo que eu precisava!")
                    end
                end
            end
        end
    else
        -- Rotina da Madrugada (00h às 05h59): Casa Residencial (20.0, -35.0) - Loja FECHADA
        npc_set_shop_open(false)
        if current_routine ~= "to_home" and current_routine ~= "in_home" then
            current_routine = "to_home"
            waypoints = {
                { x = -15.0, z = 15.0 },
                { x = 0.0, z = -10.0 },
                { x = 20.0, z = -35.0 }
            }
            waypoint_index = 1
            npc_say("A calada da noite... Hora de me recolher aos meus aposentos.")
        end

        if current_routine == "to_home" then
            local target = waypoints[waypoint_index]
            if target then
                npc_move_to(target.x, target.z, 2.3)
                if dist(pos_x, pos_z, target.x, target.z) <= 0.8 then
                    waypoint_index = waypoint_index + 1
                    if waypoint_index > #waypoints then
                        current_routine = "in_home"
                        npc_set_state(0) -- Dormindo
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
