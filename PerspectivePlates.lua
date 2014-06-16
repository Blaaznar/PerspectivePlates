-----------------------------------------------------------------------------------------------
-- Client Lua Script for PerspectivePlates
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
-- To subscribe your own nameplate addon add this just before showing the nameplate 
-- window in your DrawNameplate function:
-- Event_FireGenericEvent("GenericEvent_PerspectivePlates_PerspectiveResize", tNameplate)
-----------------------------------------------------------------------------------------------
 
require "Window"

-----------------------------------------------------------------------------------------------
-- Packages
-----------------------------------------------------------------------------------------------
local LuaUtils = Apollo.GetPackage("Blaz:Lib:LuaUtils-0.1").tPackage
 
-----------------------------------------------------------------------------------------------
-- PerspectivePlates Module Definition
-----------------------------------------------------------------------------------------------
local PerspectivePlates = {}
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function PerspectivePlates:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 
	
    self.settings = {}
	self.settings.perspectiveEnabled = true
	self.settings.hideHitpoints = true
    self.settings.zoom  = 0.3 

    self.nameplateDefaultBounds = {} -- todo: read from nameplate addon data
    self.nameplateDefaultBounds.left = -150
    self.nameplateDefaultBounds.top = -66
    self.nameplateDefaultBounds.right = 150
    self.nameplateDefaultBounds.bottom =  30
    
    return o
end

