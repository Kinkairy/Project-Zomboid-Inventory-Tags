-- Run from repository root: lua tests/selection.lua
-- Surrogate UI/Java lists; actual Selection/Categories/Menu/Controls modules execute.
local root="workshop/Contents/mods/InventoryTags/common/media/lua/"
package.path=root.."client/?.lua;"..root.."shared/?.lua;"..package.path
local tests=0
local function eq(a,b,msg) assert(a==b,(msg or "mismatch")..": "..tostring(a).." ~= "..tostring(b)) end
local function test(name,fn) fn();tests=tests+1;print("PASS "..name) end
local function list(t) return {size=function() return #t end,get=function(_,i) return t[i+1] end} end
local player={isAsleep=function(self) return self.asleep end}
function getSpecificPlayer() return player end
function getText(k) return k end
function getTextOrNull() return nil end
function instanceof(x,c) return type(x)=="table" and x._item==true and c=="InventoryItem" end
SandboxVars={InventoryTags={}}
ISMouseDrag={}
JoypadState={players={}}
local inv,loot
function getPlayerInventory() return inv end
function getPlayerLoot() return loot end
function wasMouseActiveMoreRecentlyThanJoypad() return false end
ISInventoryPane={MAX_ITEMS_IN_STACK_TO_RENDER=50,update=function(p) if p.doController then p.selected={} end end}
package.loaded['ISUI/ISInventoryPane']=true
ISModalDialog={new=function(_,x,y,w,h,text) return {initialise=function()end,addToUIManager=function()end,text=text} end}
package.loaded['ISUI/ISModalDialog']=true
local ui={}
function ui:new() return setmetatable({options={},numOptions=0},{__index=ui}) end
function ui:addOption(name,target,callback)
 local o={name=name,target=target,onSelect=callback};self.options[#self.options+1]=o;self.numOptions=#self.options;return o
end
function ui:getNew() return ui:new() end
function ui:addSubMenu(o,c) o.child=c end
function ui:setOptionChecked(o,on) o.checked=on end
function ui:onJoypadDirRight() self.entered=self.options[self.mouseOver].onSelect==nil end
function ui:calcWidth()return 250 end
function ui:setWidth()end
ISContextMenu={get=function()return ui:new()end}
package.loaded['ISUI/ISContextMenu']=true
require 'InventoryTags/InventoryTags_Selection'
local IT=InventoryTags;local S=IT.Selection;local C=IT.Categories
-- Existing networking/storage APIs are poison pills: selecting must never use them.
local writes=0
local function noWrite() writes=writes+1;error('selection attempted persistent/gameplay write') end
IT.Store={isSupported=function(c) return c and c.storage end,get=noWrite,selected=noWrite}
IT.Network={send=noWrite,ensure=noWrite,busy=function()return false end}
IT.Filter={allowed=noWrite,apply=noWrite}
IT.Sort={};IT.AutoOrganize={start=noWrite}
package.loaded['InventoryTags/InventoryTags_Sort']=true
package.loaded['InventoryTags/InventoryTags_AutoOrganize']=true
require 'InventoryTags/InventoryTags_Menu'
local M=IT.Menu
local serial=0
local function item(cat,name,options)
 serial=serial+1
 local i={_item=true,cat=cat,name=name or tostring(serial),id='Mock.'..serial}
 for k,v in pairs(options or {})do i[k]=v end
 function i:getDisplayCategory()return self.cat end
 function i:getCategory()return self.fallback end
 function i:getFullType()return self.id end
 function i:getContainer()return self.container end
 function i:getScriptItem() return {getObsolete=function()return self.obsolete end,isHidden=function()return self.hidden end} end
 return i
end
local function pane(items)
 local c={storage=true,raw={locked=true},items=items}
 function c:getItems()return list(self.items)end
 for _,i in ipairs(items)do i.container=c end
 local p={inventory=c,player=0,items={},itemslist={},selected={},collapsed={},joyselection=0}
 function p:refreshContainer()
  local groups,order={},{}
  for _,i in ipairs(c.items) do
   if not groups[i.name]then groups[i.name]={name=i.name,items={i}};order[#order+1]=groups[i.name] end
   local g=groups[i.name];g.items[#g.items+1]=i
   if self.collapsed[i.name]==nil then self.collapsed[i.name]=true end
  end
  self.itemslist=order
 end
 p:refreshContainer();local page={inventoryPane=p};p.inventoryPage=page;p.parent=page
 inv=page;loot=nil
 return p,c
end
local function rule(keys,on) local r={all=on==true,categories={}};for _,k in ipairs(keys or {})do r.categories[k]=true end;return r end
-- Native context collection contract: read pane.items indices, skip expanded headers,
-- flatten real stack members (2..N), deduplicate both expanded/header selections.
local function selectedItems(p)
 local out,seen={},{}
 local function add(i)if not seen[i]then seen[i]=true;out[#out+1]=i end end
 for k,row in ipairs(p.items)do
  if p.selected[k]then
   if instanceof(row,'InventoryItem')then add(row)
   elseif p.collapsed[row.name]then for i=2,#row.items do add(row.items[i])end end
  end
 end
 return out,seen
end
local function clicked(o) assert(o and o.onSelect);o.onSelect(o.target) end
local function named(context,name)
 for _,o in ipairs(context.options)do if o.name==name or o.name==name..IT.text('Partial') then return o end end
 error('missing menu '..name)
end
local function menu(p,c)
 local control={getAbsoluteX=function()return 0 end,getAbsoluteY=function()return 0 end,getHeight=function()return 20 end}
 local old=ISContextMenu.get;local result=ui:new();ISContextMenu.get=function()return result end
 M.open(p.player,c,control,'Select',p);ISContextMenu.get=old;return result
end
for _,k in ipairs({'Food','Water','FirstAid','FirstAidWeapon','Material','MaterialWeapon','Tool','ToolWeapon','MysteryCategory'})do C.rememberCategory(k)end
C.scanned=true

test('single raw category replaces the existing selection',function()
 local a,b=item('FirstAid'),item('Food');local p,c=pane({a,b});p.selected[8]=b
 eq(S.apply(p,c,rule({'FirstAid'})),1);local out,seen=selectedItems(p);eq(#out,1);assert(seen[a]and not seen[b]);eq(p.selected[8],nil)
end)
test('two categories form a union',function()
 local p,c=pane({item('FirstAid'),item('Food'),item('Tool')});eq(S.apply(p,c,rule({'Food','FirstAid'})),2);eq(#selectedItems(p),2)
end)
test('opening a menu does not select items or store category choices',function()
 local p,c=pane({item('Food')});menu(p,c);eq(#selectedItems(p),0);eq(S.choices,nil);eq(S.rule,nil)
end)
test('whole parent uses exact shared grouping including slash forms',function()
 local p,c=pane({item('Material'),item('MaterialWeapon'),item('ToolWeapon')})
 local ctx=menu(p,c);clicked(named(ctx,IT.text('GroupMaterials')))
 eq(#selectedItems(p),2);eq(S.choices,nil)
end)
test('leaf click is one-shot; another category replaces and repeated click reselects',function()
 local a,b=item('Food'),item('FirstAid');local p,c=pane({a,b,item('Tool')})
 clicked(named(named(menu(p,c),IT.text('GroupFood')).child,C.label('Food')));eq(#selectedItems(p),1)
 clicked(named(named(menu(p,c),IT.text('GroupMedical')).child,C.label('FirstAid')))
 local out=selectedItems(p);eq(#out,1);eq(out[1],b)
 clicked(named(named(menu(p,c),IT.text('GroupMedical')).child,C.label('FirstAid')))
 out=selectedItems(p);eq(#out,1);eq(out[1],b);eq(S.choices,nil)
end)
test('all and clear act only on current pane',function()
 local p,c=pane({item('Food'),item('Tool')});local other={selected={sentinel=true}};loot={inventoryPane=other}
 local bulk=named(menu(p,c),IT.text('Bulk')).child;clicked(named(bulk,IT.text('All')));eq(#selectedItems(p),2)
 clicked(named(bulk,IT.text('ClearSelection')));eq(#selectedItems(p),0);eq(other.selected.sentinel,true)
end)
test('whole expanded stack over 50 is fully selected through collapsed native header',function()
 local a={};for i=1,130 do a[#a+1]=item('Material','Nails')end
 local p,c=pane(a);p.collapsed.Nails=false;eq(S.apply(p,c,rule({'Material'})),130)
 eq(p.collapsed.Nails,true);eq(#p.items,1);eq(#selectedItems(p),130)
end)
test('same display name with different categories selects only matching real children',function()
 local a,b=item('Food','Same name'),item('Tool','Same name');local p,c=pane({a,b})
 eq(S.apply(p,c,rule({'Food'})),1);eq(p.collapsed['Same name'],false)
 local out,seen=selectedItems(p);eq(#out,1);assert(seen[a]and not seen[b]);eq(p.selected[1],nil)
end)
test('mixed stack beyond native cap fails without selecting wrong header',function()
 local a={};for i=1,60 do a[#a+1]=item(i==60 and 'Food' or 'Tool','Mix')end
 local p,c=pane(a);local previous={marker=true};p.selected=previous
 local count,err=S.apply(p,c,rule({'Food'}));eq(count,nil);eq(err,'SelectionMixedLimit');eq(p.selected,previous);eq(p.collapsed.Mix,true)
end)
test('mixed stack with all matches inside cap remains precise',function()
 local a={};for i=1,60 do a[#a+1]=item(i==2 and 'Food' or 'Tool','Mix')end
 local p,c=pane(a);eq(S.apply(p,c,rule({'Food'})),1);local out=selectedItems(p);eq(#out,1);eq(out[1],a[2])
end)
test('expanded unselected groups keep subsequent selection indices correct',function()
 local p,c=pane({item('Tool','Tools'),item('Tool','Tools'),item('Food','Food')});p.collapsed.Tools=false
 eq(S.apply(p,c,rule({'Food'})),1);eq(p.selected[4],p.itemslist[2]);eq(#selectedItems(p),1)
end)
test('hidden obsolete and reviewed debug items remain excluded',function()
 local p,c=pane({item('Food','a',{hidden=true}),item('Food','b',{obsolete=true}),item('Food','c',{id='Base.Bitters'}),item('Food','d')})
 eq(S.apply(p,c,rule({},true)),1);eq(#selectedItems(p),1)
end)
test('raw fallback is not guessed from display name',function()
 local a=item(nil,'Pretend medicine',{fallback='Material'});local p,c=pane({a})
 eq(S.apply(p,c,rule({'FirstAid'})),0);eq(S.apply(p,c,rule({'Material'})),1)
end)
test('unknown mod category remains selectable under Other',function()
 local p,c=pane({item('MysteryCategory')});clicked(named(menu(p,c),IT.text('GroupOther')));eq(#selectedItems(p),1)
end)
test('no bag recursion',function()
 local child=item('Food');local bag=item('Bag');bag.contents={child};local p,c=pane({bag})
 eq(S.apply(p,c,rule({'Food'})),0);eq(#c.items,1)
end)
test('no capacity acceptance equipped or favorite filtering is applied to selection',function()
 local a=item('Tool','a',{equipped=true,favorite=true});local p,c=pane({a});c.isItemAllowed=noWrite
 eq(S.apply(p,c,rule({'Tool'})),1);eq(a.container,c);eq(c.raw.locked,true);eq(writes,0)
end)
test('switched container cannot receive a stale menu action',function()
 local p,c=pane({item('Food')});local ctx=menu(p,c);local other={};p.inventory=other
 clicked(named(ctx,IT.text('GroupFood')));eq(#selectedItems(p),0);eq(p.inventory,other)
end)
test('drag in progress blocks selection',function()
 local p,c=pane({item('Food')});p.dragging=1;local n,e=S.apply(p,c,rule({'Food'}));eq(n,nil);eq(e,'SelectionDragging')
 p.dragging=nil;ISMouseDrag.draggingFocus={};eq(S.apply(p,c,rule({'Food'})),nil);ISMouseDrag={}
end)
test('empty container and no matches clear selection',function()
 local p,c=pane({});p.selected[1]='stale';eq(S.apply(p,c,rule({'Food'})),0);eq(#selectedItems(p),0)
end)
test('one-shot actions stay isolated between panes players and containers',function()
 local p,c=pane({item('Food')});S.apply(p,c,rule({'Food'}))
 local p2,c2=pane({item('Tool')});p2.player=1;S.apply(p2,c2,rule({'Tool'}))
 eq(#selectedItems(p),1);eq(#selectedItems(p2),1);eq(S.choices,nil)
end)
test('selection independent of storage category sandbox switch',function()
 local p,c=pane({item('Food')});SandboxVars.InventoryTags.EnableCategories=false;eq(S.apply(p,c,rule({'Food'})),1)
 SandboxVars.InventoryTags.EnableCategories=nil;SandboxVars.InventoryTags.EnableSelection=false;eq(S.apply(p,c,rule({'Food'})),nil)
 SandboxVars.InventoryTags.EnableSelection=nil
end)
test('no persistence or network writes',function()eq(writes,0);eq(IT.PROTOCOL,6)end)
test('explicit pane disambiguates same container displayed twice',function()
 local p,c=pane({item('Food')});loot={inventoryPane={inventory=c}};eq(S.findPane(0,c),nil);eq(S.apply(p,c,rule({'Food'})),1)
end)
test('parent controller navigation retains its toggle callback',function()
 local p,c=pane({item('Food')});local ctx=menu(p,c);local o=named(ctx,IT.text('GroupFood'))
 for k,v in ipairs(ctx.options)do if v==o then ctx.mouseOver=k end end
 local callback=o.onSelect;ctx:onJoypadDirRight();eq(ctx.entered,true);eq(o.onSelect,callback)
end)
test('controller update preserves category multiselect without moving anything',function()
 local p,c=pane({item('Food'),item('Tool')});p.doController=true;eq(S.apply(p,c,rule({},true)),2)
 ISInventoryPane.update(p);eq(#selectedItems(p),2);eq(#c.items,2)
end)
test('controller movement releases the hold',function()
 local p,c=pane({item('Food'),item('Tool')});p.doController=true;S.apply(p,c,rule({},true));p.joyselection=p.joyselection+1
 ISInventoryPane.update(p);eq(S.holds[p],nil);eq(#selectedItems(p),0)
end)
test('controller manual selection changes are not resurrected',function()
 local p,c=pane({item('Food')});p.doController=true;S.apply(p,c,rule({},true));p.selected={}
 ISInventoryPane.update(p);eq(S.holds[p],nil);eq(#selectedItems(p),0)
end)
test('controller container refresh does not reselect new arrivals',function()
 local p,c=pane({item('Food')});p.doController=true;S.apply(p,c,rule({},true));p:refreshContainer()
 ISInventoryPane.update(p);eq(S.holds[p],nil);eq(#selectedItems(p),0)
end)
test('moved items invalidate hold, including moves during native update',function()
 local a=item('Food');local p,c=pane({a});p.doController=true;S.apply(p,c,rule({},true))
 S.updateHold(p,function(self)self.selected={};a.container={} end);eq(S.holds[p],nil);eq(#selectedItems(p),0)
end)
test('another UI mod selection is not overwritten by the controller hold',function()
 local a,b=item('Food'),item('Tool');local p,c=pane({a,b});p.doController=true;S.apply(p,c,rule({'Food'}))
 S.updateHold(p,function(self) self.selected={[2]=self.items[2]} end);eq(S.holds[p],nil);eq(p.selected[2],p.items[2])
end)
test('mouse update does not keep restoring a manual selection',function()
 local p,c=pane({item('Food')});S.apply(p,c,rule({},true));p.selected={};ISInventoryPane.update(p);eq(#selectedItems(p),0)
end)
test('main character inventory can select without becoming a storage-rule target',function()
 local p,c=pane({item('Food')});c.storage=false;eq(M.available('Categories',c),false);eq(M.available('Select',c),true)
 eq(S.apply(p,c,rule({'Food'})),1)
end)
-- Controls registration and non-overlap layout surrogate.
local base={}
function base:derive(name)local cls={Type=name};setmetatable(cls,{__index=self});return cls end
function base:new()return setmetatable({},{__index=self})end
function base:getButtonControl(text)return {title=text}end
ISLootWindowObjectControlHandler=base;ISInventoryWindowControlHandler=base
local lhandlers,ihandlers={},{}
ISLootWindowContainerControls={AddHandler=function(c)lhandlers[#lhandlers+1]=c end}
ISInventoryWindowContainerControls={AddHandler=function(c)ihandlers[#ihandlers+1]=c end,arrange=function()end}
for _,n in ipairs({'ISUI/LootWindow/ISLootWindowContainerControls','ISUI/LootWindow/ISLootWindowObjectControlHandler','ISUI/InventoryWindow/ISInventoryWindowContainerControls','ISUI/InventoryWindow/ISInventoryWindowControlHandler'})do package.loaded[n]=true end
require 'InventoryTags/InventoryTags_Controls'
test('four native handlers on each pane, registration idempotent',function()
 eq(#lhandlers,4);eq(#ihandlers,4)
 package.loaded['InventoryTags/InventoryTags_Controls']=nil;require 'InventoryTags/InventoryTags_Controls';eq(#lhandlers,4);eq(#ihandlers,4)
end)
test('new handler passes exact originating pane',function()
 local p,c=pane({item('Food')});local h=ihandlers[1]:new();h.inventoryWindow={inventoryPane=p};h.playerNum=0
 eq(h:shouldBeVisible(),true);eq(h:getControl().title,IT.text('Select'))
 local old=M.open;local called=false;M.open=function(n,cc,b,kind,pp)eq(cc,c);eq(kind,'Select');eq(pp,p);called=true end
 h:perform();assert(called);M.open=old
end)
local function button(x,y,w,own)return {x=x,y=y,width=w,_InventoryTagsOwn=own,getY=function(b)return b.y end,getWidth=function(b)return b.width end,getRight=function(b)return b.x+b.width end,setX=function(b,v)b.x=v end}end
test('narrow layout keeps native wrapped rows rather than overlapping transfer controls',function()
 local a=button(1,1,90,false);local b=button(96,1,90,true);local c=button(1,24,90,true)
 local controls={a,b,c};ISInventoryWindowContainerControls.arrange({inventoryWindow={inventoryPane={width=150}},controls=controls})
 eq(b.x,96);assert(c.x>=1);eq(a.x,1);eq(c.y,24)
end)
test('wide layout right-aligns only own controls',function()
 local a=button(1,1,90,false);local b=button(96,1,50,true);local c=button(151,1,60,true)
 ISInventoryWindowContainerControls.arrange({inventoryWindow={inventoryPane={width=400}},controls={a,b,c}})
 eq(a.x,1);eq(c.x,335);eq(b.x,280)
end)
test('EN CN CH selection labels exist',function()
 for _,lang in ipairs({'EN','CN','CH'})do Translator={getLanguage=function()return {name=function()return lang end}end};assert(IT.text('Select')~='IGUI_InventoryTags_Select')end
 Translator=nil
end)
-- Execute the reference onHighlight invocation signature: option receives itself,
-- the native owning menu and a boolean (onHighlightParams is a required table).
local function hover(owner,o,on) o:onHighlight(owner,on,table.unpack(o.onHighlightParams)) end
local function allTicks(context,out)
 out=out or {};for _,o in ipairs(context.options)do
  if o.checked then out[#out+1]=o end
  if o.child then allTicks(o.child,out)end
 end;return out
end
test('parent hover shows only that parent, not all its children',function()
 local p,c=pane({item('Material'),item('MaterialWeapon')});local ctx=menu(p,c)
 local a=named(ctx,IT.text('GroupMaterials'));hover(ctx,a,true)
 eq(#allTicks(ctx),1);eq(allTicks(ctx)[1],a);eq(#selectedItems(p),0)
 hover(ctx,a,false);eq(#allTicks(ctx),0)
end)
test('hover child replaces parent tick across the menu chain',function()
 local p,c=pane({item('Material'),item('MaterialWeapon')});local ctx=menu(p,c)
 local a=named(ctx,IT.text('GroupMaterials'));local b=named(a.child,C.label('Material'))
 hover(ctx,a,true);hover(a.child,b,true);eq(a.checked,false);eq(b.checked,true);eq(#allTicks(ctx),1)
 -- Delayed parent out event must not remove the current child tick.
 hover(ctx,a,false);eq(b.checked,true)
 hover(a.child,b,false);eq(#allTicks(ctx),0)
end)
test('moving hover to a different parent clears previous child tick',function()
 local p,c=pane({item('Food'),item('Material')});local ctx=menu(p,c)
 local a=named(ctx,IT.text('GroupMaterials'));local b=named(a.child,C.label('Material'))
 local food=named(ctx,IT.text('GroupFood'));hover(a.child,b,true);hover(ctx,food,true)
 eq(b.checked,false);eq(food.checked,true);eq(#allTicks(ctx),1)
end)
test('click clears hover tick while actual item selection remains',function()
 local p,c=pane({item('Food')});local ctx=menu(p,c);local o=named(ctx,IT.text('GroupFood'))
 hover(ctx,o,true);clicked(o);eq(#allTicks(ctx),0);eq(#selectedItems(p),1)
 eq(#allTicks(menu(p,c)),0);eq(S.choices,nil)
end)
test('same menu instance can click another action without accumulating categories',function()
 local food,med=item('Food'),item('FirstAid');local p,c=pane({food,med});local ctx=menu(p,c)
 clicked(named(ctx,IT.text('GroupFood')));clicked(named(ctx,IT.text('GroupMedical')))
 local out=selectedItems(p);eq(#out,1);eq(out[1],med);eq(#allTicks(ctx),0)
end)
test('bulk heading clears hover without showing a misleading tick',function()
 local p,c=pane({item('Food')});local ctx=menu(p,c)
 hover(ctx,named(ctx,IT.text('GroupFood')),true);hover(ctx,named(ctx,IT.text('Bulk')),true)
 eq(#allTicks(ctx),0);eq(#selectedItems(p),0)
end)
test('failed action also clears transient menu checkmarks',function()
 local p,c=pane({item('Food')});local ctx=menu(p,c);local o=named(ctx,IT.text('GroupFood'))
 hover(ctx,o,true);p.inventory={};clicked(o);eq(#allTicks(ctx),0);eq(S.choices,nil)
end)
test('reopen has no replay saved-rule entry or partial labels',function()
 local p,c=pane({item('Food')});local ctx=menu(p,c);clicked(named(ctx,IT.text('GroupFood')))
 ctx=menu(p,c);eq(#allTicks(ctx),0)
 for _,o in ipairs(ctx.options)do assert(o.name~=IT.text('SelectMatches'));assert(not o.name:find(IT.text('Partial'),1,true))end
end)
test('both button registrations produce Select Categories Sort Auto in native order',function()
 local expected={'Select','Categories','Sort','Auto'}
 for i,name in ipairs(expected)do
  eq(ihandlers[i].Type,'InventoryTagsPersonal'..name)
  eq(lhandlers[5-i].Type,'InventoryTagsNative'..name) -- native right strip grows leftward
 end
end)
print('PASS: '..tests..' selection tests; no engine/Steam/NUC execution.')
