local ok, C = pcall(require, 'src.core')
assert(ok, 'economy core must be implemented')
local function eq(a,b) assert(math.abs(a-b)<1e-8, tostring(a)..' ~= '..tostring(b)) end
local c = C.settings({global=1.25, initial=1.25, enemy=1.20, summons=true})
eq(C.scale(c,'initial',400),625)
eq(C.scale(c,'enemy',10),15)
eq(C.scale(c,'other',20),25)
eq(C.scale(c,'refund',100),100)
eq(C.scale(c,'spend',-125),-125)
local total=0
for i=1,100 do total=total+C.scale(c,'enemy',1) end
eq(total,150)
for _,v in ipairs({0,0.74,1.26,1.03,math.huge,-math.huge,'1.25'}) do
 assert(not pcall(C.settings,{global=v}), 'invalid preset accepted: '..tostring(v))
end
assert(not pcall(C.settings,{global=0/0}))
assert(not pcall(C.settings,{summons='yes'}))
for i=75,125,5 do eq(C.settings({global=i/100}).global,i/100) end
local defaults=C.settings()
for _,kind in ipairs({'initial','enemy','other','refund','spend'}) do eq(C.scale(defaults,kind,17),17) end
local value,reason=C.summon(c,0,6,true,1)
eq(value,9); assert(not reason)
eq(C.summon(c,12,6,false,1),18)
eq(C.summon(C.settings({summons=false}),4,6,true,1),4)
local zero,why=C.summon(c,0,0,true,1)
eq(zero,0);assert(why=='zero-base')
local missing,why=C.summon(c,4,nil,true,1)
eq(missing,6);assert(why=='missing-base')
eq(C.summon(c,0,6,true,0.5),4.5)
local disabled=C.settings({global=1.25,enemy=1.25,enabled=false,summons=true})
eq(C.scale(disabled,'initial',400),400);eq(C.summon(disabled,0,6,true,1),0)
print('core: presets, fractional rewards, defaults, summons, exceptions OK')
