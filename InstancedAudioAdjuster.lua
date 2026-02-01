
IAA = {}
IAA.name = "Instanced Audio Adjuster"
IAA.loaded = false
IAA.frame = CreateFrame("Frame")
IAA.defaults = {
    verbose = true,
    instanceTypes = {
        -- default  = { master = nil, music = nil, sfx = nil, ambience = nil, dialog = nil },
        party    = { master = nil, music = nil, sfx = nil, ambience = nil, dialog = nil },
        raid     = { master = nil, music = nil, sfx = nil, ambience = nil, dialog = nil },
        scenario = { master = nil, music = nil, sfx = nil, ambience = nil, dialog = nil },
        arena    = { master = nil, music = nil, sfx = nil, ambience = nil, dialog = nil },
        pvp      = { master = nil, music = nil, sfx = nil, ambience = nil, dialog = nil },
        none     = { master = nil, music = nil, sfx = nil, ambience = nil, dialog = nil },
        interior = { master = nil, music = nil, sfx = nil, ambience = nil, dialog = nil },
        neighborhood = { master = nil, music = nil, sfx = nil, ambience = nil, dialog = nil },
    },
    order = {
        instanceTypes = { "none", "party", "raid", "scenario", "arena", "pvp", "interior", "neighborhood" },
        channels = { "master", "music", "sfx", "ambience", "dialog" }
    }
}

-----------------------------------------------------------
-- Applying Audio Changes
-----------------------------------------------------------

function IAA.PrintInfo(msg)
    if InstancedAudioAdjusterDB.verbose then
        print("|c00bf40bf" .. IAA.name .. ":|r " .. msg)
    end
end

function IAA.ApplyAudioConfig(cfg)
    SetCVar("Sound_MasterVolume",   cfg.master)
    SetCVar("Sound_MusicVolume",    cfg.music)
    SetCVar("Sound_SFXVolume",      cfg.sfx)
    SetCVar("Sound_AmbienceVolume", cfg.ambience)
    SetCVar("Sound_DialogVolume",   cfg.dialog)
end

function IAA.CheckInstanceType(worldInstance)
    for instanceType, cfg in pairs(InstancedAudioAdjusterDB.instanceTypes) do
        if instanceType == worldInstance then
            IAA.ApplyAudioConfig(cfg)
            IAA.PrintInfo("Adjusted audio for instance type: " .. tostring(worldInstance))
            return
        end
    end

    IAA.PrintInfo("|c00666666Unable to find config for: " .. tostring(worldInstance) .. "|r")
    -- IAA.ApplyAudioConfig(InstancedAudioAdjusterDB.instanceTypes.default)
end

-----------------------------------------------------------
-- Configuration & Options Panel
-----------------------------------------------------------

function IAA.CreateAudioSlider(category, db, instanceType, channel)
    do
        local name = instanceType .. " " .. channel
        local defaultValue = tonumber(db.instanceTypes[instanceType][channel]) or 0
        local variable = instanceType .. "_" .. channel
        local minValue = 0
        local maxValue = 1
        local step = .05
        local tooltip = "Adjust " .. instanceType .. ":" .. channel

        local function GetValue()
            return tonumber(db.instanceTypes[instanceType][channel]) or defaultValue
        end

        local function SetValue(value)
            db.instanceTypes[instanceType][channel] = math.floor((value + step/2) / step) * step
            IAA.ApplyOptionChange(instanceType)
        end

        local setting = Settings.RegisterProxySetting(
            category,
            variable,
            type(defaultValue),
            name,
            defaultValue,
            GetValue,
            SetValue
        )

        local options = Settings.CreateSliderOptions(minValue, maxValue, step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
            return string.format("%.2f", value)
        end);
        Settings.CreateSlider(category, setting, options, tooltip)
    end
end

function IAA.ApplyOptionChange(cfgInstanceType)
    local _, worldInstanceType = IsInInstance()
    if cfgInstanceType == worldInstanceType then
        -- print('in ' .. worldInstanceType .. ': setting config')
        SetCVar("Sound_MasterVolume",   IAA.db.instanceTypes[cfgInstanceType].master)
        SetCVar("Sound_MusicVolume",    IAA.db.instanceTypes[cfgInstanceType].music)
        SetCVar("Sound_SFXVolume",      IAA.db.instanceTypes[cfgInstanceType].sfx)
        SetCVar("Sound_AmbienceVolume", IAA.db.instanceTypes[cfgInstanceType].ambience)
        SetCVar("Sound_DialogVolume",   IAA.db.instanceTypes[cfgInstanceType].dialog)
    end
