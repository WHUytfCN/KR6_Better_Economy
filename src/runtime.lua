local C = require('src.core')
local R = {}; R.__index=R
local spawners = {
    enemy_necromancer='necromancer', enemy_crowcaller='crowcaller',
    decal_spider_egg='spider-egg', controller_graveyard_KR6='graveyard',
    controller_stage_18_moloch='moloch-reinforcement',
    bullet_enemy_flying={origin='dark-construct-split',source='bullet_dark_construct_spawn'},
}

function R.new(config, deps)
    local self=setmetatable({config=C.settings(config),deps=deps,exceptions={},
        states=setmetatable({},{__mode='k'}),provenance=setmetatable({},{__mode='k'}),
        spawn_functions={},writers={}},R)
    local original=deps.signal.emit
    self.original_emit=original
    self.emit_hook=function(name,entity,amount,...)
        if name=='got-enemy-gold' then amount=self:complete_reward(entity,amount) end
        return original(name,entity,amount,...)
    end
    deps.signal.emit=self.emit_hook
    return self
end

function R:set_settings(config) self.config=C.settings(config) end

function R:report(template,reason)
    local key=tostring(template)..':'..reason
    if not self.exceptions[key] then
        self.exceptions[key]=true
        if self.deps.log then self.deps.log('exception '..key) end
    end
end

function R:tag(entity,origin)
    if not entity.enemy or entity.soldier or entity.hero or self.provenance[entity] then return end
    local template=self.deps.entities.entities[entity.template_name]
    self.provenance[entity]={origin=origin,base=template and template.enemy and template.enemy.gold}
end

function R:register_spawners(scripts)
    self.spawn_functions={}
    for name,reason in pairs(spawners) do
        local block=scripts[name]
        if block and type(block.update)=='function' then
            self.spawn_functions[block.update]=reason
            if jit then jit.off(block.update,true) end
        end
    end
end

function R:install_queue(sim)
    if self.queue_original then return end
    self.sim=sim;self.queue_original=sim.queue_insert_entity
    self.queue_hook=function(simulation,entity,...)
        if entity and entity.enemy and not self.provenance[entity] then
            for level=2,16 do
                local frame=debug.getinfo(level,'f')
                if not frame then break end
                local origin=self.spawn_functions[frame.func]
                if type(origin)=='table' then
                    local rule=origin;origin=nil
                    for index=1,32 do
                        local name,value=debug.getlocal(level,index)
                        if not name then break end
                        if name=='this' and type(value)=='table' and value.template_name==rule.source then
                            origin=rule.origin;break
                        end
                    end
                end
                if origin then self:tag(entity,origin);break end
            end
            if not self.provenance[entity] and entity.enemy.gold==0 then
                local template=self.deps.entities.entities[entity.template_name]
                if template and template.enemy and template.enemy.gold>0 then
                    self:report(entity.template_name,'unclassified-zero-bounty')
                end
            end
        end
        return self.queue_original(simulation,entity,...)
    end
    sim.queue_insert_entity=self.queue_hook
end

function R:attach(store,systems)
    assert(not self.stopped,'economy runtime has been uninstalled')
    if self.states[store] then self.store=store;return end
    assert(getmetatable(store)==nil,'economy refuses a store with an existing metatable')
    for _,spec in ipairs({{'level','init','initial'}, {'health','on_update','kill'},
        {'tower_upgrade','on_update','refund'}, {'goal_line','on_update','enemy'}}) do
        local fn=assert(systems[spec[1]] and systems[spec[1]][spec[2]],'missing game economy writer')
        self.writers[fn]=spec[3]
        -- A stable Lua frame is required for identity-based accounting.
        if jit then jit.off(fn,true) end
    end
    local state={balance=rawget(store,'player_gold') or 0,initial_done=false}
    self.states[store]=state;self.store=store
    rawset(store,'player_gold',nil)
    local mt={}
    mt.__index=function(_,key) if key=='player_gold' then return state.balance end end
    mt.__newindex=function(t,key,value)
        if key~='player_gold' then rawset(t,key,value);return end
        if type(value)~='number' or value~=value or math.abs(value)==math.huge then
            error('invalid gold assignment')
        end
        local frame=debug.getinfo(2,'f')
        local kind=frame and self.writers[frame.func] or 'other'
        local delta=value-state.balance
        state.receipt=nil
        if kind=='initial' then
            -- Only the native initialization assignment is scaled, once per store.
            state.balance=state.initial_done and value or C.scale(self.config,'initial',value)
            state.initial_done=true
        elseif delta<0 then
            state.balance=value
        else
            local category=kind=='kill' and 'enemy' or kind
            local awarded=C.scale(self.config,category,delta)
            state.balance=state.balance+awarded
            if kind=='kill' then state.receipt={original=delta,awarded=awarded} end
        end
    end
    state.metatable=mt
    setmetatable(store,mt)
end

function R:complete_reward(entity,original)
    local store=self.store
    local state=store and self.states[store]
    local receipt=state and state.receipt
    if not receipt or type(original)~='number' or math.abs(receipt.original-original)>1e-7 then
        return original
    end
    state.receipt=nil -- consume before calling observers; a duplicate signal cannot award again
    local p=self.provenance[entity]
    local factors=self.deps.settings.gold_enemy_factor_per_mode
    local factor=factors and factors[store.level_mode] or 1
    local amount,reason=C.summon(self.config,original,p and p.base,p~=nil,factor)
    if reason then self:report(entity.template_name,reason) end
    state.balance=state.balance+amount-receipt.awarded
    return amount
end

function R:detach(store)
    local state=self.states[store]
    if not state then return end
    if getmetatable(store)==state.metatable then
        setmetatable(store,nil)
        rawset(store,'player_gold',state.balance)
    end
    self.states[store]=nil
    if self.store==store then self.store=nil end
end

function R:uninstall()
    self.stopped=true
    for store in pairs(self.states) do self:detach(store) end
    if self.deps.signal.emit==self.emit_hook then self.deps.signal.emit=self.original_emit end
    if self.sim and self.sim.queue_insert_entity==self.queue_hook then
        self.sim.queue_insert_entity=self.queue_original
    end
end

return R
