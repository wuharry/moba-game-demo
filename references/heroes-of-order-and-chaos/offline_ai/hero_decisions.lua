-- Offline clone, both factions. Keep original hero spell definitions and engine
-- validation (range, mana, cooldown, targets); never alter combat statistics.
OfflineHeroAI = OfflineHeroAI or {version = 3, stats = {}}
local AI = OfflineHeroAI

function AI.Alive(guid)
    return type(guid) == "number" and guid > 0 and IsObjectExist(guid)
        and GetUnitParameters(guid, UNIT_PARAM_HP) > 0
end

function AI.Ratio(guid)
    return GetUnitParameters(guid, UNIT_PARAM_HP)
        / math.max(1, GetUnitParameters(guid, UNIT_PARAM_MAX_HP))
end

function AI.Context(self)
    local faction = GetUnitParameters(self, UNIT_PARAM_FACTION_TYPE)
    local enemies = GetSurroundingUnits(self, 1-faction, 12)
    local allies = GetSurroundingUnits(self, faction, 10)
    local ctx = {faction=faction, enemies={}, towers={}, enemyHeroes=0,
        allyHeroes=1, towerAggro=false, ratio=AI.Ratio(self),
        allies={}, allyTargets={}, protectTargets={}}
    for _, guid in pairs(allies) do
        if guid ~= self and AI.Alive(guid) and GetUnitType(guid) <= 1 then
            ctx.allies[guid] = AI.Ratio(guid)
            if ctx.allies[guid] > 0.3 then ctx.allyHeroes = ctx.allyHeroes + 1 end
            local _, target = GetTarget(guid)
            if AI.Alive(target) and GetUnitType(target) <= 1
                and GetUnitParameters(target, UNIT_PARAM_FACTION_TYPE) == 1-faction then
                ctx.allyTargets[target] = (ctx.allyTargets[target] or 0)+1
            end
        end
    end
    for _, guid in pairs(enemies) do
        if AI.Alive(guid) then
            table.insert(ctx.enemies, guid)
            local kind = GetUnitType(guid)
            if kind <= 1 then
                ctx.enemyHeroes = ctx.enemyHeroes + 1
                local _, victim = GetTarget(guid)
                if ctx.allies[victim] and ctx.allies[victim] < 0.45 then
                    ctx.protectTargets[guid] = true
                end
            end
            if kind == UNIT_SCRIPT_BUILDING
                and GetUnitParameters(guid, UNIT_PARAM_ATTACK_VALUE) >= 50 then
                local _, victim = GetTarget(guid)
                local range = GetUnitParameters(guid, UNIT_PARAM_ATTACK_RANGE)
                if type(range) ~= "number" or range <= 0 then range = 8 end
                local covered = victim ~= self and AI.Alive(victim)
                    and GetUnitParameters(victim, UNIT_PARAM_FACTION_TYPE) == faction
                    and AI.Ratio(victim) > 0.3
                table.insert(ctx.towers, {guid=guid, range=range, covered=covered})
                if victim == self and GetUnitsFlatDistance(self, guid) <= (range+2)^2 then
                    ctx.towerAggro = true
                end
            end
        end
    end
    return ctx
end

function AI.SafeTarget(self, target, ctx)
    if not AI.Alive(target)
        or GetUnitParameters(target, UNIT_PARAM_FACTION_TYPE) == ctx.faction then
        return false
    end
    -- Do not add hidden units to the native engine's already filtered query.
    if GetUnitType(target) <= 1 then
        if ctx.ratio < 0.3 and GetUnitsFlatDistance(self, target) > 9 then return false end
        for _, tower in ipairs(ctx.towers) do
            if not tower.covered
                and GetUnitsFlatDistance(target, tower.guid) <= (tower.range+1)^2 then
                return false
            end
        end
    end
    return true
end

