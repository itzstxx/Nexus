--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║           NEXUS  —  NexusClient  v3.0                        ║
    ║           Hecho por EnanoTop1 (stx)                          ║
    ╠══════════════════════════════════════════════════════════════╣
    ║  NOVEDADES v3.0:                                             ║
    ║  · Silent Aim: FOV hasta 500, TargetPart (Head/Chest/Leg     ║
    ║    /Random Smart), HitChance, VisibleCheck, Snapline         ║
    ║  · ESP: Skeleton, Box, Healthbar, Distance, Nametag          ║
    ║    Cada opción es activable individualmente                  ║
    ║  · Sistema de configuración persistente (writefile/readfile) ║
    ║  · Tabs: Aimbot | Visuals | Settings                         ║
    ║  · Firma: Hecho por EnanoTop1 (stx)                          ║
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
    -- Aimbot
    SilentAimEnabled  = false,
    HitChance         = 100,
    Manipulation      = false,
    VisibleCheck      = true,
    FovEnabled        = true,
    FovRadius         = 500,
    Snapline          = false,
    TargetPart        = "Random",   -- "Head" | "UpperTorso" | "LowerTorso" | "Random"
    -- ESP
    EspEnabled        = false,
    EspBox            = true,
    EspSkeleton       = true,
    EspHealthBar      = true,
    EspDistance       = true,
    EspNames          = true,
    EspMaxDist        = 500,
}

local Config = {}

local function deepCopy(t)
    local copy = {}
    for k, v in pairs(t) do copy[k] = v end
    return copy
end

local function loadConfig()
    if pcall(function()
        local raw = readfile(CONFIG_FILE)
        local decoded = HttpService:JSONDecode(raw)
        for k, v in pairs(DefaultConfig) do
            Config[k] = (decoded[k] ~= nil) and decoded[k] or v
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
        print("[NEXUS] Config guardada en " .. CONFIG_FILE)
    end)
end

loadConfig()

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
local MIN_W, MIN_H = 340, 460
local panelW, panelH = 420, 560

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
subtitleLbl.Text               = "Hecho por EnanoTop1 (stx)"
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

    row.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then onTap() end
    end)
    row.MouseButton1Click:Connect(onTap) -- Frame no tiene MouseButton1Click, workaround:
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

-- Dropdown (para TargetPart)
local function makeDropdown(page, text, configKey, options, callback)
    local open = false

    local container = Instance.new("Frame")
    container.Size             = UDim2.new(1,0,0,34)
    container.BackgroundTransparency = 1
    container.ClipsDescendants = false
    container.Parent           = page
    -- No UIListLayout aquí porque se expande dinámicamente; se maneja con resize

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

    -- Dropdown list (dentro del mismo contenedor, aparece debajo)
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
makeSliderRow(pageAim, "HitChance",     "HitChance",  1, 100)
makeToggle(pageAim,    "Manipulation",  "Manipulation")
makeToggle(pageAim,    "VisibleCheck",  "VisibleCheck")
makeToggle(pageAim,    "FOV Circle",    "FovEnabled")
makeSliderRow(pageAim, "Fov Radius",    "FovRadius",  1, 500)
makeToggle(pageAim,    "Snapline",      "Snapline")

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
makeToggle(pageVis, "Skeleton",      "EspSkeleton")
makeToggle(pageVis, "Health Bar",    "EspHealthBar")
makeToggle(pageVis, "Distancia",     "EspDistance")
makeToggle(pageVis, "Nombres",       "EspNames")
makeSliderRow(pageVis, "Dist Máx",   "EspMaxDist", 50, 1000)

-- ══════════════════════════════════════════════════════════════
-- TAB 3: SETTINGS
-- ══════════════════════════════════════════════════════════════
local pageSet = tabPages[3]

sectionLabel(pageSet, "Configuración")

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
    info.Text              = "NEXUS v3.0\nHecho por EnanoTop1 (stx)\n\nConfig: "..CONFIG_FILE.."\nUser: "..player.Name
    info.TextColor3        = Color3.fromRGB(140,210,255)
    info.Font              = Enum.Font.GothamMedium
    info.TextSize          = 11
    info.TextWrapped       = true
    info.Parent            = pageSet
    corner(info, 5)
