require "InventoryTags/InventoryTags_Text"
require "InventoryTags/InventoryTags_Categories"
require "ISUI/ISInventoryPane"
require "ISUI/ISModalDialog"
local IT=InventoryTags
IT.Selection=IT.Selection or {}
local S=IT.Selection
-- SELECT3: one-shot category actions; menu ticks follow hover, never a saved rule.
S.choices=nil -- discard an older loaded module's UI-only choices, not ModData
S.holds=S.holds or setmetatable({},{__mode="k"})
-- All entry points resolve an already displayed native list. No storage whitelist.
local function displays(page,pane,c)
    if not page or page.inventoryPane~=pane or pane.inventory~=c then return false end
    if IT.call(page,"getIsVisible")==false or page.isCollapsed==true then return false end
    -- A stale selected inventory can survive briefly after its container button
    -- disappears (distance/lock/UI refresh). Do not expose that stale list.
    if type(page.backpacks)=="table" then
        for _,button in ipairs(page.backpacks) do
            if button.inventory==c then return true end
        end
        return false
    end
    return true
end
function S.findPane(playerNum,c,preferred)
    if playerNum==nil or c==nil then return nil end
    local found
    for _,getPage in ipairs({getPlayerInventory,getPlayerLoot}) do
        local page=getPage(playerNum)
        local pane=page and page.inventoryPane
        if pane and displays(page,pane,c) then
            if preferred==pane then return pane end
            if found and found~=pane then found=false else found=found or pane end
        end
    end
    if preferred then return nil end
    return found or nil
end
function S.available(pane,c)
    return IT.selectionEnabled() and pane~=nil and c~=nil and pane.inventory==c
        and S.findPane(pane.player,c,pane)==pane
        and type(pane.refreshContainer)=="function" and type(pane.selected)=="table"
        and IT.call(c,"getItems")~=nil
end
-- Floor/world items need not report the temporary floor-list container as owner.
-- Membership in the displayed list is authoritative; never descend into bags.
function S.containsItems(c,wanted)
    local remaining={}
    local count=0
    for item in pairs(wanted) do remaining[item]=true;count=count+1 end
    if count==0 then return false end
    local items=IT.call(c,"getItems")
    if not items then return false end
    for i=0,items:size()-1 do
        local item=items:get(i)
        if remaining[item] then remaining[item]=nil;count=count-1 end
    end
    return count==0
end
function S.sourcePane(playerNum,items)
    if #items==0 then return nil end
    local wanted={}
    for _,item in ipairs(items) do wanted[item]=true end
    local found
    for _,getPage in ipairs({getPlayerInventory,getPlayerLoot}) do
        local page=getPage(playerNum)
        local pane=page and page.inventoryPane
        local c=pane and pane.inventory
        if S.available(pane,c) and S.containsItems(c,wanted) then
            if found and found~=pane then return nil end
            found=pane
        end
    end
    return found
end
local function holdItemsPresent(c,wanted)
    if not S.containsItems(c,wanted) then return false end
    if IT.call(c,"getType")=="floor" then return true end
    for item in pairs(wanted) do
        if IT.call(item,"getContainer")~=c then return false end
    end
    return true
end
local function sameRows(a,b)
    for k,v in pairs(a or {}) do if not b or b[k]~=v then return false end end
    for k,v in pairs(b or {}) do if not a or a[k]~=v then return false end end
    return true
