--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║           NEXUS  —  NexusClient  v5.0                        ║
    ║           Hecho por EnanoTop1 (stx)                          ║
    ╠══════════════════════════════════════════════════════════════╣
    ║  FIXES v5.0:                                                 ║
    ║  · syncFAB declarado antes de usarse                         ║
    ║  · Hook __namecall con detección de origen (no cámara)       ║
    ║  · Solo usa Workspace:Raycast() moderno, Ray.new eliminado   ║
    ║  · Memory leak Drawing corregido: cleanup completo           ║
    ║  · Anti-recursión en hook (flag _inHook)                     ║
    ║  · math.random reemplazado por Cache de target (60fps safe)  ║
    ║  · VisibleCheck con FilterDescendantsInstances correcto       ║
    ║  · Layout recalculado al resize                              ║
    ║  · AutomaticCanvasSize desactivado, canvas manual             ║
    ║  · readfile/writefile con fallback seguro                    ║
    ║  · Loops detenidos al destruir la GUI                        ║
    ║  · Team Check añadido                                        ║
    ║  · getBestTarget cacheado cada 0.05s (no cada raycast)       ║
    ║  · Conexiones almacenadas y limpiadas                        ║
    ║  · Validación de executor al inicio                          ║
    ║  · RenderStepped optimizado (skip si panel oculto no afecta) ║
    ║  · Tamaño por defecto 600×800, pinch-to-resize móvil         ║
    ║  · Botón minimizar y cerrar en header                        ║
    ╚══════════════════════════════════════════════════════════════╝
]]

-- ══════════════════════════════════════════════════════════════
-- VALIDACIÓN DE EXECUTOR
-- ══════════════════════════════════════════════════════════════
local function hasFunc(name)
    return type(_G[name]) == "function" or type(getfenv()[name]) == "function"
end
local HAS_DRAWING      = typeof(Drawing) == "table" or type(Drawing) == "table"
local HAS_READFILE     = hasFunc("readfile") and hasFunc("writefile")
local HAS_METAMETHODS  = hasFunc("getrawmetatable") and hasFunc("setreadonly") and hasFunc("newcclosure") and hasFunc("getnamecallmethod")

-- ══════════════════════════════════════════════════════════════
-- SERVICIOS
-- ══════════════════════════════════════════════════════════════
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local HttpService      = game:GetService("HttpService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera    = Workspace.CurrentCamera

local LOGO_IMAGE_ID = "rbxassetid://18712765450"  -- logo generico (reemplazable)
local CONFIG_FILE   = "nexus_config.json"

-- ══════════════════════════════════════════════════════════════
-- CONFIGURACIÓN PERSISTENTE
-- ══════════════════════════════════════════════════════════════
local DefaultConfig = {
    SilentAimEnabled = false,
    HitChance        = 100,
    Manipulation     = false,
    VisibleCheck     = true,
    TeamCheck        = true,
    FovEnabled       = true,
    FovRadius        = 500,
    Snapline         = false,
    TargetPart       = "Head",
    FovColorR=255, FovColorG=255, FovColorB=255,
    SnapColorR=255, SnapColorG=255, SnapColorB=255,
    EspEnabled       = false,
    EspBox           = true,
    EspSkeleton      = true,
    EspHealthBar     = true,
    EspDistance      = true,
    EspNames         = true,
    EspMaxDist       = 500,
    BoxColorR=0,   BoxColorG=220, BoxColorB=255,
    SkelColorR=0,  SkelColorG=220,SkelColorB=255,
    NameColorR=255,NameColorG=255,NameColorB=255,
    RoundToggles   = false,
    AutoLoadTheme  = false,
    Whitelist      = {},
}

local Config = {}

local function deepCopy(t)
    local c = {}
    for k,v in pairs(t) do c[k] = type(v)=="table" and deepCopy(v) or v end
    return c
end

local function loadConfig()
    if HAS_READFILE then
        local ok = pcall(function()
            local raw     = readfile(CONFIG_FILE)
            local decoded = HttpService:JSONDecode(raw)
            for k,v in pairs(DefaultConfig) do
                Config[k] = decoded[k] ~= nil and decoded[k] or (type(v)=="table" and deepCopy(v) or v)
            end
        end)
        if ok then print("[NEXUS] Config cargada."); return end
    end
    Config = deepCopy(DefaultConfig)
    print("[NEXUS] Config por defecto aplicada.")
end

local function saveConfig()
    if not HAS_READFILE then return end
    pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(Config)) end)
end

loadConfig()

-- ══════════════════════════════════════════════════════════════
-- WHITELIST
-- ══════════════════════════════════════════════════════════════
local function isWhitelisted(p)
    for _,n in ipairs(Config.Whitelist) do
        if n:lower() == p.Name:lower() then return true end
    end
    return false
end
local function addWhitelist(name)
    if name == "" then return false end
    for _,n in ipairs(Config.Whitelist) do
        if n:lower() == name:lower() then return false end
    end
    table.insert(Config.Whitelist, name); saveConfig(); return true
end
local function removeWhitelist(name)
    for i,n in ipairs(Config.Whitelist) do
        if n:lower() == name:lower() then
            table.remove(Config.Whitelist, i); saveConfig(); return true
        end
    end
    return false
end

-- ══════════════════════════════════════════════════════════════
-- CONEXIONES (para cleanup al destruir)
-- ══════════════════════════════════════════════════════════════
local _connections = {}
local function trackConn(c) table.insert(_connections, c) end

local function cleanupAll()
    for _,c in ipairs(_connections) do pcall(function() c:Disconnect() end) end
    _connections = {}
end

-- ══════════════════════════════════════════════════════════════
-- LIMPIEZA PREVIA
-- ══════════════════════════════════════════════════════════════
local oldGui = playerGui:FindFirstChild("NexusSystemUI")
if oldGui then oldGui:Destroy() end

-- ══════════════════════════════════════════════════════════════
-- SCREEN GUI
-- ══════════════════════════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name           = "NexusSystemUI"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder   = 99
gui.Parent         = playerGui

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
    l.Parent             = parent; return l
end

-- ══════════════════════════════════════════════════════════════
-- PANEL PRINCIPAL — 600×800 por defecto
-- ══════════════════════════════════════════════════════════════
local MIN_W, MIN_H   = 300, 400
local panelW, panelH = 600, 800
local isMinimized    = false
local MINI_H         = 48

local main = Instance.new("Frame")
main.Name                   = "NexusPanel"
main.Size                   = UDim2.fromOffset(panelW, panelH)
main.Position               = UDim2.new(0.5, -panelW/2, 0.5, -panelH/2)
main.BackgroundColor3       = Color3.fromRGB(4, 12, 24)
main.BackgroundTransparency = 0.05
main.BorderSizePixel        = 0
main.ClipsDescendants       = true
main.Parent                 = gui
corner(main, 8)

local mainStroke = stroke(main, Color3.fromRGB(0,190,255), 2, 0.05)

local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,    Color3.fromRGB(0,  34,  70)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(5,  13,  26)),
    ColorSequenceKeypoint.new(1,    Color3.fromRGB(0,  78, 126)),
})
grad.Rotation = 35
grad.Parent   = main

-- ── Header ────────────────────────────────────────────────────
local headerH = 48
local header  = Instance.new("Frame")
header.Name                  = "Header"
header.Size                  = UDim2.new(1, 0, 0, headerH)
header.BackgroundColor3      = Color3.fromRGB(2, 10, 22)
header.BackgroundTransparency= 0.1
header.BorderSizePixel       = 0
header.ZIndex                = 3
header.Parent                = main

