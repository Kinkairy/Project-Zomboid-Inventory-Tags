require "InventoryTags/InventoryTags_Filter"
require "InventoryTags/InventoryTags_Arrival"
require "TimedActions/ISTransferAction"
local IT=InventoryTags
if not IT.transferGateInstalled then
    IT.transferGateInstalled=true
    local native=ISTransferAction.transferItem
    ISTransferAction.transferItem=function(self,character,item,source,target,...)
        if IT.Store.isSupported(target) and IT.categoriesEnabled() and IT.Store.hasTags(target)
            and not IT.Filter.allowed(target,item) then return false end

        local wasThere=target and IT.call(item,"getContainer")==target and target:getItems():contains(item)
        local result=native(self,character,item,source,target,...)
        if result~=false and not wasThere then
            local arrived=IT.isItem(result) and result or item
            IT.Arrival.record(arrived,source,target,true)
        end
        return result
    end
end
