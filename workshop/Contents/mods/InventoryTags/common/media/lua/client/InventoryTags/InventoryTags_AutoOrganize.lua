require "InventoryTags/InventoryTags_Core"
require "InventoryTags/InventoryTags_Store"
require "InventoryTags/InventoryTags_Filter"
require "ISUI/ISInventoryPaneContextMenu"
require "ISUI/ISCraftingUI"
require "Entity/ISEntityUI"
require "TimedActions/ISInventoryTransferUtil"\nrequire "TimedActions/ISTimedActionQueue"

InventoryTags.AutoOrganize = InventoryTags.AutoOrganize or {}
local AutoOrganize = InventoryTags.AutoOrganize
local Store = InventoryTags.Store
local Filter = InventoryTags.Filter

AutoOrganize.sessions = AutoOrganize.sessions or {}
AutoOrganize.nextSessionId = AutoOrganize.nextSessionId or 1

local reverseWords = {
    "open ",
    "open_",
    "unpack",
    "unstack",
    "unbundle",
    "unwrap",
    "remove from",
    "take out",
    "takeout",
    "empty ",
}

local function isCompressionRecipe(recipe)
    if not recipe then
        return false
    end

    if InventoryTags.lower(recipe:getCategory()) ~= "packing" then
        return false
    end

    local combined = InventoryTags.lower(recipe:getName()) .. " " ..
        InventoryTags.lower(recipe:getTranslationName())

    for _, word in ipairs(reverseWords) do
        if string.find(combined, word, 1, true) then
            return false
        end
    end

    -- The vanilla Packing category also contains destructive/extraction
    -- recipes such as Gather Gunpowder, Take Clay from Sack and Empty Sack.
    -- Only explicit compression/packing verbs are eligible.
    local compressionWords = {
        "pack",
        "place",
        "put",
        "stack items",
        "stack_items",
    }
    for _, word in ipairs(compressionWords) do
        if string.find(combined, word, 1, true) then
            return true
        end
    end
    return false
end

local function getContainersTargetFirst(playerObj, targetContainer)
    local result = ArrayList.new()
    if targetContainer then
        result:add(targetContainer)
    end

    local native = ISInventoryPaneContextMenu.getContainers(playerObj)
    for i = 0, native:size() - 1 do
        local container = native:get(i)
        if container ~= targetContainer then
            result:add(container)
        end
    end
    return result
end

local function inputsAreFromTarget(logic, targetContainer)
    local data = logic and logic:getRecipeData() or nil
    if not data then
        return false
    end

    local items = data:getAllInputItems()
    if not items or items:isEmpty() then
        return false
    end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if not item or item:getContainer() ~= targetContainer then
            return false
        end
    end
    return true
end

local function findNext(playerObj, container)
    if not container or not container:getItems() then
        return nil
    end

    local containers = getContainersTargetFirst(playerObj, container)
    local items = container:getItems()
    local seenType = {}

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local fullType = item:getFullType()
        if not seenType[fullType] then
            seenType[fullType] = true

            local recipes = CraftRecipeManager.getUniqueRecipeItems(item, playerObj, containers)
            if recipes then
                for j = 0, recipes:size() - 1 do
                    local recipe = recipes:get(j)
                    if isCompressionRecipe(recipe) then
                        local logic = HandcraftLogic.new(playerObj, nil, nil)
                        logic:setIsoObject(logic:findCraftSurface(playerObj, 2))
                        logic:setContainers(containers)
                        logic:setRecipeFromContextClick(recipe, item)

                        if logic:canPerformCurrentRecipe() and inputsAreFromTarget(logic, container) then
                            return {
                                item = item,
                                recipe = recipe,
                                logic = logic,
                            }
                        end
                    end
                end
            end
        end
    end

    return nil
end

local function snapshotInventory(container)
    local snapshot = {}
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        snapshot[items:get(i)] = true
    end
    return snapshot
end

local function queueIsIdle(playerObj)
    local queue = ISTimedActionQueue.getTimedActionQueue(playerObj)
    return not queue or not queue.queue or #queue.queue == 0
end

function AutoOrganize.finish(state)
    if not state then
        return
    end
    if AutoOrganize.sessions[state.playerNum] == state then
        AutoOrganize.sessions[state.playerNum] = nil
    end
    ISInventoryPage.dirtyUI()
end

function AutoOrganize.onCraftComplete(state)
    if not state or AutoOrganize.sessions[state.playerNum] ~= state then
        return
    end
    if state.completionHandled then
        return
    end
    state.completionHandled = true

    if state.currentLogic then
        state.currentLogic:stopCraftAction()
    end

    state.currentAction = nil
    state.currentLogic = nil
    state.phase = "awaitOutput"
    state.outputWaitTicks = 0
end

local function queueOutputTransfers(state, newItems)
    Filter.apply(state.container)

    local queued = 0
    for _, item in ipairs(newItems) do
        local source = item:getContainer()
        if source and source ~= state.container and state.container:isItemAllowed(item) then
            ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(
                state.playerObj,
                item,
                source,
                state.container
            ))
            queued = queued + 1
        end
    end
    return queued
