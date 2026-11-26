-- Execute actual Lua 5.1 game scripts against controlled engine responses.
assert(_VERSION == 'Lua 5.1')
UNIT_PARAM_HP=0; UNIT_PARAM_MP=1; UNIT_PARAM_MAX_HP=2; UNIT_PARAM_MAX_MP=3
UNIT_PARAM_FACTION_TYPE=4; UNIT_PARAM_ENTRY=5; UNIT_PARAM_ATTACK_VALUE=9; UNIT_PARAM_ATTACK_RANGE=39
UNIT_SCRIPT_BUILDING=4; GAME_MODE_TUTORIAL=99; AI_Skill_Recall=6
SKILLTYPE_TARGET=1; SKILLTYPE_POSITION=2; SKILLTYPE_DIRECTION=3; SKILLTYPE_CHANNEL=4
SKILLTYPE_SWITCH=5; SKILLTYPE_ENEMY=101; SKILLTYPE_ALLY=102; SKILLTYPE_SELF=103
local me=0
local units, casts, priorities, events, rejected, skills, mode
function GetSelfGuid() return me end
function LoadScript(path) dofile('analysis/unpacked/script.bin/script/'..path) end
function GetGameMode() return mode or 1 end
function IsObjectExist(guid) return units and units[guid] ~= nil end
function GetUnitParameters(guid, param)
    if guid == 0 then guid=me end -- native binding's self alias
    return units[guid] and (units[guid][param or 0] or 0) or 0
end
function GetUnitType(guid) return units[guid] and units[guid].kind or 3 end
function GetTarget(guid) return 1, units[guid] and units[guid].target or 0 end
function GetUnitPosition(guid) return {units[guid].x, 0, units[guid].z} end
function GetUnitsFlatDistance(a,b)
    return (units[a].x-units[b].x)^2+(units[a].z-units[b].z)^2
end
function GetSurroundingUnits(guid, faction, range)
    local result={}
    for id,unit in pairs(units) do
        if id ~= guid and unit[4] == faction and unit[0] > 0
            and GetUnitsFlatDistance(guid,id) <= range^2 then table.insert(result,id) end
    end
    return result,#result
end
function GetUnitSkill(guid,slot) return skills[slot] or 0 end
function GetSynRandom(low,high) return low end -- actual game uses an exclusive upper bound
function GetSynRandomf(low,high) return low end
function GetClockTick() return 31 end
function ForcePriorityChange(self,guid,p,duration) priorities[guid]=p end
function table.clone(src,dst) for k,v in pairs(src) do dst[k]=v end end
function CastSkillToUnit(self,slot,target)
    table.insert(casts,{slot=slot,target=target,kind='unit'})
    return not rejected[slot]
end
function CastSkillToPos(self,slot,x,y,z)
    table.insert(casts,{slot=slot,x=x,z=z,kind='position'})
    return not rejected[slot]
end
function GetDirection(x,z,tx,tz) return tx-x+100*(tz-z) end
function CastSkillToDirection(self,slot,current,direction)
    table.insert(casts,{slot=slot,current=current,direction=direction,kind='direction'})
    return not rejected[slot]
end
function ScriptSwitchSpell(self,slot) table.insert(casts,{slot=slot,kind='switch'}) end
function Temp_AI_Retreat_Actions(guid) events.retreat=events.retreat+1 end
function Start_Base_SiegeCheck_Order() events.retreat=events.retreat+1 end
function Start_Base_SiegeCheck_Chaos() events.retreat=events.retreat+1 end
function SetUnitAIType(guid,kind) events.aiType=kind end
function TriggerRemovePointReachedEvent() end
function CreateFunctionClock() return 1 end
function TriggerFunctionClockEvent() end
function StartFunctionClock() end
function TriggerRegisterSkillInterrupt() end
function Resume_AI_Player_Moving() events.resume=events.resume+1 end

