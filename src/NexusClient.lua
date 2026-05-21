--[[
    NEXUS Client UI
    Studio-safe LocalScript for your own Roblox experience.

    Install:
    1. Upload the Nexus logo to Roblox.
    2. Replace LOGO_IMAGE_ID with your asset id.
    3. Put this file in StarterPlayer > StarterPlayerScripts.

    The UI exposes a BindableEvent named "NexusChanged" under the ScreenGui.
    Your own game systems can listen to it and react to settings changes.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LOGO_IMAGE_ID = "rbxassetid://TU_ID_DEL_LOGO"

local Settings = {
    ModuleEnabled = false,
    Prediction = true,
    FOV = 12,
    Smooth = 65,
    MaxRange = 500,
}

local oldGui = playerGui:FindFirstChild("NexusSystemUI")
if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "NexusSystemUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local changedEvent = Instance.new("BindableEvent")
changedEvent.Name = "NexusChanged"
changedEvent.Parent = gui

local function emitChanged()
    gui:SetAttribute("ModuleEnabled", Settings.ModuleEnabled)
    gui:SetAttribute("Prediction", Settings.Prediction)
    gui:SetAttribute("FOV", Settings.FOV)
    gui:SetAttribute("Smooth", Settings.Smooth)
    gui:SetAttribute("MaxRange", Settings.MaxRange)
    changedEvent:Fire(table.clone(Settings))
end

local function corner(parent, radius)
    local item = Instance.new("UICorner")
    item.CornerRadius = UDim.new(0, radius)
    item.Parent = parent
    return item
end

local function stroke(parent, color, thickness, transparency)
    local item = Instance.new("UIStroke")
    item.Color = color
    item.Thickness = thickness
    item.Transparency = transparency
    item.Parent = parent
    return item
end

local main = Instance.new("Frame")
main.Name = "NexusPanel"
main.Size = UDim2.fromOffset(404, 526)
main.Position = UDim2.new(0, 30, 0.5, -263)
main.BackgroundColor3 = Color3.fromRGB(4, 12, 24)
main.BackgroundTransparency = 0.06
main.BorderSizePixel = 0
main.Parent = gui
corner(main, 6)

local mainStroke = stroke(main, Color3.fromRGB(0, 190, 255), 2, 0.05)

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 34, 70)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(5, 13, 26)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 78, 126)),
})
gradient.Rotation = 35
gradient.Parent = main

local topLine = Instance.new("Frame")
topLine.Name = "TopGlow"
topLine.Size = UDim2.new(1, -44, 0, 2)
topLine.Position = UDim2.fromOffset(22, 15)
topLine.BackgroundColor3 = Color3.fromRGB(0, 210, 255)
topLine.BorderSizePixel = 0
topLine.Parent = main

local scanLine = Instance.new("Frame")
scanLine.Name = "ScanLine"
scanLine.Size = UDim2.new(1, -40, 0, 1)
scanLine.Position = UDim2.fromOffset(20, 92)
scanLine.BackgroundColor3 = Color3.fromRGB(120, 240, 255)
scanLine.BackgroundTransparency = 0.2
scanLine.BorderSizePixel = 0
scanLine.Parent = main

local logo = Instance.new("ImageLabel")
logo.Name = "Logo"
logo.Size = UDim2.fromOffset(84, 84)
logo.Position = UDim2.fromOffset(24, 24)
logo.BackgroundTransparency = 1
logo.Image = LOGO_IMAGE_ID
logo.ImageColor3 = Color3.fromRGB(120, 232, 255)
logo.Parent = main

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -134, 0, 40)
title.Position = UDim2.fromOffset(122, 28)
title.BackgroundTransparency = 1
title.Text = "NEXUS"
title.TextColor3 = Color3.fromRGB(205, 250, 255)
title.Font = Enum.Font.GothamBlack
title.TextSize = 34
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Size = UDim2.new(1, -134, 0, 24)
subtitle.Position = UDim2.fromOffset(124, 70)
subtitle.BackgroundTransparency = 1
subtitle.Text = "SYSTEM INTERFACE"
subtitle.TextColor3 = Color3.fromRGB(70, 210, 255)
subtitle.Font = Enum.Font.GothamMedium
subtitle.TextSize = 13
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = main

local statusHeader = Instance.new("Frame")
statusHeader.Name = "StatusHeader"
statusHeader.Size = UDim2.fromOffset(184, 38)
statusHeader.Position = UDim2.new(0.5, -92, 0, 124)
statusHeader.BackgroundColor3 = Color3.fromRGB(5, 20, 34)
statusHeader.BackgroundTransparency = 0.18
statusHeader.BorderSizePixel = 0
statusHeader.Parent = main
corner(statusHeader, 4)
stroke(statusHeader, Color3.fromRGB(120, 230, 255), 1, 0.25)

