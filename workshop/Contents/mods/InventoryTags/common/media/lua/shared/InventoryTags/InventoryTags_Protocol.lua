require "InventoryTags/InventoryTags_Access"
require "InventoryTags/InventoryTags_Filter"
local IT=InventoryTags
IT.Protocol=IT.Protocol or {}
local P=IT.Protocol
P.memo=P.memo or setmetatable({},{__mode="k"})
function P.process(player,a,directTarget)
    if type(a)~="table" or a.protocol~=IT.PROTOCOL or type(a.token)~="string" or #a.token>120
        or not a.token:match("^[%w:_%-]+$") then return nil end
    local cache=P.memo[player]
    if not cache then cache={map={},order={}};P.memo[player]=cache end
    if cache.map[a.token] then return cache.map[a.token] end
    local reply={token=a.token,protocol=IT.PROTOCOL,ok=false,reason="Access"}
    local c
    -- Singleplayer already has the authoritative object from the native menu.
    -- Do not serialize it and re-resolve through a more restrictive MP locator.
    if directTarget and not isClient() and not isServer() then
        if IT.Store.isSupported(directTarget) and IT.Access.canUse(player,directTarget) then c=directTarget end
    else c=IT.Access.resolve(player,a.locator) end
    if c then
        local s=IT.Store.get(c,true)
        local isRead=a.op=="read"
        if not s then reply.reason="BadRequest"
        elseif isRead then reply.ok=true
        elseif not IT.categoriesEnabled() then reply.reason="Disabled"
        elseif a.uid~=s.uid or a.revision~=s.revision then reply.reason="Conflict"
        elseif a.op=="set" and IT.Categories.validKey(a.category) and type(a.enabled)=="boolean" then
            IT.Categories.refreshRegistry()
            -- Accept only a category known to this server (including categories
            -- observed in the exact target). Arbitrary client keys are rejected.
            IT.Categories.keys(c)
            if IT.Categories.known[a.category] then reply.ok=IT.Store.set(c,a.category,a.enabled) else reply.reason="UnknownCategory" end
        elseif a.op=="group" and IT.Categories.groupSet[a.category] and type(a.enabled)=="boolean" then
            reply.ok=IT.Store.setGroup(c,a.category,a.enabled)
        elseif a.op=="all" and type(a.enabled)=="boolean" then reply.ok=IT.Store.setAll(c,a.enabled)
        else reply.reason="BadRequest" end
        IT.Filter.apply(c)
        reply.state=IT.Store.snapshot(c)
        if reply.ok and not isRead then
            local published=pcall(IT.Store.publish,player,c)
            if not published then IT.logOnce("publish", "Native ModData broadcast failed; authoritative rule retained and sent via protocol") end
            if isServer() then sendServerCommand("InventoryTags","changed",{protocol=IT.PROTOCOL,state=reply.state}) end
        end
    end
    cache.map[a.token]=reply;cache.order[#cache.order+1]=a.token
    if #cache.order>128 then local old=table.remove(cache.order,1);cache.map[old]=nil end
    return reply
end
