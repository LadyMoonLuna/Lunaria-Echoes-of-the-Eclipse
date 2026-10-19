-- garrick.lua — Script de Comportamento para Garrick, o Ferreiro (Marco 2 & 3)

local current_routine = ""

-- Estados Visuais:
-- 0 = Parado
-- 1 = Andando
-- 2 = Trabalhando na Forja
-- 3 = Bebendo na Taverna

-- OnTick é chamado pelo servidor a cada 1 segundo passando a hora atual (0 a 23)
function OnTick(world_hour)
    if world_hour >= 6 and world_hour < 18 then
        -- Rotina Diurna: Das 06h às 17h, caminha até a Forja (6.0, 6.0)
        if current_routine ~= "forge" then
            current_routine = "forge"
            npc_say("O sol já nasceu! Hora de acender a forja e bater o ferro.")
            npc_move_to(6.0, 6.0, 3.0)
        end
    else
        -- Rotina Noturna: Das 18h às 05h, caminha até a Taverna (-6.0, -4.0)
        if current_routine ~= "tavern" then
            current_routine = "tavern"
            npc_say("Já deu por hoje... Vou tomar uma caneca na Taverna!")
            npc_move_to(-6.0, -4.0, 2.5)
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
function OnPlayerInteract(player_id, world_hour, player_race, player_class)
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
