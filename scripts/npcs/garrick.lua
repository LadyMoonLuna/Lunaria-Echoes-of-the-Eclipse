-- garrick.lua — Script de Comportamento para Garrick, o Ferreiro (Marco 2 & 3)

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
-- 2 = Trabalhando na Forja
-- 3 = Bebendo na Taverna

-- OnTick é chamado pelo servidor a cada 1 segundo passando a hora atual (0 a 23)
function OnTick(world_hour, npc_id, pos_x, pos_z)
    if world_hour >= 6 and world_hour < 18 then
        -- Rotina Diurna (06h às 17h59): Forja do Garrick (30.0, 25.0) - Loja ABERTA
        npc_set_shop_open(true)
        if current_routine ~= "to_forge" and current_routine ~= "in_forge" then
            current_routine = "to_forge"
            waypoints = {
                { x = -15.0, z = 20.0 }, -- Sai da calçada da taverna
                { x = 0.0, z = 15.0 },   -- Cruza a praça central
                { x = 20.0, z = 20.0 },  -- Segue pela rua leste
                { x = 30.0, z = 25.0 }   -- Posto de trabalho na bigorna da forja
            }
            waypoint_index = 1
            npc_say("O sol já nasceu! Hora de sair do descanso e acender o fogo sagrado da forja!")
        end

        if current_routine == "to_forge" then
            local target = waypoints[waypoint_index]
            if target then
                npc_move_to(target.x, target.z, 2.4)
                if dist(pos_x, pos_z, target.x, target.z) <= 0.8 then
                    waypoint_index = waypoint_index + 1
                    if waypoint_index > #waypoints then
                        current_routine = "in_forge"
                        walk_timer = 0
                        walk_step = 0
                        npc_set_state(2) -- Trabalhando na Forja
                    end
                end
            end
        elseif current_routine == "in_forge" then
            walk_timer = walk_timer + 1
            if walk_timer >= 12 then
                walk_timer = 0
                walk_step = (walk_step + 1) % 2
                if walk_step == 0 then
                    npc_move_to(30.0, 25.0, 1.6)  -- Bancada da bigorna
                else
                    npc_move_to(32.0, 25.0, 1.6)  -- Próximo à fornalha
                end
            end
        end
    elseif world_hour >= 18 and world_hour < 24 then
        -- Rotina da Noite (18h às 23h59): Taverna do Javali Dourado (-30.0, 25.0) - Loja FECHADA
        npc_set_shop_open(false)
        if current_routine ~= "to_tavern" and current_routine ~= "in_tavern" then
            current_routine = "to_tavern"
            waypoints = {
                { x = 20.0, z = 20.0 },  -- Sai da forja para a rua
                { x = 0.0, z = 15.0 },   -- Cruza a praça central
                { x = -20.0, z = 20.0 }, -- Chega em frente à calçada da taverna
                { x = -30.0, z = 25.0 }  -- Entra na Taverna do Javali Dourado
            }
            waypoint_index = 1
            npc_say("O expediente encerrou por hoje! Vou caminhar até a Taverna do Javali Dourado para descansar e beber um hidromel.")
        end

        if current_routine == "to_tavern" then
            local target = waypoints[waypoint_index]
            if target then
                npc_move_to(target.x, target.z, 2.4)
                if dist(pos_x, pos_z, target.x, target.z) <= 0.8 then
                    waypoint_index = waypoint_index + 1
                    if waypoint_index > #waypoints then
                        current_routine = "in_tavern"
                        npc_set_state(3) -- Bebendo na Taverna
                        npc_say("O calor desta lareira é muito bem-vindo! Uma boa caneca depois de um dia de ferro e fogo!")
                    end
                end
            end
        end
    else
        -- Rotina da Madrugada (00h às 05h59): Descanso em Casa (20.0, 20.0) - Loja FECHADA
        npc_set_shop_open(false)
        if current_routine ~= "to_home" and current_routine ~= "in_home" then
            current_routine = "to_home"
            waypoints = {
                { x = -15.0, z = 20.0 },
                { x = 0.0, z = 15.0 },
                { x = 20.0, z = 20.0 }
            }
            waypoint_index = 1
            npc_say("A meia-noite chegou... Preciso descansar para o trabalho de amanhã.")
        end

        if current_routine == "to_home" then
            local target = waypoints[waypoint_index]
            if target then
                npc_move_to(target.x, target.z, 2.4)
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