dofile('analysis/unpacked/script.bin/script/AI/Action/Action_AIHero_Common.lua')
local before_update=Action_Hero_Common_Update
SetSkillInfo(); SetSkillInfo_2()
local real_skill_info=AI_Skill_Info
dofile('analysis/unpacked/script.bin/script/AI/Player/Temp_AIPlayers.lua')
local before_situation=Temp_CheckSituation
dofile('trial/ai-unpacked/script/AI/Player/Temp_AIPlayers.lua')
local after_situation=Temp_CheckSituation
-- Restore engine observers overwritten by the real player script.
function Temp_AI_Retreat_Actions(guid) events.retreat=events.retreat+1 end
function Resume_AI_Player_Moving() events.resume=events.resume+1 end
Legacy_Hero_Common_Update=before_update
dofile('offline_ai/hero_decisions.lua')
local AI=OfflineHeroAI
local function unit(faction,kind,hp,x,z)
    return {[0]=hp or 1000,[1]=500,[2]=1000,[3]=500,[4]=faction,[5]=1,[9]=60,[39]=8,
        kind=kind or 1,x=x or 100,z=z or 100,target=0}
end
local function reset(faction)
    faction=faction or 0
    me=1; mode=1
    units={[1]=unit(faction),[2]=unit(1-faction,1,700,103,100)}
    units[1].target=2
    casts={}; priorities={}; events={retreat=0,resume=0}; rejected={}
    skills={[0]=101,[1]=102,[6]=3}
    AI_Hero_Countings={[1]={[1]=3,[2]={},[3]=0,suspend=false}}
    AI_Counting={[1]=0}; AI_Hero_Available_Skill={[1]={0,1}}
    AI_Skill_Info={
        [101]=function() return 100,{SKILLTYPE_TARGET,SKILLTYPE_ENEMY} end,
        [102]=function() return 80,{SKILLTYPE_TARGET,SKILLTYPE_ENEMY} end,
        [3]=function() return 0,{0,0} end}
    Retreat_AI_Players={}; AI_Retreat_Teleport={[1]=false}; RetreatCheck_Times={[1]=60}
    AI_Player_Path_Info={[1]={path_name='lane',index=2}}; March_Path={lane={{0,0,0},{100,0,100}}}
    BaseAid_Heroes_Order={}; BaseAid_Heroes_Chaos={}; Battle_Start=true
    AI_HomeRun_Order={0,0}; AI_HomeRun_Chaos={0,0}
    AI.stats={}; AI.Stats(1).lastReport=31
end
local results={}
local function test(name,fn)
    fn(); table.insert(results,name); print('PASS '..name)