local logo = Instance.new("ImageLabel")
logo.Size               = UDim2.fromOffset(34, 34)
logo.Position           = UDim2.fromOffset(8, 7)
logo.BackgroundTransparency = 1
logo.Image              = LOGO_IMAGE_ID
logo.ImageColor3        = Color3.fromRGB(120, 232, 255)
logo.ZIndex             = 4
logo.Parent             = header

local titleLbl = Instance.new("TextLabel")
titleLbl.Size             = UDim2.new(1,-200,1,0)
titleLbl.Position         = UDim2.fromOffset(50, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text             = "NEXUS  v5.0"
titleLbl.TextColor3       = Color3.fromRGB(205,250,255)
titleLbl.Font             = Enum.Font.GothamBlack
titleLbl.TextSize         = 20
titleLbl.TextXAlignment   = Enum.TextXAlignment.Left
titleLbl.ZIndex           = 4
titleLbl.Parent           = header

local subtitleLbl = Instance.new("TextLabel")
subtitleLbl.Size             = UDim2.new(1,-200,0,14)
subtitleLbl.Position         = UDim2.fromOffset(51, 28)
subtitleLbl.BackgroundTransparency = 1
subtitleLbl.Text             = "Hecho por EnanoTop1 (stx)"
subtitleLbl.TextColor3       = Color3.fromRGB(70,210,255)
subtitleLbl.Font             = Enum.Font.GothamMedium
subtitleLbl.TextSize         = 11
subtitleLbl.TextXAlignment   = Enum.TextXAlignment.Left
subtitleLbl.ZIndex           = 4
subtitleLbl.Parent           = header

-- Botón minimizar
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size             = UDim2.fromOffset(34, 34)
minimizeBtn.Position         = UDim2.new(1,-78, 0, 7)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(0,40,70)
minimizeBtn.BorderSizePixel  = 0
minimizeBtn.Text             = "—"
minimizeBtn.TextColor3       = Color3.fromRGB(150,230,255)
minimizeBtn.Font             = Enum.Font.GothamBold
minimizeBtn.TextSize         = 16
minimizeBtn.AutoButtonColor  = false
minimizeBtn.ZIndex           = 6
minimizeBtn.Parent           = header
corner(minimizeBtn, 6)
stroke(minimizeBtn, Color3.fromRGB(0,160,255), 1, 0.3)

-- Botón cerrar
local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.fromOffset(34, 34)
closeBtn.Position         = UDim2.new(1,-40, 0, 7)
closeBtn.BackgroundColor3 = Color3.fromRGB(60,10,10)
closeBtn.BorderSizePixel  = 0
closeBtn.Text             = "×"
closeBtn.TextColor3       = Color3.fromRGB(255,90,90)
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.TextSize         = 20
closeBtn.AutoButtonColor  = false
closeBtn.ZIndex           = 6
closeBtn.Parent           = header
corner(closeBtn, 6)
stroke(closeBtn, Color3.fromRGB(200,30,30), 1, 0.3)

-- Lógica minimizar/restaurar
local function toggleMinimize()
    isMinimized = not isMinimized
    if isMinimized then
        minimizeBtn.Text = "▢"
        TweenService:Create(main, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            Size = UDim2.fromOffset(main.AbsoluteSize.X, MINI_H)
        }):Play()
    else
        minimizeBtn.Text = "—"
        TweenService:Create(main, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            Size = UDim2.fromOffset(main.AbsoluteSize.X, panelH)
        }):Play()
    end
end
minimizeBtn.MouseButton1Click:Connect(toggleMinimize)
closeBtn.MouseButton1Click:Connect(function() main.Visible = false end)

-- ── Perfil card ───────────────────────────────────────────────
local profileY = headerH + 6
local profileCard = Instance.new("Frame")
profileCard.Size              = UDim2.new(1,-24,0,44)
profileCard.Position          = UDim2.fromOffset(12, profileY)
profileCard.BackgroundColor3  = Color3.fromRGB(3,18,36)
profileCard.BackgroundTransparency = 0.2
profileCard.BorderSizePixel   = 0
profileCard.Parent            = main
corner(profileCard, 5)
stroke(profileCard, Color3.fromRGB(0,180,255), 1, 0.3)

local avatarImg = Instance.new("ImageLabel")
avatarImg.Size              = UDim2.fromOffset(34, 34)
avatarImg.Position          = UDim2.fromOffset(6, 5)
avatarImg.BackgroundTransparency = 0.4
avatarImg.BorderSizePixel   = 0
avatarImg.Image             = ("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=150&height=150&format=png"):format(player.UserId)
avatarImg.Parent            = profileCard
corner(avatarImg, 4)

label(profileCard, player.DisplayName,
    48, 4,  300, 18, 14, Enum.Font.GothamBold, Color3.fromRGB(210,248,255))
label(profileCard, "@"..player.Name.."  ·  ID "..player.UserId,
    48, 24, 320, 14, 11, Enum.Font.GothamMedium, Color3.fromRGB(100,190,230))

-- ══════════════════════════════════════════════════════════════
-- TABS
-- ══════════════════════════════════════════════════════════════
local tabY    = profileY + 44 + 8
local tabBarH = 38
local contentY = tabY + tabBarH + 6
local contentH = panelH - contentY - 10

local tabBar = Instance.new("Frame")
tabBar.Size             = UDim2.new(1,-24,0,tabBarH)
tabBar.Position         = UDim2.fromOffset(12, tabY)
tabBar.BackgroundColor3 = Color3.fromRGB(3,14,26)
tabBar.BorderSizePixel  = 0
tabBar.Parent           = main
corner(tabBar, 6)
stroke(tabBar, Color3.fromRGB(0,160,255), 1, 0.4)

local tabNames = {"Aimbot","Visuals","Settings"}
local tabBtns  = {}
local tabPages = {}
local activeTab = 1

-- Función que recalcula las páginas al resize
local function recalcLayout()
    contentH = panelH - contentY - 10
    for _,page in ipairs(tabPages) do
        page.Size = UDim2.new(1,-24, 0, contentH)
    end
end

local function makeTabPage()
    local page = Instance.new("ScrollingFrame")
    page.Size                  = UDim2.new(1,-24, 0, contentH)
    page.Position              = UDim2.fromOffset(12, contentY)
    page.BackgroundColor3      = Color3.fromRGB(3,14,26)
    page.BackgroundTransparency= 0.2
    page.BorderSizePixel       = 0
    page.ScrollBarThickness    = 5
    page.ScrollBarImageColor3  = Color3.fromRGB(0,190,255)
    -- Canvas manual para evitar lag de AutomaticCanvasSize
    page.CanvasSize            = UDim2.new(0,0,0,2000)
    page.AutomaticCanvasSize   = Enum.AutomaticSize.None
    page.Visible               = false
    page.Parent                = main
    corner(page, 6)
    stroke(page, Color3.fromRGB(0,160,255), 1, 0.35)
    local pad = Instance.new("UIPadding")
    pad.PaddingTop=UDim.new(0,8); pad.PaddingLeft=UDim.new(0,10)
    pad.PaddingRight=UDim.new(0,10); pad.PaddingBottom=UDim.new(0,8)
    pad.Parent = page
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding   = UDim.new(0,8)
    layout.Parent    = page
    -- Actualiza canvas al cambiar contenido
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0,0,0, layout.AbsoluteContentSize.Y + 20)
    end)
    return page
