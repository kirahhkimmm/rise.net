local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local uiLoader
do
    local localPath = "rise.net/dollarware.lua"
    local loadedLocal = false

    pcall(function()
        if readfile and isfile and isfile(localPath) then
            local localSource = readfile(localPath)
            if localSource and #localSource > 0 then
                uiLoader = loadstring(localSource)
                loadedLocal = uiLoader ~= nil
            end
        end
    end)

    if not loadedLocal then
        uiLoader = loadstring(game:HttpGet('https://raw.githubusercontent.com/kirahhkimmm/rise.net/refs/heads/main/uilib/dollarware.lua'))
    end
end

local ui = uiLoader({
    rounding = false,
    theme = 'frostbite',
    smoothDragging = true
})

ui.autoDisableToggles = true

local window = ui.newWindow({
    text = 'rise.net',
    resize = true,
    size = Vector2.new(650, 500),
    position = nil
})

 
local features = {
    esp = {enabled = false, boxes = true, names = true, health = true, tracers = false, distance = true, rainbow = false, rainbowTracers = false, teamColor = false},
    aimbot = {
        enabled = false, 
        fov = 100, 
        smooth = 0.05, 
        prediction = 0.065,
        target = nil,
        aiming = false,
        wallCheck = true,
        stickyAim = false,
        teamCheck = false,
        healthCheck = false,
        minHealth = 0
        ,
        universal = false
    },
    triggerbot = false,
    rcs = false,
    speed = {enabled = false, multiplier = 2},
    movement = {noclip = false, infiniteJump = false, glide = false, glideFallSpeed = 12, customJump = false, jumpPower = 50},
    fly = {enabled = false, speed = 50, bedwars = false, key = "CapsLock"},
    bhop = false,
    chams = false,
    render = {fullbright = false, customFov = false, cameraFov = 70, crosshair = false, crosshairSize = 10},
    fovCircle = false,
    circleColor = Color3.fromRGB(255, 0, 0),
    targetedColor = Color3.fromRGB(0, 255, 0),
    rainbowFov = false,
    hue = 0,
    rainbowSpeed = 0.002,
    autoclicker = {enabled = false, cps = 12, holding = false},
    killaura = {enabled = false, range = 8, toolCheck = true, teamCheck = false, universal = false, auto = true, orbitEnabled = true, orbitRadius = 3, orbitSpeed = 3},
    pvp = {rcs = false, triggerDelay = 0.01, autoWeapon = false, aimAssist = 0.5, silentAim = false, reach = 8},
    utilities = {antiAfk = false, antiVoid = false, voidY = -50, damageNotify = false, damageThreshold = 1, autoRespawn = false, antiRagdoll = false},
    config = {autoSave = true, autoSaveInterval = 30}
}
features.killaura.cps = 12
features.killaura.partsMode = false
if not features.config then
    features.config = {}
end
if features.config.autoSave == nil then
    features.config.autoSave = true
end
features.config.autoSaveInterval = math.clamp(tonumber(features.config.autoSaveInterval) or 30, 10, 300)

-- friend logic: speed/rubberband bypass + remote scanner + kill settings
local HUB = {
    SPEED = features.speed and features.speed.multiplier or 1.8,
    RANGE = features.killaura and features.killaura.range or 8,
    HIT_CHANCE = 0.78,
    FOV = features.aimbot and features.aimbot.fov or 100,
    AUTO_KICK = true,
    TOGGLE_KEY = Enum.KeyCode.RightShift,
    AUTO_ROUTE = true,
    DEFAULT_PROFILE = "universal",
    ACTIVE_PROFILE = "universal",
    MANUAL_PROFILE = "universal"
}
local PANIC_KEY = Enum.KeyCode.End

local function deepCopy(value)
    if typeof(value) ~= "table" then
        return value
    end

    local copied = {}
    for key, innerValue in pairs(value) do
        copied[key] = deepCopy(innerValue)
    end
    return copied
end

local function deepMerge(target, source)
    if typeof(target) ~= "table" or typeof(source) ~= "table" then
        return target
    end

    for key, value in pairs(source) do
        if typeof(value) == "table" and typeof(target[key]) == "table" then
            deepMerge(target[key], value)
        else
            target[key] = deepCopy(value)
        end
    end

    return target
end

local PROFILE_PRESETS = {
    universal = {
        label = "Universal",
        description = "Safe default profile for most games.",
        autoAim = false,
        autoKillaura = false,
        overrides = {
            aimbot = {universal = false},
            killaura = {auto = false}
        }
    },
    bedwars = {
        label = "BedWars",
        description = "Faster movement and auto-combat defaults for BedWars-like games.",
        autoAim = true,
        autoKillaura = true,
        overrides = {
            aimbot = {fov = 140, prediction = 0.08, universal = true},
            killaura = {range = 12, toolCheck = false, universal = true, auto = true, orbitEnabled = false},
            fly = {bedwars = true, speed = 70},
            speed = {enabled = true, multiplier = 2.5},
            utilities = {antiVoid = true, voidY = -35}
        }
    },
    arena = {
        label = "Arena",
        description = "Close-range arena profile with tighter FOV and stronger assist.",
        autoAim = true,
        autoKillaura = true,
        overrides = {
            aimbot = {fov = 110, prediction = 0.06, universal = true},
            killaura = {range = 9, auto = true, universal = true, orbitEnabled = true},
            speed = {enabled = true, multiplier = 1.9},
            pvp = {aimAssist = 0.65, reach = 10}
        }
    }
}

local PROFILE_ORDER = {"universal", "bedwars", "arena"}

local function findProfileIndex(profileKey)
    for index, key in ipairs(PROFILE_ORDER) do
        if key == profileKey then
            return index
        end
    end
    return 1
end

local PROFILE_ROUTES = {
    place = {
        [6872265039] = "bedwars",
        [139566161526375] = "arena"
    },
    game = {
        -- ["1234567890"] = "bedwars"
    }
}

local autoAimActive = false
local hubProfileStatusLabel = nil
local hubRouteStatusLabel = nil
local ESP
local applyFeaturesToUI

local function refreshHubDerivedValues()
    HUB.SPEED = features.speed and features.speed.multiplier or HUB.SPEED
    HUB.RANGE = features.killaura and features.killaura.range or HUB.RANGE
    HUB.FOV = features.aimbot and features.aimbot.fov or HUB.FOV
end

local function getProfileLabel(profileKey)
    local profile = PROFILE_PRESETS[profileKey]
    return (profile and profile.label) or tostring(profileKey)
end

local function getRoutedProfileKey()
    if not HUB.AUTO_ROUTE then
        return HUB.MANUAL_PROFILE or HUB.ACTIVE_PROFILE or HUB.DEFAULT_PROFILE
    end

    local placeProfile = PROFILE_ROUTES.place[game.PlaceId]
    if placeProfile then
        return placeProfile
    end

    local gameId = tostring(game.GameId)
    local gameProfile = PROFILE_ROUTES.game[gameId]
    if gameProfile then
        return gameProfile
    end

    return HUB.DEFAULT_PROFILE
end

local function updateHubLabels()
    local profileText = "Profile: " .. getProfileLabel(HUB.ACTIVE_PROFILE)
    local routeText = HUB.AUTO_ROUTE and "Route: Auto (Game ID)" or "Route: Manual"

    if hubProfileStatusLabel and hubProfileStatusLabel.setText then
        pcall(function() hubProfileStatusLabel:setText(profileText) end)
    end
    if hubRouteStatusLabel and hubRouteStatusLabel.setText then
        pcall(function() hubRouteStatusLabel:setText(routeText) end)
    end
end

local function applyProfile(profileKey, reason, notifyChange)
    local selectedKey = profileKey or HUB.DEFAULT_PROFILE
    local profile = PROFILE_PRESETS[selectedKey] or PROFILE_PRESETS[HUB.DEFAULT_PROFILE]
    if not profile then
        return
    end

    local overrides = deepCopy(profile.overrides or {})
    deepMerge(features, overrides)

    if profile.autoKillaura ~= nil then
        features.killaura.auto = profile.autoKillaura
    end
    autoAimActive = profile.autoAim == true

    HUB.ACTIVE_PROFILE = selectedKey
    refreshHubDerivedValues()
    updateHubLabels()

    if notifyChange then
        local message = ("%s applied (%s)"):format(getProfileLabel(selectedKey), reason or "manual")
        ui.notify({title = "Hub Profile", message = message, duration = 3})
    end
end

local function routeProfile(notifyChange)
    local profileKey = getRoutedProfileKey()
    applyProfile(profileKey, HUB.AUTO_ROUTE and "auto route" or "manual route", notifyChange)
end

routeProfile(false)

local function findRemote(names)
    for _, name in pairs(names) do
        for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") and obj.Name == name then
                return obj
            end
        end
    end
    return nil
end

local MoveRemote = findRemote({"Move", "Walk", "Position", "UpdatePosition"})
local CombatRemote = findRemote({"Damage", "Swing", "Hit", "Attack", "Combat"})

print("[friend-logic] MoveRemote:", MoveRemote and MoveRemote.Name or "nil", "CombatRemote:", CombatRemote and CombatRemote.Name or "nil")

local hasFolderApi = (typeof(makefolder) == "function") and (typeof(isfolder) == "function")

local ConfigManager = {
    version = 4,
    useFolderStorage = hasFolderApi,
    rootDir = "rise_v4",
    profilesDir = "rise_v4/profiles",
    profilePrefix = "rise_v4_profile_",
    indexFile = hasFolderApi and "rise_v4/index.json" or "rise_v4_index.json",
    stateFile = hasFolderApi and "rise_v4/state.json" or "rise_v4_state.json",
    current = "default",
    autoloadEnabled = true,
    autoloadProfile = "default"
}

local HttpService = game:GetService("HttpService")

local function sanitizeConfigName(name)
    local safe = tostring(name or "default")
    safe = safe:gsub("^%s+", ""):gsub("%s+$", "")
    safe = safe:gsub("%s+", "_")
    safe = safe:gsub("[^%w%-%._]", "")
    if safe == "" then
        safe = "default"
    end
    return safe:sub(1, 48)
end