end
test('cooldown failure tries the next usable skill, both factions',function()
    reset(); rejected[0]=true; AI_Hero_Countings[1][1]=9; before_update()
    assert(#casts==1 and casts[1].slot==0 and events.retreat==0)
    for faction=0,1 do
        reset(faction); rejected[0]=true; AI.Update()
        assert(#casts==2 and casts[1].slot==0 and casts[2].slot==1)
        assert(AI.Stats(1).casts==1 and AI.Stats(1).fallbacks==1)
    end
end)
test('critical health retreats instead of choosing a high-score attack',function()
    reset(); units[1][0]=150; AI_Hero_Countings[1][1]=9; before_update()
    assert(events.retreat==0 and #casts==1)
    for faction=0,1 do
        reset(faction); units[1][0]=150; AI.Update()
        assert(events.retreat==1 and #casts==0 and Retreat_AI_Players[1])
        AI.Update(); assert(events.retreat==1)
    end
end)
test('tower aggro forces retreat at full health',function()
    reset(); units[3]=unit(1,4,1000,105,100); units[3].target=1
    AI.Update(); assert(events.retreat==1 and AI.Stats(1).towerRetreats==1)
end)
test('retreat does not resume under an attacking tower',function()
    local function situation()
        reset(); units[1][0]=600; units[2]=nil
        units[3]=unit(1,4,1000,105,100); units[3].target=1
        for id=4,7 do units[id]=unit(0,2,1000,100+id/10,100) end
    end
    situation(); before_situation(1); assert(events.resume==1)
    situation(); after_situation(1); assert(events.resume==0)
end)
test('healthy retreat can resume with allied support',function()
    reset(); units[1][0]=800; units[2]=nil
    units[3]=unit(0,1,1000,102,100); units[4]=unit(0,2,1000,101,100)
    after_situation(1); assert(events.resume==1)
end)
test('safe vulnerable hero is focused; unsupported tower target is suppressed',function()
    reset(); units[2][0]=200; units[3]=unit(1,2,20,101,100)
    AI.Focus(1,2,AI.Context(1)); assert(priorities[2]>priorities[3])
    units[4]=unit(1,4,1000,109,100)
    AI.Focus(1,2,AI.Context(1)); assert(priorities[2]==0)
end)
test('allied tower cover allows an otherwise safe target',function()
    reset(); units[3]=unit(1,4,1000,109,100)
    units[4]=unit(0,2,900,105,100); units[3].target=4
    assert(AI.SafeTarget(1,2,AI.Context(1)))
end)
test('both factions prioritize a nearby teammate focus target',function()
    for faction=0,1 do
        reset(faction); units[3]=unit(1-faction,1,700,100,103)
        units[4]=unit(faction,1,1000,101,100); units[4].target=3
        assert(AI.Focus(1,2,AI.Context(1))==3)
        assert(priorities[3]>priorities[2] and AI.Stats(1).assistChoices==1)
    end
end)
test('both factions protect low-health teammates from a nearby pursuer',function()
    for faction=0,1 do
        reset(faction); units[3]=unit(1-faction,1,700,100,103)
        units[4]=unit(faction,1,200,101,101); units[3].target=4
        assert(AI.Focus(1,2,AI.Context(1))==3)
    end
end)
test('team focus does not override tower safety or extend local search',function()
    reset(); units[3]=unit(1,1,700,100,103)
    units[4]=unit(0,1,1000,101,100); units[4].target=3
    units[5]=unit(1,4,1000,100,112)
    AI.Focus(1,2,AI.Context(1)); assert(priorities[3]==0)
    units[5]=nil; units[3].z=108; priorities={}
    AI.Focus(1,2,AI.Context(1)); assert(priorities[3]==nil)
end)
test('channeling and existing recall are not interrupted',function()
    reset(); AI_Hero_Countings[1][3]=5; AI.Update()
    assert(#casts==0 and AI_Hero_Countings[1][3]==4)
    reset(); Retreat_AI_Players[1]=true; AI.Update(); assert(#casts==0)
end)
test('channel aim uses the actual enemy, not enum/object-id collisions',function()
    reset(); units[3]=unit(1,1,1000,101,100)
    assert(AI.TryCast(1,0,{4,101,3,30,2},2,AI.Context(1)))
    assert(casts[1].kind=='direction' and casts[1].current==false and casts[1].direction==3)
    assert(AI_Hero_Countings[1][3]==30)
end)
test('position payloads are not treated as object IDs',function()
    reset(); assert(AI.TryCast(1,0,{2,101,{104,0,102}},2,AI.Context(1)))
    assert(casts[1].x==104 and casts[1].z==102)
end)
test('dead or allied offensive targets do not cast',function()
    reset(); units[2][0]=0; AI.Update(); assert(#casts==0)
    reset(); units[2][4]=0; AI.Update(); assert(#casts==0)
end)
test('invalid scores and scorer errors do not block another ability',function()
    reset(); AI_Skill_Info[101]=function() return 0/0,{1,101} end
    AI.Update(); assert(#casts==1 and casts[1].slot==1)
    reset(); AI_Skill_Info[101]=function() error('controlled scorer failure') end
    AI.Update(); assert(#casts==1 and casts[1].slot==1 and AI.Stats(1).scoreErrors==1)
end)
test('failed casts are bounded to three per decision',function()
    reset(); skills[4]=104; skills[5]=105; rejected={[0]=true,[1]=true,[4]=true,[5]=true}
    AI_Skill_Info[104]=AI_Skill_Info[101]; AI_Skill_Info[105]=AI_Skill_Info[101]
    AI.Update(); assert(#casts==3 and AI.Stats(1).casts==0)
end)
test('one successful cast ends the decision',function()
    reset(); AI.Update(); assert(#casts==1 and AI.Stats(1).casts==1)
end)
test('original hero and summoner scorers work with the new dispatcher',function()
    for faction=0,1 do
        reset(faction); units[2][0]=100
        AI_Skill_Info=real_skill_info
        skills={[0]=84,[1]=72,[4]=34,[5]=593,[6]=3}
        AI.Update()
        assert(#casts==1 and casts[1].kind=='position' and casts[1].slot==1)
        assert(AI.Stats(1).scoreErrors==0)
    end
end)
test('real low-score mage ability remains available at a bounded cadence, both factions',function()
    local random = GetSynRandom
    reset(); AI_Skill_Info=real_skill_info; skills={[0]=1808}
    AI_Hero_Available_Skill[1]={0}; AI_Hero_Countings[1][1]=9
    GetSynRandom=function(low,high) return high-1 end
    before_update()
    assert(#casts==1 and casts[1].kind=='direction') -- legacy sometimes chooses below normal-attack weight
    GetSynRandom=random
    for faction=0,1 do
        reset(faction); AI_Skill_Info=real_skill_info; skills={[0]=1808}
        AI_Hero_Available_Skill[1]={0}
        AI.Update(); assert(#casts==0)
        AI_Hero_Countings[1][1]=3; AI.Update(); assert(#casts==0)
        AI_Hero_Countings[1][1]=3; AI.Update()
        assert(#casts==1 and casts[1].kind=='direction' and AI.Stats(1).casts==1)
    end
end)

test('low-score fallback does not waste spells on creeps or trigger weak recall scores',function()
    reset(); AI.stats[1].updates=2; units[2].kind=3
    AI_Skill_Info[101]=function() return 30,{SKILLTYPE_TARGET,SKILLTYPE_ENEMY} end
    AI_Skill_Info[102]=AI_Skill_Info[101]
    AI.Update(); assert(#casts==0 and events.retreat==0)
    reset(); AI.stats[1].updates=2; skills={[6]=3}; AI_Hero_Available_Skill[1]={}
    AI_Skill_Info[3]=function() return 30,{SKILLTYPE_TARGET,SKILLTYPE_SELF} end
    AI.Update(); assert(#casts==0 and events.retreat==0)
end)

test('tutorial dispatch retains legacy behavior without playing tutorial',function()
    reset(); mode=GAME_MODE_TUTORIAL; local called=0
    Legacy_Hero_Common_Update=function() called=called+1 end
    Action_Hero_Common_Update(); assert(called==1 and #casts==0)
end)
test('packaged scripts compile in Lua 5.1',function()
    assert(loadfile('trial/ai-unpacked/script/AI/Action/Action_AIHero_Common.lua'))
    assert(loadfile('trial/ai-unpacked/script/AI/Player/Temp_AIPlayers.lua'))
    assert(loadfile('trial/ai-unpacked/script/AI/Action/Offline_Hero_Decisions.lua'))
end)
local file=assert(io.open('trial/ai-scenario-verification.json','w'))
file:write('{"runtime":"Lua 5.1","status":"PASS","scenario_count":'..#results..',"scenarios":[')
for i,name in ipairs(results) do
    if i>1 then file:write(',') end
    file:write('"'..name..'"')
end
file:write('],"scope":"Actual Lua functions with controlled engine mocks; not device gameplay proof."}\n')
file:close()
print('PASS '..#results..' scenarios')
