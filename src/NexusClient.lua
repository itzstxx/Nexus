--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║           NEXUS  —  NexusClient  v5.0                        ║
    ║           Hecho por EnanoTop1 (stx)                          ║
    ╠══════════════════════════════════════════════════════════════╣
    ║  v5.0 - OPTIMIZADO MÓVIL:                                    ║
    ║  · Solo Aimbot / Visuals / Extras / Settings                 ║
    ║  · Item en Mano movido a Visuals                             ║
    ║  · Fly + InstaInteract en Extras                             ║
    ║  · Panel rectangular estilo golden (sin resize pinch)        ║
    ║  · RenderStepped unificado (un solo loop)                    ║
    ║  · Sin Shop, sin CajaFuerte, sin LootBuyer                   ║
    ╚══════════════════════════════════════════════════════════════╝
]]

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

local LOGO_IMAGE_ID = "rbxassetid://TU_ID_DEL_LOGO"
local CONFIG_FILE   = "nexus_config.json"

-- ══════════════════════════════════════════════════════════════
-- CONFIGURACIÓN
-- ══════════════════════════════════════════════════════════════
local DefaultConfig = {
    -- Aimbot
    SilentAimEnabled = false,
    HitChance        = 100,
    Manipulation     = false,
    VisibleCheck     = true,
    FovEnabled       = true,
    FovRadius        = 500,
    Snapline         = false,
    TargetPart       = "Random",
    FovColorR=255, FovColorG=255, FovColorB=255,
    SnapColorR=255, SnapColorG=255, SnapColorB=255,
    -- Visuals
    EspEnabled   = false,
    EspBox       = true,
    EspSkeleton  = true,
    EspHealthBar = true,
    EspDistance  = true,
    EspNames     = true,
    EspMaxDist   = 500,
    ItemInHand   = true,
    BoxColorR=0,  BoxColorG=220, BoxColorB=255,
    SkelColorR=0, SkelColorG=220,SkelColorB=255,
    NameColorR=255,NameColorG=255,NameColorB=255,
    -- Extras
    FlyEnabled       = false,
    FlySpeed         = 50,
    RageMode         = false,
    InstaInteract     = false,
    InstaInteractAuto = false,
    InstaInteractFilter = "",
    -- Settings
    Whitelist = {},
}

local Config = {}

local function deepCopy(t)
    local c = {}
    for k,v in pairs(t) do
        c[k] = type(v)=="table" and deepCopy(v) or v
    end
    return c
end

local function loadConfig()
    if pcall(function()
        local raw = readfile(CONFIG_FILE)
        local d   = HttpService:JSONDecode(raw)
        for k,v in pairs(DefaultConfig) do
            Config[k] = d[k] ~= nil and d[k] or (type(v)=="table" and deepCopy(v) or v)
        end
    end) then
        print("[NEXUS] Config cargada.")
    else
        Config = deepCopy(DefaultConfig)
    end
end

local function saveConfig()
    pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(Config)) end)
end

loadConfig()

-- ══════════════════════════════════════════════════════════════
-- WHITELIST
-- ══════════════════════════════════════════════════════════════
local function isWhitelisted(p)
    for _, n in ipairs(Config.Whitelist) do
        if n:lower() == p.Name:lower() then return true end
    end
    return false
end
local function addWhitelist(name)
    if name=="" then return false end
    for _, n in ipairs(Config.Whitelist) do
        if n:lower()==name:lower() then return false end
    end
    table.insert(Config.Whitelist, name); saveConfig(); return true
end
local function removeWhitelist(name)
    for i,n in ipairs(Config.Whitelist) do
        if n:lower()==name:lower() then
            table.remove(Config.Whitelist,i); saveConfig(); return true
        end
    end
    return false
end

-- ══════════════════════════════════════════════════════════════
-- GUI BASE
-- ══════════════════════════════════════════════════════════════
local old = playerGui:FindFirstChild("NexusSystemUI")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name           = "NexusSystemUI"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder   = 99
gui.Parent         = playerGui

-- ── helpers UI ──────────────────────────────────────────────
local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 4)
    c.Parent = p
end
local function stroke(p, col, thick)
    local s = Instance.new("UIStroke")
    s.Color = col or Color3.fromRGB(0,190,255)
    s.Thickness = thick or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p
    return s
end

-- ══════════════════════════════════════════════════════════════
-- PANEL PRINCIPAL  — rectangular, sin bordes redondeados grandes
-- ══════════════════════════════════════════════════════════════
local panelW, panelH = 310, 470

local main = Instance.new("Frame")
main.Name               = "NexusPanel"
main.Size               = UDim2.fromOffset(panelW, panelH)
main.Position           = UDim2.new(0, 28, 0.5, -panelH/2)
main.BackgroundColor3   = Color3.fromRGB(10, 10, 10)
main.BackgroundTransparency = 0
main.BorderSizePixel    = 0
main.ClipsDescendants   = true
main.Parent             = gui
-- Sin corner para look rectangular (golden-style)

local mainStroke = stroke(main, Color3.fromRGB(218,165,32), 2)  -- dorado

-- Gradiente oscuro
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,    Color3.fromRGB(20, 15, 0)),
    ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(10, 10, 10)),
    ColorSequenceKeypoint.new(1,    Color3.fromRGB(25, 18, 0)),
})
grad.Rotation = 45
grad.Parent   = main

-- ── Header ──────────────────────────────────────────────────
local headerH = 44
local header  = Instance.new("Frame")
header.Size                 = UDim2.new(1,0,0,headerH)
header.BackgroundColor3     = Color3.fromRGB(15,12,0)
header.BackgroundTransparency = 0
header.BorderSizePixel      = 0
header.Parent               = main

local headerBot = Instance.new("Frame")
headerBot.Size              = UDim2.new(1,0,0,1)
headerBot.Position          = UDim2.new(0,0,1,-1)
headerBot.BackgroundColor3  = Color3.fromRGB(218,165,32)
headerBot.BorderSizePixel   = 0
headerBot.Parent            = header

