require "InventoryTags/InventoryTags_Core"
require "InventoryTags/InventoryTags_Store"
require "InventoryTags/InventoryTags_Categories"
require "InventoryTags/InventoryTags_Filter"
require "InventoryTags/InventoryTags_Sort"
require "InventoryTags/InventoryTags_AutoOrganize"
require "ISUI/ISContextMenu"\nrequire "ISUI/ISInventoryPane"

InventoryTags.Menu = InventoryTags.Menu or {}
local Menu = InventoryTags.Menu
local Store = InventoryTags.Store
local Categories = InventoryTags.Categories
local Filter = InventoryTags.Filter
local Sort = InventoryTags.Sort
local AutoOrganize = InventoryTags.AutoOrganize

local function afterSettingsChanged(playerNum, container)
    local playerObj = getSpecificPlayer(playerNum)
    Filter.apply(container)
    Store.sync(container, playerObj)
    ISInventoryPage.dirtyUI()
end

function Menu.onToggleCategory(container, categoryId, playerNum)
    Store.toggleCategory(container, categoryId)
    afterSettingsChanged(playerNum, container)
end

function Menu.onClearCategories(container, playerNum)
    Store.clearCategories(container)
    afterSettingsChanged(playerNum, container)
end

function Menu.populateCategories(context, playerNum, container)
    context:addOption(
        getText("IGUI_InventoryTags_ClearCategories"),
        container,
        Menu.onClearCategories,
        playerNum
    )

    for _, def in ipairs(Categories.DEFINITIONS) do
        local option = context:addOption(
            getText(def.text),
            container,
            Menu.onToggleCategory,
            def.id,
            playerNum
        )
        context:setOptionChecked(option, Store.isCategoryEnabled(container, def.id))
    end
end

function Menu.addCategoryEntry(context, playerNum, container)
    local option = context:addOption(getText("IGUI_InventoryTags_Categories"))
    local subMenu = context:getNew(context)
    context:addSubMenu(option, subMenu)
    Menu.populateCategories(subMenu, playerNum, container)
    return option
end

function Menu.onSetSortMode(container, mode, playerNum)
    Store.setSortMode(container, mode)
    Store.sync(container, getSpecificPlayer(playerNum))
    Sort.applyToDisplayedContainer(playerNum, container)
    ISInventoryPage.dirtyUI()
end

function Menu.populateSort(context, playerNum, container)
    local current = Store.getSortMode(container)
    for _, def in ipairs(Sort.MODES) do
        local option = context:addOption(
            getText(def.text),
            container,
            Menu.onSetSortMode,
            def.id,
            playerNum
        )
        context:setOptionChecked(option, current == def.id)
    end
end

function Menu.addSortEntry(context, playerNum, container)
    local option = context:addOption(getText("IGUI_InventoryTags_Sort"))
    local subMenu = context:getNew(context)
    context:addSubMenu(option, subMenu)
    Menu.populateSort(subMenu, playerNum, container)
    return option
end

function Menu.onAutoOrganize(container, playerNum)
    AutoOrganize.start(playerNum, container)
end

function Menu.addAutoOrganizeEntry(context, playerNum, container)
    return context:addOption(
        getText("IGUI_InventoryTags_AutoOrganize"),
        container,
        Menu.onAutoOrganize,
        playerNum
    )
end

function Menu.addAllEntries(context, playerNum, container)
    if not Store.isSupported(container) then
        return
    end

    if InventoryTags.categoriesEnabled() then
        Menu.addCategoryEntry(context, playerNum, container)
    end
    if InventoryTags.sortingEnabled() then
        Menu.addSortEntry(context, playerNum, container)
    end
    if InventoryTags.autoOrganizeEnabled() then
        Menu.addAutoOrganizeEntry(context, playerNum, container)
    end
end

local function openAtControl(playerNum, control, populate)
    if not control then
        return
    end
    local context = ISContextMenu.get(
        playerNum,
        control:getAbsoluteX(),
        control:getAbsoluteY() + control:getHeight()
    )
    populate(context)
end

function Menu.openCategories(playerNum, container, control)
    openAtControl(playerNum, control, function(context)
        Menu.populateCategories(context, playerNum, container)
    end)
end

function Menu.openSort(playerNum, container, control)
    openAtControl(playerNum, control, function(context)
        Menu.populateSort(context, playerNum, container)
    end)
end

local function displayedContainerForObject(playerNum, object)
    local loot = getPlayerLoot(playerNum)
    local container = loot and loot.inventoryPane and loot.inventoryPane.inventory or nil
    if container and container:getParent() == object then
        return container
    end
    return nil
end

function Menu.findWorldContainer(playerNum, worldobjects)
    if not worldobjects then
        return nil
    end

    -- If the loot window is already showing one of the clicked world objects,
    -- that is the least ambiguous target on crowded squares.
    for _, object in ipairs(worldobjects) do
        if object and object.getContainerCount and object.getContainerByIndex then
            local displayed = displayedContainerForObject(playerNum, object)
            if displayed and Store.isSupported(displayed) then
                return displayed
            end
        end
    end

    for _, object in ipairs(worldobjects) do
        if object and object.getItem then
            local item = object:getItem()
            if item and instanceof(item, "InventoryContainer") then
                local itemContainer = item:getInventory()
                if itemContainer and Store.isSupported(itemContainer) then
                    return itemContainer
                end
            end
        end

        if object and object.getContainerCount and object.getContainerByIndex then
            local count = object:getContainerCount()
            for i = 0, count - 1 do
                local container = object:getContainerByIndex(i)
                if container and Store.isSupported(container) then
                    return container
                end
            end
        end
    end
    return nil
end

function Menu.onInventoryObjectContext(playerNum, context, items)
    local actualItems = ISInventoryPane.getActualItems(items or {})
    if #actualItems ~= 1 then
        return
    end

    local item = actualItems[1]
    if not item or not instanceof(item, "InventoryContainer") then
        return
    end

    local container = item:getInventory()
    if not container or not Store.isSupported(container) then
        return
    end

    Filter.apply(container)
    Menu.addAllEntries(context, playerNum, container)
end

function Menu.onWorldContext(playerNum, context, worldobjects, test)
    if test then
        return
    end

    local container = Menu.findWorldContainer(playerNum, worldobjects)
    if not container then
        return
    end

    Filter.apply(container)
    Menu.addAllEntries(context, playerNum, container)
end
