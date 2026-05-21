--[[
    NEXUS Client UI  —  v2.0
    ─────────────────────────────────────────────────────────
    FIXES v2.0:
      · Drag del panel completamente reescrito (móvil + PC).
      · Resize handle en esquina inferior-derecha.
      · Toggle ON/OFF funciona y refleja estado visualmente.
      · Perfil del usuario local (nombre + nivel de cuenta).
      · Panel arranca bien orientado en móvil.
      · Botón flotante: tap corto = show/hide, hold = toggle módulo.
]]

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Config ────────────────────────────────────────────────
local LOGO_IMAGE_ID = "rbxassetid://TU_ID_DEL_LOGO"

local Settings = {
    ModuleEnabled = false,
    Prediction    = true,
    FOV           = 12,
    Smooth        = 65,
    MaxRange      = 500,
}

-- ── Limpiar GUI anterior ──────────────────────────────────
local oldGui = playerGui:FindFirstChild("NexusSystemUI")
if oldGui then oldGui:Destroy() end

-- ── ScreenGui ─────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name            = "NexusSystemUI"
gui.ResetOnSpawn    = false
gui.IgnoreGuiInset  = true
gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder    = 99
gui.Parent          = playerGui

local changedEvent = Instance.new("BindableEvent")
changedEvent.Name   = "NexusChanged"
changedEvent.Parent = gui

local function emitChanged()
    gui:SetAttribute("ModuleEnabled", Settings.ModuleEnabled)
    gui:SetAttribute("Prediction",    Settings.Prediction)
    gui:SetAttribute("FOV",           Settings.FOV)
    gui:SetAttribute("Smooth",        Settings.Smooth)
    gui:SetAttribute("MaxRange",      Settings.MaxRange)
    changedEvent:Fire(table.clone(Settings))
end

-- ════════════════════════════════════════════════════════════
-- UTILIDADES
-- ════════════════════════════════════════════════════════════
local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = p ; return c
end

local function mkStroke(p, color, thick, transp)
    local s = Instance.new("UIStroke")
    s.Color        = color
    s.Thickness    = thick  or 1
    s.Transparency = transp or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p ; return s
end

-- ════════════════════════════════════════════════════════════
-- PANEL PRINCIPAL
-- ════════════════════════════════════════════════════════════
local MIN_W, MIN_H = 320, 420
local panelW, panelH = 404, 526

local main = Instance.new("Frame")
main.Name              = "NexusPanel"
main.Size              = UDim2.fromOffset(panelW, panelH)
main.Position          = UDim2.new(0, 30, 0.5, -panelH/2)
main.BackgroundColor3  = Color3.fromRGB(4, 12, 24)
main.BackgroundTransparency = 0.06
main.BorderSizePixel   = 0
main.ClipsDescendants  = true
main.Parent            = gui
corner(main, 8)

local mainStroke = mkStroke(main, Color3.fromRGB(0, 190, 255), 2, 0.05)

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,    Color3.fromRGB(0,  34,  70)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(5,  13,  26)),
    ColorSequenceKeypoint.new(1,    Color3.fromRGB(0,  78, 126)),
})
gradient.Rotation = 35
gradient.Parent   = main

-- Línea superior
local topLine = Instance.new("Frame")
topLine.Name              = "TopGlow"
topLine.Size              = UDim2.new(1, -44, 0, 2)
topLine.Position          = UDim2.fromOffset(22, 15)
topLine.BackgroundColor3  = Color3.fromRGB(0, 210, 255)
topLine.BorderSizePixel   = 0
topLine.Parent            = main

-- Scan line animada
local scanLine = Instance.new("Frame")
scanLine.Name              = "ScanLine"
scanLine.Size              = UDim2.new(1, -40, 0, 1)
scanLine.Position          = UDim2.fromOffset(20, 92)
scanLine.BackgroundColor3  = Color3.fromRGB(120, 240, 255)
scanLine.BackgroundTransparency = 0.2
scanLine.BorderSizePixel   = 0
scanLine.Parent            = main