local function containsValue(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

local function normalizeConfigList(list)
    if typeof(list) ~= "table" then
        return {}
    end

    local normalized = {}
    local seen = {}
    for _, entry in ipairs(list) do
        local name = sanitizeConfigName(entry)
        if not seen[name] then
            seen[name] = true
            table.insert(normalized, name)
        end
    end
    table.sort(normalized)
    return normalized
end

local function encodeConfigValue(value)
    local valueType = typeof(value)
    if valueType == "Color3" then
        return {__type = "Color3", r = value.R, g = value.G, b = value.B}
    end
    if valueType == "table" then
        local out = {}
        for key, inner in pairs(value) do
            local keyType = typeof(key)
            if keyType == "string" or keyType == "number" then
                out[key] = encodeConfigValue(inner)
            end
        end
        return out
    end
    if valueType == "boolean" or valueType == "number" or valueType == "string" or valueType == "nil" then
        return value
    end
    return nil
end

local function decodeConfigValue(value)
    if typeof(value) ~= "table" then
        return value
    end

    if value.__type == "Color3" then
        local r = tonumber(value.r) or 1
        local g = tonumber(value.g) or 1
        local b = tonumber(value.b) or 1
        return Color3.new(math.clamp(r, 0, 1), math.clamp(g, 0, 1), math.clamp(b, 0, 1))
    end

    local out = {}
    for key, inner in pairs(value) do
        if key ~= "__type" then
            out[key] = decodeConfigValue(inner)
        end
    end
    return out
end

local function safeReadJSON(path)
    local ok, res = pcall(function()
        if isfile(path) then
            return HttpService:JSONDecode(readfile(path))
        end
        return nil
    end)
    if ok then return res end
    return nil
end

function ConfigManager:_ensureStorage()
    pcall(function()
        if self.useFolderStorage and makefolder and isfolder then
            if not isfolder(self.rootDir) then
                makefolder(self.rootDir)
            end
            if not isfolder(self.profilesDir) then
                makefolder(self.profilesDir)
            end
        end
    end)
end

function ConfigManager:_profilePath(name)
    local cleaned = sanitizeConfigName(name)
    if self.useFolderStorage then
        return self.profilesDir .. "/" .. cleaned .. ".json"
    end
    return self.profilePrefix .. cleaned .. ".json"
end

function ConfigManager:_writeIndex(list)
    pcall(function()
        writefile(self.indexFile, HttpService:JSONEncode(normalizeConfigList(list)))
    end)
end

function ConfigManager:_saveState()
    pcall(function()
        writefile(self.stateFile, HttpService:JSONEncode({
            version = self.version,
            current = sanitizeConfigName(self.current),
            autoloadEnabled = self.autoloadEnabled == true,
            autoloadProfile = sanitizeConfigName(self.autoloadProfile or self.current)
        }))
    end)
end

function ConfigManager:_loadState()
    local state = safeReadJSON(self.stateFile)
    if typeof(state) ~= "table" then
        return
    end
    self.current = sanitizeConfigName(state.current or self.current)
    self.autoloadEnabled = state.autoloadEnabled ~= false
    self.autoloadProfile = sanitizeConfigName(state.autoloadProfile or self.current)
end

function ConfigManager:list()
    self:_ensureStorage()
    local rawList = safeReadJSON(self.indexFile) or {}
    local combined = normalizeConfigList(rawList)

    if self.useFolderStorage and listfiles and isfolder and isfolder(self.profilesDir) then
        pcall(function()
            for _, fullPath in ipairs(listfiles(self.profilesDir)) do
                local fileName = tostring(fullPath):match("[^/\\]+$") or ""
                local profileName = fileName:match("^(.-)%.json$")
                if profileName then
                    profileName = sanitizeConfigName(profileName)
                    if not containsValue(combined, profileName) then
                        table.insert(combined, profileName)
                    end
                end
            end
        end)
    end

    combined = normalizeConfigList(combined)
    self:_writeIndex(combined)
    return combined
end

function ConfigManager:setCurrent(name, saveState)
    self.current = sanitizeConfigName(name or self.current)
    if saveState ~= false then
        self:_saveState()
    end
end

function ConfigManager:setAutoloadProfile(name, notifyChange)
    local profileName = sanitizeConfigName(name or self.current)
    self.autoloadProfile = profileName
    self:_saveState()
    if notifyChange then
        ui.notify({ title = "Configs", message = ("Autoload profile: %s"):format(profileName), duration = 3 })
    end
end

function ConfigManager:toggleAutoload(state, notifyChange)
    self.autoloadEnabled = state == true
    self:_saveState()
    if notifyChange then
        ui.notify({
            title = "Configs",
            message = self.autoloadEnabled and "Autoload enabled" or "Autoload disabled",
            duration = 3
        })
    end
end

function ConfigManager:save(name, silent)
    self:_ensureStorage()
    local profileName = sanitizeConfigName(name or self.current or "default")
    local payload = {
        version = self.version,
        profileName = profileName,
        savedAt = os.time(),
        placeId = game.PlaceId,
        gameId = tostring(game.GameId),
        features = encodeConfigValue(features)
    }

    local ok, err = pcall(function()
        writefile(self:_profilePath(profileName), HttpService:JSONEncode(payload))
        local index = self:list()
        if not containsValue(index, profileName) then
            table.insert(index, profileName)
        end
        self:_writeIndex(index)
    end)

    if not ok then
        ui.notify({ title = "Config Save Failed", message = tostring(err), duration = 4 })
        return false
    end

    self.current = profileName
    if not self.autoloadProfile or self.autoloadProfile == "" then
        self.autoloadProfile = profileName
    end
    self:_saveState()
    if not silent then
        ui.notify({ title = "Configs", message = ("Saved profile '%s'"):format(profileName), duration = 3 })
    end
    print("[ConfigManager] Saved:", self:_profilePath(profileName))
    return true
end

function ConfigManager:load(name, silent)
    self:_ensureStorage()
    local profileName = sanitizeConfigName(name or self.current or "default")
    local profilePath = self:_profilePath(profileName)
    if not isfile(profilePath) then
        if not silent then
            ui.notify({ title = "Config Load Failed", message = ("Profile '%s' not found"):format(profileName), duration = 3 })
        end
        return false
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(profilePath))
    end)
    if not ok or typeof(data) ~= "table" or typeof(data.features) ~= "table" then
        if not silent then
            ui.notify({ title = "Config Load Failed", message = ("Profile '%s' is invalid"):format(profileName), duration = 3 })
        end
        return false
    end

    local loadedFeatures = decodeConfigValue(data.features)
    if typeof(loadedFeatures) ~= "table" then
        if not silent then
            ui.notify({ title = "Config Load Failed", message = ("Profile '%s' has bad data"):format(profileName), duration = 3 })
        end
        return false
    end

    for key, value in pairs(loadedFeatures) do
        if typeof(features[key]) == typeof(value) then
            if typeof(value) == "table" and typeof(features[key]) == "table" then
                deepMerge(features[key], value)
            else
                features[key] = value
            end
        end
    end

    if not features.config then
        features.config = {}
    end
    if features.config.autoSave == nil then
        features.config.autoSave = true
    end
    features.config.autoSaveInterval = math.clamp(tonumber(features.config.autoSaveInterval) or 30, 10, 300)

    refreshHubDerivedValues()
    updateHubLabels()
    self.current = profileName
    self:_saveState()

    pcall(function()
        if ESP and features.esp then
            if features.esp.enabled ~= nil and ESP.Toggle then
                ESP:Toggle(features.esp.enabled == true)
            end
            if features.esp.boxes ~= nil then ESP.ShowBoxes = features.esp.boxes == true end
            if features.esp.names ~= nil then ESP.ShowNames = features.esp.names == true end
            if features.esp.distance ~= nil then ESP.ShowDistance = features.esp.distance == true end
            if features.esp.health ~= nil then ESP.ShowHealth = features.esp.health == true end
            if features.esp.tracers ~= nil then ESP.ShowTracers = features.esp.tracers == true end
            if features.esp.rainbow ~= nil then ESP.Rainbow = features.esp.rainbow == true end
            if features.esp.rainbowTracers ~= nil then ESP.RainbowTracers = features.esp.rainbowTracers == true end
            if features.esp.teamColor ~= nil then ESP.TeamColor = features.esp.teamColor == true end
        end
    end)

    pcall(function() applyFeaturesToUI() end)
    if not silent then
        ui.notify({ title = "Configs", message = ("Loaded profile '%s'"):format(profileName), duration = 3 })
    end
    print("[ConfigManager] Loaded:", profilePath)
    return true
end

function ConfigManager:delete(name)
    self:_ensureStorage()
    local profileName = sanitizeConfigName(name or self.current)
    if profileName == "" then
        return false
    end

    local ok = pcall(function()
        local path = self:_profilePath(profileName)
        if isfile(path) then
            delfile(path)
        end

        local index = self:list()
        local newIndex = {}
        for _, item in ipairs(index) do
            if item ~= profileName then
                table.insert(newIndex, item)
            end
        end
        self:_writeIndex(newIndex)

        if self.current == profileName then
            self.current = newIndex[1] or "default"
        end
        if self.autoloadProfile == profileName then
            self.autoloadProfile = self.current
        end
        self:_saveState()
    end)

    if not ok then
        ui.notify({ title = "Configs", message = ("Failed deleting '%s'"):format(profileName), duration = 3 })
        return false
    end

    ui.notify({ title = "Configs", message = ("Deleted profile '%s'"):format(profileName), duration = 3 })
    return true
end

function ConfigManager:startupLoad()
    self:_ensureStorage()
    self:_loadState()

    local loaded = false
    if self.autoloadEnabled then
        loaded = self:load(self.autoloadProfile, true)
    end
    if not loaded then
        loaded = self:load(self.current, true)
    end
    if not loaded then
        local names = self:list()
        if #names > 0 then
            loaded = self:load(names[1], true)
        end
    end

    return loaded
end

local clickInterval = 1 / (features.autoclicker.cps or 12)

-- Load profile at startup (Vape-style autoload + current fallback)
spawn(function()
    wait(1)
    ConfigManager:startupLoad()
    if HUB.AUTO_ROUTE then
        routeProfile(false)
    else
        applyProfile(HUB.MANUAL_PROFILE, "startup", false)
    end
    clickInterval = 1 / (features.autoclicker.cps or 12)
end)

-- **ENHANCED FOV CIRCLE** - Now shows REAL FOV visualization
local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Radius = features.aimbot.fov
fovCircle.Color = features.circleColor
fovCircle.Thickness = 3
fovCircle.Transparency = 0.8
fovCircle.Filled = false
fovCircle.NumSides = 64

local currentTarget = nil
local killauraTarget = nil
local killauraAngle = 0

-- NEW: Kill Aura + Auto Clicker Logic
local connections = {}
local lastClick = 0
local killauraLastClick = 0
local vuserCaptured = false
local lastVoidTime = 0
local lastSafePosition = nil
local lastLocalHealth = nil
local baseWalkSpeed = 16
local baseJumpPower = 50
local baseUseJumpPower = true
local lastRespawnAttempt = 0
local antiRagdollApplied = nil
local noclipPartState = {}

local fullbrightBackup = nil
local baseCameraFov = Camera.FieldOfView
local crosshairLines = {
    Drawing.new("Line"),
    Drawing.new("Line"),
    Drawing.new("Line"),
    Drawing.new("Line")
}
for _, line in ipairs(crosshairLines) do
    line.Visible = false
    line.Thickness = 1.5
    line.Color = Color3.fromRGB(255, 255, 255)
    line.Transparency = 1
end

local chamHighlights = {}
local lastChamRefresh = 0

local function clearChams()
    for player, highlight in pairs(chamHighlights) do
        if highlight then
            pcall(function() highlight:Destroy() end)
        end
        chamHighlights[player] = nil
    end
end

local function applyChams()
    if not features.chams then
        clearChams()
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if character and humanoid and humanoid.Health > 0 then
                local highlight = chamHighlights[player]
                if not highlight then
                    highlight = Instance.new("Highlight")
                    highlight.Name = "rise_chams"
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.FillTransparency = 0.65
                    highlight.OutlineTransparency = 0.1
                    chamHighlights[player] = highlight
                end
                highlight.Adornee = character
                highlight.FillColor = Color3.fromRGB(255, 75, 75)
                highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                if highlight.Parent ~= character then
                    highlight.Parent = character
                end
            else
                local stale = chamHighlights[player]
                if stale then
                    pcall(function() stale:Destroy() end)
                    chamHighlights[player] = nil
                end
            end
        end
    end
end

local function setCrosshairVisible(visible)
    for _, line in ipairs(crosshairLines) do
        line.Visible = visible
    end
end

local function applyRenderEnhancements()
    local activeCamera = workspace.CurrentCamera or Camera
    if not activeCamera then
        return
    end

    if features.render and features.render.fullbright then
        if not fullbrightBackup then
            fullbrightBackup = {
                Brightness = Lighting.Brightness,
                ClockTime = Lighting.ClockTime,
                FogEnd = Lighting.FogEnd,
                GlobalShadows = Lighting.GlobalShadows,
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient
            }
        end
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
    elseif fullbrightBackup then
        Lighting.Brightness = fullbrightBackup.Brightness
        Lighting.ClockTime = fullbrightBackup.ClockTime
        Lighting.FogEnd = fullbrightBackup.FogEnd
        Lighting.GlobalShadows = fullbrightBackup.GlobalShadows
        Lighting.Ambient = fullbrightBackup.Ambient
        Lighting.OutdoorAmbient = fullbrightBackup.OutdoorAmbient
        fullbrightBackup = nil
    end

    if features.render and features.render.customFov then
        activeCamera.FieldOfView = math.clamp(features.render.cameraFov or baseCameraFov, 40, 120)
    else
        activeCamera.FieldOfView = baseCameraFov
    end

    if features.render and features.render.crosshair then
        local center = Vector2.new(activeCamera.ViewportSize.X / 2, activeCamera.ViewportSize.Y / 2)
        local size = math.clamp(features.render.crosshairSize or 10, 4, 30)
        local gap = 4
        local color = features.circleColor or Color3.fromRGB(255, 255, 255)

        crosshairLines[1].From = Vector2.new(center.X - gap - size, center.Y)
        crosshairLines[1].To = Vector2.new(center.X - gap, center.Y)
        crosshairLines[2].From = Vector2.new(center.X + gap, center.Y)
        crosshairLines[2].To = Vector2.new(center.X + gap + size, center.Y)
        crosshairLines[3].From = Vector2.new(center.X, center.Y - gap - size)
        crosshairLines[3].To = Vector2.new(center.X, center.Y - gap)
        crosshairLines[4].From = Vector2.new(center.X, center.Y + gap)
        crosshairLines[4].To = Vector2.new(center.X, center.Y + gap + size)

        for _, line in ipairs(crosshairLines) do
            line.Color = color
            line.Visible = true
        end
    else
        setCrosshairVisible(false)
    end

    local now = os.clock()
    if not features.chams or (now - lastChamRefresh) > 0.2 then
        applyChams()
        lastChamRefresh = now
    end
end

local function setNoClip(state)
    if state then
        local character = LocalPlayer.Character
        if not character then
            return
        end

        for _, object in ipairs(character:GetDescendants()) do
            if object:IsA("BasePart") then
                if noclipPartState[object] == nil then
                    noclipPartState[object] = object.CanCollide
                end
                object.CanCollide = false
            end
        end
    else
        for part, oldCanCollide in pairs(noclipPartState) do
            if part and part.Parent then
                part.CanCollide = oldCanCollide
            end
            noclipPartState[part] = nil
        end
    end
end

