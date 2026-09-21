require "InventoryTags/InventoryTags_Store"
local IT=InventoryTags
IT.Arrival=IT.Arrival or {}
local A=IT.Arrival
A.KEY="InventoryTagsArrival3"
function A.record(item,source,target,confirmedTransition)
    if not item or not source or not target or source==target then return false end
    if IT.call(item,"getContainer")~=target or not target:getItems():contains(item) then return false end
    local md=IT.call(item,"getModData")
    if type(md)~="table" then return false end
    if not IT.sortingEnabled() or not IT.Store.isSupported(target) then
        md[A.KEY]=nil
        return false
    end
    local game=getGameTime and getGameTime() or nil
    local hours=IT.call(game,"getWorldAgeHours")
    if type(hours)~="number" or hours~=hours or hours<0 then return false end
    local state=IT.Store.get(target,true)
    if not state then return false end
    local previous=md[A.KEY]
    -- The gate proves a fresh source->target transition. A later completion
    -- observer sees the same receipt and is deduplicated. A genuinely new
    -- transition can refresh a prior stamp, even if departure was unobserved.
    if not confirmedTransition and type(previous)=="table" and previous.container==state.uid then return false end
    state.arrivalSerial=(tonumber(state.arrivalSerial) or 0)+1
    md[A.KEY]={container=state.uid,hours=hours,serial=state.arrivalSerial}
    return true
end
function A.get(item,target)
    local state=IT.Store.get(target,false)
    local md=IT.call(item,"getModData")
    local record=type(md)=="table" and md[A.KEY] or nil
    if not state or type(record)~="table" or record.container~=state.uid then return nil end
    if type(record.hours)~="number" or not IT.integer(record.serial,1) then return nil end
    return record.hours,record.serial
end
-- Rows keep vanilla grouping. The row's time is its newest known addition.
-- Untimestamped existing contents remain unknown: scanning never invents dates.
function A.row(row,target)
    local latest,serial
    for _,item in ipairs(row and row.items or {}) do
        if IT.isItem(item) then
            local h,s=A.get(item,target)
            if h and (not latest or h>latest or (h==latest and s>serial)) then latest,serial=h,s end
        end
    end
    return latest,serial
end

-- Read-only snapshot for a single sort. List positions are an ordering fallback
-- for contents whose actual arrival was never recorded, NOT historical dates.
-- Never stamp an item just because a container is opened or sorted.
function A.snapshot(target)
    local snapshot={items={},byID={}}
    local list=IT.call(target,"getItems")
    if not list then return snapshot end
    for i=0,list:size()-1 do
        local item=list:get(i)
        local h,s=A.get(item,target)
        local row={hours=h,serial=s,index=i+1}
        snapshot.items[item]=row
        local id=IT.id(item)
        if IT.integer(id,0) then snapshot.byID[id]=row end
    end
    return snapshot
end
function A.rowOrder(row,target,snapshot)
    local newestHours,newestSerial,position=nil,nil,0
    for _,item in ipairs(row and row.items or {}) do
        if IT.isItem(item) then
            local stamp=snapshot.items[item] or snapshot.byID[IT.id(item)]
            if stamp then
                position=math.max(position,stamp.index)
                local h,s=stamp.hours,stamp.serial
                if h and (not newestHours or h>newestHours or (h==newestHours and s>newestSerial)) then
                    newestHours,newestSerial=h,s
                end
            end
        end
    end
    return newestHours,newestSerial,position
end
