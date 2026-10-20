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
        -- Rotina Diurna (06h às 17h): Forja na Rua Nordeste
        if current_routine ~= "to_forge" and current_routine ~= "in_forge" then
            current_routine = "to_forge"
            waypoints = {
                { x = -14.0, z = 6.0 }, -- Sai pela porta da taverna para a calçada
                { x = 0.0, z = 6.0 },   -- Caminha pela rua da praça central
                { x = 10.0, z = 6.0 },  -- Segue pela rua em direção à forja
                { x = 10.0, z = 9.0 }   -- Posto de trabalho em frente à bigorna
            }
            waypoint_index = 1
            npc_say("O sol já nasceu! Hora de sair da taverna e acender a forja.")
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
                    end
                end
            end
        elseif current_routine == "in_forge" then
            walk_timer = walk_timer + 1
            if walk_timer >= 12 then
                walk_timer = 0
                walk_step = (walk_step + 1) % 3
                if walk_step == 0 then
                    npc_move_to(10.0, 9.0, 1.6)  -- Bancada da bigorna
                elseif walk_step == 1 then
                    npc_move_to(11.5, 9.0, 1.6)  -- Próximo à fornalha
                else
                    npc_move_to(8.5, 8.0, 1.6)   -- Calçada externa
                end
            end
        end
    else
        -- Rotina Noturna (18h às 05h): Taverna do Crepúsculo
        if current_routine ~= "to_tavern" and current_routine ~= "in_tavern" then
            current_routine = "to_tavern"
            waypoints = {
                { x = 10.0, z = 6.0 },  -- Sai da forja para a rua
                { x = 0.0, z = 6.0 },   -- Cruza a praça central pela rua
                { x = -14.0, z = 6.0 }, -- Chega em frente à porta da taverna
                { x = -14.0, z = 9.5 }  -- Entra de verdade pela porta da taverna
            }
            waypoint_index = 1
            npc_say("Já deu por hoje... Vou caminhar pelas ruas até a Taverna e tomar uma caneca!")
        end

        if current_routine == "to_tavern" then
            local target = waypoints[waypoint_index]
            if target then
                npc_move_to(target.x, target.z, 2.4)
                if dist(pos_x, pos_z, target.x, target.z) <= 0.8 then
                    waypoint_index = waypoint_index + 1
                    if waypoint_index > #waypoints then
                        current_routine = "in_tavern"
                        npc_say("Cheguei à Taverna. O calor desta lareira é muito bem-vindo!")
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

    -- Viajante Sem Classe (Classe 0): Ensina a profissão básica de Ferreiro
    if player_class == 0 then
        npc_say("Um viajante sem rumo? Se você tiver mãos fortes para bater o martelo, posso lhe ensinar os segredos da Forja e do combate com martelos pesados! Você agora é um Ferreiro (Tier 1)!")
        return
    end

    -- Colega de Profissão: Ferreiro (Classe 5)
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
