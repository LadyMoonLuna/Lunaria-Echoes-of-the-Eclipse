-- kaelen.lua — Script de Comportamento para Kaelen, o Mestre Caçador (ID 109)
-- Localização: Posto do Caçador em (34.0, 0.0, -30.0)
-- Ensina a classe Batedor (ClassID = 2) e dá dicas sobre os Lobos da Bruma e o Lobo Alfa.

local current_routine = "in_post"

function OnTick(world_hour, npc_id, pos_x, pos_z)
    -- Kaelen cuida da fogueira e inspeciona a saída para o Bosque Sussurrante
    npc_set_active(true)
    if world_hour >= 6 and world_hour < 18 then
        current_routine = "day_training"
    else
        current_routine = "night_hunting"
    end
end

function OnPlayerApproach(player_id, distance, player_race)
    local hour = get_world_hour()
    local moon = get_moon_phase()

    if moon == 4 then
        npc_say("Ouviu esse uivo retumbante vindo do Bosque? É o Lobo Alfa! Sob a Lua Cheia, ele lidera a matilha para estraçalhar invasores!")
        return
    elseif moon == 8 then
        npc_say("O cheiro de ferro e sangue impregna a brisa... O Licantropo Alfa despertou nas sombras profundas! Nem pense em caçar sozinho esta noite!")
        return
    end

    if hour >= 6 and hour < 18 then
        npc_say("Aproxime-se da cabana, viajante. Se for entrar no Bosque Sussurrante, verifique a corda do seu arco e suas lâminas.")
    else
        npc_say("Noite escura nas trilhas. A fogueira está acesa; puxe um tronco e aqueça as mãos antes de se aventurar.")
    end
end

function OnPlayerInteract(player_id, world_hour, player_race, player_class, player_mas, friendship_level)
    local f_level = friendship_level or 0
    local moon = get_moon_phase()

    -- Viajante Sem Classe (ClassID == 0): Iniciação como Batedor
    if player_class == 0 then
        npc_say("Quer aprender a ler o rastro na grama e abater presas antes que percebam sua presença? A mata exige pés leves e coração frio. Venha, eu lhe ensinarei a arte do Batedor (Tier 1)!")
        return
    end

    -- Colega de Caça: Batedor (Classe 2)
    if player_class == 2 then
        if f_level >= 3 then
            npc_say("Você se move como o próprio vento entre os pinheiros, parceiro. Tome este Arco de Caça da Vigília Reforçado. Na próxima caçada ao Lobo Alfa, miraremos juntos no coração da fera!")
            return
        else
            npc_say("Saudações, colega Batedor! As trilhas a Sudeste estão infestadas de Lobos da Bruma. Quer reforçar seu estoque de flechas, armadilhas ou trocar dicas sobre a movimentação da matilha?")
            return
        end
    end

    -- Dicas de Caça Ricas e Úteis para Qualquer Aventureiro:
    if moon == 4 then
        npc_say("Dica crucial para a Lua Cheia: Os Lobos da Bruma comuns em (55, -45) e (65, -52) ficam mais rápidos, mas o verdadeiro perigo é o Lobo Alfa em (75, -60). Mantenha distância e evite lutar no meio da névoa cerrada!")
    elseif moon == 8 then
        npc_say("Alerta vermelho na Lua de Sangue! O terrível Licantropo Alfa em (88, -72) regenera vida com ferocidade titânica. Traga amigos, elixires de fogo e não deixe suas costas desprotegidas!")
    else
        npc_say("No Bosque Sussurrante, os Lobos da Bruma atacam em bando. O segredo é atrair um de cada vez usando pedras ou flechas para longe da clareira central. Precisa de provisões ou flechas de caça?")
    end
end
