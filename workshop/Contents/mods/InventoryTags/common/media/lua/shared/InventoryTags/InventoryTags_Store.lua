require "InventoryTags/InventoryTags_Core"

InventoryTags.Store = InventoryTags.Store or {}
local Store = InventoryTags.Store

local ROOT_KEY = "InventoryTags"

local function normalize(record)
    if not record then
        return nil
    end
    record.categories = record.categories or {}
    record.sortMode = record.sortMode or "default"
    return record
end

local function getContainerIndex(parent, container)
    if not parent or not container or not parent.getContainerCount or not parent.getContainerByIndex then
        return nil
    end

    local count = parent:getContainerCount()
    for i = 0, count - 1 do
        if parent:getContainerByIndex(i) == container then
            return i
        end
    end
    return nil
end

function Store.getOwner(container)
    if not container or container:getType() == "floor" then
        return nil
    end

    local part = container:getVehiclePart()
    if part then
        return {
            kind = "vehicle",
            part = part,
            vehicle = part:getVehicle(),
        }
    end

    local item = container:getContainingItem()
    if item then
        return {
            kind = "item",
            item = item,
        }
    end

    local parent = container:getParent()
    if not parent then
        return nil
    end
    if instanceof(parent, "IsoGameCharacter") or instanceof(parent, "IsoDeadBody") then
        return nil
    end
    if not parent.getModData then
        return nil
    end

    local containerIndex = getContainerIndex(parent, container)
    if containerIndex == nil then
        return nil
    end

    return {
        kind = "world",
        object = parent,
        containerIndex = containerIndex,
    }
end

function Store.isSupported(container)
    return Store.getOwner(container) ~= nil
end

function Store.getSettings(container, create)
    local owner = Store.getOwner(container)
    if not owner then
        return nil, nil
    end

    local modData
    local record

    if owner.kind == "vehicle" then
        modData = owner.part:getModData()
        if create and not modData[ROOT_KEY] then
            modData[ROOT_KEY] = {}
        end
        record = modData[ROOT_KEY]
    elseif owner.kind == "item" then
        modData = owner.item:getModData()
        if create and not modData[ROOT_KEY] then
            modData[ROOT_KEY] = {}
        end
        record = modData[ROOT_KEY]
    else
        modData = owner.object:getModData()
        if create and not modData[ROOT_KEY] then
            modData[ROOT_KEY] = { containers = {} }
        end
        local root = modData[ROOT_KEY]
        if not root then
            return nil, owner
        end
        root.containers = root.containers or {}
        local key = tostring(owner.containerIndex)
        if create and not root.containers[key] then
            root.containers[key] = {}
        end
        record = root.containers[key]
    end

    return normalize(record), owner
end

function Store.hasCategories(container)
    local settings = Store.getSettings(container, false)
    if not settings or not settings.categories then
        return false
    end
    for _, enabled in pairs(settings.categories) do
        if enabled then
            return true
        end
    end
    return false
end

function Store.isCategoryEnabled(container, categoryId)
    local settings = Store.getSettings(container, false)
    return settings and settings.categories and settings.categories[categoryId] == true or false
end

function Store.setCategory(container, categoryId, enabled)
    local settings = Store.getSettings(container, true)
    if not settings then
        return false
    end
    if enabled then
        settings.categories[categoryId] = true
    else
        settings.categories[categoryId] = nil
    end
    return true
end

function Store.toggleCategory(container, categoryId)
    local enabled = not Store.isCategoryEnabled(container, categoryId)
    Store.setCategory(container, categoryId, enabled)
    return enabled
end

function Store.clearCategories(container)
    local settings = Store.getSettings(container, true)
    if not settings then
        return false
    end
    settings.categories = {}
    return true
end

function Store.getSortMode(container)
    local settings = Store.getSettings(container, false)
    return settings and settings.sortMode or "default"
end

function Store.setSortMode(container, mode)
    local settings = Store.getSettings(container, true)
    if not settings then
        return false
    end
    settings.sortMode = mode or "default"
    return true
end

