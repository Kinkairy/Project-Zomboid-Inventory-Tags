InventoryTags = InventoryTags or {}

InventoryTags.VERSION = "0.1.0"
InventoryTags.MOD_ID = "InventoryTags"
InventoryTags.ACCEPT_FUNCTION = "InventoryTags.Filter.acceptItem"
InventoryTags.MAX_AUTO_ORGANIZE_STEPS = 500

local function sandboxEnabled(name)
    local vars = SandboxVars and SandboxVars.InventoryTags
    if not vars then
        return true
    end
    return vars[name] ~= false
end

function InventoryTags.categoriesEnabled()
    return sandboxEnabled("EnableCategories")
end

function InventoryTags.sortingEnabled()
    return sandboxEnabled("EnableSorting")
end

function InventoryTags.autoOrganizeEnabled()
    return sandboxEnabled("EnableAutoOrganize")
end

function InventoryTags.resolveLuaFunction(path)
    if not path or path == "" then
        return nil
    end

    local value = _G
    for token in string.gmatch(path, "[^%.]+") do
        if value == nil then
            return nil
        end
        value = value[token]
    end

    if type(value) == "function" then
        return value
    end
    return nil
end

function InventoryTags.lower(value)
    if value == nil then
        return ""
    end
    return string.lower(tostring(value))
end