end

for i, name in ipairs(tabNames) do
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(1/#tabNames,-4,1,-6)
    btn.Position         = UDim2.new((i-1)/#tabNames,2,0,3)
    btn.BackgroundColor3 = (i==1) and Color3.fromRGB(0,50,80) or Color3.fromRGB(4,18,30)
    btn.BorderSizePixel  = 0
    btn.Text             = name
    btn.TextColor3       = Color3.fromRGB(180,240,255)
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 14
    btn.AutoButtonColor  = false
    btn.Parent           = tabBar
    corner(btn, 5)
    tabBtns[i]  = btn
    tabPages[i] = makeTabPage()
    btn.MouseButton1Click:Connect(function()
        for j,p in ipairs(tabPages) do
            p.Visible = (j==i)
            tabBtns[j].BackgroundColor3 = (j==i) and Color3.fromRGB(0,50,80) or Color3.fromRGB(4,18,30)
        end
        activeTab = i
    end)
end
tabPages[1].Visible = true

-- ══════════════════════════════════════════════════════════════
-- HELPERS DE CONTROLES
-- ══════════════════════════════════════════════════════════════
local function sectionLabel(page, text)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,22); f.BackgroundTransparency=1; f.Parent=page
    local l = Instance.new("TextLabel")
    l.Size=UDim2.new(1,0,1,0); l.BackgroundTransparency=1
    l.Text="━━  "..text.."  ━━"; l.TextColor3=Color3.fromRGB(0,200,255)
    l.Font=Enum.Font.GothamBlack; l.TextSize=12; l.TextXAlignment=Enum.TextXAlignment.Left
    l.Parent=f; return f
end

local function makeToggle(page, text, configKey, callback)
    local row = Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,38); row.BackgroundColor3=Color3.fromRGB(4,22,38)
    row.BorderSizePixel=0; row.Parent=page
    corner(row,6); stroke(row,Color3.fromRGB(0,160,255),1,0.45)

    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-58,1,0); lbl.Position=UDim2.fromOffset(12,0)
    lbl.BackgroundTransparency=1; lbl.Text=text
    lbl.TextColor3=Color3.fromRGB(195,245,255); lbl.Font=Enum.Font.GothamMedium
    lbl.TextSize=13; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row

    local togBg=Instance.new("Frame")
    togBg.Size=UDim2.fromOffset(46,24); togBg.Position=UDim2.new(1,-52,0.5,-12)
    togBg.BorderSizePixel=0; togBg.Parent=row; corner(togBg,12)

    local togKnob=Instance.new("Frame")
    togKnob.Size=UDim2.fromOffset(20,20); togKnob.Position=UDim2.fromOffset(2,2)
    togKnob.BackgroundColor3=Color3.fromRGB(255,255,255); togKnob.BorderSizePixel=0
    togKnob.Parent=togBg; corner(togKnob,10)

    local function refresh()
        local on=Config[configKey]
        togBg.BackgroundColor3 = on and Color3.fromRGB(0,180,80) or Color3.fromRGB(40,60,75)
        TweenService:Create(togKnob,TweenInfo.new(0.12),{
            Position=on and UDim2.fromOffset(24,2) or UDim2.fromOffset(2,2)}):Play()
    end
    refresh()

    local hitbox=Instance.new("TextButton")
    hitbox.Size=UDim2.new(1,0,1,0); hitbox.BackgroundTransparency=1
    hitbox.Text=""; hitbox.ZIndex=2; hitbox.Parent=row
    hitbox.MouseButton1Click:Connect(function()
        Config[configKey]=not Config[configKey]; refresh(); saveConfig()
        if callback then callback(Config[configKey]) end
    end)
    return row, refresh
end

local function makeSliderRow(page, text, configKey, minV, maxV, callback)
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,56); row.BackgroundColor3=Color3.fromRGB(4,22,38)
    row.BorderSizePixel=0; row.Parent=page
    corner(row,6); stroke(row,Color3.fromRGB(0,160,255),1,0.45)

    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,0,0,20); lbl.Position=UDim2.fromOffset(12,6)
    lbl.BackgroundTransparency=1; lbl.Text=text..": "..tostring(Config[configKey])
    lbl.TextColor3=Color3.fromRGB(195,245,255); lbl.Font=Enum.Font.GothamMedium
    lbl.TextSize=13; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row

    local bar=Instance.new("Frame")
    bar.Size=UDim2.new(1,-24,0,9); bar.Position=UDim2.fromOffset(12,33)
    bar.BackgroundColor3=Color3.fromRGB(12,45,65); bar.BorderSizePixel=0
    bar.Parent=row; corner(bar,9)

    local fill=Instance.new("Frame")
    local initA=math.clamp((Config[configKey]-minV)/(maxV-minV),0,1)
    fill.Size=UDim2.new(initA,0,1,0); fill.BackgroundColor3=Color3.fromRGB(0,200,255)
    fill.BorderSizePixel=0; fill.Parent=bar; corner(fill,9)

    local dragging=false
    local function update(ix)
        local alpha=math.clamp((ix-bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1)
        local value=math.floor(minV+(maxV-minV)*alpha)
        Config[configKey]=value; fill.Size=UDim2.new(alpha,0,1,0)
        lbl.Text=text..": "..tostring(value)
        if callback then callback(value) end; saveConfig()
    end
    trackConn(bar.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            dragging=true; update(inp.Position.X) end end))
    trackConn(UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then dragging=false end end))
    trackConn(UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement
        or inp.UserInputType==Enum.UserInputType.Touch) then update(inp.Position.X) end end))
    return row
end

