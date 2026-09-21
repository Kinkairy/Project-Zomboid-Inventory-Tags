require "InventoryTags/InventoryTags_Core"
require "InventoryTags/InventoryTags_Store"
require "ISUI/ISInventoryPane"

InventoryTags.Sort = InventoryTags.Sort or {}
local Sort = InventoryTags.Sort
local Store = InventoryTags.Store

Sort.MODES = {
    { id = "default",      text = "IGUI_InventoryTags_Sort_Default" },
    { id = "nameAsc",      text = "IGUI_InventoryTags_Sort_NameAsc" },
    { id = "nameDesc",     text = "IGUI_InventoryTags_Sort_NameDesc" },
    { id = "quantityDesc", text = "IGUI_InventoryTags_Sort_QuantityDesc" },
    { id = "quantityAsc",  text = "IGUI_InventoryTags_Sort_QuantityAsc" },
    { id = "weightAsc",    text = "IGUI_InventoryTags_Sort_WeightAsc" },
    { id = "weightDesc",   text = "IGUI_InventoryTags_Sort_WeightDesc" },
    { id = "categoryAsc",  text = "IGUI_InventoryTags_Sort_CategoryAsc" },
    { id = "categoryDesc", text = "IGUI_InventoryTags_Sort_CategoryDesc" },
}

local function rowCount(row)
    return row and row.items and #row.items or 0
end

local function rowName(row)
    return InventoryTags.lower(row and row.name or "")
end

local function quantityAsc(a, b)
    local ac, bc = rowCount(a), rowCount(b)
    if ac ~= bc then
        return ac < bc
    end
    return rowName(a) < rowName(b)
end

local function quantityDesc(a, b)
    local ac, bc = rowCount(a), rowCount(b)
    if ac ~= bc then
        return ac > bc
    end
    return rowName(a) < rowName(b)
end

local function comparatorFor(mode)
    if mode == "nameAsc" then return ISInventoryPane.itemSortByNameInc end
    if mode == "nameDesc" then return ISInventoryPane.itemSortByNameDesc end
    if mode == "quantityAsc" then return quantityAsc end
    if mode == "quantityDesc" then return quantityDesc end
    if mode == "weightAsc" then return ISInventoryPane.itemSortByWeightAsc end
    if mode == "weightDesc" then return ISInventoryPane.itemSortByWeightDesc end
    if mode == "categoryAsc" then return ISInventoryPane.itemSortByCatInc end
    if mode == "categoryDesc" then return ISInventoryPane.itemSortByCatDesc end
    return nil
end

function Sort.applyToPane(pane, container, refresh)
    if not pane or not container then
        return
    end

    local mode = "default"
    if InventoryTags.sortingEnabled() and Store.isSupported(container) then
        mode = Store.getSortMode(container)
    end

    -- "Default" hands sorting back to vanilla.  If Inventory Tags had an
    -- active custom comparator, restore the vanilla initial comparator once;
    -- after that, native header clicks remain untouched.
    if mode == "default" then
        if pane._InventoryTagsCustomSortActive then
            pane._InventoryTagsCustomSortActive = false
            pane._InventoryTagsCustomSortContainer = nil
            if pane.itemSortFunc ~= ISInventoryPane.itemSortByNameInc then
                pane.itemSortFunc = ISInventoryPane.itemSortByNameInc
                if refresh ~= false then
                    pane:refreshContainer()
                end
            end
        end
        return
    end

    local comparator = comparatorFor(mode)
    if not comparator then
        return
    end

    pane._InventoryTagsCustomSortActive = true
    pane._InventoryTagsCustomSortContainer = container

    if pane.itemSortFunc ~= comparator then
        pane.itemSortFunc = comparator
        if refresh ~= false then
            pane:refreshContainer()
        end
    end
end

function Sort.applyToDisplayedContainer(playerNum, container)
    local loot = getPlayerLoot(playerNum)
    if loot and loot.inventoryPane and loot.inventoryPane.inventory == container then
        Sort.applyToPane(loot.inventoryPane, container, true)
    end
end