local function applyUtilityEnhancements()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        antiRagdollApplied = nil
        return
    end

    local antiRagdollDesired = features.utilities and features.utilities.antiRagdoll
    if antiRagdollDesired ~= antiRagdollApplied then
        antiRagdollApplied = antiRagdollDesired
        pcall(function()
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not antiRagdollDesired)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not antiRagdollDesired)
        end)
    end

    if features.utilities and features.utilities.autoRespawn and humanoid.Health <= 0 then
        local now = os.clock()
        if now - lastRespawnAttempt > 2 then
            lastRespawnAttempt = now
            pcall(function()
                LocalPlayer:LoadCharacter()
            end)
        end
    end
end

local function captureBaseWalkSpeed(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.WalkSpeed > 0 then
        baseWalkSpeed = humanoid.WalkSpeed
        baseJumpPower = humanoid.JumpPower
        baseUseJumpPower = humanoid.UseJumpPower
    end
end

local function applyMovementEnhancements()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    local baseline = (baseWalkSpeed > 0 and baseWalkSpeed) or 16
    if features.speed and features.speed.enabled then
        local multiplier = math.clamp(features.speed.multiplier or 1, 1, 10)
        local targetSpeed = math.clamp(baseline * multiplier, baseline, 200)
        if math.abs(humanoid.WalkSpeed - targetSpeed) > 0.05 then
            humanoid.WalkSpeed = targetSpeed
        end
    else
        if math.abs(humanoid.WalkSpeed - baseline) > 0.05 then
            humanoid.WalkSpeed = baseline
        end
    end

    local movementSettings = features.movement or {}
    if movementSettings.customJump then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = math.clamp(movementSettings.jumpPower or baseJumpPower, 25, 200)
    else
        humanoid.UseJumpPower = baseUseJumpPower
        if baseUseJumpPower then
            humanoid.JumpPower = baseJumpPower
        end
    end

    if movementSettings.noclip then
        setNoClip(true)
    elseif next(noclipPartState) ~= nil then
        setNoClip(false)
    end

    if movementSettings.glide then
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local maxFall = math.max(movementSettings.glideFallSpeed or 12, 2)
            local velocity = hrp.AssemblyLinearVelocity
            if velocity.Y < -maxFall then
                hrp.AssemblyLinearVelocity = Vector3.new(velocity.X, -maxFall, velocity.Z)
            end
        end
    end

    if features.bhop and humanoid.Health > 0 and humanoid.FloorMaterial ~= Enum.Material.Air then
        humanoid.Jump = true
    end

    applyUtilityEnhancements()
end

-- **VAPE V4 FLY** - Replace the entire Bedwars fly section with this:
local flyActive = false
local flyBV = nil
local flyOwnershipConnection = nil
local flyVelocityConnection = nil
local flyPositionSpoofConnection = nil
local lastFlyPosition = nil
local networkOwnershipSpamInterval = 0.1
local ownershipSpamCounter = 0

local function setNetworkOwnership(part)
    if part and part.Parent then
        pcall(function()
            part:SetNetworkOwner(LocalPlayer)
        end)
    end
end

local function enableVapeV4Fly()
    if flyActive then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local hrp = char:FindFirstChild('HumanoidRootPart')
    local hum = char:FindFirstChildOfClass('Humanoid')
    if not hrp or not hum then return end

    -- **1. NETWORK OWNERSHIP SPAM** 🔥
    flyOwnershipConnection = RunService.Heartbeat:Connect(function()
        ownershipSpamCounter = ownershipSpamCounter + 1
        if ownershipSpamCounter % math.floor(networkOwnershipSpamInterval * 60) == 0 then
            setNetworkOwnership(hrp)
            for _, part in pairs(char:GetChildren()) do
                if part:IsA("BasePart") and part ~= hrp then
                    setNetworkOwnership(part)
                end
            end
        end
    end)

    -- **2. ENHANCED BODYVELOCITY** ⚡
    if flyBV then flyBV:Destroy() end
    flyBV = Instance.new('BodyVelocity')
    flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    flyBV.P = 15000
    flyBV.Velocity = Vector3.new(0, 0, 0)
    flyBV.Parent = hrp

    -- **3. VAPE-STYLE MOVEMENT** 🎮
    local flyBackoff = 1 -- local multiplier to avoid mutating global UI speed
    flyVelocityConnection = RunService.Heartbeat:Connect(function()
        if not flyActive or not flyBV or not hrp.Parent then return end
        
        local cam = workspace.CurrentCamera
        local moveVector = Vector3.new(0, 0, 0)
        local flySpeed = (features.fly and features.fly.speed or 50) * flyBackoff
        
        local forward = cam.CFrame.LookVector
        local right = cam.CFrame.RightVector
        local up = cam.CFrame.UpVector
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector = moveVector + forward end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector = moveVector - forward end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector = moveVector - right end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector = moveVector + right end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVector = moveVector + up end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveVector = moveVector - up end
        
        if moveVector.Magnitude > 0 then
            flyBV.Velocity = moveVector.Unit * flySpeed
        else
            flyBV.Velocity = Vector3.new(0, 0, 0)
        end
        
        -- **ANTI-GRAVITY** (prevents falling)
        flyBV.Velocity = flyBV.Velocity + Vector3.new(0, 2, 0)

        -- attempt to notify MoveRemote for rubberband bypass / server sync (best-effort)
        pcall(function()
            if MoveRemote and hrp and hrp.Position then
                MoveRemote:FireServer(hrp.Position + (flyBV.Velocity * 0.033), flyBV.Velocity, HUB.SPEED or 16)
            end
        end)
    end)

    -- **4. PACKET SPOOFING**
    flyPositionSpoofConnection = RunService.Stepped:Connect(function()
        if not flyActive or not hrp.Parent then return end
        
        local currentPos = hrp.Position
        lastFlyPosition = lastFlyPosition or currentPos
        local spoofOffset = (currentPos - lastFlyPosition) * 0.95
        local spoofedPos = currentPos + spoofOffset
        
        hrp.CFrame = hrp.CFrame:Lerp(CFrame.new(spoofedPos, spoofedPos + workspace.CurrentCamera.CFrame.LookVector), 0.1)
        lastFlyPosition = currentPos
    end)

    -- rubberband detection with improved soft-backoff and server-sync
    spawn(function()
        local rubberCount = 0
        local flyLastPos = hrp and hrp.Position or Vector3.new()
        local enabledAt = os.clock()
        local deltaSamples = {}
        while flyActive and hrp and hrp.Parent do
            local nowPos = hrp.Position
            local deltaVec = nowPos - flyLastPos
            local delta = deltaVec.Magnitude
            local deltaY = math.abs(deltaVec.Y)

            -- ignore immediate spikes right after enabling fly
            if os.clock() - enabledAt > 1.5 then
                local spaceHeld = UserInputService:IsKeyDown(Enum.KeyCode.Space)
                -- lower thresholds when moving straight up to detect rubberband reliably
                local magThreshold = spaceHeld and 4 or 8
                local vertThreshold = spaceHeld and 3 or 10

                -- rolling window to avoid false positives
                table.insert(deltaSamples, delta)
                if #deltaSamples > 6 then table.remove(deltaSamples, 1) end
                local avg = 0
                for _,v in ipairs(deltaSamples) do avg = avg + v end
                avg = #deltaSamples > 0 and (avg / #deltaSamples) or 0

                if delta > magThreshold or deltaY > vertThreshold or avg > (magThreshold * 0.9) then
                    rubberCount = rubberCount + 1
                else
                    rubberCount = math.max(rubberCount - 0.35, 0)
                end

                if HUB.AUTO_KICK and rubberCount >= 3 then
                    pcall(function() ui.notify({ title = 'Rise', message = 'Rubberband detected — soft backoff', duration = 2 }) end)
                    local originalSpeed = features.fly and features.fly.speed or 50
                    local safeFactor = 0.5
                    flyBackoff = safeFactor

                    -- aggressively set network ownership for all body parts to regain authority
                    pcall(function()
                        for _, part in pairs(char:GetChildren()) do
                            if part:IsA('BasePart') then
                                pcall(function() setNetworkOwnership(part) end)
                            end
                        end
                    end)

                    -- send multiple interpolated MoveRemote pings to help server reconcile position
                    if MoveRemote then
                        local basePos = hrp.Position
                        for i = 0, 4 do
                            pcall(function()
                                local t = i / 4
                                local interp = basePos:Lerp(basePos + Vector3.new(0, 0.5, 0), t)
                                MoveRemote:FireServer(interp, Vector3.new(0,0,0), originalSpeed * flyBackoff)
                            end)
                            wait(0.05)
                        end
                    end

                    -- smooth ease-out restore (shorter, more gradual)
                    local restoreTime = 0.6
                    local steps = 12
                    for s = 1, steps do
                        local t = s / steps
                        local eased = 1 - (1 - t) * (1 - t) -- ease-out quadratic
                        flyBackoff = safeFactor + (1 - safeFactor) * eased
                        wait(restoreTime / steps)
                    end
                    flyBackoff = 1
                    rubberCount = 0
                    deltaSamples = {}
                    lastFlyPosition = hrp.Position
                end
            end

            flyLastPos = nowPos
            wait(0.08)
        end
    end)

    flyActive = true
    pcall(function() 
        ui.notify({ title = 'Rise', message = 'Fly Activated', duration = 4 }) 
    end)
end

local function disableVapeV4Fly()
    if flyOwnershipConnection then flyOwnershipConnection:Disconnect() flyOwnershipConnection = nil end
    if flyVelocityConnection then flyVelocityConnection:Disconnect() flyVelocityConnection = nil end
    if flyPositionSpoofConnection then flyPositionSpoofConnection:Disconnect() flyPositionSpoofConnection = nil end
    
    if flyBV then flyBV:Destroy() flyBV = nil end
    
    flyActive = false
    ownershipSpamCounter = 0
    lastFlyPosition = nil
    
    pcall(function() 
        ui.notify({ title = 'Rise', message = 'Fly Deactivated', duration = 3 }) 
    end)
end

-- **UPDATE FUNCTION REFERENCES** (add these 2 lines right after disableVapeV4Fly):
enableBedwarsFly = enableVapeV4Fly
disableBedwarsFly = disableVapeV4Fly

local function hasTool()
    local char = LocalPlayer.Character
    if not char then return false end
    local tool = char:FindFirstChildOfClass("Tool")
    return tool ~= nil
end

local function getClosestEnemy(range)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    
    local closest, closestDist = nil, range
    local myPos = char.HumanoidRootPart.Position
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") then
            local ignoreTeammate = false
            if features.killaura.teamCheck then
                local bothHaveTeams = (player.Team ~= nil) and (LocalPlayer.Team ~= nil)
                if bothHaveTeams and player.Team == LocalPlayer.Team then
                    ignoreTeammate = true
                end
            end
            if not ignoreTeammate then
                local dist = (player.Character.HumanoidRootPart.Position - myPos).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest = player
                end
            end
        end
    end
    return closest
end

local function attackPlayer(player)
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    -- prefer firing discovered CombatRemote with humanized hit chance
    if CombatRemote and player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        if math.random() < (HUB.HIT_CHANCE or 0.78) then
            pcall(function()
                CombatRemote:FireServer(player.Character and player.Character:FindFirstChild("HumanoidRootPart"), 40, char and char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.Position)
            end)
            return
        end
    end
    -- Respect PvP reach setting: don't attempt attack if target is out of reach
    pcall(function()
        if player and player.Character and char and char:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (player.Character.HumanoidRootPart.Position - char.HumanoidRootPart.Position).Magnitude
            if features.pvp and features.pvp.reach and dist > (features.pvp.reach or 8) then
                return
            end
        end
    end)

    if tool then
        pcall(function()
            local remote = tool:FindFirstChildWhichIsA("RemoteEvent", true) or ReplicatedStorage:FindFirstChildWhichIsA("RemoteEvent", true) or ReplicatedStorage:FindFirstChild("Combat", true)
            if remote and remote:IsA("RemoteEvent") then
                remote:FireServer(player.Character and player.Character:FindFirstChild("Humanoid"))
                return
            end
        end)

        pcall(function()
            tool:Activate()
        end)
    else
        -- No tool: try firing common remotes or simulate click via VirtualUser
        pcall(function()
            local remote = ReplicatedStorage:FindFirstChildWhichIsA("RemoteEvent", true) or ReplicatedStorage:FindFirstChild("Combat", true)
            if remote and remote:IsA("RemoteEvent") then
                remote:FireServer(player.Character and player.Character:FindFirstChild("Humanoid"))
            else
                VirtualUser:CaptureController()
                VirtualUser:Button1Down(Vector2.new(0,0))
                VirtualUser:Button1Up(Vector2.new(0,0))
            end
        end)
    end
end

-- Aimbot Helper Functions (unchanged)
local function checkTeam(player)
    if features.aimbot.teamCheck and player.Team == LocalPlayer.Team then
        return true
    end
    return false
end

local function checkWall(targetCharacter)
    local targetHead = targetCharacter:FindFirstChild("Head")
    if not targetHead then return true end

    local origin = Camera.CFrame.Position
    local direction = (targetHead.Position - origin).unit * (targetHead.Position - origin).magnitude
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, targetCharacter}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

    local raycastResult = workspace:Raycast(origin, direction, raycastParams)
    return raycastResult and raycastResult.Instance ~= nil
