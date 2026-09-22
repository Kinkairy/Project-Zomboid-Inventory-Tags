require "InventoryTags/InventoryTags_Text"
require "InventoryTags/InventoryTags_Sort"
require "InventoryTags/InventoryTags_AutoOrganize"
require "InventoryTags/InventoryTags_Selection"
require "ISUI/ISContextMenu"
require "ISUI/ISModalDialog"
local IT=InventoryTags
IT.Menu=IT.Menu or {}
local M=IT.Menu
M.live=M.live or {}
M.dialogs=M.dialogs or {}
local function submenu(context,label,target,callback)
    local option=context:addOption(label,target,callback)
    local child=context:getNew(context)
    context:addSubMenu(option,child)
    return child,option
end
function M.available(which,c)
    if which=="Select" then return IT.selectionEnabled() and c~=nil and IT.call(c,"getItems")~=nil end
    if not IT.Store.isSupported(c) then return false end
    if which=="Categories" then return IT.categoriesEnabled() end
    if which=="Sort" then return IT.sortingEnabled() end
    return which=="Auto" and IT.autoOrganizeEnabled()
end
function M.refreshChecks(c)
    for _,view in pairs(M.live) do
        if view.container==c then
            local record=IT.Store.get(c,false)
            local blocked=IT.Network.busy(c) or (isClient() and not IT.Network.confirmed[c])
                or not M.available("Categories",c)
            for _,row in ipairs(view.rows) do
                local on=false
                local empty=false
                if row.group then
                    local all,partial,count=IT.Categories.groupState(record,row.group,c)
                    on=all or partial;empty=count==0
                    local name=IT.text("Group"..row.group)..(partial and IT.text("Partial") or "")
                    row.option.name=name
                else on=IT.Store.selected(c,row.key) end
                row.context:setOptionChecked(row.option,on==true)
                row.option.notAvailable=blocked or empty
            end
            for _,o in ipairs(view.bulk) do o.notAvailable=blocked end
            if view.context.calcWidth then view.context:setWidth(view.context:calcWidth()) end
        end
    end
end
local function changed(c)
    return function()
        M.refreshChecks(c)
        if ISInventoryPage then ISInventoryPage.dirtyUI() end
    end
end
function M.confirmBulk(playerNum,c,on)
    if not M.available("Categories",c) or IT.Network.busy(c) then return end
    local previous=M.dialogs[playerNum]
    if previous and previous:getIsVisible() then previous:bringToTop();return end
    local target={container=c,playerNum=playerNum,enabled=on}
    local modal=ISModalDialog:new(0,0,280,120,IT.text(on and "ConfirmAll" or "ConfirmNone"),true,target,
        function(request,button)
            M.dialogs[request.playerNum]=nil
            if button.internal~="YES" or not M.available("Categories",request.container) then return end
            IT.Network.send(request.playerNum,request.container,"all",nil,request.enabled,changed(request.container))
            M.refreshChecks(request.container)
        end,playerNum)
    modal:initialise()
    modal.yes:setTitle(IT.text("Confirm"))
    modal.no:setTitle(IT.text("Cancel"))
    modal:addToUIManager()
    modal:bringToTop()
    M.dialogs[playerNum]=modal
    if JoypadState and JoypadState.players[playerNum+1] and setJoypadFocus then
        modal.prevFocus=JoypadState.players[playerNum+1].focus
        setJoypadFocus(playerNum,modal)
    end
end
-- Native right-navigation rejects a row when it also has an onSelect.
-- Parent rows intentionally have both (A/click toggles, Right enters children).
-- Adapt only this menu instance and delegate navigation to the original method.
-- Callback identity guards against options recycled by the native menu pool.
local function enableParentNavigation(context)
    context._InventoryTagsParentCallbacks={}
    if context._InventoryTagsRightWrapped or type(context.onJoypadDirRight)~="function" then return end
    local native=context.onJoypadDirRight
    context._InventoryTagsRightWrapped=true
    context.onJoypadDirRight=function(self,...)
        local option=self.options and self.options[self.mouseOver or -1]
        local expected=option and self._InventoryTagsParentCallbacks and self._InventoryTagsParentCallbacks[option]
        if not expected or option.onSelect~=expected then return native(self,...) end
        option.onSelect=nil
        local ok,result=pcall(native,self,...)
        option.onSelect=expected
        if not ok then error(result) end
        return result
    end