-- ── Header: Logo + título ─────────────────────────────────
local logo = Instance.new("ImageLabel")
logo.Name                  = "Logo"
logo.Size                  = UDim2.fromOffset(72, 72)
logo.Position              = UDim2.fromOffset(20, 18)
logo.BackgroundTransparency = 1
logo.Image                 = LOGO_IMAGE_ID
logo.ImageColor3           = Color3.fromRGB(120, 232, 255)
logo.Parent                = main

local title = Instance.new("TextLabel")
title.Name              = "Title"
title.Size              = UDim2.new(1, -110, 0, 36)
title.Position          = UDim2.fromOffset(104, 20)
title.BackgroundTransparency = 1
title.Text              = "NEXUS"
title.TextColor3        = Color3.fromRGB(205, 250, 255)
title.Font              = Enum.Font.GothamBlack
title.TextSize          = 30
title.TextXAlignment    = Enum.TextXAlignment.Left
title.Parent            = main

local subtitle = Instance.new("TextLabel")
subtitle.Name           = "Subtitle"
subtitle.Size           = UDim2.new(1, -110, 0, 20)
subtitle.Position       = UDim2.fromOffset(106, 58)
subtitle.BackgroundTransparency = 1
subtitle.Text           = "SYSTEM INTERFACE"
subtitle.TextColor3     = Color3.fromRGB(70, 210, 255)
subtitle.Font           = Enum.Font.GothamMedium
subtitle.TextSize       = 12
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent         = main

-- ── STATUS box ───────────────────────────────────────────
local statusBox = Instance.new("Frame")
statusBox.Name              = "StatusBox"
statusBox.Size              = UDim2.new(1, -40, 0, 38)
statusBox.Position          = UDim2.fromOffset(20, 102)
statusBox.BackgroundColor3  = Color3.fromRGB(5, 20, 34)
statusBox.BackgroundTransparency = 0.18
statusBox.BorderSizePixel   = 0
statusBox.Parent            = main
corner(statusBox, 4)
mkStroke(statusBox, Color3.fromRGB(120, 230, 255), 1, 0.25)

local statusTitle = Instance.new("TextLabel")
statusTitle.Size             = UDim2.fromScale(1, 1)
statusTitle.BackgroundTransparency = 1
statusTitle.Text             = "STATUS"
statusTitle.TextColor3       = Color3.fromRGB(225, 252, 255)
statusTitle.Font             = Enum.Font.GothamBlack
statusTitle.TextSize         = 18
statusTitle.Parent           = statusBox

-- ── Info: nivel + estado + PERFIL ────────────────────────
local infoRow = Instance.new("Frame")
infoRow.Name              = "InfoRow"
infoRow.Size              = UDim2.new(1, -40, 0, 80)
infoRow.Position          = UDim2.fromOffset(20, 150)
infoRow.BackgroundTransparency = 1
infoRow.Parent            = main

-- Nivel
local levelNum = Instance.new("TextLabel")
levelNum.Size             = UDim2.fromOffset(100, 50)
levelNum.Position         = UDim2.fromOffset(0, 0)
levelNum.BackgroundTransparency = 1
levelNum.Text             = "18"
levelNum.TextColor3       = Color3.fromRGB(165, 245, 255)
levelNum.Font             = Enum.Font.GothamBlack
levelNum.TextSize         = 44
levelNum.Parent           = infoRow

local levelLbl = Instance.new("TextLabel")
levelLbl.Size             = UDim2.fromOffset(100, 18)
levelLbl.Position         = UDim2.fromOffset(4, 52)
levelLbl.BackgroundTransparency = 1
levelLbl.Text             = "LEVEL"
levelLbl.TextColor3       = Color3.fromRGB(190, 235, 255)
levelLbl.Font             = Enum.Font.GothamMedium
levelLbl.TextSize         = 12
levelLbl.Parent           = infoRow

-- Estado del módulo
local moduleStatus = Instance.new("TextLabel")
moduleStatus.Name         = "ModuleStatus"
moduleStatus.Size         = UDim2.new(1, -110, 0, 24)
moduleStatus.Position     = UDim2.fromOffset(108, 4)
moduleStatus.BackgroundTransparency = 1
moduleStatus.Text         = "MODULE: OFFLINE"
moduleStatus.TextColor3   = Color3.fromRGB(210, 244, 255)
moduleStatus.Font         = Enum.Font.GothamBold
moduleStatus.TextSize     = 14
moduleStatus.TextXAlignment = Enum.TextXAlignment.Left
moduleStatus.Parent       = infoRow

