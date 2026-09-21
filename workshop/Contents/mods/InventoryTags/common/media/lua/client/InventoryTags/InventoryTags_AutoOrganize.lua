require "InventoryTags/InventoryTags_Text"
require "InventoryTags/InventoryTags_Network"
require "InventoryTags/InventoryTags_CraftBridge"
require "ISUI/ISInventoryPaneContextMenu"
require "ISUI/ISCraftingUI"
require "Entity/ISEntityUI"
require "TimedActions/ISTimedActionQueue"
require "TimedActions/ISInventoryTransferUtil"
local IT=InventoryTags
IT.AutoOrganize=IT.AutoOrganize or {}
local A=IT.AutoOrganize
A.sessions=A.sessions or {}
function A.idle(player)
    local q=ISTimedActionQueue.getTimedActionQueue(player)
    return not q or not q.queue or #q.queue==0
end
function A.finish(s,reason)
    if not s or A.sessions[s.playerNum]~=s then return end
    s.cancelled=true;A.sessions[s.playerNum]=nil
    if reason and reason~="Complete" and reason~="Cancelled" then
        IT.logOnce("pack:"..tostring(s.token)..":"..reason,"Auto Pack stopped: "..reason)
    end
    local queue=ISTimedActionQueue.getTimedActionQueue(s.player)
    if s.owned and queue and queue.queue then
        local current=queue.current
        local pending={}
        for _,action in ipairs(queue.queue) do
            if s.owned[action] and action~=current then pending[#pending+1]=action end
        end
        for _,action in ipairs(pending) do
            action:forceCancel();queue:removeFromQueue(action)
        end
        if current and s.owned[current] and current:isStarted() then
            -- This is the game's normal cancellation cleanup, not a homemade
            -- rollback. Already-completed item transfers are not reversed.
            pcall(current.forceStop,current)
        end
    end
    if isClient() then sendClientCommand(s.player,"InventoryTags","cancelArm",{protocol=IT.PROTOCOL,token=s.token}) end
    if s.logic and s.action then pcall(s.logic.stopCraftAction,s.logic) end
end
function A.cancel(s)
    if not s or s.cancelled then return end
    A.finish(s,"Cancelled")
end
function A.complete(s)
    if not s or s.cancelled or A.sessions[s.playerNum]~=s then return end
    if s.logic then s.logic:stopCraftAction() end
    s.phase="receipt";s.deadline=IT.now()+15000;s.queryAt=0
end
function A.receipt(packet)
    if type(packet)~="table" or packet.protocol~=IT.PROTOCOL or type(packet.outputs)~="table" then return end
    for _,s in pairs(A.sessions) do
        if s.token==packet.token and not s.cancelled then
            if not packet.ok or #packet.outputs==0 or #packet.outputs>64 then A.finish(s,"Output");return end
            local seen={}
            for _,r in ipairs(packet.outputs) do
                if not IT.integer(r.id,0) or seen[r.id] or type(r.fullType)~="string" then A.finish(s,"Output");return end
                seen[r.id]=true
            end
            s.receipt=packet.outputs
            return
        end
    end
end
local function containers(player,target)
    local out=ArrayList.new();out:add(target)
    local native=ISInventoryPaneContextMenu.getContainers(player)
    for i=0,native:size()-1 do
        local c=native:get(i)
        if c~=target and (c==player:getInventory() or c:isInCharacterInventory(player)) then out:add(c) end
    end
    return out
end
function A.find(player,target)
    local available=containers(player,target)
    local items=target:getItems()
    for i=0,items:size()-1 do
        local item=items:get(i)
        if not item:isFavorite() then
            local recipes=CraftRecipeManager.getUniqueRecipeItems(item,player,available)
            for j=0,(recipes and recipes:size() or 0)-1 do
                local recipe=recipes:get(j)
                if IT.Packing.allowed(recipe) then
                    local logic=HandcraftLogic.new(player,nil,nil)
                    logic:setIsoObject(logic:findCraftSurface(player,2))
                    logic:setContainers(available);logic:setRecipeFromContextClick(recipe,item)
                    if logic:canPerformCurrentRecipe() then
                        local plan=IT.Packing.plan(logic,target,player)
                        if plan and IT.Packing.pin(logic) then
                            local pinned=IT.Packing.plan(logic,target,player)
                            if pinned and IT.Packing.signature(pinned.ids)==IT.Packing.signature(plan.ids) then
                                return {logic=logic,recipe=recipe,item=item,plan=pinned}
                            end
                        end
                    end
                end
            end
        end
    end
end
function A.enqueue(s)
    if s.cancelled or not IT.autoOrganizeEnabled() or not IT.Access.canUse(s.player,s.container) then A.finish(s,"Cancelled");return end
    if not A.idle(s.player) then A.finish(s,"Busy");return end
    local candidate=s.candidate
    -- Revalidate pinned inputs after the server round trip, before taking any.
    if not candidate.logic:canPerformCurrentRecipe() then A.finish(s,"Failed");return end
    local plan=IT.Packing.plan(candidate.logic,s.container,s.player)
    if not plan or IT.Packing.signature(plan.ids)~=IT.Packing.signature(candidate.plan.ids) then A.finish(s,"Failed");return end
    local q=ISTimedActionQueue.getTimedActionQueue(s.player)
    local before={};for _,a in ipairs(q.queue) do before[a]=true end
    s.owned=s.owned or {}
    local action=ISEntityUI.HandcraftStart(s.player,candidate.logic,false,false,0)
    for _,a in ipairs(q.queue) do if not before[a] then s.owned[a]=true end end
    if not action then A.finish(s,"Failed");return end
    local returns={}
    local keep=candidate.logic:getRecipeData():getAllPutBackInputItems()
    if not candidate.recipe:isCanBeDoneFromFloor() then
        for _,item in ipairs(plan.inputs) do
            if item:getContainer()~=s.player:getInventory() then
                if keep:contains(item) then returns[#returns+1]=item end
                ISInventoryPaneContextMenu.transferIfNeeded(s.player,item)
                for _,a in ipairs(q.queue) do if not before[a] then s.owned[a]=true end end
            end
        end
    end
    s.action=action;s.logic=candidate.logic;s.phase="crafting";s.owned[action]=true
    action._InventoryTagsReceipt={token=s.token}
    local nativeValidStart=action.isValidStart
    action.isValidStart=function(self)
        return not s.cancelled and IT.autoOrganizeEnabled()
            and IT.Access.canUse(s.player,s.container) and nativeValidStart(self)
    end
    action:setOnCancel(A.cancel,s)
    action:setOnComplete(A.complete,s)
    s.logic:startCraftAction(action)
    ISTimedActionQueue.add(action)
    ISCraftingUI.ReturnItemsToOriginalContainer(s.player,returns)
    for _,a in ipairs(q.queue) do if not before[a] then s.owned[a]=true end end
end
function A.next(s)
    if s.steps>=IT.MAX_AUTO_ORGANIZE_STEPS then A.finish(s,"Complete");return end
    s.candidate=A.find(s.player,s.container)
    if not s.candidate then A.finish(s,s.steps>0 and "Complete" or "Nothing");return end
    s.steps=s.steps+1;s.token=IT.Network.token(s.playerNum);s.receipt=nil
    if isClient() then
        s.phase="arm";s.deadline=IT.now()+6000
        sendClientCommand(s.player,"InventoryTags","arm",{protocol=IT.PROTOCOL,token=s.token,
            locator=IT.Access.locate(s.player,s.container),recipe=s.candidate.plan.recipe,ids=s.candidate.plan.ids})
    else A.enqueue(s) end
end
function A.returnOutputs(s)
    if not s.receipt then
        if IT.now()>s.deadline then A.finish(s,"Timeout")
        elseif isClient() and IT.now()-s.queryAt>1500 then
            s.queryAt=IT.now()
            sendClientCommand(s.player,"InventoryTags","receiptQuery",{protocol=IT.PROTOCOL,token=s.token})
        end
        return
    end
    local all={}
    local weight=0
    for _,r in ipairs(s.receipt) do
        if r.ground then A.finish(s,"Output");return end
        local item=IT.Access.direct(s.player:getInventory(),r.id)
        if not item then
            if IT.now()>s.deadline then A.finish(s,"Output") end
            return
        end
        if item:getFullType()~=r.fullType or not IT.Filter.allowed(s.container,item) then A.finish(s,"Output");return end
        weight=weight+item:getUnequippedWeight();all[#all+1]=item
    end
    if not s.container:hasRoomFor(s.player,weight) then A.finish(s,"Output");return end
    s.returningIDs={}
    for _,item in ipairs(all) do
        s.returningIDs[#s.returningIDs+1]=item:getID()
        local transfer=ISInventoryTransferUtil.newInventoryTransferAction(s.player,item,item:getContainer(),s.container)
        s.owned=s.owned or {};s.owned[transfer]=true
        ISTimedActionQueue.add(transfer)
    end
    s.phase="returning"
end
function A.tick()
    for _,s in pairs(A.sessions) do
        local ok,err=pcall(function()
            if not IT.autoOrganizeEnabled() or not IT.Store.isSupported(s.container) or not IT.Access.canUse(s.player,s.container) then
                A.finish(s,"Cancelled")
                return
            end
            if s.phase=="arm" then
                if IT.now()>s.deadline then A.finish(s,"Timeout") end
            elseif s.phase=="crafting" then
                if A.idle(s.player) then A.finish(s,"Cancelled") end
            elseif A.idle(s.player) then
                if s.phase=="waiting" then A.next(s)
                elseif s.phase=="receipt" then A.returnOutputs(s)
                elseif s.phase=="returning" then
                    for _,id in ipairs(s.returningIDs) do
                        if not IT.Access.direct(s.container,id) then A.finish(s,"Output");return end
                    end
                    s.action=nil;s.logic=nil;s.candidate=nil;s.phase="waiting"
                    A.next(s)
                end
            end
        end)
        if not ok then IT.logOnce("organize:"..tostring(s.token),tostring(err));A.finish(s,"Failed") end
    end
end
function A.start(playerNum,c)
    if not IT.autoOrganizeEnabled() or not IT.Store.isSupported(c) then return end
    if A.sessions[playerNum] then
        local s=A.sessions[playerNum];A.cancel(s)
        return
    end
    local player=getSpecificPlayer(playerNum)
    if not IT.Access.canUse(player,c) then return end
    if not A.idle(player) then return end
    local s={player=player,playerNum=playerNum,container=c,steps=0,phase="waiting",token=IT.Network.token(playerNum)}
    A.sessions[playerNum]=s
end
local function server(module,cmd,a)
    if module~="InventoryTags" or type(a)~="table" or a.protocol~=IT.PROTOCOL then return end
    if cmd=="craftReceipt" then A.receipt(a)
    elseif cmd=="armReply" then
        for _,s in pairs(A.sessions) do
            if s.token==a.token and s.phase=="arm" then
                if not a.ok then A.finish(s,"Access") else
                    local ok,err=pcall(A.enqueue,s)
                    if not ok then IT.logOnce("enqueue",err);A.finish(s,"Failed") end
                end
                return
            end
        end
    end
end
if not A.installed then
    A.installed=true;IT.addEvent("OnTick",A.tick);IT.addEvent("OnServerCommand",server)
end
