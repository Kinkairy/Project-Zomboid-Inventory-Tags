require "InventoryTags/InventoryTags_Core"

InventoryTags.Categories = InventoryTags.Categories or {}
local Categories = InventoryTags.Categories

Categories.DEFINITIONS = {
    { id = "Food",        text = "IGUI_InventoryTags_Category_Food" },
    { id = "Drinks",      text = "IGUI_InventoryTags_Category_Drinks" },
    { id = "Medical",     text = "IGUI_InventoryTags_Category_Medical" },
    { id = "Weapons",     text = "IGUI_InventoryTags_Category_Weapons" },
    { id = "Ammo",        text = "IGUI_InventoryTags_Category_Ammo" },
    { id = "Clothing",    text = "IGUI_InventoryTags_Category_Clothing" },
    { id = "Tools",       text = "IGUI_InventoryTags_Category_Tools" },
    { id = "Materials",   text = "IGUI_InventoryTags_Category_Materials" },
    { id = "Literature",  text = "IGUI_InventoryTags_Category_Literature" },
    { id = "Electronics", text = "IGUI_InventoryTags_Category_Electronics" },
    { id = "Vehicle",     text = "IGUI_InventoryTags_Category_Vehicle" },
    { id = "Farming",     text = "IGUI_InventoryTags_Category_Farming" },
    { id = "Fishing",     text = "IGUI_InventoryTags_Category_Fishing" },
    { id = "Cooking",     text = "IGUI_InventoryTags_Category_Cooking" },
    { id = "Containers",  text = "IGUI_InventoryTags_Category_Containers" },
    { id = "Misc",        text = "IGUI_InventoryTags_Category_Misc" },
}

local function safeValue(item, methodName)
    if not item or not item[methodName] then
        return nil
    end
    local ok, value = pcall(item[methodName], item)
    return ok and value or nil
end

local function safeBool(item, methodName)
    return safeValue(item, methodName) == true
end

local function safeHasTag(item, tag)
    if not item or not tag or not item.hasTag then
        return false
    end
    local ok, value = pcall(item.hasTag, item, tag)
    return ok and value == true
end

local function containsAny(text, needles)
    text = InventoryTags.lower(text)
    for _, needle in ipairs(needles) do
        if string.find(text, needle, 1, true) then
            return true
        end
    end
    return false
end

local function descriptors(item)
    return table.concat({
        tostring(safeValue(item, "getDisplayCategory") or ""),
        tostring(safeValue(item, "getCategory") or ""),
        tostring(safeValue(item, "getStringItemType") or ""),
        tostring(safeValue(item, "getFullType") or ""),
    }, " "):lower()
end

local function isDrink(item, desc)
    local fluidContainer = safeValue(item, "getFluidContainer")
    if fluidContainer and fluidContainer.getPrimaryFluid then
        local okPrimary, primary = pcall(fluidContainer.getPrimaryFluid, fluidContainer)
        if okPrimary and primary and FluidCategory and primary.isCategory then
            local okBeverage, beverage = pcall(primary.isCategory, primary, FluidCategory.Beverage)
            if okBeverage and beverage then
                return true
            end
        end
    end
    return containsAny(desc, {
        "drink", "beverage", "water", "soda", "juice", "coffee", "tea",
        "beer", "wine", "liquor", "alcohol",
    })
end

local function isMedical(item, desc)
    if safeValue(item, "getStringItemType") == "Medical" then
        return true
    end
    return containsAny(desc, {
        "medical", "firstaid", "first aid", "bandage", "medicine",
        "antibiotic", "pill",
    })
end

local function isAmmo(item, desc)
    if ItemTag then
        if safeHasTag(item, ItemTag.AMMO) or
                safeHasTag(item, ItemTag.SHOTGUN_SHELL) or
                safeHasTag(item, ItemTag.PISTOL_MAGAZINE) then
            return true
        end
    end
    return containsAny(desc, { "ammo", "ammunition", "bullet", "shell" })
end

local function isTool(desc)
    return containsAny(desc, { "tool", "toolbox" })
end

local function isFood(item, desc)
    if isDrink(item, desc) or isMedical(item, desc) then
        return false
    end

    if containsAny(desc, { "food", "ingredient" }) then
        return true
    end

    if instanceof(item, "Food") then
        local hunger = safeValue(item, "getHungChange")
        return hunger ~= nil and hunger < 0
    end
    return false
end

local function matchKnown(item, categoryId, desc)
    if categoryId == "Drinks" then
        return isDrink(item, desc)
    end

    if categoryId == "Food" then
        return isFood(item, desc)
    end

    if categoryId == "Medical" then
        return isMedical(item, desc)
    end

    if categoryId == "Ammo" then
        return isAmmo(item, desc)
    end

    if categoryId == "Tools" then
        return isTool(desc)
    end

    if categoryId == "Weapons" then
        return (instanceof(item, "HandWeapon") or
            containsAny(desc, { "weapon", "firearm", "melee" })) and not isTool(desc)
    end

    if categoryId == "Clothing" then
        return instanceof(item, "Clothing") or
            containsAny(desc, { "clothing", "armor", "armour" })
    end

    if categoryId == "Materials" then
        return containsAny(desc, {
            "material", "crafting", "resource", "metalwork", "carpentry",
        })
    end

    if categoryId == "Literature" then
        return safeBool(item, "IsLiterature") or
            containsAny(desc, { "literature", "book", "magazine", "newspaper" })
    end

    if categoryId == "Electronics" then
        return instanceof(item, "Radio") or
            containsAny(desc, { "electronic", "radio", "device", "communication" })
    end

    if categoryId == "Vehicle" then
        return containsAny(desc, {
            "vehicle", "mechanic", "automotive", "carpart", "car part",
        })
    end

    if categoryId == "Farming" then
        return containsAny(desc, { "farming", "agriculture", "seed", "gardening" })
    end

    if categoryId == "Fishing" then
        return containsAny(desc, { "fishing", "fishbait", "fish bait", "lure" })
    end

    if categoryId == "Cooking" then
        return containsAny(desc, { "cooking", "cookware", "kitchen", "baking" })
    end

    if categoryId == "Containers" then
        return instanceof(item, "InventoryContainer") or
            containsAny(desc, { "container", "bag" })
    end

    return false
end

function Categories.matchesCategory(item, categoryId)
    if not item or not categoryId then
        return false
    end

    local desc = descriptors(item)
    if categoryId ~= "Misc" then
        return matchKnown(item, categoryId, desc)
    end

    for _, def in ipairs(Categories.DEFINITIONS) do
        if def.id ~= "Misc" and matchKnown(item, def.id, desc) then
            return false
        end
    end
    return true
end

function Categories.matchesAny(item, selected)
    for categoryId, enabled in pairs(selected or {}) do
        if enabled and Categories.matchesCategory(item, categoryId) then
            return true
        end
    end
    return false
end
