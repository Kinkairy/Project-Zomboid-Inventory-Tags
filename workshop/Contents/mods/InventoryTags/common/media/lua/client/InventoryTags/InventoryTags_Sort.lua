require "InventoryTags/InventoryTags_Access"
require "InventoryTags/InventoryTags_Arrival"
require "ISUI/ISInventoryPane"
local IT=InventoryTags
IT.Sort=IT.Sort or {}
local S=IT.Sort
S.panes=S.panes or setmetatable({},{__mode="k"})

S.groups={
    {"Default","nativeAsc","nativeDesc","Asc","Desc"},
    {"Quantity","quantityAsc","quantityDesc","Asc","Desc"},
    {"Weight","weightAsc","weightDesc","Asc","Desc"},
    {"Time","timeAsc","timeDesc","Asc","Desc"},
}
S.timeComparators=S.timeComparators or {}
function S.count(row)
    local count,seen=0,{}
    for _,item in ipairs(row and row.items or {}) do
        if IT.isItem(item) and not seen[item] then count=count+1;seen[item]=true end
    end
    return count
end
local function tie(a,b)
    local an,bn=tostring(a.name or ""),tostring(b.name or "")
    if an==bn then return false end
    return ISInventoryPane.itemSortByNameInc(a,b)
end
local function quantity(a,b,ascending)
    if a.equipped~=b.equipped and (a.equipped or b.equipped) then return not a.equipped end
    if a.inHotbar~=b.inHotbar and (a.inHotbar or b.inHotbar) then return a.inHotbar==true end
    local ac,bc=S.count(a),S.count(b)
    if ac==bc then return tie(a,b) end
    if ascending then return ac<bc end
    return ac>bc
end
function S.quantityAsc(a,b) return quantity(a,b,true) end
function S.quantityDesc(a,b) return quantity(a,b,false) end

function S.validMode(mode)
    return mode=="nativeAsc" or mode=="nativeDesc" or mode=="quantityAsc"
        or mode=="quantityDesc" or mode=="weightAsc" or mode=="weightDesc"
        or mode=="timeAsc" or mode=="timeDesc"
end
-- The two directions compare the same chronological key in opposite order.
-- Recorded arrivals use world hours + the per-container receipt sequence.
-- Untimestamped pre-existing contents form a baseline block in native container
-- order. That block is reversed too; it is never mislabeled with a made-up date.
function S.timeCompare(a,b,target,ascending,snapshot)
    snapshot=snapshot or IT.Arrival.snapshot(target)
    local ah,an,ai=IT.Arrival.rowOrder(a,target,snapshot)
    local bh,bn,bi=IT.Arrival.rowOrder(b,target,snapshot)
    local relation
    if (ah~=nil)~=(bh~=nil) then
        relation=ah==nil -- baseline before dated arrivals in ascending order
    elseif ah and ah~=bh then relation=ah<bh
    elseif ah and an~=bn then relation=an<bn
    elseif ai~=bi then relation=ai<bi
    else
        if ascending then return tie(a,b) end
        return tie(b,a)
    end
    if ascending then return relation end
    return not relation
end
function S.comparator(mode,target)
    local map={
        weightAsc=ISInventoryPane.itemSortByWeightAsc,weightDesc=ISInventoryPane.itemSortByWeightDesc,
        quantityAsc=S.quantityAsc,quantityDesc=S.quantityDesc}
    if mode=="timeAsc" or mode=="timeDesc" then
        if not target then return nil end
        local record=S.timeComparators[target]
        if not record then
            record={
                timeAsc=function(a,b) return S.timeCompare(a,b,target,true,S.timeComparators[target].snapshot) end,
                timeDesc=function(a,b) return S.timeCompare(a,b,target,false,S.timeComparators[target].snapshot) end,
            }
            S.timeComparators[target]=record
        end
        return record[mode]
    end
    return map[mode]
end
local function preferences(player)
    local md=player:getModData()
    md.InventoryTagsView=md.InventoryTagsView or {}
    return md.InventoryTagsView
end
function S.get(player,c)
    if not player or not c or not IT.Store.isSupported(c) then return "nativeAsc" end
    local mode=preferences(player)[IT.Access.key(player,c)] or "nativeAsc"
    return S.validMode(mode) and mode or "nativeAsc"
end
function S.set(player,c,mode)
    if not player or not IT.Store.isSupported(c) or not S.validMode(mode) then return false end
    if mode=="nativeAsc" then preferences(player)[IT.Access.key(player,c)]=nil
    else preferences(player)[IT.Access.key(player,c)]=mode end
    for pane in pairs(S.panes) do
        if pane.inventory==c and pane.player==player:getPlayerNum() then
            local state=S.panes[pane];state.force=true
            pane:refreshContainer()
        end
    end
    return true
end
function S.apply(pane)
    if not pane or not pane.inventory then return end
    local player=getSpecificPlayer(pane.player)
    if not player then return end
    local c=pane.inventory
    local state=S.panes[pane]
    if not state then state={};S.panes[pane]=state end
    if state.container~=c then
        if state.active and pane.itemSortFunc==state.injected then pane.itemSortFunc=state.original end
        state.active=false;state.container=c;state.force=false
    elseif state.active and pane.itemSortFunc~=state.injected and not state.force then
        -- Native header clicks or another mod's comparator win; do not fight
        -- them on every refresh. Reset this player's preference only.
        preferences(player)[IT.Access.key(player,c)]=nil
        state.active=false
    end
    local mode=IT.sortingEnabled() and S.get(player,c) or "nativeAsc"
    local cmp=S.comparator(mode,c)
    if mode=="timeAsc" or mode=="timeDesc" then
        S.timeComparators[c].snapshot=IT.Arrival.snapshot(c)
    end
    state.reverse=mode=="nativeDesc"
    if mode=="nativeDesc" then
        cmp=state.active and state.original or pane.itemSortFunc
    end
    if not cmp then
        if state.active and pane.itemSortFunc==state.injected then pane.itemSortFunc=state.original end
        state.active=false;state.force=false;return
    end
    if not state.active then state.original=pane.itemSortFunc;state.active=true end
    state.injected=cmp;pane.itemSortFunc=cmp;state.force=false
end
function S.tick()
    if IT.sortingEnabled() then return end
    for pane,state in pairs(S.panes) do
        if state.active then S.apply(pane);pane:refreshContainer() end
    end
end
if not S.installed then
    S.installed=true
    local native=ISInventoryPane.refreshContainer
    ISInventoryPane.refreshContainer=function(self,...)
        S.apply(self)
        local result=native(self,...)
        local state=S.panes[self]
        if state and state.reverse and self.itemslist then
            local list=self.itemslist
            for i=1,math.floor(#list/2) do
                local j=#list-i+1;list[i],list[j]=list[j],list[i]
            end
        end
        return result
    end
    IT.addEvent("OnTick",S.tick)
end