end
function M.categories(context,playerNum,c)
    if not M.available("Categories",c) then return end
    IT.Network.ensure(playerNum,c)
    IT.Categories.keys(c)
    local rows,bulk={},{}
    enableParentNavigation(context)
    local bulkMenu=submenu(context,IT.text("Bulk"))
    for _,value in ipairs({true,false}) do
        local on=value
        bulk[#bulk+1]=bulkMenu:addOption(IT.text(on and "All" or "None"),c,function(target)
            M.confirmBulk(playerNum,target,on)
        end)
    end
    for _,g in ipairs(IT.Categories.groups) do
        local group=g
        local keys=IT.Categories.groupKeys(group,c)
        if #keys>0 then
            local child,parent=submenu(context,IT.text("Group"..group),c,function(target)
                if not M.available("Categories",target) then return end
                local all=IT.Categories.groupState(IT.Store.get(target,false),group,target)
                IT.Network.send(playerNum,target,"group",group,not all,changed(target))
                M.refreshChecks(target)
            end)
            context._InventoryTagsParentCallbacks[parent]=parent.onSelect
            rows[#rows+1]={context=context,option=parent,group=group}
            for _,k in ipairs(keys) do
                local key=k
                local option=child:addOption(IT.Categories.label(key),c,function(target)
                    if not M.available("Categories",target) then return end
                    IT.Network.send(playerNum,target,"set",key,not IT.Store.selected(target,key),changed(target))
                    M.refreshChecks(target)
                end)
                rows[#rows+1]={context=child,option=option,key=key}
            end
        end
    end
    M.live[playerNum]={context=context,container=c,rows=rows,bulk=bulk}
    M.refreshChecks(c)
end
function M.sort(context,playerNum,c)
    if not M.available("Sort",c) then return end
    local player=getSpecificPlayer(playerNum)
    local selected=IT.Sort.get(player,c)
    for _,g in ipairs(IT.Sort.groups) do
        local child,parent=submenu(context,IT.text(g[1]))
        context:setOptionChecked(parent,selected==g[2] or selected==g[3])
        for n=2,3 do
            local mode=g[n]
            local option=child:addOption(IT.text(g[n+2]),c,function(target)
                if M.available("Sort",target) then IT.Sort.set(player,target,mode);ISInventoryPage.dirtyUI() end
            end)
            child:setOptionChecked(option,selected==mode)
        end
    end
end
local function present(context,option)
    if not option then return false end
    for _,current in ipairs(context.options or {}) do if current==option then return true end end
    return false
end
function M.entry(context,playerNum,c,which)
    if not M.available(which,c) then return end
    context._InventoryTagsEntries=context._InventoryTagsEntries or {}
    local key=tostring(c)..":"..which
    local prior=context._InventoryTagsEntries[key]
    if prior and present(context,prior) and prior.name==IT.text(which) then return end
    local option
    if which=="Select" then
        local pane=IT.Selection.findPane(playerNum,c)
        if not IT.Selection.available(pane,c) then return end
        local child;child,option=submenu(context,IT.text("Select"))
        IT.Selection.menu(child,playerNum,c,pane,enableParentNavigation)
    elseif which=="Categories" or which=="Sort" then
        local child;child,option=submenu(context,IT.text(which))
        if which=="Categories" then M.categories(child,playerNum,c) else M.sort(child,playerNum,c) end
    else
        option=context:addOption(IT.text("Auto"),c,function(target)
            if M.available("Auto",target) then IT.AutoOrganize.start(playerNum,target) end
        end)
    end
    context._InventoryTagsEntries[key]=option
end
function M.all(context,playerNum,c)
    if not context or not c then return end
    local any=false
    for _,kind in ipairs({"Categories","Sort","Auto","Select"}) do if M.available(kind,c) and (kind~="Select" or IT.Selection.findPane(playerNum,c)) then any=true;break end end
    if not any then return end
    context._InventoryTagsRoots=context._InventoryTagsRoots or {}
    local saved=context._InventoryTagsRoots[c]
    local child
    if saved and present(context,saved.option) and saved.option.name==IT.text("Project") then child=saved.child
    else
        local option;child,option=submenu(context,IT.text("Project"))
        context._InventoryTagsRoots[c]={child=child,option=option}
        -- Vanilla pools submenu objects. A fresh parent must not inherit a
        -- prior invocation's dedup markers or live checkbox view.
        child._InventoryTagsEntries={}
    end
    for _,kind in ipairs({"Categories","Sort","Auto","Select"}) do M.entry(child,playerNum,c,kind) end
end
function M.open(playerNum,c,control,which,pane)
    if not M.available(which,c) then return end
    if which=="Auto" then IT.AutoOrganize.start(playerNum,c);return end
    if not control then return end
    if which=="Sort" or which=="Select" then M.live[playerNum]=nil end
    local context=ISContextMenu.get(playerNum,control:getAbsoluteX(),control:getAbsoluteY()+control:getHeight())
    if which=="Select" then
        pane=pane or IT.Selection.findPane(playerNum,c)
        if not IT.Selection.available(pane,c) then return end
        context.origin=pane.inventoryPage or pane.parent
        IT.Selection.menu(context,playerNum,c,pane,enableParentNavigation)
    elseif which=="Categories" then M.categories(context,playerNum,c) else M.sort(context,playerNum,c) end
    if JoypadState and JoypadState.players[playerNum+1] and setJoypadFocus then setJoypadFocus(playerNum,context) end
end
function M.world(playerNum,context,objects,test)
    if test then return end
    local targets,seen={},{}
    local function add(c)
        if c then IT.Filter.apply(c) end
        if c and IT.Store.isSupported(c) and not seen[c] then targets[#targets+1]=c;seen[c]=true end
    end
    for _,obj in ipairs(objects or {}) do
        local item=IT.call(obj,"getItem")
        if item then add(IT.call(item,"getInventory")) end
        local n=IT.call(obj,"getContainerCount")
        for i=0,(n or 0)-1 do add(obj:getContainerByIndex(i)) end
        if instanceof(obj,"BaseVehicle") then
            for i=0,obj:getPartCount()-1 do add(obj:getPartByIndex(i):getItemContainer()) end
        end
    end
    local loot=getPlayerLoot(playerNum)
    local current=loot and loot.inventoryPane and loot.inventoryPane.inventory
    if seen[current] then M.all(context,playerNum,current);return end
    if #targets==1 then M.all(context,playerNum,targets[1]) end
end
function M.inventory(playerNum,context,items)
    local actual=IT.itemsFromUI(items)
    -- Selection acts on the displayed SOURCE list, not a bag inside that list.
    local source=actual[1] and IT.call(actual[1],"getContainer")
    if source and IT.Selection.findPane(playerNum,source) then M.entry(context,playerNum,source,"Select") end
    if #actual==1 then local c=IT.call(actual[1],"getInventory");if c then M.all(context,playerNum,c) end end
end
function M.empty(playerNum,context,isLoot)
    local page=isLoot and getPlayerLoot(playerNum) or getPlayerInventory(playerNum)
    if page and page.inventoryPane then M.all(context,playerNum,page.inventoryPane.inventory) end
end
