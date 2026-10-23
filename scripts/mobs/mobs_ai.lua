-- ============================================================================
-- Lunaria Online — Cérebro Tático dos Mobs (Marco 4)
-- Suporte completo a Hot-Reload via fsnotify
-- Mobs:
--   1: Lobo da Bruma (Bosque Sussurrante)
--   2: Saqueador Deserdado (Estrada das Ruínas)
--   3: Besteiro da Vigília
--   4: Acólito do Eclipse
--   5: Executor de Ferro (Entrada das Ruínas)
-- ============================================================================

local mob_timers = {}
local mob_cooldowns = {}
local executor_telegraphs = {}

-- Inicializa tabelas de controle por mob
local function get_mob_data(mob_id)
    if not mob_timers[mob_id] then
        mob_timers[mob_id] = {
            attack_cd = 0.0,
            special_cd = 0.0,
            state_timer = 0.0,
            vulnerable_timer = 0.0,
            is_charging_aoe = false,
            is_vulnerable = false,
            has_shouted_flee = false,
            blocked_count = 0
        }
    end
    return mob_timers[mob_id]
end

-- ============================================================================
-- UpdateMob é chamado autoritativamente a cada tick do servidor Go
-- ============================================================================
function UpdateMob(mob_id, mob_type, mob_x, mob_z, mob_hp, mob_max_hp, current_state, spawn_x, spawn_z, nearest_player_id, player_dist, player_x, player_z, moon_phase, dt)
    local data = get_mob_data(mob_id)

    -- Atualiza cooldowns
    if data.attack_cd > 0 then data.attack_cd = data.attack_cd - dt end
    if data.special_cd > 0 then data.special_cd = data.special_cd - dt end
    if data.state_timer > 0 then data.state_timer = data.state_timer - dt end

    -- ------------------------------------------------------------------------
    -- 1. LOBO DA BRUMA (MobType == 1)
    -- ------------------------------------------------------------------------
    if mob_type == 1 then
        local is_empowered = (moon_phase == 4 or moon_phase == 8) -- Lua Cheia (4) ou Lua de Sangue (8)
        local aggro_radius = is_empowered and 14.0 or 9.0
        local move_speed = is_empowered and (4.2 * 1.3) or 4.2
        local bite_damage = is_empowered and 23 or 18

        if nearest_player_id > 0 and player_dist <= aggro_radius then
            if player_dist > 2.0 then
                -- Persegue o jogador
                mob_set_state(mob_id, 1) -- Chasing
                mob_move_to(mob_id, player_x, player_z, move_speed)
            else
                -- Morde o jogador a cada 1.2s
                if data.attack_cd <= 0 then
                    mob_set_state(mob_id, 2) -- Attacking
                    mob_attack_player(mob_id, nearest_player_id, bite_damage)
                    data.attack_cd = 1.2
                end
            end
        else
            -- Retorna ao spawn se estiver longe
            local dist_to_spawn = math.sqrt((spawn_x - mob_x)^2 + (spawn_z - mob_z)^2)
            if dist_to_spawn > 1.0 then
                mob_set_state(mob_id, 0)
                mob_move_to(mob_id, spawn_x, spawn_z, 2.5)
            else
                mob_set_state(mob_id, 0) -- Idle
            end
        end

    -- ------------------------------------------------------------------------
    -- 25. JAVALI SELVAGEM (MobType == 25): territorial — só investe de perto
    -- ------------------------------------------------------------------------
    elseif mob_type == 25 then
        local aggro_radius = 6.0
        if nearest_player_id > 0 and player_dist <= aggro_radius then
            if player_dist > 1.8 then
                mob_set_state(mob_id, 1) -- Investida
                mob_move_to(mob_id, player_x, player_z, 3.6)
            elseif data.attack_cd <= 0 then
                mob_set_state(mob_id, 2) -- Chifrada com as presas
                mob_attack_player(mob_id, nearest_player_id, 10)
                data.attack_cd = 1.5
            end
        else
            local dist_to_spawn = math.sqrt((spawn_x - mob_x)^2 + (spawn_z - mob_z)^2)
            mob_set_state(mob_id, 0)
            if dist_to_spawn > 1.0 then
                mob_move_to(mob_id, spawn_x, spawn_z, 2.0)
            end
        end

    -- ------------------------------------------------------------------------
    -- 2. SAQUEADOR DESERDADO (MobType == 2)
    -- ------------------------------------------------------------------------
    elseif mob_type == 2 then
        local aggro_radius = 11.0
        local move_speed = 3.2

        if nearest_player_id > 0 and player_dist <= aggro_radius then
            if player_dist > 2.6 then
                mob_set_state(mob_id, 1) -- Chasing
                mob_move_to(mob_id, player_x, player_z, move_speed)
            else
                -- Em combate próximo: alterna para escudo levantado (State = 3)
                if data.special_cd <= 0 then
                    -- Contra-ataque pesado de 28 dano
                    mob_set_state(mob_id, 2)
                    mob_attack_player(mob_id, nearest_player_id, 28)
                    data.special_cd = 2.5
                    data.state_timer = 1.2
                else
                    if data.state_timer > 0 then
                        -- Mantém escudo levantado (reduz 50% do dano)
                        mob_set_state(mob_id, 3)
                    else
                        mob_set_state(mob_id, 1)
                    end
                end
            end
        else
            mob_set_state(mob_id, 0)
            mob_move_to(mob_id, spawn_x, spawn_z, 2.0)
        end

    -- ------------------------------------------------------------------------
    -- 3. BESTEIRO DA VIGÍLIA (MobType == 3)
    -- ------------------------------------------------------------------------
    elseif mob_type == 3 then
        local aggro_radius = 12.0

        if nearest_player_id > 0 and player_dist <= aggro_radius then
            if player_dist < 3.8 then
                -- Jogador chegou muito perto: recuo tático rápido para longe
                local dx = mob_x - player_x
                local dz = mob_z - player_z
                local len = math.sqrt(dx * dx + dz * dz)
                if len < 0.01 then len = 1.0; dx = 1.0 end
                local retreat_x = mob_x + (dx / len) * 5.0
                local retreat_z = mob_z + (dz / len) * 5.0

                mob_set_state(mob_id, 4) -- Fugindo / Recuando
                mob_move_to(mob_id, retreat_x, retreat_z, 4.8)
            else
                -- Dispara flecha de até 11.0m causando 20 de dano a cada 1.8s
                if player_dist <= 11.0 then
                    if data.attack_cd <= 0 then
                        mob_set_state(mob_id, 2) -- Atacando
                        mob_attack_player(mob_id, nearest_player_id, 20)
                        data.attack_cd = 1.8
                    end
                else
                    mob_set_state(mob_id, 1)
                    mob_move_to(mob_id, player_x, player_z, 3.5)
                end
            end
        else
            mob_set_state(mob_id, 0)
            mob_move_to(mob_id, spawn_x, spawn_z, 2.0)
        end

    -- ------------------------------------------------------------------------
    -- 4. ACÓLITO DO ECLIPSE (MobType == 4)
    -- ------------------------------------------------------------------------
    elseif mob_type == 4 then
        local hp_pct = mob_hp / mob_max_hp

        -- Se vida cair abaixo de 25%: Fuga em pânico para o norte
        if hp_pct < 0.25 then
            mob_set_state(mob_id, 4) -- Fleeing
            if not data.has_shouted_flee then
                mob_say(mob_id, "O Eclipse há de vingar meu sangue!")
                data.has_shouted_flee = true
            end
            -- Corre para o norte (direção +Z)
            mob_move_to(mob_id, mob_x, mob_z + 8.0, 4.0)
        else
            data.has_shouted_flee = false

            -- Cura aliados a cada 4.0s
            if data.special_cd <= 0 then
                local healed = mob_heal_ally(mob_id, 0, 45) -- 0 busca o aliado mais ferido
                if healed then
                    data.special_cd = 4.0
                end
            end

            -- Combate ou perseguição
            if nearest_player_id > 0 and player_dist <= 10.0 then
                if player_dist > 2.5 then
                    mob_set_state(mob_id, 1)
                    mob_move_to(mob_id, player_x, player_z, 3.0)
                else
                    if data.attack_cd <= 0 then
                        mob_set_state(mob_id, 2)
                        mob_attack_player(mob_id, nearest_player_id, 16)
                        data.attack_cd = 1.5
                    end
                end
            else
                mob_set_state(mob_id, 0)
                mob_move_to(mob_id, spawn_x, spawn_z, 2.0)
            end
        end

    -- ------------------------------------------------------------------------
    -- 5. EXECUTOR DE FERRO (MobType == 5)
    -- ------------------------------------------------------------------------
    elseif mob_type == 5 then
        local base_speed = 2.4

        -- 1. VERIFICAÇÃO E RECUPERAÇÃO DO ESTADO VULNERÁVEL (State == 4)
        -- No topo da função de Tick do Executor, antes de qualquer return:
        if current_state == 4 or data.is_vulnerable then
            if data.vulnerable_timer > 0 then
                data.vulnerable_timer = data.vulnerable_timer - dt
            end

            if data.vulnerable_timer > 0 then
                -- Ainda vulnerável com a maça cravada no chão
                mob_set_state(mob_id, 4)
                return
            end

            -- Timer de 2.0s expirou! Recupera-se da maça no chão
            data.is_vulnerable = false
            data.vulnerable_timer = 0.0
            data.is_charging_aoe = false
            data.state_timer = 0.0
            data.special_cd = 4.5 -- Reseta o timer de recarga do AoE
            mob_set_state(mob_id, 1) -- Força o estado a voltar para 1 (Perseguindo)
            current_state = 1
        end

        -- 2. CANALIZAÇÃO DO GOLPE TELEGRAFADO (State == 2 durante AoE)
        if data.is_charging_aoe then
            if data.state_timer > 0 then
                data.state_timer = data.state_timer - dt
            end

            if data.state_timer > 0 then
                mob_set_state(mob_id, 2) -- Carregando / Canalizando
                return
            end

            -- Duração de 1.5s expirou: Impacto massivo no chão!
            data.is_charging_aoe = false
            data.state_timer = 0.0
            mob_trigger_slam_damage(mob_id, data.telegraph_x, data.telegraph_z, 4.0, 55)

            -- Fica 2.0s vulnerável com a maça presa no chão (State = 4)
            data.is_vulnerable = true
            data.vulnerable_timer = 2.0
            data.special_cd = 4.5
            mob_set_state(mob_id, 4)
            return
        end

        -- 3. PERSEGUIÇÃO E COMBATE REGULAR
        if nearest_player_id > 0 and player_dist <= 12.0 then
            -- Se puder desferir o golpe em área telegrafado
            if data.special_cd <= 0 and player_dist <= 8.0 then
                data.is_charging_aoe = true
                data.state_timer = 1.5 -- 1.5s até a detonação
                data.telegraph_x = player_x
                data.telegraph_z = player_z
                mob_spawn_telegraph(mob_id, player_x, player_z, 4.0, 1500)
                mob_set_state(mob_id, 2) -- State 2: Carregando golpe
                return
            else
                if player_dist > 2.5 then
                    mob_set_state(mob_id, 1) -- Chasing
                    mob_move_to(mob_id, player_x, player_z, base_speed)
                else
                    if data.attack_cd <= 0 then
                        mob_set_state(mob_id, 2)
                        mob_attack_player(mob_id, nearest_player_id, 26)
                        data.attack_cd = 1.8
                    else
                        mob_set_state(mob_id, 1)
                    end
                end
            end
        else
            mob_set_state(mob_id, 0)
            mob_move_to(mob_id, spawn_x, spawn_z, 1.8)
        end

    -- ------------------------------------------------------------------------
    -- 6. LOBO ALFA (MobType == 6 — Ativo na Lua Cheia)
    -- ------------------------------------------------------------------------
    elseif mob_type == 6 then
        local aggro_radius = 15.0
        local move_speed = 4.6
        local bite_damage = 35

        if nearest_player_id > 0 and player_dist <= aggro_radius then
            -- Uivo Alfa a cada 10 segundos para fortalecer a alcateia
            if data.special_cd <= 0 then
                mob_say(mob_id, "*UIVO ALFA! O Lobo Alfa faz o bosque sussurrar em terror!*")
                data.special_cd = 10.0
            end

            if player_dist > 2.2 then
                mob_set_state(mob_id, 1) -- Chasing
                mob_move_to(mob_id, player_x, player_z, move_speed)
            else
                if data.attack_cd <= 0 then
                    mob_set_state(mob_id, 2) -- Attacking
                    mob_attack_player(mob_id, nearest_player_id, bite_damage)
                    data.attack_cd = 1.3
                else
                    mob_set_state(mob_id, 1)
                end
            end
        else
            local dist_to_spawn = math.sqrt((spawn_x - mob_x)^2 + (spawn_z - mob_z)^2)
            if dist_to_spawn > 1.0 then
                mob_set_state(mob_id, 0)
                mob_move_to(mob_id, spawn_x, spawn_z, 2.5)
            else
                mob_set_state(mob_id, 0) -- Idle
            end
        end

    -- ------------------------------------------------------------------------
    -- 7. LICANTROPO ALFA (MobType == 7 — Boss de Raid Secreto da Lua de Sangue)
    -- ------------------------------------------------------------------------
    elseif mob_type == 7 then
        local aggro_radius = 18.0
        local move_speed = 4.4
        local claw_damage = 45

        -- 1. Canalização do Salto Sanguinário (AoE Telegraph 5.0m, 75 dano)
        if data.is_charging_aoe then
            if data.state_timer > 0 then
                data.state_timer = data.state_timer - dt
            end

            if data.state_timer > 0 then
                mob_set_state(mob_id, 2) -- Carregando Salto
                return
            end

            -- Impacto do Salto Sanguinário no local telegrafado!
            data.is_charging_aoe = false
            data.state_timer = 0.0
            mob_move_to(mob_id, data.telegraph_x, data.telegraph_z, 25.0)
            mob_trigger_slam_damage(mob_id, data.telegraph_x, data.telegraph_z, 5.0, 75)
            mob_say(mob_id, "*SALTO SANGUINÁRIO! A fera colide com o solo em uma onda carmesim!*")
            data.special_cd = 6.0
            mob_set_state(mob_id, 1)
            return
        end

        -- 2. Combate Regular e Decisão de Habilidade
        if nearest_player_id > 0 and player_dist <= aggro_radius then
            -- Salto Sanguinário disponível a cada 6.0s
            if data.special_cd <= 0 and player_dist <= 14.0 then
                data.is_charging_aoe = true
                data.state_timer = 1.6 -- 1.6s até o impacto
                data.telegraph_x = player_x
                data.telegraph_z = player_z
                mob_spawn_telegraph(mob_id, player_x, player_z, 5.0, 1600)
                mob_say(mob_id, "*O Licantropo Alfa salta em direção à presa!*")
                mob_set_state(mob_id, 2)
                return
            else
                if player_dist > 2.6 then
                    mob_set_state(mob_id, 1) -- Chasing
                    mob_move_to(mob_id, player_x, player_z, move_speed)
                else
                    if data.attack_cd <= 0 then
                        mob_set_state(mob_id, 2) -- Attacking
                        mob_attack_player(mob_id, nearest_player_id, claw_damage)
                        data.attack_cd = 1.4
                    else
                        mob_set_state(mob_id, 1)
                    end
                end
            end
        else
            local dist_to_spawn = math.sqrt((spawn_x - mob_x)^2 + (spawn_z - mob_z)^2)
            if dist_to_spawn > 1.0 then
                mob_set_state(mob_id, 0)
                mob_move_to(mob_id, spawn_x, spawn_z, 2.0)
            else
                mob_set_state(mob_id, 0)
            end
        end

    -- ------------------------------------------------------------------------
    -- 10. CULTISTA SOMBRIO (MobType == 10 — HP 400, Projéteis de Trevas)
    -- ------------------------------------------------------------------------
    elseif mob_type == 10 then
        local aggro_radius = 14.0
        local move_speed = 3.2

        if nearest_player_id > 0 and player_dist <= aggro_radius then
            if player_dist < 3.2 then
                -- Recuo tático para manter distância de conjuração
                local dx = mob_x - player_x
                local dz = mob_z - player_z
                local len = math.sqrt(dx * dx + dz * dz)
                if len < 0.01 then len = 1.0; dx = 1.0 end
                local retreat_x = mob_x + (dx / len) * 4.5
                local retreat_z = mob_z + (dz / len) * 4.5
                mob_set_state(mob_id, 4) -- Recuando
                mob_move_to(mob_id, retreat_x, retreat_z, 4.0)
            else
                if player_dist <= 12.0 then
                    if data.attack_cd <= 0 then
                        mob_set_state(mob_id, 2) -- Atacando
                        mob_spawn_telegraph(mob_id, player_x, player_z, 2.0, 700)
                        mob_attack_player(mob_id, nearest_player_id, 24)
                        data.attack_cd = 1.8
                    end
                else
                    mob_set_state(mob_id, 1) -- Perseguindo
                    mob_move_to(mob_id, player_x, player_z, move_speed)
                end
            end
        else
            mob_set_state(mob_id, 0)
            mob_move_to(mob_id, spawn_x, spawn_z, 2.0)
        end

    -- ------------------------------------------------------------------------
    -- 11. GÁRGULA DE PEDRA (MobType == 11 — HP 580, Alta Defesa, Mergulho)
    -- ------------------------------------------------------------------------
    elseif mob_type == 11 then
        local aggro_radius = 15.0
        local move_speed = 3.8

        -- Mergulho Aéreo Telegrafado
        if data.is_charging_aoe then
            if data.state_timer > 0 then
                data.state_timer = data.state_timer - dt
            end

            if data.state_timer > 0 then
                mob_set_state(mob_id, 2)
                return
            end

            -- Impacto do Mergulho da Gárgula
            data.is_charging_aoe = false
            data.state_timer = 0.0
            mob_move_to(mob_id, data.telegraph_x, data.telegraph_z, 20.0)
            mob_trigger_slam_damage(mob_id, data.telegraph_x, data.telegraph_z, 3.5, 42)
            mob_say(mob_id, "*A Gárgula de Pedra despenca dos céus em um impacto esmagador!*")
            data.special_cd = 5.0
            mob_set_state(mob_id, 1)
            return
        end

        if nearest_player_id > 0 and player_dist <= aggro_radius then
            -- Dispara Mergulho Telegrafado a cada 5.0s
            if data.special_cd <= 0 and player_dist <= 11.0 then
                data.is_charging_aoe = true
                data.state_timer = 1.2
                data.telegraph_x = player_x
                data.telegraph_z = player_z
                mob_spawn_telegraph(mob_id, player_x, player_z, 3.5, 1200)
                mob_set_state(mob_id, 2)
                return
            else
                if player_dist > 2.2 then
                    mob_set_state(mob_id, 1)
                    mob_move_to(mob_id, player_x, player_z, move_speed)
                else
                    if data.attack_cd <= 0 then
                        mob_set_state(mob_id, 2)
                        mob_attack_player(mob_id, nearest_player_id, 26)
                        data.attack_cd = 1.5
                    else
                        mob_set_state(mob_id, 1)
                    end
                end
            end
        else
            mob_set_state(mob_id, 0)
            mob_move_to(mob_id, spawn_x, spawn_z, 2.0)
        end

    -- ------------------------------------------------------------------------
    -- 12. MINI-BOSS INQUISIDOR VEX (MobType == 12 — HP 1.400, Foice e Correntes)
    -- ------------------------------------------------------------------------
    elseif mob_type == 12 then
        local aggro_radius = 16.0
        local move_speed = 3.4

        -- Correntes de Sombra (AoE Telegraph)
        if data.is_charging_aoe then
            if data.state_timer > 0 then
                data.state_timer = data.state_timer - dt
            end

            if data.state_timer > 0 then
                mob_set_state(mob_id, 2)
                return
            end

            data.is_charging_aoe = false
            data.state_timer = 0.0
            mob_trigger_slam_damage(mob_id, data.telegraph_x, data.telegraph_z, 4.0, 48)
            mob_say(mob_id, "*Inquisidor Vex: 'Suas correntes estão atadas à escuridão!'*")
            data.special_cd = 5.5
            mob_set_state(mob_id, 1)
            return
        end

        if nearest_player_id > 0 and player_dist <= aggro_radius then
            if data.special_cd <= 0 and player_dist <= 10.0 then
                data.is_charging_aoe = true
                data.state_timer = 1.4
                data.telegraph_x = player_x
                data.telegraph_z = player_z
                mob_spawn_telegraph(mob_id, player_x, player_z, 4.0, 1400)
                mob_say(mob_id, "*Inquisidor Vex ergue sua foice envolta em correntes sombrias!*")
                mob_set_state(mob_id, 2)
                return
            else
                if player_dist > 2.6 then
                    mob_set_state(mob_id, 1)
                    mob_move_to(mob_id, player_x, player_z, move_speed)
                else
                    if data.attack_cd <= 0 then
                        mob_set_state(mob_id, 2)
                        mob_attack_player(mob_id, nearest_player_id, 36)
                        data.attack_cd = 1.4
                    else
                        mob_set_state(mob_id, 1)
                    end
                end
            end
        else
            mob_set_state(mob_id, 0)
            mob_move_to(mob_id, spawn_x, spawn_z, 2.0)
        end

    -- ------------------------------------------------------------------------
    -- 13. BOSS NORMAL COMANDANTE VAELEN (MobType == 13 — HP 3.200, Espada & Investidas)
    -- ------------------------------------------------------------------------
    elseif mob_type == 13 then
        local hp_pct = mob_hp / mob_max_hp
        local aggro_radius = 18.0
        local move_speed = 3.5

        -- Ao atingir 50% de HP chama reforços de besteiros
        if hp_pct <= 0.50 and not data.has_called_minions then
            data.has_called_minions = true
            mob_say(mob_id, "*Comandante Vaelen: 'Besteiros da Vigília, cerquem estes insolentes! Fogo à vontade!'*")
        end

        -- Investida Voraz com Espada (AoE Slam)
        if data.is_charging_aoe then
            if data.state_timer > 0 then
                data.state_timer = data.state_timer - dt
            end

            if data.state_timer > 0 then
                mob_set_state(mob_id, 2)
                return
            end

            data.is_charging_aoe = false
            data.state_timer = 0.0
            mob_move_to(mob_id, data.telegraph_x, data.telegraph_z, 16.0)
            mob_trigger_slam_damage(mob_id, data.telegraph_x, data.telegraph_z, 4.0, 56)
            data.special_cd = 6.0
            mob_set_state(mob_id, 1)
            return
        end

        if nearest_player_id > 0 and player_dist <= aggro_radius then
            if data.special_cd <= 0 and player_dist <= 12.0 then
                data.is_charging_aoe = true
                data.state_timer = 1.3
                data.telegraph_x = player_x
                data.telegraph_z = player_z
                mob_spawn_telegraph(mob_id, player_x, player_z, 4.0, 1300)
                mob_say(mob_id, "*Comandante Vaelen prepara uma investida devastadora com sua lâmina pesada!*")
                mob_set_state(mob_id, 2)
                return
            else
                if player_dist > 2.6 then
                    mob_set_state(mob_id, 1)
                    mob_move_to(mob_id, player_x, player_z, move_speed)
                else
                    if data.attack_cd <= 0 then
                        mob_set_state(mob_id, 2)
                        mob_attack_player(mob_id, nearest_player_id, 42)
                        data.attack_cd = 1.3
                    else
                        mob_set_state(mob_id, 1)
                    end
                end
            end
        else
            mob_set_state(mob_id, 0)
            mob_move_to(mob_id, spawn_x, spawn_z, 2.0)
        end

    -- ------------------------------------------------------------------------
    -- 14. RAID BOSS MALAKOR, O ARAUTO DO ECLIPSE (MobType == 14 — HP 7.500)
    -- Desafio de 3 Fases para 5 Jogadores
    -- ------------------------------------------------------------------------
    elseif mob_type == 14 then
        local hp_pct = mob_hp / mob_max_hp
        local aggro_radius = 22.0
        local move_speed = 3.0

        -- Determina a fase atual
        local current_phase = 1
        if hp_pct <= 0.30 then
            current_phase = 3
        elseif hp_pct <= 0.70 then
            current_phase = 2
        end

        -- Transição de Fases com avisos narrativos
        if not data.last_phase then data.last_phase = 1 end
        if current_phase ~= data.last_phase then
            if current_phase == 2 then
                mob_say(mob_id, "*MALAKOR [FASE 2]: 'Correntes do Eclipse, aprisionem suas almas! Destruam os 4 Cristais ou pereçam!'*")
            elseif current_phase == 3 then
                mob_say(mob_id, "*MALAKOR [FASE 3]: 'ECLIPSE TOTAL! A noite eterna recai sobre Lunaria! Permaneçam na luz da Tocha Sagrada!'*")
            end
            data.last_phase = current_phase
        end

        -- Canalização de Habilidade AoE Ativa
        if data.is_charging_aoe then
            if data.state_timer > 0 then
                data.state_timer = data.state_timer - dt
            end

            if data.state_timer > 0 then
                mob_set_state(mob_id, 2)
                return
            end

            data.is_charging_aoe = false
            data.state_timer = 0.0

            if current_phase == 1 then
                -- Fase 1: Clivagem em Arco de 180 graus (Raio 5.0m, 62 dano)
                mob_trigger_slam_damage(mob_id, data.telegraph_x, data.telegraph_z, 5.0, 62)
                mob_say(mob_id, "*Malakor desfere um golpe em arco de 180° exigindo a contenção do Tank!*")
                data.special_cd = 4.0
            elseif current_phase == 2 then
                -- Fase 2: Detonação dos Cristais de Sombra
                mob_trigger_slam_damage(mob_id, data.telegraph_x, data.telegraph_z, 4.0, 50)
                data.special_cd = 5.0
            elseif current_phase == 3 then
                -- Fase 3: Pulso Abissal do Eclipse Total
                mob_trigger_slam_damage(mob_id, mob_x, mob_z, 7.5, 45)
                data.special_cd = 3.5
            end

            mob_set_state(mob_id, 1)
            return
        end

        if nearest_player_id > 0 and player_dist <= aggro_radius then
            -- FASE 1: Golpes em arco de 180° e aggro frontal
            if current_phase == 1 then
                if data.special_cd <= 0 and player_dist <= 8.0 then
                    data.is_charging_aoe = true
                    data.state_timer = 1.4
                    data.telegraph_x = player_x
                    data.telegraph_z = player_z
                    mob_spawn_telegraph(mob_id, player_x, player_z, 5.0, 1400)
                    mob_set_state(mob_id, 2)
                    return
                end

            -- FASE 2: Correntes de Sombra & Cristais Cardeais
            elseif current_phase == 2 then
                if data.special_cd <= 0 then
                    data.is_charging_aoe = true
                    data.state_timer = 1.6
                    data.telegraph_x = player_x
                    data.telegraph_z = player_z
                    -- Sinaliza os 4 Cristais de Sombra ao redor da arena
                    mob_spawn_telegraph(mob_id, -76.0, 75.0, 2.0, 1600)
                    mob_spawn_telegraph(mob_id, -68.0, 75.0, 2.0, 1600)
                    mob_spawn_telegraph(mob_id, -72.0, 79.0, 2.0, 1600)
                    mob_spawn_telegraph(mob_id, -72.0, 71.0, 2.0, 1600)
                    mob_set_state(mob_id, 2)
                    return
                end

            -- FASE 3: Eclipse Total (Escuro absoluto, pulsos constantes na arena)
            elseif current_phase == 3 then
                if data.special_cd <= 0 then
                    data.is_charging_aoe = true
                    data.state_timer = 1.5
                    data.telegraph_x = mob_x
                    data.telegraph_z = mob_z
                    mob_spawn_telegraph(mob_id, mob_x, mob_z, 7.5, 1500)
                    mob_set_state(mob_id, 2)
                    return
                end
            end

            -- Ataque Básico Corpo a Corpo
            if player_dist > 2.8 then
                mob_set_state(mob_id, 1)
                mob_move_to(mob_id, player_x, player_z, move_speed)
            else
                if data.attack_cd <= 0 then
                    mob_set_state(mob_id, 2)
                    local base_dmg = (current_phase == 3) and 58 or 46
                    mob_attack_player(mob_id, nearest_player_id, base_dmg)
                    data.attack_cd = (current_phase == 3) and 1.1 or 1.3
                else
                    mob_set_state(mob_id, 1)
                end
            end
        else
            mob_set_state(mob_id, 0)
            mob_move_to(mob_id, spawn_x, spawn_z, 2.0)
        end

    -- ------------------------------------------------------------------------
    -- 15. ARANHA TECELÃ DA BRUMA (MobType == 15 — HP 380, Cospe Teias & Veneno)
    -- ------------------------------------------------------------------------
    elseif mob_type == 15 then
        local aggro_radius = 12.0
        local move_speed = 3.8

        if nearest_player_id > 0 and player_dist <= aggro_radius then
            if data.special_cd <= 0 and player_dist > 3.0 and player_dist <= 10.0 then
                data.special_cd = 4.5
                mob_spawn_telegraph(mob_id, player_x, player_z, 2.8, 900)
                mob_say(mob_id, "*A Aranha Tecelã cospe um casulo espesso de teia pegajosa!*")
            end

            if player_dist > 2.0 then
                mob_set_state(mob_id, 1)
                mob_move_to(mob_id, player_x, player_z, move_speed)
            else
                if data.attack_cd <= 0 then
                    mob_set_state(mob_id, 2)
                    mob_attack_player(mob_id, nearest_player_id, 24)
                    data.attack_cd = 1.3
                else
                    mob_set_state(mob_id, 1)
                end
            end
        else
            mob_set_state(mob_id, 0)
            mob_move_to(mob_id, spawn_x, spawn_z, 2.0)
        end

    -- ------------------------------------------------------------------------
    -- 16. ARACHNA, A RAINHA TECELÃ (MobType == 16 — RAID BOSS HP 6.800)
    -- Ninho de Teias em (120, -120) no Bosque Sussurrante
    -- ------------------------------------------------------------------------
    elseif mob_type == 16 then
        local aggro_radius = 22.0
        local move_speed = 3.4

        if data.is_charging_aoe then
            if data.state_timer > 0 then
                data.state_timer = data.state_timer - dt
            end

            if data.state_timer > 0 then
                mob_set_state(mob_id, 2)
                return
            end

            data.is_charging_aoe = false
            data.state_timer = 0.0
            mob_trigger_slam_damage(mob_id, data.telegraph_x, data.telegraph_z, 4.8, 52)
            data.special_cd = 6.0
            mob_set_state(mob_id, 1)
            return
        end

        if nearest_player_id > 0 and player_dist <= aggro_radius then
            if data.special_cd <= 0 and player_dist <= 14.0 then
                data.is_charging_aoe = true
                data.state_timer = 1.4
                data.telegraph_x = player_x
                data.telegraph_z = player_z
                mob_spawn_telegraph(mob_id, player_x, player_z, 4.8, 1400)
                mob_say(mob_id, "*Arachna bate suas patas gigantes no solo e dispara casulos imperiais de seda!*")
                mob_set_state(mob_id, 2)
                return
            else
                if player_dist > 2.8 then
                    mob_set_state(mob_id, 1)
                    mob_move_to(mob_id, player_x, player_z, move_speed)
                else
                    if data.attack_cd <= 0 then
                        mob_set_state(mob_id, 2)
                        mob_attack_player(mob_id, nearest_player_id, 46)
                        data.attack_cd = 1.3
                    else
                        mob_set_state(mob_id, 1)
                    end
                end
            end
        else
            mob_set_state(mob_id, 0)
            mob_move_to(mob_id, spawn_x, spawn_z, 2.0)
        end

    -- ------------------------------------------------------------------------
    -- 17. LODO ÁCIDO CORROSIVO (MobType == 17 — HP 320, Esgotos Antigos)
    -- ------------------------------------------------------------------------
    elseif mob_type == 17 then
        local aggro_radius = 10.0
        local move_speed = 2.5

        if nearest_player_id > 0 and player_dist <= aggro_radius then
            if player_dist > 1.8 then
                mob_set_state(mob_id, 1)
                mob_move_to(mob_id, player_x, player_z, move_speed)
            else
                if data.attack_cd <= 0 then
                    mob_set_state(mob_id, 2)
                    mob_attack_player(mob_id, nearest_player_id, 20)
                    data.attack_cd = 1.5
                else
                    mob_set_state(mob_id, 1)
                end
            end
        else
            mob_set_state(mob_id, 0)
            mob_move_to(mob_id, spawn_x, spawn_z, 1.8)
        end

    -- ------------------------------------------------------------------------
    -- 18. ESCORPIÃO ABISSAL GIGANTE (MobType == 18 — HP 540, Esgotos Antigos)
    -- ------------------------------------------------------------------------
    elseif mob_type == 18 then
        local aggro_radius = 12.0
        local move_speed = 3.4

        if data.is_charging_aoe then
            if data.state_timer > 0 then
                data.state_timer = data.state_timer - dt
            end

            if data.state_timer > 0 then
                mob_set_state(mob_id, 2)
                return
            end

            data.is_charging_aoe = false
            data.state_timer = 0.0
            mob_trigger_slam_damage(mob_id, data.telegraph_x, data.telegraph_z, 2.6, 40)
            data.special_cd = 5.0
            mob_set_state(mob_id, 1)
            return
        end

        if nearest_player_id > 0 and player_dist <= aggro_radius then
            if data.special_cd <= 0 and player_dist <= 5.0 then
                data.is_charging_aoe = true
                data.state_timer = 1.1
                data.telegraph_x = player_x
                data.telegraph_z = player_z
                mob_spawn_telegraph(mob_id, player_x, player_z, 2.6, 1100)
                mob_say(mob_id, "*O Escorpião Abissal ergue seu ferrão venenoso verde-neon!*")
                mob_set_state(mob_id, 2)
                return
            else
                if player_dist > 2.2 then
                    mob_set_state(mob_id, 1)
                    mob_move_to(mob_id, player_x, player_z, move_speed)
                else
                    if data.attack_cd <= 0 then
                        mob_set_state(mob_id, 2)
                        mob_attack_player(mob_id, nearest_player_id, 26)
                        data.attack_cd = 1.2
                    else
                        mob_set_state(mob_id, 1)
                    end
                end
            end
        else
            mob_set_state(mob_id, 0)
            mob_move_to(mob_id, spawn_x, spawn_z, 2.0)
        end

    -- ------------------------------------------------------------------------
    -- 19. EXPERIMENTO Nº 0: A QUIMERA COSTURADA (MobType == 19 — MINI-BOSS HP 2.800)
    -- ------------------------------------------------------------------------
    elseif mob_type == 19 then
        local aggro_radius = 16.0
        local move_speed = 3.6

        if data.is_charging_aoe then
            if data.state_timer > 0 then
                data.state_timer = data.state_timer - dt
            end

            if data.state_timer > 0 then
                mob_set_state(mob_id, 2)
                return
            end

            data.is_charging_aoe = false
            data.state_timer = 0.0
            mob_trigger_slam_damage(mob_id, data.telegraph_x, data.telegraph_z, 3.8, 48)
            data.special_cd = 5.5
            mob_set_state(mob_id, 1)
            return
        end

        if nearest_player_id > 0 and player_dist <= aggro_radius then
            if data.special_cd <= 0 and player_dist <= 10.0 then
                data.is_charging_aoe = true
                data.state_timer = 1.2
                data.telegraph_x = player_x
                data.telegraph_z = player_z
                mob_spawn_telegraph(mob_id, player_x, player_z, 3.8, 1200)
                mob_say(mob_id, "*A Quimera Costurada ruge com múltiplas vozes e desfere um golpe titânico!*")
                mob_set_state(mob_id, 2)
                return
            else
                if player_dist > 2.5 then
                    mob_set_state(mob_id, 1)
                    mob_move_to(mob_id, player_x, player_z, move_speed)
                else
                    if data.attack_cd <= 0 then
                        mob_set_state(mob_id, 2)
                        mob_attack_player(mob_id, nearest_player_id, 35)
                        data.attack_cd = 1.3
                    else
                        mob_set_state(mob_id, 1)
                    end
                end
            end
        else
            mob_set_state(mob_id, 0)
            mob_move_to(mob_id, spawn_x, spawn_z, 2.0)
        end

    -- ------------------------------------------------------------------------
    -- 20. GOLEM DE GELO ANTIGO (MobType == 20 — HP 720, Norte Nevado ZoneID 2)
    -- ------------------------------------------------------------------------
    elseif mob_type == 20 then
        local aggro_radius = 12.0
        local move_speed = 2.2

        if data.is_charging_aoe then
            if data.state_timer > 0 then
                data.state_timer = data.state_timer - dt
            end

            if data.state_timer > 0 then
                mob_set_state(mob_id, 2)
                return
            end

            data.is_charging_aoe = false
            data.state_timer = 0.0
            mob_trigger_slam_damage(mob_id, data.telegraph_x, data.telegraph_z, 3.5, 36)
            data.special_cd = 5.0
            mob_set_state(mob_id, 1)
            return
        end

        if nearest_player_id > 0 and player_dist <= aggro_radius then
            if data.special_cd <= 0 and player_dist <= 6.0 then
                data.is_charging_aoe = true
                data.state_timer = 1.3
                data.telegraph_x = player_x
                data.telegraph_z = player_z
                mob_spawn_telegraph(mob_id, player_x, player_z, 3.5, 1300)
                mob_say(mob_id, "*O Golem de Gelo racha o solo congelado com uma pisada estrondosa!*")
                mob_set_state(mob_id, 2)
                return
            else
                if player_dist > 2.2 then
                    mob_set_state(mob_id, 1)
                    mob_move_to(mob_id, player_x, player_z, move_speed)
                else
                    if data.attack_cd <= 0 then
                        mob_set_state(mob_id, 2)
                        mob_attack_player(mob_id, nearest_player_id, 30)
                        data.attack_cd = 1.6
                    else
                        mob_set_state(mob_id, 1)
                    end
                end
            end
        else
            mob_set_state(mob_id, 0)
            mob_move_to(mob_id, spawn_x, spawn_z, 1.8)
        end

    -- ------------------------------------------------------------------------
    -- 21. DRACO DE GEADA SELVAGEM (MobType == 21 — HP 950, Ruínas da Vigília)
    -- ------------------------------------------------------------------------
    elseif mob_type == 21 then
        local aggro_radius = 15.0
        local move_speed = 4.0

        if data.is_charging_aoe then
            if data.state_timer > 0 then
                data.state_timer = data.state_timer - dt
            end

            if data.state_timer > 0 then
                mob_set_state(mob_id, 2)
                return
            end

            data.is_charging_aoe = false
            data.state_timer = 0.0
            mob_trigger_slam_damage(mob_id, data.telegraph_x, data.telegraph_z, 3.8, 42)
            data.special_cd = 5.0
            mob_set_state(mob_id, 1)
            return
        end

        if nearest_player_id > 0 and player_dist <= aggro_radius then
            if data.special_cd <= 0 and player_dist <= 8.0 then
                data.is_charging_aoe = true
                data.state_timer = 1.2
                data.telegraph_x = player_x
                data.telegraph_z = player_z
                mob_spawn_telegraph(mob_id, player_x, player_z, 3.8, 1200)
                mob_say(mob_id, "*O Draco de Geada canaliza um sopro congelante ancestral!*")
                mob_set_state(mob_id, 2)
                return
            else
                if player_dist > 2.4 then
                    mob_set_state(mob_id, 1)
                    mob_move_to(mob_id, player_x, player_z, move_speed)
                else
                    if data.attack_cd <= 0 then
                        mob_set_state(mob_id, 2)
                        mob_attack_player(mob_id, nearest_player_id, 32)
                        data.attack_cd = 1.3
                    else
                        mob_set_state(mob_id, 1)
                    end
                end
            end
        else
            mob_set_state(mob_id, 0)
            mob_move_to(mob_id, spawn_x, spawn_z, 2.0)
        end

    -- ------------------------------------------------------------------------
    -- 22. YMIR, O PATRIARCA GIGANTE DE GELO (MobType == 22 — BOSS HP 5.200)
    -- Trono de Gelo em (0, 150) na ZoneID 2
    -- ------------------------------------------------------------------------
    elseif mob_type == 22 then
        local aggro_radius = 20.0
        local move_speed = 2.8

        if data.is_charging_aoe then
            if data.state_timer > 0 then
                data.state_timer = data.state_timer - dt
            end

            if data.state_timer > 0 then
                mob_set_state(mob_id, 2)
                return
            end

            data.is_charging_aoe = false
            data.state_timer = 0.0
            mob_trigger_slam_damage(mob_id, data.telegraph_x, data.telegraph_z, 5.0, 62)
            data.special_cd = 6.0
            mob_set_state(mob_id, 1)
            return
        end

        if nearest_player_id > 0 and player_dist <= aggro_radius then
            if data.special_cd <= 0 and player_dist <= 12.0 then
                data.is_charging_aoe = true
                data.state_timer = 1.5
                data.telegraph_x = player_x
                data.telegraph_z = player_z
                mob_spawn_telegraph(mob_id, player_x, player_z, 5.0, 1500)
                mob_say(mob_id, "*Ymir ergue sua clava colossal de gelo eterno: 'Sintam a fúria da Geada Boreal!'*")
                mob_set_state(mob_id, 2)
                return
            else
                if player_dist > 2.8 then
                    mob_set_state(mob_id, 1)
                    mob_move_to(mob_id, player_x, player_z, move_speed)
                else
                    if data.attack_cd <= 0 then
                        mob_set_state(mob_id, 2)
                        mob_attack_player(mob_id, nearest_player_id, 48)
                        data.attack_cd = 1.4
                    else
                        mob_set_state(mob_id, 1)
                    end
                end
            end
        else
            mob_set_state(mob_id, 0)
            mob_move_to(mob_id, spawn_x, spawn_z, 2.0)
        end

    -- ------------------------------------------------------------------------
    -- 23. GUARDA SANGUINÁRIO DE VESPERIAN (MobType == 23 — HP 680, Cripta Carmesim)
    -- ------------------------------------------------------------------------
    elseif mob_type == 23 then
        local aggro_radius = 13.0
        local move_speed = 3.6

        if nearest_player_id > 0 and player_dist <= aggro_radius then
            if player_dist > 2.2 then
                mob_set_state(mob_id, 1)
                mob_move_to(mob_id, player_x, player_z, move_speed)
            else
                if data.attack_cd <= 0 then
                    mob_set_state(mob_id, 2)
                    mob_attack_player(mob_id, nearest_player_id, 34)
                    data.attack_cd = 1.3
                else
                    mob_set_state(mob_id, 1)
                end
            end
        else
            mob_set_state(mob_id, 0)
            mob_move_to(mob_id, spawn_x, spawn_z, 2.0)
        end

    -- ------------------------------------------------------------------------
    -- 24. LORDE VESPERIAN, O PROGENITOR VAMPIRO (MobType == 24 — RAID BOSS SECRETO HP 8.500)
    -- Cripta Carmesim em (-140, 140) na ZoneID 3
    -- ------------------------------------------------------------------------
    elseif mob_type == 24 then
        local aggro_radius = 24.0
        local move_speed = 4.2

        if data.is_charging_aoe then
            if data.state_timer > 0 then
                data.state_timer = data.state_timer - dt
            end

            if data.state_timer > 0 then
                mob_set_state(mob_id, 2)
                return
            end

            data.is_charging_aoe = false
            data.state_timer = 0.0
            mob_trigger_slam_damage(mob_id, data.telegraph_x, data.telegraph_z, 5.5, 55)
            mob_heal_ally(mob_id, mob_id, 300)
            data.special_cd = 5.5
            mob_set_state(mob_id, 1)
            return
        end

        if nearest_player_id > 0 and player_dist <= aggro_radius then
            if player_dist > 7.0 and player_dist <= 18.0 and (not data.teleport_cd or data.teleport_cd <= 0) then
                data.teleport_cd = 7.0
                mob_say(mob_id, "*Lorde Vesperian dissolve-se em névoa carmesim e surge instantaneamente atrás de sua presa!*")
                mob_move_to(mob_id, player_x, player_z, 22.0)
            end
            if data.teleport_cd and data.teleport_cd > 0 then
                data.teleport_cd = data.teleport_cd - dt
            end

            if data.special_cd <= 0 and player_dist <= 12.0 then
                data.is_charging_aoe = true
                data.state_timer = 1.3
                data.telegraph_x = player_x
                data.telegraph_z = player_z
                mob_spawn_telegraph(mob_id, player_x, player_z, 5.5, 1300)
                mob_say(mob_id, "*Lorde Vesperian: 'Seu sangue pertencerá ao primeiro dos imortais!'*")
                mob_set_state(mob_id, 2)
                return
            else
                if player_dist > 2.6 then
                    mob_set_state(mob_id, 1)
                    mob_move_to(mob_id, player_x, player_z, move_speed)
                else
                    if data.attack_cd <= 0 then
                        mob_set_state(mob_id, 2)
                        mob_attack_player(mob_id, nearest_player_id, 50)
                        data.attack_cd = 1.1
                    else
                        mob_set_state(mob_id, 1)
                    end
                end
            end
        else
            mob_set_state(mob_id, 0)
            mob_move_to(mob_id, spawn_x, spawn_z, 2.0)
        end
    end