end

local function getTarget()
    local nearestPlayer = nil
    local shortestCursorDistance = features.aimbot.fov
    local shortestPlayerDistance = math.huge
    local cameraPos = Camera.CFrame.Position
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") and not checkTeam(player) then
            if player.Character.Humanoid.Health >= features.aimbot.minHealth or not features.aimbot.healthCheck then
                local head = player.Character.Head
                local headPos = Camera:WorldToViewportPoint(head.Position)
                local screenPos = Vector2.new(headPos.X, headPos.Y)
                local cursorDistance = (screenPos - mousePos).Magnitude
                local playerDistance = (head.Position - cameraPos).Magnitude

                if cursorDistance < shortestCursorDistance and headPos.Z > 0 then
                    if not checkWall(player.Character) or not features.aimbot.wallCheck then
                        if playerDistance < shortestPlayerDistance then
                            shortestPlayerDistance = playerDistance
                            shortestCursorDistance = cursorDistance
                            nearestPlayer = player
                        end
                    end
                end
            end
        end
    end

    return nearestPlayer
end

local function predict(player)
    if player and player.Character and player.Character:FindFirstChild("Head") and player.Character:FindFirstChild("HumanoidRootPart") then
        local head = player.Character.Head
        local hrp = player.Character.HumanoidRootPart
        local velocity = hrp.Velocity
        local predictedPosition = head.Position + (velocity * features.aimbot.prediction)
        return predictedPosition
    end
    return nil
end

local function smooth(from, to)
    return from:Lerp(to, features.aimbot.smooth)
end

local function aimAt(player)
    local predictedPosition = predict(player)
    if predictedPosition then
        if player.Character.Humanoid.Health >= features.aimbot.minHealth or not features.aimbot.healthCheck then
            local targetCFrame = CFrame.new(Camera.CFrame.Position, predictedPosition)
            Camera.CFrame = smooth(Camera.CFrame, targetCFrame)
        end
    end
end

local function triggerPanicMode(reason)
    features.aimbot.enabled = false
    features.aimbot.aiming = false
    features.autoclicker.enabled = false
    features.autoclicker.holding = false
    features.killaura.enabled = false
    features.killaura.universal = false
    features.speed.enabled = false
    features.fly.enabled = false
    features.bhop = false

    if features.movement then
        features.movement.noclip = false
        features.movement.infiniteJump = false
        features.movement.glide = false
    end

    killauraTarget = nil
    currentTarget = nil
    setNoClip(false)
    disableBedwarsFly()
    setCrosshairVisible(false)
    fovCircle.Visible = false

    pcall(function()
        ui.notify({
            title = "Safety",
            message = ("Quick-disabled movement/combat (%s)"):format(reason or "manual"),
            duration = 3
        })
    end)

    if applyFeaturesToUI then
        pcall(function() applyFeaturesToUI() end)
    end
end

-- UI (Combat tab) - ADDED NEW SECTIONS
local combatTab = window:addMenu({text = 'Combat'})

local aimSection = combatTab:addSection({text = 'Aimbot', side = 'left', showMinButton = true})
local aimbotToggle = aimSection:addToggle({text = 'Aimbot', state = false})
local fovSlider = aimSection:addSlider({text = 'FOV', min = 0, max = 1000, step = 1, val = 100})
local smoothSlider = aimSection:addSlider({text = 'Smoothness', min = 0, max = 100, step = 1, val = 5})
local predictionSlider = aimSection:addSlider({text = 'Prediction', min = 0, max = 0.2, step = 0.001, val = 0.065})
local fovCircleToggle = aimSection:addToggle({text = 'FOV Circle', state = false})
local universalAimToggle = aimSection:addToggle({text = 'Universal Aim (no hold)', state = false})

-- NEW: Auto Clicker Section
local autoclickerSection = combatTab:addSection({text = 'Auto Clicker', side = 'left', showMinButton = true})
local autoclickerToggle = autoclickerSection:addToggle({text = 'Hold to Auto Click', state = false})
local cpsSlider = autoclickerSection:addSlider({text = 'CPS (Max 20)', min = 1, max = 20, step = 1, val = 12})

-- NEW: Kill Aura Section
local killauraSection = combatTab:addSection({text = 'Kill Aura', side = 'right', showMinButton = true})
local killauraToggle = killauraSection:addToggle({text = 'Kill Aura (Tool Required)', state = false})
local rangeSlider = killauraSection:addSlider({text = 'Range', min = 3, max = 15, step = 0.5, val = 8})
local toolCheckToggle = killauraSection:addToggle({text = 'Require Tool', state = false})
local universalKillauraToggle = killauraSection:addToggle({text = 'Universal Aura', state = features.killaura.universal})
local autoKillauraToggle = killauraSection:addToggle({text = 'Auto by Profile', state = features.killaura.auto})
local orbitToggle = killauraSection:addToggle({text = 'Orbit Attack', state = features.killaura.orbitEnabled})
local orbitRadiusSlider = killauraSection:addSlider({text = 'Orbit Radius', min = 1, max = 8, step = 0.1, val = features.killaura.orbitRadius})
local orbitSpeedSlider = killauraSection:addSlider({text = 'Orbit Speed', min = 0.5, max = 10, step = 0.1, val = features.killaura.orbitSpeed})
local killauraCpsSlider = killauraSection:addSlider({text = 'Attack CPS', min = 1, max = 60, step = 1, val = features.killaura.cps})
local killauraTeamCheckToggle = killauraSection:addToggle({text = 'Team Check', state = features.killaura.teamCheck})
local partsModeToggle = killauraSection:addToggle({text = 'Parts Viewport Mode', state = features.killaura.partsMode})

local advancedAimSection = combatTab:addSection({text = 'Advanced', side = 'right', showMinButton = true})
local wallCheckToggle = advancedAimSection:addToggle({text = 'Wall Check', state = true})
local stickyAimToggle = advancedAimSection:addToggle({text = 'Sticky Aim', state = false})
local aimTeamCheckToggle = advancedAimSection:addToggle({text = 'Team Check', state = false})
local healthCheckToggle = advancedAimSection:addToggle({text = 'Health Check', state = false})
local minHealthSlider = advancedAimSection:addSlider({text = 'Min Health', min = 0, max = 100, step = 1, val = 0})

local visualsSection = combatTab:addSection({text = 'FOV Visuals', side = 'right', showMinButton = true})
local circleColorPicker = visualsSection:addColorPicker({text = 'FOV Color', color = features.circleColor})
local targetColorPicker = visualsSection:addColorPicker({text = 'Target Color', color = features.targetedColor})
local rainbowFovToggle = visualsSection:addToggle({text = 'Rainbow FOV', state = false})

-- PvP Section (extra combat features)
local pvpSection = combatTab:addSection({text = 'PvP', side = 'left', showMinButton = true})
local rcsToggle = pvpSection:addToggle({text = 'RCS (Recoil Comp)', state = features.pvp.rcs})
local triggerDelaySlider = pvpSection:addSlider({text = 'Trigger Delay (s)', min = 0, max = 0.5, step = 0.005, val = features.pvp.triggerDelay})
local aimAssistSlider = pvpSection:addSlider({text = 'Aim Assist Strength', min = 0, max = 1, step = 0.01, val = features.pvp.aimAssist})
local autoWeaponToggle = pvpSection:addToggle({text = 'Auto Weapon Switch', state = features.pvp.autoWeapon})
local silentAimToggle = pvpSection:addToggle({text = 'Silent Aim', state = features.pvp.silentAim})
local reachSlider = pvpSection:addSlider({text = 'Reach', min = 1, max = 20, step = 0.5, val = features.pvp.reach or 8})

-- Event Connections
aimbotToggle:bindToEvent('onToggle', function(state) 
    features.aimbot.enabled = state
    fovCircle.Visible = state and features.fovCircle
end)

fovSlider:bindToEvent('onValueChanged', function(val) 
    features.aimbot.fov = val
    HUB.FOV = val
    fovCircle.Radius = val
end)

smoothSlider:bindToEvent('onValueChanged', function(val) 
    features.aimbot.smooth = 1 - (val / 100)
end)

predictionSlider:bindToEvent('onValueChanged', function(val) 
    features.aimbot.prediction = val
end)

fovCircleToggle:bindToEvent('onToggle', function(state)
    features.fovCircle = state
    fovCircle.Visible = state and features.aimbot.enabled
end)

universalAimToggle:bindToEvent('onToggle', function(state)
    features.aimbot.universal = state
end)

wallCheckToggle:bindToEvent('onToggle', function(state) features.aimbot.wallCheck = state end)
stickyAimToggle:bindToEvent('onToggle', function(state) features.aimbot.stickyAim = state end)
aimTeamCheckToggle:bindToEvent('onToggle', function(state) features.aimbot.teamCheck = state end)
healthCheckToggle:bindToEvent('onToggle', function(state) features.aimbot.healthCheck = state end)
minHealthSlider:bindToEvent('onValueChanged', function(val) features.aimbot.minHealth = val end)

circleColorPicker:bindToEvent('onValueChanged', function(color)
    features.circleColor = color
    fovCircle.Color = color
end)

targetColorPicker:bindToEvent('onValueChanged', function(color)
    features.targetedColor = color
end)

rainbowFovToggle:bindToEvent('onToggle', function(state)
    features.rainbowFov = state
end)

-- PvP bindings
rcsToggle:bindToEvent('onToggle', function(state) features.pvp.rcs = state end)
triggerDelaySlider:bindToEvent('onValueChanged', function(val) features.pvp.triggerDelay = val end)
aimAssistSlider:bindToEvent('onValueChanged', function(val) features.pvp.aimAssist = val end)
autoWeaponToggle:bindToEvent('onToggle', function(state) features.pvp.autoWeapon = state end)
silentAimToggle:bindToEvent('onToggle', function(state) features.pvp.silentAim = state end)
reachSlider:bindToEvent('onValueChanged', function(val) features.pvp.reach = val end)

-- NEW: Auto Clicker Events
autoclickerToggle:bindToEvent('onToggle', function(state) 
    features.autoclicker.enabled = state 
    local cps = math.clamp(features.autoclicker.cps or 12, 1, 20)
    clickInterval = 1 / cps
    lastClick = 0
end)

cpsSlider:bindToEvent('onValueChanged', function(val)
    features.autoclicker.cps = val
    local cps = math.clamp(val, 1, 20)
    features.autoclicker.cps = cps
    clickInterval = 1 / cps
end)

-- Killaura: clear target when toggled off
killauraToggle:bindToEvent('onToggle', function(state)
    features.killaura.enabled = state
    if not state then
        killauraTarget = nil
    else
        lastClick = 0
    end
end)

-- NEW: Kill Aura Events
-- (handled above with clearer onToggle binding)

rangeSlider:bindToEvent('onValueChanged', function(val)
    features.killaura.range = val
    HUB.RANGE = val
end)

toolCheckToggle:bindToEvent('onToggle', function(state)
    features.killaura.toolCheck = state
end)

universalKillauraToggle:bindToEvent('onToggle', function(state)
    features.killaura.universal = state
end)

autoKillauraToggle:bindToEvent('onToggle', function(state)
    features.killaura.auto = state
end)

orbitToggle:bindToEvent('onToggle', function(state)
    features.killaura.orbitEnabled = state
end)

orbitRadiusSlider:bindToEvent('onValueChanged', function(val)
    features.killaura.orbitRadius = val
end)

orbitSpeedSlider:bindToEvent('onValueChanged', function(val)
    features.killaura.orbitSpeed = val
end)

killauraCpsSlider:bindToEvent('onValueChanged', function(val)
    features.killaura.cps = val
end)

killauraTeamCheckToggle:bindToEvent('onToggle', function(state)
    features.killaura.teamCheck = state
end)

partsModeToggle:bindToEvent('onToggle', function(state)
    features.killaura.partsMode = state
end)

-- Mouse Controls
Mouse.Button2Down:Connect(function()
    if autoAimActive or features.aimbot.universal then return end
    if features.aimbot.enabled then
        features.aimbot.aiming = true
    end
end)

Mouse.Button2Up:Connect(function()
    if autoAimActive or features.aimbot.universal then return end
    if features.aimbot.enabled then
        features.aimbot.aiming = false
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        features.autoclicker.holding = true
        lastClick = 0
        if features.autoclicker.enabled and not vuserCaptured then
            pcall(function() VirtualUser:CaptureController() end)
            vuserCaptured = true
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        features.autoclicker.holding = false
    end
end)

