require "InventoryTags/InventoryTags_Protocol"
require "InventoryTags/InventoryTags_CraftBridge"
require "InventoryTags/InventoryTags_TransferGate"
local IT=InventoryTags
IT.Server=IT.Server or {}
local S=IT.Server
S.rate=S.rate or setmetatable({},{__mode="k"})
local function command(module,cmd,player,args)
    if module~="InventoryTags" or not player or type(args)~="table" or args.protocol~=IT.PROTOCOL then return end
    if type(args.token)~="string" or #args.token>120 or not args.token:match("^[%w:_%-]+$") then return end
    local now=IT.now();local rate=S.rate[player]
    if not rate or now-rate.at>1000 then rate={at=now,n=0};S.rate[player]=rate end
    rate.n=rate.n+1;if rate.n>30 then return end
    if cmd=="rules" then
        local ok,r=pcall(IT.Protocol.process,player,args)
        if ok and r then sendServerCommand(player,module,"rulesReply",r)
        elseif not ok then IT.logOnce("server-request","Invalid rule request was rejected") end
    elseif cmd=="arm" then
        local ok,result=pcall(IT.CraftBridge.arm,player,args)
        sendServerCommand(player,module,"armReply",{protocol=IT.PROTOCOL,token=args.token,ok=ok and result==true})
    elseif cmd=="cancelArm" then IT.CraftBridge.cancel(player,args.token)
    elseif cmd=="receiptQuery" then
        local cached=IT.CraftBridge.receipts[player]
        if cached and cached.untilTime>now and cached.packet.token==args.token then sendServerCommand(player,module,"craftReceipt",cached.packet) end
    end
end
if not S.installed then S.installed=true;IT.addEvent("OnClientCommand",command) end
