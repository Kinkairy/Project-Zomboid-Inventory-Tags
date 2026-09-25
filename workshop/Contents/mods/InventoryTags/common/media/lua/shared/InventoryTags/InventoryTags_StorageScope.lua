require "InventoryTags/InventoryTags_Core"
local IT=InventoryTags
IT.StorageScope=IT.StorageScope or {}
local P=IT.StorageScope
-- Positive storage types. Unknown furniture is not silently treated as a box.
P.worldTypes={
    crate=true,cardboardbox=true,woodenbox=true,metalbox=true,storagebox=true,
    counter=true,cabinet=true,cupboard=true,locker=true,wardrobe=true,
    shelves=true,metalshelves=true,bookshelves=true,bookshelf=true,
    sidetable=true,nightstand=true,bedsidecabinet=true,desk=true,
    filingcabinet=true,filecabinet=true,dresser=true,chest=true,
    trunk=true,displaycase=true,displaycounter=true,medicinecabinet=true,
    garageStorage=true,garagestorage=true,toolcabinet=true,toolchest=true,
    bin=true,garbage=true,garbagebin=true,trashcan=true,dumpster=true,
    suitcase=true,storage=true,container=true,
}
P.vehicleStorage={truckbed=true,trunk=true,glovebox=true,trailertrunk=true,
    roofrack=true,storage=true,cargo=true,cargostorage=true,overhead=true}
-- Exclusions are based on raw container IDs / engine classes, not translated
-- object names. An unpowered fridge is still a fridge.
local functionalWords={"fridge","freezer","refrigerat","microwave","stove","oven",
    "washer","dryer","washing","barbecue","bbq","campfire","fireplace",
    "furnace","forge","compost","generator","vending","fuel","tank",
    "sink","toilet","dishwasher","mannequin","incinerator","autoclave"}
local function norm(s) return tostring(s or ""):lower():gsub("[^%w]","") end
local function functionalName(s)
    s=norm(s)
    for _,word in ipairs(functionalWords) do if s:find(word,1,true) then return true end end
    return false
end
local function functionalObject(obj)
    if not obj then return false end
    for _,name in ipairs({"IsoStove","IsoBarbecue","IsoFireplace","IsoClothingWasher",
        "IsoClothingDryer","IsoCombinationWasherDryer","IsoCompost","IsoGenerator","IsoMannequin"}) do
        if instanceof(obj,name) then return true end
    end
    return IT.call(obj,"getFluidContainer")~=nil
end
function P.accepts(c,owner)
    if not c or not owner then return false end
    local kind=norm(IT.call(c,"getType"))
    if kind=="floor" or functionalName(kind) then return false end
    if owner.kind=="item" then
        -- Dedicated portable storage, including a bag nested inside an appliance.
        return instanceof(owner.object,"InventoryContainer")
            and IT.call(owner.object,"getInventory")==c
    end
    if owner.kind=="vehicle" then
        local part=owner.object
        local id=norm(IT.call(part,"getId"))
        if functionalName(id) then return false end
        -- Seats, fuel/battery systems and unknown functional parts are not storage.
        return P.vehicleStorage[id]==true or P.worldTypes[kind]==true
            or P.vehicleStorage[kind]==true
    end
    if functionalObject(owner.object) then return false end
    return P.worldTypes[kind]==true
end