local titleLbl = Instance.new("TextLabel")
titleLbl.Size               = UDim2.new(1,-100,1,0)
titleLbl.Position           = UDim2.fromOffset(12,0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text               = "⚡ NEXUS v5.0"
titleLbl.TextColor3         = Color3.fromRGB(255,215,0)
titleLbl.Font               = Enum.Font.GothamBlack
titleLbl.TextSize            = 17
titleLbl.TextXAlignment     = Enum.TextXAlignment.Left
titleLbl.Parent             = header

local subtitleLbl = Instance.new("TextLabel")
subtitleLbl.Size               = UDim2.new(1,-100,0,14)
subtitleLbl.Position           = UDim2.new(0,12,1,-16)
subtitleLbl.BackgroundTransparency = 1
subtitleLbl.Text               = "EnanoTop1 (stx)  ·  "..player.Name
subtitleLbl.TextColor3         = Color3.fromRGB(180,140,40)
subtitleLbl.Font               = Enum.Font.GothamMedium
subtitleLbl.TextSize            = 10
subtitleLbl.TextXAlignment     = Enum.TextXAlignment.Left
subtitleLbl.Parent             = header

-- Botón cerrar
local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.fromOffset(32,32)
closeBtn.Position         = UDim2.new(1,-38,0.5,-16)
closeBtn.BackgroundColor3 = Color3.fromRGB(80,20,0)
closeBtn.BorderSizePixel  = 0
closeBtn.Text             = "✕"
closeBtn.TextColor3       = Color3.fromRGB(255,100,80)
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.TextSize          = 14
closeBtn.AutoButtonColor  = false
closeBtn.Parent           = header
closeBtn.MouseButton1Click:Connect(function() main.Visible = false end)

-- ── Tab Bar ──────────────────────────────────────────────────
local tabBarH  = 30
local tabY     = headerH + 2
local contentY = tabY + tabBarH + 4
local contentH = panelH - contentY - 8

local tabBar = Instance.new("Frame")
tabBar.Size             = UDim2.new(1,0,0,tabBarH)
tabBar.Position         = UDim2.fromOffset(0, tabY)
tabBar.BackgroundColor3 = Color3.fromRGB(8,6,0)
tabBar.BorderSizePixel  = 0
tabBar.Parent           = main

local tabSep = Instance.new("Frame")
tabSep.Size             = UDim2.new(1,0,0,1)
tabSep.Position         = UDim2.new(0,0,1,-1)
tabSep.BackgroundColor3 = Color3.fromRGB(218,165,32)
tabSep.BorderSizePixel  = 0
tabSep.Parent           = tabBar

local tabNames = {"Aimbot","Visuals","Extras","Settings"}
local tabBtns  = {}
local tabPages = {}

local function makeTabPage()
    local page = Instance.new("ScrollingFrame")
    page.Size              = UDim2.new(1,-2,0,contentH)
    page.Position          = UDim2.fromOffset(1, contentY)
    page.BackgroundTransparency = 1
    page.BorderSizePixel   = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Color3.fromRGB(218,165,32)
    page.CanvasSize        = UDim2.new(0,0,0,0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible           = false
    page.Parent            = main
    local pad = Instance.new("UIPadding")
    pad.PaddingTop=UDim.new(0,6); pad.PaddingLeft=UDim.new(0,8)
    pad.PaddingRight=UDim.new(0,8); pad.PaddingBottom=UDim.new(0,8)
    pad.Parent = page
    local lay = Instance.new("UIListLayout")
    lay.SortOrder=Enum.SortOrder.LayoutOrder; lay.Padding=UDim.new(0,5)
    lay.Parent = page
    return page
end

for i, name in ipairs(tabNames) do
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(1/#tabNames,-2,1,-4)
    btn.Position         = UDim2.new((i-1)/#tabNames,1,0,2)
    btn.BackgroundColor3 = (i==1) and Color3.fromRGB(40,28,0) or Color3.fromRGB(8,6,0)
    btn.BorderSizePixel  = 0
    btn.Text             = name
    btn.TextColor3       = (i==1) and Color3.fromRGB(255,215,0) or Color3.fromRGB(140,110,40)
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize          = 11
    btn.AutoButtonColor  = false
    btn.Parent           = tabBar
    tabBtns[i] = btn

    local page = makeTabPage()
    tabPages[i] = page

    btn.MouseButton1Click:Connect(function()
        for j,p in ipairs(tabPages) do
            p.Visible = (j==i)
            tabBtns[j].BackgroundColor3 = (j==i) and Color3.fromRGB(40,28,0) or Color3.fromRGB(8,6,0)
            tabBtns[j].TextColor3 = (j==i) and Color3.fromRGB(255,215,0) or Color3.fromRGB(140,110,40)
        end
    end)
end
tabPages[1].Visible = true

-- ══════════════════════════════════════════════════════════════
-- UI HELPERS
-- ══════════════════════════════════════════════════════════════
local function secLabel(page, text)
    local f = Instance.new("Frame")
    f.Size=UDim2.new(1,0,0,18); f.BackgroundTransparency=1; f.Parent=page
    local l = Instance.new("TextLabel")
    l.Size=UDim2.new(1,0,1,0); l.BackgroundTransparency=1
    l.Text="▸ "..text; l.TextColor3=Color3.fromRGB(218,165,32)
    l.Font=Enum.Font.GothamBlack; l.TextSize=10; l.TextXAlignment=Enum.TextXAlignment.Left
    l.Parent=f
    return f
end

local function makeToggle(page, text, key, cb)
    local row = Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,32); row.BackgroundColor3=Color3.fromRGB(16,12,0)
    row.BorderSizePixel=0; row.Parent=page
    stroke(row, Color3.fromRGB(60,45,0), 1)

    local lbl = Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-46,1,0); lbl.Position=UDim2.fromOffset(8,0)
    lbl.BackgroundTransparency=1; lbl.Text=text
    lbl.TextColor3=Color3.fromRGB(220,200,120); lbl.Font=Enum.Font.GothamMedium
    lbl.TextSize=11; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row

    local tog = Instance.new("TextButton")
    tog.Size=UDim2.fromOffset(38,20); tog.Position=UDim2.new(1,-42,0.5,-10)
    tog.BorderSizePixel=0; tog.AutoButtonColor=false
    tog.Text=""; tog.Parent=row

    local function refresh()
        local on = Config[key]
        tog.BackgroundColor3 = on and Color3.fromRGB(218,165,32) or Color3.fromRGB(35,25,0)
        local dot = tog:FindFirstChild("dot")
        if not dot then
            dot = Instance.new("Frame"); dot.Name="dot"
            dot.Size=UDim2.fromOffset(16,16); dot.BorderSizePixel=0
            corner(dot,8); dot.Parent=tog
        end
        dot.BackgroundColor3 = on and Color3.fromRGB(255,255,255) or Color3.fromRGB(80,60,0)
        dot.Position = on and UDim2.fromOffset(20,2) or UDim2.fromOffset(2,2)
    end
    corner(tog, 10); refresh()

    tog.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        refresh(); saveConfig()
        if cb then cb(Config[key]) end
    end)
    return row, refresh
end

local function makeSlider(page, text, key, mn, mx, cb)
    local row = Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,44); row.BackgroundColor3=Color3.fromRGB(16,12,0)
    row.BorderSizePixel=0; row.Parent=page
    stroke(row, Color3.fromRGB(60,45,0),1)

    local lbl = Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-50,0,18); lbl.Position=UDim2.fromOffset(8,4)
    lbl.BackgroundTransparency=1
    lbl.Text=text..": "..tostring(Config[key])
    lbl.TextColor3=Color3.fromRGB(220,200,120); lbl.Font=Enum.Font.GothamMedium
    lbl.TextSize=11; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row

    local track = Instance.new("Frame")
    track.Size=UDim2.new(1,-16,0,6); track.Position=UDim2.fromOffset(8,28)
    track.BackgroundColor3=Color3.fromRGB(35,25,0); track.BorderSizePixel=0
    track.Parent=row; corner(track,3)
    stroke(track, Color3.fromRGB(60,45,0),1)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3=Color3.fromRGB(218,165,32)
    fill.BorderSizePixel=0; fill.Parent=track; corner(fill,3)

    local function setVal(v)
        v = math.clamp(math.floor(v), mn, mx)
        Config[key] = v
        lbl.Text = text..": "..tostring(v)
        fill.Size = UDim2.new((v-mn)/(mx-mn),0,1,0)
        if cb then cb(v) end
    end
    setVal(Config[key])

    local sliding = false
    local function slide(inp)
        local abs = track.AbsolutePosition
        local sz  = track.AbsoluteSize
        local t = math.clamp((inp.Position.X - abs.X) / sz.X, 0, 1)
        setVal(mn + t*(mx-mn))
    end
    track.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            sliding=true; slide(inp)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if sliding and (inp.UserInputType==Enum.UserInputType.MouseMovement
        or inp.UserInputType==Enum.UserInputType.Touch) then
            slide(inp)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            if sliding then sliding=false; saveConfig() end
        end
    end)
    return row
