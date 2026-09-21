require "InventoryTags/InventoryTags_Protocol"
local IT=InventoryTags
IT.Network=IT.Network or {}
local N=IT.Network
N.pending=N.pending or {}
N.confirmed=N.confirmed or setmetatable({},{__mode="k"})
N.observed=N.observed or setmetatable({},{__mode="v"})
N.sequence=N.sequence or 0
function N.token(playerNum)
    N.sequence=N.sequence+1
    return string.format("%.0f:%.0f:%.0f",IT.now(),playerNum,N.sequence)
end
function N.apply(c,state)
    if not IT.Store.receive(c,state) then return false end
    N.observed[state.uid]=c
    IT.Filter.apply(c)
    if IT.Menu then IT.Menu.refreshChecks(c) end
    return true
end
function N.busy(c)
    for _,p in pairs(N.pending) do if p.container==c then return true end end
    return false
end
function N.send(playerNum,c,op,category,on,callback)
    local player=getSpecificPlayer(playerNum)
    if not player or not IT.Store.isSupported(c) or not IT.Access.canUse(player,c) then if callback then callback(false,"Access") end;return false end
    if N.busy(c) then return false end
    local locator=IT.Access.locate(player,c)
    if isClient() and not locator then return false end
    local s=IT.Store.get(c,false)
    local a={protocol=IT.PROTOCOL,token=N.token(playerNum),locator=locator,op=op,category=category,enabled=on,
        uid=s and s.uid,revision=s and s.revision}
    if not isClient() then
        local reply=IT.Protocol.process(player,a,c)
        if callback then callback(reply and reply.ok,reply and reply.reason) end
        return reply and reply.ok or false
    end
    N.pending[a.token]={args=a,player=player,container=c,last=IT.now(),tries=1,callback=callback}
    sendClientCommand(player,"InventoryTags","rules",a)
    return true
end
function N.ensure(playerNum,c)
    if not isClient() then IT.Store.get(c,true);return true end
    local stamp=N.confirmed[c]
    if stamp and IT.now()-stamp<5000 then return true end
    if not N.busy(c) then N.send(playerNum,c,"read") end
    return stamp~=nil
end
function N.onReply(module,command,a)
    if module~="InventoryTags" or type(a)~="table" or a.protocol~=IT.PROTOCOL then return end
    if command=="changed" then
        local c=a.state and N.observed[a.state.uid]
        if c then N.apply(c,a.state) end
        return
    end
    if command~="rulesReply" then return end
    local p=N.pending[a.token]
    if not p then return end
    N.pending[a.token]=nil
    if a.state and N.apply(p.container,a.state) then N.confirmed[p.container]=IT.now() end
    if IT.Menu then IT.Menu.refreshChecks(p.container) end
    if p.callback then p.callback(a.ok==true,a.reason) end
    if ISInventoryPage then ISInventoryPage.dirtyUI() end
end
function N.tick()
    local now=IT.now()
    for token,p in pairs(N.pending) do
        if now-p.last>=1500 then
            if p.tries>=3 or not IT.Access.canUse(p.player,p.container) then
                N.pending[token]=nil
                if IT.Menu then IT.Menu.refreshChecks(p.container) end
                if p.callback then p.callback(false,"Timeout") end
                IT.logOnce("network:"..token,"Rule request timed out; local settings were not committed")
            else
                p.last=now;p.tries=p.tries+1
                sendClientCommand(p.player,"InventoryTags","rules",p.args)
            end
        end
    end
end
if not N.installed then
    N.installed=true
    IT.addEvent("OnServerCommand",N.onReply)
    IT.addEvent("OnTick",N.tick)
end
