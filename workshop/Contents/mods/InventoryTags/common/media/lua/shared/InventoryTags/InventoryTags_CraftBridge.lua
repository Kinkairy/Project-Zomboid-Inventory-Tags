require "InventoryTags/InventoryTags_Packing"
require "Entity/TimedActions/ISHandcraftAction"
local IT=InventoryTags
IT.CraftBridge=IT.CraftBridge or {}
local B=IT.CraftBridge
B.armed=B.armed or setmetatable({},{__mode="k"})
B.receipts=B.receipts or setmetatable({},{__mode="k"})
function B.arm(player,a)
    if type(a)~="table" or type(a.token)~="string" or #a.token>120 or not a.token:match("^[%w:_%-]+$")
        or type(a.recipe)~="string" or #a.recipe>256 or type(a.ids)~="table" or #a.ids<2 or #a.ids>4096
        or not IT.autoOrganizeEnabled() then return false end
    local c=IT.Access.resolve(player,a.locator)
    if not c then return false end
    local seen,count={},0
    for k,id in pairs(a.ids) do
        if not IT.integer(k,1,#a.ids) or not IT.integer(id,0) or seen[id] or not IT.Access.direct(c,id) then return false end
        seen[id]=true;count=count+1
    end
    if count~=#a.ids then return false end
    local current=B.armed[player]
    if current and current.token~=a.token and current.expires>IT.now() then return false end
    B.armed[player]={token=a.token,recipe=a.recipe,signature=IT.Packing.signature(a.ids),target=c,expires=IT.now()+900000}
    return true
end
function B.cancel(player,token)
    local r=B.armed[player]
    if r and r.token==token then B.armed[player]=nil end
end
function B.match(action)
    local mark=action._InventoryTagsReceipt
    if mark and not isClient() and not isServer() then return mark end
    if not isServer() then return nil end
    local r=B.armed[action.character]
    if not r or r.expires<IT.now() or not IT.autoOrganizeEnabled()
        or r.recipe~=IT.Packing.name(action.craftRecipe) or not IT.Packing.allowed(action.craftRecipe)
        or not IT.Access.canUse(action.character,r.target) then return nil end
    local data=action.logic and action.logic:getRecipeData()
    local inputs=data and data:getAllNotKeepInputItems()
    local keep=data and data:getAllKeepInputItems()
    if not inputs or not keep then return nil end
    local keepSet,ids={},{}
    for i=0,keep:size()-1 do keepSet[keep:get(i)]=true end
    for i=0,inputs:size()-1 do if not keepSet[inputs:get(i)] then ids[#ids+1]=IT.id(inputs:get(i)) end end
    if IT.Packing.signature(ids)~=r.signature then return nil end
    B.armed[action.character]=nil
    return r
end
if not B.installed then
    B.installed=true
    local native=ISHandcraftAction.performRecipe
    ISHandcraftAction.performRecipe=function(self,...)
        local mark=B.match(self)
        local result=native(self,...)
        if mark and IT.autoOrganizeEnabled() then
            local ok,rows=pcall(IT.Packing.receipt,self)
            local packet={protocol=IT.PROTOCOL,token=mark.token,ok=ok and #rows>0,outputs=ok and rows or {}}
            if isServer() then
                B.receipts[self.character]={packet=packet,untilTime=IT.now()+30000}
                sendServerCommand(self.character,"InventoryTags","craftReceipt",packet)
            elseif IT.AutoOrganize then IT.AutoOrganize.receipt(packet) end
        end
        return result
    end
end
