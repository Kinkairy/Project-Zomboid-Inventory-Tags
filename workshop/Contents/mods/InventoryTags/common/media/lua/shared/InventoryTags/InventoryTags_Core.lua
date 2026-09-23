InventoryTags = InventoryTags or {}
local IT = InventoryTags
IT.VERSION = "0.1.3"
IT.PROTOCOL = 6
IT.ACCEPT_FUNCTION = "InventoryTags.Filter.acceptItem"
IT.MAX_AUTO_ORGANIZE_STEPS = 500
IT._logged = IT._logged or {}
function IT.logOnce(key, text)
    if IT._logged[key] then return end
    IT._logged[key] = true
    print("[InventoryTags " .. IT.VERSION .. "] " .. tostring(text))
end
function IT.enabled(name)
    local v = SandboxVars and SandboxVars.InventoryTags
    return not v or v[name] ~= false
end
function IT.categoriesEnabled() return IT.enabled("EnableCategories") end
function IT.selectionEnabled() return IT.enabled("EnableSelection") end
function IT.sortingEnabled() return IT.enabled("EnableSorting") end
function IT.autoOrganizeEnabled() return IT.enabled("EnableAutoOrganize") end
-- A guarded read of optional native APIs; never substitutes a successful write.
function IT.call(object, method, ...)
    if object == nil then return nil end
    local ok, fn = pcall(function() return object[method] end)
    if not ok or not fn then return nil end
    local success, value = pcall(fn, object, ...)
    if success then return value end
    return nil
end
function IT.integer(n, lo, hi)
    return type(n) == "number" and n == n and n % 1 == 0
        and n >= (lo or -9007199254740991) and n <= (hi or 9007199254740991)
end
function IT.now()
    if getTimestampMs then return getTimestampMs() end
    return (getTimestamp and getTimestamp() or 0) * 1000
end
-- Kahlua does not expose the standard Lua global next().
-- Use the native pairs iterator and return without mutating the table.
-- Keep this helper inside InventoryTags; never install a global polyfill.
function IT.hasEntries(value)
    if type(value) ~= "table" then return false end
    for _ in pairs(value) do return true end
    return false
end
function IT.copy(t)
    local r = {}
    for k,v in pairs(t or {}) do r[k] = v end
    return r
end
function IT.list(a)
    local r = {}
    if not a then return r end
    for i=0,a:size()-1 do r[#r+1] = a:get(i) end
    return r
end
function IT.id(item) return item and IT.call(item, "getID") end
function IT.isItem(x) return x and instanceof(x, "InventoryItem") end
function IT.itemsFromUI(values)
    local result, seen = {}, {}
    for _,row in ipairs(values or {}) do
        if IT.isItem(row) then
            if not seen[row] then result[#result+1]=row;seen[row]=true end
        elseif type(row)=="table" and row.items then
            for _,item in ipairs(row.items) do
                if IT.isItem(item) and not seen[item] then result[#result+1]=item;seen[item]=true end
            end
        end
    end
    return result
end
function IT.addEvent(name, fn)
    if not Events or not Events[name] then
        IT.logOnce("event:"..name, "Native event unavailable: "..name)
        return false
    end
    Events[name].Add(fn)
    return true
end