UserInputService.JumpRequest:Connect(function()
    local movementSettings = features.movement
    if movementSettings and movementSettings.infiniteJump then
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- **MAIN LOOP** - Everything combined
RunService.Heartbeat:Connect(function(dt)
    applyMovementEnhancements()

    -- FOV Circle
    if features.aimbot.enabled or features.fovCircle then
        local offset = 50
        fovCircle.Position = Vector2.new(Mouse.X, Mouse.Y + offset)
        fovCircle.Radius = features.aimbot.fov

        -- central rainbow update: if any rainbow visuals are enabled, advance shared hue
        if features.rainbowFov or ESP.Rainbow or ESP.RainbowTracers then
            features.hue = features.hue + features.rainbowSpeed
            if features.hue > 1 then features.hue = 0 end
        end
        if features.rainbowFov then
            fovCircle.Color = Color3.fromHSV(features.hue, 1, 1)
        else
            if features.aimbot.aiming and currentTarget then
                fovCircle.Color = features.targetedColor
            else
                fovCircle.Color = features.circleColor
            end
        end

        fovCircle.Visible = features.fovCircle and (features.aimbot.enabled or features.aimbot.aiming)

            -- If running in an auto-aim place or universal mode, force aiming whenever aimbot is enabled
            if autoAimActive or features.aimbot.universal then
                features.aimbot.aiming = features.aimbot.enabled
            end

            if features.aimbot.aiming then
            if features.aimbot.stickyAim and currentTarget then
                local headPos = Camera:WorldToViewportPoint(currentTarget.Character.Head.Position)
                local screenPos = Vector2.new(headPos.X, headPos.Y)
                local cursorDistance = (screenPos - Vector2.new(Mouse.X, Mouse.Y)).Magnitude

                if cursorDistance > features.aimbot.fov or 
                   (features.aimbot.wallCheck and checkWall(currentTarget.Character)) or 
                   checkTeam(currentTarget) then
                    currentTarget = nil
                end
            end

            if not features.aimbot.stickyAim or not currentTarget then
                currentTarget = getTarget()
            end

            if currentTarget then
                aimAt(currentTarget)
            end
        else
            currentTarget = nil
        end
    end
    
    -- NEW: AUTO CLICKER
    if features.autoclicker.enabled and features.autoclicker.holding then
        local now = os.clock()
        if now - lastClick >= math.max(clickInterval, 0.001) then
            pcall(function()
                -- Ensure controller is captured once
                if not vuserCaptured then
                    pcall(function() VirtualUser:CaptureController() end)
                    vuserCaptured = true
                end
                local pos = Vector2.new(Mouse.X or 0, Mouse.Y or 0)
                VirtualUser:Button1Down(pos)
                VirtualUser:Button1Up(pos)
            end)
            lastClick = now
        end
    else
        -- release capture flag when not holding
        vuserCaptured = false
    end
    
        -- NEW: KILL AURA (with lock-on) - supports universal mode and auto-enable in listed place IDs
            local function validKTarget(p)
                if not p or not p.Character then return false end
                local humanoid = p.Character:FindFirstChild("Humanoid")
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if not humanoid or not hrp then return false end
                if humanoid.Health <= 0 then return false end
                if features.killaura.teamCheck then
                    local bothHaveTeams = (p.Team ~= nil) and (LocalPlayer.Team ~= nil)
                    if bothHaveTeams and p.Team == LocalPlayer.Team then return false end
                end
                local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not myHrp then return false end
                if (hrp.Position - myHrp.Position).Magnitude > features.killaura.range then return false end
                return true
            end

            -- Determine whether killaura should run this frame
            local inAutoPlace = autoAimActive
            local runKillaura = false
            if features.killaura.universal then
                runKillaura = true
            elseif inAutoPlace and features.killaura.auto then
                runKillaura = true
            elseif features.killaura.enabled then
                runKillaura = true
            end

            if runKillaura then
                -- enforce tool check only if set and not in universal/auto modes
                local requireTool = features.killaura.toolCheck and not features.killaura.universal and not (inAutoPlace and features.killaura.auto)
                if requireTool and not hasTool() then
                    killauraTarget = nil
                else
                        -- New parts-in-viewport touch-based attack mode
                        if features.killaura.partsMode then
                            -- non-blocking, find parts visible within configured range and touch them with tool handle
                            local function getPartsInViewport(maxDistance)
                                local partsInViewport = {}
                                local cam = Camera
                                local lp = LocalPlayer
                                for _, part in ipairs(workspace:GetDescendants()) do
                                    if part:IsA("BasePart") and part.Parent then
                                        local ok, dist = pcall(function() return lp:DistanceFromCharacter(part.Position) end)
                                        if ok and dist and dist <= maxDistance then
                                            local _, onScreen = cam:WorldToViewportPoint(part.Position)
                                            if onScreen then
                                                table.insert(partsInViewport, part)
                                            end
                                        end
                                    end
                                end
                                return partsInViewport
                            end

                            local parts = getPartsInViewport(features.killaura.range or 8)
                            local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                            if tool and tool:FindFirstChild("Handle") then
                                for _, part in ipairs(parts) do
                                    if part and part.Parent and part.Parent ~= LocalPlayer.Character and part.Parent:FindFirstChildWhichIsA("Humanoid") and part.Parent:FindFirstChildWhichIsA("Humanoid").Health > 0 then
                                        pcall(function()
                                            tool:Activate()
                                            if firetouchinterest then
                                                firetouchinterest(tool.Handle, part, 0)
                                                firetouchinterest(tool.Handle, part, 1)
                                            end
                                        end)
                                    end
                                end
                            end
                        else
                            -- legacy player-targeting killaura (keeps orbit and clicks)
                            if not validKTarget(killauraTarget) then
                                killauraTarget = getClosestEnemy(features.killaura.range)
                            end
                            if validKTarget(killauraTarget) then
                                -- Orbit movement around the target if enabled
                                local myChar = LocalPlayer.Character
                                local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                                local tgtHrp = killauraTarget.Character and killauraTarget.Character:FindFirstChild("HumanoidRootPart")
                                if myHrp and tgtHrp and features.killaura.orbitEnabled then
                                    -- update angle
                                    killauraAngle = killauraAngle + (dt or 0) * features.killaura.orbitSpeed
                                    -- compute orbit position
                                    local radius = features.killaura.orbitRadius or 3
                                    local offset = Vector3.new(math.cos(killauraAngle) * radius, 0, math.sin(killauraAngle) * radius)
                                    local orbitPos = tgtHrp.Position + offset
                                    -- move humanoid toward orbit position
                                    local humanoid = myChar:FindFirstChildWhichIsA("Humanoid")
                                    if humanoid then
                                        pcall(function() humanoid:MoveTo(orbitPos) end)
                                    end
                                    -- face target
                                    pcall(function() myHrp.CFrame = CFrame.new(myHrp.Position, tgtHrp.Position) end)
                                end
                                -- Attack logic: prefer tool activation, otherwise spam VirtualUser (Mouse1) at configured CPS
                                local cps = math.clamp(features.killaura.cps or 12, 1, 60)
                                if not vuserCaptured then
                                    pcall(function() VirtualUser:CaptureController() end)
                                    vuserCaptured = true
                                end

                                local attacked = false
                                if hasTool() then
                                    pcall(function()
                                        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                                        if tool and tool.Parent then
                                            tool:Activate()
                                            attacked = true
                                        end
                                    end)
                                end

                                if not attacked then
                                    local now = os.clock()
                                    if now - killauraLastClick >= (1 / cps) then
                                        pcall(function()
                                            local pos = Vector2.new(Mouse.X or 0, Mouse.Y or 0)
                                            VirtualUser:Button1Down(pos)
                                            VirtualUser:Button1Up(pos)
                                        end)
                                        killauraLastClick = now
                                    end
                                end
                            end
                        end
                    end
            else
                killauraTarget = nil
            end

    -- Track last grounded position to recover safer from void falls.
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if hrp and humanoid and humanoid.Health > 0 then
            local voidThreshold = (features.utilities and features.utilities.voidY) or -50
            if humanoid.FloorMaterial ~= Enum.Material.Air and hrp.Position.Y > (voidThreshold + 10) then
                lastSafePosition = hrp.Position
            end
        end
    end)

    -- Anti-Void: teleport to last safe position (or spawn fallback) when below threshold.
    if features.utilities and features.utilities.antiVoid then
        pcall(function()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.Position and hrp.Position.Y <= (features.utilities.voidY or -50) then
                local now = os.clock()
                if now - lastVoidTime > 5 then
                    local spawnPos
                    local message = "Teleported to safety"
                    if lastSafePosition and lastSafePosition.Y > (features.utilities.voidY or -50) then
                        spawnPos = lastSafePosition
                        message = "Returned to last safe position"
                    end
                    local spawn = workspace:FindFirstChild("SpawnLocation") or workspace:FindFirstChild("Spawn")
                    if not spawnPos and spawn then
                        if spawn:IsA("BasePart") then
                            spawnPos = spawn.Position
                        elseif spawn.CFrame then
                            spawnPos = spawn.CFrame.Position
                        end
                    end
                    spawnPos = spawnPos or Vector3.new(0, 50, 0)
                    hrp.CFrame = CFrame.new(spawnPos + Vector3.new(0, 5, 0))
                    pcall(function() ui.notify({ title = "Anti-Void", message = message, duration = 3 }) end)
                    lastVoidTime = now
                end
            end
        end)
    end
end)

-- ESP CODE (unchanged - keeping your exact ESP implementation)
ESP = {}
ESP.Drawings = {}
ESP.Enabled = false
ESP.ShowBoxes = true
ESP.ShowNames = true
ESP.ShowDistance = true
ESP.ShowHealth = true
ESP.ShowTracers = false
ESP.Rainbow = false
ESP.RainbowTracers = false
ESP.TeamColor = false
ESP.BoxColor = Color3.fromRGB(255, 255, 255)
ESP.TracerColor = Color3.fromRGB(255, 0, 0)

local Camera = workspace.CurrentCamera
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local function WTS(Position)
    local Vector, OnScreen = Camera:WorldToViewportPoint(Position)
    return Vector2.new(Vector.X, Vector.Y), OnScreen
end

local function CleanupPlayer(Player)
    if ESP.Drawings[Player] then
        for _, Drawing in pairs(ESP.Drawings[Player]) do
            pcall(function() 
                Drawing:Remove() 
            end)
        end
        ESP.Drawings[Player] = nil
    end
end

function ESP:CreateESP(Player)
    CleanupPlayer(Player)
    
    local Drawings = {}
    
    Drawings.Box = Drawing.new("Quad")
    Drawings.Box.Color = ESP.BoxColor
    Drawings.Box.Thickness = 2
    Drawings.Box.Transparency = 1
    Drawings.Box.Visible = false
    
    Drawings.Name = Drawing.new("Text")
    Drawings.Name.Size = 16
    Drawings.Name.Center = true
    Drawings.Name.Outline = true
    Drawings.Name.Font = 2
    Drawings.Name.Color = Color3.new(1,1,1)
    Drawings.Name.Visible = false
    
    Drawings.Distance = Drawing.new("Text")
    Drawings.Distance.Size = 14
    Drawings.Distance.Center = true
    Drawings.Distance.Outline = true
    Drawings.Distance.Font = 2
    Drawings.Distance.Color = Color3.new(1,1,0)
    Drawings.Distance.Visible = false
    
    Drawings.HealthBG = Drawing.new("Quad")
    Drawings.HealthBG.Color = Color3.new(0,0,0)
    Drawings.HealthBG.Thickness = 3
    Drawings.HealthBG.Transparency = 0.5
    Drawings.HealthBG.Visible = false
    
    Drawings.Health = Drawing.new("Quad")
    Drawings.Health.Color = Color3.new(0,1,0)
    Drawings.Health.Thickness = 3
    Drawings.Health.Transparency = 1
    Drawings.Health.Visible = false
    
    Drawings.Tracer = Drawing.new("Line")
    Drawings.Tracer.Color = ESP.TracerColor
    Drawings.Tracer.Thickness = 2
    Drawings.Tracer.Transparency = 1
    Drawings.Tracer.Visible = false
    
    ESP.Drawings[Player] = Drawings
end

