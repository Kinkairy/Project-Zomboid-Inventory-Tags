-- Actual mod modules + installed native handcraft Lua; Java/network fixtures are explicit.
local root=(arg and arg[1]) or "."
local native=(arg and arg[2]) or "/home/aiops/private-state/pz-stage-a/server/media/lua/shared/Entity/TimedActions/ISHandcraftAction.lua"
local load=PACK_TEST_LOAD or function(name)
    if name=="native" then return dofile(native) end
    return dofile(root.."/workshop/Contents/mods/InventoryTags/common/media/lua/"..name)
end
local checks=0
local function eq(a,b,label) checks=checks+1;assert(a==b,(label or "")..": expected "..tostring(b)..", got "..tostring(a)) end
local mode="server"
function require()end
function isClient()return mode=="client"end
function isServer()return mode=="server"end
local now=100
function getTimestampMs()return now end
local function list(values)
    local o={values=values or {}}
    function o:size()return #self.values end
    function o:get(i)return self.values[i+1]end
    function o:add(v)self.values[#self.values+1]=v end
    function o:set(i,v)self.values[i+1]=v end
    function o:contains(v)for _,x in ipairs(self.values)do if x==v then return true end end;return false end
    return o
end
ArrayList={new=function()return list()end}
ISBaseTimedAction={}
function ISBaseTimedAction:derive()local c={};setmetatable(c,{__index=self});return c end
function ISBaseTimedAction:perform()end
ISInventoryPage={dirtyUI=function()end}
load("native")
local nativePerform=ISHandcraftAction.performRecipe
load("shared/InventoryTags/InventoryTags_Core.lua")
local IT=InventoryTags
local accessible=true
IT.Access={canUse=function()return accessible end,resolve=function(_,loc)return loc end,
    direct=function(c,id)for _,item in ipairs(c.items)do if item.id==id then return item end end end}
load("shared/InventoryTags/InventoryTags_Packing.lua")
local player,container,inv,packets,logic,recipe,action,q,allowRecipe,wrongInputs
local function item(id,fullType,c)
    local o={id=id,fullType=fullType or "Base.Nails",container=c}
    function o:getID()return self.id end
    function o:getFullType()return self.fullType end
    function o:getContainer()return self.container end
    function o:getWorldItem()return self.ground end
    function o:getUnequippedWeight()return 1 end
    function o:getModData()self.md=self.md or {};return self.md end
    return o
end
function sendServerCommand(_,_,_,packet)packets[#packets+1]=packet end
local clientCommands={}
function sendClientCommand(_,_,cmd,packet)clientCommands[#clientCommands+1]={cmd=cmd,packet=packet}end
Actions={addOrDropItem=function(_,output)output.container=inv;inv.items[#inv.items+1]=output end}
local function reset()
    mode="server";now=100;accessible=true;allowRecipe=true;wrongInputs=false;packets={};clientCommands={}
    container={items={},room=true};function container:hasRoomFor()return self.room end
    inv={items={}};function inv:getItemById(id)return IT.Access.direct(self,id)end
    player={getInventory=function()return inv end,getPlayerNum=function()return 0 end}
    local input={item(101,nil,container),item(102,nil,container)}
    container.items=input
    recipe={getName=function()return "PlaceInBox"end,getCategory=function()return "Packing"end,
        isVanilla=function()return true end,getIOForIndex=function()return {}end}
    local data={populated=false,outputs={},consumed=input}
    function data:getAllNotKeepInputItems()return list(self.populated and (wrongInputs and {item(999),input[2]} or input) or {})end
    function data:getAllKeepInputItems()return list()end
    function data:getAllConsumedItems()return list(input)end
    function data:luaCallOnCreate()end
    function data:processDestroyAndUsedItems()end
    logic={data=data,validations=0,performed=0}
    function logic:setContainers()end
    function logic:setRecipe()end
    function logic:setTargetVariableInputRatio()end
    function logic:setManualSelectInputs()end
    function logic:clearManualInputs()self.data.populated=false end
    function logic:setManualInputsFor()return true end
    function logic:getRecipeData()return self.data end
    function logic:canPerformCurrentRecipe()self.validations=self.validations+1;self.data.populated=true;return allowRecipe end
    function logic:performCurrentRecipe()
        self.performed=self.performed+1
        self.data.populated=true
        if not allowRecipe then return false end
        container.items={}
        self.data.outputs={item(201,"Base.NailsBox")}
        return true
    end
    function logic:getCreatedOutputItems(out)for _,v in ipairs(self.data.outputs)do out:add(v)end end
    function logic:stopCraftAction()end
    HandcraftLogic={new=function()return logic end}
    action=setmetatable({character=player,craftRecipe=recipe,manualInputs={[0]=list(input)},eatPercentage=0},{__index=ISHandcraftAction})
    IT.CraftBridge=nil;ISHandcraftAction.performRecipe=nativePerform
    load("shared/InventoryTags/InventoryTags_CraftBridge.lua")
    q={queue={}}
    ISTimedActionQueue={getTimedActionQueue=function()return q end,add=function(a)q.queue[#q.queue+1]=a end}
    return input
end
local function arm()
    eq(IT.CraftBridge.arm(player,{token="p:1",recipe="PlaceInBox",ids={101,102},locator=container}),true,"arm")
end
local function craftServer()
    action:serverStart()
    eq(logic.data.populated,false,"native serverStart leaves manual cache unpopulated")
    action:complete()
end
-- Exact native serverStart -> complete -> performRecipe reproduces the original missing receipt.
reset();arm();craftServer()
eq(logic.performed,1,"native recipe executes once")
eq(#packets,1,"server sends receipt for actual craft")
eq(packets[1].ok,true,"receipt succeeds")
eq(packets[1].outputs[1].id,201,"receipt names exact native output")
eq(IT.CraftBridge.armed[player],nil,"arm consumed")
eq(IT.CraftBridge.receipts[player].packet,packets[1],"receipt cached for retry")
-- Foreign/expired/cancelled/invalid recipes cannot claim another action's outputs.
reset();arm();wrongInputs=true;craftServer();eq(#packets,0,"wrong inputs")
reset();arm();now=900101;craftServer();eq(#packets,0,"expired arm")
reset();arm();IT.CraftBridge.cancel(player,"p:1");craftServer();eq(#packets,0,"cancelled arm")
reset();arm();allowRecipe=false;craftServer();eq(#packets,0,"native validation failure")
reset();arm();accessible=false;craftServer();eq(#packets,0,"access removed")
reset();craftServer();eq(#packets,0,"unrelated craft");eq(logic.validations,0,"unrelated craft not prevalidated")
reset();arm();recipe.getName=function()return "UnpackBox"end;craftServer();eq(#packets,0,"wrong recipe")
-- Kept tools are excluded from the consumed-input signature.
reset();arm()
local getInputs=logic.data.getAllNotKeepInputItems
local tool=item(301,"Base.Hammer")
function logic.data:getAllNotKeepInputItems()local l=getInputs(self);if self.populated then l:add(tool)end;return l end
function logic.data:getAllKeepInputItems()return list({tool})end
craftServer();eq(#packets,1,"kept tool does not invalidate receipt")
-- Single player still obtains the receipt from its exact marked native action.
reset();mode="single";local received
IT.AutoOrganize={receipt=function(packet)received=packet end}
action._InventoryTagsReceipt={token="single:1"}
action:serverStart();action:performRecipe()
eq(received.ok,true,"single-player receipt");eq(received.outputs[1].id,201,"single-player exact output")
-- Exercise real return/tick/next code with an explicit transfer/network queue.
reset()
IT.AutoOrganize=nil;IT.Store={isSupported=function()return true end}
IT.Filter={allowed=function()return true end}
IT.Network={token=function()return "next:token"end}
ISInventoryTransferUtil={newInventoryTransferAction=function(_,it,source,dest)return {item=it,source=source,dest=dest}end}
load("client/InventoryTags/InventoryTags_AutoOrganize.lua")
local A=IT.AutoOrganize
local function session(token)
    local s={player=player,playerNum=0,container=container,steps=1,token=token or "p:1",phase="crafting",logic=logic,owned={}}
    A.sessions={[0]=s};return s
end
local function drain()
    for _,t in ipairs(q.queue)do
        for i=#t.source.items,1,-1 do if t.source.items[i]==t.item then table.remove(t.source.items,i)end end
        t.item.container=t.dest;t.dest.items[#t.dest.items+1]=t.item
    end
    q.queue={}
end
arm();local s=session();craftServer()
mode="client";A.receipt(packets[1]);A.complete(s)
eq(s.phase,"receipt","craft complete")
A.tick();eq(s.phase,"returning","queues return");eq(#q.queue,1,"one native transfer")
eq(q.queue[1].item.id,201,"return exact output");eq(q.queue[1].dest,container,"return original container")
local scans=0
A.find=function()scans=scans+1;return nil end
drain();A.tick();eq(scans,1,"rescans after return");eq(A.sessions[0],nil,"completes when no remaining recipe")
eq(container.items[1].id,201,"output in container")
-- Delayed receipt: query retry, then return; never take unrelated inventory items.
s=session();s.phase="receipt";s.deadline=now+15000;s.queryAt=-2000
A.tick();eq(clientCommands[#clientCommands].cmd,"receiptQuery","retry missing packet")
local unrelated=item(700,"Base.NailsBox",inv);inv.items={unrelated}
A.receipt({protocol=IT.PROTOCOL,token=s.token,ok=true,outputs={{id=702,fullType="Base.NailsBox",ground=false}}})
A.tick();eq(#q.queue,0,"waits for exact output replication")
inv.items[#inv.items+1]=item(702,"Base.NailsBox",inv)
A.tick();eq(#q.queue,1,"queues delayed exact output");eq(q.queue[1].item.id,702,"unrelated output ignored")
drain();A.tick();eq(inv.items[1],unrelated,"unrelated inventory preserved")
-- Multiple consecutive batches use the next token only after the preceding output returns.
local batchIndex=0
IT.Network.token=function()return "batch:"..tostring(batchIndex+1)end
IT.Access.locate=function()return container end
A.find=function()if batchIndex<3 then return {plan={recipe="PlaceInBox",ids={401,402}}}end end
s=session("batch:1")
for i=1,3 do
    batchIndex=i
    local token=s.token
    s.phase="crafting"
    inv.items={item(800+i,"Base.NailsBox",inv)}
    A.receipt({protocol=IT.PROTOCOL,token=token,ok=true,outputs={{id=800+i,fullType="Base.NailsBox",ground=false}}})
    A.complete(s);A.tick();drain();A.tick()
    if i<3 then
        eq(A.sessions[0],s,"same session continues")
        eq(s.phase,"arm","starts next batch after return")
        eq(s.steps,i+1,"increments batch count")
        eq(s.receipt,nil,"previous receipt cleared")
        A.receipt({protocol=IT.PROTOCOL,token=token,ok=true,outputs={{id=800+i,fullType="Base.NailsBox",ground=false}}})
        eq(s.receipt,nil,"old batch receipt ignored")
    else eq(A.sessions[0],nil,"last batch completes")end
end
eq(IT.Access.direct(container,801).id,801,"batch1 returned")
eq(IT.Access.direct(container,802).id,802,"batch2 returned")
eq(IT.Access.direct(container,803).id,803,"batch3 returned")
-- Actual native single-player completion callbacks feed the same return loop.
reset();mode="single";s=session("single:2")
action._InventoryTagsReceipt={token=s.token}
action:setOnComplete(A.complete,s)
action:serverStart()
action:complete()
action:perform()
eq(s.phase,"receipt","single-player completion enters receipt")
eq(s.receipt[1].id,201,"single-player exact action receipt delivered")
A.find=function()return nil end
A.tick();eq(s.phase,"returning","single-player queues return")
drain();A.tick()
eq(A.sessions[0],nil,"single-player finishes")
eq(IT.Access.direct(container,201).id,201,"single-player output returned")
mode="client"
-- Capacity/filter/ground/cancellation failures stop without inventing or deleting output.
s=session();container.room=false;inv.items={item(901,"Base.NailsBox",inv)}
s.phase="receipt";s.receipt={{id=901,fullType="Base.NailsBox",ground=false}}
A.tick();eq(A.sessions[0],nil,"full container stops");eq(inv.items[1].id,901,"full container preserves output")
container.room=true;s=session();s.phase="receipt";s.receipt={{id=901,fullType="Base.NailsBox",ground=false}}
IT.Filter.allowed=function()return false end
A.tick();eq(A.sessions[0],nil,"category rejection stops");eq(#q.queue,0,"category rejection transfers nothing")
IT.Filter.allowed=function()return true end
s=session();s.phase="receipt";s.receipt={{id=901,fullType="Base.NailsBox",ground=true}}
A.tick();eq(A.sessions[0],nil,"ground output stops safely")
s=session();A.cancel(s);A.receipt({protocol=IT.PROTOCOL,token=s.token,ok=true,outputs={{id=901,fullType="Base.NailsBox"}}})
eq(A.sessions[0],nil,"late receipt cannot resume cancellation")
s=session();s.phase="receipt";s.deadline=now-1;s.queryAt=now;A.tick();eq(A.sessions[0],nil,"missing receipt bounded timeout")
print("PASS: "..checks.." packing lifecycle checks (native Lua, explicit Java/network fixtures)")
return checks
