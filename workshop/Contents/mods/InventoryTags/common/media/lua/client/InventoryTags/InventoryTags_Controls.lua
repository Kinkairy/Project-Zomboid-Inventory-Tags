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
if not U.installed then
    U.installed=true
    -- Exactly the StoveSettings/Microwave pattern: native object handler,
    -- altColor=true, native getButtonControl(), native right-side registration.
    -- No custom panel, background, button, font, minimum width or arrange hook.
    for _,name in ipairs({"Auto","Sort","Categories"}) do
        local kind=name
        local class=ISLootWindowObjectControlHandler:derive("InventoryTagsNative"..name)
        function class:new()
            local o=ISLootWindowObjectControlHandler.new(self)
            o.altColor=true
            return o
        end
        function class:shouldBeVisible() return IT.Menu.available(kind,displayed(self)) end
        function class:getControl()
            self.control=self:getButtonControl(IT.text(kind))
            return self.control
        end
        function class:perform() IT.Menu.open(self.playerNum,displayed(self),self.control,kind) end
        function class:handleJoypadContextMenu(context) IT.Menu.all(context,self.playerNum,displayed(self)) end
        U.classes[#U.classes+1]=class
        ISLootWindowContainerControls.AddHandler(class,true)
    end
    -- The personal-inventory strip has a separate native handler class.
    -- Reuse its button creation too; never borrow a loot handler on that side.
    U.inventoryClasses={}
    for _,name in ipairs({"Categories","Sort","Auto"}) do
        local kind=name
        local class=ISInventoryWindowControlHandler:derive("InventoryTagsPersonal"..name)
        function class:new()
            local o=ISInventoryWindowControlHandler.new(self);o.altColor=true;return o
        end
        function class:shouldBeVisible() return IT.Menu.available(kind,displayed(self)) end
        function class:getControl()
            self.control=self:getButtonControl(IT.text(kind));self.control._InventoryTagsOwn=true
            return self.control
        end
        function class:perform() IT.Menu.open(self.playerNum,displayed(self),self.control,kind) end
        function class:handleJoypadContextMenu(context) IT.Menu.all(context,self.playerNum,displayed(self)) end
        U.inventoryClasses[#U.inventoryClasses+1]=class
        ISInventoryWindowContainerControls.AddHandler(class)
    end
    -- The native personal strip has no displayToRight argument. Move only our
    -- three already-created buttons; never move/rebuild the original controls.
    local native=ISInventoryWindowContainerControls.arrange
    ISInventoryWindowContainerControls.arrange=function(self,...)
        local result=native(self,...)
        local page=self.inventoryWindow
        local x=page and page.inventoryPane and page.inventoryPane.width
        if x then
            for i=#U.inventoryClasses,1,-1 do
                local h=self.handlers and self.handlers[U.inventoryClasses[i]]
                local b=h and h.control
                if b and b:isVisible() then x=x-b:getWidth()-5;b:setX(x) end
            end
        end
        return result
    end
end