end

function IAA:CreateOptionsPanel()
    self.category, self.layout = Settings.RegisterVerticalLayoutCategory(IAA.name);

    do
        local name = "Verbose"
        local variable = "IAA_verbose"
        local defaultValue = IAA.db.verbose or true
        local tooltip = "Print to chat when IAA Changes your settings."

        local function GetValue()
            return IAA.db.verbose or defaultValue
        end

        local function SetValue(value)
            IAA.db.verbose = value
        end

        local setting = Settings.RegisterProxySetting(self.category, variable, type(defaultValue), name, defaultValue, GetValue, SetValue)

        Settings.CreateCheckbox(self.category, setting, tooltip)
    end

    for _, instanceType in ipairs(IAA.defaults.order.instanceTypes) do
        -- Add title
        cfg = IAA.db.instanceTypes[instanceType]
        local name = 'Instance Type: ' .. instanceType
        local tooltip = 'Change the audio settings for ' .. instanceType .. ' '
        local headerInitializer = CreateSettingsListSectionHeaderInitializer(name, tooltip);
        self.layout:AddInitializer(headerInitializer);

        for _, channel in ipairs(IAA.defaults.order.channels) do
            self.CreateAudioSlider(self.category, IAA.db, instanceType, channel)
        end
    end

    Settings.RegisterAddOnCategory(self.category)
end

function IAA:setDefaultsToCurrentCVARS(instanceType)
    IAA.db.instanceTypes[instanceType].master   = GetCVar("Sound_MasterVolume")
    IAA.db.instanceTypes[instanceType].music    = GetCVar("Sound_MusicVolume")
    IAA.db.instanceTypes[instanceType].sfx      = GetCVar("Sound_SFXVolume")
    IAA.db.instanceTypes[instanceType].ambience = GetCVar("Sound_AmbienceVolume")
    IAA.db.instanceTypes[instanceType].dialog   = GetCVar("Sound_DialogVolume")
end

function IAA:InitDB()
    if IAA.db.verbose == nil then
        IAA.db.verbose = IAA.defaults.verbose
    end

    if IAA.db.instanceTypes == nil then
        IAA.db.instanceTypes = {}
        IAA.PrintInfo(
            "No previous settings found, this may be the first time IAA has run, "..
            "or the InstancedAudioAdjuster.lua SavedVariable was deleted. "..
            "Your current audio settings will be saved as defaults for all instance types. "
        )
        IAA.PrintInfo(
            "Changing your volume sliders in settings will be overwritten by the Addon when changing areas. "..
            "You can make permanant audio adjustments by changing the sliders in IAA options (/iaa). "
        )
    end

    for instanceType, _ in pairs(IAA.defaults.instanceTypes) do
        if IAA.db.instanceTypes[instanceType] == nil or next(IAA.db.instanceTypes[instanceType]) == nil then
            IAA.db.instanceTypes[instanceType] = {}
            self:setDefaultsToCurrentCVARS(instanceType)
        end
    end
end

function IAA:Init()
    InstancedAudioAdjusterDB = InstancedAudioAdjusterDB or {}
    IAA.db = InstancedAudioAdjusterDB

    self:InitDB()
    self:CreateOptionsPanel()
end

function IAA:OpenSettings()
    Settings.OpenToCategory(self.category:GetID());
end

SLASH_IAA1 = "/iaa"
SlashCmdList["IAA"] = function(msg)
    IAA:OpenSettings()
end

-----------------------------------------------------------
-- Event Logic
-----------------------------------------------------------

local lastUpdate = 0

function IAA.frame:DoUpdate()
    local now = GetTime()
    if now - lastUpdate < 10 then return end
    lastUpdate = now

    local inInstance, instanceType = IsInInstance()
    IAA.CheckInstanceType(instanceType)
end

IAA.frame:SetScript("OnEvent", function(self, event, addon, ...)
    if event == "ADDON_LOADED" then
        if addon == "InstancedAudioAdjuster" then
            IAA:Init()
            IAA.loaded = true
            IAA.PrintInfo("Type /iaa for options. |c00666666(Turn off these messages by unchecking 'Verbose')|r")
        end

    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if IAA.loaded then
            self:DoUpdate()
        else
            print("IAA not loaded yet, please reload!")
        end
    end
end)

IAA.frame:RegisterEvent("ADDON_LOADED")
IAA.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
IAA.frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
