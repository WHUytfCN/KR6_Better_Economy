-- Loaded by entry.lua after an explicit -custom_script KR6_Better_Economy.entry argument.
if rawget(_G,'KR6_ECONOMY_PLUGIN') then return KR6_ECONOMY_PLUGIN end
local plugin={active=false}
KR6_ECONOMY_PLUGIN=plugin
custom_script=plugin
local paths=package.loaded['KR6_Better_Economy.paths']
local root=paths and paths.root or 'KR6_Better_Economy'
local function log(message)
    local f=io.open(root..'/logs/plugin.log','ab')
    if f then f:write(os.date('%Y-%m-%d %H:%M:%S'),' ',tostring(message),'\n');f:close() end
    print('[KR6 Economy] '..tostring(message))
end

function plugin:shutdown()
    self.active=false
    for i=#(self.cleanups or {}),1,-1 do
        local ok,err=pcall(self.cleanups[i])
        if not ok then log('cleanup error: '..tostring(err)) end
    end
    self.cleanups={};self.initialized=false
end

local function install(self)
    local function replace(owner,key,fn)
        local old=owner[key]
        self.cleanups[#self.cleanups+1]=function() if owner[key]==fn then owner[key]=old end end
        owner[key]=fn
    end
    local Config=require('src.config')
    local Runtime=require('src.runtime')
    local UI=require('src.ui')
    local config=Config.load(root..'/settings.ini')
    local E=require('entity_db')
    local signal=require('hump.signal')
    local GS=require('game_settings')
    require('klove.simulation')
    local sim=assert(simulation,'game simulation module unavailable')
    local r=Runtime.new(config,{entities=E,signal=signal,settings=GS,log=log})
    self.runtime=r
    self.cleanups[#self.cleanups+1]=function() r:uninstall() end
    r:install_queue(sim)
    local original_load=E.load
    replace(E,'load',function(db,...)
        local result=original_load(db,...)
        local scripts=package.loaded.scripts_game
        if scripts and self.active and not r.stopped then r:register_spawners(scripts) end
        return result
    end)
    local original_init=sim.init
    replace(sim,'init',function(instance,store,systems,...)
        if self.active and not r.stopped then
            local attached,err=pcall(r.attach,r,store,systems)
            if not attached then r.store=nil;log('REFUSED store hook: '..tostring(err)) end
        end
        return original_init(instance,store,systems,...)
    end)
    local original_destroy=sim.destroy
    replace(sim,'destroy',function(instance,...)
        local store=instance.store
        local result=original_destroy(instance,...)
        if store then r:detach(store) end
        return result
    end)
    local controls={get=function() return r.config end,set=function(next_config)
        local saved,err=Config.save(root..'/settings.ini',next_config)
        if not saved then log('settings save failed: '..tostring(err));return nil,err end
        r:set_settings(next_config);log('settings updated');return true
    end}
    local original_require=require
    self.cleanups[#self.cleanups+1]=function() if UI.uninstall then UI.uninstall() end end
    replace(_G,'require',function(name)
        local result=original_require(name)
        if self.active and name=='kviews_gg_sequels' then
            local ok,err=pcall(UI.install,controls)
            if not ok then self:shutdown();log('REFUSED UI hook: '..tostring(err)) end
        end
        return result
    end)
    UI.install(controls)
    self.active=true
    log('loaded for '..version.string..'; live gameplay verification pending')
end

function plugin:init()
    if self.initialized then return end
    if not version or version.string~='kr6-desktop-1.00.072' then
        log('REFUSED unsupported version '..tostring(version and version.string));return
    end
    self.initialized=true;self.cleanups={}
    local ok,err=xpcall(function() install(self) end,debug.traceback)
    if not ok then self:shutdown();log('REFUSED initialization: '..tostring(err)) end
end

return plugin