function ESP:Update()
    if not ESP.Enabled then return end

    -- use shared hue from features for rainbow coloring (keeps all rainbow visuals in sync)
    local hue = features.hue
    local LocalChar = LocalPlayer.Character
    if not LocalChar or not LocalChar:FindFirstChild("HumanoidRootPart") then return end
    
    for Player, Drawings in pairs(ESP.Drawings) do
        if not Player.Parent or Player == LocalPlayer then
            CleanupPlayer(Player)
        else
            local Char = Player.Character
            if Char and Char:FindFirstChild("HumanoidRootPart") and Char:FindFirstChild("Humanoid") and Char:FindFirstChild("Head") then
                
                local RootPart = Char.HumanoidRootPart
                local Humanoid = Char.Humanoid
                local Head = Char.Head
                
                local Distance = (RootPart.Position - LocalChar.HumanoidRootPart.Position).Magnitude
                local HealthPct = math.clamp(Humanoid.Health / Humanoid.MaxHealth, 0, 1)
                
                local HeadPos, HeadOnScreen = WTS(Head.Position + Vector3.new(0, 0.5, 0))
                local LegPos, LegOnScreen = WTS(RootPart.Position - Vector3.new(0, 3, 0))

                if HeadOnScreen then
                    -- use head (top) and leg (bottom) screen Y positions for proper box placement
                    local BoxTop = HeadPos.Y
                    local BoxBottom = LegPos.Y
                    local BoxHeight = BoxBottom - BoxTop
                    local BoxWidth = BoxHeight * 0.5
                    local BoxLeft = HeadPos.X - BoxWidth / 2
                    local BoxRight = HeadPos.X + BoxWidth / 2

                    local BoxColor = ESP.TeamColor and (Player.Team and Player.Team.TeamColor.Color or Color3.new(1,1,1)) or ESP.BoxColor
                    if ESP.Rainbow then BoxColor = Color3.fromHSV(hue, 1, 1) end
                    Drawings.Box.Color = BoxColor

                    local TracerColor = ESP.TracerColor
                    if ESP.RainbowTracers then TracerColor = Color3.fromHSV(hue + 0.5, 1, 1) end
                    Drawings.Tracer.Color = TracerColor

                    local ScreenCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
                    Drawings.Tracer.From = ScreenCenter
                    Drawings.Tracer.To = HeadPos
                    Drawings.Tracer.Visible = ESP.ShowTracers

                    Drawings.Box.PointA = Vector2.new(BoxLeft, BoxTop)
                    Drawings.Box.PointB = Vector2.new(BoxRight, BoxTop)
                    Drawings.Box.PointC = Vector2.new(BoxRight, BoxBottom)
                    Drawings.Box.PointD = Vector2.new(BoxLeft, BoxBottom)
                    Drawings.Box.Visible = ESP.ShowBoxes

                    if ESP.ShowNames then
                        Drawings.Name.Text = Player.Name
                        Drawings.Name.Position = Vector2.new(HeadPos.X, BoxTop - 20)
                        Drawings.Name.Visible = true
                    else
                        Drawings.Name.Visible = false
                    end

                    if ESP.ShowDistance then
                        Drawings.Distance.Text = math.floor(Distance).."m"
                        Drawings.Distance.Position = Vector2.new(HeadPos.X, BoxTop - 5)
                        Drawings.Distance.Visible = true
                    else
                        Drawings.Distance.Visible = false
                    end

                    if ESP.ShowHealth then
                        local BarHeight = BoxHeight * 0.6
                        local BarWidth = 4
                        local BarX = BoxRight + 5
                        local BarY = BoxBottom - BarHeight

                        Drawings.HealthBG.PointA = Vector2.new(BarX, BarY)
                        Drawings.HealthBG.PointB = Vector2.new(BarX + BarWidth, BarY)
                        Drawings.HealthBG.PointC = Vector2.new(BarX + BarWidth, BarY + BarHeight)
                        Drawings.HealthBG.PointD = Vector2.new(BarX, BarY + BarHeight)
                        Drawings.HealthBG.Visible = true

                        local HealthColor = Color3.fromRGB(255*(1-HealthPct), 255*HealthPct, 0)
                        Drawings.Health.Color = HealthColor
                        Drawings.Health.PointA = Vector2.new(BarX+1, BarY+1)
                        Drawings.Health.PointB = Vector2.new(BarX+BarWidth-1, BarY+1)
                        Drawings.Health.PointC = Vector2.new(BarX+BarWidth-1, BarY+BarHeight*(1-HealthPct))
                        Drawings.Health.PointD = Vector2.new(BarX+1, BarY+BarHeight*(1-HealthPct))
                        Drawings.Health.Visible = true
                    else
                        Drawings.HealthBG.Visible = false
                        Drawings.Health.Visible = false
                    end

                    Drawings.Box.Transparency = 1
                    Drawings.Name.Transparency = 1
                    Drawings.Distance.Transparency = 1
                    Drawings.Tracer.Transparency = 1
                else
                    Drawings.Box.Visible = false
                    Drawings.Name.Visible = false
                    Drawings.Distance.Visible = false
                    Drawings.HealthBG.Visible = false
                    Drawings.Health.Visible = false
                    Drawings.Tracer.Visible = false
                end
            else
                Drawings.Box.Visible = false
                Drawings.Name.Visible = false
                Drawings.Distance.Visible = false
                Drawings.HealthBG.Visible = false
                Drawings.Health.Visible = false
                Drawings.Tracer.Visible = false
            end
        end
    end
end

function ESP:Toggle(state)
    ESP.Enabled = state
    if state then
        for _, Player in pairs(Players:GetPlayers()) do
            if Player ~= LocalPlayer then
                ESP:CreateESP(Player)
            end
        end
    else
        for Player, Drawings in pairs(ESP.Drawings) do
            CleanupPlayer(Player)
        end
        ESP.Drawings = {}
    end
end

-- Hub Tab (game-id routing + manual profile switching)
local hubTab = window:addMenu({text = 'Hub'})

local hubRouteSection = hubTab:addSection({text = 'Router', side = 'left', showMinButton = true})
local autoRouteToggle = hubRouteSection:addToggle({text = 'Auto Route by Game ID', state = HUB.AUTO_ROUTE})
hubRouteStatusLabel = hubRouteSection:addLabel({text = 'Route: Auto (Game ID)', dim = true})
hubProfileStatusLabel = hubRouteSection:addLabel({text = 'Profile: ' .. getProfileLabel(HUB.ACTIVE_PROFILE)})
hubRouteSection:addLabel({text = 'PlaceId: ' .. tostring(game.PlaceId), dim = true})
hubRouteSection:addLabel({text = 'GameId: ' .. tostring(game.GameId), dim = true})
local routeRefreshButton = hubRouteSection:addButton({text = 'Re-detect Profile'})
local cycleProfileButton = hubRouteSection:addButton({text = 'Cycle Manual Profile'})
local applyManualProfileButton = hubRouteSection:addButton({text = 'Apply Manual Profile'})

local hubPresetSection = hubTab:addSection({text = 'Quick Presets', side = 'right', showMinButton = true})
local universalProfileButton = hubPresetSection:addButton({text = 'Use Universal'})
local bedwarsProfileButton = hubPresetSection:addButton({text = 'Use BedWars'})
local arenaProfileButton = hubPresetSection:addButton({text = 'Use Arena'})
hubPresetSection:addLabel({text = 'Edit PROFILE_ROUTES for your own game ids.', dim = true})

local manualProfileIndex = findProfileIndex(HUB.MANUAL_PROFILE)

local function selectManualProfile(profileKey, notifySelection)
    if not PROFILE_PRESETS[profileKey] then
        return
    end

    HUB.MANUAL_PROFILE = profileKey
    manualProfileIndex = findProfileIndex(profileKey)
    updateHubLabels()

    if notifySelection then
        ui.notify({
            title = 'Hub Manual Profile',
            message = 'Selected: ' .. getProfileLabel(profileKey),
            duration = 2
        })
    end
end

autoRouteToggle:bindToEvent('onToggle', function(state)
    HUB.AUTO_ROUTE = state
    if HUB.AUTO_ROUTE then
        routeProfile(true)
    else
        applyProfile(HUB.MANUAL_PROFILE, "manual route", true)
    end
end)

routeRefreshButton:bindToEvent('onClick', function()
    if HUB.AUTO_ROUTE then
        routeProfile(true)
    else
        applyProfile(HUB.MANUAL_PROFILE, "manual refresh", true)
    end
end)

