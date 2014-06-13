-----------------------------------------------------------------------------------------------
-- Client Lua Script for PerspectivePlates
-- Copyright (c) NCsoft. All rights reserved
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
    self.settings.zoom  = 0.4 

    return o
end

function PerspectivePlates:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
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
	
	self.addonNameplates = Apollo.GetAddon("Nameplates")
	
	Apollo.GetPackage("Gemini:Hook-1.0").tPackage:Embed(self)

  	-- Hooks
	self:RawHook(self.addonNameplates, "OnUnitCreated")
	self:RawHook(self.addonNameplates, "DrawNameplate")
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
		
		self.unitPlayer = GameLib.GetPlayerUnit()
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

	try(function()
			local settings = table.ShallowCopy(self.settings)
			table.ShallowMerge(t, settings)
			
			-- validate user data
			assert(settings.zoom > 0 and settings.zoom <= 2)
			assert(type(settings.perspectiveEnabled ) == "boolean")
			
			self.settings = settings
		end,
		function(e)
		end)
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
	try(function()
			local wnd = self.addonNameplates.arUnit2Nameplate[idUnit].wndNameplate
			local healthHealthLabel = wnd:FindChild("Container:Health:HealthLabel")
			healthHealthLabel:SetOpacity(0.0)
		end,
		function(e)
            Print(tostring(e))
		end)
end

function PerspectivePlates:ShowHealthNumber(idUnit)
	try(function()
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

function PerspectivePlates:NameplatePerspectiveResize(tNameplate)
	try(function()
			local unitOwner = tNameplate.unitOwner
			local wnd = tNameplate.wndNameplate

			if nameplateDefaults == nil then nameplateDefaults = {wnd:GetAnchorOffsets()} end -- todo: read this from a more 'reliable' source
			
            local zoom = self.settings.zoom 
            local cameraDist = 20 -- how to get to this number??
            local nameplateWidth = nameplateDefaults[2] - nameplateDefaults[1]
            local nameplateOffsetFactor = 1.75
            
			local distance = self:DistanceToUnit(unitOwner) + zoom + cameraDist
            
			local scale = zoom * nameplateWidth / distance
			
			self.wndMain:SetOpacity(0) -- temporary workarround for jumping nameplates
			
			wnd:SetScale(scale)
			
            local nameplateOffset = nameplateOffsetFactor * nameplateWidth * (1 - scale)

            wnd:SetAnchorOffsets(nameplateDefaults[1] + nameplateOffset, nameplateDefaults[2] + nameplateOffset/2, nameplateDefaults[3] + nameplateOffset, nameplateDefaults[4] + nameplateOffset/2)
            
			-- debug
			--if unitOwner == GameLib.GetTargetUnit() then 
				--Print(string.format("scale: %f; distance: %f; offset: %f;", scale, distance, nameplateOffset))
			--end
			
			self.wndMain:SetOpacity(1) -- temporary workarround for jumping nameplates
		end,
		function(e)
			Print(tostring(e))
		end)
end

function PerspectivePlates:NameplateRestoreDefaultSize(tNameplate)
	try(function()
			local wnd = tNameplate.wndNameplate
			wnd:SetScale(1)
            wnd:SetAnchorOffsets(nameplateDefaults[1], nameplateDefaults[2], nameplateDefaults[3], nameplateDefaults[4])
		end,
		function(e)
			Print(tostring(e))
		end)
end

function PerspectivePlates:DistanceToUnit(unitOwner)
	local unitPlayer = self.unitPlayer

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
	try(function()
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