end

local function makeColorRow(page, text, rk, gk, bk)
    local row = Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,32); row.BackgroundColor3=Color3.fromRGB(16,12,0)
    row.BorderSizePixel=0; row.Parent=page
    stroke(row, Color3.fromRGB(60,45,0),1)

    local lbl = Instance.new("TextLabel")
    lbl.Size=UDim2.new(0.55,0,1,0); lbl.Position=UDim2.fromOffset(8,0)
    lbl.BackgroundTransparency=1; lbl.Text=text
    lbl.TextColor3=Color3.fromRGB(220,200,120); lbl.Font=Enum.Font.GothamMedium
    lbl.TextSize=10; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row

    local preview = Instance.new("Frame")
    preview.Size=UDim2.fromOffset(18,18); preview.Position=UDim2.new(1,-24,0.5,-9)
    preview.BorderSizePixel=0; preview.Parent=row; corner(preview,3)
    stroke(preview, Color3.fromRGB(218,165,32),1)

    local function refreshPrev()
        preview.BackgroundColor3 = Color3.fromRGB(Config[rk], Config[gk], Config[bk])
    end
    refreshPrev()

    -- cycling preset colors
    local presets = {
        {255,255,255},{255,80,80},{80,255,80},{80,160,255},
        {255,215,0},{255,140,0},{200,80,255},{0,255,220},
    }
    local ci = 1
    preview.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            ci = ci%#presets+1
            Config[rk]=presets[ci][1]; Config[gk]=presets[ci][2]; Config[bk]=presets[ci][3]
            refreshPrev(); saveConfig()
        end
    end)
    return row
end

