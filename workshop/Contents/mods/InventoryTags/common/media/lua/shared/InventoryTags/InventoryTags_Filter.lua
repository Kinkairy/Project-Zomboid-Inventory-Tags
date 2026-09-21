require "InventoryTags/InventoryTags_Categories"
require "InventoryTags/InventoryTags_Store"
local IT=InventoryTags
IT.Filter=IT.Filter or {}
local F=IT.Filter
F.bound=F.bound or setmetatable({},{__mode="k"})
F.busy=F.busy or setmetatable({},{__mode="k"})
F.blocked=F.blocked or setmetatable({},{__mode="k"})
function F.native(c,item)
    local state=F.bound[c]
    local old=state and state.original
    if not state then
        local stored=IT.Store.raw(c)
        old=(stored and stored.nativeAccept)
    end
    if old==IT.ACCEPT_FUNCTION then old=nil end
    if F.busy[c] then return false end
    F.busy[c]=true
    local before=c:getAcceptItemFunction()
    c:setAcceptItemFunction(old)
    local ok,allowed=pcall(c.isItemAllowed,c,item)
    c:setAcceptItemFunction(before)
    F.busy[c]=nil
    if not ok then IT.logOnce("native-accept:"..tostring(old),"Native acceptance callback failed; item retained") end
    return ok and allowed==true
end
function F.acceptItem(c,item)
    if not F.native(c,item) then return false end
    if not IT.categoriesEnabled() or not IT.Store.isSupported(c) then return true end
    local s=IT.Store.get(c,false)
    return not s or IT.Categories.matches(item,s.categories,s.all)
end
function F.detach(c)
    if not c then return end
    local current=IT.call(c,"getAcceptItemFunction")
    local state=F.bound[c]
    if current==IT.ACCEPT_FUNCTION then
        local stored=IT.Store.raw(c)
        local original=state and state.original or (stored and stored.nativeAccept)
        if original==IT.ACCEPT_FUNCTION then original=nil end
        c:setAcceptItemFunction(original)
    end
    F.bound[c]=nil;F.blocked[c]=nil
end
function F.apply(c)
    if not IT.Store.isSupported(c) then F.detach(c);return end
    local current=c:getAcceptItemFunction()
    local state=F.bound[c]
    if F.blocked[c] then return end
    if state and current~=IT.ACCEPT_FUNCTION then
        -- Another mod took ownership. Never overwrite its callback on refresh.
        F.bound[c]=nil;F.blocked[c]=true
        IT.logOnce("accept-conflict:"..tostring(c),"Another mod changed a tagged container callback; using transfer gate without replacing it")
        return
    end
    if not IT.categoriesEnabled() or not IT.Store.hasTags(c) then
        if current==IT.ACCEPT_FUNCTION then
            local original
            if state then original=state.original else
                local stored=IT.Store.raw(c)
                original=(stored and stored.nativeAccept)
            end
            if original==IT.ACCEPT_FUNCTION then original=nil end
            c:setAcceptItemFunction(original)
        end
        F.bound[c]=nil;return
    end
    if not state then
        local original=current
        local stored=IT.Store.raw(c)
        if original==IT.ACCEPT_FUNCTION then original=(stored and stored.nativeAccept) end
        if original==IT.ACCEPT_FUNCTION then original=nil end
        state={original=original};F.bound[c]=state
        if stored then stored.nativeAccept=original end
    end
    c:setAcceptItemFunction(IT.ACCEPT_FUNCTION)
end
function F.allowed(c,item)
    if not c then return false end
    F.apply(c)
    if not c:isItemAllowed(item) then return false end
    if not IT.categoriesEnabled() or not IT.Store.isSupported(c) then return true end
    local s=IT.Store.get(c,false)
    return not s or IT.Categories.matches(item,s.categories,s.all)
end
function F.filter(c,items)
    local r={}
    for _,item in ipairs(items or {}) do if F.allowed(c,item) then r[#r+1]=item end end
    return r
end
function F.refreshBound()
    for c in pairs(F.bound) do F.apply(c) end
end
