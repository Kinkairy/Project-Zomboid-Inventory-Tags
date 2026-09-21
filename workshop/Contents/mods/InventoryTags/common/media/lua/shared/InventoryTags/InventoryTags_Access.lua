require "InventoryTags/InventoryTags_Store"
local IT=InventoryTags
IT.Access=IT.Access or {}
local A=IT.Access
local S=IT.Store
local function int(v,lo,hi) return IT.integer(v,lo,hi) end
function A.square(player,square)
    if not player or IT.call(player,"isDead")==true or not square then return false end
    local from=IT.call(player,"getCurrentSquare")
    if not from or from:getZ()~=square:getZ() then return false end
    if math.abs(from:getX()-square:getX())>1 or math.abs(from:getY()-square:getY())>1 then return false end
    if from~=square and IT.call(from,"isBlockedTo",square)~=false then return false end
    if SafeHouse and getServerOptions then
        local options=getServerOptions()
        if options and not options:getBoolean("SafehouseAllowLoot") then
            local denied=SafeHouse.isSafeHouse(square,player:getUsername(),true)
            if denied then return false end
        end
    end
    return true
end
function A.canUse(player,c)
    if not player or not c or IT.call(player,"isDead")==true then return false end
    if c==player:getInventory() then return true end
    local seen={}
    for depth=1,32 do
        if seen[c] then return false end
        seen[c]=true
        if c==player:getInventory() then return true end
        local item=IT.call(c,"getContainingItem")
        if item then
            if IT.call(item,"getInventory")~=c then return false end
            local world=IT.call(item,"getWorldItem")
            if world then return A.square(player,world:getSquare()) end
            local parent=IT.call(item,"getContainer")
            if not parent or not parent:getItems():contains(item) then return false end
            c=parent
        else
            local part=IT.call(c,"getVehiclePart")
            if part then
                local vehicle=part:getVehicle()
                return vehicle~=nil and math.floor(vehicle:getZ())==math.floor(player:getZ())
                    and IT.call(vehicle,"canAccessContainer",part:getIndex(),player)==true
            end
            local obj=IT.call(c,"getParent")
            if obj and instanceof(obj,"IsoGameCharacter") then return false end
            if obj and instanceof(obj,"IsoThumpable") then
                if IT.call(obj,"isLockedByKey")==true or IT.call(obj,"isLockedByPadlock")==true then return false end
            end
            local targetSquare=IT.call(c,"getSourceGrid") or IT.call(obj,"getSquare")
            local from=IT.call(player,"getCurrentSquare")
            if not targetSquare or not from or from:getZ()~=targetSquare:getZ()
                or math.abs(from:getX()-targetSquare:getX())>1 or math.abs(from:getY()-targetSquare:getY())>1 then return false end
            if not isServer() and ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.getContainers then
                local accessible=ISInventoryPaneContextMenu.getContainers(player)
                if accessible and accessible:contains(c) then return S.owner(c)~=nil end
            end
            return S.owner(c)~=nil and A.square(player,targetSquare)
        end
    end
    return false
end
-- Serialize only direct ownership edges. No client object or function is trusted.
function A.locate(player,c)
    local result={chain={}}
    local reversed,seen={},{}
    for depth=1,32 do
        if not c or seen[c] then return nil end
        seen[c]=true
        if c==player:getInventory() then result.kind="player";break end
        local item=IT.call(c,"getContainingItem")
        if item and item:getInventory()==c then
            local id=IT.id(item)
            if not int(id,0) then return nil end
            reversed[#reversed+1]=id
            local world=IT.call(item,"getWorldItem")
            if world then
                local sq=world:getSquare()
                if not sq then return nil end
                result.kind="ground";result.x=sq:getX();result.y=sq:getY();result.z=sq:getZ();break
            end
            c=IT.call(item,"getContainer")
        else
            local owner=S.owner(c)
            if not owner then return nil end
            if owner.kind=="vehicle" then
                result.kind="vehicle";result.vehicle=owner.object:getVehicle():getId();result.part=owner.object:getIndex()
            else
                local sq=owner.object:getSquare()
                if not sq then return nil end
                result.kind="world";result.x=sq:getX();result.y=sq:getY();result.z=sq:getZ()
                result.object=owner.object:getObjectIndex();result.index=owner.index
                result.sprite=IT.call(owner.object,"getSpriteName") or ""
            end
            result.ctype=c:getType();break
        end
    end
    if not result.kind then return nil end
    for i=#reversed,1,-1 do result.chain[#result.chain+1]=reversed[i] end
    return result
end
function A.validLocator(a)
    if type(a)~="table" or type(a.chain)~="table" or #a.chain>32 then return false end
    local count=0
    for k,v in pairs(a.chain) do
        if not int(k,1,32) or not int(v,0) then return false end
        count=count+1
    end
    if count~=#a.chain then return false end
    if a.kind=="player" then return #a.chain>0 end
    if a.kind=="vehicle" then return int(a.vehicle,0,2147483647) and int(a.part,0,4096) end
    if a.kind~="world" and a.kind~="ground" then return false end
    if not int(a.x,-1000000,1000000) or not int(a.y,-1000000,1000000) or not int(a.z,-32,128) then return false end
    if a.kind=="ground" then return #a.chain>0 end
    return int(a.object,0,10000) and int(a.index,0,128) and type(a.sprite)=="string" and #a.sprite<256
end
local function direct(c,id)
    local items=c and c:getItems()
    if not items or items:size()>65536 then return nil end
    local found
    for i=0,items:size()-1 do
        local v=items:get(i)
        if IT.id(v)==id then
            if found then return nil end
            found=v
        end
    end
    return found
end
A.direct=direct
function A.resolve(player,a)
    if not A.validLocator(a) or not player then return nil end
    local c,first=nil,1
    if a.kind=="player" then c=player:getInventory()
    elseif a.kind=="vehicle" then
        local v=getVehicleById(a.vehicle)
        if not v or a.part>=v:getPartCount() then return nil end
        local p=v:getPartByIndex(a.part)
        c=p and p:getItemContainer()
    else
        local sq=getCell():getGridSquare(a.x,a.y,a.z)
        if not A.square(player,sq) then return nil end
        if a.kind=="world" then
            local objects=sq:getObjects()
            if a.object>=objects:size() then return nil end
            local obj=objects:get(a.object)
            if a.sprite~=(IT.call(obj,"getSpriteName") or "") then return nil end
            c=IT.call(obj,"getContainerByIndex",a.index)
        else
            local list=sq:getWorldObjects()
            for i=0,list:size()-1 do
                local item=IT.call(list:get(i),"getItem")
                if IT.id(item)==a.chain[1] then c=IT.call(item,"getInventory");break end
            end
            first=2
        end
    end
    if not c or (a.ctype and c:getType()~=a.ctype) then return nil end
    for i=first,#a.chain do
        local item=direct(c,a.chain[i])
        if not item or IT.call(item,"getContainer")~=c then return nil end
        c=IT.call(item,"getInventory")
        if not c then return nil end
    end
    if not S.isSupported(c) or not A.canUse(player,c) then return nil end
    return c
end
function A.key(player,c)
    if c==player:getInventory() then return "player-main" end
    if IT.call(c,"getType")=="floor" then return "floor-view" end
    local a=A.locate(player,c)
    if not a then return tostring(c) end
    if #a.chain>0 then return "item:"..tostring(a.chain[#a.chain]) end
    return table.concat({a.kind,tostring(a.x or a.vehicle),tostring(a.y or a.part),tostring(a.z or ""),tostring(a.object or ""),tostring(a.index or "")},":")
end