function AI.Focus(self, target, ctx)
    local candidates = {}
    -- Original focus search was 5 world units; retain that visibility/range scope.
    for _, guid in ipairs(ctx.enemies) do
        local distance = GetUnitsFlatDistance(self, guid)
        if distance <= 25 then
            if AI.SafeTarget(self, guid, ctx) then
                local score = (1-AI.Ratio(guid))*40 - math.sqrt(distance)*4
                if GetUnitType(guid) <= 1 then score = score + 50 end
                if guid == target then score = score + 8 end -- avoid target thrashing
                score = score + 18*math.min(2, ctx.allyTargets[guid] or 0)
                if ctx.protectTargets[guid] then score = score + 24 end
                table.insert(candidates, {guid=guid, score=score})
            elseif GetUnitType(guid) <= 1 then
                ForcePriorityChange(self, guid, 0, 700)
            end
        end
    end
    table.sort(candidates, function(a,b)
        if a.score == b.score then return a.guid < b.guid end
        return a.score > b.score
    end)
    for i=1, math.min(3, #candidates) do
        local guid = candidates[i].guid
        local priority = 4-i
        if GetUnitType(guid) <= 1 then priority = priority*5 end
        ForcePriorityChange(self, guid, priority, 700)
    end
    local best = candidates[1] and candidates[1].guid
    if best and (ctx.allyTargets[best] or ctx.protectTargets[best]) then
        local stats = AI.Stats(self)
        stats.assistChoices = stats.assistChoices+1
    end
    return best
end

function AI.MustRetreat(ctx)
    return ctx.towerAggro
        or ctx.ratio <= 0.22
        or (ctx.ratio < 0.45 and ctx.enemyHeroes > ctx.allyHeroes)
        or (ctx.ratio < 0.7 and ctx.enemyHeroes >= ctx.allyHeroes+2)
end

function AI.CanResume(self)
    if not AI.Alive(self) then return false end
    local ctx = AI.Context(self)
    return ctx.ratio >= 0.5 and not ctx.towerAggro
        and ctx.enemyHeroes <= ctx.allyHeroes
end

function AI.BeginRetreat(self, ctx, stats)
    local path = AI_Player_Path_Info and AI_Player_Path_Info[self]
    if Retreat_AI_Players[self] or Battle_Start ~= true
        or not path or not March_Path[path.path_name] then return false end
    Retreat_AI_Players[self] = true
    if BaseAid_Heroes_Order[self] or BaseAid_Heroes_Chaos[self] then
        if ctx.faction == 0 then Start_Base_SiegeCheck_Order(self, 0, true)
        else Start_Base_SiegeCheck_Chaos(self, 0, true) end
    else
        Temp_AI_Retreat_Actions(self)
    end
    stats.retreats = stats.retreats + 1
    if ctx.towerAggro then stats.towerRetreats = stats.towerRetreats + 1 end
    return true
end

function AI.TryCast(self, slot, types, target, ctx)
    local kind, relation = types[1], types[2]
    local channel = kind == SKILLTYPE_CHANNEL
    local use_to
    if relation == SKILLTYPE_SELF then
        use_to = self
    elseif relation == SKILLTYPE_ALLY then
        local suggested = channel and types[5] or types[3]
        use_to = AI.Alive(suggested) and suggested or self
        if GetUnitParameters(use_to, UNIT_PARAM_FACTION_TYPE) ~= ctx.faction then return false end
    elseif relation == SKILLTYPE_ENEMY then
        local suggested = channel and types[5] or types[3]
        use_to = AI.Alive(suggested) and suggested or target
        if not AI.SafeTarget(self, use_to, ctx)
            or GetUnitType(use_to) == UNIT_SCRIPT_BUILDING then return false end
    else
        return false
    end
    local cast_type = channel and types[3] or kind
    local result = false
    if cast_type == SKILLTYPE_TARGET then
        result = CastSkillToUnit(self, slot, use_to)
    elseif cast_type == SKILLTYPE_POSITION then
        local pos = (not channel and type(types[3]) == "table") and types[3] or GetUnitPosition(use_to)
        if type(pos) ~= "table" or not pos[1] or not pos[2] or not pos[3] then return false end
        result = CastSkillToPos(self, slot, pos[1], pos[2], pos[3])
    elseif cast_type == SKILLTYPE_DIRECTION then
        local p1, p2 = GetUnitPosition(self), GetUnitPosition(use_to)
        local direction = GetDirection(p1[1], p1[3], p2[1], p2[3])
        -- Channel types[3] is a cast-mode enum, never an "aim at current facing" flag.
        local current_facing = not channel and types[3] == true
        result = CastSkillToDirection(self, slot, current_facing, direction)
    elseif cast_type == SKILLTYPE_SWITCH then
        -- The legacy binding has no return value; stop after dispatching a switch.
        ScriptSwitchSpell(use_to, slot)
        result = true
    end
    if result == true and channel then
        AI_Hero_Countings[self][3] = math.max(1, tonumber(types[4]) or 1)
    end
    return result == true
end

function AI.Stats(self)
    local stats = AI.stats[self]
    if not stats then
        stats = {updates=0, casts=0, attempts=0, fallbacks=0, retreats=0,
            towerRetreats=0, scoreErrors=0, assistChoices=0, lastReport=-30}
        AI.stats[self] = stats
    end
    return stats
end

function AI.Report(self, stats)
    local now = GetClockTick()
    -- The game's clock counts down before battle and then starts at zero.
    if now < stats.lastReport then stats.lastReport = now end
    if now-stats.lastReport < 30 then return end
    stats.lastReport = now
    print(string.format("OFFLINE_AI_V3 t=%d hero=%d faction=%d decisions=%d casts=%d attempts=%d fallback=%d retreat=%d tower=%d errors=%d",
        now, self, GetUnitParameters(self, UNIT_PARAM_FACTION_TYPE), stats.updates,
        stats.casts, stats.attempts, stats.fallbacks, stats.retreats, stats.towerRetreats, stats.scoreErrors))
    -- Small, overwritten local diagnostic snapshot; no network and no UI text.
    if type(io) == "table" and type(io.open) == "function" then
        local file = io.open("/data/user/0/com.gameloft.android.ANMP.GloftHOHO/files/offline-ai-metrics.txt", "w")
        if file then
            file:write("OFFLINE_AI_V3 time="..now.."\n")
            for guid, value in pairs(AI.stats) do
                if AI.Alive(guid) then
                    file:write(string.format("hero=%d entry=%d faction=%d decisions=%d casts=%d attempts=%d fallback=%d retreats=%d tower=%d errors=%d assist=%d\n",
                        guid, GetUnitParameters(guid, UNIT_PARAM_ENTRY), GetUnitParameters(guid, UNIT_PARAM_FACTION_TYPE),
                        value.updates, value.casts, value.attempts, value.fallbacks, value.retreats, value.towerRetreats, value.scoreErrors, value.assistChoices))
                end
            end
            file:close()
        end
    end
end

function AI.Update()
    local self = GetSelfGuid()
    local counting = AI_Hero_Countings and AI_Hero_Countings[self]
    if not counting or not AI.Alive(self) or counting.suspend then return end
    AI_Counting[self] = (AI_Counting[self] or 0)+1
    local stats = AI.Stats(self)
    AI.Report(self, stats)
    -- Do not interrupt a recall or issue a second retreat timer.
    if Retreat_AI_Players[self] then return end
    if counting[3] > 0 then counting[3] = counting[3]-1; return end
    counting[1] = counting[1]+1
    if counting[1] < 4 then return end
    counting[1] = 0
    stats.updates = stats.updates+1
    local ctx = AI.Context(self)
    if AI.MustRetreat(ctx) and AI.BeginRetreat(self, ctx, stats) then return end
    local _, target = GetTarget(self)
    if not AI.Alive(target) then target = 0 end
    AI.Focus(self, target, ctx)
    local slots, seen = {}, {}
    for _, slot in pairs(AI_Hero_Available_Skill[self] or {}) do
        if not seen[slot] then table.insert(slots, slot); seen[slot] = true end
    end
    for slot=4,6 do
        if not seen[slot] then table.insert(slots, slot); seen[slot] = true end
    end
    local candidates = {}
    for _, slot in ipairs(slots) do
        local spell = GetUnitSkill(self, slot)
        local evaluate = AI_Skill_Info[spell]
        if evaluate then
            local ok, weight, types = pcall(evaluate, 0, {0,0}, self, target, target > 0 and 1 or 0)
            if not ok then
                stats.scoreErrors = stats.scoreErrors+1
                if stats.scoreErrors <= 3 then print("OFFLINE_AI_SCORE_ERROR "..spell.." "..tostring(weight)) end
            elseif type(weight) == "number" and weight == weight and math.abs(weight) < math.huge
                and type(types) == "table" then
                weight = weight*((target > 0 and GetUnitType(target) <= 1) and 1.25 or 0.75)
                -- Legacy selection sometimes chose useful spells below normal-attack
                -- weight. Keep that option at a slower cadence against heroes only;
                -- never turn a weak recall/summoner score into an extra cast.
                local low_priority_spell = slot >= 0 and slot < 4 and stats.updates%3 == 0
                    and target > 0 and GetUnitType(target) <= 1
                if weight > 55 or (weight > 0 and low_priority_spell) then
                    table.insert(candidates, {slot=slot, weight=weight, types=types})
                end
            end
        end
    end
    table.sort(candidates, function(a,b)
        if a.weight == b.weight then return a.slot < b.slot end
        return a.weight > b.weight
    end)
    local attempts = 0
    for _, candidate in ipairs(candidates) do
        if candidate.slot == AI_Skill_Recall then
            if AI.BeginRetreat(self, ctx, stats) then return end
        else
            attempts = attempts+1
            stats.attempts = stats.attempts+1
            if AI.TryCast(self, candidate.slot, candidate.types, target, ctx) then
                stats.casts = stats.casts+1
                if attempts > 1 then stats.fallbacks = stats.fallbacks+1 end
                return
            end
            if attempts >= 3 then return end
        end
    end
end

function Action_Hero_Common_Update()
    if GetGameMode() == GAME_MODE_TUTORIAL then return Legacy_Hero_Common_Update() end
    return AI.Update()
end