cycleProfileButton:bindToEvent('onClick', function()
    manualProfileIndex = (manualProfileIndex % #PROFILE_ORDER) + 1
    local nextProfile = PROFILE_ORDER[manualProfileIndex]
    selectManualProfile(nextProfile, true)
end)

applyManualProfileButton:bindToEvent('onClick', function()
    if HUB.AUTO_ROUTE then
        ui.notify({
            title = 'Hub',
            message = 'Disable Auto Route to force manual profiles.',
            duration = 3
        })
        return
    end

    applyProfile(HUB.MANUAL_PROFILE, "manual apply", true)
end)

universalProfileButton:bindToEvent('onClick', function()
    selectManualProfile("universal", false)
    if HUB.AUTO_ROUTE then
        HUB.AUTO_ROUTE = false
        pcall(function() autoRouteToggle:setState(false) end)
    end
    applyProfile("universal", "manual preset", true)
end)

bedwarsProfileButton:bindToEvent('onClick', function()
    selectManualProfile("bedwars", false)
    if HUB.AUTO_ROUTE then
        HUB.AUTO_ROUTE = false
        pcall(function() autoRouteToggle:setState(false) end)
    end
    applyProfile("bedwars", "manual preset", true)
end)

arenaProfileButton:bindToEvent('onClick', function()
    selectManualProfile("arena", false)
    if HUB.AUTO_ROUTE then
        HUB.AUTO_ROUTE = false
        pcall(function() autoRouteToggle:setState(false) end)
    end
    applyProfile("arena", "manual preset", true)
end)

updateHubLabels()

-- ESP Tab (unchanged)
local espTab = window:addMenu({text = 'Render'})

local mainSection = espTab:addSection({text = 'Main', side = 'left'})
local toggle = mainSection:addToggle({text = 'Enable ESP', state = false})

local rainbowSection = espTab:addSection({text = 'Rainbow', side = 'left'})
local rainbowToggle = rainbowSection:addToggle({text = 'Boxes', state = false})
local rainbowTracerToggle = rainbowSection:addToggle({text = 'Tracers', state = false})
local speedSlider = rainbowSection:addSlider({text = 'Speed', min = 1, max = 10, val = 3})

local boxSection = espTab:addSection({text = 'Boxes', side = 'right'})
local boxToggle = boxSection:addToggle({text = 'Show Boxes', state = true})
local nameToggle = boxSection:addToggle({text = 'Names', state = true})
local distToggle = boxSection:addToggle({text = 'Distance', state = true})
local healthToggle = boxSection:addToggle({text = 'Health', state = true})
local teamToggle = boxSection:addToggle({text = 'Team Color', state = false})
local colorPicker = boxSection:addColorPicker({text = 'Color', color = ESP.BoxColor})

local tracerSection = espTab:addSection({text = 'Tracers', side = 'right'})
local tracerToggle = tracerSection:addToggle({text = 'Show Tracers', state = false})
local tracerColorPicker = tracerSection:addColorPicker({text = 'Color', color = ESP.TracerColor})

local renderEnhanceSection = espTab:addSection({text = 'Enhancements', side = 'left'})
local fullbrightToggle = renderEnhanceSection:addToggle({text = 'Fullbright', state = features.render and features.render.fullbright or false})
local customFovToggle = renderEnhanceSection:addToggle({text = 'Custom Camera FOV', state = features.render and features.render.customFov or false})
local cameraFovSlider = renderEnhanceSection:addSlider({text = 'Camera FOV', min = 40, max = 120, step = 1, val = features.render and features.render.cameraFov or 70})
local crosshairToggle = renderEnhanceSection:addToggle({text = 'Crosshair', state = features.render and features.render.crosshair or false})
local crosshairSizeSlider = renderEnhanceSection:addSlider({text = 'Crosshair Size', min = 4, max = 30, step = 1, val = features.render and features.render.crosshairSize or 10})
local chamsToggle = renderEnhanceSection:addToggle({text = 'Player Chams', state = features.chams})

toggle:bindToEvent('onToggle', function(state) ESP:Toggle(state) features.esp.enabled = state end)
rainbowToggle:bindToEvent('onToggle', function(state) ESP.Rainbow = state features.esp.rainbow = state end)
rainbowTracerToggle:bindToEvent('onToggle', function(state) ESP.RainbowTracers = state features.esp.rainbowTracers = state end)
speedSlider:bindToEvent('onValueChanged', function(val)
    local speed = val * 0.001
    features.rainbowSpeed = speed
    ESP.RainbowSpeed = speed
end)

boxToggle:bindToEvent('onToggle', function(state) ESP.ShowBoxes = state features.esp.boxes = state end)
nameToggle:bindToEvent('onToggle', function(state) ESP.ShowNames = state features.esp.names = state end)
distToggle:bindToEvent('onToggle', function(state) ESP.ShowDistance = state features.esp.distance = state end)
healthToggle:bindToEvent('onToggle', function(state) ESP.ShowHealth = state features.esp.health = state end)
teamToggle:bindToEvent('onToggle', function(state) ESP.TeamColor = state features.esp.teamColor = state end)
colorPicker:bindToEvent('onValueChanged', function(color) ESP.BoxColor = color end)

tracerToggle:bindToEvent('onToggle', function(state) ESP.ShowTracers = state features.esp.tracers = state end)
tracerColorPicker:bindToEvent('onValueChanged', function(color) ESP.TracerColor = color end)
fullbrightToggle:bindToEvent('onToggle', function(state)
    if not features.render then features.render = {} end
    features.render.fullbright = state
    applyRenderEnhancements()
end)
customFovToggle:bindToEvent('onToggle', function(state)
    if not features.render then features.render = {} end
    features.render.customFov = state
    applyRenderEnhancements()
end)
cameraFovSlider:bindToEvent('onValueChanged', function(val)
    if not features.render then features.render = {} end
    features.render.cameraFov = val
end)
crosshairToggle:bindToEvent('onToggle', function(state)
    if not features.render then features.render = {} end
    features.render.crosshair = state
    applyRenderEnhancements()
end)
crosshairSizeSlider:bindToEvent('onValueChanged', function(val)
    if not features.render then features.render = {} end
    features.render.crosshairSize = val
end)
chamsToggle:bindToEvent('onToggle', function(state)
    features.chams = state
    applyRenderEnhancements()
end)

-- Movement Tab
local movementTab = window:addMenu({text = 'Movement'})

local speedSection = movementTab:addSection({text = 'Speed', side = 'left'})
local speedToggle = speedSection:addToggle({text = 'Enable Speed', state = features.speed.enabled})
local speedMultiplierSlider = speedSection:addSlider({text = 'Speed Multiplier', min = 1, max = 10, step = 1, val = features.speed.multiplier})

local flySection = movementTab:addSection({text = 'Fly', side = 'right'})
local flyToggle = flySection:addToggle({text = 'Enable Fly', state = features.fly.enabled})
local flySpeedSlider = flySection:addSlider({text = 'Fly Speed', min = 1, max = 200, step = 1, val = features.fly.speed})
local flyBypassToggle = flySection:addToggle({text = 'Bedwars Bypass Mode', state = features.fly.bedwars})

local miscSection = movementTab:addSection({text = 'Misc', side = 'left'})
local bhopToggle = miscSection:addToggle({text = 'Bunny Hop', state = features.bhop})

local movementAdvancedSection = movementTab:addSection({text = 'Advanced', side = 'right'})
local noclipToggle = movementAdvancedSection:addToggle({text = 'Noclip', state = features.movement and features.movement.noclip or false})
local infiniteJumpToggle = movementAdvancedSection:addToggle({text = 'Infinite Jump', state = features.movement and features.movement.infiniteJump or false})
local glideToggle = movementAdvancedSection:addToggle({text = 'Glide', state = features.movement and features.movement.glide or false})
local glideSpeedSlider = movementAdvancedSection:addSlider({text = 'Glide Fall Speed', min = 2, max = 40, step = 1, val = features.movement and features.movement.glideFallSpeed or 12})
local customJumpToggle = movementAdvancedSection:addToggle({text = 'Custom Jump Power', state = features.movement and features.movement.customJump or false})
local jumpPowerSlider = movementAdvancedSection:addSlider({text = 'Jump Power', min = 25, max = 200, step = 1, val = features.movement and features.movement.jumpPower or 50})

-- Utilities Tab
local utilTab = window:addMenu({text = 'Utilities'})
local utilSection = utilTab:addSection({text = 'General', side = 'left'})
local antiAfkToggle = utilSection:addToggle({text = 'Anti-AFK', state = features.utilities and features.utilities.antiAfk or false})
local antiVoidToggle = utilSection:addToggle({text = 'Anti-Void', state = features.utilities and features.utilities.antiVoid or false})
local voidYSlider = utilSection:addSlider({text = 'Void Y Threshold', min = -500, max = 0, step = 1, val = features.utilities and features.utilities.voidY or -50})
local damageNotifyToggle = utilSection:addToggle({text = 'Damage Notify', state = features.utilities and features.utilities.damageNotify or false})
local dmgThresholdSlider = utilSection:addSlider({text = 'Damage Threshold', min = 1, max = 100, step = 1, val = features.utilities and features.utilities.damageThreshold or 1})

local utilityAutomationSection = utilTab:addSection({text = 'Automation', side = 'right'})
local autoRespawnToggle = utilityAutomationSection:addToggle({text = 'Auto Respawn', state = features.utilities and features.utilities.autoRespawn or false})
local antiRagdollToggle = utilityAutomationSection:addToggle({text = 'Anti-Ragdoll', state = features.utilities and features.utilities.antiRagdoll or false})
local panicButton = utilityAutomationSection:addButton({text = 'Panic Disable (End)'})
local rejoinButton = utilityAutomationSection:addButton({text = 'Rejoin Server'})
local copyJobIdButton = utilityAutomationSection:addButton({text = 'Copy JobId'})

-- Movement bindings
speedToggle:bindToEvent('onToggle', function(state)
    features.speed.enabled = state
    refreshHubDerivedValues()
end)
speedMultiplierSlider:bindToEvent('onValueChanged', function(val)
    features.speed.multiplier = val
    refreshHubDerivedValues()
end)
flyToggle:bindToEvent('onToggle', function(state)
    features.fly.enabled = state
    if not state then
        disableBedwarsFly()
    elseif features.fly.bedwars and not flyActive then
        enableBedwarsFly()
    end
end)
flySpeedSlider:bindToEvent('onValueChanged', function(val) features.fly.speed = val end)
flyBypassToggle:bindToEvent('onToggle', function(state)
    features.fly.bedwars = state
    if not state then
        disableBedwarsFly()
    elseif features.fly.enabled and not flyActive then
        enableBedwarsFly()
    end
end)
bhopToggle:bindToEvent('onToggle', function(state) features.bhop = state end)
noclipToggle:bindToEvent('onToggle', function(state)
    if not features.movement then features.movement = {} end
    features.movement.noclip = state
    if not state then
        setNoClip(false)
    end
end)
infiniteJumpToggle:bindToEvent('onToggle', function(state)
    if not features.movement then features.movement = {} end
    features.movement.infiniteJump = state
end)
glideToggle:bindToEvent('onToggle', function(state)
    if not features.movement then features.movement = {} end
    features.movement.glide = state
end)
glideSpeedSlider:bindToEvent('onValueChanged', function(val)
    if not features.movement then features.movement = {} end
    features.movement.glideFallSpeed = val
end)
customJumpToggle:bindToEvent('onToggle', function(state)
    if not features.movement then features.movement = {} end
    features.movement.customJump = state
end)
jumpPowerSlider:bindToEvent('onValueChanged', function(val)
    if not features.movement then features.movement = {} end
    features.movement.jumpPower = val
end)
antiAfkToggle:bindToEvent('onToggle', function(state) if not features.utilities then features.utilities = {} end features.utilities.antiAfk = state end)
antiVoidToggle:bindToEvent('onToggle', function(state) if not features.utilities then features.utilities = {} end features.utilities.antiVoid = state end)
voidYSlider:bindToEvent('onValueChanged', function(val) if not features.utilities then features.utilities = {} end features.utilities.voidY = val end)
damageNotifyToggle:bindToEvent('onToggle', function(state) if not features.utilities then features.utilities = {} end features.utilities.damageNotify = state end)
dmgThresholdSlider:bindToEvent('onValueChanged', function(val) if not features.utilities then features.utilities = {} end features.utilities.damageThreshold = val end)
autoRespawnToggle:bindToEvent('onToggle', function(state) if not features.utilities then features.utilities = {} end features.utilities.autoRespawn = state end)
antiRagdollToggle:bindToEvent('onToggle', function(state) if not features.utilities then features.utilities = {} end features.utilities.antiRagdoll = state antiRagdollApplied = nil end)
panicButton:bindToEvent('onClick', function()
    triggerPanicMode("button")
end)
rejoinButton:bindToEvent('onClick', function()
    local joined = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
    if not joined then
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end
end)
copyJobIdButton:bindToEvent('onClick', function()
    if setclipboard then
        pcall(function() setclipboard(tostring(game.JobId)) end)
        ui.notify({title = "Utilities", message = "Copied JobId to clipboard", duration = 2})
    else
        ui.notify({title = "Utilities", message = "Clipboard API unavailable", duration = 2})
    end
end)

-- CapsLock input: toggles Bedwars-style fly when UI enabled
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.CapsLock then
        if features.fly.enabled and features.fly.bedwars then
            if not flyActive then
                enableBedwarsFly()
            else
                disableBedwarsFly()
            end
        end
    end
end)

-- RightShift toggle: toggles fly + killaura together (friend logic)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == PANIC_KEY then
        triggerPanicMode("key")
        return
    end
    if input.KeyCode == HUB.TOGGLE_KEY then
        features.fly.enabled = not features.fly.enabled
        if features.fly.enabled and features.fly.bedwars then
            enableBedwarsFly()
        else
            disableBedwarsFly()
        end

        features.killaura.enabled = not features.killaura.enabled

        pcall(function()
            ui.notify({ title = 'Rise', message = ('Toggle: Fly=%s | KillAura=%s'):format(tostring(features.fly.enabled), tostring(features.killaura.enabled)), duration = 3 })
        end)
    end
end)

-- Anti-AFK handler
if LocalPlayer then
    LocalPlayer.Idled:Connect(function()
        if features.utilities and features.utilities.antiAfk then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:Button2Down(Vector2.new(0,0))
                wait(0.1)
                VirtualUser:Button2Up(Vector2.new(0,0))
            end)
        end
    end)
end

-- Local damage listener for notifications
local function setupLocalDamageListener(character)
    pcall(function()
        local humanoid = character:FindFirstChild("Humanoid") or character:WaitForChild("Humanoid", 5)
        if humanoid then
            lastLocalHealth = humanoid.Health
            humanoid.HealthChanged:Connect(function(new)
                if features.utilities and features.utilities.damageNotify and lastLocalHealth and new < lastLocalHealth and (lastLocalHealth - new) >= (features.utilities.damageThreshold or 1) then
                    pcall(function()
                        ui.notify({ title = "Damage Taken", message = ("You took %d damage"):format(math.floor(lastLocalHealth - new)), duration = 3 })
                    end)
                end
                lastLocalHealth = new
            end)
        end
    end)
end

if LocalPlayer.Character then
    captureBaseWalkSpeed(LocalPlayer.Character)
    local initialHrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if initialHrp then
        lastSafePosition = initialHrp.Position
    end
    setupLocalDamageListener(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(function(char)
    setNoClip(false)
    antiRagdollApplied = nil
    captureBaseWalkSpeed(char)
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 5)
    if hrp then
        lastSafePosition = hrp.Position
    end
    setupLocalDamageListener(char)
    if HUB.AUTO_ROUTE then
        routeProfile(false)
    else
        applyProfile(HUB.MANUAL_PROFILE, "respawn", false)
    end
end)

RunService.RenderStepped:Connect(function()
    applyRenderEnhancements()
    ESP:Update()
end)