end

function AutoOrganize.finalizeCraft(state)
    if not state.beforeInventory then
        AutoOrganize.finish(state)
        return
    end

    local inventory = state.playerObj:getInventory()
    local newItems = {}
    local items = inventory:getItems()

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if not state.beforeInventory[item] then
            table.insert(newItems, item)
        end
    end

    if #newItems == 0 then
        state.outputWaitTicks = (state.outputWaitTicks or 0) + 1
        if state.outputWaitTicks < 30 then
            return
        end

        -- No output reached the client after the vanilla action completed.
        -- Stop rather than guessing or creating an item ourselves.
        AutoOrganize.finish(state)
        return
    end

    local queued = queueOutputTransfers(state, newItems)

    state.beforeInventory = nil
    state.outputWaitTicks = nil
    state.completionHandled = nil

    if queued > 0 then
        state.phase = "returningOutput"
    else
        state.phase = "waiting"
    end
end

local function startRecipe(state, candidate)
    local playerObj = state.playerObj
    local logic = candidate.logic
    local recipe = candidate.recipe
    local selectedItem = candidate.item

    -- Snapshot before vanilla transferIfNeeded moves the target-container
    -- recipe inputs into the player inventory.
    state.beforeInventory = snapshotInventory(playerObj:getInventory())
    state.completionHandled = false

    local items = logic:getRecipeData():getAllInputItems()
    local itemsToReturn = logic:getRecipeData():getAllPutBackInputItems()
    local returnToContainer = {}

    if logic:isUsingRecipeAtHandBenefit() then
        local recipeAtHandItem = logic:getUsingRecipeAtHandItem()
        if recipeAtHandItem then
            items:add(recipeAtHandItem)
            itemsToReturn:add(recipeAtHandItem)
        end
    end

    if not recipe:isCanBeDoneFromFloor() then
        local itemsWereMoved = false
        for i = 1, items:size() do
            local item = items:get(i - 1)
            if item:getContainer() ~= playerObj:getInventory() then
                ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
                if itemsToReturn:contains(item) then
                    table.insert(returnToContainer, item)
                end
                itemsWereMoved = true
            end
        end
        if itemsWereMoved then
            logic:setRecipeFromContextClick(recipe, selectedItem)
        end
    end

    local action = ISEntityUI.HandcraftStart(playerObj, logic, false, true, 0)
    if not action then
        state.beforeInventory = nil
        state.completionHandled = nil
        return false
    end

    state.currentAction = action
    state.currentLogic = logic
    state.phase = "crafting"
    state.craftIdleTicks = 0

    action:setOnComplete(AutoOrganize.onCraftComplete, state)
    logic:startCraftAction(action)

    ISCraftingUI.ReturnItemsToOriginalContainer(playerObj, returnToContainer)
    return true
end

function AutoOrganize.continue(state)
    if not state or AutoOrganize.sessions[state.playerNum] ~= state then
        return
    end

    if not InventoryTags.autoOrganizeEnabled() or not Store.isSupported(state.container) then
        AutoOrganize.finish(state)
        return
    end

    state.steps = state.steps + 1
    if state.steps > InventoryTags.MAX_AUTO_ORGANIZE_STEPS then
        AutoOrganize.finish(state)
        return
    end

    local candidate = findNext(state.playerObj, state.container)
    if not candidate then
        AutoOrganize.finish(state)
        return
    end

    if not startRecipe(state, candidate) then
        AutoOrganize.finish(state)
    end
end

function AutoOrganize.onTick()
    for _, state in pairs(AutoOrganize.sessions) do
        if queueIsIdle(state.playerObj) then
            if state.phase == "waiting" then
                AutoOrganize.continue(state)
            elseif state.phase == "awaitOutput" then
                AutoOrganize.finalizeCraft(state)
            elseif state.phase == "returningOutput" then
                state.phase = "waiting"
                AutoOrganize.continue(state)
            elseif state.phase == "crafting" then
                -- Native onComplete should move us to awaitOutput.  This is only
                -- a fail-safe for an interrupted/client-side callback.
                state.craftIdleTicks = (state.craftIdleTicks or 0) + 1
                if state.craftIdleTicks > 10 then
                    AutoOrganize.onCraftComplete(state)
                end
            end
        end
    end
end

function AutoOrganize.start(playerNum, container)
    if not InventoryTags.autoOrganizeEnabled() or not Store.isSupported(container) then
        return false
    end

    if AutoOrganize.sessions[playerNum] then
        return false
    end

    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then
        return false
    end

    local state = {
        id = AutoOrganize.nextSessionId,
        playerNum = playerNum,
        playerObj = playerObj,
        container = container,
        steps = 0,
        phase = "waiting",
    }

    AutoOrganize.nextSessionId = AutoOrganize.nextSessionId + 1
    AutoOrganize.sessions[playerNum] = state

    if queueIsIdle(playerObj) then
        AutoOrganize.continue(state)
    end
    return true
end

if not AutoOrganize.tickInstalled then
    AutoOrganize.tickInstalled = true
    Events.OnTick.Add(AutoOrganize.onTick)
end
