require "InventoryTags/InventoryTags_Core"
require "InventoryTags/InventoryTags_Store"
require "InventoryTags/InventoryTags_Filter"
require "InventoryTags/InventoryTags_Sort"
require "InventoryTags/InventoryTags_Menu"
require "InventoryTags/InventoryTags_Controls"
require "ISUI/ISInventoryPane"
require "ISUI/ISInventoryPaneContextMenu"

local Store = InventoryTags.Store
local Filter = InventoryTags.Filter
local Sort = InventoryTags.Sort
local Menu = InventoryTags.Menu

InventoryTags.ContainerSyncCache = InventoryTags.ContainerSyncCache or {}
local SyncCache = InventoryTags.ContainerSyncCache

local function syncSignature(container)
    local settings = Store.getSettings(container, false)
    if not settings then
        return nil
    end
    return table.concat({
        Store.encodeCategories(settings.categories),
        settings.sortMode or "default",
        settings.nativeAccept or "",
    }, "|")
end

local function syncExistingSettings(playerNum, container)
    if not isClient() or playerNum == nil or not container then
        return
    end

    local signature = syncSignature(container)
    if not signature then
        return
    end

    local cacheKey = tostring(container)
    if SyncCache[cacheKey] == signature then
        return
    end

    Store.sync(container, getSpecificPlayer(playerNum))
    SyncCache[cacheKey] = signature
end

local function onRefreshContainers(page, phase)
    if phase ~= "end" or not page then
        return
    end

    if page.backpacks then
        for _, button in ipairs(page.backpacks) do
            if button.inventory and Store.isSupported(button.inventory) then
                Filter.apply(button.inventory)
                syncExistingSettings(page.player, button.inventory)
            end
        end
    end

    if page.onCharacter then
        return
    end

    local pane = page.inventoryPane
    local container = pane and pane.inventory or nil
    if pane and container and Store.isSupported(container) then
        Filter.apply(container)
        syncExistingSettings(page.player, container)
        Sort.applyToPane(pane, container, true)
    end
end

local function installTransferWrappers()
    if InventoryTags.TransferWrappersInstalled then
        return
    end
    InventoryTags.TransferWrappersInstalled = true

    local originalTransferItemsByWeight = ISInventoryPane.transferItemsByWeight
    ISInventoryPane.transferItemsByWeight = function(self, items, container)
        if container and Store.isSupported(container) then
            Filter.apply(container)
            syncExistingSettings(self.player, container)
        end
        return originalTransferItemsByWeight(self, items, container)
    end

    local originalOnPutItems = ISInventoryPaneContextMenu.onPutItems
    ISInventoryPaneContextMenu.onPutItems = function(items, player)
        local loot = getPlayerLoot(player)
        local container = loot and loot.inventory or nil
        if container and Store.isSupported(container) then
            Filter.apply(container)
            syncExistingSettings(player, container)
        end
        return originalOnPutItems(items, player)
    end

    local originalOnMoveItemsTo = ISInventoryPaneContextMenu.onMoveItemsTo
    ISInventoryPaneContextMenu.onMoveItemsTo = function(items, dest, player)
        if dest and Store.isSupported(dest) then
            Filter.apply(dest)
            syncExistingSettings(player, dest)
            if InventoryTags.categoriesEnabled() and Store.hasCategories(dest) then
                local actualItems = ISInventoryPane.getActualItems(items)
                actualItems = Filter.filterItems(dest, actualItems)
                if #actualItems == 0 then
                    return
                end
                return originalOnMoveItemsTo(actualItems, dest, player)
            end
        end
        return originalOnMoveItemsTo(items, dest, player)
    end
end

if not InventoryTags.ClientHooksInstalled then
    InventoryTags.ClientHooksInstalled = true
    installTransferWrappers()
    Events.OnFillWorldObjectContextMenu.Add(Menu.onWorldContext)
    Events.OnFillInventoryObjectContextMenu.Add(Menu.onInventoryObjectContext)
    Events.OnRefreshInventoryWindowContainers.Add(onRefreshContainers)
end
