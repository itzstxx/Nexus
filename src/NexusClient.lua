--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║           NEXUS  —  NexusClient  v4.3                        ║
    ║           Hecho por EnanoTop1 (stx)                          ║
    ╠══════════════════════════════════════════════════════════════╣
    ║  NOVEDADES v4.3:                                             ║
    ║  · HOOK reescrito igual al script universal (hookmetamethod)  ║
    ║  · checkcaller() + ValidateArguments → cámara libre          ║
    ║  · Fallback getrawmetatable para exploits sin hookmetamethod  ║
    ║  · Panel 600×800, pinch dos dedos, Lista Blanca, colores ESP  ║
    ╚══════════════════════════════════════════════════════════════╝
]]

-- ══════════════════════════════════════════════════════════════
-- SERVICIOS
-- ══════════════════════════════════════════════════════════════
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local HttpService       = game:GetService("HttpService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera    = Workspace.CurrentCamera

local LOGO_IMAGE_ID = "rbxassetid://TU_ID_DEL_LOGO"
local CONFIG_FILE   = "nexus_config.json"

-- ══════════════════════════════════════════════════════════════
-- CONFIGURACIÓN PERSISTENTE
-- ══════════════════════════════════════════════════════════════
local DefaultConfig = {
    -- Silent Aim
    SilentAimEnabled  = false,
    HitChance         = 100,
    Manipulation      = false,
    VisibleCheck      = true,
    FovEnabled        = true,
    FovRadius         = 500,
    Snapline          = false,
    TargetPart        = "Random",   -- "Head" | "UpperTorso" | "LowerTorso" | "Random"
    -- Colores Aimbot (R,G,B por separado para serializar)
    FovColorR = 255, FovColorG = 255, FovColorB = 255,
    SnapColorR = 255, SnapColorG = 255, SnapColorB = 255,
    -- ESP
    EspEnabled        = false,
    EspBox            = true,
    EspSkeleton       = true,
    EspHealthBar      = true,
    EspDistance       = true,
    EspNames          = true,
    EspMaxDist        = 500,
    -- Colores ESP
    BoxColorR=0,   BoxColorG=220,  BoxColorB=255,
    SkelColorR=0,  SkelColorG=220, SkelColorB=255,
    NameColorR=255,NameColorG=255, NameColorB=255,
    -- Settings
    RoundToggles      = false,  -- apaga aimbot y esp al terminar ronda
    AutoLoadTheme     = false,
    -- Lista Blanca (array de nombres de usuario)
    Whitelist         = {},
}

local Config = {}

local function deepCopy(t)
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = deepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function loadConfig()
    if pcall(function()
        local raw = readfile(CONFIG_FILE)
        local decoded = HttpService:JSONDecode(raw)
        for k, v in pairs(DefaultConfig) do
            if decoded[k] ~= nil then
                Config[k] = decoded[k]
            else
                Config[k] = type(v) == "table" and deepCopy(v) or v
            end
        end
    end) then
        print("[NEXUS] Config cargada desde " .. CONFIG_FILE)
    else
        Config = deepCopy(DefaultConfig)
        print("[NEXUS] Config por defecto aplicada.")
    end
end

local function saveConfig()
    pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(Config))
    end)
end

loadConfig()

-- ══════════════════════════════════════════════════════════════
-- WHITELIST HELPERS
-- ══════════════════════════════════════════════════════════════
local function isWhitelisted(p)
    for _, name in ipairs(Config.Whitelist) do
        if name:lower() == p.Name:lower() then
            return true
        end
    end
    return false
end

local function addWhitelist(name)
    if name == "" then return false end
    for _, n in ipairs(Config.Whitelist) do
        if n:lower() == name:lower() then return false end
    end
    table.insert(Config.Whitelist, name)
    saveConfig()
    return true
end

local function removeWhitelist(name)
    for i, n in ipairs(Config.Whitelist) do
        if n:lower() == name:lower() then
            table.remove(Config.Whitelist, i)
            saveConfig()
            return true
        end
    end
    return false
end

-- ══════════════════════════════════════════════════════════════
-- LIMPIEZA
-- ══════════════════════════════════════════════════════════════
local oldGui = playerGui:FindFirstChild("NexusSystemUI")
if oldGui then oldGui:Destroy() end

-- ══════════════════════════════════════════════════════════════
-- SCREEN GUI
-- ══════════════════════════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name            = "NexusSystemUI"
gui.ResetOnSpawn    = false
gui.IgnoreGuiInset  = true
gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder    = 99
gui.Parent          = playerGui

-- ══════════════════════════════════════════════════════════════
-- UTILIDADES UI
-- ══════════════════════════════════════════════════════════════
local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = p; return c
end

local function stroke(p, col, thick, transp)
    local s = Instance.new("UIStroke")
    s.Color           = col or Color3.fromRGB(0,190,255)
    s.Thickness       = thick or 1
    s.Transparency    = transp or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p; return s
end

local function label(parent, text, x, y, w, h, size, font, color, xAlign)
    local l = Instance.new("TextLabel")
    l.Size               = UDim2.fromOffset(w or 200, h or 18)
    l.Position           = UDim2.fromOffset(x, y)
    l.BackgroundTransparency = 1
    l.Text               = text
    l.TextColor3         = color or Color3.fromRGB(200,248,255)
    l.Font               = font or Enum.Font.GothamMedium
    l.TextSize           = size or 12
    l.TextXAlignment     = xAlign or Enum.TextXAlignment.Left
    l.Parent             = parent
    return l
end

-- ══════════════════════════════════════════════════════════════
-- PANEL PRINCIPAL
-- ══════════════════════════════════════════════════════════════
local MIN_W, MIN_H = 480, 600
local panelW, panelH = 600, 800

local main = Instance.new("Frame")
main.Name                    = "NexusPanel"
main.Size                    = UDim2.fromOffset(panelW, panelH)
main.Position                = UDim2.new(0, 30, 0.5, -panelH/2)
main.BackgroundColor3        = Color3.fromRGB(4, 12, 24)
main.BackgroundTransparency  = 0.05
main.BorderSizePixel         = 0
main.ClipsDescendants        = true
main.Parent                  = gui
corner(main, 8)

local mainStroke = stroke(main, Color3.fromRGB(0, 190, 255), 2, 0.05)

local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,    Color3.fromRGB(0,  34,  70)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(5,  13,  26)),
    ColorSequenceKeypoint.new(1,    Color3.fromRGB(0,  78, 126)),
})
grad.Rotation = 35
grad.Parent   = main

-- Header
local headerH = 90
local header = Instance.new("Frame")
header.Size              = UDim2.new(1, 0, 0, headerH)
header.BackgroundTransparency = 1
header.Parent            = main

local logo = Instance.new("ImageLabel")
logo.Size               = UDim2.fromOffset(60, 60)
logo.Position           = UDim2.fromOffset(16, 14)
logo.BackgroundTransparency = 1
logo.Image              = LOGO_IMAGE_ID
logo.ImageColor3        = Color3.fromRGB(120, 232, 255)
logo.Parent             = header

local titleLbl = Instance.new("TextLabel")
titleLbl.Size               = UDim2.new(1,-100,0,32)
titleLbl.Position           = UDim2.fromOffset(88, 12)
titleLbl.BackgroundTransparency = 1
titleLbl.Text               = "NEXUS"
titleLbl.TextColor3         = Color3.fromRGB(205, 250, 255)
titleLbl.Font               = Enum.Font.GothamBlack
titleLbl.TextSize           = 28
titleLbl.TextXAlignment     = Enum.TextXAlignment.Left
titleLbl.Parent             = header

