require "InventoryTags/InventoryTags_Core"
local IT=InventoryTags
IT.Categories=IT.Categories or {}
local C=IT.Categories
-- LT9: approved parents and exact native category IDs / translations unchanged.
-- The item eligibility screen is separate from grouping: it never changes a
-- normal item's raw category by its name, type, tags or fluid contents.
-- Static source audit: user-collected vanilla 42.20.4, 2026-09-22.
-- 5105 declarations / 5092 unique IDs reviewed; see evidence in the package.
-- Other mods, Java runtime state and real in-game validation are NOT certified.
C.AUDIT_STATUS="LOCAL_VANILLA_42_20_4_STATIC_AUDITED"
C.groups={"Food","Medical","Weapons","Clothing","Tools","Materials","Literature","Electronics","Vehicle","Outdoors","Cooking","Containers","Household","Entertainment","Toys","Other"}
C.groupSet={};C.known={};C.leaves={};C.byGroup={};C.parentByCategory={}
C.scanned=nil
for _,g in ipairs(C.groups) do C.groupSet[g]=true;C.byGroup[g]={} end
local function assign(group,rawIDs)
    for _,raw in ipairs(rawIDs) do C.parentByCategory[raw]=group end
end
assign("Food",{"Food","Water"})
assign("Medical",{"FirstAid","FirstAidWeapon"})
assign("Weapons",{"Weapon","WeaponImprovised","WeaponCrafted","BrokenWeapon","Ammo","WeaponPart","Explosives"})
assign("Clothing",{"Clothing","Accessory","ProtectiveGear","Appearance","Ears","Tail"})
assign("Tools",{"Tool","ToolWeapon","LightSource","FireSource"})
assign("Materials",{"Material","MaterialWeapon","AnimalPart","AnimalPartWeapon","Paint"})
assign("Literature",{"Literature","SkillBook","Cartography","RecipeResource"})
assign("Electronics",{"Electronics","Communications"})
assign("Vehicle",{"VehicleMaintenance","VehicleMaintenanceWeapon"})
assign("Outdoors",{"Gardening","GardeningWeapon","Fishing","FishingWeapon","Trapping","Camping","Animal"})
assign("Cooking",{"Cooking","CookingWeapon"})
assign("Containers",{"Bag","Container","WaterContainer","Bear"})
assign("Household",{"Furniture","Household","HouseholdWeapon","Security"})
assign("Entertainment",{"Entertainment","Instrument","InstrumentWeapon","Sports","SportsWeapon"})
assign("Toys",{"Memento","Teddy Bear","Goblin","Eye","Bunny","Fox","Squirrel","Beaver","Mole","Hedgehog","Badger","Dog","Raccoon","Duck","Spider","Bug"})
assign("Other",{"Junk","JunkWeapon","Corpse","Frog"})

-- Alternate exact spellings are recognized only if actually loaded/observed.
C.parentByCategory["Tool/Weapon"]="Tools"
C.parentByCategory["Tools/Weapon"]="Tools"
C.parentByCategory["Gardening/Weapon"]="Outdoors"
C.parentByCategory["Fishing/Weapon"]="Outdoors"
C.parentByCategory["FirstAid/Weapon"]="Medical"
C.parentByCategory["Material/Weapon"]="Materials"
C.parentByCategory["AnimalPart/Weapon"]="Materials"
C.parentByCategory["Cooking/Weapon"]="Cooking"
C.parentByCategory["Household/Weapon"]="Household"
C.parentByCategory["Instrument/Weapon"]="Entertainment"
C.parentByCategory["Sports/Weapon"]="Entertainment"
C.parentByCategory["Junk/Weapon"]="Other"
C.parentByCategory["VehicleMaintenance/Weapon"]="Vehicle"

-- No ordinary menu entries for these two internal categories.
-- This suppresses MENU discovery, not all item transfers. A visible mod item
-- declaring either raw ID still keeps that ID and the stored/default rule.
C.menuExcludedCategories={Hidden=true,Generic=true}

-- Narrow Base IDs reviewed against the collected vanilla source and translations.
-- This is NOT a global name substring, weight, missing-icon or missing-model rule.
-- Hidden/obsolete script flags remain handled independently below.
C.excludedItemTypes={
    ["Base.Hat_SantaHatDebug"]="reviewed debug hat",
    ["Base.FISH_DEV_ITEM"]="reviewed development item",
    ["Base.YardstickDEBUG"]="reviewed debug yardstick",
    ["Base.WaterRationCan_Open"]="explicit nonfunctional dummy",
    ["Base.MysteryCan_Open"]="explicit nonfunctional dummy",
    ["Base.DentedCan_Open"]="explicit nonfunctional dummy",
    ["Base.WaterDrop"]="reviewed non-drink placeholder",
    ["Base.Stairs"]="reviewed internal stairs placeholder",
    ["Base.TestWaterMug"]="reviewed test water-mug variant",
    ["Base.TestHotDrink"]="reviewed test hot-drink variant",
    ["Base.TestMug"]="reviewed base of the test mug chain",
    ["Base.TestDebugWater"]="reviewed debug liquid source",
    ["Base.DebugFluid"]="reviewed debug fluid container",
    ["Base.BucketWaterDebug"]="reviewed debug bucket variant",
    ["Base.Animal_Item_Dummy"]="native name explicitly DEBUG DUMMY ITEM",
    ["Base.Bitters"]="native name explicitly Bitters (Placeholder)",
}