local function makeDropdown(page, text, key, options)
    local open = false
    local container = Instance.new("Frame")
    container.Size=UDim2.new(1,0,0,32); container.BackgroundTransparency=1
    container.BorderSizePixel=0; container.Parent=page
    local lay2=Instance.new("UIListLayout"); lay2.SortOrder=Enum.SortOrder.LayoutOrder
    lay2.Padding=UDim.new(0,2); lay2.Parent=container

    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,32); row.BackgroundColor3=Color3.fromRGB(16,12,0)
    row.BorderSizePixel=0; row.Parent=container; stroke(row,Color3.fromRGB(60,45,0),1)

    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-46,1,0); lbl.Position=UDim2.fromOffset(8,0)
    lbl.BackgroundTransparency=1; lbl.Text=text..": "..Config[key]
    lbl.TextColor3=Color3.fromRGB(220,200,120); lbl.Font=Enum.Font.GothamMedium
    lbl.TextSize=11; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row

    local arr=Instance.new("TextLabel")
    arr.Size=UDim2.fromOffset(24,20); arr.Position=UDim2.new(1,-28,0.5,-10)
    arr.BackgroundTransparency=1; arr.Text="▾"; arr.TextColor3=Color3.fromRGB(218,165,32)
    arr.Font=Enum.Font.GothamBold; arr.TextSize=14; arr.Parent=row

    local dropFrame=Instance.new("Frame")
    dropFrame.Size=UDim2.new(1,0,0,#options*28)
    dropFrame.BackgroundColor3=Color3.fromRGB(12,9,0)
    dropFrame.BorderSizePixel=0; dropFrame.Visible=false
    dropFrame.ZIndex=10; dropFrame.Parent=container
    stroke(dropFrame,Color3.fromRGB(218,165,32),1)

    for idx,opt in ipairs(options) do
        local ob=Instance.new("TextButton")
        ob.Size=UDim2.new(1,0,0,26); ob.Position=UDim2.fromOffset(0,(idx-1)*28)
        ob.BackgroundColor3=Color3.fromRGB(20,14,0); ob.BorderSizePixel=0
        ob.Text=opt; ob.Font=Enum.Font.GothamMedium; ob.TextSize=11
        ob.TextColor3=(Config[key]==opt) and Color3.fromRGB(255,215,0) or Color3.fromRGB(180,150,60)
        ob.AutoButtonColor=false; ob.ZIndex=11; ob.Parent=dropFrame
        ob.MouseButton1Click:Connect(function()
            Config[key]=opt; lbl.Text=text..": "..opt
            for _,b in ipairs(dropFrame:GetChildren()) do
                if b:IsA("TextButton") then
                    b.TextColor3=(b.Text==opt) and Color3.fromRGB(255,215,0) or Color3.fromRGB(180,150,60)
                end
            end
            dropFrame.Visible=false; open=false
            container.Size=UDim2.new(1,0,0,32)
            saveConfig()
        end)
    end

    local hitbox=Instance.new("TextButton")
    hitbox.Size=UDim2.new(1,0,1,0); hitbox.BackgroundTransparency=1
    hitbox.Text=""; hitbox.ZIndex=2; hitbox.Parent=row
    hitbox.MouseButton1Click:Connect(function()
        open=not open; dropFrame.Visible=open
        container.Size=open and UDim2.new(1,0,0,32+#options*28) or UDim2.new(1,0,0,32)
        arr.Text=open and "▴" or "▾"
    end)
    return container
end

local function makeTextInput(page, placeholder, key)
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,32); row.BackgroundColor3=Color3.fromRGB(16,12,0)
    row.BorderSizePixel=0; row.Parent=page; stroke(row,Color3.fromRGB(60,45,0),1)

    local box=Instance.new("TextBox")
    box.Size=UDim2.new(1,-12,1,-8); box.Position=UDim2.fromOffset(6,4)
    box.BackgroundColor3=Color3.fromRGB(8,6,0); box.BorderSizePixel=0
    box.Text=Config[key] or ""; box.PlaceholderText=placeholder
    box.PlaceholderColor3=Color3.fromRGB(80,65,20)
    box.TextColor3=Color3.fromRGB(220,200,120); box.Font=Enum.Font.GothamMedium
    box.TextSize=11; box.ClearTextOnFocus=false; box.Parent=row; corner(box,3)
    box.FocusLost:Connect(function()
        Config[key]=box.Text; saveConfig()
    end)
    return row
end

-- ══════════════════════════════════════════════════════════════
-- TAB 1: AIMBOT
-- ══════════════════════════════════════════════════════════════
local pageAim = tabPages[1]

secLabel(pageAim, "Silent Aim")
makeToggle(pageAim, "Silent Aim",   "SilentAimEnabled")
makeToggle(pageAim, "VisibleCheck", "VisibleCheck")
makeToggle(pageAim, "Manipulation", "Manipulation")
makeSlider(pageAim, "HitChance %",  "HitChance", 1, 100)

secLabel(pageAim, "FOV")
makeToggle(pageAim, "FOV Circle",   "FovEnabled")
makeSlider(pageAim, "Fov Radius",   "FovRadius", 10, 800)
makeColorRow(pageAim, "FOV Color",  "FovColorR","FovColorG","FovColorB")

secLabel(pageAim, "Snapline")
makeToggle(pageAim, "Snapline",     "Snapline")
makeColorRow(pageAim,"Snap Color",  "SnapColorR","SnapColorG","SnapColorB")

secLabel(pageAim, "Target")
makeDropdown(pageAim,"Target Part", "TargetPart",{"Head","UpperTorso","LowerTorso","Random"})

-- ══════════════════════════════════════════════════════════════
-- TAB 2: VISUALS
-- ══════════════════════════════════════════════════════════════
local pageVis = tabPages[2]

secLabel(pageVis, "ESP")
makeToggle(pageVis,"ESP Enabled",   "EspEnabled")
makeToggle(pageVis,"Box",           "EspBox")
makeColorRow(pageVis,"Box Color",   "BoxColorR","BoxColorG","BoxColorB")
makeToggle(pageVis,"Skeleton",      "EspSkeleton")
makeColorRow(pageVis,"Skel Color",  "SkelColorR","SkelColorG","SkelColorB")
makeToggle(pageVis,"Health Bar",    "EspHealthBar")
makeToggle(pageVis,"Distancia",     "EspDistance")
makeToggle(pageVis,"Nombres",       "EspNames")
makeColorRow(pageVis,"Name Color",  "NameColorR","NameColorG","NameColorB")
makeSlider(pageVis, "Dist Máx",     "EspMaxDist", 50, 1000)

secLabel(pageVis, "Item en la Mano")
makeToggle(pageVis,"Ver Item Mano", "ItemInHand")

-- ══════════════════════════════════════════════════════════════
-- TAB 3: EXTRAS
-- ══════════════════════════════════════════════════════════════
local pageExt = tabPages[3]

secLabel(pageExt, "Rage Mode")
makeToggle(pageExt,"🔴 Rage Mode","RageMode", function(on)
    if on then
        Config.SilentAimEnabled=true; Config.HitChance=100
        Config.FovRadius=999; Config.VisibleCheck=false
        Config.Manipulation=true; Config.TargetPart="Head"
        saveConfig()
    end
end)

secLabel(pageExt, "Fly")
makeToggle(pageExt,"Fly Enabled","FlyEnabled")
makeSlider(pageExt,"Velocidad Fly","FlySpeed",10,200)

secLabel(pageExt, "Insta Interact")
makeToggle(pageExt,"Insta Interact (tap)","InstaInteract")
makeToggle(pageExt,"Auto Interact (prox)","InstaInteractAuto")
makeTextInput(pageExt,"Filtro: ej. Interact,Open","InstaInteractFilter")

do
    local infoLbl=Instance.new("TextLabel")
    infoLbl.Size=UDim2.new(1,0,0,28); infoLbl.BackgroundTransparency=1
    infoLbl.Text="Filtro vacío = activa cualquier prompt\nSepara palabras por coma"
    infoLbl.TextColor3=Color3.fromRGB(120,90,30); infoLbl.Font=Enum.Font.GothamMedium
    infoLbl.TextSize=9; infoLbl.TextWrapped=true
    infoLbl.TextXAlignment=Enum.TextXAlignment.Left; infoLbl.Parent=pageExt
end

-- ══════════════════════════════════════════════════════════════
-- TAB 4: SETTINGS
-- ══════════════════════════════════════════════════════════════
local pageSet = tabPages[4]

secLabel(pageSet, "Whitelist")
do
    local inputRow=Instance.new("Frame")
    inputRow.Size=UDim2.new(1,0,0,32); inputRow.BackgroundColor3=Color3.fromRGB(16,12,0)
    inputRow.BorderSizePixel=0; inputRow.Parent=pageSet; stroke(inputRow,Color3.fromRGB(60,45,0),1)

    local nameBox=Instance.new("TextBox")
    nameBox.Size=UDim2.new(1,-74,1,-8); nameBox.Position=UDim2.fromOffset(5,4)
    nameBox.BackgroundColor3=Color3.fromRGB(8,6,0); nameBox.BorderSizePixel=0
    nameBox.Text=""; nameBox.PlaceholderText="Nombre de usuario..."
    nameBox.PlaceholderColor3=Color3.fromRGB(80,65,20)
    nameBox.TextColor3=Color3.fromRGB(220,200,120); nameBox.Font=Enum.Font.GothamMedium
    nameBox.TextSize=11; nameBox.ClearTextOnFocus=false
    nameBox.Parent=inputRow; corner(nameBox,3)

    local addBtn=Instance.new("TextButton")
    addBtn.Size=UDim2.fromOffset(60,24); addBtn.Position=UDim2.new(1,-64,0.5,-12)
    addBtn.BackgroundColor3=Color3.fromRGB(30,22,0); addBtn.BorderSizePixel=0
    addBtn.Text="+ Add"; addBtn.TextColor3=Color3.fromRGB(255,215,0)
    addBtn.Font=Enum.Font.GothamBold; addBtn.TextSize=11; addBtn.AutoButtonColor=false
    addBtn.Parent=inputRow; corner(addBtn,3); stroke(addBtn,Color3.fromRGB(218,165,32),1)

    local wlFrame=Instance.new("Frame")
    wlFrame.Size=UDim2.new(1,0,0,0); wlFrame.BackgroundTransparency=1
    wlFrame.AutomaticSize=Enum.AutomaticSize.Y; wlFrame.Parent=pageSet
    local wlLay=Instance.new("UIListLayout")
    wlLay.SortOrder=Enum.SortOrder.LayoutOrder; wlLay.Padding=UDim.new(0,3); wlLay.Parent=wlFrame

    local function rebuildWL()
        for _,c in ipairs(wlFrame:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        for _,name in ipairs(Config.Whitelist) do
            local e=Instance.new("Frame")
            e.Size=UDim2.new(1,0,0,26); e.BackgroundColor3=Color3.fromRGB(18,14,0)
            e.BorderSizePixel=0; e.Parent=wlFrame; stroke(e,Color3.fromRGB(60,45,0),1)
            local nl=Instance.new("TextLabel")
            nl.Size=UDim2.new(1,-36,1,0); nl.Position=UDim2.fromOffset(6,0)
            nl.BackgroundTransparency=1; nl.Text="✓ "..name
            nl.TextColor3=Color3.fromRGB(218,165,32); nl.Font=Enum.Font.GothamMedium
            nl.TextSize=10; nl.TextXAlignment=Enum.TextXAlignment.Left; nl.Parent=e
            local db=Instance.new("TextButton")
            db.Size=UDim2.fromOffset(26,18); db.Position=UDim2.new(1,-30,0.5,-9)
            db.BackgroundColor3=Color3.fromRGB(50,10,0); db.BorderSizePixel=0
            db.Text="✕"; db.TextColor3=Color3.fromRGB(255,80,80)
            db.Font=Enum.Font.GothamBold; db.TextSize=10; db.AutoButtonColor=false; db.Parent=e
            corner(db,3)
            db.MouseButton1Click:Connect(function() removeWhitelist(name); rebuildWL() end)
        end
    end
    rebuildWL()

    addBtn.MouseButton1Click:Connect(function()
        local n=nameBox.Text:match("^%s*(.-)%s*$")
        if addWhitelist(n) then
            nameBox.Text=""; rebuildWL()
            addBtn.Text="✅"; task.delay(1,function() addBtn.Text="+ Add" end)
        else
            addBtn.Text="Ya existe"; task.delay(1.2,function() addBtn.Text="+ Add" end)
        end
    end)
end

secLabel(pageSet,"Config")
do
    local saveBtn=Instance.new("TextButton")
    saveBtn.Size=UDim2.new(1,0,0,32); saveBtn.BackgroundColor3=Color3.fromRGB(30,22,0)
    saveBtn.BorderSizePixel=0; saveBtn.Text="💾  Guardar Config"
    saveBtn.TextColor3=Color3.fromRGB(255,215,0); saveBtn.Font=Enum.Font.GothamBold
    saveBtn.TextSize=12; saveBtn.AutoButtonColor=false; saveBtn.Parent=pageSet
    stroke(saveBtn,Color3.fromRGB(218,165,32),1)
    saveBtn.MouseButton1Click:Connect(function()
        saveConfig(); saveBtn.Text="✅  Guardado!"
        task.delay(1.5,function() saveBtn.Text="💾  Guardar Config" end)
    end)
end
do
    local rstBtn=Instance.new("TextButton")
    rstBtn.Size=UDim2.new(1,0,0,32); rstBtn.BackgroundColor3=Color3.fromRGB(40,8,0)
    rstBtn.BorderSizePixel=0; rstBtn.Text="🔄  Resetear Config"
    rstBtn.TextColor3=Color3.fromRGB(255,100,80); rstBtn.Font=Enum.Font.GothamBold
    rstBtn.TextSize=12; rstBtn.AutoButtonColor=false; rstBtn.Parent=pageSet
    stroke(rstBtn,Color3.fromRGB(180,40,0),1)
    rstBtn.MouseButton1Click:Connect(function()
        Config=deepCopy(DefaultConfig); saveConfig()
        rstBtn.Text="✅  Reseteado — recarga"
        task.delay(2,function() rstBtn.Text="🔄  Resetear Config" end)
    end)
end

-- ══════════════════════════════════════════════════════════════
-- DRAG PANEL
-- ══════════════════════════════════════════════════════════════
do
    local drag,dragStart,startPos=false,nil,nil
    local dh=Instance.new("TextButton")
    dh.Size=UDim2.new(1,0,0,headerH); dh.BackgroundTransparency=1
    dh.Text=""; dh.ZIndex=5; dh.Parent=main

    dh.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            drag=true; dragStart=inp.Position; startPos=main.Position
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then drag=false end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if drag and (inp.UserInputType==Enum.UserInputType.MouseMovement
        or inp.UserInputType==Enum.UserInputType.Touch) then
            local d=inp.Position-dragStart
            main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,
                                    startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
-- FAB (botón flotante)
-- ══════════════════════════════════════════════════════════════
local fab=Instance.new("TextButton")
fab.Name="NexusFAB"
fab.Size=UDim2.fromOffset(52,52); fab.Position=UDim2.new(1,-62,0.5,-26)
fab.BackgroundColor3=Color3.fromRGB(10,8,0); fab.BorderSizePixel=0
fab.AutoButtonColor=false; fab.Text="⚡"; fab.TextColor3=Color3.fromRGB(255,215,0)
fab.Font=Enum.Font.GothamBlack; fab.TextSize=20; fab.ZIndex=20; fab.Parent=gui
stroke(fab, Color3.fromRGB(218,165,32),2)

do
    local fabDrag,fabDragStart,fabStartPos=false,nil,nil
    local fabMoved,holding,holdStart=false,false,0
    fab.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            fabDrag=true; fabMoved=false
            fabDragStart=inp.Position; fabStartPos=fab.Position
            holding=true; holdStart=os.clock()
            task.delay(0.4,function()
                if holding and not fabMoved then
                    Config.SilentAimEnabled=not Config.SilentAimEnabled
                    saveConfig()
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if fabDrag and (inp.UserInputType==Enum.UserInputType.MouseMovement
        or inp.UserInputType==Enum.UserInputType.Touch) then
            local delta=inp.Position-fabDragStart
            if delta.Magnitude>5 then fabMoved=true; holding=false end
            if fabMoved then
                local sc=gui.AbsoluteSize
                local nx=math.clamp(fabStartPos.X.Offset+delta.X,4,sc.X-56)
                local ny=math.clamp(fabStartPos.Y.Offset+delta.Y,4,sc.Y-56)
                fab.Position=UDim2.new(0,nx,0,ny)
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            if fabDrag then
                holding=false
                if not fabMoved and (os.clock()-holdStart)<0.4 then
                    main.Visible=not main.Visible
                end
                fabDrag=false; fabMoved=false
            end
        end
    end)
end

-- Hotkey PC
UserInputService.InputBegan:Connect(function(inp,proc)
    if proc then return end
    if inp.KeyCode==Enum.KeyCode.RightShift then main.Visible=not main.Visible end
    if inp.KeyCode==Enum.KeyCode.RightControl then
        Config.SilentAimEnabled=not Config.SilentAimEnabled; saveConfig()
    end
end)

-- ══════════════════════════════════════════════════════════════
-- FLY — lógica
-- ══════════════════════════════════════════════════════════════
local flyActive=false

local function stopFly()
    flyActive=false
    local char=player.Character; if not char then return end
    local hum=char:FindFirstChildOfClass("Humanoid")
    local root=char:FindFirstChild("HumanoidRootPart")
    if hum then hum.PlatformStand=false end
    if root then
        local bp=root:FindFirstChild("NexusFlyBP")
        local bg=root:FindFirstChild("NexusFlyBG")
        if bp then bp:Destroy() end; if bg then bg:Destroy() end
    end
end

local function startFly()
    flyActive=true
    local char=player.Character; if not char then return end
    local hum=char:FindFirstChildOfClass("Humanoid")
    local root=char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end
    hum.PlatformStand=true
    if not root:FindFirstChild("NexusFlyBP") then
        local bp=Instance.new("BodyPosition")
        bp.Name="NexusFlyBP"; bp.MaxForce=Vector3.new(1e5,1e5,1e5)
        bp.Position=root.Position; bp.D=500; bp.P=10000; bp.Parent=root
    end
    if not root:FindFirstChild("NexusFlyBG") then
        local bg=Instance.new("BodyGyro")
        bg.Name="NexusFlyBG"; bg.MaxTorque=Vector3.new(1e5,1e5,1e5)
        bg.D=100; bg.P=10000; bg.CFrame=root.CFrame; bg.Parent=root
    end
end

player.CharacterAdded:Connect(function()
    flyActive=false; task.wait(0.5)
    if Config.FlyEnabled then startFly() end
end)

-- ══════════════════════════════════════════════════════════════
-- INSTA INTERACT
-- ══════════════════════════════════════════════════════════════
local lastTriggered={}

local function promptOk(prompt)
    local filter=Config.InstaInteractFilter or ""
    if filter=="" then return true end
    local at=(prompt.ActionText or ""):lower()
    local ot=(prompt.ObjectText or ""):lower()
    local nm=(prompt.Name or ""):lower()
    for word in filter:gmatch("[^,]+") do
        word=word:match("^%s*(.-)%s*$"):lower()
        if word~="" then
            if at:find(word,1,true) or ot:find(word,1,true) or nm:find(word,1,true) then
                return true
            end
        end
    end
    return false
end

local function triggerPrompt(prompt)
    if not promptOk(prompt) then return end
    local now=os.clock()
    if lastTriggered[prompt] and (now-lastTriggered[prompt])<1.5 then return end
    lastTriggered[prompt]=now
    pcall(function() fireclickdetector(prompt) end)
    pcall(function()
        prompt:InputHoldBegin()
        task.delay(0.1,function() pcall(function() prompt:InputHoldEnd() end) end)
    end)
end

-- Auto interact (corutina ligera, 0.4s interval)
task.spawn(function()
    while gui.Parent do
        task.wait(0.4)
        if Config.InstaInteractAuto then
            local myChar=player.Character
            local myRoot=myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myRoot then
                for _,v in ipairs(Workspace:GetDescendants()) do
                    if v:IsA("ProximityPrompt") and v.Enabled then
                        local pp=v.Parent
                        local pos=(pp and pp:IsA("BasePart")) and pp.Position
                                or (pp and pp:FindFirstChild("PrimaryPart") and pp.PrimaryPart.Position)
                        if pos and (pos-myRoot.Position).Magnitude<v.MaxActivationDistance then
                            triggerPrompt(v)
                        end
                    end
                end
            end
        end
    end
end)

-- Tap manual
UserInputService.InputBegan:Connect(function(inp,proc)
    if proc then return end
    if inp.UserInputType~=Enum.UserInputType.MouseButton1
    and inp.UserInputType~=Enum.UserInputType.Touch then return end
    if not Config.InstaInteract then return end
    local myChar=player.Character
    local myRoot=myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local best,bestD=nil,math.huge
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Enabled then
            local pp=v.Parent
            local pos=(pp and pp:IsA("BasePart")) and pp.Position
                    or (pp and pp:FindFirstChild("PrimaryPart")) and pp.PrimaryPart.Position
            if pos then
                local d=(pos-myRoot.Position).Magnitude
                if d<v.MaxActivationDistance and d<bestD then bestD=d; best=v end
            end
        end
    end
    if best then triggerPrompt(best) end
end)

-- ══════════════════════════════════════════════════════════════
-- DRAWINGS — ESP + FOV + Snap + ItemInHand
-- ══════════════════════════════════════════════════════════════
local function getItemInHand(char)
    if not char then return nil end
    for _,v in ipairs(char:GetChildren()) do
        if v:IsA("Tool") then return v.Name end
    end
    return nil
end

local fovCircle=Drawing.new("Circle")
fovCircle.Visible=false; fovCircle.Thickness=1.5; fovCircle.Filled=false

local snapLineDraw=Drawing.new("Line")
snapLineDraw.Visible=false; snapLineDraw.Thickness=1.5

local SKELETON_PAIRS={
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
}

local espObjects={}
local itemDrawings={}

local function newLine(col)
    local l=Drawing.new("Line"); l.Color=col or Color3.fromRGB(0,255,200)
    l.Thickness=1; l.Visible=false; return l
end
local function newText(sz,col)
    local t=Drawing.new("Text"); t.Size=sz or 12
    t.Color=col or Color3.fromRGB(255,255,255); t.Outline=true; t.Visible=false; return t
end
local function newRect(col,fill)
    local r=Drawing.new("Square"); r.Color=col or Color3.fromRGB(0,255,200)
    r.Filled=fill or false; r.Thickness=1.5; r.Visible=false; return r
end

local function createEsp(p)
    if p==player then return end
    local obj={
        box=newRect(Color3.fromRGB(0,220,255)),
        nameTag=newText(13),
        distTag=newText(11,Color3.fromRGB(160,230,255)),
        healthBg=newRect(Color3.fromRGB(30,30,30),true),
        healthBar=newRect(Color3.fromRGB(80,255,80),true),
        skeleton={},
    }
    for _=1,#SKELETON_PAIRS do table.insert(obj.skeleton,newLine()) end
    espObjects[p]=obj

    local it=Drawing.new("Text"); it.Size=12
    it.Color=Color3.fromRGB(255,215,0); it.Outline=true; it.Visible=false
    itemDrawings[p]=it
end

local function removeEsp(p)
    local obj=espObjects[p]; if not obj then return end
    obj.box:Remove(); obj.nameTag:Remove(); obj.distTag:Remove()
    obj.healthBg:Remove(); obj.healthBar:Remove()
    for _,l in ipairs(obj.skeleton) do l:Remove() end
    espObjects[p]=nil
    if itemDrawings[p] then itemDrawings[p]:Remove(); itemDrawings[p]=nil end
end

for _,p in ipairs(Players:GetPlayers()) do if p~=player then createEsp(p) end end
Players.PlayerAdded:Connect(createEsp)
Players.PlayerRemoving:Connect(removeEsp)

-- ══════════════════════════════════════════════════════════════
-- SILENT AIM — target cache + hook
-- ══════════════════════════════════════════════════════════════
local cachedTargetPos=nil

local isFiring=false
local fireDebounce=0

local function onFireStart(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1 then
        isFiring=true; fireDebounce=os.clock()
    elseif inp.UserInputType==Enum.UserInputType.Touch then
        local vp=camera.ViewportSize
        if inp.Position.X>vp.X*0.35 then
            isFiring=true; fireDebounce=os.clock()
        end
    end
end
local function onFireEnd(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1
    or inp.UserInputType==Enum.UserInputType.Touch then
        task.delay(0.08,function() isFiring=false end)
    end
end
UserInputService.InputBegan:Connect(onFireStart)
UserInputService.InputEnded:Connect(onFireEnd)

local function watchTool(tool)
    if not tool then return end
    tool.Activated:Connect(function()
        isFiring=true; fireDebounce=os.clock()
        task.delay(0.15,function() isFiring=false end)
    end)
end
local function watchChar(char)
    if not char then return end
    for _,t in ipairs(char:GetChildren()) do if t:IsA("Tool") then watchTool(t) end end
    char.ChildAdded:Connect(function(c) if c:IsA("Tool") then watchTool(c) end end)
end
watchChar(player.Character); player.CharacterAdded:Connect(watchChar)

local wallbreakParams=RaycastParams.new()
wallbreakParams.FilterType=Enum.RaycastFilterType.Include
wallbreakParams.FilterDescendantsInstances={}

local function updateWallbreak()
    local chars={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=player and p.Character then table.insert(chars,p.Character) end
    end
    wallbreakParams.FilterDescendantsInstances=chars
end

local function getBestTarget()
    local center=Vector2.new(camera.ViewportSize.X/2,camera.ViewportSize.Y/2)
    local bestD=math.huge; local bestP=nil; local bestPos=nil
    for _,p in ipairs(Players:GetPlayers()) do
        if p==player then continue end
        if isWhitelisted(p) then continue end
        local char=p.Character; if not char then continue end
        local hum=char:FindFirstChildOfClass("Humanoid")
        local root=char:FindFirstChild("HumanoidRootPart")
        if not hum or hum.Health<=0 or not root then continue end
        local sp,onScreen=camera:WorldToViewportPoint(root.Position)
        if not onScreen then continue end
        local d2=(Vector2.new(sp.X,sp.Y)-center).Magnitude
        if d2>Config.FovRadius then continue end
        if Config.VisibleCheck then
            local localChar=player.Character
            if localChar then
                local ok,obs=pcall(function()
                    return camera:GetPartsObscuringTarget({root.Position},{localChar,char})
                end)
                if ok and #obs>0 then continue end
            end
        end
        if d2<bestD then
            bestD=d2; bestP=p
            local pn=Config.TargetPart
            if pn=="Random" then
                local r=math.random(100)
                pn=r<=30 and "Head" or (r<=80 and "UpperTorso" or "LowerTorso")
            end
            local hp=char:FindFirstChild(pn) or root
            bestPos=hp.Position
        end
    end
    return bestP, bestPos
end

-- Hook Silent Aim
pcall(function()
    local oldNC
    oldNC=hookmetamethod(game,"__namecall",newcclosure(function(...)
        local method=getnamecallmethod()
        if not Config.SilentAimEnabled then return oldNC(...) end
        if checkcaller()               then return oldNC(...) end
        if not cachedTargetPos         then return oldNC(...) end
        if math.random(100)>Config.HitChance then return oldNC(...) end
        local args={...}
        if args[1]~=Workspace then return oldNC(...) end
        if method=="Raycast" then
            if typeof(args[2])~="Vector3" or typeof(args[3])~="Vector3" then return oldNC(...) end
            args[3]=(cachedTargetPos-args[2]).Unit*1000
            if Config.Manipulation then args[4]=wallbreakParams end
            return oldNC(table.unpack(args))
        elseif method=="FindPartOnRayWithIgnoreList" or method=="FindPartOnRay" then
            if typeof(args[2])~="Ray" then return oldNC(...) end
            local o=args[2].Origin
            args[2]=Ray.new(o,(cachedTargetPos-o).Unit*1000)
            if Config.Manipulation and method=="FindPartOnRayWithIgnoreList" then args[3]={} end
            return oldNC(table.unpack(args))
        end
        return oldNC(...)
    end))
end)

-- ══════════════════════════════════════════════════════════════
-- RENDER STEP UNIFICADO — un solo loop para todo
-- ══════════════════════════════════════════════════════════════
local frameCount=0

RunService.RenderStepped:Connect(function()
    frameCount=frameCount+1

    -- Fly
    if Config.FlyEnabled~=flyActive then
        if Config.FlyEnabled then startFly() else stopFly() end
    end
    if Config.FlyEnabled and flyActive then
        local char=player.Character
        local root=char and char:FindFirstChild("HumanoidRootPart")
        local bp=root and root:FindFirstChild("NexusFlyBP")
        local bg=root and root:FindFirstChild("NexusFlyBG")
        if bp and bg then
            local speed=Config.FlySpeed
            local camCF=camera.CFrame
            local mv=Vector3.new(0,0,0)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv=mv+camCF.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv=mv-camCF.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv=mv-camCF.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv=mv+camCF.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space)
            or UserInputService:IsKeyDown(Enum.KeyCode.Q) then mv=mv+Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            or UserInputService:IsKeyDown(Enum.KeyCode.E) then mv=mv-Vector3.new(0,1,0) end
            local hum2=char:FindFirstChildOfClass("Humanoid")
            if hum2 and hum2.MoveDirection.Magnitude>0.1 then
                local md=hum2.MoveDirection
                local wf=Vector3.new(md.X,0,md.Z)
                if wf.Magnitude>0.01 then mv=mv+wf.Unit end
            end
            if mv.Magnitude>0 then bp.Position=bp.Position+mv.Unit*speed*0.016
            else bp.Position=root.Position end
            bg.CFrame=CFrame.new(root.Position,root.Position+camCF.LookVector)
        end
    end

    -- Cada 2 frames: actualizar target cache y wallbreak (ahorra CPU)
    if frameCount%2==0 then
        updateWallbreak()
        if Config.SilentAimEnabled then
            local _,pos=getBestTarget()
            cachedTargetPos=pos
        else
            cachedTargetPos=nil
        end
    end

    local vpSize=camera.ViewportSize
    local center2D=Vector2.new(vpSize.X/2,vpSize.Y/2)
    local myChar=player.Character
    local myRoot=myChar and myChar:FindFirstChild("HumanoidRootPart")

    -- FOV Circle
    fovCircle.Visible=Config.FovEnabled and Config.SilentAimEnabled
    if fovCircle.Visible then
        fovCircle.Position=center2D
        fovCircle.Radius=Config.FovRadius
        fovCircle.Color=Color3.fromRGB(Config.FovColorR,Config.FovColorG,Config.FovColorB)
    end

    local boxCol=Color3.fromRGB(Config.BoxColorR,Config.BoxColorG,Config.BoxColorB)
    local skelCol=Color3.fromRGB(Config.SkelColorR,Config.SkelColorG,Config.SkelColorB)
    local namCol=Color3.fromRGB(Config.NameColorR,Config.NameColorG,Config.NameColorB)
    local snapCol=Color3.fromRGB(Config.SnapColorR,Config.SnapColorG,Config.SnapColorB)

    local snapTargetP=nil
    if Config.Snapline and Config.SilentAimEnabled then
        snapTargetP=getBestTarget()
    end

    -- ESP
    for p,obj in pairs(espObjects) do
        local active=Config.EspEnabled and p.Character~=nil
        local char=p.Character

        local function allOff()
            obj.box.Visible=false; obj.nameTag.Visible=false
            obj.distTag.Visible=false; obj.healthBar.Visible=false; obj.healthBg.Visible=false
            for _,l in ipairs(obj.skeleton) do l.Visible=false end
            if itemDrawings[p] then itemDrawings[p].Visible=false end
        end

        if not active then allOff(); continue end

        local root=char:FindFirstChild("HumanoidRootPart")
        local hum=char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then allOff(); continue end

        local screenPos,onScreen=camera:WorldToViewportPoint(root.Position)
        if not onScreen then allOff(); continue end

        local dist3D=myRoot and math.floor((root.Position-myRoot.Position).Magnitude) or 0
        if dist3D>Config.EspMaxDist then allOff(); continue end

        local sp=Vector2.new(screenPos.X,screenPos.Y)
        local head=char:FindFirstChild("Head")
        local foot=char:FindFirstChild("LeftFoot") or root
        local topSP,botSP
        if head and foot then
            local t=camera:WorldToViewportPoint(head.Position+Vector3.new(0,0.6,0))
            local b=camera:WorldToViewportPoint(foot.Position-Vector3.new(0,0.2,0))
            topSP=Vector2.new(t.X,t.Y); botSP=Vector2.new(b.X,b.Y)
        else topSP=sp-Vector2.new(0,50); botSP=sp+Vector2.new(0,50) end

        local boxH=math.abs(botSP.Y-topSP.Y)
        local boxW=boxH*0.45

        obj.box.Visible=Config.EspBox; obj.box.Color=boxCol
        if Config.EspBox then obj.box.Position=Vector2.new(sp.X-boxW/2,topSP.Y); obj.box.Size=Vector2.new(boxW,boxH) end

        obj.nameTag.Visible=Config.EspNames; obj.nameTag.Color=namCol
        if Config.EspNames then obj.nameTag.Text=p.DisplayName; obj.nameTag.Position=Vector2.new(sp.X-boxW/2,topSP.Y-16) end

        obj.distTag.Visible=Config.EspDistance
        if Config.EspDistance then obj.distTag.Text=dist3D.."m"; obj.distTag.Position=Vector2.new(sp.X-boxW/2,botSP.Y+2) end

        local hp=hum.Health/math.max(hum.MaxHealth,1)
        obj.healthBg.Visible=Config.EspHealthBar; obj.healthBar.Visible=Config.EspHealthBar
        if Config.EspHealthBar then
            local bx=sp.X-boxW/2-7
            obj.healthBg.Position=Vector2.new(bx,topSP.Y); obj.healthBg.Size=Vector2.new(4,boxH); obj.healthBg.Color=Color3.fromRGB(30,30,30)
            local barH=boxH*hp
            obj.healthBar.Position=Vector2.new(bx,topSP.Y+boxH-barH); obj.healthBar.Size=Vector2.new(4,barH)
            obj.healthBar.Color=Color3.fromRGB(math.floor(255*(1-hp)),math.floor(255*hp),0)
        end

        for si,pair in ipairs(SKELETON_PAIRS) do
            local pA=char:FindFirstChild(pair[1]); local pB=char:FindFirstChild(pair[2])
            local line=obj.skeleton[si]; line.Color=skelCol
            if Config.EspSkeleton and pA and pB then
                local sA,onA=camera:WorldToViewportPoint(pA.Position)
                local sB,onB=camera:WorldToViewportPoint(pB.Position)
                line.Visible=onA and onB
                if onA and onB then line.From=Vector2.new(sA.X,sA.Y); line.To=Vector2.new(sB.X,sB.Y) end
            else line.Visible=false end
        end

        -- Item en la mano
        local itDraw=itemDrawings[p]
        if itDraw then
            local iname=Config.ItemInHand and getItemInHand(char) or nil
            if iname then
                itDraw.Text="[🔫 "..iname.."]"; itDraw.Position=Vector2.new(sp.X,topSP.Y-28); itDraw.Visible=true
            else itDraw.Visible=false end
        end

        -- Snapline
        if snapTargetP==p then
            snapLineDraw.Visible=true; snapLineDraw.From=center2D
            snapLineDraw.To=sp; snapLineDraw.Color=snapCol
        end
    end

    if not (Config.Snapline and Config.SilentAimEnabled and snapTargetP) then
        snapLineDraw.Visible=false
    end
end)

print("[NEXUS v5.0] Cargado — EnanoTop1 (stx) | "..player.Name)