local subtitleLbl = Instance.new("TextLabel")
subtitleLbl.Size               = UDim2.new(1,-100,0,16)
subtitleLbl.Position           = UDim2.fromOffset(90, 46)
subtitleLbl.BackgroundTransparency = 1
subtitleLbl.Text               = "v4.3 — Hecho por EnanoTop1 (stx)"
subtitleLbl.TextColor3         = Color3.fromRGB(70, 210, 255)
subtitleLbl.Font               = Enum.Font.GothamMedium
subtitleLbl.TextSize           = 11
subtitleLbl.TextXAlignment     = Enum.TextXAlignment.Left
subtitleLbl.Parent             = header

-- Perfil card
local profileCard = Instance.new("Frame")
profileCard.Size              = UDim2.new(1,-32,0,40)
profileCard.Position          = UDim2.fromOffset(16, headerH)
profileCard.BackgroundColor3  = Color3.fromRGB(3,18,36)
profileCard.BackgroundTransparency = 0.15
profileCard.BorderSizePixel   = 0
profileCard.Parent            = main
corner(profileCard, 5)
stroke(profileCard, Color3.fromRGB(0,180,255), 1, 0.3)

local avatarImg = Instance.new("ImageLabel")
avatarImg.Size              = UDim2.fromOffset(30, 30)
avatarImg.Position          = UDim2.fromOffset(6, 5)
avatarImg.BackgroundTransparency = 0.4
avatarImg.BorderSizePixel   = 0
avatarImg.Image             = ("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=150&height=150&format=png"):format(player.UserId)
avatarImg.Parent            = profileCard
corner(avatarImg, 4)

label(profileCard, player.DisplayName, 44, 4,  260, 16, 13, Enum.Font.GothamBold,   Color3.fromRGB(210,248,255))
label(profileCard, "@"..player.Name.."  ·  ID "..player.UserId, 44, 22, 280, 13, 10, Enum.Font.GothamMedium, Color3.fromRGB(100,190,230))

-- Scanline
local scanLine = Instance.new("Frame")
scanLine.Size              = UDim2.new(1,-40,0,1)
scanLine.Position          = UDim2.fromOffset(20, headerH + 44)
scanLine.BackgroundColor3  = Color3.fromRGB(120,240,255)
scanLine.BackgroundTransparency = 0.2
scanLine.BorderSizePixel   = 0
scanLine.Parent            = main

-- ══════════════════════════════════════════════════════════════
-- TABS  (Aimbot | Visuals | Settings)
-- ══════════════════════════════════════════════════════════════
local tabY       = headerH + 48
local tabBarH    = 34
local contentY   = tabY + tabBarH + 6
local contentH   = panelH - contentY - 14

local tabBar = Instance.new("Frame")
tabBar.Size             = UDim2.new(1,-32,0,tabBarH)
tabBar.Position         = UDim2.fromOffset(16, tabY)
tabBar.BackgroundColor3 = Color3.fromRGB(3,14,26)
tabBar.BorderSizePixel  = 0
tabBar.Parent           = main
corner(tabBar, 5)
stroke(tabBar, Color3.fromRGB(0,160,255), 1, 0.4)

local tabNames  = {"Aimbot", "Visuals", "Settings"}
local tabBtns   = {}
local tabPages  = {}
local activeTab = 1

