local M = {}
local defaults = {global=1, initial=1, enemy=1, summons=false, enabled=true}

function M.settings(input)
    input = input or {}
    assert(type(input)=='table', 'settings must be a table')
    local result = {}
    for k, v in pairs(defaults) do
        if input[k] ~= nil then v = input[k] end
        if k=='summons' or k=='enabled' then
            assert(type(v)=='boolean', k..' must be boolean')
        else
            assert(type(v)=='number' and v==v and v>=0.75 and v<=1.25,
                   k..' must be a preset from 0.75 to 1.25')
            assert(math.abs(v*20-math.floor(v*20+0.5))<1e-8, k..' must use 0.05 steps')
        end
        result[k] = v
    end
    for k in pairs(input) do assert(defaults[k]~=nil, 'unknown setting: '..tostring(k)) end
    return result
end

function M.scale(c, kind, amount)
    assert(type(amount)=='number' and amount==amount and math.abs(amount)<math.huge, 'invalid gold')
    if not c.enabled or kind=='refund' or kind=='spend' or kind=='absolute' then return amount end
    local factor = c.global
    if kind=='initial' then factor=factor*c.initial end
    if kind=='enemy' then factor=factor*c.enemy end
    return amount*factor
end

function M.summon(c, original, base, tagged, mode_factor)
    local native = M.scale(c,'enemy',original)
    if not c.enabled or not c.summons or not tagged then return native end
    if type(base)~='number' or base~=base or base<0 or base==math.huge then return native,'missing-base' end
    if base==0 then return native,'zero-base' end
    -- Preserve explicit native bonuses if a summon already has a positive payout.
    if original>0 then return native end
    return M.scale(c,'enemy',base*(mode_factor or 1))
end

return M