end
-- Native B42.20 stacks have a duplicate header at items[1]; real items start at 2.
-- Build the SAME visible row projection as renderdetails(), including its cap.
-- Full matching stacks are collapsed so native context actions include ALL items,
-- rather than just the first MAX_ITEMS_IN_STACK_TO_RENDER expanded children.
function S.plan(pane,c,rule)
    if type(pane.itemslist)~="table" or type(pane.collapsed)~="table" then return nil,"SelectionUnavailable" end
    local cap=ISInventoryPane.MAX_ITEMS_IN_STACK_TO_RENDER
    if not IT.integer(cap,1,10000) then return nil,"SelectionUnavailable" end
    local direct={}
    local items=c:getItems()
    for i=0,items:size()-1 do direct[items:get(i)]=true end
    local rows,selected,wanted,collapse={},{},{},IT.copy(pane.collapsed)
    local count,first=0,nil
    for _,group in ipairs(pane.itemslist) do
        if type(group)~="table" or type(group.items)~="table" or #group.items<2
            or group.items[1]~=group.items[2] or type(group.name)~="string" then
            return nil,"SelectionUnavailable"
        end
        local matches,total,on={},0,0
        for j=2,#group.items do
            local item=group.items[j]
            if not IT.isItem(item) then return nil,"SelectionUnavailable" end
            total=total+1
            if direct[item] and IT.Categories.matches(item,rule.categories,rule.all) then
                matches[j]=true;on=on+1
                if not wanted[item] then wanted[item]=true;count=count+1 end
            end
        end
        if on>0 and on==total then collapse[group.name]=true
        elseif on>0 then
            -- Never select a mixed header: same display name is not same category.
            -- Hidden matching children beyond vanilla's rendering cap cannot be
            -- represented safely without changing vanilla stacking. Stop explicitly.
            for j=cap+2,#group.items do
                if matches[j] then return nil,"SelectionMixedLimit" end
            end
            collapse[group.name]=false
        end
        rows[#rows+1]=group
        if on>0 and on==total then selected[#rows]=group;first=first or #rows end
        if not collapse[group.name] then
            for j=2,math.min(#group.items,cap+1) do
                rows[#rows+1]=group.items[j]
                if matches[j] then selected[#rows]=group.items[j];first=first or #rows end
            end
        end
    end
    return {rows=rows,selected=selected,collapse=collapse,items=wanted,count=count,first=first}
end
function S.apply(pane,c,rule)
    if not S.available(pane,c) then return nil,"SelectionUnavailable" end
    if pane.dragging or pane.draggingMarquis or (ISMouseDrag and ISMouseDrag.draggingFocus) then
        return nil,"SelectionDragging"
    end
    local player=getSpecificPlayer(pane.player)
    if not player or IT.call(player,"isAsleep")==true then return nil,"SelectionUnavailable" end
    -- Refresh only this pane, then work on live objects, never cached row indices.
    pane:refreshContainer()
    if not S.available(pane,c) then return nil,"SelectionUnavailable" end
    local plan,err=S.plan(pane,c,rule)
    if not plan then return nil,err end
    pane.collapsed=plan.collapse
    pane.items=plan.rows
    pane.selected=plan.selected
    pane.firstSelect=plan.first
    pane.mouseOverOption=0
    pane.buttonOption=0
    pane.previousMouseUp=nil
    if plan.first then pane.joyselection=plan.first-1 end
    S.holds[pane]=nil
    if pane.doController and plan.first then
        S.holds[pane]={container=c,list=pane.itemslist,focus=pane.joyselection,
            selected=IT.copy(plan.selected),items=plan.items}
    end
    if pane.updateWorldObjectHighlight then pane:updateWorldObjectHighlight() end
    return plan.count
end
local function report(playerNum,key)
    local modal=ISModalDialog:new(0,0,360,140,IT.text(key),false,nil,nil,playerNum)
    modal:initialise();modal:addToUIManager()
    if JoypadState and JoypadState.players[playerNum+1] and setJoypadFocus then
        modal.prevFocus=JoypadState.players[playerNum+1].focus
        setJoypadFocus(playerNum,modal)
    end
end
local function execute(playerNum,pane,c,rule)
    local count,err=S.apply(pane,c,rule)
    if count==nil then report(playerNum,err) end
end
-- One menu invocation owns one hover tick, shared by its parent and child menus.
-- Use the native onHighlight callback, never replace the global menu renderer.
local function hoverOption(context,option,view,showTick)
    context:setOptionChecked(option,false)
    option.onHighlightParams={}
    option.onHighlight=function(row,owner,highlighted)
        if highlighted then
            if view.hover then view.owner:setOptionChecked(view.hover,false) end
            view.hover=nil;view.owner=nil
            if showTick then
                owner:setOptionChecked(row,true)
                view.hover=row;view.owner=owner
            end
        elseif view.hover==row then
            owner:setOptionChecked(row,false)
            view.hover=nil;view.owner=nil
        end
    end
end
local function clearHover(view)
    if view.hover then view.owner:setOptionChecked(view.hover,false) end
    view.hover=nil;view.owner=nil
end
function S.menu(context,playerNum,c,pane,enableParentNavigation)
    pane=pane or S.findPane(playerNum,c)
    if not S.available(pane,c) then return end
    IT.Categories.keys(c)
    if enableParentNavigation then enableParentNavigation(context) end
    local view={}
    local function action(owner,label,makeRule)
        local option=owner:addOption(label,nil,function()
            clearHover(view)
            execute(playerNum,pane,c,makeRule())
        end)
        hoverOption(owner,option,view,true)
        return option
    end
    local bulkOption=context:addOption(IT.text("Bulk"))
    hoverOption(context,bulkOption,view,false)
    local bulk=context:getNew(context);context:addSubMenu(bulkOption,bulk)
    for _,enabled in ipairs({true,false}) do
        local on=enabled
        action(bulk,IT.text(on and "All" or "ClearSelection"),function()
            return {all=on,categories={}}
        end)
    end
    for _,g in ipairs(IT.Categories.groups) do
        local group=g
        local keys=IT.Categories.groupKeys(group,c)
        if #keys>0 then
            local parent=action(context,IT.text("Group"..group),function()
                local rule={all=false,categories={}}
                for _,key in ipairs(IT.Categories.groupKeys(group,c)) do rule.categories[key]=true end
                return rule
            end)
            if context._InventoryTagsParentCallbacks then context._InventoryTagsParentCallbacks[parent]=parent.onSelect end
            local child=context:getNew(context);context:addSubMenu(parent,child)
            for _,k in ipairs(keys) do
                local key=k
                action(child,IT.Categories.label(key),function()
                    return {all=false,categories={[key]=true}}
                end)
            end
        end
    end
end
-- Vanilla update clears multi-selection every controller frame. Retain only this
-- explicit selection while its rows/container/focus stay unchanged. Any manual
-- selection, cursor movement, container refresh/change, or moved item releases it.
-- No category rematching here and no transfer, Store, network or ModData writes.
function S.updateHold(pane,native,...)
    local h=S.holds[pane]
    local keep=h and IT.selectionEnabled() and pane.doController and pane.inventory==h.container
        and pane.itemslist==h.list and pane.joyselection==h.focus and sameRows(pane.selected,h.selected)
    if keep then keep=holdItemsPresent(h.container,h.items) end
    local result=native(pane,...)
    if keep and pane.inventory==h.container and pane.itemslist==h.list and pane.joyselection==h.focus
        and (pane.player~=0 or (wasMouseActiveMoreRecentlyThanJoypad and wasMouseActiveMoreRecentlyThanJoypad()==false)) then
        keep=holdItemsPresent(h.container,h.items)
        if keep and not IT.hasEntries(pane.selected) then pane.selected=IT.copy(h.selected) else keep=false end
    else keep=false end
    if not keep then S.holds[pane]=nil end
    return result
end
if not S.updateInstalled and type(ISInventoryPane.update)=="function" then
    S.updateInstalled=true
    local native=ISInventoryPane.update
    ISInventoryPane.update=function(self,...) return S.updateHold(self,native,...) end
end
