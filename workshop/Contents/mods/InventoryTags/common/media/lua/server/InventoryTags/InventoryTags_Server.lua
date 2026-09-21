require "InventoryTags/InventoryTags_Core"
require "InventoryTags/InventoryTags_Store"
require "InventoryTags/InventoryTags_Filter"

local Store = InventoryTags.Store
local Filter = InventoryTags.Filter

local function closeEnough(player, x, y)
    if not player or not x or not y then
        return false
    end
    return math.abs(player:getX() - x) <= 6 and math.abs(player:getY() - y) <= 6
end

local function serverNativeAccept(container)
    local settings = Store.getSettings(container, false)
    local nativeAccept = settings and settings.nativeAccept or nil
    local current = container:getAcceptItemFunction()
    if current and current ~= "" and current ~= InventoryTags.ACCEPT_FUNCTION then
        nativeAccept = current
    end
    return nativeAccept
end

local function applyAuthoritativeSettings(container, args)
    local nativeAccept = serverNativeAccept(container)

    if not Store.applyNetworkSettings(container, args) then
        return false
    end

    -- The server owns the authoritative original acceptance callback. Do not
    -- trust a client-supplied value that could weaken vanilla/other-mod rules.
    local settings = Store.getSettings(container, true)
    settings.nativeAccept = nativeAccept

    Filter.apply(container)
    return true
end

local function getWorldObject(player, x, y, z, objectIndex)
    local square = getCell():getGridSquare(x, y, z)
    if not square or not closeEnough(player, x, y) then
        return nil
    end

    local objects = square:getObjects()
    objectIndex = tonumber(objectIndex)
    if not objects or not objectIndex or objectIndex < 0 or objectIndex >= objects:size() then
        return nil
    end
    return objects:get(objectIndex)
end

local function getWorldContainer(player, args, indexField)
    local object = getWorldObject(player, args.x, args.y, args.z, args.objectIndex)
    if not object or not object.getContainerCount or not object.getContainerByIndex then
        return nil, nil
    end

    local containerIndex = tonumber(args[indexField])
    if not containerIndex or containerIndex < 0 or containerIndex >= object:getContainerCount() then
        return nil, nil
    end
    return object:getContainerByIndex(containerIndex), object
end

local function getVehiclePartContainer(player, vehicleId, partIndex)
    vehicleId = tonumber(vehicleId)
    partIndex = tonumber(partIndex)
    if not vehicleId or not partIndex then
        return nil, nil, nil
    end

    local vehicle = getVehicleById(vehicleId)
    if not vehicle or not closeEnough(player, vehicle:getX(), vehicle:getY()) then
        return nil, nil, nil
    end
    if partIndex < 0 or partIndex >= vehicle:getPartCount() then
        return nil, nil, nil
    end

    local part = vehicle:getPartByIndex(partIndex)
    return part and part:getItemContainer() or nil, vehicle, part
end

local function itemById(container, itemID)
    if not container or not itemID then
        return nil
    end
    return container:getItemWithID(itemID) or container:getItemWithIDRecursiv(itemID)
end

local function getGroundItemById(player, args, itemID)
    local square = getCell():getGridSquare(args.x, args.y, args.z)
    if not square or not closeEnough(player, args.x, args.y) then
        return nil
    end

    itemID = tonumber(itemID)
    if not itemID then
        return nil
    end

    local worldObjects = square:getWorldObjects()
    for i = 0, worldObjects:size() - 1 do
        local worldItem = worldObjects:get(i)
        local item = worldItem and worldItem:getItem() or nil
        if item and item:getID() == itemID then
            return item
        end
    end
    return nil
end

local function getGroundItem(player, args)
    return getGroundItemById(player, args, args.itemID)
end

local function resolveItemOwner(player, args)
    local itemID = tonumber(args.itemID)
    if not itemID then
        return nil
    end

    if args.rootKind == "player" then
        return itemById(player:getInventory(), itemID)
    end

    if args.rootKind == "world" then
        local root = getWorldContainer(player, args, "rootContainerIndex")
        return itemById(root, itemID)
    end

    if args.rootKind == "vehicle" then
        local root = getVehiclePartContainer(player, args.vehicle, args.partIndex)
        return itemById(root, itemID)
    end

    if args.rootKind == "ground" then
        return getGroundItem(player, args)
    end

    if args.rootKind == "groundContainer" then
        local rootItem = getGroundItemById(player, args, args.rootItemID)
        if not rootItem or not instanceof(rootItem, "InventoryContainer") then
            return nil
        end
        return itemById(rootItem:getInventory(), itemID)
    end

    return nil
end

local function applyWorldSettings(player, args)
    local container, object = getWorldContainer(player, args, "containerIndex")
    if not container or not object or not Store.isSupported(container) then
        return
    end

    if applyAuthoritativeSettings(container, args) then
        object:transmitModData()
    end
end

local function applyVehicleSettings(player, args)
    local container, vehicle, part =
        getVehiclePartContainer(player, args.vehicle, args.partIndex)
    if not container or not vehicle or not part or not Store.isSupported(container) then
        return
    end

    if applyAuthoritativeSettings(container, args) then
        vehicle:transmitPartModData(part)
    end
end

local function applyItemSettings(player, args)
    local item = resolveItemOwner(player, args)
    if not item or not instanceof(item, "InventoryContainer") then
        return
    end

    local container = item:getInventory()
    if not container or not Store.isSupported(container) then
        return
    end

    -- Item ModData itself is synchronized by the native syncItemModData path.
    -- This command exists to restore the server-side runtime accept callback.
    applyAuthoritativeSettings(container, args)
end

local function onClientCommand(module, command, player, args)
    if module ~= "InventoryTags" or command ~= "setContainerSettings" or not args then
        return
    end

    if args.kind == "world" then
        applyWorldSettings(player, args)
    elseif args.kind == "vehicle" then
        applyVehicleSettings(player, args)
    elseif args.kind == "item" then
        applyItemSettings(player, args)
    end
end

Events.OnClientCommand.Add(onClientCommand)