local function makeColorRow(page, text, rKey, gKey, bKey)
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,38); row.BackgroundColor3=Color3.fromRGB(4,22,38)
    row.BorderSizePixel=0; row.Parent=page
    corner(row,6); stroke(row,Color3.fromRGB(0,160,255),1,0.45)

    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-54,1,0); lbl.Position=UDim2.fromOffset(12,0)
    lbl.BackgroundTransparency=1; lbl.Text=text
    lbl.TextColor3=Color3.fromRGB(195,245,255); lbl.Font=Enum.Font.GothamMedium
    lbl.TextSize=13; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row

    local swatch=Instance.new("Frame")
    swatch.Size=UDim2.fromOffset(32,22); swatch.Position=UDim2.new(1,-38,0.5,-11)
    swatch.BackgroundColor3=Color3.fromRGB(Config[rKey],Config[gKey],Config[bKey])
    swatch.BorderSizePixel=0; swatch.Parent=row
    corner(swatch,4); stroke(swatch,Color3.fromRGB(0,190,255),1,0.2)

    local presets={{255,255,255},{0,220,255},{80,255,160},{255,80,80},{255,200,0},{200,0,255}}
    local pi=1
    local hitbox=Instance.new("TextButton")
    hitbox.Size=UDim2.new(1,0,1,0); hitbox.BackgroundTransparency=1
    hitbox.Text=""; hitbox.ZIndex=2; hitbox.Parent=row
    hitbox.MouseButton1Click:Connect(function()
        pi=(pi%#presets)+1
        local p=presets[pi]
        Config[rKey]=p[1]; Config[gKey]=p[2]; Config[bKey]=p[3]
        swatch.BackgroundColor3=Color3.fromRGB(p[1],p[2],p[3])
        saveConfig()
    end)
    return row
end

local function makeDropdown(page, text, configKey, options, callback)
    local open=false
    local container=Instance.new("Frame")
    container.Size=UDim2.new(1,0,0,38); container.BackgroundTransparency=1
    container.ClipsDescendants=false; container.Parent=page

    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,38); row.BackgroundColor3=Color3.fromRGB(4,22,38)
    row.BorderSizePixel=0; row.Parent=container
    corner(row,6); stroke(row,Color3.fromRGB(0,160,255),1,0.45)

    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-60,1,0); lbl.Position=UDim2.fromOffset(12,0)
    lbl.BackgroundTransparency=1; lbl.Text=text..": "..Config[configKey]
    lbl.TextColor3=Color3.fromRGB(195,245,255); lbl.Font=Enum.Font.GothamMedium
    lbl.TextSize=13; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row

    local arrow=Instance.new("TextLabel")
    arrow.Size=UDim2.fromOffset(30,24); arrow.Position=UDim2.new(1,-36,0.5,-12)
    arrow.BackgroundTransparency=1; arrow.Text="▾"
    arrow.TextColor3=Color3.fromRGB(0,200,255); arrow.Font=Enum.Font.GothamBold
    arrow.TextSize=18; arrow.Parent=row

    local dropList=Instance.new("Frame")
    dropList.Size=UDim2.new(1,0,0,#options*32)
    dropList.Position=UDim2.fromOffset(0,40)
    dropList.BackgroundColor3=Color3.fromRGB(3,16,28)
    dropList.BorderSizePixel=0; dropList.Visible=false; dropList.ZIndex=10
    dropList.Parent=container
    corner(dropList,6); stroke(dropList,Color3.fromRGB(0,160,255),1,0.3)

    for idx,opt in ipairs(options) do
        local ob=Instance.new("TextButton")
        ob.Size=UDim2.new(1,0,0,30); ob.Position=UDim2.fromOffset(0,(idx-1)*32)
        ob.BackgroundColor3=Color3.fromRGB(4,22,38); ob.BorderSizePixel=0
        ob.Text=opt; ob.Font=Enum.Font.GothamMedium; ob.TextSize=13
        ob.TextColor3=(Config[configKey]==opt) and Color3.fromRGB(80,255,160) or Color3.fromRGB(190,240,255)
        ob.AutoButtonColor=false; ob.ZIndex=11; ob.Parent=dropList
        ob.MouseButton1Click:Connect(function()
            Config[configKey]=opt; lbl.Text=text..": "..opt
            for _,b in ipairs(dropList:GetChildren()) do
                if b:IsA("TextButton") then
                    b.TextColor3=(b.Text==opt) and Color3.fromRGB(80,255,160) or Color3.fromRGB(190,240,255)
                end
            end
            dropList.Visible=false; open=false
            container.Size=UDim2.new(1,0,0,38); saveConfig()
            if callback then callback(opt) end
        end)
    end
    local hitbox=Instance.new("TextButton")
    hitbox.Size=UDim2.new(1,0,1,0); hitbox.BackgroundTransparency=1
    hitbox.Text=""; hitbox.ZIndex=2; hitbox.Parent=row
    hitbox.MouseButton1Click:Connect(function()
        open=not open; dropList.Visible=open
        container.Size=open and UDim2.new(1,0,0,38+#options*32) or UDim2.new(1,0,0,38)
        arrow.Text=open and "▴" or "▾"
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
makeToggle(pageAim,    "Team Check",    "TeamCheck")
makeToggle(pageAim,    "Manipulation",  "Manipulation")
makeSliderRow(pageAim, "HitChance %",   "HitChance", 1, 100)
sectionLabel(pageAim, "FOV")
makeToggle(pageAim,    "FOV Circle",    "FovEnabled")
makeSliderRow(pageAim, "Fov Radius",    "FovRadius", 50, 600)
makeColorRow(pageAim,  "FOV Color",     "FovColorR","FovColorG","FovColorB")
sectionLabel(pageAim, "Snapline")
makeToggle(pageAim,    "Snapline",      "Snapline")
makeColorRow(pageAim,  "Snapline Color","SnapColorR","SnapColorG","SnapColorB")
sectionLabel(pageAim, "Target Part")
makeDropdown(pageAim, "Target Part", "TargetPart", {"Head","UpperTorso","LowerTorso","Random"})

-- ══════════════════════════════════════════════════════════════
-- TAB 2: VISUALS
-- ══════════════════════════════════════════════════════════════
local pageVis = tabPages[2]
sectionLabel(pageVis, "ESP")
makeToggle(pageVis, "ESP Enabled",    "EspEnabled")
makeToggle(pageVis, "Box",            "EspBox")
makeColorRow(pageVis,"Box Color",     "BoxColorR","BoxColorG","BoxColorB")
makeToggle(pageVis, "Skeleton",       "EspSkeleton")
makeColorRow(pageVis,"Skeleton Color","SkelColorR","SkelColorG","SkelColorB")
makeToggle(pageVis, "Health Bar",     "EspHealthBar")
makeToggle(pageVis, "Distancia",      "EspDistance")
makeToggle(pageVis, "Nombres",        "EspNames")
makeColorRow(pageVis,"Name Color",    "NameColorR","NameColorG","NameColorB")
makeSliderRow(pageVis,"Dist Máx",     "EspMaxDist", 50, 1000)

-- ══════════════════════════════════════════════════════════════
-- TAB 3: SETTINGS
-- ══════════════════════════════════════════════════════════════
local pageSet = tabPages[3]
sectionLabel(pageSet, "General")
makeToggle(pageSet, "Round Toggles",  "RoundToggles")
makeToggle(pageSet, "Auto Load Theme","AutoLoadTheme")

sectionLabel(pageSet, "Lista Blanca (Whitelist)")
do
    local inputRow=Instance.new("Frame")
    inputRow.Size=UDim2.new(1,0,0,38); inputRow.BackgroundColor3=Color3.fromRGB(4,22,38)
    inputRow.BorderSizePixel=0; inputRow.Parent=pageSet
    corner(inputRow,6); stroke(inputRow,Color3.fromRGB(0,160,255),1,0.45)

    local nameBox=Instance.new("TextBox")
    nameBox.Size=UDim2.new(1,-84,1,-8); nameBox.Position=UDim2.fromOffset(6,4)
    nameBox.BackgroundColor3=Color3.fromRGB(3,14,26); nameBox.BorderSizePixel=0
    nameBox.Text=""; nameBox.PlaceholderText="Nombre de usuario..."
    nameBox.PlaceholderColor3=Color3.fromRGB(90,130,160)
    nameBox.TextColor3=Color3.fromRGB(200,248,255); nameBox.Font=Enum.Font.GothamMedium
    nameBox.TextSize=13; nameBox.ClearTextOnFocus=false; nameBox.Parent=inputRow
    corner(nameBox,4)

    local addBtn=Instance.new("TextButton")
    addBtn.Size=UDim2.fromOffset(70,28); addBtn.Position=UDim2.new(1,-76,0.5,-14)
    addBtn.BackgroundColor3=Color3.fromRGB(0,50,30); addBtn.BorderSizePixel=0
    addBtn.Text="+ Add"; addBtn.TextColor3=Color3.fromRGB(80,255,160)
    addBtn.Font=Enum.Font.GothamBold; addBtn.TextSize=12
    addBtn.AutoButtonColor=false; addBtn.Parent=inputRow
    corner(addBtn,4); stroke(addBtn,Color3.fromRGB(0,200,80),1,0.3)

    local wlListFrame=Instance.new("Frame")
    wlListFrame.Size=UDim2.new(1,0,0,0); wlListFrame.BackgroundTransparency=1
    wlListFrame.BorderSizePixel=0; wlListFrame.AutomaticSize=Enum.AutomaticSize.Y
    wlListFrame.Parent=pageSet
    local wlLayout=Instance.new("UIListLayout")
    wlLayout.SortOrder=Enum.SortOrder.LayoutOrder; wlLayout.Padding=UDim.new(0,4)
    wlLayout.Parent=wlListFrame

    local function rebuildWL()
        for _,c in ipairs(wlListFrame:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        for _,name in ipairs(Config.Whitelist) do
            local entry=Instance.new("Frame")
            entry.Size=UDim2.new(1,0,0,30); entry.BackgroundColor3=Color3.fromRGB(5,25,15)
            entry.BorderSizePixel=0; entry.Parent=wlListFrame
            corner(entry,4); stroke(entry,Color3.fromRGB(0,180,80),1,0.4)
            local nl=Instance.new("TextLabel")
            nl.Size=UDim2.new(1,-40,1,0); nl.Position=UDim2.fromOffset(8,0)
            nl.BackgroundTransparency=1; nl.Text="✓ "..name
            nl.TextColor3=Color3.fromRGB(80,255,160); nl.Font=Enum.Font.GothamMedium
            nl.TextSize=12; nl.TextXAlignment=Enum.TextXAlignment.Left; nl.Parent=entry
            local db=Instance.new("TextButton")
            db.Size=UDim2.fromOffset(30,22); db.Position=UDim2.new(1,-34,0.5,-11)
            db.BackgroundColor3=Color3.fromRGB(60,10,10); db.BorderSizePixel=0
            db.Text="✕"; db.TextColor3=Color3.fromRGB(255,80,80)
            db.Font=Enum.Font.GothamBold; db.TextSize=12
            db.AutoButtonColor=false; db.Parent=entry; corner(db,4)
            db.MouseButton1Click:Connect(function() removeWhitelist(name); rebuildWL() end)
        end
    end
    rebuildWL()
    addBtn.MouseButton1Click:Connect(function()
        local n=nameBox.Text:match("^%s*(.-)%s*$")
        if addWhitelist(n) then
            nameBox.Text=""; rebuildWL(); addBtn.Text="✅"
            task.delay(1,function() addBtn.Text="+ Add" end)
        else
            addBtn.Text="Ya existe"
            task.delay(1.2,function() addBtn.Text="+ Add" end)
        end
    end)
end

sectionLabel(pageSet, "Config")
do
    local btn=Instance.new("TextButton")
    btn.Size=UDim2.new(1,0,0,40); btn.BackgroundColor3=Color3.fromRGB(0,50,30)
    btn.BorderSizePixel=0; btn.Text="💾  Guardar Config"
    btn.TextColor3=Color3.fromRGB(100,255,160); btn.Font=Enum.Font.GothamBold
    btn.TextSize=14; btn.AutoButtonColor=false; btn.Parent=pageSet
    corner(btn,6); stroke(btn,Color3.fromRGB(0,200,80),1,0.3)
    btn.MouseButton1Click:Connect(function()
        saveConfig(); btn.Text="✅  Guardado!"
        task.delay(1.5,function() btn.Text="💾  Guardar Config" end)
    end)
end
do
    local btn=Instance.new("TextButton")
    btn.Size=UDim2.new(1,0,0,40); btn.BackgroundColor3=Color3.fromRGB(50,10,10)
    btn.BorderSizePixel=0; btn.Text="🔄  Resetear Config"
    btn.TextColor3=Color3.fromRGB(255,100,100); btn.Font=Enum.Font.GothamBold
    btn.TextSize=14; btn.AutoButtonColor=false; btn.Parent=pageSet
    corner(btn,6); stroke(btn,Color3.fromRGB(200,0,0),1,0.3)
    btn.MouseButton1Click:Connect(function()
        Config=deepCopy(DefaultConfig); saveConfig()
        btn.Text="✅  Reseteado — recarga el script"
        task.delay(2,function() btn.Text="🔄  Resetear Config" end)
    end)
end
sectionLabel(pageSet,"Info")
do
    local info=Instance.new("TextLabel")
    info.Size=UDim2.new(1,0,0,90); info.BackgroundColor3=Color3.fromRGB(3,14,26)
    info.BackgroundTransparency=0.3; info.BorderSizePixel=0
    info.Text="NEXUS v5.0\nEnanoTop1 (stx)\n\nConfig: "..CONFIG_FILE
        .."\nUser: "..player.Name
        .."\nHook: "..(HAS_METAMETHODS and "✅" or "❌")
        .."\nDrawing: "..(HAS_DRAWING and "✅" or "❌")
    info.TextColor3=Color3.fromRGB(140,210,255); info.Font=Enum.Font.GothamMedium
    info.TextSize=12; info.TextWrapped=true; info.Parent=pageSet; corner(info,6)
end

-- ══════════════════════════════════════════════════════════════
-- DRAWING WRAPPERS (con cleanup garantizado)
-- ══════════════════════════════════════════════════════════════
local _drawings = {}
local function newDrawing(dtype, props)
    if not HAS_DRAWING then return {Visible=false,Remove=function()end} end
    local ok,d = pcall(function() return Drawing.new(dtype) end)
    if not ok then return {Visible=false,Remove=function()end} end
    for k,v in pairs(props or {}) do d[k]=v end
    table.insert(_drawings, d)
    return d
end
local function cleanupDrawings()
    for _,d in ipairs(_drawings) do
        pcall(function() d:Remove() end)
    end
    _drawings = {}
end

local fovCircle = newDrawing("Circle",{Visible=false,Thickness=1.5,Filled=false})
local snapLineDraw = newDrawing("Line",{Visible=false,Thickness=1.5})

-- ══════════════════════════════════════════════════════════════
-- ESP
-- ══════════════════════════════════════════════════════════════
local espObjects = {}

local SKELETON_PAIRS = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
}

local function createEsp(p)
    if p==player then return end
    local obj={
        box      = newDrawing("Square",{Color=Color3.fromRGB(0,220,255),Filled=false,Thickness=1.5,Visible=false}),
        nameTag  = newDrawing("Text",  {Size=14,Color=Color3.fromRGB(255,255,255),Outline=true,Visible=false}),
        distTag  = newDrawing("Text",  {Size=12,Color=Color3.fromRGB(160,230,255),Outline=true,Visible=false}),
        healthBg = newDrawing("Square",{Color=Color3.fromRGB(30,30,30),Filled=true, Thickness=1,Visible=false}),
        healthBar= newDrawing("Square",{Color=Color3.fromRGB(80,255,80),Filled=true, Thickness=1,Visible=false}),
        skeleton = {},
    }
    for _=1,#SKELETON_PAIRS do
        table.insert(obj.skeleton, newDrawing("Line",{Color=Color3.fromRGB(0,220,255),Thickness=1,Visible=false}))
    end
    espObjects[p]=obj
end

local function removeEsp(p)
    local obj=espObjects[p]
    if not obj then return end
    obj.box:Remove(); obj.nameTag:Remove(); obj.distTag:Remove()
    obj.healthBg:Remove(); obj.healthBar:Remove()
    for _,l in ipairs(obj.skeleton) do l:Remove() end
    espObjects[p]=nil
end

for _,p in ipairs(Players:GetPlayers()) do createEsp(p) end
trackConn(Players.PlayerAdded:Connect(createEsp))
trackConn(Players.PlayerRemoving:Connect(removeEsp))

-- ══════════════════════════════════════════════════════════════
-- SILENT AIM — TARGET CACHEADO
-- ══════════════════════════════════════════════════════════════
local _cachedTarget    = nil
local _cacheTime       = 0
local CACHE_INTERVAL   = 0.05   -- recalcula target cada 50ms, no cada raycast

local function getTargetPart(char)
    local part = Config.TargetPart
    if part=="Random" then
        local r=math.random(3)
        part = r==1 and "Head" or r==2 and "UpperTorso" or "LowerTorso"
    end
    return char:FindFirstChild(part) or char:FindFirstChild("HumanoidRootPart")
end

-- VisibleCheck mejorado: filtra personaje local Y el target
local function isVisible(origin, targetPart, targetChar)
    local dir = (targetPart.Position - origin)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {player.Character, targetChar}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local result = Workspace:Raycast(origin, dir, params)
    return result == nil  -- nil = nada en medio = visible
end

local function getBestTarget()
    local now = tick()
    if now - _cacheTime < CACHE_INTERVAL and _cachedTarget then
        -- validar que el cache sigue vivo
        if _cachedTarget.Character and _cachedTarget.Parent then
            return _cachedTarget
        end
    end

    local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    local bestP, bestD = nil, math.huge

    for _,p in ipairs(Players:GetPlayers()) do
        if p==player then continue end
        if isWhitelisted(p) then continue end

        -- Team Check
        if Config.TeamCheck and player.Team and p.Team and player.Team==p.Team then continue end

        local char=p.Character
        if not char then continue end
        local hum=char:FindFirstChildOfClass("Humanoid")
        local root=char:FindFirstChild("HumanoidRootPart")
        if not hum or hum.Health<=0 or not root then continue end

        local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
        if not onScreen then continue end

        local dist2D=(Vector2.new(screenPos.X,screenPos.Y)-center).Magnitude
        if dist2D>Config.FovRadius then continue end

        if Config.VisibleCheck then
            local ok,vis=pcall(isVisible, camera.CFrame.Position, root, char)
            if ok and not vis then continue end
        end

        if dist2D<bestD then bestD=dist2D; bestP=p end
    end

    _cachedTarget=bestP; _cacheTime=now
    return bestP
end

-- ══════════════════════════════════════════════════════════════
-- FAB (botón flotante) — definido ANTES del hook para que
-- syncFAB() exista cuando el hook lo necesite
-- ══════════════════════════════════════════════════════════════
local floating = Instance.new("ImageButton")
floating.Name             = "NexusFloatingToggle"
floating.Size             = UDim2.fromOffset(72,72)
floating.Position         = UDim2.new(1,-90,0.5,-36)
floating.BackgroundColor3 = Color3.fromRGB(3,18,32)
floating.BorderSizePixel  = 0
floating.AutoButtonColor  = false
floating.Image            = ""
floating.ZIndex           = 20
floating.Parent           = gui
corner(floating,72)

local floatStroke=stroke(floating,Color3.fromRGB(0,200,255),2,0.05)

local floatLogo=Instance.new("ImageLabel")
floatLogo.Size=UDim2.fromOffset(46,46); floatLogo.AnchorPoint=Vector2.new(0.5,0.5)
floatLogo.Position=UDim2.new(0.5,0,0.5,0); floatLogo.BackgroundTransparency=1
floatLogo.Image=LOGO_IMAGE_ID; floatLogo.ImageColor3=Color3.fromRGB(125,235,255)
floatLogo.Parent=floating

local activeDot=Instance.new("Frame")
activeDot.Size=UDim2.fromOffset(13,13); activeDot.Position=UDim2.new(1,-15,0,4)
activeDot.BackgroundColor3=Color3.fromRGB(90,110,120); activeDot.BorderSizePixel=0
activeDot.ZIndex=21; activeDot.Parent=floating; corner(activeDot,13)

-- syncFAB declarado ANTES del hook
local function syncFAB()
    local on=Config.SilentAimEnabled or Config.EspEnabled
    activeDot.BackgroundColor3=on and Color3.fromRGB(85,255,165) or Color3.fromRGB(90,110,120)
    floatStroke.Color=on and Color3.fromRGB(85,255,165) or Color3.fromRGB(0,200,255)
end

-- ══════════════════════════════════════════════════════════════
-- HOOK __namecall — ANTI-CRASH + ANTI-CÁMARA
-- ══════════════════════════════════════════════════════════════
local _inHook = false

if HAS_METAMETHODS then
    local mt=getrawmetatable(game)
    local oldNC
    local ok,msg=pcall(function()
        setreadonly(mt,false)
        oldNC=mt.__namecall
        mt.__namecall=newcclosure(function(self,...)
            -- Evitar re-entrada recursiva
            if _inHook then return oldNC(self,...) end

            local method=getnamecallmethod()

            -- Solo interceptar si es Raycast Y el llamador es Workspace o un Tool/weapon,
            -- NO si self es la cámara (eso congela la pantalla)
            if Config.SilentAimEnabled
            and (method=="Raycast" or method=="FindPartOnRayWithIgnoreList")
            and self ~= camera          -- ← CLAVE: no tocar raycasts de la cámara
            and self ~= Workspace.Terrain then

                -- HitChance: usar random FUERA del hook para no ralentizar
                if math.random(100) <= Config.HitChance then
                    _inHook=true
                    local target=nil
                    pcall(function() target=getBestTarget() end)
                    _inHook=false

                    if target and target.Character then
                        local part=getTargetPart(target.Character)
                        if part then
                            local origin=camera.CFrame.Position
                            local dir=(part.Position-origin)

                            if Config.Manipulation then
                                -- Ruido sub-pixel para evadir detección
                                local n=0.008
                                dir=dir+Vector3.new(
                                    (math.random()-0.5)*n,
                                    (math.random()-0.5)*n,
                                    (math.random()-0.5)*n)
                            end

                            -- Usar SOLO Raycast moderno
                            if method=="Raycast" then
                                local args={...}
                                args[1]=origin; args[2]=dir
                                return oldNC(self,table.unpack(args))
                            else
                                -- FindPartOnRay legacy: re-mapear a Raycast moderno
                                local rp=RaycastParams.new()
                                rp.FilterType=Enum.RaycastFilterType.Exclude
                                rp.FilterDescendantsInstances={player.Character}
                                local res=Workspace:Raycast(origin,dir,rp)
                                if res then return res.Instance,res.Position,res.Material end
                                return nil,origin+dir
                            end
                        end
                    end
                end
            end
            return oldNC(self,...)
        end)
        setreadonly(mt,true)
    end)
    if not ok then warn("[NEXUS] Hook no disponible: "..tostring(msg)) end
end

-- ══════════════════════════════════════════════════════════════
-- ROUND TOGGLES
-- ══════════════════════════════════════════════════════════════
trackConn(player.CharacterAdded:Connect(function(char)
    local hum=char:WaitForChild("Humanoid")
    hum.Died:Connect(function()
        task.delay(0.5,function()
            if Config.RoundToggles then
                Config.SilentAimEnabled=false; Config.EspEnabled=false
                saveConfig(); syncFAB()
            end
        end)
    end)
end))

-- ══════════════════════════════════════════════════════════════
-- RENDER STEP — optimizado: cache de colores y skip de skip
-- ══════════════════════════════════════════════════════════════
-- Acumular target para snapline sin llamar getBestTarget cada frame
local _snapTarget=nil
local _snapTimer=0

trackConn(RunService.RenderStepped:Connect(function(dt)
    local vpSize=camera.ViewportSize
    local center2D=Vector2.new(vpSize.X/2,vpSize.Y/2)
    local myChar=player.Character
    local myRoot=myChar and myChar:FindFirstChild("HumanoidRootPart")

    -- FOV Circle
    if fovCircle.Visible ~= (Config.FovEnabled and Config.SilentAimEnabled) then
        fovCircle.Visible = Config.FovEnabled and Config.SilentAimEnabled
    end
    if fovCircle.Visible then
        fovCircle.Position=center2D; fovCircle.Radius=Config.FovRadius
        fovCircle.Color=Color3.fromRGB(Config.FovColorR,Config.FovColorG,Config.FovColorB)
    end

    -- Snapline target: actualizar cada 0.05s
    _snapTimer=_snapTimer+dt
    if _snapTimer>=0.05 then
        _snapTimer=0
        _snapTarget=nil
        if Config.Snapline and Config.SilentAimEnabled then
            _inHook=true  -- evitar que getBestTarget dispare el hook
            pcall(function() _snapTarget=getBestTarget() end)
            _inHook=false
        end
    end

    -- Cache de colores (no recalcular si no cambiaron)
    local boxCol =Color3.fromRGB(Config.BoxColorR, Config.BoxColorG, Config.BoxColorB)
    local skelCol=Color3.fromRGB(Config.SkelColorR,Config.SkelColorG,Config.SkelColorB)
    local namCol =Color3.fromRGB(Config.NameColorR,Config.NameColorG,Config.NameColorB)
    local snapCol=Color3.fromRGB(Config.SnapColorR,Config.SnapColorG,Config.SnapColorB)

    local snapDrawn=false

    -- ESP loop
    for p,obj in pairs(espObjects) do
        local char=p.Character
        local active=Config.EspEnabled and char~=nil

        if not active then
            obj.box.Visible=false; obj.nameTag.Visible=false
            obj.distTag.Visible=false; obj.healthBar.Visible=false
            obj.healthBg.Visible=false
            for _,l in ipairs(obj.skeleton) do l.Visible=false end
            continue
        end

        local root=char:FindFirstChild("HumanoidRootPart")
        local hum=char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then
            obj.box.Visible=false; obj.nameTag.Visible=false
            obj.distTag.Visible=false; obj.healthBar.Visible=false
            obj.healthBg.Visible=false
            for _,l in ipairs(obj.skeleton) do l.Visible=false end
            continue
        end

        local screenPos,onScreen=camera:WorldToViewportPoint(root.Position)
        if not onScreen then
            obj.box.Visible=false; obj.nameTag.Visible=false
            obj.distTag.Visible=false; obj.healthBar.Visible=false
            obj.healthBg.Visible=false
            for _,l in ipairs(obj.skeleton) do l.Visible=false end
            continue
        end

        local dist3D=myRoot and math.floor((root.Position-myRoot.Position).Magnitude) or 0
        if dist3D>Config.EspMaxDist then
            obj.box.Visible=false; obj.nameTag.Visible=false
            obj.distTag.Visible=false; obj.healthBar.Visible=false
            obj.healthBg.Visible=false
            for _,l in ipairs(obj.skeleton) do l.Visible=false end
            continue
        end

        local sp=Vector2.new(screenPos.X,screenPos.Y)
        local head=char:FindFirstChild("Head")
        local foot=char:FindFirstChild("LeftFoot") or root
        local topSP,botSP
        if head and foot then
            local t=camera:WorldToViewportPoint(head.Position+Vector3.new(0,0.7,0))
            local b=camera:WorldToViewportPoint(foot.Position-Vector3.new(0,0.2,0))
            topSP=Vector2.new(t.X,t.Y); botSP=Vector2.new(b.X,b.Y)
        else
            topSP=sp-Vector2.new(0,55); botSP=sp+Vector2.new(0,55)
        end

        local boxH=math.abs(botSP.Y-topSP.Y)
        local boxW=boxH*0.46

        obj.box.Visible=Config.EspBox; obj.box.Color=boxCol
        if Config.EspBox then
            obj.box.Position=Vector2.new(sp.X-boxW/2,topSP.Y)
            obj.box.Size=Vector2.new(boxW,boxH)
        end

        obj.nameTag.Visible=Config.EspNames; obj.nameTag.Color=namCol
        if Config.EspNames then
            obj.nameTag.Text=p.DisplayName
            obj.nameTag.Position=Vector2.new(sp.X-boxW/2,topSP.Y-20)
        end

        obj.distTag.Visible=Config.EspDistance
        if Config.EspDistance then
            obj.distTag.Text=dist3D.."m"
            obj.distTag.Position=Vector2.new(sp.X-boxW/2,botSP.Y+3)
        end

        local hp=hum.Health/math.max(hum.MaxHealth,1)
        obj.healthBg.Visible=Config.EspHealthBar; obj.healthBar.Visible=Config.EspHealthBar
        if Config.EspHealthBar then
            local bx=sp.X-boxW/2-9
            obj.healthBg.Position=Vector2.new(bx,topSP.Y)
            obj.healthBg.Size=Vector2.new(5,boxH)
            obj.healthBg.Color=Color3.fromRGB(30,30,30)
            local barH=boxH*hp
            obj.healthBar.Position=Vector2.new(bx,topSP.Y+boxH-barH)
            obj.healthBar.Size=Vector2.new(5,barH)
            obj.healthBar.Color=Color3.fromRGB(math.floor(255*(1-hp)),math.floor(255*hp),0)
        end

        for si,pair in ipairs(SKELETON_PAIRS) do
            local pA=char:FindFirstChild(pair[1])
            local pB=char:FindFirstChild(pair[2])
            local line=obj.skeleton[si]; line.Color=skelCol
            if Config.EspSkeleton and pA and pB then
                local sA,onA=camera:WorldToViewportPoint(pA.Position)
                local sB,onB=camera:WorldToViewportPoint(pB.Position)
                line.Visible=onA and onB
                if onA and onB then
                    line.From=Vector2.new(sA.X,sA.Y); line.To=Vector2.new(sB.X,sB.Y)
                end
            else line.Visible=false end
        end

        -- Snapline
        if _snapTarget==p then
            snapLineDraw.Visible=true; snapLineDraw.From=center2D
            snapLineDraw.To=sp; snapLineDraw.Color=snapCol
            snapDrawn=true
        end
    end

    if not snapDrawn then snapLineDraw.Visible=false end
end))

-- ══════════════════════════════════════════════════════════════
-- DRAG PANEL
-- ══════════════════════════════════════════════════════════════
do
    local dragging,dragStart,startPos=false,nil,nil
    local dh=Instance.new("TextButton")
    dh.Size=UDim2.new(1,0,0,MINI_H); dh.Position=UDim2.fromOffset(0,0)
    dh.BackgroundTransparency=1; dh.Text=""; dh.ZIndex=5; dh.Parent=main
    trackConn(dh.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=inp.Position; startPos=main.Position end end))
    trackConn(UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then dragging=false end end))
    trackConn(UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement
        or inp.UserInputType==Enum.UserInputType.Touch) then
            local d=inp.Position-dragStart
            main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,
                startPos.Y.Scale,startPos.Y.Offset+d.Y) end end))
