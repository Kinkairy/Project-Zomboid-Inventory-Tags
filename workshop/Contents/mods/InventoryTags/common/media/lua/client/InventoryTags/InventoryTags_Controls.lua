require "InventoryTags/InventoryTags_Core"
require "InventoryTags/InventoryTags_Store"
require "InventoryTags/InventoryTags_Menu"
require "ISUI/LootWindow/ISLootWindowObjectControlHandler"
require "ISUI/LootWindow/ISLootWindowContainerControls"

local Store = InventoryTags.Store
local Menu = InventoryTags.Menu

ISLootWindowObjectControlHandler_InventoryTagsCategories =
    ISLootWindowObjectControlHandler:derive("ISLootWindowObjectControlHandler_InventoryTagsCategories")

function ISLootWindowObjectControlHandler_InventoryTagsCategories:shouldBeVisible()
    return InventoryTags.categoriesEnabled() and Store.isSupported(self.container)
end

function ISLootWindowObjectControlHandler_InventoryTagsCategories:getControl()
    return self:getButtonControl(getText("IGUI_InventoryTags_Categories"))
end

function ISLootWindowObjectControlHandler_InventoryTagsCategories:perform()
    Menu.openCategories(self.playerNum, self.container, self.control)
end

function ISLootWindowObjectControlHandler_InventoryTagsCategories:handleJoypadContextMenu(context)
    Menu.addCategoryEntry(context, self.playerNum, self.container)
end

function ISLootWindowObjectControlHandler_InventoryTagsCategories:new()
    local o = ISLootWindowObjectControlHandler.new(self)
    o.altColor = true
    return o
end

ISLootWindowObjectControlHandler_InventoryTagsSort =
    ISLootWindowObjectControlHandler:derive("ISLootWindowObjectControlHandler_InventoryTagsSort")

function ISLootWindowObjectControlHandler_InventoryTagsSort:shouldBeVisible()
    return InventoryTags.sortingEnabled() and Store.isSupported(self.container)
end

function ISLootWindowObjectControlHandler_InventoryTagsSort:getControl()
    return self:getButtonControl(getText("IGUI_InventoryTags_Sort"))
end

function ISLootWindowObjectControlHandler_InventoryTagsSort:perform()
    Menu.openSort(self.playerNum, self.container, self.control)
end

function ISLootWindowObjectControlHandler_InventoryTagsSort:handleJoypadContextMenu(context)
    Menu.addSortEntry(context, self.playerNum, self.container)
end

function ISLootWindowObjectControlHandler_InventoryTagsSort:new()
    local o = ISLootWindowObjectControlHandler.new(self)
    o.altColor = true
    return o
end

ISLootWindowObjectControlHandler_InventoryTagsAuto =
    ISLootWindowObjectControlHandler:derive("ISLootWindowObjectControlHandler_InventoryTagsAuto")

function ISLootWindowObjectControlHandler_InventoryTagsAuto:shouldBeVisible()
    return InventoryTags.autoOrganizeEnabled() and Store.isSupported(self.container)
end

function ISLootWindowObjectControlHandler_InventoryTagsAuto:getControl()
    return self:getButtonControl(getText("IGUI_InventoryTags_AutoOrganize"))
end

function ISLootWindowObjectControlHandler_InventoryTagsAuto:perform()
    Menu.onAutoOrganize(self.container, self.playerNum)
end

function ISLootWindowObjectControlHandler_InventoryTagsAuto:handleJoypadContextMenu(context)
    Menu.addAutoOrganizeEntry(context, self.playerNum, self.container)
end

function ISLootWindowObjectControlHandler_InventoryTagsAuto:new()
    local o = ISLootWindowObjectControlHandler.new(self)
    o.altColor = true
    return o
end

if not InventoryTags.ControlsRegistered then
    InventoryTags.ControlsRegistered = true
    -- Same native B42 loot-window control row used by stove/microwave controls.
    ISLootWindowContainerControls.AddHandler(ISLootWindowObjectControlHandler_InventoryTagsCategories, true)
    ISLootWindowContainerControls.AddHandler(ISLootWindowObjectControlHandler_InventoryTagsSort, true)
    ISLootWindowContainerControls.AddHandler(ISLootWindowObjectControlHandler_InventoryTagsAuto, true)
end
