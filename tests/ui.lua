local ok,U=pcall(require,'src.ui');assert(ok,'native settings-page integration must be implemented')
-- Controlled native-view boundary; tests layout tree/navigation/actions, not rendering.
local function node(size)
 local n={size=size or {x=0,y=0},pos={x=0,y=0},colors={},children={},hidden=false}
 function n:add_child(c) table.insert(self.children,c);c.parent=self end
 function n:ci(id)
  if self.id==id then return self end
  for _,c in ipairs(self.children) do local found=c:ci(id);if found then return found end end
 end
 return n
end
KView={new=function(_,size) return node(size) end};KLabel=KView;KButton=KView
GG5PopUpOptionsDesktop={show_page=function(self,i) for j,p in ipairs(self.pages) do p.hidden=j~=i end end}
GG5Pager={setup=function(self,count,owner,fn) self.count=count;self.owner=owner;self.callback=fn end}
local config={global=1,initial=1,enemy=1,summons=false,enabled=true};local saves=0
local controls={get=function() return config end,set=function(c) config=c;saves=saves+1;return true end}
U.install(controls)
local owner=node();owner.pages={};owner.show_page=GG5PopUpOptionsDesktop.show_page
function owner:isInstanceOf(cls) return cls==GG5PopUpOptionsDesktop end
local contents=node();contents.id='contents';owner:add_child(contents)
local title=node();title.id='title_text';title.font_name='fla_body';owner:add_child(title)
for i=1,4 do local p=node();p.id=string.format('page_%02d',i);contents:add_child(p);table.insert(owner.pages,p) end
local pager={};GG5Pager.setup(pager,4,owner,owner.show_page)
assert(pager.count==5 and #owner.pages==5)
owner:show_page(5);assert(not owner._economy_page.hidden and owner.pages[1].hidden)
owner:ci('economy_global_plus'):on_click();assert(config.global==1.05 and saves==1)
for i=1,20 do owner:ci('economy_global_plus'):on_click() end
assert(config.global==1.25)
owner:ci('economy_summons'):on_click();assert(config.summons)
owner:show_page(1);assert(owner._economy_page.hidden and not owner.pages[1].hidden)
GG5Pager.setup(pager,5,owner,owner.show_page);assert(#owner.pages==5)
U.install(controls);assert(#owner.pages==5)
print('UI: append-only page, navigation, preset limits and persistence actions OK')
