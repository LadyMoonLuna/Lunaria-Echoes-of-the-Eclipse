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
    end
end
