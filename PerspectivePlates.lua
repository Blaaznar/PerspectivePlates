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
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function PerspectivePlates:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 
	self.nameplateOffsetFactor = 1.92
    self.pF = 78
	
	self.slider1 = 0
	self.slider2 = 0
	self.slider3 = 0
	self.slider4 = 0


    -- initialize variables here

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
	
		Apollo.RegisterSlashCommand("sp", "OnSlashConfig", self)	
		
		--self.wndMain:Invoke()

	end
end

local function PrintObj(obj)
	if obj then
		for k,v in pairs(getmetatable(obj)) do
			Print(k)
		end
	end
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

local nameplateDefaults = nil

function PerspectivePlates:DrawNameplate(luaCaller, tNameplate)
	try(function()
			local unitOwner = tNameplate.unitOwner
			local wnd = tNameplate.wndNameplate

			local distance = self:DistanceToUnit(unitOwner)
            
            if distance > self.pF then distance = self.pF end
            
			local scale = 1 - distance / self.pF -- TODO: do a proper calculation
			
			self.wndMain:SetOpacity(0) -- temporary workarround for jumping nameplates
			
			wnd:SetScale(scale)
			
            if nameplateDefaults == nil then nameplateDefaults = {wnd:GetAnchorOffsets()} end -- todo: read from a more 'reliable' source
            
            local offset = distance * self.nameplateOffsetFactor
            local offsetH = distance * self.nameplateOffsetFactor

            wnd:SetAnchorOffsets(nameplateDefaults[1] + offset, nameplateDefaults[2] + offset/2, nameplateDefaults[3] + offset, nameplateDefaults[4] + offset/2)	
            local nLeft, nTop, nRight, nBottom = wnd:GetAnchorPoints()

			-- debug
			--if unitOwner == GameLib.GetTargetUnit() then 
				--Print(string.format("Scale: %f; Offset: %f; Offsets: %d %d %d %d", scale, offsetW, nLeft, nTop, nRight, nBottom))
				--Print(string.format("scale: %f; distance: %f; sliders: %f %f", scale, distance, self.slider1, self.slider2))
			--end
			
			self.wndMain:SetOpacity(1) -- temporary
			
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
	self.slider1 = fNewValue
    self.nameplateOffsetFactor = fNewValue
end

function PerspectivePlates:Slider2_OnSliderBarChanged( wndHandler, wndControl, fNewValue, fOldValue )
	self.slider2 = fNewValue
end

function PerspectivePlates:Slider3_OnSliderBarChanged( wndHandler, wndControl, fNewValue, fOldValue )
	self.slider3 = fNewValue
end

function PerspectivePlates:Slider4_OnSliderBarChanged( wndHandler, wndControl, fNewValue, fOldValue )
	self.slider4 = fNewValue
end

-----------------------------------------------------------------------------------------------
-- PerspectivePlates Instance
-----------------------------------------------------------------------------------------------
local PerspectivePlatesInst = PerspectivePlates:new()
PerspectivePlatesInst:Init()
