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
	self.settings.fadingEnabled = false
	self.settings.hideHitpoints = true
    self.settings.zoom = 0.0 
	self.settings.deadZoneDist = 10

    self.nameplateDefaultBounds = {} -- todo: read from nameplate addon data
    self.nameplateDefaultBounds.left = -150
    self.nameplateDefaultBounds.top = -93
    self.nameplateDefaultBounds.right = 150
    self.nameplateDefaultBounds.bottom =  30
    
    self.fovY = 60
    self.cameraDistanceMax = 32
    
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
        self:RawHook(self.addonNameplates, "OnFrame")
        --self:RawHook(self.addonNameplates, "UpdateNameplateVisibility")
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
        
        -- Console vars
        self.fovY = Apollo.GetConsoleVariable("camera.FovY") or 60
        self.cameraDistanceMax = Apollo.GetConsoleVariable("camera.distanceMax") or 32
        
        Apollo.RegisterTimerHandler("SniffConsoleVarsTimer", "OnSniffConsoleVarsTimer", self)
        Apollo.CreateTimer("SniffConsoleVarsTimer", 1, true)
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
            
			assert(settings.zoom >= 0 and settings.zoom <= 10)
			assert(self.settings.deadZoneDist >= 5 and self.settings.deadZoneDist <= 30)
			
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
-- Overrides of Carbine Nameplates
-----------------------------------------------------------------------------------------------
function PerspectivePlates:OnUnitCreated(luaCaller, unitNew)
	if unitNew == nil
		or not unitNew:IsValid()
		or not unitNew:ShouldShowNamePlate()
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

	if self.settings.hideHitpoints then 
        self:HideHealthNumber(idUnit)
    end

    -- prepare new nameplates, preventing initial jumping
    local tNameplate = luaCaller.arUnit2Nameplate[idUnit]
    self:NameplatePerspectiveResize(tNameplate, nil, self.nameplateDefaultBounds)
end

function PerspectivePlates:OnFrame(luaCaller)
    local fnResize = self.NameplatePerspectiveResize
    local arUnit2Nameplate = luaCaller.arUnit2Nameplate
    
    -- This is responsible for default nameplates perspective
	if self.settings.perspectiveEnabled or self.settings.fadingEnabled then
        local defaultBounds = self.nameplateDefaultBounds
    
        for idx, tNameplate in pairs(arUnit2Nameplate) do
            if tNameplate.bShow then
                fnResize(self, tNameplate, nil, defaultBounds)
            end
        end
	end
        
    -- Pass the call back to the original method
    self.hooks[self.addonNameplates].OnFrame(luaCaller)
end

function PerspectivePlates:UpdateNameplateVisibility(luaCaller, tNameplate)
	local unitOwner = tNameplate.unitOwner
    local unitPlayer = luaCaller.unitPlayer
    
	if unitOwner ~= nil 
        and unitOwner:GetPosition() ~= nil 
        and unitPlayer ~= nil 
        and unitPlayer:GetPosition() ~= nil 
    then
        -- Prevents 'jumpy nameplates'
        local bNewShow = luaCaller:HelperVerifyVisibilityOptions(tNameplate) and luaCaller:CheckDrawDistance(tNameplate)
        if bNewShow then
            self:NameplatePerspectiveResize(tNameplate, nil, self.nameplateDefaultBounds)
        end
	end
    
    -- Pass the call back to the original method
    self.hooks[self.addonNameplates].UpdateNameplateVisibility(luaCaller, tNameplate)
end

-----------------------------------------------------------------------------------------------
-- PerspectivePlates Functions
-----------------------------------------------------------------------------------------------

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

function PerspectivePlates:OnSniffConsoleVarsTimer()
        self.fovY = Apollo.GetConsoleVariable("camera.FovY") or 60
        self.cameraDistanceMax = Apollo.GetConsoleVariable("camera.distanceMax") or 32
end

-----------------------------------------------------------------------------------------------
-- Event handlers for other nameplate addons
-----------------------------------------------------------------------------------------------
function PerspectivePlates:OnRequestedResize(tNameplate, scale, defaultBounds)
    if self.settings.perspectiveEnabled or self.settings.fadingEnabled then
        self:NameplatePerspectiveResize(tNameplate, (scale or 1) - 1, defaultBounds or self.nameplateDefaultBounds)
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