local function makeTabPage()
    local page = Instance.new("ScrollingFrame")
    page.Size              = UDim2.new(1,-32,0,contentH)
    page.Position          = UDim2.fromOffset(16, contentY)
    page.BackgroundColor3  = Color3.fromRGB(3,14,26)
    page.BackgroundTransparency = 0.2
    page.BorderSizePixel   = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = Color3.fromRGB(0,190,255)
    page.CanvasSize        = UDim2.new(0,0,0,0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible           = false
    page.Parent            = main
    corner(page, 5)
    stroke(page, Color3.fromRGB(0,160,255), 1, 0.35)
    local pad = Instance.new("UIPadding")
    pad.PaddingTop    = UDim.new(0,8)
    pad.PaddingLeft   = UDim.new(0,10)
    pad.PaddingRight  = UDim.new(0,10)
    pad.PaddingBottom = UDim.new(0,8)
    pad.Parent        = page
    local layout = Instance.new("UIListLayout")
    layout.SortOrder   = Enum.SortOrder.LayoutOrder
    layout.Padding     = UDim.new(0,7)
    layout.Parent      = page
    return page
end

for i, name in ipairs(tabNames) do
    local btn = Instance.new("TextButton")
    btn.Size              = UDim2.new(1/#tabNames, -4, 1, -6)
    btn.Position          = UDim2.new((i-1)/#tabNames, 2, 0, 3)
    btn.BackgroundColor3  = (i==1) and Color3.fromRGB(0,50,80) or Color3.fromRGB(4,18,30)
    btn.BorderSizePixel   = 0
    btn.Text              = name
    btn.TextColor3        = Color3.fromRGB(180,240,255)
    btn.Font              = Enum.Font.GothamBold
    btn.TextSize          = 12
    btn.AutoButtonColor   = false
    btn.Parent            = tabBar
    corner(btn, 4)
    tabBtns[i] = btn

    local page = makeTabPage()
    tabPages[i] = page

    btn.MouseButton1Click:Connect(function()
        for j, p in ipairs(tabPages) do
            p.Visible = (j == i)
            tabBtns[j].BackgroundColor3 = (j==i)
                and Color3.fromRGB(0,50,80) or Color3.fromRGB(4,18,30)
        end
        activeTab = i
    end)
end
tabPages[1].Visible = true

-- ══════════════════════════════════════════════════════════════
-- HELPERS para construir controles dentro de tabs
-- ══════════════════════════════════════════════════════════════
local function sectionLabel(page, text)
    local f = Instance.new("Frame")
    f.Size              = UDim2.new(1, 0, 0, 20)
    f.BackgroundTransparency = 1
    f.LayoutOrder       = 0
    f.Parent            = page
    local l = Instance.new("TextLabel")
    l.Size              = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.Text              = "— "..text.." —"
    l.TextColor3        = Color3.fromRGB(0, 200, 255)
    l.Font              = Enum.Font.GothamBlack
    l.TextSize          = 11
    l.TextXAlignment    = Enum.TextXAlignment.Left
    l.Parent            = f
    return f
end

local function makeToggle(page, text, configKey, callback)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = Color3.fromRGB(4,22,38)
    row.BorderSizePixel  = 0
    row.Parent           = page
    corner(row, 5)
    stroke(row, Color3.fromRGB(0,160,255), 1, 0.45)

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(1,-54,1,0)
    lbl.Position         = UDim2.fromOffset(10,0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = text
    lbl.TextColor3       = Color3.fromRGB(195,245,255)
    lbl.Font             = Enum.Font.GothamMedium
    lbl.TextSize         = 12
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.Parent           = row

    local togBg = Instance.new("Frame")
    togBg.Size             = UDim2.fromOffset(42,22)
    togBg.Position         = UDim2.new(1,-48,0.5,-11)
    togBg.BorderSizePixel  = 0
    togBg.Parent           = row
    corner(togBg, 11)

    local togKnob = Instance.new("Frame")
    togKnob.Size             = UDim2.fromOffset(18,18)
    togKnob.Position         = UDim2.fromOffset(2,2)
    togKnob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    togKnob.BorderSizePixel  = 0
    togKnob.Parent           = togBg
    corner(togKnob, 9)

    local function refreshToggle()
        local on = Config[configKey]
        togBg.BackgroundColor3 = on
            and Color3.fromRGB(0, 180, 80)
            or  Color3.fromRGB(40, 60, 75)
        TweenService:Create(togKnob, TweenInfo.new(0.12), {
            Position = on and UDim2.fromOffset(22,2) or UDim2.fromOffset(2,2)
        }):Play()
    end
    refreshToggle()

    local function onTap()
        Config[configKey] = not Config[configKey]
        refreshToggle()
        saveConfig()
        if callback then callback(Config[configKey]) end
    end

    local hitbox = Instance.new("TextButton")
    hitbox.Size              = UDim2.new(1,0,1,0)
    hitbox.BackgroundTransparency = 1
    hitbox.Text              = ""
    hitbox.ZIndex            = 2
    hitbox.Parent            = row
    hitbox.MouseButton1Click:Connect(onTap)

    return row, refreshToggle
end

local function makeSliderRow(page, text, configKey, minV, maxV, callback)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 52)
    row.BackgroundColor3 = Color3.fromRGB(4,22,38)
    row.BorderSizePixel  = 0
    row.Parent           = page
    corner(row, 5)
    stroke(row, Color3.fromRGB(0,160,255), 1, 0.45)

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(1,0,0,18)
    lbl.Position         = UDim2.fromOffset(10,6)
    lbl.BackgroundTransparency = 1
    lbl.Text             = text..": "..tostring(Config[configKey])
    lbl.TextColor3       = Color3.fromRGB(195,245,255)
    lbl.Font             = Enum.Font.GothamMedium
    lbl.TextSize         = 12
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.Parent           = row

    local bar = Instance.new("Frame")
    bar.Size             = UDim2.new(1,-20,0,8)
    bar.Position         = UDim2.fromOffset(10,30)
    bar.BackgroundColor3 = Color3.fromRGB(12,45,65)
    bar.BorderSizePixel  = 0
    bar.Parent           = row
    corner(bar, 8)

    local fill = Instance.new("Frame")
    local initAlpha = (Config[configKey]-minV)/(maxV-minV)
    fill.Size             = UDim2.new(math.clamp(initAlpha,0,1),0,1,0)
    fill.BackgroundColor3 = Color3.fromRGB(0,200,255)
    fill.BorderSizePixel  = 0
    fill.Parent           = bar
    corner(fill, 8)

    local dragging = false
    local function update(ix)
        local alpha = math.clamp((ix - bar.AbsolutePosition.X)/bar.AbsoluteSize.X, 0, 1)
        local value = math.floor(minV + (maxV-minV)*alpha)
        Config[configKey] = value
        fill.Size = UDim2.new(alpha,0,1,0)
        lbl.Text  = text..": "..tostring(value)
        if callback then callback(value) end
        saveConfig()
    end

    bar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; update(inp.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (
            inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch) then
            update(inp.Position.X)
        end
    end)
    return row
end

-- Color picker (botón que abre un mini-picker RGB simplificado)
local function makeColorRow(page, text, rKey, gKey, bKey, onChanged)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = Color3.fromRGB(4,22,38)
    row.BorderSizePixel  = 0
    row.Parent           = page
    corner(row, 5)
    stroke(row, Color3.fromRGB(0,160,255), 1, 0.45)

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(1,-50,1,0)
    lbl.Position         = UDim2.fromOffset(10,0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = text
    lbl.TextColor3       = Color3.fromRGB(195,245,255)
    lbl.Font             = Enum.Font.GothamMedium
    lbl.TextSize         = 12
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.Parent           = row

    local swatch = Instance.new("Frame")
    swatch.Size             = UDim2.fromOffset(28, 20)
    swatch.Position         = UDim2.new(1,-34,0.5,-10)
    swatch.BackgroundColor3 = Color3.fromRGB(Config[rKey],Config[gKey],Config[bKey])
    swatch.BorderSizePixel  = 0
    swatch.Parent           = row
    corner(swatch, 4)
    stroke(swatch, Color3.fromRGB(0,190,255), 1, 0.2)

    local function refreshSwatch()
        swatch.BackgroundColor3 = Color3.fromRGB(Config[rKey],Config[gKey],Config[bKey])
        if onChanged then onChanged() end
    end

    -- Cicla entre colores preset al tocar
    local presets = {
        {255,255,255}, {0,220,255}, {80,255,160},
        {255,80,80},   {255,200,0},{200,0,255},
    }
    local presetIdx = 1
    local hitbox = Instance.new("TextButton")
    hitbox.Size              = UDim2.new(1,0,1,0)
    hitbox.BackgroundTransparency = 1
    hitbox.Text              = ""
    hitbox.ZIndex            = 2
    hitbox.Parent            = row
    hitbox.MouseButton1Click:Connect(function()
        presetIdx = (presetIdx % #presets) + 1
        local p = presets[presetIdx]
        Config[rKey] = p[1]; Config[gKey] = p[2]; Config[bKey] = p[3]
        refreshSwatch()
        saveConfig()
    end)

    return row
end

-- Dropdown
local function makeDropdown(page, text, configKey, options, callback)
    local open = false
    local container = Instance.new("Frame")
    container.Size             = UDim2.new(1,0,0,34)
    container.BackgroundTransparency = 1
    container.ClipsDescendants = false
    container.Parent           = page

    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,0,0,34)
    row.BackgroundColor3 = Color3.fromRGB(4,22,38)
    row.BorderSizePixel  = 0
    row.Parent           = container
    corner(row, 5)
    stroke(row, Color3.fromRGB(0,160,255), 1, 0.45)

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(1,-60,1,0)
    lbl.Position         = UDim2.fromOffset(10,0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = text..": "..Config[configKey]
    lbl.TextColor3       = Color3.fromRGB(195,245,255)
    lbl.Font             = Enum.Font.GothamMedium
    lbl.TextSize         = 12
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.Parent           = row

    local arrow = Instance.new("TextLabel")
    arrow.Size             = UDim2.fromOffset(30,22)
    arrow.Position         = UDim2.new(1,-36,0.5,-11)
    arrow.BackgroundTransparency = 1
    arrow.Text             = "▾"
    arrow.TextColor3       = Color3.fromRGB(0,200,255)
    arrow.Font             = Enum.Font.GothamBold
    arrow.TextSize         = 16
    arrow.Parent           = row

    local dropList = Instance.new("Frame")
    dropList.Size             = UDim2.new(1,0,0,#options*30)
    dropList.Position         = UDim2.fromOffset(0,36)
    dropList.BackgroundColor3 = Color3.fromRGB(3,16,28)
    dropList.BorderSizePixel  = 0
    dropList.Visible          = false
    dropList.ZIndex           = 10
    dropList.Parent           = container
    corner(dropList, 5)
    stroke(dropList, Color3.fromRGB(0,160,255), 1, 0.3)

    for idx, opt in ipairs(options) do
        local ob = Instance.new("TextButton")
        ob.Size              = UDim2.new(1,0,0,28)
        ob.Position          = UDim2.fromOffset(0,(idx-1)*30)
        ob.BackgroundColor3  = Color3.fromRGB(4,22,38)
        ob.BorderSizePixel   = 0
        ob.Text              = opt
        ob.TextColor3        = (Config[configKey]==opt)
            and Color3.fromRGB(80,255,160) or Color3.fromRGB(190,240,255)
        ob.Font              = Enum.Font.GothamMedium
        ob.TextSize          = 12
        ob.AutoButtonColor   = false
        ob.ZIndex            = 11
        ob.Parent            = dropList

        ob.MouseButton1Click:Connect(function()
            Config[configKey] = opt
            lbl.Text = text..": "..opt
            for _, b in ipairs(dropList:GetChildren()) do
                if b:IsA("TextButton") then
                    b.TextColor3 = (b.Text==opt)
                        and Color3.fromRGB(80,255,160) or Color3.fromRGB(190,240,255)
                end
            end
            dropList.Visible = false
            open = false
            container.Size = UDim2.new(1,0,0,34)
            saveConfig()
            if callback then callback(opt) end
        end)
    end

    local hitbox = Instance.new("TextButton")
    hitbox.Size              = UDim2.new(1,0,1,0)
    hitbox.BackgroundTransparency = 1
    hitbox.Text              = ""
    hitbox.ZIndex            = 2
    hitbox.Parent            = row
    hitbox.MouseButton1Click:Connect(function()
        open = not open
        dropList.Visible = open
        container.Size   = open
            and UDim2.new(1,0,0,34 + #options*30)
            or  UDim2.new(1,0,0,34)
        arrow.Text = open and "▴" or "▾"
    end)

    return container
end

-- ══════════════════════════════════════════════════════════════
-- TAB 1: AIMBOT
-- ══════════════════════════════════════════════════════════════
local pageAim = tabPages[1]

sectionLabel(pageAim, "Silent Aim")
makeToggle(pageAim,    "Silent Aim",    "SilentAimEnabled")
makeToggle(pageAim,    "VisibleCheck",  "VisibleCheck")
makeToggle(pageAim,    "Manipulation",  "Manipulation")
makeSliderRow(pageAim, "HitChance %",   "HitChance",  1, 100)

sectionLabel(pageAim, "FOV")
makeToggle(pageAim,    "FOV Circle",    "FovEnabled")
makeSliderRow(pageAim, "Fov Radius",    "FovRadius",  1, 500)
makeColorRow(pageAim,  "FOV Color",     "FovColorR","FovColorG","FovColorB")

sectionLabel(pageAim, "Snapline")
makeToggle(pageAim,    "Snapline",      "Snapline")
makeColorRow(pageAim,  "Snapline Color","SnapColorR","SnapColorG","SnapColorB")

sectionLabel(pageAim, "Target Part")
makeDropdown(pageAim, "Target Part", "TargetPart",
    {"Head","UpperTorso","LowerTorso","Random"})

-- ══════════════════════════════════════════════════════════════
-- TAB 2: VISUALS (ESP)
-- ══════════════════════════════════════════════════════════════
local pageVis = tabPages[2]

sectionLabel(pageVis, "ESP")
makeToggle(pageVis, "ESP Enabled",   "EspEnabled")
makeToggle(pageVis, "Box",           "EspBox")
makeColorRow(pageVis,"Box Color",    "BoxColorR","BoxColorG","BoxColorB")
makeToggle(pageVis, "Skeleton",      "EspSkeleton")
makeColorRow(pageVis,"Skeleton Color","SkelColorR","SkelColorG","SkelColorB")
makeToggle(pageVis, "Health Bar",    "EspHealthBar")
makeToggle(pageVis, "Distancia",     "EspDistance")
makeToggle(pageVis, "Nombres",       "EspNames")
makeColorRow(pageVis,"Name Color",   "NameColorR","NameColorG","NameColorB")
makeSliderRow(pageVis,"Dist Máx",    "EspMaxDist", 50, 1000)

-- ══════════════════════════════════════════════════════════════
-- TAB 3: SETTINGS
-- ══════════════════════════════════════════════════════════════
local pageSet = tabPages[3]

sectionLabel(pageSet, "General")
makeToggle(pageSet, "Round Toggles",   "RoundToggles")   -- apaga aim/esp al fin de ronda
makeToggle(pageSet, "Auto Load Theme", "AutoLoadTheme")

-- ── LISTA BLANCA ──────────────────────────────────────────────
sectionLabel(pageSet, "Lista Blanca (Whitelist)")

-- Caja de texto + botón Agregar
do
    local inputRow = Instance.new("Frame")
    inputRow.Size             = UDim2.new(1,0,0,34)
    inputRow.BackgroundColor3 = Color3.fromRGB(4,22,38)
    inputRow.BorderSizePixel  = 0
    inputRow.Parent           = pageSet
    corner(inputRow, 5)
    stroke(inputRow, Color3.fromRGB(0,160,255), 1, 0.45)

    local nameBox = Instance.new("TextBox")
    nameBox.Size              = UDim2.new(1,-80,1,-8)
    nameBox.Position          = UDim2.fromOffset(6,4)
    nameBox.BackgroundColor3  = Color3.fromRGB(3,14,26)
    nameBox.BorderSizePixel   = 0
    nameBox.Text              = ""
    nameBox.PlaceholderText   = "Nombre de usuario..."
    nameBox.PlaceholderColor3 = Color3.fromRGB(90,130,160)
    nameBox.TextColor3        = Color3.fromRGB(200,248,255)
    nameBox.Font              = Enum.Font.GothamMedium
    nameBox.TextSize          = 12
    nameBox.ClearTextOnFocus  = false
    nameBox.Parent            = inputRow
    corner(nameBox, 4)

    local addBtn = Instance.new("TextButton")
    addBtn.Size              = UDim2.fromOffset(66,26)
    addBtn.Position          = UDim2.new(1,-72,0.5,-13)
    addBtn.BackgroundColor3  = Color3.fromRGB(0,50,30)
    addBtn.BorderSizePixel   = 0
    addBtn.Text              = "+ Add"
    addBtn.TextColor3        = Color3.fromRGB(80,255,160)
    addBtn.Font              = Enum.Font.GothamBold
    addBtn.TextSize          = 11
    addBtn.AutoButtonColor   = false
    addBtn.Parent            = inputRow
    corner(addBtn, 4)
    stroke(addBtn, Color3.fromRGB(0,200,80), 1, 0.3)

    -- Lista dinámica de jugadores en WL
    local wlListFrame = Instance.new("Frame")
    wlListFrame.Size             = UDim2.new(1,0,0,0)
    wlListFrame.BackgroundTransparency = 1
    wlListFrame.BorderSizePixel  = 0
    wlListFrame.AutomaticSize    = Enum.AutomaticSize.Y
    wlListFrame.Parent           = pageSet
    local wlLayout = Instance.new("UIListLayout")
    wlLayout.SortOrder  = Enum.SortOrder.LayoutOrder
    wlLayout.Padding    = UDim.new(0,4)
    wlLayout.Parent     = wlListFrame

    local function rebuildWLList()
        for _, c in ipairs(wlListFrame:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        for _, name in ipairs(Config.Whitelist) do
            local entry = Instance.new("Frame")
            entry.Size             = UDim2.new(1,0,0,28)
            entry.BackgroundColor3 = Color3.fromRGB(5,25,15)
            entry.BorderSizePixel  = 0
            entry.Parent           = wlListFrame
            corner(entry, 4)
            stroke(entry, Color3.fromRGB(0,180,80), 1, 0.4)

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size             = UDim2.new(1,-40,1,0)
            nameLbl.Position         = UDim2.fromOffset(8,0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text             = "✓ "..name
            nameLbl.TextColor3       = Color3.fromRGB(80,255,160)
            nameLbl.Font             = Enum.Font.GothamMedium
            nameLbl.TextSize         = 11
            nameLbl.TextXAlignment   = Enum.TextXAlignment.Left
            nameLbl.Parent           = entry

            local delBtn = Instance.new("TextButton")
            delBtn.Size              = UDim2.fromOffset(30,20)
            delBtn.Position          = UDim2.new(1,-34,0.5,-10)
            delBtn.BackgroundColor3  = Color3.fromRGB(60,10,10)
            delBtn.BorderSizePixel   = 0
            delBtn.Text              = "✕"
            delBtn.TextColor3        = Color3.fromRGB(255,80,80)
            delBtn.Font              = Enum.Font.GothamBold
            delBtn.TextSize          = 11
            delBtn.AutoButtonColor   = false
            delBtn.Parent            = entry
            corner(delBtn, 4)
            delBtn.MouseButton1Click:Connect(function()
                removeWhitelist(name)
                rebuildWLList()
            end)
        end
    end

    rebuildWLList()

    addBtn.MouseButton1Click:Connect(function()
        local n = nameBox.Text:match("^%s*(.-)%s*$")
        if addWhitelist(n) then
            nameBox.Text = ""
            rebuildWLList()
            addBtn.Text = "✅"
            task.delay(1, function() addBtn.Text = "+ Add" end)
        else
            addBtn.Text = "Ya existe"
            task.delay(1.2, function() addBtn.Text = "+ Add" end)
        end
    end)
end

sectionLabel(pageSet, "Config")

-- Botón guardar config
do
    local btn = Instance.new("TextButton")
    btn.Size              = UDim2.new(1,0,0,36)
    btn.BackgroundColor3  = Color3.fromRGB(0,50,30)
    btn.BorderSizePixel   = 0
    btn.Text              = "💾  Guardar Config"
    btn.TextColor3        = Color3.fromRGB(100,255,160)
    btn.Font              = Enum.Font.GothamBold
    btn.TextSize          = 13
    btn.AutoButtonColor   = false
    btn.Parent            = pageSet
    corner(btn, 5)
    stroke(btn, Color3.fromRGB(0,200,80), 1, 0.3)
    btn.MouseButton1Click:Connect(function()
        saveConfig()
        btn.Text = "✅  Guardado!"
        task.delay(1.5, function() btn.Text = "💾  Guardar Config" end)
    end)
end

-- Botón reset config
do
    local btn = Instance.new("TextButton")
    btn.Size              = UDim2.new(1,0,0,36)
    btn.BackgroundColor3  = Color3.fromRGB(50,10,10)
    btn.BorderSizePixel   = 0
    btn.Text              = "🔄  Resetear Config"
    btn.TextColor3        = Color3.fromRGB(255,100,100)
    btn.Font              = Enum.Font.GothamBold
    btn.TextSize          = 13
    btn.AutoButtonColor   = false
    btn.Parent            = pageSet
    corner(btn, 5)
    stroke(btn, Color3.fromRGB(200,0,0), 1, 0.3)
    btn.MouseButton1Click:Connect(function()
        Config = deepCopy(DefaultConfig)
        saveConfig()
        btn.Text = "✅  Reseteado — recarga el script"
        task.delay(2, function() btn.Text = "🔄  Resetear Config" end)
    end)
end

sectionLabel(pageSet, "Info")
do
    local info = Instance.new("TextLabel")
    info.Size              = UDim2.new(1,0,0,80)
    info.BackgroundColor3  = Color3.fromRGB(3,14,26)
    info.BackgroundTransparency = 0.3
    info.BorderSizePixel   = 0
    info.Text              = "NEXUS v4.3\nHecho por EnanoTop1 (stx)\n\nConfig: "..CONFIG_FILE.."\nUser: "..player.Name
    info.TextColor3        = Color3.fromRGB(140,210,255)
    info.Font              = Enum.Font.GothamMedium
    info.TextSize          = 11
    info.TextWrapped       = true
    info.Parent            = pageSet
    corner(info, 5)
end

-- ══════════════════════════════════════════════════════════════
-- FOV CIRCLE + SNAPLINE (Drawing)
-- ══════════════════════════════════════════════════════════════
local fovCircle = Drawing.new("Circle")
fovCircle.Visible   = false
fovCircle.Thickness = 1.5
fovCircle.Filled    = false

local snapLineDraw = Drawing.new("Line")
snapLineDraw.Visible   = false
snapLineDraw.Thickness = 1.5

-- ══════════════════════════════════════════════════════════════
-- ESP DRAWINGS
-- ══════════════════════════════════════════════════════════════
local espObjects = {}

local SKELETON_PAIRS = {
    {"Head","UpperTorso"},
    {"UpperTorso","LowerTorso"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
}

local function newLine(col)
    local l = Drawing.new("Line")
    l.Color     = col or Color3.fromRGB(0,255,200)
    l.Thickness = 1
    l.Visible   = false
    return l
end
local function newText(size, col)
    local t = Drawing.new("Text")
    t.Size    = size or 13
    t.Color   = col  or Color3.fromRGB(255,255,255)
    t.Outline = true
    t.Visible = false
    return t
end
local function newRect(col, fill)
    local r = Drawing.new("Square")
    r.Color     = col  or Color3.fromRGB(0,255,200)
    r.Filled    = fill or false
    r.Thickness = 1.5
    r.Visible   = false
    return r
end

local function createEspForPlayer(p)
    if p == player then return end
    local obj = {
        box       = newRect(Color3.fromRGB(0,220,255)),
        nameTag   = newText(13, Color3.fromRGB(255,255,255)),
        distTag   = newText(11, Color3.fromRGB(160,230,255)),
        healthBg  = newRect(Color3.fromRGB(30,30,30), true),
        healthBar = newRect(Color3.fromRGB(80,255,80), true),
        skeleton  = {},
    }
    for _ = 1, #SKELETON_PAIRS do
        table.insert(obj.skeleton, newLine(Color3.fromRGB(0,220,255)))
    end
    espObjects[p] = obj
end

local function removeEspForPlayer(p)
    local obj = espObjects[p]
    if not obj then return end
    obj.box:Remove(); obj.nameTag:Remove(); obj.distTag:Remove()
    obj.healthBg:Remove(); obj.healthBar:Remove()
    for _, l in ipairs(obj.skeleton) do l:Remove() end
    espObjects[p] = nil
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= player then createEspForPlayer(p) end
end
Players.PlayerAdded:Connect(createEspForPlayer)
Players.PlayerRemoving:Connect(removeEspForPlayer)

-- ══════════════════════════════════════════════════════════════
-- SILENT AIM — LÓGICA ARREGLADA
-- ══════════════════════════════════════════════════════════════
local function getTargetPart(char)
    local part = Config.TargetPart
    if part == "Random" then
        local r = math.random(100)
        if r <= 30 then
            part = "Head"
        elseif r <= 80 then
            part = "UpperTorso"
        else
            part = "LowerTorso"
        end
    end
    return char:FindFirstChild(part)
        or char:FindFirstChild("HumanoidRootPart")
end

local function isVisible(part)
    local origin = camera.CFrame.Position
    local dir    = (part.Position - origin)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {player.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local result = Workspace:Raycast(origin, dir, params)
    if not result then return true end
    return result.Instance:IsDescendantOf(part.Parent)
end

local function getBestTarget()
    local center  = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    local bestP   = nil
    local bestD   = math.huge

    for _, p in ipairs(Players:GetPlayers()) do
        if p == player then continue end
        -- WHITELIST: si está en la lista, skip
        if isWhitelisted(p) then continue end

        local char = p.Character
        if not char then continue end
        local hum  = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not hum or hum.Health <= 0 or not root then continue end

        local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
        if not onScreen then continue end

        local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if dist2D > Config.FovRadius then continue end

        if Config.VisibleCheck then
            local ok, vis = pcall(isVisible, root)
            if ok and not vis then continue end
        end

        if dist2D < bestD then
            bestD = dist2D
            bestP = p
        end
    end
    return bestP
end

-- Hook metatables para silent aim
-- ══════════════════════════════════════════════════════════════
-- FLAG DE DISPARO — solo interceptamos raycasts mientras el
-- jugador está presionando el botón de ataque/tap en pantalla.
-- Esto evita que los raycasts de cámara sean redirigidos.
-- ══════════════════════════════════════════════════════════════
local isFiring     = false
local fireDebounce = 0   -- timestamp del último disparo

-- Detecta tap en la mitad derecha de la pantalla (zona de ataque en móvil)
-- y clicks de ratón en PC
local function onFireStart(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        isFiring = true; fireDebounce = os.clock()
    elseif inp.UserInputType == Enum.UserInputType.Touch then
        -- Solo zona derecha de pantalla (botones Puño/Teléfono)
        local vp = camera.ViewportSize
        if inp.Position.X > vp.X * 0.35 and not main.Visible then
            isFiring = true; fireDebounce = os.clock()
        elseif inp.Position.X > vp.X * 0.35 then
            isFiring = true; fireDebounce = os.clock()
        end
    end
end
local function onFireEnd(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        -- Pequeño delay para que el raycast del juego alcance a procesarse
        task.delay(0.08, function() isFiring = false end)
    end
end

UserInputService.InputBegan:Connect(onFireStart)
UserInputService.InputEnded:Connect(onFireEnd)

-- También detectamos activación por tool (arma equipada)
local function watchTool(tool)
    if not tool then return end
    tool.Activated:Connect(function()
        isFiring = true; fireDebounce = os.clock()
        task.delay(0.15, function() isFiring = false end)
    end)
end
local function watchChar(char)
    if not char then return end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then watchTool(tool) end
    end
    char.ChildAdded:Connect(function(c)
        if c:IsA("Tool") then watchTool(c) end
    end)
end
watchChar(player.Character)
player.CharacterAdded:Connect(watchChar)


-- ══════════════════════════════════════════════════════════════
-- SILENT AIM HOOK  (mismo patrón del script universal que funciona)
-- Diferencias clave vs versión anterior:
--   · hookmetamethod en vez de getrawmetatable+setreadonly
--   · checkcaller() para no interceptar nuestros propios calls
--   · ValidateArguments verifica tipos antes de redirigir
--     → esto evita interceptar raycasts de cámara/movimiento
--   · Args indexados correctamente: en __namecall con (...)
--     Arguments[1]=self, [2]=origin/ray, [3]=dir/params
-- ══════════════════════════════════════════════════════════════

-- Estructura de argumentos esperados por método (igual que el script universal)
local ExpectedArgs = {
    FindPartOnRayWithIgnoreList = { Required = 3,
        Types = {"Instance","Ray","table","boolean","boolean"} },
    FindPartOnRayWithWhitelist  = { Required = 3,
        Types = {"Instance","Ray","table","boolean"} },
    FindPartOnRay               = { Required = 2,
        Types = {"Instance","Ray","Instance","boolean","boolean"} },
    Raycast                     = { Required = 3,
        Types = {"Instance","Vector3","Vector3","RaycastParams"} },
}

local function validateArgs(args, schema)
    if #args < schema.Required then return false end
    local matches = 0
    for i, arg in ipairs(args) do
        if schema.Types[i] and typeof(arg) == schema.Types[i] then
            matches = matches + 1
        end
    end
    return matches >= schema.Required
end

local function getDirectionTo(origin, position)
    return (position - origin).Unit * 1000
end

local function applyManipulation(dir)
    if Config.Manipulation then
        return dir + Vector3.new(
            math.random(-5,5)*0.01,
            math.random(-5,5)*0.01,
            math.random(-5,5)*0.01)
    end
    return dir
end

local saHookOk, saHookErr = pcall(function()
    local oldNamecallSA
    oldNamecallSA = hookmetamethod(game, "__namecall", newcclosure(function(...)
        local Method    = getnamecallmethod()
        local Arguments = {...}   -- [1]=self, [2..n]=args reales
        local self_obj  = Arguments[1]

        -- Condiciones para interceptar (igual que el script universal)
        if Config.SilentAimEnabled
        and self_obj == Workspace
        and not checkcaller()
        and math.random(100) <= Config.HitChance then

            local hitPart = nil

            -- ── FindPartOnRayWithIgnoreList ──────────────────
            if Method == "FindPartOnRayWithIgnoreList"
            and validateArgs(Arguments, ExpectedArgs.FindPartOnRayWithIgnoreList) then
                local target = getBestTarget()
                if target and target.Character then
                    hitPart = getTargetPart(target.Character)
                end
                if hitPart then
                    local ray    = Arguments[2]
                    local origin = ray.Origin
                    local dir    = applyManipulation(getDirectionTo(origin, hitPart.Position))
                    Arguments[2] = Ray.new(origin, dir)
                    return oldNamecallSA(unpack(Arguments))
                end

            -- ── FindPartOnRayWithWhitelist ───────────────────
            elseif Method == "FindPartOnRayWithWhitelist"
            and validateArgs(Arguments, ExpectedArgs.FindPartOnRayWithWhitelist) then
                local target = getBestTarget()
                if target and target.Character then
                    hitPart = getTargetPart(target.Character)
                end
                if hitPart then
                    local ray    = Arguments[2]
                    local origin = ray.Origin
                    local dir    = applyManipulation(getDirectionTo(origin, hitPart.Position))
                    Arguments[2] = Ray.new(origin, dir)
                    return oldNamecallSA(unpack(Arguments))
                end

            -- ── FindPartOnRay ────────────────────────────────
            elseif (Method == "FindPartOnRay" or Method == "findPartOnRay")
            and validateArgs(Arguments, ExpectedArgs.FindPartOnRay) then
                local target = getBestTarget()
                if target and target.Character then
                    hitPart = getTargetPart(target.Character)
                end
                if hitPart then
                    local ray    = Arguments[2]
                    local origin = ray.Origin
                    local dir    = applyManipulation(getDirectionTo(origin, hitPart.Position))
                    Arguments[2] = Ray.new(origin, dir)
                    return oldNamecallSA(unpack(Arguments))
                end

            -- ── Raycast ──────────────────────────────────────
            elseif Method == "Raycast"
            and validateArgs(Arguments, ExpectedArgs.Raycast) then
                local target = getBestTarget()
                if target and target.Character then
                    hitPart = getTargetPart(target.Character)
                end
                if hitPart then
                    local origin = Arguments[2]  -- Vector3
                    Arguments[3] = applyManipulation(getDirectionTo(origin, hitPart.Position))
                    return oldNamecallSA(unpack(Arguments))
                end
            end
        end

        return oldNamecallSA(...)
    end))
end)

if not saHookOk then
    -- hookmetamethod no disponible en este exploit, usar fallback getrawmetatable
    warn("[NEXUS] hookmetamethod falló ("..tostring(saHookErr).."), usando fallback...")
    local mt = getrawmetatable and getrawmetatable(game)
    if mt then
        pcall(function()
            setreadonly(mt, false)
            local oldNC = mt.__namecall
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if Config.SilentAimEnabled
                and self == Workspace
                and math.random(100) <= Config.HitChance
                and (method=="Raycast" or method=="FindPartOnRay"
                  or method=="FindPartOnRayWithIgnoreList") then
                    local args = {...}
                    -- validación por tipos para no tocar raycasts de cámara
                    if method == "Raycast" and typeof(args[1])=="Vector3" and typeof(args[2])=="Vector3" then
                        local target = getBestTarget()
                        if target and target.Character then
                            local part = getTargetPart(target.Character)
                            if part then
                                args[2] = applyManipulation(getDirectionTo(args[1], part.Position))
                                return oldNC(self, table.unpack(args))
                            end
                        end
                    elseif method ~= "Raycast" and typeof(args[1])=="Ray" then
                        local target = getBestTarget()
                        if target and target.Character then
                            local part = getTargetPart(target.Character)
                            if part then
                                local origin = args[1].Origin
                                local dir    = applyManipulation(getDirectionTo(origin, part.Position))
                                args[1]      = Ray.new(origin, dir)
                                return oldNC(self, table.unpack(args))
                            end
                        end
                    end
                end
                return oldNC(self, ...)
            end)
            setreadonly(mt, true)
        end)
    end
end

-- Round Toggles: detecta fin de ronda (Humanoid muriendo)
if Config.RoundToggles then
    player.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid")
        hum.Died:Connect(function()
            -- pequeño delay para no interferir con respawn
            task.delay(0.5, function()
                if Config.RoundToggles then
                    Config.SilentAimEnabled = false
                    Config.EspEnabled       = false
                    saveConfig()
                    syncFAB()
                end
            end)
        end)
    end)
end

-- ══════════════════════════════════════════════════════════════
-- RENDER STEP — ESP + FOV + Snapline con colores dinámicos
-- ══════════════════════════════════════════════════════════════
RunService.RenderStepped:Connect(function()
    local vpSize   = camera.ViewportSize
    local center2D = Vector2.new(vpSize.X/2, vpSize.Y/2)
    local myChar   = player.Character
    local myRoot   = myChar and myChar:FindFirstChild("HumanoidRootPart")

    -- FOV Circle
    fovCircle.Visible = Config.FovEnabled and Config.SilentAimEnabled
    if fovCircle.Visible then
        fovCircle.Position = center2D
        fovCircle.Radius   = Config.FovRadius
        fovCircle.Color    = Color3.fromRGB(Config.FovColorR, Config.FovColorG, Config.FovColorB)
    end

    -- Colores ESP del frame actual
    local boxCol  = Color3.fromRGB(Config.BoxColorR,  Config.BoxColorG,  Config.BoxColorB)
    local skelCol = Color3.fromRGB(Config.SkelColorR, Config.SkelColorG, Config.SkelColorB)
    local namCol  = Color3.fromRGB(Config.NameColorR, Config.NameColorG, Config.NameColorB)
    local snapCol = Color3.fromRGB(Config.SnapColorR, Config.SnapColorG, Config.SnapColorB)

    local snapTarget = nil
    if Config.Snapline and Config.SilentAimEnabled then
        snapTarget = getBestTarget()
    end

    -- ESP
    for p, obj in pairs(espObjects) do
        local active = Config.EspEnabled and p.Character ~= nil
        local char   = p.Character

        local function allOff()
            obj.box.Visible=false; obj.nameTag.Visible=false
            obj.distTag.Visible=false; obj.healthBar.Visible=false
            obj.healthBg.Visible=false
            for _, l in ipairs(obj.skeleton) do l.Visible=false end
        end

        if not active then allOff(); continue end

        local root = char:FindFirstChild("HumanoidRootPart")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then allOff(); continue end

        local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
        if not onScreen then allOff(); continue end

        local dist3D = myRoot
            and math.floor((root.Position - myRoot.Position).Magnitude) or 0
        if dist3D > Config.EspMaxDist then allOff(); continue end

        local sp = Vector2.new(screenPos.X, screenPos.Y)

        local head = char:FindFirstChild("Head")
        local foot = char:FindFirstChild("LeftFoot") or root
        local topSP, botSP
        if head and foot then
            local t = camera:WorldToViewportPoint(head.Position+Vector3.new(0,0.6,0))
            local b = camera:WorldToViewportPoint(foot.Position-Vector3.new(0,0.2,0))
            topSP = Vector2.new(t.X, t.Y)
            botSP = Vector2.new(b.X, b.Y)
        else
            topSP = sp-Vector2.new(0,50); botSP = sp+Vector2.new(0,50)
        end

        local boxH = math.abs(botSP.Y-topSP.Y)
        local boxW = boxH*0.45

        -- Box
        obj.box.Visible = Config.EspBox
        obj.box.Color   = boxCol
        if Config.EspBox then
            obj.box.Position = Vector2.new(sp.X-boxW/2, topSP.Y)
            obj.box.Size     = Vector2.new(boxW, boxH)
        end

        -- Nombre
        obj.nameTag.Visible = Config.EspNames
        obj.nameTag.Color   = namCol
        if Config.EspNames then
            obj.nameTag.Text     = p.DisplayName
            obj.nameTag.Position = Vector2.new(sp.X-boxW/2, topSP.Y-18)
        end

        -- Distancia
        obj.distTag.Visible = Config.EspDistance
        if Config.EspDistance then
            obj.distTag.Text     = dist3D.."m"
            obj.distTag.Position = Vector2.new(sp.X-boxW/2, botSP.Y+2)
        end

        -- Health Bar
        local hp = hum.Health/math.max(hum.MaxHealth,1)
        obj.healthBg.Visible  = Config.EspHealthBar
        obj.healthBar.Visible = Config.EspHealthBar
        if Config.EspHealthBar then
            local bx = sp.X-boxW/2-8
            obj.healthBg.Position = Vector2.new(bx, topSP.Y)
            obj.healthBg.Size     = Vector2.new(4, boxH)
            obj.healthBg.Color    = Color3.fromRGB(30,30,30)
            local barH = boxH*hp
            obj.healthBar.Position = Vector2.new(bx, topSP.Y+boxH-barH)
            obj.healthBar.Size     = Vector2.new(4, barH)
            obj.healthBar.Color    = Color3.fromRGB(math.floor(255*(1-hp)),math.floor(255*hp),0)
        end

        -- Skeleton
        for si, pair in ipairs(SKELETON_PAIRS) do
            local pA = char:FindFirstChild(pair[1])
            local pB = char:FindFirstChild(pair[2])
            local line = obj.skeleton[si]
            line.Color = skelCol
            if Config.EspSkeleton and pA and pB then
                local sA, onA = camera:WorldToViewportPoint(pA.Position)
                local sB, onB = camera:WorldToViewportPoint(pB.Position)
                line.Visible = onA and onB
                if onA and onB then
                    line.From = Vector2.new(sA.X,sA.Y)
                    line.To   = Vector2.new(sB.X,sB.Y)
                end
            else
                line.Visible = false
            end
        end

        -- Snapline al target
        if snapTarget == p then
            snapLineDraw.Visible = true
            snapLineDraw.From    = center2D
            snapLineDraw.To      = sp
            snapLineDraw.Color   = snapCol
        end
    end

    if not (Config.Snapline and Config.SilentAimEnabled and snapTarget) then
        snapLineDraw.Visible = false
    end
end)

-- ══════════════════════════════════════════════════════════════
-- DRAG PANEL
-- ══════════════════════════════════════════════════════════════
do
    local dragging, dragStart, startPos = false, nil, nil
    local dragHandle = Instance.new("TextButton")
    dragHandle.Size              = UDim2.new(1,0,0,88)
    dragHandle.Position          = UDim2.fromOffset(0,0)
    dragHandle.BackgroundTransparency = 1
    dragHandle.Text              = ""
    dragHandle.ZIndex            = 5
    dragHandle.Parent            = main

    dragHandle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = inp.Position; startPos = main.Position
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
-- RESIZE — esquina (PC) + PINCH DOS DEDOS (móvil)
-- ══════════════════════════════════════════════════════════════
do
    -- ── Esquina arrastrable (PC y un dedo móvil) ──
    local rh = Instance.new("TextButton")
    rh.Size              = UDim2.fromOffset(28,28)
    rh.Position          = UDim2.new(1,-28,1,-28)
    rh.BackgroundColor3  = Color3.fromRGB(0,170,255)
    rh.BackgroundTransparency = 0.3
    rh.Text              = "⤡"
    rh.TextColor3        = Color3.fromRGB(200,245,255)
    rh.TextSize          = 15
    rh.Font              = Enum.Font.GothamBold
    rh.BorderSizePixel   = 0
    rh.ZIndex            = 10
    rh.Parent            = main
    corner(rh, 5)

    local resizing, resizeStart, startSz = false, nil, nil
    rh.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            resizing=true; resizeStart=inp.Position; startSz=main.AbsoluteSize
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            resizing=false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if resizing and (inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch) then
            local d  = inp.Position - resizeStart
            local nW = math.clamp(startSz.X+d.X, MIN_W, 900)
            local nH = math.clamp(startSz.Y+d.Y, MIN_H, 1000)
            main.Size = UDim2.fromOffset(nW, nH)
        end
    end)

    -- ── Pinch con dos dedos para redimensionar (móvil) ──
    local touches     = {}  -- {id -> Vector2}
    local pinchStartDist = nil
    local pinchStartSz   = nil

    local function getTouchCount()
        local n = 0
        for _ in pairs(touches) do n = n + 1 end
        return n
    end
    local function getTouchDist()
        local pts = {}
        for _, p in pairs(touches) do table.insert(pts, p) end
        if #pts < 2 then return nil end
        return (pts[1] - pts[2]).Magnitude
    end

    -- Usamos InputBegan/Changed/Ended globales para rastrear touches sobre el panel
    UserInputService.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.Touch then return end
        -- Solo si el toque empieza dentro del panel
        local abs = main.AbsolutePosition
        local sz  = main.AbsoluteSize
        local px, py = inp.Position.X, inp.Position.Y
        if px < abs.X or px > abs.X+sz.X then return end
        if py < abs.Y or py > abs.Y+sz.Y then return end
        touches[inp.KeyCode.Value ~= 0 and inp.KeyCode.Value or inp] = Vector2.new(px, py)
        if getTouchCount() >= 2 then
            pinchStartDist = getTouchDist()
            pinchStartSz   = main.AbsoluteSize
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local key = inp.KeyCode.Value ~= 0 and inp.KeyCode.Value or inp
        if not touches[key] then return end
        touches[key] = Vector2.new(inp.Position.X, inp.Position.Y)
        if getTouchCount() >= 2 and pinchStartDist and pinchStartDist > 0 then
            local curDist = getTouchDist()
            if curDist then
                local scale = curDist / pinchStartDist
                local nW = math.clamp(pinchStartSz.X * scale, MIN_W, 900)
                local nH = math.clamp(pinchStartSz.Y * scale, MIN_H, 1000)
                main.Size = UDim2.fromOffset(nW, nH)
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local key = inp.KeyCode.Value ~= 0 and inp.KeyCode.Value or inp
        touches[key] = nil
        pinchStartDist = nil
        pinchStartSz   = nil
    end)
end


-- ══════════════════════════════════════════════════════════════
-- FAB (botón flotante)
-- ══════════════════════════════════════════════════════════════
local floating = Instance.new("ImageButton")
floating.Name              = "NexusFloatingToggle"
floating.Size              = UDim2.fromOffset(68,68)
floating.Position          = UDim2.new(1,-88, 0.5,-34)
floating.BackgroundColor3  = Color3.fromRGB(3,18,32)
floating.BorderSizePixel   = 0
floating.AutoButtonColor   = false
floating.Image             = ""
floating.ZIndex            = 20
floating.Parent            = gui
corner(floating, 68)

local floatStroke = stroke(floating, Color3.fromRGB(0,200,255), 2, 0.05)

local floatLogo = Instance.new("ImageLabel")
floatLogo.Size              = UDim2.fromOffset(44,44)
floatLogo.Position          = UDim2.new(0.5,0,0.5,0)
floatLogo.AnchorPoint       = Vector2.new(0.5,0.5)
floatLogo.BackgroundTransparency = 1
floatLogo.Image             = LOGO_IMAGE_ID
floatLogo.ImageColor3       = Color3.fromRGB(125,235,255)
floatLogo.Parent            = floating

local activeDot = Instance.new("Frame")
activeDot.Size              = UDim2.fromOffset(12,12)
activeDot.Position          = UDim2.new(1,-14,0,4)
activeDot.BackgroundColor3  = Color3.fromRGB(90,110,120)
activeDot.BorderSizePixel   = 0
activeDot.ZIndex            = 21
activeDot.Parent            = floating
corner(activeDot, 12)

function syncFAB()
    local on = Config.SilentAimEnabled or Config.EspEnabled
    activeDot.BackgroundColor3 = on
        and Color3.fromRGB(85,255,165) or Color3.fromRGB(90,110,120)
    floatStroke.Color = on
        and Color3.fromRGB(85,255,165) or Color3.fromRGB(0,200,255)
end

do
    local fabDragging, fabDragStart, fabStartPos = false, nil, nil
    local fabMoved, holding, holdStarted = false, false, 0
    local HOLD_TIME = 0.45

    floating.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            fabDragging=true; fabMoved=false
            fabDragStart=inp.Position; fabStartPos=floating.Position
            holding=true; holdStarted=os.clock()
            task.delay(HOLD_TIME, function()
                if holding and not fabMoved then
                    Config.SilentAimEnabled = not Config.SilentAimEnabled
                    saveConfig(); syncFAB()
                    TweenService:Create(floating,TweenInfo.new(0.1),{Size=UDim2.fromOffset(78,78)}):Play()
                    task.delay(0.12, function()
                        TweenService:Create(floating,TweenInfo.new(0.15),{Size=UDim2.fromOffset(68,68)}):Play()
                    end)
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if fabDragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch) then
            local delta = inp.Position - fabDragStart
            if delta.Magnitude > 5 then fabMoved=true; holding=false end
            if fabMoved then
                local sc = gui.AbsoluteSize
                local nx = math.clamp(fabStartPos.X.Offset+delta.X, 4, sc.X-72)
                local ny = math.clamp(fabStartPos.Y.Offset+delta.Y, 4, sc.Y-72)
                floating.Position = UDim2.new(0,nx,0,ny)
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            if fabDragging then
                local held = os.clock()-holdStarted
                holding=false
                if not fabMoved and held < HOLD_TIME then
                    main.Visible = not main.Visible
                end
                fabDragging=false; fabMoved=false
            end
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
-- HOTKEY PC
-- ══════════════════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(inp, processed)
    if processed then return end
    if inp.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    elseif inp.KeyCode == Enum.KeyCode.RightControl then
        Config.SilentAimEnabled = not Config.SilentAimEnabled
        saveConfig(); syncFAB()
    end
end)

-- ══════════════════════════════════════════════════════════════
-- SCANLINE ANIM
-- ══════════════════════════════════════════════════════════════
task.spawn(function()
    while gui.Parent do
        TweenService:Create(mainStroke,  TweenInfo.new(0.8,Enum.EasingStyle.Sine),{Transparency=0.42}):Play()
        TweenService:Create(floatStroke, TweenInfo.new(0.8,Enum.EasingStyle.Sine),{Transparency=0.28}):Play()
        TweenService:Create(scanLine,    TweenInfo.new(1.2,Enum.EasingStyle.Sine),{
            Position=UDim2.new(0,20,1,-20), BackgroundTransparency=0.65}):Play()
        task.wait(1.2)
        scanLine.Position = UDim2.fromOffset(20, headerH+44)
        scanLine.BackgroundTransparency = 0.2
        TweenService:Create(mainStroke,  TweenInfo.new(0.8,Enum.EasingStyle.Sine),{Transparency=0.05}):Play()
        TweenService:Create(floatStroke, TweenInfo.new(0.8,Enum.EasingStyle.Sine),{Transparency=0.05}):Play()
        task.wait(0.8)
    end
end)

syncFAB()
print("[NEXUS v4.3] Cargado — Hecho por EnanoTop1 (stx) | User: " .. player.Name)