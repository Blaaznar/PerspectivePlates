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
local LuaUtils = Apollo.GetPackage("Blaz:Lib:LuaUtils-0.2").tPackage:new()
 
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
    
    self.fovY = 60
    self.cameraDistanceMax = 32
    
    return o
end

function PerspectivePlates:Init()
	local bHasConfigureFunction = true
	local strConfigureButtonText = "PerspectivePlates"
	local tDependencies = {
        "Blaz:Lib:LuaUtils-0.2",
        "Gemini:Hook-1.0"
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- PerspectivePlates OnLoad
-----------------------------------------------------------------------------------------------
function PerspectivePlates:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("PerspectivePlates.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
	
	Apollo.GetPackage("Gemini:Hook-1.0").tPackage:Embed(self)
    
    Apollo.RegisterEventHandler("GenericEvent_PerspectivePlates_PerspectiveResize", "OnRequestedResize", self)
    Apollo.RegisterEventHandler("GenericEvent_PerspectivePlates_RegisterOffsets", "OnRegisterDefaultBounds", self)
	Apollo.RegisterEventHandler("GenericEvent_PerspectivePlates_SetAnchorOffsets", "OnSetAnchorOffsets", self)
	Apollo.RegisterEventHandler("GenericEvent_PerspectivePlates_GetAnchorOffsets", "OnGetAnchorOffsets", self)

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
        Apollo.CreateTimer("SniffConsoleVarsTimer", 2, true)
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
			local settings = LuaUtils:ShallowCopy(self.settings)
			LuaUtils:ShallowMerge(t, settings)
			
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

function PerspectivePlates:OnConfigure()
    self:OnSlashConfig()
end

function PerspectivePlates:OnSniffConsoleVarsTimer()
        self.fovY = Apollo.GetConsoleVariable("camera.FovY") or 60
        self.cameraDistanceMax = Apollo.GetConsoleVariable("camera.distanceMax") or 32
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

    -- Prepare new nameplates, preventing initial jumping
    local tNameplate = luaCaller.arUnit2Nameplate[idUnit]
    self:NameplatePerspectiveResize(tNameplate, nil)
end

function PerspectivePlates:OnFrame(luaCaller)
    local fnResize = self.NameplatePerspectiveResize
    local arUnit2Nameplate = luaCaller.arUnit2Nameplate
    
    -- This is responsible for default nameplates perspective
	if self.settings.perspectiveEnabled or self.settings.fadingEnabled then
        for idx, tNameplate in pairs(arUnit2Nameplate) do
            if tNameplate.bShow then
                fnResize(self, tNameplate, nil)
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
            self:NameplatePerspectiveResize(tNameplate, nil)
        end
	end
    
    -- Pass the call back to the original method
    self.hooks[self.addonNameplates].UpdateNameplateVisibility(luaCaller, tNameplate)
end

-----------------------------------------------------------------------------------------------
-- Extra tweaks of Carbine Nameplates
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

-----------------------------------------------------------------------------------------------
-- Main resizing logic
-----------------------------------------------------------------------------------------------
function PerspectivePlates:NameplatePerspectiveResize(tNameplate, scaleOffset)
    if not tNameplate or not tNameplate.wndNameplate or not tNameplate.unitOwner then return end
    
    local settings = self.settings
    if not settings.perspectiveEnabled and not settings.fadingEnabled then return end    

    local unitOwner = tNameplate.unitOwner
    local wnd = tNameplate.wndNameplate

    local sensitivity = 0.005 -- the lower the sensitivity, the bigger is the performance hit
    local fovFactor = 60 / self.fovY
    local cameraDistanceFactor = (-5 + self.cameraDistanceMax * 1.5)
    local zoom = 1 + settings.zoom * 0.1
    local deadZone = settings.deadZoneDist
    local focalFactor = fovFactor * cameraDistanceFactor + deadZone
	
    local distance = self:DistanceToUnit(unitOwner) - deadZone
    if distance < 0 then distance = 0 end
    
    local scale = math.floor(zoom * (1 + focalFactor) / (1 + distance + focalFactor) / sensitivity) * sensitivity + (scaleOffset or 0)
	
    if settings.perspectiveEnabled and math.abs(wnd:GetScale() - scale) >= sensitivity then 
		local l, t, r, b = self:GetCacheAnchorOffsets(wnd)
	
        wnd:SetScale(scale)
        
        local offsetH = (r - l) * (1 - scale) / 2
        local offsetV = -(t) * (1 - scale)

        -- this is the most costly operation processing wise
        wnd:SetAnchorOffsets(l + offsetH, t + offsetV, r + offsetH, b + offsetV)
    end 
	
    -- if settings.fadingEnabled and math.abs(wnd:GetOpacity() - scale) >= sensitivity then 
    --     wnd:SetOpacity(scale) -- This is not working correctly anymore...
    -- end 
    
    -- Debug
    --if unitOwner == GameLib.GetTargetUnit() then Print(string.format("focalFactor: %f; scale: %f; distance: %f", focalFactor, scale, distance)) end
end

function PerspectivePlates:GetCacheAnchorOffsets(wnd)
	local l, t, r, b = wnd:GetAnchorPoints()
	if l == 0 and t == 0 and r == 0 and b == 0 then
		l, t, r, b = wnd:GetAnchorOffsets()

		-- I'm storing the unmodified offsets in the window's own points setting (which is otherwise unused for nameplate windows)
		wnd:SetAnchorPoints(l, t, r, b)
	end	
	
	return l, t, r, b
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

function PerspectivePlates:NameplateRestoreDefaults(tNameplate, settings)
	xpcall(function()
			local wnd = tNameplate.wndNameplate
			
			if not settings.perspectiveEnabled then
				wnd:SetScale(1)
	            local l, t, r, b = self:GetCacheAnchorOffsets(wnd)
	            wnd:SetAnchorOffsets(l, t, r, b)
				wnd:SetAnchorPoints(0, 0, 0, 0)
			end
			
			if not settings.fadingEnabled then
				wnd:SetOpacity(1)
			end
		end,
		function(e)
			Print(tostring(e))
		end)
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

    self.model.previousSettings = LuaUtils:ShallowCopy(self.settings)
	self.model.settings = LuaUtils:ShallowCopy(self.settings)
	
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
                        self:NameplatePerspectiveResize(tNameplate, nil)
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
-- Interface for other nameplate addons
-----------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------
-- Applies perspective to a nameplate. Call this before your tNameplate.wndNameplate:Show()
--
-- Required parameter
--   tNameplate: requires tNameplate.unitOwner and tNameplate.wndNameplate to be populated
-- Optional parameters
--   scale:  custom nameplate scale
-----------------------------------------------------------------------------------------------
function PerspectivePlates:OnRequestedResize(tNameplate, scale)
    if self.settings.perspectiveEnabled or self.settings.fadingEnabled then
        self:NameplatePerspectiveResize(tNameplate, (scale or 1) - 1)
    end
end

-----------------------------------------------------------------------------------------------
-- Use this method to modify the anchor offsets as the actual anchor offsets are modified for
-- the perspective effect
-----------------------------------------------------------------------------------------------
function PerspectivePlates:OnSetAnchorOffsets(wnd, left, top, right, bottom)
	if settings.perspectiveEnabled then
		wnd:SetAnchorPoints(left, top, right, bottom)
	else
		wnd:SetAnchorOffsets(left, top, right, bottom)
	end
end

-----------------------------------------------------------------------------------------------
-- Use this method to get the anchor offsets
-----------------------------------------------------------------------------------------------
function PerspectivePlates:OnGetAnchorOffsets(wnd)
	if settings.perspectiveEnabled then
		return self:GetCacheAnchorOffsets(wnd)
	else
		return wnd:GetAnchorOffsets()
	end
end

-----------------------------------------------------------------------------------------------
-- (OBSOLETE) Sets default nameplate dimensions
-----------------------------------------------------------------------------------------------
function PerspectivePlates:OnRegisterDefaultBounds(left, top, right, bottom)
	-- not used anymore
end

-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
-- PerspectivePlates Instance
-----------------------------------------------------------------------------------------------
local PerspectivePlatesInst = PerspectivePlates:new()
PerspectivePlatesInst:Init()