function PerspectivePlates:Init()
	local bHasConfigureFunction = true
	local strConfigureButtonText = "PerspectivePlates"
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- PerspectivePlates OnLoad
-----------------------------------------------------------------------------------------------
function PerspectivePlates:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("PerspectivePlates.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
	
	Apollo.GetPackage("Gemini:Hook-1.0").tPackage:Embed(self)
    
    Apollo.RegisterEventHandler("GenericEvent_PerspectivePlates_PerspectiveResize", "OnRequestedResize", self)
    Apollo.RegisterEventHandler("GenericEvent_PerspectivePlates_RegisterOffsets", "OnRegisterDefaultBounds", self)

  	-- Hooks
    self.addonNameplates = Apollo.GetAddon("Nameplates")
    if self.addonNameplates ~= nil then
        self:RawHook(self.addonNameplates, "OnUnitCreated")
        self:RawHook(self.addonNameplates, "DrawNameplate")
    end
end

-----------------------------------------------------------------------------------------------
-- PerspectivePlates OnDocLoaded
-----------------------------------------------------------------------------------------------
function PerspectivePlates:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "PerspectivePlatesForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
	    self.wndMain:Show(false, true)
	
		Apollo.RegisterSlashCommand("pp", "OnSlashConfig", self)
		Apollo.RegisterSlashCommand("perspectiveplates", "OnSlashConfig", self)
		Apollo.RegisterSlashCommand("PerspectivePlates", "OnSlashConfig", self)
	end
end

function PerspectivePlates:OnSave(eType)
    if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then return end
    
    return self.settings
end

function PerspectivePlates:OnRestore(eType, t)
    if eType ~= GameLib.CodeEnumAddonSaveLevel.Account
    or t == nil then
        return 
    end

	xpcall(function()
			local settings = table.ShallowCopy(self.settings)
			table.ShallowMerge(t, settings)
			
			-- validate user data
            assert(type(settings.zoom) == "number")
            assert(type(settings.perspectiveEnabled) == "boolean")
            assert(type(settings.hideHitpoints) == "boolean")
            
			assert(settings.zoom > 0 and settings.zoom <= 2)
			
			self.settings = settings
		end,
		function(e)
		end)
end

-- on Configure button from Addons window
function PerspectivePlates:OnConfigure()
    self:OnSlashConfig()
end

-----------------------------------------------------------------------------------------------
-- PerspectivePlates Functions
-----------------------------------------------------------------------------------------------
function PerspectivePlates:OnUnitCreated(luaCaller, unitNew)
	if not unitNew:ShouldShowNamePlate() 
		or unitNew:GetType() == "Collectible" 
		or unitNew:GetType() == "PinataLoot" then
		-- Never have nameplates
		return
	end

	local idUnit = unitNew:GetId()
	if self.addonNameplates.arUnit2Nameplate[idUnit] ~= nil and self.addonNameplates.arUnit2Nameplate[idUnit].wndNameplate:IsValid() then
		return
	end
	
	self.hooks[self.addonNameplates].OnUnitCreated(luaCaller, unitNew)

	if not self.settings.hideHitpoints then 
		return 
	end	
		
    self:HideHealthNumber(idUnit)
end

function PerspectivePlates:HideHealthNumber(idUnit)
	xpcall(function()
			local wnd = self.addonNameplates.arUnit2Nameplate[idUnit].wndNameplate
			local healthHealthLabel = wnd:FindChild("Container:Health:HealthLabel")
			healthHealthLabel:SetOpacity(0.0)
		end,
		function(e)
            Print(tostring(e))
		end)
end

function PerspectivePlates:ShowHealthNumber(idUnit)
	xpcall(function()
			local wnd = self.addonNameplates.arUnit2Nameplate[idUnit].wndNameplate
			local healthHealthLabel = wnd:FindChild("Container:Health:HealthLabel")
			healthHealthLabel:SetOpacity(1.0)
		end,
		function(e)
            Print(tostring(e))
		end)
end

function PerspectivePlates:DrawNameplate(luaCaller, tNameplate)
	
	if self.settings.perspectiveEnabled then
		self:NameplatePerspectiveResize(tNameplate)
	end
        
    -- Pass the call back to the original method
    self.hooks[self.addonNameplates].DrawNameplate(luaCaller, tNameplate)
end

-- Event handlers for other nameplate addons
function PerspectivePlates:OnRequestedResize(tNameplate, t)
    if self.settings.perspectiveEnabled then
        Print(tostring(t))
        self:NameplatePerspectiveResize(tNameplate)
    end
end

function PerspectivePlates:OnRegisterDefaultBounds(left, top, right, bottom)
    assert(type(left) == "number")
    assert(type(top) == "number")
    assert(type(right) == "number")
    assert(type(bottom) == "number")
    
    self.nameplateDefaultBounds.left = left
    self.nameplateDefaultBounds.top = top
    self.nameplateDefaultBounds.right = right
    self.nameplateDefaultBounds.bottom = bottom
end

function PerspectivePlates:NameplatePerspectiveResize(tNameplate)
	-- xpcall(function() -- has a high performance cost, will use only for debugging
    if tNameplate == nil then return end

    local unitOwner = tNameplate.unitOwner
    local wnd = tNameplate.wndNameplate

    local bounds = self.nameplateDefaultBounds
    
    local sensitivity = 0.01
    local zoom = self.settings.zoom 
    local cameraDist = 20 -- how to get to this number??
    local nameplateWidth = bounds.right - bounds.left -- the nameplate is left-anchored to the unit, I just need it's width
    
    local distance = self:DistanceToUnit(unitOwner) + cameraDist
    
    local scale = math.floor(zoom * 0.2 * nameplateWidth / distance / sensitivity) * sensitivity
    
    -- lower the sensitivity, the bigger is the performance hit
    if math.abs(wnd:GetScale() - scale) < sensitivity then return end 
    
    wnd:SetScale(scale)
    
    local nameplateOffset = nameplateWidth * (1 - scale) / 2

    -- Oddly enough, this is the biggest hit on performance
    wnd:SetAnchorOffsets(bounds.left + nameplateOffset, bounds.top + nameplateOffset/2.5, bounds.right + nameplateOffset, bounds.bottom + nameplateOffset/2.5)

    -- Debug
    --if unitOwner == GameLib.GetTargetUnit() then Print(string.format("scale: %f; distance: %f; offset: %f;", scale, distance, nameplateOffset)) end

    --end, function(e) Print(tostring(e)) end) -- xpcall
end

function PerspectivePlates:NameplateRestoreDefaultSize(tNameplate)
	xpcall(function()
			local wnd = tNameplate.wndNameplate
			wnd:SetScale(1)
            
            local bounds = self.nameplateDefaultBounds
            wnd:SetAnchorOffsets(bounds.left, bounds.top, bounds.right, bounds.bottom)
		end,
		function(e)
			Print(tostring(e))
		end)
end

function PerspectivePlates:DistanceToUnit(unitOwner)
	local unitPlayer = GameLib.GetPlayerUnit()

	if not unitOwner or not unitPlayer then
	    return 0
	end

	tPosTarget = unitOwner:GetPosition()
	tPosPlayer = unitPlayer:GetPosition()

	if tPosTarget == nil then
		return 0
	end
	
	local nDeltaX = tPosTarget.x - tPosPlayer.x
	local nDeltaY = tPosTarget.y - tPosPlayer.y
	local nDeltaZ = tPosTarget.z - tPosPlayer.z

	return math.sqrt((nDeltaX * nDeltaX) + (nDeltaY * nDeltaY) + (nDeltaZ * nDeltaZ))
end

-----------------------------------------------------------------------------------------------
-- PerspectivePlatesForm Functions
-----------------------------------------------------------------------------------------------
function PerspectivePlates:OnSlashConfig()
	self:GenerateModel()	
	self:GenerateView()

	self.wndMain:Invoke()
end

function PerspectivePlates:GenerateModel()
	self.model = {}
	self.model.settings = table.ShallowCopy(self.settings)
end

function PerspectivePlates:GenerateView()
    self.wndMain:FindChild("SbZoom"):SetValue(self.model.settings.zoom or 0)

	self.wndMain:FindChild("ChkHideHitpoints"):SetCheck(self.model.settings.hideHitpoints)
	self.wndMain:FindChild("ChkPerspective"):SetCheck(self.model.settings.perspectiveEnabled)
end

-- when the OK button is clicked
function PerspectivePlates:OnOK()
	xpcall(function()
            if self.addonNameplates ~= nil then
                for idx, tNameplate in pairs(self.addonNameplates.arUnit2Nameplate) do
                    if self.model.settings.hideHitpoints then 
                        self:HideHealthNumber(idx)
                    else
                        self:ShowHealthNumber(idx)
                    end
                    
                    if not self.model.settings.perspectiveEnabled then
                        self:NameplateRestoreDefaultSize(tNameplate)
                    end
                end
            end
				
			self.settings = self.model.settings

			self.wndMain:Close() -- hide the window
		end,
		function(e)
			Print(tostring(e))
		end)
end

-- when the Cancel button is clicked
function PerspectivePlates:OnCancel()
	self.wndMain:Close() -- hide the window
end

function PerspectivePlates:SbZoom_OnSliderBarChanged( wndHandler, wndControl, fNewValue, fOldValue )
	self.model.settings.zoom = fNewValue
	self.settings.zoom = fNewValue
end

function PerspectivePlates:ChkHideHitpoints_OnButtonCheck( wndHandler, wndControl, eMouseButton )
	self.model.settings.hideHitpoints = true
end

function PerspectivePlates:ChkHideHitpoints_OnButtonUnCheck( wndHandler, wndControl, eMouseButton )
	self.model.settings.hideHitpoints = false
end

function PerspectivePlates:ChkPerspective_OnButtonCheck( wndHandler, wndControl, eMouseButton )
	self.model.settings.perspectiveEnabled = true
end

function PerspectivePlates:ChkPerspective_OnButtonUnCheck( wndHandler, wndControl, eMouseButton )
	self.model.settings.perspectiveEnabled = false
end

-----------------------------------------------------------------------------------------------
-- PerspectivePlates Instance
-----------------------------------------------------------------------------------------------
local PerspectivePlatesInst = PerspectivePlates:new()
PerspectivePlatesInst:Init()
