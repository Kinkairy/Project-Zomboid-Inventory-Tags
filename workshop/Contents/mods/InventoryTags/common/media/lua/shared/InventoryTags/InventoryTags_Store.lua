require "InventoryTags/InventoryTags_Core"
require "InventoryTags/InventoryTags_Categories"
require "InventoryTags/InventoryTags_StorageScope"
local IT=InventoryTags
IT.Store=IT.Store or {}
local S=IT.Store
S.KEY="InventoryTagsNativeCategoryRules"
S.serial=0
function S.owner(c)
    if not c or IT.call(c,"getType")=="floor" then return nil end
    -- An item-owned bag stays item-owned even when nested in a vehicle.
    local item=IT.call(c,"getContainingItem")
    if item and IT.call(item,"getInventory")==c then return {kind="item",object=item,key="bag"} end
    local part=IT.call(c,"getVehiclePart")
    if part and IT.call(part,"getItemContainer")==c then return {kind="vehicle",object=part,key="part"} end
    local obj=IT.call(c,"getParent")
    if not obj or instanceof(obj,"IsoGameCharacter") or instanceof(obj,"IsoDeadBody") then return nil end
    local n=IT.call(obj,"getContainerCount")
    if not n then return nil end
    for i=0,n-1 do
        if obj:getContainerByIndex(i)==c then return {kind="world",object=obj,key=tostring(i),index=i} end
    end
end
function S.isSupported(c) return IT.StorageScope.accepts(c,S.owner(c)) end
function S.raw(c)
    local owner=S.owner(c)
    if not owner then return nil end
    local root=owner.object:getModData()[S.KEY]
    local record=type(root)=="table" and root[owner.key] or nil
    if type(record)~="table" or record.schema~=6 or record.selector~="InventoryDisplayCategory"
        or type(record.all)~="boolean" or type(record.categories)~="table" then return nil end
    return record
end
function S.get(c,create)
    if not S.isSupported(c) then return nil end
    local owner=S.owner(c)
    local md=owner.object:getModData()
    local root=md[S.KEY]
    if not root and create then root={};md[S.KEY]=root end
    if type(root)~="table" then return nil end
    local r=root[owner.key]
    if not r and create then
        S.serial=S.serial+1
        r={schema=6,selector="InventoryDisplayCategory",all=true,categories={},revision=0,
            uid=tostring(IT.now())..":"..tostring(ZombRand and ZombRand(1000000000) or 0)..":"..S.serial}
        root[owner.key]=r
    end
    if type(r)~="table" or r.schema~=6 or r.selector~="InventoryDisplayCategory"
        or type(r.all)~="boolean" or type(r.categories)~="table" then return nil end
    return r
end
function S.hasTags(c)
    local s=S.get(c,false)
    return s~=nil and (s.all~=true or IT.hasEntries(s.categories))
end
function S.selected(c,k)
    local s=S.get(c,false)
    return IT.Categories.selected(s,k)
end
function S.allSelected(c)
    local s=S.get(c,false)
    if not s then return true end
    if s.all==true and not IT.hasEntries(s.categories) then return true end
    local keys=IT.Categories.keys(c)
    for _,key in ipairs(keys) do if not IT.Categories.selected(s,key) then return false end end
    return #keys>0
end
function S.snapshot(c)
    local s=S.get(c,true)
    if not s then return nil end
    return {schema=6,selector="InventoryDisplayCategory",all=s.all,uid=s.uid,revision=s.revision,categories=IT.copy(s.categories)}
end
function S.setAll(c,on)
    local s=S.get(c,true)
    if not s or type(on)~="boolean" then return false end
    if s.all~=on or IT.hasEntries(s.categories) then
        s.all=on;s.categories={};s.revision=s.revision+1
    end
    return true
end
-- categories is a sparse override map relative to the explicit default all.
-- Preserve false values: deleting an unchecked key in all=true mode would turn
-- it back on. An empty map is never implicitly interpreted as "unrestricted".
function S.set(c,k,on)
    local record=S.get(c,true)
    if not record or not IT.Categories.validKey(k) or type(on)~="boolean" then return false end
    if IT.Categories.selected(record,k)==on then return true end
    if on==record.all then record.categories[k]=nil else record.categories[k]=on end
    record.revision=record.revision+1
    return true
end
function S.setGroup(c,group,on)
    local record=S.get(c,true)
    if not record or not IT.Categories.groupSet[group] or type(on)~="boolean" then return false end
    local keys=IT.Categories.groupKeys(group,c)
    if #keys==0 then return false end
    local changed=false
    for _,k in ipairs(keys) do
        if IT.Categories.selected(record,k)~=on then
            if on==record.all then record.categories[k]=nil else record.categories[k]=on end
            changed=true
        end
    end
    if changed then record.revision=record.revision+1 end
    return true
end
-- Internal reset helper. No additional 'clear tags' menu entry is created.
function S.clear(c) return S.setAll(c,true) end
function S.receive(c,packet)
    if type(packet)~="table" or packet.schema~=6 or packet.selector~="InventoryDisplayCategory" or type(packet.all)~="boolean"
        or type(packet.uid)~="string" or #packet.uid>160
        or not IT.integer(packet.revision,0,2147483647) or type(packet.categories)~="table" then return false end
    local copy,count={},0
    for k,v in pairs(packet.categories) do
        if not IT.Categories.validKey(k) or type(v)~="boolean" then return false end
        copy[k]=v;count=count+1
        if count>1024 then return false end
    end
    local s=S.get(c,true)
    if not s then return false end
    if s.uid==packet.uid and s.revision>packet.revision then return false end
    s.uid=packet.uid;s.revision=packet.revision;s.categories=copy;s.all=packet.all
    return true
end
function S.publish(player,c)
    local owner=S.owner(c)
    if not owner then return end
    if owner.kind=="world" then owner.object:transmitModData()
    elseif owner.kind=="vehicle" then owner.object:getVehicle():transmitPartModData(owner.object)
    elseif syncItemModData then syncItemModData(player,owner.object) end
end