-----------------------------------------------------------------------------------------------
-- Main resizing logic
-----------------------------------------------------------------------------------------------
function PerspectivePlates:NameplatePerspectiveResize(tNameplate, scaleOffset, defaultBounds)
    if tNameplate == nil then return end
    
    local settings = self.settings
    if not settings.perspectiveEnabled and not settings.fadingEnabled then return end    

    local unitOwner = tNameplate.unitOwner
    local wnd = tNameplate.wndNameplate

    local sensitivity = 0.005
    local fovFactor = 60 / self.fovY
    local zoom = 1 + settings.zoom * 0.1
    
    local distance = self:DistanceToUnit(unitOwner)
    
    -- deadzone
    local deadZone = settings.deadZoneDist
    if distance < deadZone then distance = deadZone end

    local focalFactor = fovFactor * (-5 + self.cameraDistanceMax * 1.5) + deadZone -- needs more tweaking    
    local scaleFactor = zoom * (focalFactor + deadZone)
    
    local scale = math.floor(scaleFactor / (distance + focalFactor) / sensitivity) * sensitivity + (scaleOffset or 0)

    -- lower the sensitivity, the bigger is the performance hit
    if settings.perspectiveEnabled and math.abs(wnd:GetScale() - scale) >= sensitivity then 
        wnd:SetScale(scale)
        
        local bounds = defaultBounds
        local nameplateWidth = bounds.right - bounds.left -- the nameplate is left-anchored to the unit, I just need it's width for setting scale
        local nameplateOffset = nameplateWidth * (1 - scale) * 0.5
        local nameplateOffsetV = -(bounds.top) * (1 - scale)

        -- Oddly enough, this is the biggest hit on performance
        wnd:SetAnchorOffsets(bounds.left + nameplateOffset, bounds.top + nameplateOffsetV, bounds.right + nameplateOffset, bounds.bottom + nameplateOffsetV)
    end 
    
    -- if settings.fadingEnabled and math.abs(wnd:GetOpacity() - scale) >= sensitivity then 
    --     wnd:SetOpacity(scale) -- This is not working correctly anymore...
    -- end 

    -- Debug
    --if unitOwner == GameLib.GetTargetUnit() then Print(string.format("scale: %f; distance: %f", scale, distance)) end
end

function PerspectivePlates:NameplateRestoreDefaults(tNameplate, settings)
	xpcall(function()
			local wnd = tNameplate.wndNameplate
			
			if not settings.perspectiveEnabled then
				wnd:SetScale(1)
	            local bounds = self.nameplateDefaultBounds
	            wnd:SetAnchorOffsets(bounds.left, bounds.top, bounds.right, bounds.bottom)
			end
			
			if not settings.fadingEnabled then
				wnd:SetOpacity(1)
			end
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

    self.model.previousSettings = table.ShallowCopy(self.settings)
	self.model.settings = table.ShallowCopy(self.settings)
	
	self.model.isDefaultNameplates = self.addonNameplates ~= nil
end

function PerspectivePlates:GenerateView()
    self.wndMain:FindChild("SbZoom"):SetValue(self.model.settings.zoom)
	self.wndMain:FindChild("SbDeadZone"):SetValue(self.model.settings.deadZoneDist)

	self.wndMain:FindChild("ChkHideHitpoints"):SetCheck(self.model.settings.hideHitpoints)
	self.wndMain:FindChild("ChkPerspective"):SetCheck(self.model.settings.perspectiveEnabled)
    self.wndMain:FindChild("ChkFadeNameplates"):SetCheck(self.model.settings.fadingEnabled)

	if not self.model.isDefaultNameplates then
		self.wndMain:FindChild("GrpDefaultNameplates"):Enable(false)
		self.wndMain:FindChild("GrpDefaultNameplates"):SetOpacity(0.2)
		self.wndMain:FindChild("LblDefaultNameplates"):SetText("Only for default nameplates")
	end
    
    -- disabled for now
    self.wndMain:FindChild("ChkFadeNameplates"):Enable(false)
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
                    
                    if self.model.settings.perspectiveEnabled or self.model.settings.fadingEnabled then
                        self:NameplatePerspectiveResize(tNameplate, nil, self.nameplateDefaultBounds)
                    end
                    
                    if not self.model.settings.perspectiveEnabled or not self.model.settings.fadingEnabled then
                        self:NameplateRestoreDefaults(tNameplate, self.model.settings)
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
    self.settings = self.model.previousSettings

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

function PerspectivePlates:SbDeadZone_OnSliderBarChanged( wndHandler, wndControl, fNewValue, fOldValue )
	self.model.settings.deadZoneDist = fNewValue
	self.settings.deadZoneDist = fNewValue
end

function PerspectivePlates:ChkFadeNameplates_OnButtonCheck( wndHandler, wndControl, eMouseButton )
	self.model.settings.fadingEnabled = true
end

function PerspectivePlates:ChkFadeNameplates_OnButtonUnCheck( wndHandler, wndControl, eMouseButton )
	self.model.settings.fadingEnabled = false
end

-----------------------------------------------------------------------------------------------
-- PerspectivePlates Instance
-----------------------------------------------------------------------------------------------
local PerspectivePlatesInst = PerspectivePlates:new()
PerspectivePlatesInst:Init()
