require "InventoryTags/InventoryTags_Menu"
require "ISUI/LootWindow/ISLootWindowContainerControls"
require "ISUI/LootWindow/ISLootWindowObjectControlHandler"
require "ISUI/InventoryWindow/ISInventoryWindowContainerControls"
require "ISUI/InventoryWindow/ISInventoryWindowControlHandler"
local IT=InventoryTags
IT.Controls=IT.Controls or {}
local U=IT.Controls
U.classes=U.classes or {}
local function displayed(handler)
    local page=handler.lootWindow or handler.inventoryWindow
    return page and page.inventoryPane and page.inventoryPane.inventory or handler.container
end
local function displayedPane(handler)
    local page=handler.lootWindow or handler.inventoryWindow
    return page and page.inventoryPane
end
if not U.installed then
    U.installed=true
    -- Exactly the StoveSettings/Microwave pattern: native object handler,
    -- altColor=true, native getButtonControl(), native right-side registration.
    -- No custom panel, background, button, font, minimum width or arrange hook.
    for _,name in ipairs({"Auto","Sort","Categories","Select"}) do
        local kind=name
        local class=ISLootWindowObjectControlHandler:derive("InventoryTagsNative"..name)
        function class:new()
            local o=ISLootWindowObjectControlHandler.new(self)
            o.altColor=true
            return o
        end
        function class:shouldBeVisible()
            if kind=="Select" then return IT.Selection.available(displayedPane(self),displayed(self)) end
            return IT.Menu.available(kind,displayed(self))
        end
        function class:getControl()
            self.control=self:getButtonControl(IT.text(kind))
            return self.control
        end
        function class:perform() IT.Menu.open(self.playerNum,displayed(self),self.control,kind,displayedPane(self)) end
        function class:handleJoypadContextMenu(context) IT.Menu.all(context,self.playerNum,displayed(self)) end
        U.classes[#U.classes+1]=class
        ISLootWindowContainerControls.AddHandler(class,true)
    end
    -- The personal-inventory strip has a separate native handler class.
    -- Reuse its button creation too; never borrow a loot handler on that side.
    U.inventoryClasses={}
    for _,name in ipairs({"Select","Categories","Sort","Auto"}) do
        local kind=name
        local class=ISInventoryWindowControlHandler:derive("InventoryTagsPersonal"..name)
        function class:new()
            local o=ISInventoryWindowControlHandler.new(self);o.altColor=true;return o
        end
        function class:shouldBeVisible()
            if kind=="Select" then return IT.Selection.available(displayedPane(self),displayed(self)) end
            return IT.Menu.available(kind,displayed(self))
        end
        function class:getControl()
            self.control=self:getButtonControl(IT.text(kind));self.control._InventoryTagsOwn=true
            return self.control
        end
        function class:perform() IT.Menu.open(self.playerNum,displayed(self),self.control,kind,displayedPane(self)) end
        function class:handleJoypadContextMenu(context) IT.Menu.all(context,self.playerNum,displayed(self)) end
        U.inventoryClasses[#U.inventoryClasses+1]=class
        ISInventoryWindowContainerControls.AddHandler(class)
    end
    -- The native personal strip has no displayToRight argument. Move only our
    -- already-created buttons; never move/rebuild the original controls.
    local native=ISInventoryWindowContainerControls.arrange
    ISInventoryWindowContainerControls.arrange=function(self,...)
        local result=native(self,...)
        local page=self.inventoryWindow
        local x=page and page.inventoryPane and page.inventoryPane.width
        if x then
            -- Preserve native wrapping when four buttons do not fit on one row.
            local rows={}
            for _,b in ipairs(self.controls or {}) do
                local y=b:getY()
                rows[y]=rows[y] or {own={},left=0,width=0}
                local row=rows[y]
                if b._InventoryTagsOwn then
                    row.own[#row.own+1]=b;row.width=row.width+b:getWidth()+5
                else row.left=math.max(row.left,b:getRight()+5) end
            end
            for _,row in pairs(rows) do
                if x-row.width>=row.left then
                    local right=x
                    for i=#row.own,1,-1 do
                        local b=row.own[i];right=right-b:getWidth()-5;b:setX(right)
                    end
                end
            end
        end
        return result
    end
end
