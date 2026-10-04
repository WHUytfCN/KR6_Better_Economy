version={string='kr6-desktop-1.00.072'}
local original_require=require
local E={entities={},load=function() end}
local signal={emit=function() end}
local sim={queue_insert_entity=function() end}
function sim:init(store,sys) self.store=store;sys.level:init(store) end
function sim:destroy() self.store=nil end
local refs={E.load,signal.emit,sim.init,sim.destroy,sim.queue_insert_entity}
package.loaded.entity_db=E;package.loaded['hump.signal']=signal;package.loaded.game_settings={}
package.preload['klove.simulation']=function() simulation=sim;return sim end
local fail=true
package.loaded['src.ui']={install=function() if fail then error('injected UI install failure') end end,uninstall=function() end}
local p=assert(loadfile('src/bootstrap.lua'))()
local survived=pcall(function() p:init() end)
assert(survived,'plugin installation failure must not escape into game startup')
assert(not p.active and not p.initialized,'failed install must be retryable')
assert(E.load==refs[1] and signal.emit==refs[2] and sim.init==refs[3] and sim.destroy==refs[4])
assert(sim.queue_insert_entity==refs[5] and require==original_require,'all owned hooks must roll back')
fail=false;p:init();assert(p.active)
local systems={level={},health={on_update=function() end},tower_upgrade={on_update=function() end},goal_line={on_update=function() end}}
function systems.level:init(s) s.player_gold=400 end
p.runtime:set_settings({global=1.25,initial=1.25})
local store={};sim:init(store,systems);assert(store.player_gold==625)
p:shutdown();assert(rawget(store,'player_gold')==625 and getmetatable(store)==nil)
assert(require==original_require and sim.init==refs[3] and E.load==refs[1])
local later={};sim:init(later,systems)
assert(later.player_gold==400 and getmetatable(later)==nil,'next level after shutdown must remain native')
print('bootstrap rollback: injected failure, retry, full shutdown and next-level neutrality OK')
