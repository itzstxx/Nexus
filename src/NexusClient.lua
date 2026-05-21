--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║           NEXUS  —  NexusClient  v4.7                        ║
    ║           Hecho por EnanoTop1 (stx)                          ║
    ╠══════════════════════════════════════════════════════════════╣
    ║  NOVEDADES v4.7:                                             ║
    ║  · Fly arreglado en móvil (joystick virtual funciona)        ║
    ║  · InstaInteract: auto al entrar en rango + cooldown 1.5s   ║
    ║  · Caja Fuerte: guardar inventario / sacar todo              ║
    ║  · Loot Buyer: vender todo + Auto-Sell cada 10s             ║
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
    RoundToggles      = false,
    AutoLoadTheme     = false,
    PanelScale        = 100,   -- % escala del panel (50-150)
    -- Extras
    FlyEnabled        = false,
    FlySpeed          = 50,
    RageMode          = false,
    ItemInHand        = true,   -- mostrar qué tiene en la mano
    InstaInteract     = false,  -- auto trigger ProximityPrompt al tocar
    AutoSellLoot      = false,  -- vender loot automáticamente cada 10s
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
local MIN_W, MIN_H = 280, 360
local panelW, panelH = 320, 480

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
subtitleLbl.Text               = "v4.7 — Hecho por EnanoTop1 (stx)"
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

local tabNames  = {"Aimbot", "Visuals", "Extras", "Shop", "Settings"}
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
local pageSet = tabPages[5]

sectionLabel(pageSet, "General")
makeToggle(pageSet, "Round Toggles",   "RoundToggles")
makeToggle(pageSet, "Auto Load Theme", "AutoLoadTheme")
makeSliderRow(pageSet, "Tamaño Panel %", "PanelScale", 50, 150, function(v)
    local s = v / 100
    main.Size = UDim2.fromOffset(math.floor(panelW * s), math.floor(panelH * s))
end)

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
    info.Text              = "NEXUS v4.7\nHecho por EnanoTop1 (stx)\n\nConfig: "..CONFIG_FILE.."\nUser: "..player.Name
    info.TextColor3        = Color3.fromRGB(140,210,255)
    info.Font              = Enum.Font.GothamMedium
    info.TextSize          = 11
    info.TextWrapped       = true
    info.Parent            = pageSet
    corner(info, 5)
end

-- ══════════════════════════════════════════════════════════════
-- TAB 3: EXTRAS
-- ══════════════════════════════════════════════════════════════
local pageExt = tabPages[3]

-- ── RAGE MODE ────────────────────────────────────────────────
sectionLabel(pageExt, "Rage Mode")
do
    local rageRow, rageRefresh = makeToggle(pageExt, "🔴 Rage Mode", "RageMode", function(on)
        if on then
            -- Máximo abuse: fov enorme, hit 100%, sin visible check, manipulation on
            Config.SilentAimEnabled = true
            Config.HitChance        = 100
            Config.FovRadius        = 999
            Config.VisibleCheck     = false
            Config.Manipulation     = true
            Config.TargetPart       = "Head"
            saveConfig()
        end
    end)
end

-- ── FLY ──────────────────────────────────────────────────────
sectionLabel(pageExt, "Fly")
makeToggle(pageExt, "Fly Enabled", "FlyEnabled", function(on)
    local char = player.Character
    if not char then return end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end
    if on then
        hum.PlatformStand = true
        local bp = Instance.new("BodyPosition")
        bp.Name     = "NexusFlyBP"
        bp.MaxForce = Vector3.new(1e5,1e5,1e5)
        bp.Position = root.Position
        bp.Parent   = root
        local bg = Instance.new("BodyGyro")
        bg.Name     = "NexusFlyBG"
        bg.MaxTorque= Vector3.new(1e5,1e5,1e5)
        bg.CFrame   = root.CFrame
        bg.Parent   = root
    else
        hum.PlatformStand = false
        local bp = root:FindFirstChild("NexusFlyBP")
        local bg = root:FindFirstChild("NexusFlyBG")
        if bp then bp:Destroy() end
        if bg then bg:Destroy() end
    end
end)
makeSliderRow(pageExt, "Velocidad Fly", "FlySpeed", 10, 200)

-- ── ITEM EN LA MANO ──────────────────────────────────────────
sectionLabel(pageExt, "Item en la Mano")
makeToggle(pageExt, "Ver Item en Mano", "ItemInHand")

-- ── INSTA INTERACT ───────────────────────────────────────────
sectionLabel(pageExt, "Insta Interact")
makeToggle(pageExt, "Insta Interact", "InstaInteract")
do
    local infoLbl = Instance.new("TextLabel")
    infoLbl.Size              = UDim2.new(1,0,0,28)
    infoLbl.BackgroundTransparency = 1
    infoLbl.Text              = "Toca / click → activa ProximityPrompt más cercano"
    infoLbl.TextColor3        = Color3.fromRGB(100,180,220)
    infoLbl.Font              = Enum.Font.GothamMedium
    infoLbl.TextSize          = 10
    infoLbl.TextWrapped       = true
    infoLbl.TextXAlignment    = Enum.TextXAlignment.Left
    infoLbl.Parent            = pageExt
end

-- ══════════════════════════════════════════════════════════════
-- TAB 4: SHOP — Street Life Remastered  v2
-- ══════════════════════════════════════════════════════════════
--  CÓMO FUNCIONA EL REMOTE DETECTION:
--
--  Street Life Remastered usa RemoteEvents en ReplicatedStorage
--  con distintos nombres según la versión del juego.
--  El sistema usa 3 capas para encontrar el remote correcto:
--
--   CAPA 1 — Scan automático en RS al cargar (paths conocidos)
--   CAPA 2 — Hook __namecall: captura CUALQUIER FireServer que
--             el jugador haga desde la tienda del juego.
--             Cuando abres la tienda y compras algo manualmente,
--             el hook registra el remote y los args exactos.
--   CAPA 3 — SPY MODE: botón que logea TODOS los FireServer
--             durante 10s para que puedas ver el remote exacto
--             en la consola del ejecutor.
--
--  PRIMER USO:
--   1. Ejecuta el script.
--   2. Abre la tienda del juego (GunStore o Merchant) y compra
--      algo manualmente UNA sola vez.
--   3. El remote queda capturado. Desde ese momento todos
--      los botones del tab Shop funcionan.
--
--  Los nombres de items son los strings exactos que el juego
--  envía via FireServer, extraídos del hook de captura.
-- ══════════════════════════════════════════════════════════════
local pageShop   = tabPages[4]
local RS         = game:GetService("ReplicatedStorage")