function Store.encodeCategories(categories)
    local ids = {}
    for id, enabled in pairs(categories or {}) do
        if enabled then
            table.insert(ids, tostring(id))
        end
    end
    table.sort(ids)
    return table.concat(ids, ",")
end

function Store.decodeCategories(encoded)
    local categories = {}
    if not encoded or encoded == "" then
        return categories
    end
    for id in string.gmatch(encoded, "[^,]+") do
        categories[id] = true
    end
    return categories
end

function Store.applyNetworkSettings(container, args)
    local settings = Store.getSettings(container, true)
    if not settings then
        return false
    end

    settings.categories = Store.decodeCategories(args and args.categories or "")
    settings.sortMode = args and args.sortMode or "default"
    local nativeAccept = args and args.nativeAccept or nil
    settings.nativeAccept = nativeAccept ~= "" and nativeAccept or nil
    return true
end

local function addWorldRoot(args, root)
    local parent = root and root:getParent() or nil
    if not parent or not parent.getContainerCount or not parent.getContainerByIndex then
        return false
    end

    local square = parent:getSquare()
    local containerIndex = getContainerIndex(parent, root)
    if not square or containerIndex == nil then
        return false
    end

    args.rootKind = "world"
    args.x = square:getX()
    args.y = square:getY()
    args.z = square:getZ()
    args.objectIndex = parent:getObjectIndex()
    args.rootContainerIndex = containerIndex
    return true
end

local function addVehicleRoot(args, root)
    local part = root and root:getVehiclePart() or nil
    local vehicle = part and part:getVehicle() or nil
    if not part or not vehicle then
        return false
    end

    args.rootKind = "vehicle"
    args.vehicle = vehicle:getId()
    args.partIndex = part:getIndex()
    return true
end

local function addItemLocator(args, item, playerObj)
    args.itemID = item:getID()

    local worldItem = item:getWorldItem()
    if worldItem and worldItem:getSquare() and not item:getContainer() then
        local square = worldItem:getSquare()
        args.rootKind = "ground"
        args.x = square:getX()
        args.y = square:getY()
        args.z = square:getZ()
        return true
    end

    local root = item:getOutermostContainer()
    if not root then
        return false
    end

    if playerObj and root == playerObj:getInventory() then
        args.rootKind = "player"
        return true
    end

    local rootItem = root:getContainingItem()
    local rootWorldItem = rootItem and rootItem:getWorldItem() or nil
    if rootWorldItem and rootWorldItem:getSquare() then
        local square = rootWorldItem:getSquare()
        args.rootKind = "groundContainer"
        args.rootItemID = rootItem:getID()
        args.x = square:getX()
        args.y = square:getY()
        args.z = square:getZ()
        return true
    end

    if addVehicleRoot(args, root) then
        return true
    end

    if addWorldRoot(args, root) then
        return true
    end

    return false
end

function Store.sync(container, playerObj)
    local settings, owner = Store.getSettings(container, false)
    if not settings or not owner then
        return
    end

    if not isClient() or not playerObj then
        return
    end

    local args = {
        categories = Store.encodeCategories(settings.categories),
        sortMode = settings.sortMode or "default",
        nativeAccept = settings.nativeAccept or "",
    }

    if owner.kind == "item" then
        if syncItemModData then
            syncItemModData(playerObj, owner.item)
        end
        args.kind = "item"
        if not addItemLocator(args, owner.item, playerObj) then
            return
        end
    elseif owner.kind == "vehicle" then
        if not owner.vehicle then
            return
        end
        args.kind = "vehicle"
        args.vehicle = owner.vehicle:getId()
        args.partIndex = owner.part:getIndex()
    else
        local square = owner.object:getSquare()
        if not square then
            return
        end
        args.kind = "world"
        args.x = square:getX()
        args.y = square:getY()
        args.z = square:getZ()
        args.objectIndex = owner.object:getObjectIndex()
        args.containerIndex = owner.containerIndex
    end

    sendClientCommand(playerObj, "InventoryTags", "setContainerSettings", args)
end