Players.PlayerAdded:Connect(function(Player)
    if Player == LocalPlayer then return end
    Player.CharacterAdded:Connect(function()
        if ESP.Enabled then
            ESP:CreateESP(Player)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(Player)
    CleanupPlayer(Player)
    local highlight = chamHighlights[Player]
    if highlight then
        pcall(function() highlight:Destroy() end)
        chamHighlights[Player] = nil
    end
end)

for _, Player in pairs(Players:GetPlayers()) do
    if Player ~= LocalPlayer then
        Player.CharacterAdded:Connect(function()
            if ESP.Enabled then
                ESP:CreateESP(Player)
            end
        end)
    end
end

-- Config Tab - Vape-style profile system
local configTab = window:addMenu({text = 'Config'})

ConfigManager:_loadState()

local profileSection = configTab:addSection({text = 'Profiles', side = 'left', showMinButton = true})
local profileStatusLabel = profileSection:addLabel({text = 'Current: ' .. tostring(ConfigManager.current), dim = true})
local profileNameBox = profileSection:addTextbox({text = ConfigManager.current})
local profilePrevButton = profileSection:addButton({text = 'Prev Profile'})
local profileNextButton = profileSection:addButton({text = 'Next Profile'})
local profileSaveButton = profileSection:addButton({text = 'Save Profile'})
local profileLoadButton = profileSection:addButton({text = 'Load Profile'})
local profileDeleteButton = profileSection:addButton({text = 'Delete Profile'})
local refreshProfilesButton = profileSection:addButton({text = 'Refresh Profiles'})

local startupSection = configTab:addSection({text = 'Startup', side = 'right', showMinButton = true})
local autoloadToggle = startupSection:addToggle({text = 'Autoload on Inject', state = ConfigManager.autoloadEnabled ~= false})
local autoloadStatusLabel = startupSection:addLabel({text = 'Autoload Profile: ' .. tostring(ConfigManager.autoloadProfile), dim = true})
local setAutoloadButton = startupSection:addButton({text = 'Set Current as Autoload'})
local loadAutoloadButton = startupSection:addButton({text = 'Load Autoload Now'})

local automationSection = configTab:addSection({text = 'Automation', side = 'right', showMinButton = false})
local autoSaveToggle = automationSection:addToggle({text = 'Auto Save', state = features.config and features.config.autoSave ~= false})
local autoSaveIntervalSlider = automationSection:addSlider({text = 'Save Interval (s)', min = 10, max = 300, step = 5, val = features.config and features.config.autoSaveInterval or 30})

local keybindSection = configTab:addSection({text = 'Keybinds', side = 'right', showMinButton = false})
local menuKey = keybindSection:addHotkey({text = 'Menu Toggle'})
menuKey:setHotkey(Enum.KeyCode.Insert)
keybindSection:addLabel({text = 'Panic key: End', dim = true})

-- profile list state
local configList = {}
local configListIndex = 0

local function updateConfigLabels()
    if profileStatusLabel and profileStatusLabel.setText then
        pcall(function()
            profileStatusLabel:setText(("Current: %s (%d profiles)"):format(tostring(ConfigManager.current), #configList))
        end)
    end
    if autoloadStatusLabel and autoloadStatusLabel.setText then
        pcall(function()
            local enabled = ConfigManager.autoloadEnabled and "On" or "Off"
            autoloadStatusLabel:setText(("Autoload [%s]: %s"):format(enabled, tostring(ConfigManager.autoloadProfile)))
        end)
    end
end

local function setProfileTextboxValue(name)
    if not profileNameBox or not profileNameBox.instances or not profileNameBox.instances.textBox then
        return
    end
    profileNameBox.name = name
    profileNameBox.instances.textBox.Text = name
end

local function refreshConfigList()
    configList = ConfigManager:list() or {}
    if #configList == 0 then
        configListIndex = 0
    else
        local found = false
        for index, cfgName in ipairs(configList) do
            if cfgName == ConfigManager.current then
                configListIndex = index
                found = true
                break
            end
        end
        if not found then
            configListIndex = 1
            ConfigManager:setCurrent(configList[1], true)
        end
    end
    setProfileTextboxValue(ConfigManager.current)
    updateConfigLabels()
end

local function getSelectedProfileFromInput()
    local typed = ConfigManager.current
    if profileNameBox and profileNameBox.instances and profileNameBox.instances.textBox then
        typed = profileNameBox.instances.textBox.Text
    end
    local cleaned = sanitizeConfigName(typed)
    ConfigManager:setCurrent(cleaned, true)
    setProfileTextboxValue(cleaned)
    return cleaned
end

profileNameBox:bindToEvent('onFocusLost', function(inputText)
    local cleaned = sanitizeConfigName(inputText)
    ConfigManager:setCurrent(cleaned, true)
    setProfileTextboxValue(cleaned)
    refreshConfigList()
end)

profilePrevButton:bindToEvent('onClick', function()
    refreshConfigList()
    if #configList == 0 then
        ui.notify({ title = "Configs", message = "No profiles found", duration = 3 })
        return
    end
    configListIndex = ((configListIndex - 2) % #configList) + 1
    local selected = configList[configListIndex]
    ConfigManager:setCurrent(selected, true)
    setProfileTextboxValue(selected)
    updateConfigLabels()
    ui.notify({ title = "Configs", message = ("Selected: %s"):format(selected), duration = 2 })
end)

profileNextButton:bindToEvent('onClick', function()
    refreshConfigList()
    if #configList == 0 then
        ui.notify({ title = "Configs", message = "No profiles found", duration = 3 })
        return
    end
    configListIndex = (configListIndex % #configList) + 1
    local selected = configList[configListIndex]
    ConfigManager:setCurrent(selected, true)
    setProfileTextboxValue(selected)
    updateConfigLabels()
    ui.notify({ title = "Configs", message = ("Selected: %s"):format(selected), duration = 2 })
end)

profileSaveButton:bindToEvent('onClick', function()
    local target = getSelectedProfileFromInput()
    if ConfigManager:save(target) then
        refreshConfigList()
    end
end)

profileLoadButton:bindToEvent('onClick', function()
    local target = getSelectedProfileFromInput()
    if ConfigManager:load(target, false) then
        refreshConfigList()
    end
end)

profileDeleteButton:bindToEvent('onClick', function()
    refreshConfigList()
    if #configList == 0 then
        ui.notify({ title = "Configs", message = "No profiles to delete", duration = 3 })
        return
    end
    local target = getSelectedProfileFromInput()
    if ConfigManager:delete(target) then
        refreshConfigList()
    end
end)

refreshProfilesButton:bindToEvent('onClick', function()
    refreshConfigList()
    ui.notify({ title = "Configs", message = ("Profile list refreshed (%d)"):format(#configList), duration = 2 })
end)

autoloadToggle:bindToEvent('onToggle', function(state)
    ConfigManager:toggleAutoload(state, false)
    updateConfigLabels()
end)

setAutoloadButton:bindToEvent('onClick', function()
    local target = getSelectedProfileFromInput()
    ConfigManager:setAutoloadProfile(target, true)
    updateConfigLabels()
end)

loadAutoloadButton:bindToEvent('onClick', function()
    local target = sanitizeConfigName(ConfigManager.autoloadProfile)
    if ConfigManager:load(target, false) then
        refreshConfigList()
    end
end)

autoSaveToggle:bindToEvent('onToggle', function(state)
    if not features.config then
        features.config = {}
    end
    features.config.autoSave = state
end)

autoSaveIntervalSlider:bindToEvent('onValueChanged', function(val)
    if not features.config then
        features.config = {}
    end
    features.config.autoSaveInterval = math.clamp(tonumber(val) or 30, 10, 300)
end)

menuKey:bindToEvent('onToggle', function()
    window:setVisible(not window:getVisible())
end)

-- Auto-save profile loop
spawn(function()
    while true do
        local interval = math.clamp((features.config and tonumber(features.config.autoSaveInterval)) or 30, 10, 300)
        wait(interval)
        local autoSaveEnabled = not features.config or features.config.autoSave ~= false
        if autoSaveEnabled and window:getVisible() then
            ConfigManager:save(ConfigManager.current, true)
        end
    end
end)

refreshConfigList()

-- Apply current `features` to UI controls so loaded configs reflect in the interface
applyFeaturesToUI = function()
    pcall(function() aimbotToggle:setState(features.aimbot.enabled) end)
    pcall(function() fovSlider:setValue(features.aimbot.fov) end)
    pcall(function() smoothSlider:setValue((1 - features.aimbot.smooth) * 100) end)
    pcall(function() predictionSlider:setValue(features.aimbot.prediction) end)
    pcall(function() fovCircleToggle:setState(features.fovCircle) end)
    pcall(function() universalAimToggle:setState(features.aimbot.universal) end)

    pcall(function() autoclickerToggle:setState(features.autoclicker.enabled) end)
    pcall(function() cpsSlider:setValue(features.autoclicker.cps) end)

    pcall(function() killauraToggle:setState(features.killaura.enabled) end)
    pcall(function() rangeSlider:setValue(features.killaura.range) end)
    pcall(function() toolCheckToggle:setState(features.killaura.toolCheck) end)
    pcall(function() universalKillauraToggle:setState(features.killaura.universal) end)
    pcall(function() autoKillauraToggle:setState(features.killaura.auto) end)
    pcall(function() orbitToggle:setState(features.killaura.orbitEnabled) end)
    pcall(function() orbitRadiusSlider:setValue(features.killaura.orbitRadius) end)
    pcall(function() orbitSpeedSlider:setValue(features.killaura.orbitSpeed) end)
    pcall(function() killauraCpsSlider:setValue(features.killaura.cps) end)
    pcall(function() killauraTeamCheckToggle:setState(features.killaura.teamCheck) end)
    pcall(function() partsModeToggle:setState(features.killaura.partsMode) end)

    pcall(function() wallCheckToggle:setState(features.aimbot.wallCheck) end)
    pcall(function() stickyAimToggle:setState(features.aimbot.stickyAim) end)
    pcall(function() aimTeamCheckToggle:setState(features.aimbot.teamCheck) end)
    pcall(function() healthCheckToggle:setState(features.aimbot.healthCheck) end)
    pcall(function() minHealthSlider:setValue(features.aimbot.minHealth) end)

    pcall(function() circleColorPicker:setColor(features.circleColor) end)
    pcall(function() targetColorPicker:setColor(features.targetedColor) end)
    pcall(function() rainbowFovToggle:setState(features.rainbowFov) end)
    pcall(function() fullbrightToggle:setState(features.render and features.render.fullbright) end)
    pcall(function() customFovToggle:setState(features.render and features.render.customFov) end)
    pcall(function() cameraFovSlider:setValue(features.render and features.render.cameraFov or 70) end)
    pcall(function() crosshairToggle:setState(features.render and features.render.crosshair) end)
    pcall(function() crosshairSizeSlider:setValue(features.render and features.render.crosshairSize or 10) end)
    pcall(function() chamsToggle:setState(features.chams) end)

    -- ESP
    pcall(function() toggle:setState(ESP.Enabled) end)
    pcall(function() rainbowToggle:setState(ESP.Rainbow) end)
    pcall(function() rainbowTracerToggle:setState(ESP.RainbowTracers) end)
    pcall(function() speedSlider:setValue((features.rainbowSpeed or 0.002) * 1000) end)
    pcall(function() boxToggle:setState(ESP.ShowBoxes) end)
    pcall(function() nameToggle:setState(ESP.ShowNames) end)
    pcall(function() distToggle:setState(ESP.ShowDistance) end)
    pcall(function() healthToggle:setState(ESP.ShowHealth) end)
    pcall(function() teamToggle:setState(ESP.TeamColor) end)
    pcall(function() colorPicker:setColor(ESP.BoxColor) end)
    pcall(function() tracerToggle:setState(ESP.ShowTracers) end)
    pcall(function() tracerColorPicker:setColor(ESP.TracerColor) end)
    pcall(function() speedToggle:setState(features.speed and features.speed.enabled) end)
    pcall(function() speedMultiplierSlider:setValue(features.speed and features.speed.multiplier or 2) end)
    pcall(function() flyToggle:setState(features.fly and features.fly.enabled) end)
    pcall(function() flySpeedSlider:setValue(features.fly and features.fly.speed or 50) end)
    pcall(function() flyBypassToggle:setState(features.fly and features.fly.bedwars) end)
    pcall(function() bhopToggle:setState(features.bhop) end)
    pcall(function() noclipToggle:setState(features.movement and features.movement.noclip) end)
    pcall(function() infiniteJumpToggle:setState(features.movement and features.movement.infiniteJump) end)
    pcall(function() glideToggle:setState(features.movement and features.movement.glide) end)
    pcall(function() glideSpeedSlider:setValue(features.movement and features.movement.glideFallSpeed or 12) end)
    pcall(function() customJumpToggle:setState(features.movement and features.movement.customJump) end)
    pcall(function() jumpPowerSlider:setValue(features.movement and features.movement.jumpPower or 50) end)
    pcall(function() antiAfkToggle:setState(features.utilities and features.utilities.antiAfk) end)
    pcall(function() antiVoidToggle:setState(features.utilities and features.utilities.antiVoid) end)
    pcall(function() voidYSlider:setValue(features.utilities and features.utilities.voidY or -50) end)
    pcall(function() damageNotifyToggle:setState(features.utilities and features.utilities.damageNotify) end)
    pcall(function() dmgThresholdSlider:setValue(features.utilities and features.utilities.damageThreshold or 1) end)
    pcall(function() autoRespawnToggle:setState(features.utilities and features.utilities.autoRespawn) end)
    pcall(function() antiRagdollToggle:setState(features.utilities and features.utilities.antiRagdoll) end)
    pcall(function() autoloadToggle:setState(ConfigManager.autoloadEnabled ~= false) end)
    pcall(function() autoSaveToggle:setState(features.config and features.config.autoSave ~= false) end)
    pcall(function() autoSaveIntervalSlider:setValue(math.clamp((features.config and tonumber(features.config.autoSaveInterval)) or 30, 10, 300)) end)
    pcall(function() applyRenderEnhancements() end)
    pcall(function() updateHubLabels() end)
    pcall(function() refreshConfigList() end)
    pcall(function() updateConfigLabels() end)
    pcall(function() reachSlider:setValue(features.pvp and features.pvp.reach or 8) end)
end

-- Sync UI to loaded features after UI creation
pcall(function() applyFeaturesToUI() end)

ui.notify({
    title = 'rise.net COMBAT UPGRADE!',
    message = 'Game-ID Hub Routing\nUniversal + Preset Profiles\nAuto Clicker + Kill Aura\nSmart Anti-Void + Panic Disable\nV4 Profile Config + Autoload',
    duration = 8
})

print("=== rise.net v4.2 - HUB ROUTER + V4 PROFILE CONFIG ===")