end

-- ══════════════════════════════════════════════════════════════
-- FOV CIRCLE (drawing)
-- ══════════════════════════════════════════════════════════════
local fovCircle = Drawing.new("Circle")
fovCircle.Visible   = false
fovCircle.Color     = Color3.fromRGB(255,255,255)
fovCircle.Thickness = 1.5
fovCircle.Filled    = false

-- Snapline drawing
local snapLine = Drawing.new("Line")
snapLine.Visible   = false
snapLine.Color     = Color3.fromRGB(255,255,255)
snapLine.Thickness = 1.5

-- ══════════════════════════════════════════════════════════════
-- ESP DRAWINGS  (por cada jugador)
-- ══════════════════════════════════════════════════════════════
local espObjects = {}   -- [player] = { box, nameTag, distTag, healthBar, healthBg, skeleton[] }

local SKELETON_PAIRS = {
    {"Head",       "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg","LeftLowerLeg"},
    {"LeftLowerLeg","LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg","RightLowerLeg"},
    {"RightLowerLeg","RightFoot"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm","LeftLowerArm"},
    {"LeftLowerArm","LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm","RightLowerArm"},
    {"RightLowerArm","RightHand"},
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
-- SILENT AIM  —  LÓGICA PRINCIPAL
-- ══════════════════════════════════════════════════════════════
local function getTargetPart(char)
    local part = Config.TargetPart
    if part == "Random" then
        -- Random inteligente: 50% UpperTorso, 30% Head, 20% LowerTorso
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
    local origin  = camera.CFrame.Position
    local dir     = (part.Position - origin)
    local result  = Workspace:Raycast(origin, dir,
        RaycastParams.new())  -- sin filtros por simplicidad
    if not result then return true end
    local hit = result.Instance
    -- Si golpea una parte del jugador objetivo, está visible
    return hit:IsDescendantOf(part.Parent)
end

local function getBestTarget()
    local center  = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    local bestP   = nil
    local bestD   = math.huge

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            local char = p.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                local root = char:FindFirstChild("HumanoidRootPart")
                if hum and hum.Health > 0 and root then
                    local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
                    if onScreen then
                        local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                        if dist2D <= Config.FovRadius then
                            if Config.VisibleCheck then
                                local ok, vis = pcall(isVisible, root)
                                if ok and not vis then continue end
                            end
                            if dist2D < bestD then
                                bestD = dist2D
                                bestP = p
                            end
                        end
                    end
                end
            end
        end
    end
    return bestP
end

-- Hook en el raycast del mouse para silent aim
local oldRaycast = Workspace.FindPartOnRay
if syn and syn.protect_gui then syn.protect_gui(gui) end

-- Método estándar de silent aim para ejecutores:
local mt = getrawmetatable and getrawmetatable(game)
if mt then
    local oldIndex = mt.__index
    local oldNamecall

    if pcall(function() return mt.__namecall end) then
        local success, msg = pcall(function()
            setreadonly(mt, false)

            oldNamecall = mt.__namecall
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if Config.SilentAimEnabled
                and (method == "FindPartOnRayWithIgnoreList"
                  or method == "FindPartOnRay"
                  or method == "Raycast") then
                    local chance = math.random(100)
                    if chance <= Config.HitChance then
                        local target = getBestTarget()
                        if target and target.Character then
                            local part = getTargetPart(target.Character)
                            if part then
                                local args = {...}
                                if method == "Raycast" then
                                    -- RaycastParams: reemplaza dirección
                                    local origin = camera.CFrame.Position
                                    local dir    = (part.Position - origin)
                                    args[1] = origin
                                    args[2] = dir
                                else
                                    -- Ray clásico
                                    local ray = args[1]
                                    if typeof(ray) == "Ray" then
                                        args[1] = Ray.new(ray.Origin,
                                            (part.Position - ray.Origin).Unit * ray.Direction.Magnitude)
                                    end
                                end
                                return oldNamecall(self, table.unpack(args))
                            end
                        end
                    end
                end
                return oldNamecall(self, ...)
            end)

            setreadonly(mt, true)
        end)
        if not success then
            warn("[NEXUS] Silent Aim hook no disponible en este ejecutor: "..tostring(msg))
        end
    end
end

-- ══════════════════════════════════════════════════════════════
-- RENDER STEP  —  ESP + FOV + Snapline
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
    end

    -- ESP
    for p, obj in pairs(espObjects) do
        local active = Config.EspEnabled and p.Character ~= nil
        local char   = p.Character

        local allOff = function()
            obj.box.Visible = false; obj.nameTag.Visible = false
            obj.distTag.Visible = false; obj.healthBar.Visible = false
            obj.healthBg.Visible = false
            for _, l in ipairs(obj.skeleton) do l.Visible = false end
        end

        if not active then allOff(); continue end

        local root = char:FindFirstChild("HumanoidRootPart")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then allOff(); continue end

        local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
        if not onScreen then allOff(); continue end

        -- Distancia 3D
        local dist3D = myRoot
            and math.floor((root.Position - myRoot.Position).Magnitude)
            or 0

        if dist3D > Config.EspMaxDist then allOff(); continue end

        local sp = Vector2.new(screenPos.X, screenPos.Y)

        -- Calcular tamaño del box
        local head = char:FindFirstChild("Head")
        local foot = char:FindFirstChild("LeftFoot")
            or char:FindFirstChild("HumanoidRootPart")
        local topSP, botSP
        if head and foot then
            local t, _ = camera:WorldToViewportPoint(head.Position + Vector3.new(0,0.6,0))
            local b, _ = camera:WorldToViewportPoint(foot.Position - Vector3.new(0,0.2,0))
            topSP = Vector2.new(t.X, t.Y)
            botSP = Vector2.new(b.X, b.Y)
        else
            topSP = sp - Vector2.new(0, 50)
            botSP = sp + Vector2.new(0, 50)
        end

        local boxH = math.abs(botSP.Y - topSP.Y)
        local boxW = boxH * 0.45

        -- Box
        obj.box.Visible = Config.EspBox
        if Config.EspBox then
            obj.box.Position = Vector2.new(sp.X - boxW/2, topSP.Y)
            obj.box.Size     = Vector2.new(boxW, boxH)
        end

        -- Nombre
        obj.nameTag.Visible  = Config.EspNames
        if Config.EspNames then
            obj.nameTag.Text     = p.DisplayName
            obj.nameTag.Position = Vector2.new(sp.X - boxW/2, topSP.Y - 18)
        end

        -- Distancia
        obj.distTag.Visible  = Config.EspDistance
        if Config.EspDistance then
            obj.distTag.Text     = dist3D.."m"
            obj.distTag.Position = Vector2.new(sp.X - boxW/2, botSP.Y + 2)
        end

        -- Health Bar
        local healthPct = hum.Health / math.max(hum.MaxHealth, 1)
        obj.healthBg.Visible  = Config.EspHealthBar
        obj.healthBar.Visible = Config.EspHealthBar
        if Config.EspHealthBar then
            local barX = sp.X - boxW/2 - 8
            obj.healthBg.Position  = Vector2.new(barX, topSP.Y)
            obj.healthBg.Size      = Vector2.new(4, boxH)
            obj.healthBg.Color     = Color3.fromRGB(30,30,30)

            local barH = boxH * healthPct
            local healthColor = Color3.fromRGB(
                math.floor(255*(1-healthPct)),
                math.floor(255*healthPct),
                0)
            obj.healthBar.Position = Vector2.new(barX, topSP.Y + boxH - barH)
            obj.healthBar.Size     = Vector2.new(4, barH)
            obj.healthBar.Color    = healthColor
        end

        -- Skeleton
        for si, pair in ipairs(SKELETON_PAIRS) do
            local pA = char:FindFirstChild(pair[1])
            local pB = char:FindFirstChild(pair[2])
            local line = obj.skeleton[si]
            if Config.EspSkeleton and pA and pB then
                local sA, onA = camera:WorldToViewportPoint(pA.Position)
                local sB, onB = camera:WorldToViewportPoint(pB.Position)
                line.Visible = onA and onB
                if onA and onB then
                    line.From = Vector2.new(sA.X, sA.Y)
                    line.To   = Vector2.new(sB.X, sB.Y)
                end
            else
                line.Visible = false
            end
        end

        -- Snapline
        if Config.Snapline and Config.SilentAimEnabled then
            local target = getBestTarget()
            if target == p then
                snapLine.Visible = true
                snapLine.From    = center2D
                snapLine.To      = sp
            end
        end
    end

    -- Apagar snapline si no hay target o está desactivado
    if not (Config.Snapline and Config.SilentAimEnabled) then
        snapLine.Visible = false
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
-- RESIZE HANDLE
-- ══════════════════════════════════════════════════════════════
do
    local rh = Instance.new("TextButton")
    rh.Size              = UDim2.fromOffset(22,22)
    rh.Position          = UDim2.new(1,-22,1,-22)
    rh.BackgroundColor3  = Color3.fromRGB(0,170,255)
    rh.BackgroundTransparency = 0.35
    rh.Text              = "⤡"
    rh.TextColor3        = Color3.fromRGB(200,245,255)
    rh.TextSize          = 13
    rh.Font              = Enum.Font.GothamBold
    rh.BorderSizePixel   = 0
    rh.ZIndex            = 10
    rh.Parent            = main
    corner(rh, 4)

    local resizing, resizeStart, startSz = false, nil, nil
    rh.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            resizing = true; resizeStart = inp.Position; startSz = main.AbsoluteSize
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            resizing = false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if resizing and (inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch) then
            local d  = inp.Position - resizeStart
            local nW = math.clamp(startSz.X + d.X, MIN_W, 700)
            local nH = math.clamp(startSz.Y + d.Y, MIN_H, 800)
            main.Size = UDim2.fromOffset(nW, nH)
        end
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

do
    local fabDragging, fabDragStart, fabStartPos = false, nil, nil
    local fabMoved, holding, holdStarted = false, false, 0
    local HOLD_TIME = 0.45

    floating.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            fabDragging = true; fabMoved = false
            fabDragStart = inp.Position; fabStartPos = floating.Position
            holding = true; holdStarted = os.clock()
            task.delay(HOLD_TIME, function()
                if holding and not fabMoved then
                    Config.SilentAimEnabled = not Config.SilentAimEnabled
                    saveConfig()
                    syncFAB()
                    TweenService:Create(floating, TweenInfo.new(0.1),
                        {Size=UDim2.fromOffset(78,78)}):Play()
                    task.delay(0.12, function()
                        TweenService:Create(floating, TweenInfo.new(0.15),
                            {Size=UDim2.fromOffset(68,68)}):Play()
                    end)
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if fabDragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch) then
            local delta = inp.Position - fabDragStart
            if delta.Magnitude > 5 then fabMoved = true; holding = false end
            if fabMoved then
                local sc = gui.AbsoluteSize
                local nx = math.clamp(fabStartPos.X.Offset + delta.X, 4, sc.X-72)
                local ny = math.clamp(fabStartPos.Y.Offset + delta.Y, 4, sc.Y-72)
                floating.Position = UDim2.new(0,nx,0,ny)
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            if fabDragging then
                local held = os.clock() - holdStarted
                holding = false
                if not fabMoved and held < HOLD_TIME then
                    main.Visible = not main.Visible
                end
                fabDragging = false; fabMoved = false
            end
        end
    end)
end

function syncFAB()
    local on = Config.SilentAimEnabled or Config.EspEnabled
    activeDot.BackgroundColor3 = on
        and Color3.fromRGB(85,255,165) or Color3.fromRGB(90,110,120)
    floatStroke.Color = on
        and Color3.fromRGB(85,255,165) or Color3.fromRGB(0,200,255)
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
print("[NEXUS v3.0] Cargado — Hecho por EnanoTop1 (stx) | User: " .. player.Name)