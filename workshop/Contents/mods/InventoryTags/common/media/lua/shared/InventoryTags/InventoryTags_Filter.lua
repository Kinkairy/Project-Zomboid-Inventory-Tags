require "InventoryTags/InventoryTags_Core"
require "InventoryTags/InventoryTags_Store"
require "InventoryTags/InventoryTags_Categories"

InventoryTags.Filter = InventoryTags.Filter or {}
local Filter = InventoryTags.Filter
local Store = InventoryTags.Store
local Categories = InventoryTags.Categories

local function callNative(settings, container, item)
    local nativeAccept = settings and settings.nativeAccept
    if not nativeAccept or nativeAccept == "" or nativeAccept == InventoryTags.ACCEPT_FUNCTION then
        return true
    end

    -- Delegate the original restriction back through ItemContainer itself.
    -- This preserves vanilla/other-mod acceptance behavior and any native
    -- OnlyAcceptCategory check instead of duplicating those rules here.
    container:setAcceptItemFunction(nativeAccept)
    local ok, allowed = pcall(container.isItemAllowed, container, item)
    container:setAcceptItemFunction(InventoryTags.ACCEPT_FUNCTION)

    return ok and allowed == true
end

function Filter.acceptItem(container, item)
    local settings = Store.getSettings(container, false)
    if not settings then
        return true
    end

    if not callNative(settings, container, item) then
        return false
    end

    if not InventoryTags.categoriesEnabled() then
        return true
    end

    local hasAny = false
    for _, enabled in pairs(settings.categories or {}) do
        if enabled then
            hasAny = true
            break
        end
    end
    if not hasAny then
        return true
    end

    return Categories.matchesAny(item, settings.categories)
end

function Filter.apply(container)
    if not container or not Store.isSupported(container) then
        return
    end

    local settings = Store.getSettings(container, false)
    local current = container:getAcceptItemFunction()

    if not settings or not InventoryTags.categoriesEnabled() or not Store.hasCategories(container) then
        if current == InventoryTags.ACCEPT_FUNCTION then
            container:setAcceptItemFunction(settings and settings.nativeAccept or nil)
        end
        return
    end

    if current ~= InventoryTags.ACCEPT_FUNCTION then
        settings.nativeAccept = current
    end
    container:setAcceptItemFunction(InventoryTags.ACCEPT_FUNCTION)
end

function Filter.filterItems(container, items)
    Filter.apply(container)
    local result = {}
    for _, item in ipairs(items or {}) do
        if container:isItemAllowed(item) then
            table.insert(result, item)
        end
    end
    return result
end
