local Core=require('src.core')
local M={}
local keys={'global','initial','enemy','summons','enabled'}
function M.parse(text)
    local values={}
    for line in text:gmatch('[^\r\n]+') do
        line=line:match('^%s*(.-)%s*$')
        if line~='' and line:sub(1,1)~=';' and line:sub(1,1)~='#' then
            local k,v=line:match('^(%a+)%s*=%s*(.-)%s*$')
            assert(k and not values[k..'_seen'],'invalid/duplicate settings entry')
            local known=false
            for _,name in ipairs(keys) do if k==name then known=true end end
            assert(known,'unknown settings entry')
            assert(values[k]==nil,'duplicate settings entry')
            if k=='enabled' or k=='summons' then
                assert(v=='true' or v=='false','expected true or false');values[k]=v=='true'
            else values[k]=assert(tonumber(v),'expected numeric preset') end
        end
    end
    return Core.settings(values)
end
function M.encode(c)
    c=Core.settings(c)
    local lines={'; KR6 Economy - separate plugin settings'}
    for _,k in ipairs(keys) do lines[#lines+1]=k..'='..tostring(c[k]) end
    return table.concat(lines,'\n')..'\n'
end
function M.load(path)
    local f=io.open(path,'rb')
    if not f then return Core.settings() end
    local text=f:read('*a');f:close()
    return M.parse(text)
end
function M.save(path,c)
    local data=M.encode(c)
    local f,err=io.open(path..'.tmp','wb');if not f then return nil,err end
    local wrote,write_err=f:write(data);local closed,close_err=f:close()
    if not wrote or not closed then os.remove(path..'.tmp');return nil,write_err or close_err end
    local existing=io.open(path,'rb')
    if existing then
        existing:close();os.remove(path..'.bak')
        local backed,why=os.rename(path,path..'.bak')
        if not backed then os.remove(path..'.tmp');return nil,why end
    end
    local moved,why=os.rename(path..'.tmp',path)
    if not moved and existing then os.rename(path..'.bak',path) end
    return moved,why
end
return M