end

-- ══════════════════════════════════════════════════════════════
-- RESIZE con pinch (móvil) y handle esquina (PC)
-- ══════════════════════════════════════════════════════════════
do
    -- Handle de esquina (PC/tablet)
    local rh=Instance.new("TextButton")
    rh.Size=UDim2.fromOffset(26,26); rh.Position=UDim2.new(1,-26,1,-26)
    rh.BackgroundColor3=Color3.fromRGB(0,170,255); rh.BackgroundTransparency=0.35
    rh.Text="⤡"; rh.TextColor3=Color3.fromRGB(200,245,255); rh.TextSize=14
    rh.Font=Enum.Font.GothamBold; rh.BorderSizePixel=0; rh.ZIndex=10; rh.Parent=main
    corner(rh,5)

    local resizing,resizeStart,startSz=false,nil,nil
    trackConn(rh.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            if isMinimized then return end
            resizing=true; resizeStart=inp.Position; startSz=main.AbsoluteSize end end))
    trackConn(UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then resizing=false end end))
    trackConn(UserInputService.InputChanged:Connect(function(inp)
        if resizing and not isMinimized and (inp.UserInputType==Enum.UserInputType.MouseMovement
        or inp.UserInputType==Enum.UserInputType.Touch) then
            local d=inp.Position-resizeStart
            local nW=math.clamp(startSz.X+d.X,MIN_W,800)
            local nH=math.clamp(startSz.Y+d.Y,MIN_H,900)
            panelH=nH
            main.Size=UDim2.fromOffset(nW,nH)
            recalcLayout()
        end end))

    -- Pinch-to-resize (móvil: dos dedos)
    local pinchTouches={}
    local pinchStartDist=nil
    local pinchStartSz=nil

    trackConn(UserInputService.TouchStarted:Connect(function(inp)
        pinchTouches[inp]=inp.Position
        if table.getn and table.getn(pinchTouches)>=2 then end
    end))
    trackConn(UserInputService.TouchEnded:Connect(function(inp)
        pinchTouches[inp]=nil
        pinchStartDist=nil; pinchStartSz=nil
    end))
    trackConn(UserInputService.TouchMoved:Connect(function(inp)
        pinchTouches[inp]=inp.Position
        local pts={}
        for _,pos in pairs(pinchTouches) do table.insert(pts,pos) end
        if #pts>=2 then
            local dist=(pts[1]-pts[2]).Magnitude
            if not pinchStartDist then
                pinchStartDist=dist
                pinchStartSz=main.AbsoluteSize
            else
                local scale=dist/pinchStartDist
                local nW=math.clamp(pinchStartSz.X*scale,MIN_W,800)
                local nH=math.clamp(pinchStartSz.Y*scale,MIN_H,900)
                if not isMinimized then
                    panelH=nH; main.Size=UDim2.fromOffset(nW,nH); recalcLayout()
                end
            end
        end
    end))