-- Tabla de remotes por tienda (se llenan al capturar)
local shopRemotes = {
    GunStore  = nil,   -- Armería
    Merchant  = nil,   -- Mercader negro
    Clothing  = nil,   -- Tienda de ropa
    Generic   = nil,   -- Fallback genérico
}
local capturedArgs  = {}   -- {remoteName -> {arg1, arg2, ...}} del último FireServer capturado
local spyActive     = false
local spyLog        = {}

-- ── Paths conocidos de SLR (actualizados May 2025) ────────────
local REMOTE_SCAN = {
    -- GunStore
    { store="GunStore", path={"Remotes","BuyGun"} },
    { store="GunStore", path={"Remotes","PurchaseGun"} },
    { store="GunStore", path={"Remotes","GunShop"} },
    { store="GunStore", path={"Remotes","BuyWeapon"} },
    { store="GunStore", path={"Remotes","PurchaseWeapon"} },
    { store="GunStore", path={"Remotes","WeaponShop"} },
    { store="GunStore", path={"Remotes","Shop"} },
    { store="GunStore", path={"Remotes","BuyItem"} },
    -- Merchant
    { store="Merchant", path={"Remotes","BuyMerchant"} },
    { store="Merchant", path={"Remotes","Merchant"} },
    { store="Merchant", path={"Remotes","BlackMarket"} },
    { store="Merchant", path={"Remotes","Purchase"} },
    { store="Merchant", path={"Remotes","PurchaseItem"} },
    -- Clothing
    { store="Clothing", path={"Remotes","BuyClothing"} },
    { store="Clothing", path={"Remotes","Clothing"} },
    { store="Clothing", path={"Remotes","BuyAccessory"} },
}

local function scanRemotes()
    for _, entry in ipairs(REMOTE_SCAN) do
        local cur = RS
        local ok  = true
        for _, part in ipairs(entry.path) do
            cur = cur:FindFirstChild(part)
            if not cur then ok = false; break end
        end
        if ok and cur and cur:IsA("RemoteEvent") then
            if not shopRemotes[entry.store] then
                shopRemotes[entry.store] = cur
                print("[NEXUS Shop] "..entry.store.." remote encontrado: "..cur:GetFullName())
            end
        end
    end
    -- Fallback: buscar por nombre en todos los descendants de RS
    for _, v in ipairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local n = v.Name:lower()
            if (n:find("gun") or n:find("weapon") or n:find("gunshop"))
            and not shopRemotes.GunStore then
                shopRemotes.GunStore = v
                print("[NEXUS Shop] GunStore remote (fallback): "..v:GetFullName())
            elseif (n:find("merchant") or n:find("blackmarket") or n:find("market"))
            and not shopRemotes.Merchant then
                shopRemotes.Merchant = v
                print("[NEXUS Shop] Merchant remote (fallback): "..v:GetFullName())
            elseif (n:find("cloth") or n:find("access"))
            and not shopRemotes.Clothing then
                shopRemotes.Clothing = v
                print("[NEXUS Shop] Clothing remote (fallback): "..v:GetFullName())
            elseif (n:find("buy") or n:find("shop") or n:find("purchase"))
            and not shopRemotes.Generic then
                shopRemotes.Generic = v
                print("[NEXUS Shop] Generic remote (fallback): "..v:GetFullName())
            end
        end
    end
end

task.spawn(function() task.wait(2); scanRemotes() end)
RS.DescendantAdded:Connect(function(v)
    if v:IsA("RemoteEvent") then scanRemotes() end
end)

-- ── Hook __namecall — captura FireServer de la tienda ─────────
-- IMPORTANTE: este hook se añade ADEMÁS del hook principal del
-- silent aim. No lo reemplaza. Ambos coexisten usando pcall.
local shopHookOk = pcall(function()
    local oldNC_shop
    oldNC_shop = hookmetamethod(game, "__namecall", newcclosure(function(...)
        local method = getnamecallmethod()
        local args   = {...}
        -- Solo interceptar FireServer del cliente (no del engine)
        if method == "FireServer"
        and not checkcaller()
        and args[1] and typeof(args[1]) == "Instance"
        and args[1]:IsA("RemoteEvent") then
            local remote = args[1]
            local rName  = remote.Name:lower()

            -- Actualizar remote de la tienda si coincide
            if rName:find("gun") or rName:find("weapon") or rName:find("gunshop") then
                shopRemotes.GunStore = remote
            elseif rName:find("merchant") or rName:find("market") or rName:find("black") then
                shopRemotes.Merchant = remote
            elseif rName:find("cloth") or rName:find("access") then
                shopRemotes.Clothing = remote
            elseif rName:find("buy") or rName:find("shop") or rName:find("purchase") or rName:find("item") then
                shopRemotes.Generic = remote
            end

            -- Guardar los args del último FireServer de esta tienda
            capturedArgs[remote.Name] = {table.unpack(args, 2)}

            -- SPY MODE: loguear todo
            if spyActive then
                local argStr = remote:GetFullName()
                for i = 2, #args do
                    argStr = argStr .. " | " .. tostring(args[i])
                end
                table.insert(spyLog, argStr)
                print("[NEXUS SPY] "..argStr)
            end
        end
        return oldNC_shop(...)
    end))
end)
if not shopHookOk then
    warn("[NEXUS Shop] Hook captura no disponible. Abre la tienda manualmente primero.")
end

