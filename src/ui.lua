local Core=require('src.core')
local U={}
local function v(x,y) return {x=x,y=y} end
local function label(parent,id,text,x,y,w,h,font,size)
    local n=KLabel:new(v(w,h));n.id=id;n.pos=v(x,y);n.text=text
    n.font_name=font;n.font_size=size or 28;n.text_align='left'
    n.colors.text={255,236,192,255};parent:add_child(n);return n
end
local function button(parent,id,text,x,y,w,font,click)
    local b=KButton:new(v(w,54));b.id=id;b.pos=v(x,y)
    b.colors.background={110,78,40,255};b.colors.hover={151,111,62,255}
    b.colors.click={86,59,30,255};b.on_click=click
    local t=label(b,id..'_label',text,0,9,w,40,font,27);t.text_align='center'
    parent:add_child(b);return b,t
end

function U.install(controls)
    if U.installed then return end
    if not GG5PopUpOptionsDesktop or not GG5Pager then return false end
    local original_setup=GG5Pager.setup
    local original_show=GG5PopUpOptionsDesktop.show_page
    U.owners=setmetatable({},{__mode='k'})
    U.pager_class=GG5Pager;U.popup_class=GG5PopUpOptionsDesktop
    U.original_setup=original_setup;U.original_show=original_show
    local function add_page(owner)
        if owner._economy_page then return end
        local contents=owner:ci('contents');local title=owner:ci('title_text')
        if not contents or not title then return end
        local font=title.font_name or 'fla_body'
        local page=KView:new(v(960,710));page.id='kr6_economy_page';page.pos=v(-480,-325);page.hidden=true
        local summary=label(page,'economy_summary','',15,505,930,130,font,25)
        local values={}
        local status=label(page,'economy_status','',15,650,930,48,font,22)
        local summon_label,enabled_label
        local function refresh()
            local c=controls.get()
            for k,n in pairs(values) do n.text=string.format('×%.2f',c[k]) end
            if summon_label then summon_label.text=c.summons and '开启' or '关（原版）' end
            if enabled_label then enabled_label.text=c.enabled and '金币插件：启用' or '金币插件：停用' end
            summary.text=string.format('实际开局 ×%.4g   敌人赏金 ×%.4g\n开局倍率下次开局生效；其余设置影响后续收入。\n卖塔原价退款规则不变，保留小数金币。',
                c.enabled and c.global*c.initial or 1,c.enabled and c.global*c.enemy or 1)
        end
        local function change(key,value)
            local c=Core.settings(controls.get());c[key]=value
            local ok,err=controls.set(c)
            status.text=ok and '已保存到插件目录' or ('保存失败：'..tostring(err))
            refresh()
        end
        -- The game's Chinese fonts are subsets: use supported wording, no bundled fonts.
        label(page,'economy_intro','金币控制',15,0,930,60,font,36)
        local rows={{'global','全局金币倍率'},{'initial','开局金币倍率'},{'enemy','敌人赏金倍率'}}
        for i,row in ipairs(rows) do
            local key=row[1];local y=80+(i-1)*88
            label(page,'economy_'..key,row[2],15,y+10,530,54,font)
            values[key]=label(page,'economy_'..key..'_value','',655,y+9,155,54,font)
            values[key].text_align='center'
            button(page,'economy_'..key..'_minus','-',570,y,70,font,function()
                change(key,math.max(75,math.floor(controls.get()[key]*100+0.5)-5)/100)
            end)
            button(page,'economy_'..key..'_plus','+',825,y,70,font,function()
                change(key,math.min(125,math.floor(controls.get()[key]*100+0.5)+5)/100)
            end)
        end
        label(page,'economy_summons_text','召唤物掉落金币',15,359,530,54,font)
        local ignored
        ignored,summon_label=button(page,'economy_summons','',570,350,325,font,function()
            change('summons',not controls.get().summons)
        end)
        ignored,enabled_label=button(page,'economy_enabled','',15,432,405,font,function()
            change('enabled',not controls.get().enabled)
        end)
        button(page,'economy_reset','恢复默认',570,432,325,font,function()
            local ok,err=controls.set(Core.settings());status.text=ok and '已恢复默认' or tostring(err);refresh()
        end)
        contents:add_child(page);table.insert(owner.pages,page)
        owner._economy_page=page;owner._economy_index=#owner.pages;owner._economy_refresh=refresh
        refresh()
    end
    GG5PopUpOptionsDesktop.show_page=function(owner,index)
        if index==owner._economy_index then
            for _,p in ipairs(owner.pages) do p.hidden=p~=owner._economy_page end
            owner:ci('title_text').text='金币控制';owner._economy_refresh()
        else original_show(owner,index) end
    end
    GG5Pager.setup=function(pager,count,owner,show)
        if owner.pages and owner.isInstanceOf and owner:isInstanceOf(GG5PopUpOptionsDesktop) then
            if not U.owners[owner] then
                local geometry={pager=pager,extra={}}
                local bg=pager.ci and pager:ci('pager_bg')
                if bg then geometry.bg=bg;geometry.width=bg.size.x end
                for i,b in ipairs(pager.extra_buttons or {}) do geometry.extra[i]={view=b,x=b.pos.x} end
                U.owners[owner]=geometry
            end
            add_page(owner);count=#owner.pages;show=owner.show_page
        end
        return original_setup(pager,count,owner,show)
    end
    U.setup_hook=GG5Pager.setup;U.show_hook=GG5PopUpOptionsDesktop.show_page
    U.installed=true
    return true
end

function U.uninstall()
    if not U.installed then return end
    if U.pager_class.setup==U.setup_hook then U.pager_class.setup=U.original_setup end
    if U.popup_class.show_page==U.show_hook then U.popup_class.show_page=U.original_show end
    for owner,geometry in pairs(U.owners) do
        local page=owner._economy_page
        if page then
            page:remove_from_parent()
            for i=#owner.pages,1,-1 do if owner.pages[i]==page then table.remove(owner.pages,i) end end
            if geometry.bg then geometry.bg.size.x=geometry.width end
            for _,b in ipairs(geometry.extra) do b.view.pos.x=b.x end
            owner._economy_page=nil;owner._economy_index=nil;owner._economy_refresh=nil
            U.original_setup(geometry.pager,#owner.pages,owner,U.original_show)
            if geometry.pager.show_page then geometry.pager:show_page(1) else U.original_show(owner,1) end
        end
    end
    U.owners=nil;U.installed=false
end
return U