function C.itemEligible(item)
    if not item then return false end
    local script=IT.call(item,"getScriptItem") or item
    if IT.call(script,"getObsolete")==true or IT.call(script,"isHidden")==true then
        return false
    end
    local full=IT.call(item,"getFullType") or IT.call(script,"getFullName")
        or IT.call(script,"getFullType")
    return not (full and C.excludedItemTypes[full])
end

function C.validKey(raw)
    return type(raw)=="string" and #raw>0 and #raw<=240 and not raw:find("[%z\1-\31]")
end
function C.rawCategory(item)
    if not item then return nil end
    -- Same precedence as ISInventoryPane's category column. ScriptItem has
    -- getDisplayCategory but not the runtime getCategory fallback: don't guess
    -- that fallback from ItemType. It is discovered from actual inventory items.
    local raw=IT.call(item,"getDisplayCategory")
    if raw==nil then raw=IT.call(item,"getCategory") end
    return C.validKey(raw) and raw or nil
end
function C.groupFor(raw)
    return C.parentByCategory[raw] or "Other"
end
function C.classify(item)
    if not C.itemEligible(item) then return nil end
    local raw=C.rawCategory(item)
    return raw and {group=C.groupFor(raw),category=raw} or nil
end
function C.purpose(item,raw)
    return C.groupFor(raw or C.rawCategory(item))
end
function C.rememberCategory(raw)
    if not C.validKey(raw) or C.menuExcludedCategories[raw] then return nil end
    if not C.known[raw] then
        local group=C.groupFor(raw)
        C.known[raw]=true
        C.leaves[raw]={group=group,category=raw}
        C.byGroup[group][#C.byGroup[group]+1]=raw
    end
    -- No group prefix: moving a category between parent menus must not change
    -- which inventory label it matches or the user's per-category selection.
    return raw
end
function C.remember(item)
    if not C.itemEligible(item) then return nil end
    return C.rememberCategory(C.rawCategory(item))
end
function C.key(item) return C.remember(item) end
function C.catalogEligible(script)
    return C.itemEligible(script)
end
function C.refreshRegistry()
    if C.scanned then return end
    local all=IT.call(getScriptManager and getScriptManager() or nil,"getAllItems")
    if not all or all:size()==0 then return end
    for i=0,all:size()-1 do
        local script=all:get(i)
        if C.catalogEligible(script) then
            -- Do not create entries for Java class names, ItemType enum keys or
            -- hypothetical leaves. Only actual declared display categories.
            C.rememberCategory(IT.call(script,"getDisplayCategory"))
        end
    end
    C.scanned=true
end
function C.keys(c)
    C.refreshRegistry()
    local items=IT.call(c,"getItems")
    if items then
        for i=0,items:size()-1 do C.remember(items:get(i)) end
    end
    local out={};for raw in pairs(C.known) do out[#out+1]=raw end
    table.sort(out);return out
end
function C.groupKeys(group,c)
    C.keys(c)
    local out={};for _,raw in ipairs(C.byGroup[group] or {}) do out[#out+1]=raw end
    table.sort(out);return out
end
function C.label(raw)
    -- Intentionally the EXACT call used by the inventory column, including any
    -- translation supplied by the game or another enabled mod. No local aliases.
    return getText("IGUI_ItemCat_"..raw)
end
function C.selected(record,key)
    if not record then return true end
    local value=record.categories[key]
    if value~=nil then return value==true end
    return record.all==true
end
function C.groupState(record,group,c)
    local keys=C.groupKeys(group,c)
    local on=0
    for _,key in ipairs(keys) do if C.selected(record,key) then on=on+1 end end
    return on>0 and on==#keys,on>0 and on<#keys,#keys
end
function C.matches(item,selected,all)
    if not C.itemEligible(item) then return false end
    -- A menu-suppressed category is not a deleted/reclassified game item.
    -- Retain its exact stored override or default (including select-all).
    local key=C.rawCategory(item)
    C.rememberCategory(key)
    if not key then return all==true end
    local value=selected and selected[key]
    if value~=nil then return value==true end
    return all==true
end