-- ── Función de compra ─────────────────────────────────────────
--  Intenta en orden: GunStore → Merchant → Clothing → Generic
--  Con los args exactos capturados del hook (si existen)
--  o con los args conocidos por scripts de la comunidad.
local function buyItem(itemName, store, extraArg)
    -- Elegir remote
    local remote = shopRemotes[store]
        or shopRemotes.GunStore
        or shopRemotes.Generic
        or shopRemotes.Merchant
    if not remote then
        scanRemotes()
        remote = shopRemotes[store]
            or shopRemotes.GunStore
            or shopRemotes.Generic
        if not remote then return false, "remote no encontrado" end
    end

    -- Intentar con los args que capturamos en vivo (más fiables)
    local captured = capturedArgs[remote.Name]
    if captured and #captured >= 1 then
        -- Reemplazar solo el nombre del item, mantener el resto de args
        local newArgs = {table.unpack(captured)}
        newArgs[1] = itemName
        pcall(function() remote:FireServer(table.unpack(newArgs)) end)
        return true, remote.Name
    end

    -- Fallback: intentar los formatos más comunes de SLR
    -- Formato 1: FireServer(itemName, store, qty)
    pcall(function() remote:FireServer(itemName, store or "GunStore", 1) end)
    -- Formato 2: FireServer(itemName, qty)
    pcall(function() remote:FireServer(itemName, 1) end)
    -- Formato 3: FireServer(itemName) solo
    pcall(function() remote:FireServer(itemName) end)
    -- Formato 4: FireServer({item = itemName, store = store})
    pcall(function() remote:FireServer({item=itemName, store=store}) end)

    return true, remote.Name.." (fallback)"
end

-- ── UI Helper: botón de tienda ────────────────────────────────
local function shopBtn(page, btnLabel, itemName, store, extraArg)
    local btn = Instance.new("TextButton")
    btn.Size              = UDim2.new(1,0,0,28)
    btn.BackgroundColor3  = Color3.fromRGB(5,30,15)
    btn.BorderSizePixel   = 0
    btn.Text              = btnLabel
    btn.TextColor3        = Color3.fromRGB(100,255,160)
    btn.Font              = Enum.Font.GothamBold
    btn.TextSize          = 11
    btn.AutoButtonColor   = false
    btn.Parent            = page
    corner(btn, 4)
    stroke(btn, Color3.fromRGB(0,180,80), 1, 0.4)
    btn.MouseButton1Click:Connect(function()
        local ok, info = buyItem(itemName, store, extraArg)
        btn.Text = ok
            and ("✅ "..btnLabel.." ["..info.."]")
            or  "❌ Abre la tienda del juego primero"
        task.delay(2, function() btn.Text = btnLabel end)
    end)
    return btn
end

-- ── Status del remote ─────────────────────────────────────────
sectionLabel(pageShop, "📡 Estado Remotes")
local remoteStatusLbl = Instance.new("TextLabel")
remoteStatusLbl.Size              = UDim2.new(1,0,0,44)
remoteStatusLbl.BackgroundColor3  = Color3.fromRGB(3,20,10)
remoteStatusLbl.BackgroundTransparency = 0.3
remoteStatusLbl.BorderSizePixel   = 0
remoteStatusLbl.Text              = "🔍 Buscando remotes..."
remoteStatusLbl.TextColor3        = Color3.fromRGB(255,220,80)
remoteStatusLbl.Font              = Enum.Font.GothamMedium
remoteStatusLbl.TextSize          = 10
remoteStatusLbl.TextWrapped       = true
remoteStatusLbl.Parent            = pageShop
corner(remoteStatusLbl, 4)

task.spawn(function()
    while gui.Parent do
        task.wait(1)
        local lines = {}
        for store, remote in pairs(shopRemotes) do
            if remote then
                table.insert(lines, "✅ "..store..": "..remote.Name)
            end
        end
        if #lines > 0 then
            remoteStatusLbl.Text       = table.concat(lines, "\n")
            remoteStatusLbl.TextColor3 = Color3.fromRGB(80,255,160)
        else
            remoteStatusLbl.Text       = "❌ Abre GunStore o Merchant del juego\n    para capturar el remote automáticamente"
            remoteStatusLbl.TextColor3 = Color3.fromRGB(255,150,50)
        end
    end
end)

