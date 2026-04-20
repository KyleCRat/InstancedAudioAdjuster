local CHANNEL_CVARS = {
    master   = "Sound_MasterVolume",
    music    = "Sound_MusicVolume",
    sfx      = "Sound_SFXVolume",
    ambience = "Sound_AmbienceVolume",
    dialog   = "Sound_DialogVolume",
}

local CHANNEL_LABELS = {
    master   = "Master",
    music    = "Music",
    sfx      = "SFX",
    ambience = "Ambience",
    dialog   = "Dialog",
}

local INSTANCE_TYPE_INFO = {
    none         = { name = "Open World",   description = "Active while exploring the open world, questing, or in capital cities." },
    party        = { name = "Dungeon",      description = "Active inside 5-player dungeons." },
    raid         = { name = "Raid",         description = "Active inside raid instances (Flex: 10-30, Mythic: 20, Classic: 40, 25, 10)." },
    scenario     = { name = "Scenario",     description = "Active during scenarios and solo story instances." },
    arena        = { name = "Arena",        description = "Active during arena matches (2v2, 3v3, solo shuffle)." },
    pvp          = { name = "Battleground", description = "Active inside battlegrounds and epic battlegrounds." },
    interior     = { name = "Interior",     description = "Active in Neighborhood home interiors." },
    neighborhood = { name = "Neighborhood", description = "Active in Neighborhood outdoor areas." },
}

-----------------------------------------------------------
-- Addon Table & Defaults
-----------------------------------------------------------

local ADDON_NAME, IAA = ...
IAA.name = "Instanced Audio Adjuster"
IAA.defaults = {
    verbose = true,
    instanceTypes = {
        none         = { master = 0.35, music = 0.0, sfx = 0.1,  ambience = 0.15, dialog = 0.2 },
        party        = { master = 0.75, music = 0.0, sfx = 0.05, ambience = 0.0,  dialog = 0.2 },
        raid         = { master = 0.75, music = 0.0, sfx = 0.05, ambience = 0.0,  dialog = 0.2 },
        scenario     = { master = 0.75, music = 0.3, sfx = 0.25, ambience = 0.25, dialog = 0.2 },
        arena        = { master = 0.75, music = 0.0, sfx = 0.25, ambience = 0.0,  dialog = 0.25 },
        pvp          = { master = 0.75, music = 0.0, sfx = 0.25, ambience = 0.0,  dialog = 0.25 },
        interior     = { master = 0.35, music = 0.2, sfx = 0.25, ambience = 0.25, dialog = 0.3 },
        neighborhood = { master = 0.35, music = 0.2, sfx = 0.25, ambience = 0.25, dialog = 0.3 },
    },
    order = {
        instanceTypes = { "none", "party", "raid", "scenario", "arena", "pvp", "interior", "neighborhood" },
        channels = { "master", "music", "sfx", "ambience", "dialog" },
    },
}

-----------------------------------------------------------
-- Utility
-----------------------------------------------------------

local function Print(msg)
    print("|c00bf40bf" .. IAA.name .. ":|r " .. msg)
end

local function PrintInfo(msg)
    if not IAA.db.verbose then return end

    Print(msg)
end

-----------------------------------------------------------
-- Audio
-----------------------------------------------------------

local function ApplyAudioConfig(cfg)
    for channel, cvar in pairs(CHANNEL_CVARS) do
        SetCVar(cvar, cfg[channel])
    end
end

local function CheckInstanceType(instanceType)
    local cfg = IAA.db.instanceTypes[instanceType]
    if not cfg then
        PrintInfo("|c00666666Unable to find config for: " .. tostring(instanceType) .. "|r")

        return
    end

    ApplyAudioConfig(cfg)

    PrintInfo("Adjusted audio for instance type: " .. tostring(instanceType))
end

-----------------------------------------------------------
-- DB Initialization
-----------------------------------------------------------

local function SetDefaultsFromCurrentCVars(instanceType)
    IAA.db.instanceTypes[instanceType] = {}

    for channel, cvar in pairs(CHANNEL_CVARS) do
        IAA.db.instanceTypes[instanceType][channel] = GetCVar(cvar)
    end
end