end

-- ══════════════════════════════════════════════════════════════
-- FAB interactividad
-- ══════════════════════════════════════════════════════════════
do
    local fabDrag,fabDragStart,fabStartPos=false,nil,nil
    local fabMoved,holding,holdStarted=false,false,0
    local HOLD_TIME=0.45

    trackConn(floating.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            fabDrag=true; fabMoved=false
            fabDragStart=inp.Position; fabStartPos=floating.Position
            holding=true; holdStarted=os.clock()
            task.delay(HOLD_TIME,function()
                if holding and not fabMoved then
                    Config.SilentAimEnabled=not Config.SilentAimEnabled
                    saveConfig(); syncFAB()
                    TweenService:Create(floating,TweenInfo.new(0.1),{Size=UDim2.fromOffset(82,82)}):Play()
                    task.delay(0.12,function()
                        TweenService:Create(floating,TweenInfo.new(0.15),{Size=UDim2.fromOffset(72,72)}):Play()
                    end)
                end
            end)
        end end))
    trackConn(UserInputService.InputChanged:Connect(function(inp)
        if fabDrag and (inp.UserInputType==Enum.UserInputType.MouseMovement
        or inp.UserInputType==Enum.UserInputType.Touch) then
            local delta=inp.Position-fabDragStart
            if delta.Magnitude>5 then fabMoved=true; holding=false end
            if fabMoved then
                local sc=gui.AbsoluteSize
                local nx=math.clamp(fabStartPos.X.Offset+delta.X,4,sc.X-76)
                local ny=math.clamp(fabStartPos.Y.Offset+delta.Y,4,sc.Y-76)
                floating.Position=UDim2.new(0,nx,0,ny)
            end
        end end))
    trackConn(UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            if fabDrag then
                local held=os.clock()-holdStarted; holding=false
                if not fabMoved and held<HOLD_TIME then
                    main.Visible=not main.Visible
                end
                fabDrag=false; fabMoved=false
            end
        end end))