end

-- ============================================================================
-- TABELAS DE DROP BALANCDEADAS (TAXAS RARAS REDUZIDAS PARA 2% A 8%)
-- ============================================================================
DropTables = {
    [1] = {
        name = "Lobo da Bruma",
        drops = {
            { item_id = 1, name = "Carne Crua de Lobo", rate = 1.00, rare = false },
            { item_id = 2, name = "Pelagem Cinzenta", rate = 1.00, rare = false },
            { item_id = 3, name = "Presa Lupina Afiada", rate = 0.25, rare = false },
            { item_id = 4, name = "Garra de Fera", rate = 0.20, rare = false },
            { item_id = 9, name = "Anel de Presa Ancestral", rate = 0.03, rare = true }, -- 3% raro
        }
    },
    [2] = {
        name = "Saqueador Deserdado",
        drops = {
            { item_id = 5, name = "Frasco de Vidro Vazio", rate = 0.80, rare = false },
            { item_id = 10, name = "Carne Nobre Assada", rate = 0.70, rare = false },
            { item_id = 9, name = "Anel de Presa Ancestral", rate = 0.04, rare = true }, -- 4% raro
        }
    },
    [3] = {
        name = "Besteiro da Vigília",
        drops = {
            { item_id = 5, name = "Frasco de Vidro Vazio", rate = 0.80, rare = false },
            { item_id = 10, name = "Carne Nobre Assada", rate = 0.70, rare = false },
            { item_id = 9, name = "Anel de Presa Ancestral", rate = 0.05, rare = true }, -- 5% raro
        }
    },
    [4] = {
        name = "Acólito do Eclipse",
        drops = {
            { item_id = 13, name = "Cálice da Alma Partida", rate = 0.08, rare = true }, -- 8% raro
            { item_id = 17, name = "Tomo da Foice do Eclipse", rate = 0.03, rare = true }, -- 3% raro
        }
    },
    [5] = {
        name = "Executor de Ferro",
        drops = {
            { item_id = 11, name = "Placa de Aço Pesada", rate = 0.60, rare = false },
            { item_id = 5, name = "Frasco de Vidro Vazio", rate = 0.80, rare = false },
            { item_id = 18, name = "Tomo do Martelo Titânico", rate = 0.04, rare = true }, -- 4% raro
        }
    },
    [6] = {
        name = "Lobo Alfa",
        drops = {
            { item_id = 12, name = "Pele Intacta de Lobo Alfa", rate = 1.00, rare = false },
            { item_id = 9, name = "Anel de Presa Ancestral", rate = 0.06, rare = true }, -- 6% raro
        }
    },
    [7] = {
        name = "Licantropo Alfa",
        drops = {
            { item_id = 14, name = "Coração do Licantropo Alfa", rate = 1.00, rare = false },
            { item_id = 18, name = "Tomo do Martelo Titânico", rate = 0.07, rare = true }, -- 7% raro
        }
    },
    [10] = {
        name = "Cultista Sombrio",
        drops = {
            { item_id = 5, name = "Frasco de Vidro Vazio", rate = 0.60, rare = false },
            { item_id = 19, name = "Manto do Cultista Sombrio", rate = 0.05, rare = true }, -- 5% raro
            { item_id = 17, name = "Tomo da Foice do Eclipse", rate = 0.04, rare = true }, -- 4% raro
        }
    },
    [11] = {
        name = "Gárgula de Pedra",
        drops = {
            { item_id = 11, name = "Placa de Aço Pesada", rate = 0.70, rare = false },
            { item_id = 20, name = "Coração Pétreo da Gárgula", rate = 0.06, rare = true }, -- 6% raro
        }
    },
    [12] = {
        name = "Inquisidor Vex (Mini-Boss)",
        drops = {
            { item_id = 21, name = "Foice Sombria do Inquisidor", rate = 0.06, rare = true }, -- 6% raro
            { item_id = 13, name = "Cálice da Alma Partida", rate = 0.07, rare = true }, -- 7% raro
        }
    },
    [13] = {
        name = "Comandante Vaelen, o Traidor (Boss Normal)",
        drops = {
            { item_id = 22, name = "Insígnia do Traidor Vaelen", rate = 0.05, rare = true }, -- 5% raro
            { item_id = 18, name = "Tomo do Martelo Titânico", rate = 0.04, rare = true }, -- 4% raro
            { item_id = 17, name = "Tomo da Foice do Eclipse", rate = 0.04, rare = true }, -- 4% raro
        }
    },
    [14] = {
        name = "Malakor, o Arauto do Eclipse (Raid Boss)",
        drops = {
            { item_id = 23, name = "Olho do Arauto do Eclipse", rate = 0.08, rare = true }, -- 8% raro
            { item_id = 24, name = "Tocha Sagrada do Santuário", rate = 1.00, rare = false },
            { item_id = 21, name = "Foice Sombria do Inquisidor", rate = 0.06, rare = true }, -- 6% raro
            { item_id = 14, name = "Coração do Licantropo Alfa", rate = 0.05, rare = true }, -- 5% raro
        }
    },
    [15] = {
        name = "Aranha Tecelã da Bruma",
        drops = {
            { item_id = 132, name = "Teias de Aranha", rate = 1.00, rare = false },
            { item_id = 11, name = "Glândula de Veneno", rate = 0.25, rare = false },
        }
    },
    [16] = {
        name = "Arachna, a Rainha Tecelã (Raid Boss)",
        drops = {
            { item_id = 43, name = "Coração da Rainha Aranha", rate = 1.00, rare = false },
            { item_id = 45, name = "Manto de Seda Imperial", rate = 1.00, rare = false },
            { item_id = 44, name = "Olho Multifacetado de Arachna", rate = 0.001, rare = true, secret = true },
        }
    },
    [17] = {
        name = "Lodo Ácido Corrosivo",
        drops = {
            { item_id = 153, name = "Seiva Ácida", rate = 1.00, rare = false },
            { item_id = 28, name = "Lixo Orgânico", rate = 1.00, rare = false },
        }
    },
    [18] = {
        name = "Escorpião Abissal Gigante",
        drops = {
            { item_id = 143, name = "Bolsa de Veneno Vorpal", rate = 1.00, rare = false },
            { item_id = 47, name = "Ferrão de Escorpião Abissal", rate = 0.001, rare = true, secret = true },
        }
    },
    [19] = {
        name = "Experimento Nº 0: A Quimera Costurada (Mini-Boss)",
        drops = {
            { item_id = 49, name = "Retalho Quimérico Costurado", rate = 1.00, rare = false },
            { item_id = 11, name = "Glândula de Veneno Mutante", rate = 1.00, rare = false },
            { item_id = 12, name = "Placa de Aço Deformada", rate = 1.00, rare = false },
        }
    },
    [20] = {
        name = "Golem de Gelo Antigo",
        drops = {
            { item_id = 50, name = "Núcleo de Gelo Antigo", rate = 1.00, rare = false },
            { item_id = 12, name = "Placa de Aço Pesada", rate = 1.00, rare = false },
        }
    },
    [21] = {
        name = "Draco de Geada Selvagem",
        drops = {
            { item_id = 51, name = "Escama Dracônica Primordial", rate = 1.00, rare = false },
            { item_id = 10, name = "Carne Nobre Assada", rate = 1.00, rare = false },
        }
    },
    [22] = {
        name = "Ymir, o Patriarca Jotunar (Boss)",
        drops = {
            { item_id = 50, name = "Núcleo de Gelo Ancestral", rate = 1.00, rare = false },
            { item_id = 12, name = "Placa Glacial Reforçada", rate = 1.00, rare = false },
            { item_id = 52, name = "Coração de Geada Eterna", rate = 0.001, rare = true, secret = true },
        }
    },
    [23] = {
        name = "Guarda Sanguinário de Vesperian",
        drops = {
            { item_id = 53, name = "Insígnia do Guarda Carmesim", rate = 1.00, rare = false },
            { item_id = 10, name = "Sangue Lunar Puro", rate = 1.00, rare = false },
        }
    },
    [24] = {
        name = "Lorde Vesperian, o Progenitor Vampiro (Raid Boss Secreto)",
        drops = {
            { item_id = 55, name = "Anel Carmesim de Vesperian", rate = 1.00, rare = false },
            { item_id = 17, name = "Tomo da Foice do Eclipse", rate = 1.00, rare = false },
            { item_id = 54, name = "Sangue Puro do Progenitor", rate = 0.001, rare = true, secret = true },
        }
    }
}

-- Gera o relatório consolidado de taxas de drop para o desenvolvedor
function GetDropRatesReport()
    local lines = {}
    table.insert(lines, "==================================================")
    table.insert(lines, "    LUNARIA ONLINE — TABELA DE TAXAS DE DROP (DEV)")
    table.insert(lines, "==================================================")

    local sorted_types = {1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24}
    for _, t in ipairs(sorted_types) do
        local entry = DropTables[t]
        if entry then
            table.insert(lines, string.format("[Mob %d] %s:", t, entry.name))
            for _, d in ipairs(entry.drops) do
                local rare_tag = d.rare and " [RARO]" or ""
                if d.secret then
                    rare_tag = " [SECRETO 0.1%]"
                end
                table.insert(lines, string.format("  - Item #%d (%s): %.1f%%%s", d.item_id, d.name, d.rate * 100.0, rare_tag))
            end
        end
    end
    table.insert(lines, "==================================================")
    return table.concat(lines, "\n")
end