local function InitDB()
    if IAA.db.verbose == nil then
        IAA.db.verbose = IAA.defaults.verbose
    end

    if IAA.db.instanceTypes == nil then
        IAA.db.instanceTypes = {}
        PrintInfo(
            "No previous settings found, this may be the first time IAA has run, "..
            "or the InstancedAudioAdjuster.lua SavedVariable was deleted. "..
            "Your current audio settings will be saved as defaults for all instance types. "
        )
        PrintInfo(
            "Changing your volume sliders in settings will be overwritten by the Addon when changing areas. "..
            "You can make permanent audio adjustments by changing the sliders in IAA options (/iaa). "
        )
    end

    for instanceType, _ in pairs(IAA.defaults.instanceTypes) do
        -- If instanceType config is nil or the first value inside is nil
        if IAA.db.instanceTypes[instanceType] == nil or
            next(IAA.db.instanceTypes[instanceType]) == nil
        then
            SetDefaultsFromCurrentCVars(instanceType)
        end
    end
end

-----------------------------------------------------------
-- Options Panel
-----------------------------------------------------------

local function ApplyOptionChange(cfgInstanceType)
    local _, worldInstanceType = IsInInstance()
    if cfgInstanceType ~= worldInstanceType then return end

    ApplyAudioConfig(IAA.db.instanceTypes[cfgInstanceType])
end

local function CreateAudioSlider(category, instanceType, channel)
    local info         = INSTANCE_TYPE_INFO[instanceType]
    local channelLabel = CHANNEL_LABELS[channel]
    local name         = info.name .. " " .. channelLabel
    local defaultValue = tonumber(IAA.defaults.instanceTypes[instanceType][channel]) or 0
    local variable     = instanceType .. "_" .. channel
    local step         = 0.05
    local tooltip      = "Adjust the " .. channelLabel .. " volume for " .. info.name

    local function GetValue()
        return tonumber(IAA.db.instanceTypes[instanceType][channel])
            or defaultValue
    end

    local function SetValue(value)
        IAA.db.instanceTypes[instanceType][channel] =
            math.floor((value + step / 2) / step) * step

        ApplyOptionChange(instanceType)
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

    local options = Settings.CreateSliderOptions(0, 1, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        return string.format("%d%%", value * 100)
    end)
    Settings.CreateSlider(category, setting, options, tooltip)
end

local function CreateVerboseCheckbox(category)
    local name = "Verbose"
    local variable = "IAA_verbose"
    local defaultValue = true
    local tooltip = "Print to chat when IAA changes your settings."

    local function GetValue()
        return IAA.db.verbose
    end

    local function SetValue(value)
        IAA.db.verbose = value
        Print("turned " .. (IAA.db.verbose and "on" or "off") .. " verbose")
    end

    local setting = Settings.RegisterProxySetting(
        category, variable, type(defaultValue), name, defaultValue, GetValue, SetValue
    )
    Settings.CreateCheckbox(category, setting, tooltip)
end

local function CreateOptionsPanel()
    IAA.category, IAA.layout = Settings.RegisterVerticalLayoutCategory(IAA.name)

    CreateVerboseCheckbox(IAA.category)

    for _, instanceType in ipairs(IAA.defaults.order.instanceTypes) do
        local info = INSTANCE_TYPE_INFO[instanceType]
        local headerInitializer = CreateSettingsListSectionHeaderInitializer(info.name, info.description)
        IAA.layout:AddInitializer(headerInitializer)

        for _, channel in ipairs(IAA.defaults.order.channels) do
            CreateAudioSlider(IAA.category, instanceType, channel)
        end
    end

    Settings.RegisterAddOnCategory(IAA.category)
end

-----------------------------------------------------------
-- Slash Commands
-----------------------------------------------------------

local function OpenSettings()
    Settings.OpenToCategory(IAA.category:GetID())
end

SLASH_IAA1 = "/iaa"
SlashCmdList["IAA"] = function(msg)
    if msg == "v" or msg == "verbose" then
        IAA.db.verbose = not IAA.db.verbose
        Print("turned " .. (IAA.db.verbose and "on" or "off") .. " verbose")

        return
    end

    OpenSettings()
end

-----------------------------------------------------------
-- Event Handling
-----------------------------------------------------------

local lastApplyTime = 0
local frame = CreateFrame("Frame")

local function OnAddonLoaded(_, addon)
    if addon ~= "InstancedAudioAdjuster" then return end

    InstancedAudioAdjusterDB = InstancedAudioAdjusterDB or {}
    IAA.db = InstancedAudioAdjusterDB

    InitDB()
    CreateOptionsPanel()

    frame:UnregisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

    PrintInfo("Type /iaa for options. |c00666666(Turn off these messages by unchecking 'Verbose')|r")
end

local function OnZoneChanged()
    local now = GetTime()
    if now - lastApplyTime < 2 then return end
    lastApplyTime = now

    local _, instanceType = IsInInstance()
    CheckInstanceType(instanceType)
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(_, ...)

        return
    end

    OnZoneChanged()
end)
