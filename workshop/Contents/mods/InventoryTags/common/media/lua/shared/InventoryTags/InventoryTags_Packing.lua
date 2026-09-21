require "InventoryTags/InventoryTags_Access"
local IT=InventoryTags
IT.Packing=IT.Packing or {}
local P=IT.Packing
-- Exact B42.20.2 craftRecipe identifiers, checked against CraftRecipeKey.
-- Display translations like "Pack Ammo in Box" are NOT recipe identifiers.
-- No substring inference and no recipes for opening, dismantling or unpacking.
P.names={
    place_ammo_in_box=true,PlaceInBox=true,Place12BoxesInCarton=true,
    PackCannedFood=true,PackBeerBottles=true,PackBoxOfWine=true,
    PackSetOfBooks=true,stack_items=true,PutJarsInBox=true,
    PutEggsInCarton=true,PutSeedsInPacket=true,
    PackCigarettes=true,PackCigaretteCarton=true,
}
function P.name(recipe) return tostring(IT.call(recipe,"getName") or "") end
function P.allowed(recipe)
    return recipe~=nil and IT.call(recipe,"isVanilla")==true
        and IT.call(recipe,"getCategory")=="Packing"
        and P.names[P.name(recipe)]==true
end
function P.outputCount(recipe)
    local outputs=IT.call(recipe,"getOutputs")
    if not outputs or outputs:size()==0 then return nil end
    local n=0
    for i=0,outputs:size()-1 do
        local out=outputs:get(i)
        if not ResourceType or out:getResourceType()~=ResourceType.Item then return nil end
        local amount=IT.call(out,"getIntMaxAmount")
        if not amount or amount<=0 then amount=IT.call(out,"getAmount") end
        if not IT.integer(amount,1,64) then return nil end
        n=n+amount
    end
    return n
end
function P.plan(logic,target,player)
    local data=IT.call(logic,"getRecipeData")
    local recipe=IT.call(logic,"getRecipe")
    if not data or not P.allowed(recipe) then return nil,"Recipe" end
    local inputs=IT.call(data,"getAllInputItems")
    local consumed=IT.call(data,"getAllNotKeepInputItems")
    local keep=IT.call(data,"getAllKeepInputItems")
    if not inputs or not consumed or not keep then return nil,"API" end
    local kept={}
    for i=0,keep:size()-1 do kept[keep:get(i)]=true end
    local ids,seen={},{}
    for i=0,consumed:size()-1 do
        local item=consumed:get(i)
        if not kept[item] and not seen[item] then
            if item:getContainer()~=target or IT.call(item,"isFavorite")==true or player:isEquipped(item)
                or (IT.call(item,"getAttachedSlot") or -1)>=0 then return nil,"Input" end
            if not IT.integer(IT.id(item),0) then return nil,"Input" end
            ids[#ids+1]=IT.id(item);seen[item]=true
        end
    end
    local outputs=P.outputCount(recipe)
    if not outputs or #ids<=outputs or #ids>4096 then return nil,"NotCompression" end
    table.sort(ids)
    local allIDs={}
    for i=0,inputs:size()-1 do
        local item=inputs:get(i)
        if not IT.Access.canUse(player,item:getContainer()) then return nil,"Access" end
        allIDs[#allIDs+1]=IT.id(item)
    end
    return {ids=ids,inputs=IT.list(inputs),allIDs=allIDs,recipe=P.name(recipe),maxOutputs=outputs}
end
function P.signature(ids)
    local r={};for _,id in ipairs(ids or {}) do r[#r+1]=tostring(id) end
    table.sort(r);return table.concat(r,",")
end
function P.pin(logic)
    -- Context-click logic already selects concrete inputs in manual mode.
    -- ISHandcraftAction.FromLogic copies them through getManualInputsFor.
    -- Clearing and rebuilding them via IO indices is redundant and fragile.
    return logic:isManualSelectInputs() and logic:canPerformCurrentRecipe()
end
-- A receipt is captured from this exact native action after its original
-- performRecipe. Never infer outputs from the player's whole inventory.
function P.receipt(action)
    local rows={}
    local outputs=ArrayList.new()
    action.logic:getCreatedOutputItems(outputs)
    for i=0,outputs:size()-1 do
        local item=outputs:get(i)
        rows[#rows+1]={id=IT.id(item),fullType=item:getFullType(),ground=IT.call(item,"getWorldItem")~=nil}
    end
    return rows
end