end

-- ══════════════════════════════════════════════════════════════
-- HOTKEYS PC
-- ══════════════════════════════════════════════════════════════
trackConn(UserInputService.InputBegan:Connect(function(inp,processed)
    if processed then return end
    if inp.KeyCode==Enum.KeyCode.RightShift then
        main.Visible=not main.Visible
    elseif inp.KeyCode==Enum.KeyCode.RightControl then
        Config.SilentAimEnabled=not Config.SilentAimEnabled
        saveConfig(); syncFAB()
    elseif inp.KeyCode==Enum.KeyCode.Delete then
        -- Tecla DELETE limpia todo y destruye la GUI
        cleanupAll(); cleanupDrawings(); gui:Destroy()
    end
end))

-- ══════════════════════════════════════════════════════════════
-- SCANLINE ANIM
-- ══════════════════════════════════════════════════════════════
local scanLine=Instance.new("Frame")
scanLine.Size=UDim2.new(1,-40,0,1); scanLine.Position=UDim2.fromOffset(20,headerH+10)
scanLine.BackgroundColor3=Color3.fromRGB(120,240,255); scanLine.BackgroundTransparency=0.2
scanLine.BorderSizePixel=0; scanLine.Parent=main

task.spawn(function()
    while gui.Parent do
        TweenService:Create(mainStroke,TweenInfo.new(0.8,Enum.EasingStyle.Sine),{Transparency=0.42}):Play()
        TweenService:Create(floatStroke,TweenInfo.new(0.8,Enum.EasingStyle.Sine),{Transparency=0.28}):Play()
        TweenService:Create(scanLine,TweenInfo.new(1.4,Enum.EasingStyle.Sine),{
            Position=UDim2.new(0,20,1,-10),BackgroundTransparency=0.7}):Play()
        task.wait(1.4)
        if not gui.Parent then break end
        scanLine.Position=UDim2.fromOffset(20,headerH+10); scanLine.BackgroundTransparency=0.2
        TweenService:Create(mainStroke,TweenInfo.new(0.8,Enum.EasingStyle.Sine),{Transparency=0.05}):Play()
        TweenService:Create(floatStroke,TweenInfo.new(0.8,Enum.EasingStyle.Sine),{Transparency=0.05}):Play()
        task.wait(0.8)
    end
end)

syncFAB()
print("[NEXUS v5.0] Cargado ✅ — EnanoTop1 (stx) | "..player.Name
    .." | Hook: "..(HAS_METAMETHODS and "OK" or "NO")
    .." | Drawing: "..(HAS_DRAWING and "OK" or "NO"))