-- OnPlayerApproach é disparado quando um jogador entra num raio < 4.0 metros (cooldown de 15s)
function OnPlayerApproach(player_id, distance, player_race)
    if player_race == 5 then
        npc_say("Sinto um calafrio na espinha... Um ser sem vida se aproxima!")
        return
    end

    local hour = get_world_hour()
    if hour >= 6 and hour < 18 then
        npc_say("Cuidado com as faíscas, aventureiro! O aço nesta forja está incandescente.")
    else
        local moon = get_moon_phase()
        if moon == 1 then
            npc_say("Boa noite, viajante. A luz suave da Lua Crescente traz paz à taverna.")
        elseif moon == 4 then
            npc_say("Ouça os uivos ao longe... A Lua Cheia agita as criaturas nas matas!")
        elseif moon == 8 then
            npc_say("O céu sangra carmesim... A Lua de Sangue desperta os horrores antigos!")
        elseif moon == 9 then
            npc_say("Escuridão sem fim... O Eclipse Total consome Lunaria!")
        else
            npc_say("Boa noite, viajante. Aproxime-se da lareira da taverna e tome um hidromel.")
        end
    end
end

-- OnPlayerInteract é disparado quando o jogador aperta E a < 5.0m
function OnPlayerInteract(player_id, world_hour, player_race, player_class, player_mas, friendship_level)
    local f_level = friendship_level or 0

    -- Regra de Exclusividade Rígida: Alquimistas (Classe 6) ou classes incompatíveis são barrados
    if player_class == 6 then
        npc_say("Minhas bigornas não servem para quem gasta o dia misturando fumacinhas em frascos. Vá ver a Lyra!")
        return
    end

    -- Viajante Sem Classe (Classe 0): Ensina a profissão básica de Forjador de Estrelas
    if player_class == 0 then
        npc_say("Um viajante sem rumo? Se você tiver mãos fortes para bater o martelo, posso lhe ensinar os segredos da Forja e do combate com martelos pesados! Você agora é um Forjador de Estrelas (Tier 1)!")
        return
    end

    -- Colega de Profissão: Forjador de Estrelas (Classe 5)
    if player_class == 5 then
        if f_level >= 3 then
            npc_say("Vejo que você tem talento com o martelo. Tome, vou te ensinar a forjar o Malho de Batalha Rúnico, uma arma que você não acha em nenhuma prateleira!")
            return
        else
            npc_say("Um irmão da bigorna! Pelos foles da criação, é uma honra encontrar outro ferreiro por aqui. O calor do fogo corre em nossas veias! Precisa de ferro, carvão ou quer trocar técnicas de têmpera?")
            return
        end
    elseif player_class == 8 then
        npc_say("Pelos segredos ancestrais dos Titãs da Forja! Essa arma que você empunha... É a lendária engenharia dos Artífices Rúnicos! Fundir o aço com magia rúnica é a arte mais sublime de Lunaria. Estou diante de um mestre!")
        return
    end

    -- Reatividade Racial Específica do NPC Garrick
    if player_race == 3 then
        npc_say("Um irmão Kharad! Reconheço a fuligem das forjas ancestrais no seu sangue. Para você, o reparo de armas tem desconto!")
        return
    elseif player_race == 2 then
        npc_say("Um Elfo da Lua... Suas lâminas e cajados brilham diferente sob o luar.")
        return
    elseif player_race == 4 then
        npc_say("Mantenha essas garras e esse sangue feroz longe dos cidadãos da vila, Varkai, e nos daremos bem.")
        return
    elseif player_race == 5 then
        npc_say("Pelos deuses... Você não tem pulso! Afaste essa sede de sangue da minha forja!")
        return
    elseif player_race == 1 then
        npc_say("Saudações, valoroso guerreiro de Valéria! É sempre uma honra forjar e bater o martelo para quem honra as tradições do nosso reino.")
        return
    end

    if world_hour >= 6 and world_hour < 18 then
        npc_say("Saudações! Precisa reforçar sua armadura ou procura por uma lâmina afiada o bastante para rasgar sombras? Venha forjar comigo!")
    else
        local moon = get_moon_phase()
        if moon == 1 then
            npc_say("A calmaria desta Lua Crescente acalma os espíritos. É uma ótima noite para forjar planos e recuperar as forças.")
        elseif moon == 4 then
            npc_say("Cuidado lá fora! Na Lua Cheia, feras lunares espreitam na escuridão. Dizem que os Noctari ficam especialmente letais sob esse luar.")
        elseif moon == 8 then
            npc_say("Pelos deuses ancestrais! A Lua de Sangue manchou os céus! O Comandante Vaelen e os Dhampirs sentem o chamado do sangue... Fique alerta!")
        elseif moon == 9 then
            npc_say("Um Eclipse Total! As sombras engoliram o sol e a lua... O poder dos críticos está descontrolado! É um verdadeiro Cataclismo!")
        else
            npc_say("Fale baixo... Você ouviu os rumores? Dizem que o Comandante Vaelen foi visto rondando as Ruínas do Santuário sob a lua sombria. Algo terrível está para acontecer.")
        end
    end
end
