require "InventoryTags/InventoryTags_Menu"
require "InventoryTags/InventoryTags_Controls"
require "InventoryTags/InventoryTags_TransferGate"
require "TimedActions/ISInventoryTransferAction"
require "ISUI/ISInventoryPane"
require "ISUI/ISInventoryPaneContextMenu"
local IT=InventoryTags
local function refresh(page,phase)
    if phase~="end" or not page then return end
    for _,b in ipairs(page.backpacks or {}) do
        if b.inventory then IT.Filter.apply(b.inventory) end
    end
    -- Both sides and floor: the comparator wrapper also runs on refresh.
    if page.inventoryPane then IT.Sort.apply(page.inventoryPane) end
end
if not IT.ClientHooksInstalled then
    IT.ClientHooksInstalled=true

    local completeTransfer=ISInventoryTransferAction.transferItem
    if completeTransfer then
        ISInventoryTransferAction.transferItem=function(self,item,...)
            local target,source=self.destContainer,self.srcContainer
            local wasThere=target and IT.call(item,"getContainer")==target and target:getItems():contains(item)
            local result=completeTransfer(self,item,...)
            if not isClient() then
                if not wasThere then IT.Arrival.record(item,source,target) end
            elseif IT.Store.isSupported(target) and IT.call(item,"getContainer")==target and target:getItems():contains(item) then
                -- Client callback only confirms native completion; it never
                -- queues a transfer, changes item counts, or fabricates items.
                IT.Arrival.record(item,source,target)
            end
            return result
        end
    end
    local transfer=ISInventoryPane.transferItemsByWeight
    ISInventoryPane.transferItemsByWeight=function(self,items,c,...)
        if IT.Store.isSupported(c) and IT.categoriesEnabled() then
            items=IT.Filter.filter(c,IT.itemsFromUI(items))
            if #items==0 then return end
        end
        return transfer(self,items,c,...)
    end
    local put=ISInventoryPaneContextMenu.onPutItems
    ISInventoryPaneContextMenu.onPutItems=function(items,playerNum,...)
        local page=getPlayerLoot(playerNum)
        local c=page and (page.inventory or (page.inventoryPane and page.inventoryPane.inventory))
        if IT.Store.isSupported(c) and IT.categoriesEnabled() then
            items=IT.Filter.filter(c,IT.itemsFromUI(items))
            if #items==0 then return end
        end
        return put(items,playerNum,...)
    end
    local move=ISInventoryPaneContextMenu.onMoveItemsTo
    ISInventoryPaneContextMenu.onMoveItemsTo=function(items,c,playerNum,...)
        if IT.Store.isSupported(c) and IT.categoriesEnabled() then
            items=IT.Filter.filter(c,IT.itemsFromUI(items))
            if #items==0 then return end
        end
        return move(items,c,playerNum,...)
    end
    local canMove=ISInventoryPaneContextMenu.canMoveTo
    if canMove then
        ISInventoryPaneContextMenu.canMoveTo=function(items,dest,playerNum,...)
            local c=IT.call(dest,"getInventory")
            if not c and IT.call(dest,"getItems") then c=dest end
            if c and IT.categoriesEnabled() and IT.Store.hasTags(c) then
                local selected=IT.Filter.filter(c,IT.itemsFromUI(items))
                if #selected==0 then return nil end
                return canMove(selected,dest,playerNum,...)
            end
            return canMove(items,dest,playerNum,...)
        end
    end
    IT.addEvent("OnFillWorldObjectContextMenu",IT.Menu.world)
    IT.addEvent("OnFillInventoryObjectContextMenu",IT.Menu.inventory)
    IT.addEvent("OnFillInventoryContextMenuNoItems",IT.Menu.empty)
    IT.addEvent("OnRefreshInventoryWindowContainers",refresh)
    IT.addEvent("OnTick",IT.Filter.refreshBound)
end
