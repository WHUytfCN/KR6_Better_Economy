version={string='kr6-desktop-1.00.072'}
local E={entities={},load=function(self) self.loaded=true end}
local signal={emit=function() end}
local GS={}
local systems={level={},health={},tower_upgrade={},goal_line={}}
function systems.level:init(store) store.player_gold=400 end
function systems.health:on_update() end
function systems.tower_upgrade:on_update() end
function systems.goal_line:on_update() end
local sim={queue_insert_entity=function() end}
function sim:init(store,sys) self.store=store;sys.level:init(store) end
function sim:destroy() self.store=nil end
package.loaded.entity_db=E;package.loaded['hump.signal']=signal;package.loaded.game_settings=GS
package.preload['klove.simulation']=function() simulation=sim;return sim end
local spawner=function() end
package.loaded.scripts_game={enemy_necromancer={update=spawner}}
local p=assert(loadfile('src/bootstrap.lua'))();p:init();assert(p.active)
E:load();assert(p.runtime.spawn_functions[spawner])
p.runtime:set_settings({global=1.25,initial=1.25})
local store={};sim:init(store,systems);assert(store.player_gold==625)
sim:destroy();assert(rawget(store,'player_gold')==625 and getmetatable(store)==nil)
local require_hook=require;p:init();assert(require==require_hook)
local setup=function() end
package.preload.kviews_gg_sequels=function()
 GG5PopUpOptionsDesktop={show_page=function() end};GG5Pager={setup=setup};return {}
end
require('kviews_gg_sequels');assert(GG5Pager.setup~=setup,'deferred native UI class load must be hooked')
print('bootstrap: supported startup, deferred UI, simulation init/destroy and idempotency OK')