local statusTitle = Instance.new("TextLabel")
statusTitle.Size = UDim2.fromScale(1, 1)
statusTitle.BackgroundTransparency = 1
statusTitle.Text = "STATUS"
statusTitle.TextColor3 = Color3.fromRGB(225, 252, 255)
statusTitle.Font = Enum.Font.GothamBlack
statusTitle.TextSize = 20
statusTitle.Parent = statusHeader

local level = Instance.new("TextLabel")
level.Name = "Level"
level.Size = UDim2.fromOffset(126, 62)
level.Position = UDim2.fromOffset(34, 176)
level.BackgroundTransparency = 1
level.Text = "18"
level.TextColor3 = Color3.fromRGB(165, 245, 255)
level.Font = Enum.Font.GothamBlack
level.TextSize = 48
level.Parent = main

local levelLabel = Instance.new("TextLabel")
levelLabel.Size = UDim2.fromOffset(126, 22)
levelLabel.Position = UDim2.fromOffset(34, 228)
levelLabel.BackgroundTransparency = 1
levelLabel.Text = "LEVEL"
levelLabel.TextColor3 = Color3.fromRGB(190, 235, 255)
levelLabel.Font = Enum.Font.GothamMedium
levelLabel.TextSize = 13
levelLabel.Parent = main

local moduleStatus = Instance.new("TextLabel")
moduleStatus.Name = "ModuleStatus"
moduleStatus.Size = UDim2.new(1, -190, 0, 28)
moduleStatus.Position = UDim2.fromOffset(178, 182)
moduleStatus.BackgroundTransparency = 1
moduleStatus.Text = "MODULE: OFFLINE"
moduleStatus.TextColor3 = Color3.fromRGB(210, 244, 255)
moduleStatus.Font = Enum.Font.GothamBold
moduleStatus.TextSize = 16
moduleStatus.TextXAlignment = Enum.TextXAlignment.Left
moduleStatus.Parent = main

local profileText = Instance.new("TextLabel")
profileText.Name = "ProfileText"
profileText.Size = UDim2.new(1, -190, 0, 26)
profileText.Position = UDim2.fromOffset(178, 211)
profileText.BackgroundTransparency = 1
profileText.Text = "TITLE: NEXUS USER"
profileText.TextColor3 = Color3.fromRGB(145, 220, 255)
profileText.Font = Enum.Font.GothamMedium
profileText.TextSize = 13
profileText.TextXAlignment = Enum.TextXAlignment.Left
profileText.Parent = main

local controls = Instance.new("Frame")
controls.Name = "Controls"
controls.Size = UDim2.new(1, -48, 0, 250)
controls.Position = UDim2.fromOffset(24, 260)
controls.BackgroundColor3 = Color3.fromRGB(3, 18, 32)
controls.BackgroundTransparency = 0.18
controls.BorderSizePixel = 0
controls.Parent = main
corner(controls, 4)
stroke(controls, Color3.fromRGB(0, 170, 255), 1, 0.28)

local function makeButton(text, y, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -24, 0, 42)
    button.Position = UDim2.fromOffset(12, y)
    button.BackgroundColor3 = Color3.fromRGB(4, 28, 48)
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.fromRGB(198, 246, 255)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 14
    button.AutoButtonColor = false
    button.Parent = controls
    corner(button, 4)
    stroke(button, Color3.fromRGB(0, 175, 255), 1, 0.38)

    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.14), {
            BackgroundColor3 = Color3.fromRGB(0, 56, 86),
        }):Play()
    end)

    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.14), {
            BackgroundColor3 = Color3.fromRGB(4, 28, 48),
        }):Play()
    end)

    button.MouseButton1Click:Connect(callback)
    return button
end

local moduleButton
local predictionButton
local activeDot
local floatStroke

local function syncVisuals()
    moduleButton.Text = Settings.ModuleEnabled and "NEXUS MODULE: ON" or "NEXUS MODULE: OFF"
    predictionButton.Text = Settings.Prediction and "PREDICTION: ON" or "PREDICTION: OFF"

    moduleStatus.Text = Settings.ModuleEnabled and "MODULE: ONLINE" or "MODULE: OFFLINE"
    moduleStatus.TextColor3 = Settings.ModuleEnabled
        and Color3.fromRGB(110, 255, 180)
        or Color3.fromRGB(210, 244, 255)

    if activeDot then
        activeDot.BackgroundColor3 = Settings.ModuleEnabled
            and Color3.fromRGB(85, 255, 165)
            or Color3.fromRGB(90, 110, 120)
    end

    if floatStroke then
        floatStroke.Color = Settings.ModuleEnabled
            and Color3.fromRGB(85, 255, 165)
            or Color3.fromRGB(0, 200, 255)
    end

    emitChanged()
end

moduleButton = makeButton("NEXUS MODULE: OFF", 12, function()
    Settings.ModuleEnabled = not Settings.ModuleEnabled
    syncVisuals()
end)