-- Perfil del usuario
local profileText = Instance.new("TextLabel")
profileText.Name          = "ProfileText"
profileText.Size          = UDim2.new(1, -110, 0, 20)
profileText.Position      = UDim2.fromOffset(108, 30)
profileText.BackgroundTransparency = 1
profileText.Text          = "TITLE: NEXUS USER"
profileText.TextColor3    = Color3.fromRGB(145, 220, 255)
profileText.Font          = Enum.Font.GothamMedium
profileText.TextSize      = 12
profileText.TextXAlignment = Enum.TextXAlignment.Left
profileText.Parent        = infoRow

-- ── PERFIL REAL del jugador ───────────────────────────────
local profileCard = Instance.new("Frame")
profileCard.Name              = "ProfileCard"
profileCard.Size              = UDim2.new(1, -40, 0, 42)
profileCard.Position          = UDim2.fromOffset(20, 240)
profileCard.BackgroundColor3  = Color3.fromRGB(3, 18, 36)
profileCard.BackgroundTransparency = 0.15
profileCard.BorderSizePixel   = 0
profileCard.Parent            = main
corner(profileCard, 5)
mkStroke(profileCard, Color3.fromRGB(0, 180, 255), 1, 0.3)

-- Thumbnail del avatar
local avatarImg = Instance.new("ImageLabel")
avatarImg.Size              = UDim2.fromOffset(34, 34)
avatarImg.Position          = UDim2.fromOffset(6, 4)
avatarImg.BackgroundColor3  = Color3.fromRGB(5, 20, 38)
avatarImg.BackgroundTransparency = 0.3
avatarImg.BorderSizePixel   = 0
avatarImg.Image             = string.format(
    "https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=150&height=150&format=png",
    player.UserId)
avatarImg.Parent            = profileCard
corner(avatarImg, 4)

local userNameLbl = Instance.new("TextLabel")
userNameLbl.Size              = UDim2.new(1, -50, 0, 18)
userNameLbl.Position          = UDim2.fromOffset(46, 5)
userNameLbl.BackgroundTransparency = 1
userNameLbl.Text              = player.DisplayName
userNameLbl.TextColor3        = Color3.fromRGB(210, 248, 255)
userNameLbl.Font              = Enum.Font.GothamBold
userNameLbl.TextSize          = 13
userNameLbl.TextXAlignment    = Enum.TextXAlignment.Left
userNameLbl.TextTruncate      = Enum.TextTruncate.AtEnd
userNameLbl.Parent            = profileCard

local userIdLbl = Instance.new("TextLabel")
userIdLbl.Size                = UDim2.new(1, -50, 0, 14)
userIdLbl.Position            = UDim2.fromOffset(46, 24)
userIdLbl.BackgroundTransparency = 1
userIdLbl.Text                = "@" .. player.Name .. "  ·  ID " .. player.UserId
userIdLbl.TextColor3          = Color3.fromRGB(100, 190, 230)
userIdLbl.Font                = Enum.Font.GothamMedium
userIdLbl.TextSize            = 10
userIdLbl.TextXAlignment      = Enum.TextXAlignment.Left
userIdLbl.TextTruncate        = Enum.TextTruncate.AtEnd
userIdLbl.Parent              = profileCard

-- ════════════════════════════════════════════════════════════
-- CONTROLES (botones + sliders)
-- ════════════════════════════════════════════════════════════
local controls = Instance.new("Frame")
controls.Name              = "Controls"
controls.Size              = UDim2.new(1, -40, 0, 210)
controls.Position          = UDim2.fromOffset(20, 294)
controls.BackgroundColor3  = Color3.fromRGB(3, 18, 32)
controls.BackgroundTransparency = 0.18
controls.BorderSizePixel   = 0
controls.ClipsDescendants  = true
controls.Parent            = main
corner(controls, 5)
mkStroke(controls, Color3.fromRGB(0, 170, 255), 1, 0.28)