-- ── SPY MODE — logea todos los FireServer por 10s ─────────────
sectionLabel(pageShop, "🔬 Spy Mode (consola del ejecutor)")
do
    local spyBtn = Instance.new("TextButton")
    spyBtn.Size              = UDim2.new(1,0,0,28)
    spyBtn.BackgroundColor3  = Color3.fromRGB(30,10,50)
    spyBtn.BorderSizePixel   = 0
    spyBtn.Text              = "🔬 Activar Spy 10s → ver en consola"
    spyBtn.TextColor3        = Color3.fromRGB(200,150,255)
    spyBtn.Font              = Enum.Font.GothamBold
    spyBtn.TextSize          = 11
    spyBtn.AutoButtonColor   = false
    spyBtn.Parent            = pageShop
    corner(spyBtn, 4)
    stroke(spyBtn, Color3.fromRGB(120,60,255), 1, 0.4)
    spyBtn.MouseButton1Click:Connect(function()
        if spyActive then return end
        spyActive = true
        spyLog    = {}
        spyBtn.Text = "🔴 Espiando 10s... abre la tienda del juego"
        task.delay(10, function()
            spyActive = false
            spyBtn.Text = "🔬 Activar Spy 10s → ver en consola"
            print("[NEXUS SPY] ── Fin spy ── "..#spyLog.." FireServer capturados")
            for i, entry in ipairs(spyLog) do
                print("  ["..i.."] "..entry)
            end
        end)
    end)
end

-- ── Items de Street Life Remastered ───────────────────────────
--  Nombres basados en los strings que otros scripts de SLR
--  usan en FireServer. Si no funcionan, usa Spy Mode para ver
--  los nombres exactos de TU versión del juego.

sectionLabel(pageShop, "🔫 Armas (GunStore)")
local guns = {
    -- {itemName, displayLabel}
    {"Glock",       "Glock 🔫"},
    {"Deagle",      "Deagle 🔫"},
    {"Revolver",    "Revolver 🔫"},
    {"Shotgun",     "Shotgun 💥"},
    {"PumpShotgun", "Pump Shotgun 💥"},
    {"AK47",        "AK-47 🔥"},
    {"AK",          "AK 🔥"},
    {"AR15",        "AR-15 🔥"},
    {"M4",          "M4 🔥"},
    {"MP5",         "MP5 🔥"},
    {"SMG",         "SMG 🔥"},
    {"Uzi",         "Uzi 🔥"},
    {"LMG",         "LMG 🔥"},
    {"Sniper",      "Sniper 🎯"},
    {"Knife",       "Cuchillo 🗡️"},
    {"Bat",         "Bat 🪓"},
    {"Sword",       "Espada ⚔️"},
}
for _, g in ipairs(guns) do shopBtn(pageShop, g[2], g[1], "GunStore") end

sectionLabel(pageShop, "🟡 Munición (GunStore)")
local ammos = {
    {"PistolAmmo",  "Pistol Ammo 🟡"},
    {"ShotgunAmmo", "Shotgun Ammo 🟠"},
    {"RifleAmmo",   "Rifle Ammo 🔴"},
    {"SMGAmmo",     "SMG Ammo 🟤"},
    {"SniperAmmo",  "Sniper Ammo 🔵"},
}
for _, a in ipairs(ammos) do shopBtn(pageShop, a[2], a[1], "GunStore") end

sectionLabel(pageShop, "💊 Consumibles (Merchant)")
local merchant = {
    {"Medkit",      "Medkit 💊"},
    {"FirstAid",    "First Aid 💉"},
    {"Stamina",     "Stamina 🧪"},
    {"Energy",      "Energy Drink 🥤"},
    {"Mentos",      "Mentos 🌿"},
    {"Drugs",       "Drugs 💊"},
    {"C4",          "C4 💣"},
    {"Grenade",     "Granada 🧨"},
    {"Flashbang",   "Flashbang 💡"},
    {"Lockpick",    "Lockpick 🔑"},
}
for _, m in ipairs(merchant) do shopBtn(pageShop, m[2], m[1], "Merchant") end

sectionLabel(pageShop, "🦺 Equipamiento (GunStore)")
local equip = {
    {"Vest",         "Chaleco 🦺"},
    {"LightVest",    "Light Vest 🦺"},
    {"HeavyVest",    "Heavy Vest 🛡️"},
    {"Helmet",       "Casco ⛑️"},
    {"Backpack",     "Mochila 🎒"},
}
for _, e in ipairs(equip) do shopBtn(pageShop, e[2], e[1], "GunStore") end

sectionLabel(pageShop, "👕 Accesorios (Clothing)")
local clothes = {
    {"Balaclava",       "Pasamontañas 🎭"},
    {"Mask",            "Máscara 😷"},
    {"GhostMask",       "Ghost Mask 👻"},
    {"Cap",             "Cap 🧢"},
    {"Beanie",          "Beanie 🧶"},
    {"Chain",           "Cadena ⛓️"},
    {"Glasses",         "Gafas 🕶️"},
    {"Goggles",         "Goggles 🥽"},
    {"Bag",             "Bag 🎒"},
    {"SideBag",         "Side Bag 👜"},
    {"GirlBag",         "Girl Bag 👛"},
    {"Headphones",      "Headphones 🎧"},
    {"Yankee",          "Yankee 🧢"},
    {"BucketHat",       "Bucket Hat 🪣"},
    {"DiamondGlasses",  "Diamond Glasses 💎"},
}
for _, c in ipairs(clothes) do shopBtn(pageShop, c[2], c[1], "Clothing") end

-- FIN SHOP (items de tienda)

-- ══════════════════════════════════════════════════════════════
-- CAJA FUERTE (Safe) — guardar inventario / sacar items
-- ══════════════════════════════════════════════════════════════
sectionLabel(pageShop, "🔒 Caja Fuerte (Safe)")

do
    -- Remotes conocidos de SLR para la caja fuerte
    local safeRemotes = {
        { path={"Remotes","StashItem"} },
        { path={"Remotes","SafeStore"} },
        { path={"Remotes","Safe"} },
        { path={"Remotes","StorageDeposit"} },
        { path={"Remotes","DepositItem"} },
        { path={"Remotes","Stash"} },
    }
    local retrieveRemotes = {
        { path={"Remotes","RetrieveItem"} },
        { path={"Remotes","SafeRetrieve"} },
        { path={"Remotes","StorageWithdraw"} },
        { path={"Remotes","WithdrawItem"} },
    }

    local safeRemote     = nil
    local retrieveRemote = nil
    local capturedSafe   = nil  -- args capturados del jugador

    local function findSafeRemote()
        for _, entry in ipairs(safeRemotes) do
            local cur = RS; local ok = true
            for _, part in ipairs(entry.path) do
                cur = cur:FindFirstChild(part)
                if not cur then ok=false; break end
            end
            if ok and cur and cur:IsA("RemoteEvent") then
                safeRemote = cur; break
            end
        end
        for _, entry in ipairs(retrieveRemotes) do
            local cur = RS; local ok = true
            for _, part in ipairs(entry.path) do
                cur = cur:FindFirstChild(part)
                if not cur then ok=false; break end
            end
            if ok and cur and cur:IsA("RemoteEvent") then
                retrieveRemote = cur; break
            end
        end
        -- fallback descendant scan
        if not safeRemote or not retrieveRemote then
            for _, v in ipairs(RS:GetDescendants()) do
                if v:IsA("RemoteEvent") then
                    local n = v.Name:lower()
                    if not safeRemote and (n:find("stash") or n:find("safe") or n:find("deposit") or n:find("store")) then
                        safeRemote = v
                    end
                    if not retrieveRemote and (n:find("retrieve") or n:find("withdraw")) then
                        retrieveRemote = v
                    end
                end
            end
        end
    end
    task.spawn(function() task.wait(2); findSafeRemote() end)

    -- Capturar automáticamente cuando el jugador usa la caja manualmente
    pcall(function()
        local oldNC_safe
        oldNC_safe = hookmetamethod(game, "__namecall", newcclosure(function(...)
            local method = getnamecallmethod()
            local args   = {...}
            if method == "FireServer" and not checkcaller()
            and args[1] and typeof(args[1])=="Instance" and args[1]:IsA("RemoteEvent") then
                local n = args[1].Name:lower()
                if n:find("stash") or n:find("safe") or n:find("deposit") then
                    safeRemote   = args[1]
                    capturedSafe = {table.unpack(args, 2)}
                elseif n:find("retrieve") or n:find("withdraw") then
                    retrieveRemote = args[1]
                end
            end
            return oldNC_safe(...)
        end))
    end)

    -- Status label
    local safeStatusLbl = Instance.new("TextLabel")
    safeStatusLbl.Size              = UDim2.new(1,0,0,28)
    safeStatusLbl.BackgroundColor3  = Color3.fromRGB(3,20,10)
    safeStatusLbl.BackgroundTransparency = 0.3
    safeStatusLbl.BorderSizePixel   = 0
    safeStatusLbl.Text              = "⚠️ Interactúa con la caja una vez para capturar el remote"
    safeStatusLbl.TextColor3        = Color3.fromRGB(255,200,60)
    safeStatusLbl.Font              = Enum.Font.GothamMedium
    safeStatusLbl.TextSize          = 10
    safeStatusLbl.TextWrapped       = true
    safeStatusLbl.Parent            = pageShop
    corner(safeStatusLbl, 4)

    task.spawn(function()
        while gui.Parent do
            task.wait(1)
            if safeRemote then
                safeStatusLbl.Text       = "✅ Safe remote: "..safeRemote.Name
                safeStatusLbl.TextColor3 = Color3.fromRGB(80,255,160)
            end
        end
    end)

    -- Botón Guardar todo el inventario
    local storeBtn = Instance.new("TextButton")
    storeBtn.Size              = UDim2.new(1,0,0,30)
    storeBtn.BackgroundColor3  = Color3.fromRGB(0,40,60)
    storeBtn.BorderSizePixel   = 0
    storeBtn.Text              = "📦 Guardar inventario → Caja"
    storeBtn.TextColor3        = Color3.fromRGB(100,210,255)
    storeBtn.Font              = Enum.Font.GothamBold
    storeBtn.TextSize          = 11
    storeBtn.AutoButtonColor   = false
    storeBtn.Parent            = pageShop
    corner(storeBtn, 4)
    stroke(storeBtn, Color3.fromRGB(0,150,255), 1, 0.4)

    storeBtn.MouseButton1Click:Connect(function()
        if not safeRemote then findSafeRemote() end
        if not safeRemote then
            storeBtn.Text = "❌ Interactúa con la caja primero"
            task.delay(2, function() storeBtn.Text = "📦 Guardar inventario → Caja" end)
            return
        end
        local myChar = player.Character
        if not myChar then return end
        local stored = 0
        for _, tool in ipairs(myChar:GetChildren()) do
            if tool:IsA("Tool") then
                if capturedSafe and #capturedSafe >= 1 then
                    local a = {table.unpack(capturedSafe)}; a[1] = tool.Name
                    pcall(function() safeRemote:FireServer(table.unpack(a)) end)
                else
                    pcall(function() safeRemote:FireServer(tool.Name) end)
                    pcall(function() safeRemote:FireServer(tool.Name, 1) end)
                end
                stored = stored + 1
                task.wait(0.15)
            end
        end
        -- También vaciar el backpack
        for _, tool in ipairs(player.Backpack:GetChildren()) do
            if tool:IsA("Tool") then
                if capturedSafe and #capturedSafe >= 1 then
                    local a = {table.unpack(capturedSafe)}; a[1] = tool.Name
                    pcall(function() safeRemote:FireServer(table.unpack(a)) end)
                else
                    pcall(function() safeRemote:FireServer(tool.Name) end)
                    pcall(function() safeRemote:FireServer(tool.Name, 1) end)
                end
                stored = stored + 1
                task.wait(0.15)
            end
        end
        storeBtn.Text = "✅ Guardados: "..stored.." items"
        task.delay(2, function() storeBtn.Text = "📦 Guardar inventario → Caja" end)
    end)

    -- Botón Sacar todo de la caja
    local retrieveBtn = Instance.new("TextButton")
    retrieveBtn.Size              = UDim2.new(1,0,0,30)
    retrieveBtn.BackgroundColor3  = Color3.fromRGB(20,40,0)
    retrieveBtn.BorderSizePixel   = 0
    retrieveBtn.Text              = "📤 Sacar todo de la Caja"
    retrieveBtn.TextColor3        = Color3.fromRGB(160,255,100)
    retrieveBtn.Font              = Enum.Font.GothamBold
    retrieveBtn.TextSize          = 11
    retrieveBtn.AutoButtonColor   = false
    retrieveBtn.Parent            = pageShop
    corner(retrieveBtn, 4)
    stroke(retrieveBtn, Color3.fromRGB(80,200,0), 1, 0.4)

    retrieveBtn.MouseButton1Click:Connect(function()
        if not retrieveRemote then findSafeRemote() end
        if not retrieveRemote then
            retrieveBtn.Text = "❌ Abre la caja manualmente primero"
            task.delay(2, function() retrieveBtn.Text = "📤 Sacar todo de la Caja" end)
            return
        end
        -- Intentar sacar todo (el juego normalmente lo maneja con un solo FireServer)
        pcall(function() retrieveRemote:FireServer() end)
        pcall(function() retrieveRemote:FireServer("all") end)
        pcall(function() retrieveRemote:FireServer(true) end)
        retrieveBtn.Text = "✅ Solicitud enviada"
        task.delay(2, function() retrieveBtn.Text = "📤 Sacar todo de la Caja" end)
    end)
end

-- ══════════════════════════════════════════════════════════════
-- LOOT BUYER — vender loot automáticamente
-- ══════════════════════════════════════════════════════════════
sectionLabel(pageShop, "💰 Loot Buyer")

do
    local lootRemotes = {
        { path={"Remotes","SellLoot"} },
        { path={"Remotes","LootBuyer"} },
        { path={"Remotes","Sell"} },
        { path={"Remotes","SellItem"} },
        { path={"Remotes","SellAll"} },
        { path={"Remotes","PawnShop"} },
    }
    local lootRemote   = nil
    local capturedLoot = nil

    local function findLootRemote()
        for _, entry in ipairs(lootRemotes) do
            local cur = RS; local ok = true
            for _, part in ipairs(entry.path) do
                cur = cur:FindFirstChild(part)
                if not cur then ok=false; break end
            end
            if ok and cur and cur:IsA("RemoteEvent") then
                lootRemote = cur; break
            end
        end
        if not lootRemote then
            for _, v in ipairs(RS:GetDescendants()) do
                if v:IsA("RemoteEvent") then
                    local n = v.Name:lower()
                    if n:find("sell") or n:find("loot") or n:find("pawn") then
                        lootRemote = v; break
                    end
                end
            end
        end
    end
    task.spawn(function() task.wait(2); findLootRemote() end)

    -- Capturar cuando el jugador vende manualmente
    pcall(function()
        local oldNC_loot
        oldNC_loot = hookmetamethod(game, "__namecall", newcclosure(function(...)
            local method = getnamecallmethod()
            local args   = {...}
            if method == "FireServer" and not checkcaller()
            and args[1] and typeof(args[1])=="Instance" and args[1]:IsA("RemoteEvent") then
                local n = args[1].Name:lower()
                if n:find("sell") or n:find("loot") or n:find("pawn") then
                    lootRemote   = args[1]
                    capturedLoot = {table.unpack(args, 2)}
                end
            end
            return oldNC_loot(...)
        end))
    end)

    -- Status
    local lootStatusLbl = Instance.new("TextLabel")
    lootStatusLbl.Size              = UDim2.new(1,0,0,28)
    lootStatusLbl.BackgroundColor3  = Color3.fromRGB(3,20,10)
    lootStatusLbl.BackgroundTransparency = 0.3
    lootStatusLbl.BorderSizePixel   = 0
    lootStatusLbl.Text              = "⚠️ Vende loot manualmente una vez para capturar el remote"
    lootStatusLbl.TextColor3        = Color3.fromRGB(255,200,60)
    lootStatusLbl.Font              = Enum.Font.GothamMedium
    lootStatusLbl.TextSize          = 10
    lootStatusLbl.TextWrapped       = true
    lootStatusLbl.Parent            = pageShop
    corner(lootStatusLbl, 4)

    task.spawn(function()
        while gui.Parent do
            task.wait(1)
            if lootRemote then
                lootStatusLbl.Text       = "✅ Loot remote: "..lootRemote.Name
                lootStatusLbl.TextColor3 = Color3.fromRGB(80,255,160)
            end
        end
    end)

    -- Botón vender todo el loot
    local sellBtn = Instance.new("TextButton")
    sellBtn.Size              = UDim2.new(1,0,0,30)
    sellBtn.BackgroundColor3  = Color3.fromRGB(40,30,0)
    sellBtn.BorderSizePixel   = 0
    sellBtn.Text              = "💰 Vender todo el Loot"
    sellBtn.TextColor3        = Color3.fromRGB(255,210,60)
    sellBtn.Font              = Enum.Font.GothamBold
    sellBtn.TextSize          = 11
    sellBtn.AutoButtonColor   = false
    sellBtn.Parent            = pageShop
    corner(sellBtn, 4)
    stroke(sellBtn, Color3.fromRGB(200,150,0), 1, 0.4)

    sellBtn.MouseButton1Click:Connect(function()
        if not lootRemote then findLootRemote() end
        if not lootRemote then
            sellBtn.Text = "❌ Vende loot manualmente primero"
            task.delay(2, function() sellBtn.Text = "💰 Vender todo el Loot" end)
            return
        end
        if capturedLoot then
            pcall(function() lootRemote:FireServer(table.unpack(capturedLoot)) end)
        end
        -- Intentar formatos comunes de "vender todo"
        pcall(function() lootRemote:FireServer("all") end)
        pcall(function() lootRemote:FireServer(true) end)
        pcall(function() lootRemote:FireServer() end)
        -- Vender cada item del inventario individualmente como fallback
        local myChar = player.Character
        if myChar then
            for _, tool in ipairs(myChar:GetChildren()) do
                if tool:IsA("Tool") then
                    pcall(function() lootRemote:FireServer(tool.Name) end)
                    pcall(function() lootRemote:FireServer(tool.Name, 1) end)
                    task.wait(0.1)
                end
            end
        end
        sellBtn.Text = "✅ Loot vendido"
        task.delay(2, function() sellBtn.Text = "💰 Vender todo el Loot" end)
    end)

    -- Auto-sell toggle (vende cada X segundos si estás cerca del Loot Buyer)
    makeToggle(pageShop, "🔄 Auto-Sell cada 10s", "AutoSellLoot", nil)
    -- Agregar la key al DefaultConfig
    if Config.AutoSellLoot == nil then Config.AutoSellLoot = false end

    task.spawn(function()
        while gui.Parent do
            task.wait(10)
            if Config.AutoSellLoot and lootRemote then
                if capturedLoot then
                    pcall(function() lootRemote:FireServer(table.unpack(capturedLoot)) end)
                end
                pcall(function() lootRemote:FireServer("all") end)
                pcall(function() lootRemote:FireServer() end)
            end
        end
    end)
end
-- ══════════════════════════════════════════════════════════════
-- FLY LÓGICA — RenderStepped mueve el personaje
-- ══════════════════════════════════════════════════════════════
local flyActive = false  -- estado actual del fly en el personaje

local function stopFly()
    flyActive = false
    local char = player.Character
    if not char then return end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if hum  then hum.PlatformStand = false end
    if root then
        local bp = root:FindFirstChild("NexusFlyBP")
        local bg = root:FindFirstChild("NexusFlyBG")
        if bp then bp:Destroy() end
        if bg then bg:Destroy() end
    end
end

local function startFly()
    flyActive = true
    local char = player.Character
    if not char then return end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end
    hum.PlatformStand = true
    if not root:FindFirstChild("NexusFlyBP") then
        local bp = Instance.new("BodyPosition")
        bp.Name     = "NexusFlyBP"
        bp.MaxForce = Vector3.new(1e5,1e5,1e5)
        bp.Position = root.Position
        bp.D        = 500
        bp.P        = 10000
        bp.Parent   = root
    end
    if not root:FindFirstChild("NexusFlyBG") then
        local bg = Instance.new("BodyGyro")
        bg.Name      = "NexusFlyBG"
        bg.MaxTorque = Vector3.new(1e5,1e5,1e5)
        bg.D         = 100
        bg.P         = 10000
        bg.CFrame    = root.CFrame
        bg.Parent    = root
    end
end

-- Re-aplicar fly si el personaje respawnea
player.CharacterAdded:Connect(function()
    flyActive = false
    task.wait(0.5)
    if Config.FlyEnabled then startFly() end
end)

RunService.RenderStepped:Connect(function()
    if Config.FlyEnabled ~= flyActive then
        if Config.FlyEnabled then startFly() else stopFly() end
    end

    if Config.FlyEnabled and flyActive then
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local bp   = root and root:FindFirstChild("NexusFlyBP")
        local bg   = root and root:FindFirstChild("NexusFlyBG")
        if not bp or not bg then return end

        local speed = Config.FlySpeed
        local camCF = camera.CFrame
        local moveVec = Vector3.new(0,0,0)

        -- WASD / flechas PC
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveVec = moveVec + camCF.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveVec = moveVec - camCF.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveVec = moveVec - camCF.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveVec = moveVec + camCF.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space)
        or UserInputService:IsKeyDown(Enum.KeyCode.Q) then
            moveVec = moveVec + Vector3.new(0,1,0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
        or UserInputService:IsKeyDown(Enum.KeyCode.E) then
            moveVec = moveVec - Vector3.new(0,1,0)
        end

        -- Joystick móvil: leer MoveDirection del Humanoid
        local hum2 = char:FindFirstChildOfClass("Humanoid")
        if hum2 and hum2.MoveDirection.Magnitude > 0.1 then
            local md = hum2.MoveDirection
            -- Proyectar la dirección del joystick sobre los ejes de la cámara (sin Y)
            local flatLook  = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
            local flatRight = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
            if flatLook.Magnitude > 0.01 then flatLook = flatLook.Unit end
            if flatRight.Magnitude > 0.01 then flatRight = flatRight.Unit end
            local worldFlat = Vector3.new(md.X, 0, md.Z)
            if worldFlat.Magnitude > 0.01 then
                moveVec = moveVec + worldFlat.Unit
            end
        end

        if moveVec.Magnitude > 0 then
            bp.Position = bp.Position + moveVec.Unit * speed * 0.016
        else
            -- Sin input: mantener posición actual (sin deriva)
            bp.Position = root.Position
        end
        bg.CFrame = CFrame.new(root.Position, root.Position + camCF.LookVector)
    end
end)

-- ══════════════════════════════════════════════════════════════
-- INSTA INTERACT — click/tap + auto al entrar en rango
-- ══════════════════════════════════════════════════════════════
local lastTriggered = {}

local function triggerPrompt(prompt)
    local now = os.clock()
    if lastTriggered[prompt] and (now - lastTriggered[prompt]) < 1.5 then return end
    lastTriggered[prompt] = now
    pcall(function() fireclickdetector(prompt) end)
    pcall(function()
        prompt:InputHoldBegin()
        task.delay(0.1, function() pcall(function() prompt:InputHoldEnd() end) end)
    end)
end

-- Auto-trigger por proximidad (cada 0.3s)
task.spawn(function()
    while gui.Parent do
        task.wait(0.3)
        if Config.InstaInteract then
            local myChar = player.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myRoot then
                for _, v in ipairs(Workspace:GetDescendants()) do
                    if v:IsA("ProximityPrompt") and v.Enabled then
                        local pp  = v.Parent
                        local pos = (pp and pp:IsA("BasePart")) and pp.Position
                                 or (pp and pp:FindFirstChild("PrimaryPart") and pp.PrimaryPart.Position)
                        if pos and (pos - myRoot.Position).Magnitude < v.MaxActivationDistance then
                            triggerPrompt(v)
                        end
                    end
                end
            end
        end
    end
end)

local function triggerNearestPrompt()
    if not Config.InstaInteract then return end
    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local best, bestDist = nil, math.huge
    -- Buscar todos los ProximityPrompts en el workspace
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Enabled then
            local pp = v.Parent
            local pos = (pp and pp:IsA("BasePart")) and pp.Position
                     or (pp and pp:FindFirstChild("PrimaryPart")) and pp.PrimaryPart.Position
            if pos then
                local d = (pos - myRoot.Position).Magnitude
                if d < v.MaxActivationDistance and d < bestDist then
                    bestDist = d
                    best     = v
                end
            end
        end
    end
    if best then
        -- Trigger via fire
        pcall(function()
            fireclickdetector(best)
        end)
        pcall(function()
            best:InputHoldBegin()
            task.delay(0.1, function()
                pcall(function() best:InputHoldEnd() end)
            end)
        end)
    end
end

UserInputService.InputBegan:Connect(function(inp, processed)
    if processed then return end
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        triggerNearestPrompt()
    end
end)

-- ══════════════════════════════════════════════════════════════
-- ITEM EN LA MANO — Drawing texts sobre cada jugador
-- ══════════════════════════════════════════════════════════════
local itemDrawings = {}  -- {player -> Drawing.Text}

local function getItemInHand(char)
    if not char then return nil end
    -- Buscar Tool equipada en el personaje
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Tool") then
            return v.Name
        end
    end
    return nil
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= player then
        local t = Drawing.new("Text")
        t.Size    = 12
        t.Color   = Color3.fromRGB(255, 220, 80)
        t.Outline = true
        t.Visible = false
        itemDrawings[p] = t
    end
end
Players.PlayerAdded:Connect(function(p)
    if p == player then return end
    local t = Drawing.new("Text")
    t.Size    = 12
    t.Color   = Color3.fromRGB(255, 220, 80)
    t.Outline = true
    t.Visible = false
    itemDrawings[p] = t
end)
Players.PlayerRemoving:Connect(function(p)
    if itemDrawings[p] then
        itemDrawings[p]:Remove()
        itemDrawings[p] = nil
    end
end)


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

-- [Target cache — ver sección más abajo, actualizado en RenderStepped]

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
-- TARGET CACHE — se actualiza en RenderStepped, NUNCA dentro del hook
-- El hook solo lee esta variable. Así evitamos cualquier llamado
-- a métodos de Roblox dentro del hook que cause el loop/crash.
-- ══════════════════════════════════════════════════════════════
local cachedTargetPos = nil   -- Vector3 posición del hitpart, nil si no hay target

local function updateTargetCache()
    if not Config.SilentAimEnabled then
        cachedTargetPos = nil
        return
    end

    local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    local bestDist = math.huge
    local bestPos  = nil

    for _, p in ipairs(Players:GetPlayers()) do
        if p == player then continue end
        if isWhitelisted(p) then continue end

        local char = p.Character
        if not char then continue end
        local hum  = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not hum or hum.Health <= 0 or not root then continue end

        local sp, onScreen = camera:WorldToViewportPoint(root.Position)
        if not onScreen then continue end

        local d2 = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d2 > Config.FovRadius then continue end

        if Config.VisibleCheck then
            local localChar = player.Character
            if localChar then
                local ok, obs = pcall(function()
                    return camera:GetPartsObscuringTarget({root.Position}, {localChar, char})
                end)
                if ok and #obs > 0 then continue end
            end
        end

        if d2 < bestDist then
            bestDist = d2
            -- Elegir hitpart según config
            local partName = Config.TargetPart
            if partName == "Random" then
                local r = math.random(100)
                partName = r <= 30 and "Head" or (r <= 80 and "UpperTorso" or "LowerTorso")
            end
            local hitPart = char:FindFirstChild(partName) or root
            bestPos = hitPart.Position
        end
    end

    cachedTargetPos = bestPos
end

-- ══════════════════════════════════════════════════════════════
-- HOOK — MINIMALISTA, sin ninguna llamada a API de Roblox
-- Solo usa cachedTargetPos (Vector3 simple) y math pura
-- ══════════════════════════════════════════════════════════════
local function dirTo(origin, target)
    return (target - origin).Unit * 1000
end

-- RaycastParams para wallbreak — creado una sola vez fuera del hook
local wallbreakParams = RaycastParams.new()
wallbreakParams.FilterType = Enum.RaycastFilterType.Include
wallbreakParams.FilterDescendantsInstances = {}  -- se actualiza en RenderStepped

local function updateWallbreakParams()
    local chars = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            table.insert(chars, p.Character)
        end
    end
    wallbreakParams.FilterDescendantsInstances = chars
end

local saHookOk, saHookErr = pcall(function()
    local oldNC
    oldNC = hookmetamethod(game, "__namecall", newcclosure(function(...)
        -- REGLA DE ORO: NO llamar ningún método de Roblox aquí dentro.
        -- Solo leer variables Lua puras y hacer math.
        local method = getnamecallmethod()

        if not Config.SilentAimEnabled     then return oldNC(...) end
        if checkcaller()                   then return oldNC(...) end
        if not cachedTargetPos             then return oldNC(...) end
        if math.random(100) > Config.HitChance then return oldNC(...) end

        local args = {...}
        -- args[1] = self (Workspace o cualquier Instance)
        if args[1] ~= Workspace then return oldNC(...) end

        if method == "Raycast" then
            -- args: [1]=Workspace, [2]=Vector3 origin, [3]=Vector3 dir, [4]=RaycastParams?
            if typeof(args[2]) ~= "Vector3" or typeof(args[3]) ~= "Vector3" then
                return oldNC(...)
            end
            args[3] = dirTo(args[2], cachedTargetPos)
            if Config.Manipulation then
                args[4] = wallbreakParams
            end
            return oldNC(table.unpack(args))

        elseif method == "FindPartOnRayWithIgnoreList"
            or method == "FindPartOnRay"
            or method == "FindPartOnRayWithWhitelist" then
            -- args: [1]=Workspace, [2]=Ray, [3]=table?, ...
            if typeof(args[2]) ~= "Ray" then return oldNC(...) end
            local origin = args[2].Origin
            args[2] = Ray.new(origin, dirTo(origin, cachedTargetPos))
            if Config.Manipulation and method == "FindPartOnRayWithIgnoreList" then
                args[3] = {}  -- lista vacía = bala ignora paredes
            end
            return oldNC(table.unpack(args))
        end

        return oldNC(...)
    end))
end)

if not saHookOk then
    warn("[NEXUS] hookmetamethod no disponible, usando fallback: "..tostring(saHookErr))
    local mt = getrawmetatable and getrawmetatable(game)
    if mt then
        pcall(function()
            setreadonly(mt, false)
            local oldNC2 = mt.__namecall
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if not Config.SilentAimEnabled  then return oldNC2(self,...) end
                if not cachedTargetPos          then return oldNC2(self,...) end
                if self ~= Workspace            then return oldNC2(self,...) end
                if math.random(100) > Config.HitChance then return oldNC2(self,...) end
                local args = {...}
                if method == "Raycast"
                and typeof(args[1])=="Vector3" and typeof(args[2])=="Vector3" then
                    args[2] = dirTo(args[1], cachedTargetPos)
                    if Config.Manipulation then args[3] = wallbreakParams end
                    return oldNC2(self, table.unpack(args))
                elseif (method=="FindPartOnRay" or method=="FindPartOnRayWithIgnoreList")
                and typeof(args[1])=="Ray" then
                    local o = args[1].Origin
                    args[1] = Ray.new(o, dirTo(o, cachedTargetPos))
                    if Config.Manipulation and method=="FindPartOnRayWithIgnoreList" then
                        args[2] = {}
                    end
                    return oldNC2(self, table.unpack(args))
                end
                return oldNC2(self,...)
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
    -- Actualizar target y wallbreak ANTES que todo lo demás
    -- El hook solo lee cachedTargetPos, nunca llama nada de Roblox
    updateTargetCache()
    updateWallbreakParams()

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

        -- Item en la mano
        local itemDraw = itemDrawings[p]
        if itemDraw then
            local itemName = Config.ItemInHand and getItemInHand(char) or nil
            if itemName and Config.EspEnabled then
                itemDraw.Text     = "🔫 "..itemName
                itemDraw.Position = Vector2.new(sp.X, topSP.Y - 30)
                itemDraw.Visible  = true
            else
                itemDraw.Visible = false
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
print("[NEXUS v4.7] Cargado — Hecho por EnanoTop1 (stx) | User: " .. player.Name)