predictionButton = makeButton("PREDICTION: ON", 60, function()
    Settings.Prediction = not Settings.Prediction
    syncVisuals()
end)

local function makeSlider(label, y, min, max, defaultValue, onChange)
    local box = Instance.new("Frame")
    box.Size = UDim2.new(1, -24, 0, 54)
    box.Position = UDim2.fromOffset(12, y)
    box.BackgroundTransparency = 1
    box.Parent = controls

    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 0, 22)
    text.BackgroundTransparency = 1
    text.Text = label .. ": " .. tostring(defaultValue)
    text.TextColor3 = Color3.fromRGB(185, 240, 255)
    text.Font = Enum.Font.GothamMedium
    text.TextSize = 13
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Parent = box

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 8)
    bar.Position = UDim2.fromOffset(0, 36)
    bar.BackgroundColor3 = Color3.fromRGB(12, 45, 65)
    bar.BorderSizePixel = 0
    bar.Parent = box
    corner(bar, 8)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((defaultValue - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    corner(fill, 8)

    local dragging = false

    local function update(inputX)
        local alpha = math.clamp((inputX - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + (max - min) * alpha)

        fill.Size = UDim2.new(alpha, 0, 1, 0)
        text.Text = label .. ": " .. tostring(value)
        onChange(value)
        emitChanged()
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            update(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            update(input.Position.X)
        end
    end)
end

makeSlider("FOV", 114, 2, 35, Settings.FOV, function(value)
    Settings.FOV = value
end)

makeSlider("SMOOTH", 166, 10, 100, Settings.Smooth, function(value)
    Settings.Smooth = value
end)

local floating = Instance.new("ImageButton")
floating.Name = "NexusFloatingToggle"
floating.Size = UDim2.fromOffset(72, 72)
floating.Position = UDim2.new(1, -100, 0.5, -36)
floating.BackgroundColor3 = Color3.fromRGB(3, 18, 32)
floating.BorderSizePixel = 0
floating.AutoButtonColor = false
floating.Image = ""
floating.Parent = gui
corner(floating, 72)

floatStroke = stroke(floating, Color3.fromRGB(0, 200, 255), 2, 0.05)

local floatLogo = Instance.new("ImageLabel")
floatLogo.Size = UDim2.fromOffset(46, 46)
floatLogo.Position = UDim2.fromScale(0.5, 0.5)
floatLogo.AnchorPoint = Vector2.new(0.5, 0.5)
floatLogo.BackgroundTransparency = 1
floatLogo.Image = LOGO_IMAGE_ID
floatLogo.ImageColor3 = Color3.fromRGB(125, 235, 255)
floatLogo.Parent = floating

activeDot = Instance.new("Frame")
activeDot.Size = UDim2.fromOffset(12, 12)
activeDot.Position = UDim2.new(1, -18, 0, 8)
activeDot.BackgroundColor3 = Color3.fromRGB(90, 110, 120)
activeDot.BorderSizePixel = 0
activeDot.Parent = floating
corner(activeDot, 12)

local function addDrag(handle, target)
    local dragging = false
    local dragStart = nil
    local startPos = nil

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

addDrag(main, main)

local holding = false
local holdStarted = 0
local holdTime = 0.45
local movedDuringHold = false

floating.MouseButton1Down:Connect(function()
    holding = true
    movedDuringHold = false
    holdStarted = os.clock()

    task.delay(holdTime, function()
        if holding and not movedDuringHold and os.clock() - holdStarted >= holdTime then
            Settings.ModuleEnabled = not Settings.ModuleEnabled
            syncVisuals()
        end
    end)
end)

floating.MouseButton1Up:Connect(function()
    local heldFor = os.clock() - holdStarted
    holding = false

    if heldFor < holdTime and not movedDuringHold then
        main.Visible = not main.Visible
    end
end)

do
    local dragging = false
    local dragStart = nil
    local startPos = nil

    floating.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = floating.Position
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            if delta.Magnitude > 4 then
                movedDuringHold = true
            end

            floating.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    elseif input.KeyCode == Enum.KeyCode.RightControl then
        Settings.ModuleEnabled = not Settings.ModuleEnabled
        syncVisuals()
    end
end)

task.spawn(function()
    while gui.Parent do
        TweenService:Create(mainStroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine), {
            Transparency = 0.42,
        }):Play()
        TweenService:Create(floatStroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine), {
            Transparency = 0.28,
        }):Play()
        TweenService:Create(scanLine, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {
            Position = UDim2.fromOffset(20, 500),
            BackgroundTransparency = 0.65,
        }):Play()

        task.wait(1.2)

        scanLine.Position = UDim2.fromOffset(20, 92)
        scanLine.BackgroundTransparency = 0.2

        TweenService:Create(mainStroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine), {
            Transparency = 0.05,
        }):Play()
        TweenService:Create(floatStroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine), {
            Transparency = 0.05,
        }):Play()

        task.wait(0.8)
    end
end)

syncVisuals()
