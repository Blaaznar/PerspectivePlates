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
    self.settings.slider1 = 1.25 
    self.settings.slider2 = 0 
    self.settings.slider3 = 0 
    self.settings.slider4 = 0 

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

    self.settings = t
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
	
	try(function()
			local idUnit = unitNew:GetId()
			local wnd = self.addonNameplates.arUnit2Nameplate[idUnit].wndNameplate
			
			-- Hide health numbers (cant see the bloody healthbars from them...)
			local healthHealthLabel = wnd:FindChild("Container:Health:HealthLabel")
			healthHealthLabel:SetOpacity(0.0)
		end,
		function(e)
		end)
end

function PerspectivePlates:DrawNameplate(luaCaller, tNameplate)
	try(function()
			local unitOwner = tNameplate.unitOwner
			local wnd = tNameplate.wndNameplate

            local cameraDist = self.settings.slider1 
            local nameplateWidth = 29.5
            local nameplateOffsetFactor = 147
            
			local distance = self:DistanceToUnit(unitOwner) + cameraDist + 20
            
			local scale = cameraDist * nameplateWidth / distance
			
			self.wndMain:SetOpacity(0) -- temporary workarround for jumping nameplates
			
			wnd:SetScale(scale)
			
            if nameplateDefaults == nil then nameplateDefaults = {wnd:GetAnchorOffsets()} end -- todo: read this from a more 'reliable' source

            local nameplateOffset = nameplateOffsetFactor * (1 - scale)

            wnd:SetAnchorOffsets(nameplateDefaults[1] + nameplateOffset, nameplateDefaults[2] + nameplateOffset/2, nameplateDefaults[3] + nameplateOffset, nameplateDefaults[4] + nameplateOffset/2)
            
			-- debug
			if unitOwner == GameLib.GetTargetUnit() then 
				--Print(string.format("scale: %f; distance: %f; offset: %f; sliders: %f %f %f %f", scale, distance, nameplateOffset, self.settings.slider1, self.settings.slider2, self.settings.slider3, self.settings.slider4))
			end
			
			self.wndMain:SetOpacity(1) -- temporary workarround for jumping nameplates

            -- Pass the call back to the original method
			self.hooks[self.addonNameplates].DrawNameplate(luaCaller, tNameplate)
		end,
		function(e)
			Print(tostring(e))
		end)
end

function PerspectivePlates:DistanceToUnit(unit) -- borrowed from deadlock...
	local uPlayer = GameLib.GetPlayerUnit()
	
	if (unit == nil) then return 0 end 	
	if (uPlayer == nil) then return 0 end 
 
	local posPlayer = uPlayer:GetPosition()  
	
	if unit:GetPosition() == nil then return 0 end
	local posTarget = unit:GetPosition() 
	local nDeltaX = posTarget.x - posPlayer.x
	local nDeltaY = posTarget.y - posPlayer.y
	local nDeltaZ = posTarget.z - posPlayer.z
		
	return math.sqrt(math.pow(nDeltaX, 2) + math.pow(nDeltaY, 2) + math.pow(nDeltaZ, 2))
end 

-----------------------------------------------------------------------------------------------
-- PerspectivePlatesForm Functions
-----------------------------------------------------------------------------------------------
function PerspectivePlates:OnSlashConfig()
    self.wndMain:FindChild("SliderBar1"):SetValue(self.settings.slider1 or 0)
    self.wndMain:FindChild("SliderBar2"):SetValue(self.settings.slider2 or 0)
    self.wndMain:FindChild("SliderBar3"):SetValue(self.settings.slider3 or 0)
    self.wndMain:FindChild("SliderBar4"):SetValue(self.settings.slider4 or 0)

	self.wndMain:Invoke()
end

-- when the OK button is clicked
function PerspectivePlates:OnOK()
	self.wndMain:Close() -- hide the window
end

-- when the Cancel button is clicked
function PerspectivePlates:OnCancel()
	self.wndMain:Close() -- hide the window
end

function PerspectivePlates:Slider1_OnSliderBarChanged( wndHandler, wndControl, fNewValue, fOldValue )
	self.settings.slider1 = fNewValue
end

function PerspectivePlates:Slider2_OnSliderBarChanged( wndHandler, wndControl, fNewValue, fOldValue )
	self.settings.slider2 = fNewValue
end

function PerspectivePlates:Slider3_OnSliderBarChanged( wndHandler, wndControl, fNewValue, fOldValue )
	self.settings.slider3 = fNewValue
end

function PerspectivePlates:Slider4_OnSliderBarChanged( wndHandler, wndControl, fNewValue, fOldValue )
	self.settings.slider4 = fNewValue
end

-----------------------------------------------------------------------------------------------
-- PerspectivePlates Instance
-----------------------------------------------------------------------------------------------
local PerspectivePlatesInst = PerspectivePlates:new()
PerspectivePlatesInst:Init()