-- ── Botón genérico ────────────────────────────────────────
local function makeButton(text, y, callback)
    local btn = Instance.new("TextButton")
    btn.Size              = UDim2.new(1, -24, 0, 38)
    btn.Position          = UDim2.fromOffset(12, y)
    btn.BackgroundColor3  = Color3.fromRGB(4, 28, 48)
    btn.BorderSizePixel   = 0
    btn.Text              = text
    btn.TextColor3        = Color3.fromRGB(198, 246, 255)
    btn.Font              = Enum.Font.GothamBold
    btn.TextSize          = 13
    btn.AutoButtonColor   = false
    btn.Parent            = controls
    corner(btn, 4)
    mkStroke(btn, Color3.fromRGB(0, 175, 255), 1, 0.38)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.14), {
            BackgroundColor3 = Color3.fromRGB(0, 56, 86)
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.14), {
            BackgroundColor3 = Color3.fromRGB(4, 28, 48)
        }):Play()
    end)
    -- PC click
    btn.MouseButton1Click:Connect(callback)
    -- Móvil tap
    btn.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then
            callback()
        end
    end)
    return btn
end

-- ── Slider genérico ───────────────────────────────────────
local function makeSlider(labelText, y, minV, maxV, defV, onChange)
    local box = Instance.new("Frame")
    box.Size              = UDim2.new(1, -24, 0, 50)
    box.Position          = UDim2.fromOffset(12, y)
    box.BackgroundTransparency = 1
    box.Parent            = controls

    local lbl = Instance.new("TextLabel")
    lbl.Size              = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Text              = labelText .. ": " .. tostring(defV)
    lbl.TextColor3        = Color3.fromRGB(185, 240, 255)
    lbl.Font              = Enum.Font.GothamMedium
    lbl.TextSize          = 12
    lbl.TextXAlignment    = Enum.TextXAlignment.Left
    lbl.Parent            = box

    local bar = Instance.new("Frame")
    bar.Size              = UDim2.new(1, 0, 0, 8)
    bar.Position          = UDim2.fromOffset(0, 32)
    bar.BackgroundColor3  = Color3.fromRGB(12, 45, 65)
    bar.BorderSizePixel   = 0
    bar.Parent            = box
    corner(bar, 8)

    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new((defV - minV)/(maxV - minV), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    fill.BorderSizePixel  = 0
    fill.Parent           = bar
    corner(fill, 8)

    local dragging = false

    local function update(inputX)
        local alpha = math.clamp(
            (inputX - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local value = math.floor(minV + (maxV - minV) * alpha)
        fill.Size  = UDim2.new(alpha, 0, 1, 0)
        lbl.Text   = labelText .. ": " .. tostring(value)
        onChange(value)
        emitChanged()
    end

    bar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(inp.Position.X)
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
end

-- Declaración anticipada (necesaria para syncVisuals)
local moduleButton, predictionButton, activeDot, floatStroke

-- ── syncVisuals ───────────────────────────────────────────
local function syncVisuals()
    if moduleButton then
        moduleButton.Text = Settings.ModuleEnabled
            and "NEXUS MODULE: ON" or "NEXUS MODULE: OFF"
        moduleButton.BackgroundColor3 = Settings.ModuleEnabled
            and Color3.fromRGB(0, 48, 32) or Color3.fromRGB(4, 28, 48)
    end
    if predictionButton then
        predictionButton.Text = Settings.Prediction
            and "PREDICTION: ON" or "PREDICTION: OFF"
    end

    moduleStatus.Text = Settings.ModuleEnabled
        and "MODULE: ONLINE" or "MODULE: OFFLINE"
    moduleStatus.TextColor3 = Settings.ModuleEnabled
        and Color3.fromRGB(110, 255, 180)
        or  Color3.fromRGB(210, 244, 255)

    if activeDot then
        activeDot.BackgroundColor3 = Settings.ModuleEnabled
            and Color3.fromRGB(85, 255, 165)
            or  Color3.fromRGB(90, 110, 120)
    end
    if floatStroke then
        floatStroke.Color = Settings.ModuleEnabled
            and Color3.fromRGB(85, 255, 165)
            or  Color3.fromRGB(0, 200, 255)
    end
    emitChanged()
end

-- Crear botones
moduleButton = makeButton("NEXUS MODULE: OFF", 10, function()
    Settings.ModuleEnabled = not Settings.ModuleEnabled
    syncVisuals()
end)

predictionButton = makeButton("PREDICTION: ON", 54, function()
    Settings.Prediction = not Settings.Prediction
    syncVisuals()
end)

makeSlider("FOV",    104, 2,  35,  Settings.FOV,    function(v) Settings.FOV    = v end)
makeSlider("SMOOTH", 154, 10, 100, Settings.Smooth, function(v) Settings.Smooth = v end)

-- ════════════════════════════════════════════════════════════
-- DRAG DEL PANEL  (reescrito para móvil + PC)
-- ════════════════════════════════════════════════════════════
do
    local dragging   = false
    local dragStart  = nil
    local startPos   = nil

    -- Área de drag = toda la zona por encima de los controles
    local dragHandle = Instance.new("TextButton")
    dragHandle.Size              = UDim2.new(1, 0, 0, 90)
    dragHandle.Position          = UDim2.fromOffset(0, 0)
    dragHandle.BackgroundTransparency = 1
    dragHandle.Text              = ""
    dragHandle.ZIndex            = 5
    dragHandle.Parent            = main

    dragHandle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = inp.Position
            startPos  = main.Position
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
            local d = inp.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- ════════════════════════════════════════════════════════════
-- RESIZE HANDLE  (esquina inferior-derecha)
-- ════════════════════════════════════════════════════════════
do
    local resizeHandle = Instance.new("TextButton")
    resizeHandle.Name              = "ResizeHandle"
    resizeHandle.Size              = UDim2.fromOffset(22, 22)
    resizeHandle.Position          = UDim2.new(1, -22, 1, -22)
    resizeHandle.BackgroundColor3  = Color3.fromRGB(0, 170, 255)
    resizeHandle.BackgroundTransparency = 0.35
    resizeHandle.Text              = "⤡"
    resizeHandle.TextColor3        = Color3.fromRGB(200, 245, 255)
    resizeHandle.TextSize          = 13
    resizeHandle.Font              = Enum.Font.GothamBold
    resizeHandle.BorderSizePixel   = 0
    resizeHandle.ZIndex            = 10
    resizeHandle.Parent            = main
    corner(resizeHandle, 4)

    local resizing    = false
    local resizeStart = nil
    local startSize   = nil

    resizeHandle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            resizing    = true
            resizeStart = inp.Position
            startSize   = main.AbsoluteSize
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            resizing = false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if resizing and (
            inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch) then
            local d  = inp.Position - resizeStart
            local nW = math.clamp(startSize.X + d.X, MIN_W, 700)
            local nH = math.clamp(startSize.Y + d.Y, MIN_H, 800)
            main.Size = UDim2.fromOffset(nW, nH)
            -- Adaptar controles al nuevo ancho
            controls.Size = UDim2.new(1, -40, 0, nH - 320)
        end
    end)
end

-- ════════════════════════════════════════════════════════════
-- BOTÓN FLOTANTE  (FAB)
-- ════════════════════════════════════════════════════════════
local floating = Instance.new("ImageButton")
floating.Name              = "NexusFloatingToggle"
floating.Size              = UDim2.fromOffset(68, 68)
floating.Position          = UDim2.new(1, -88, 0.5, -34)
floating.BackgroundColor3  = Color3.fromRGB(3, 18, 32)
floating.BorderSizePixel   = 0
floating.AutoButtonColor   = false
floating.Image             = ""
floating.ZIndex            = 20
floating.Parent            = gui
corner(floating, 68)

floatStroke = mkStroke(floating, Color3.fromRGB(0, 200, 255), 2, 0.05)

local floatLogo = Instance.new("ImageLabel")
floatLogo.Size              = UDim2.fromOffset(44, 44)
floatLogo.Position          = UDim2.fromScale(0.5, 0.5)
floatLogo.AnchorPoint       = Vector2.new(0.5, 0.5)
floatLogo.BackgroundTransparency = 1
floatLogo.Image             = LOGO_IMAGE_ID
floatLogo.ImageColor3       = Color3.fromRGB(125, 235, 255)
floatLogo.Parent            = floating

activeDot = Instance.new("Frame")
activeDot.Size              = UDim2.fromOffset(12, 12)
activeDot.Position          = UDim2.new(1, -14, 0, 4)
activeDot.BackgroundColor3  = Color3.fromRGB(90, 110, 120)
activeDot.BorderSizePixel   = 0
activeDot.ZIndex            = 21
activeDot.Parent            = floating
corner(activeDot, 12)

-- ── Drag del FAB (tap corto = show/hide, hold = toggle) ───
do
    local fabDragging   = false
    local fabDragStart  = nil
    local fabStartPos   = nil
    local fabMoved      = false

    local holding       = false
    local holdStarted   = 0
    local HOLD_TIME     = 0.45

    floating.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            fabDragging  = true
            fabMoved     = false
            fabDragStart = inp.Position
            fabStartPos  = floating.Position
            holding      = true
            holdStarted  = os.clock()

            -- Hold para toggle módulo
            task.delay(HOLD_TIME, function()
                if holding and not fabMoved then
                    Settings.ModuleEnabled = not Settings.ModuleEnabled
                    syncVisuals()
                    -- Pulso visual
                    TweenService:Create(floating, TweenInfo.new(0.1), {
                        Size = UDim2.fromOffset(78, 78)
                    }):Play()
                    task.delay(0.12, function()
                        TweenService:Create(floating, TweenInfo.new(0.15), {
                            Size = UDim2.fromOffset(68, 68)
                        }):Play()
                    end)
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(inp)
        if fabDragging and (
            inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch) then
            local delta = inp.Position - fabDragStart
            if delta.Magnitude > 5 then
                fabMoved = true
                holding  = false
            end
            if fabMoved then
                local scrSz = gui.AbsoluteSize
                local nx = math.clamp(fabStartPos.X.Offset + delta.X, 4, scrSz.X - 72)
                local ny = math.clamp(fabStartPos.Y.Offset + delta.Y, 4, scrSz.Y - 72)
                floating.Position = UDim2.new(0, nx, 0, ny)
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            if fabDragging then
                local heldFor = os.clock() - holdStarted
                holding = false
                -- Tap corto sin movimiento = show/hide panel
                if not fabMoved and heldFor < HOLD_TIME then
                    main.Visible = not main.Visible
                end
                fabDragging = false
                fabMoved    = false
            end
        end
    end)
end

-- ════════════════════════════════════════════════════════════
-- HOTKEY PC
-- ════════════════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(inp, processed)
    if processed then return end
    if inp.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    elseif inp.KeyCode == Enum.KeyCode.RightControl then
        Settings.ModuleEnabled = not Settings.ModuleEnabled
        syncVisuals()
    end
end)

-- ════════════════════════════════════════════════════════════
-- ANIMACIÓN SCAN LINE
-- ════════════════════════════════════════════════════════════
task.spawn(function()
    while gui.Parent do
        TweenService:Create(mainStroke,
            TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Transparency = 0.42 }):Play()
        TweenService:Create(floatStroke,
            TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Transparency = 0.28 }):Play()
        TweenService:Create(scanLine,
            TweenInfo.new(1.2, Enum.EasingStyle.Sine), {
                Position = UDim2.new(0, 20, 1, -20),
                BackgroundTransparency = 0.65,
            }):Play()

        task.wait(1.2)

        scanLine.Position              = UDim2.fromOffset(20, 92)
        scanLine.BackgroundTransparency = 0.2

        TweenService:Create(mainStroke,
            TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Transparency = 0.05 }):Play()
        TweenService:Create(floatStroke,
            TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Transparency = 0.05 }):Play()

        task.wait(0.8)
    end
end)

-- Estado inicial
syncVisuals()
print("[NEXUS v2.0] UI lista. Usuario: " .. player.Name)