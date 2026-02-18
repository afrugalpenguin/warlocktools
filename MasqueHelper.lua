local WT = WarlockTools

WT.Masque = {}
local MSQ = nil
local groups = {}

function WT.Masque:Init()
    local lib = LibStub and LibStub("Masque", true)
    if lib then
        MSQ = lib
    end
end

function WT.Masque:GetGroup(name)
    if not MSQ then return nil end
    if not groups[name] then
        groups[name] = MSQ:Group("WarlockTools", name)
    end
    return groups[name]
end

function WT.Masque:IsEnabled()
    return MSQ ~= nil
end

function WT.Masque:AddButton(groupName, button, data)
    local group = self:GetGroup(groupName)
    if group then
        group:AddButton(button, data)
    end
end

function WT.Masque:ReSkin(groupName)
    local group = self:GetGroup(groupName)
    if group then
        group:ReSkin()
    end
end
