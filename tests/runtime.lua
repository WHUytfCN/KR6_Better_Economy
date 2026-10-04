local ok, R=pcall(require,'src.runtime')
assert(ok,'runtime integration must be implemented')
local function eq(a,b) assert(math.abs(a-b)<1e-8,tostring(a)..' ~= '..tostring(b)) end
local received={}
local sig={emit=function(name,e,amount) received[#received+1]={name,e,amount} end}
local systems={level={},health={},tower_upgrade={},goal_line={}}
function systems.level:init(s) s.player_gold=400 end
function systems.health:on_update(s,e)
 s.player_gold=s.player_gold+e.enemy.gold
 sig.emit('got-enemy-gold',e,e.enemy.gold)
end
function systems.tower_upgrade:on_update(s,n) s.player_gold=s.player_gold+n end
function systems.goal_line:on_update(s,n) s.player_gold=s.player_gold+n end
local templates={enemy_skeleton={enemy={gold=6}},enemy_gargoyle={enemy={gold=20}},enemy_darkling={enemy={gold=0}}}
local r=R.new({global=1.25,initial=1.25,enemy=1.20,summons=true},{signal=sig,entities={entities=templates},settings={}})
local s={player_gold=0,level_mode=1,untouched=42}
r:attach(s,systems)
systems.level:init(s);eq(s.player_gold,625)
systems.tower_upgrade:on_update(s,100);eq(s.player_gold,725)
systems.tower_upgrade:on_update(s,-100);eq(s.player_gold,625)
s.player_gold=s.player_gold+20;eq(s.player_gold,650)
local ordinary={template_name='enemy_skeleton',enemy={gold=6}}
systems.health:on_update(s,ordinary);eq(s.player_gold,659);eq(received[#received][3],9)
local summoned={template_name='enemy_skeleton',enemy={gold=0}}
r:tag(summoned,'necromancer')
systems.health:on_update(s,summoned);eq(s.player_gold,668);eq(received[#received][3],9)
-- Unknown zero bounty and gargoyle phase events never receive an inferred bounty.
local phase={template_name='enemy_gargoyle',enemy={gold=0}}
systems.health:on_update(s,phase);eq(s.player_gold,668)
phase.enemy.gold=20;systems.health:on_update(s,phase);eq(s.player_gold,698)
r:attach(s,systems);systems.health:on_update(s,ordinary);eq(s.player_gold,707)
r:set_settings({global=1.25,enemy=1.20,summons=false})
systems.health:on_update(s,summoned);eq(s.player_gold,707)
r:set_settings({enabled=false,summons=true,global=1.25})
systems.health:on_update(s,ordinary);eq(s.player_gold,713)
r:detach(s);assert(getmetatable(s)==nil);eq(rawget(s,'player_gold'),713)
assert(s.untouched==42)
s.player_gold=s.player_gold+1;eq(s.player_gold,714)
assert(not pcall(function() r:attach(setmetatable({},{__index={}}),systems) end))
local s2={player_gold=0,level_mode=1};r:set_settings({global=1.25,enemy=1.20,summons=true})
r:attach(s2,systems);systems.level:init(s2);eq(s2.player_gold,500)
local darkling={template_name='enemy_darkling',enemy={gold=0}};r:tag(darkling,'construct')
systems.health:on_update(s2,darkling);eq(s2.player_gold,500)
assert(r.exceptions['enemy_darkling:zero-base'])
systems.goal_line:on_update(s2,10);eq(s2.player_gold,515)
-- Test stack provenance and friendly exclusion through the real queue hook.
local sim={queue_insert_entity=function(self,e) self.last=e end}
local scripts={enemy_necromancer={},enemy_gargoyle={},bullet_enemy_flying={}}
function scripts.enemy_necromancer.update(e) sim:queue_insert_entity(e) end
function scripts.enemy_gargoyle.update(e) sim:queue_insert_entity(e) end
function scripts.bullet_enemy_flying.update(this,e) sim:queue_insert_entity(e) end
r:install_queue(sim);r:register_spawners(scripts)
local e={template_name='enemy_skeleton',enemy={gold=0}}
scripts.enemy_necromancer.update(e);assert(r.provenance[e])
local e2={template_name='enemy_skeleton',enemy={gold=0}}
scripts.enemy_gargoyle.update(e2);assert(not r.provenance[e2])
assert(r.exceptions['enemy_skeleton:unclassified-zero-bounty'],'unknown zero bounty must be reported without reclassification')
local friendly={template_name='soldier',soldier={}}
scripts.enemy_necromancer.update(friendly);assert(not r.provenance[friendly])
local split={template_name='enemy_darkling',enemy={gold=0}}
scripts.bullet_enemy_flying.update({template_name='bullet_dark_construct_spawn'},split)
assert(r.provenance[split],'dark construct split needs audited bullet provenance')
local dismount={template_name='enemy_goblin',enemy={gold=6}}
scripts.bullet_enemy_flying.update({template_name='bullet_rider_goblin'},dismount)
assert(not r.provenance[dismount],'a dismount phase must not become a summon')
r:uninstall();assert(getmetatable(s2)==nil)
assert(not pcall(function() r:attach({},systems) end),'uninstalled runtime must not reattach')
print('runtime: receipt adjustment, refunds, phase exclusion, reload, provenance and cleanup OK')
