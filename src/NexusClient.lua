--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║           SYY  —  SyyClient  v5.1                        ║
    ║           Hecho por EnanoTop1 (stx)                          ║
    ╚══════════════════════════════════════════════════════════════╝
]]

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local HttpService      = game:GetService("HttpService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera    = Workspace.CurrentCamera
local CONFIG_FILE = "syy_config.json"

-- ══════════════════════════════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════════════════════════════
local DefaultConfig = {
    SilentAimEnabled=false, HitChance=100, Manipulation=false,
    VisibleCheck=true, FovEnabled=true, FovRadius=500, Snapline=false,
    TargetPart="Random",
    FovColorR=0,   FovColorG=190, FovColorB=255,
    SnapColorR=0,  SnapColorG=190,SnapColorB=255,
    EspEnabled=false, EspBox=true, EspSkeleton=true, EspHealthBar=true,
    EspDistance=true, EspNames=true, EspMaxDist=500, ItemInHand=true,
    BoxColorR=0,  BoxColorG=220, BoxColorB=255,
    SkelColorR=0, SkelColorG=220,SkelColorB=255,
    NameColorR=255,NameColorG=255,NameColorB=255,
    FlyEnabled=false, FlySpeed=50, RageMode=false, InfStamina=false,
    Whitelist={},
}
local Config = {}
local function deepCopy(t)
    local c={}; for k,v in pairs(t) do c[k]=type(v)=="table" and deepCopy(v) or v end; return c
end
local function loadConfig()
    if pcall(function()
        local d=HttpService:JSONDecode(readfile(CONFIG_FILE))
        for k,v in pairs(DefaultConfig) do Config[k]=d[k]~=nil and d[k] or (type(v)=="table" and deepCopy(v) or v) end
    end) then else Config=deepCopy(DefaultConfig) end
end
local function saveConfig() pcall(function() writefile(CONFIG_FILE,HttpService:JSONEncode(Config)) end) end
loadConfig()

local function isWhitelisted(p)
    for _,n in ipairs(Config.Whitelist) do if n:lower()==p.Name:lower() then return true end end; return false
end
local function addWhitelist(name)
    if name=="" then return false end
    for _,n in ipairs(Config.Whitelist) do if n:lower()==name:lower() then return false end end
    table.insert(Config.Whitelist,name); saveConfig(); return true
end
local function removeWhitelist(name)
    for i,n in ipairs(Config.Whitelist) do
        if n:lower()==name:lower() then table.remove(Config.Whitelist,i); saveConfig(); return true end
    end; return false
end

-- ══════════════════════════════════════════════════════════════
-- GUI
-- ══════════════════════════════════════════════════════════════
local old=playerGui:FindFirstChild("SyySystemUI"); if old then old:Destroy() end

local gui=Instance.new("ScreenGui")
gui.Name="SyySystemUI"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.DisplayOrder=99; gui.Parent=playerGui

-- helpers
local function stroke(p,col,thick)
    local s=Instance.new("UIStroke"); s.Color=col or Color3.fromRGB(0,190,255)
    s.Thickness=thick or 1; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; s.Parent=p; return s
end
local C_BG    = Color3.fromRGB(6,10,18)
local C_ROW   = Color3.fromRGB(8,14,24)
local C_DARK  = Color3.fromRGB(3,7,14)
local C_ACCENT= Color3.fromRGB(0,190,255)
local C_TEXT  = Color3.fromRGB(180,240,255)
local C_DIM   = Color3.fromRGB(70,160,210)
local TWEENI  = TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
local TWEENSL = TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)

-- ── DETECCIÓN MÓVIL ─────────────────────────────────────────
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ── PANEL — adaptativo móvil / PC ───────────────────────────
local panelW = isMobile and math.min(math.floor(camera.ViewportSize.X * 0.88), 360) or 314
local panelH = isMobile and math.min(math.floor(camera.ViewportSize.Y * 0.82), 560) or 480

local main=Instance.new("Frame")
main.Name="SyyPanel"
main.Size=UDim2.fromOffset(panelW,panelH)
-- centrado en pantalla en móvil, lateral en PC
if isMobile then
    main.Position=UDim2.new(0.5,-panelW/2,0.5,-panelH/2)
else
    main.Position=UDim2.new(0,28,0.5,-panelH/2)
end
main.BackgroundColor3=C_BG; main.BackgroundTransparency=0
main.BorderSizePixel=0; main.ClipsDescendants=true; main.Parent=gui
local mainStroke=stroke(main,C_ACCENT,2)

local grad=Instance.new("UIGradient")
grad.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(0,18,36)),
    ColorSequenceKeypoint.new(0.5,Color3.fromRGB(4,10,20)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(0,24,44)),
})
grad.Rotation=40; grad.Parent=main

-- scanline decorativa
local scanLine=Instance.new("Frame")
scanLine.Size=UDim2.new(1,0,0,1); scanLine.Position=UDim2.fromOffset(0,0)
scanLine.BackgroundColor3=C_ACCENT; scanLine.BackgroundTransparency=0.6
scanLine.BorderSizePixel=0; scanLine.ZIndex=10; scanLine.Parent=main

-- ── HEADER ──────────────────────────────────────────────────
local headerH = isMobile and 54 or 44
local header=Instance.new("Frame")
header.Size=UDim2.new(1,0,0,headerH); header.BackgroundColor3=C_DARK
header.BackgroundTransparency=0; header.BorderSizePixel=0; header.Parent=main

local headerLine=Instance.new("Frame")
headerLine.Size=UDim2.new(1,0,0,1); headerLine.Position=UDim2.new(0,0,1,-1)
headerLine.BackgroundColor3=C_ACCENT; headerLine.BorderSizePixel=0; headerLine.Parent=header

-- logo image
local logoSize = isMobile and 42 or 34
local logoImg=Instance.new("ImageLabel")
logoImg.Size=UDim2.fromOffset(logoSize,logoSize)
logoImg.Position=UDim2.new(0,6,0.5,-(logoSize/2))
logoImg.BackgroundTransparency=1; logoImg.Image="rbxassetid://1779405825649"
logoImg.ScaleType=Enum.ScaleType.Fit; logoImg.Parent=header

local titleLbl=Instance.new("TextLabel")
titleLbl.Size=UDim2.new(1,-110,0,isMobile and 26 or 24)
titleLbl.Position=UDim2.fromOffset(logoSize+10, isMobile and 6 or 4)
titleLbl.BackgroundTransparency=1; titleLbl.Text="SYY"
titleLbl.TextColor3=C_ACCENT; titleLbl.Font=Enum.Font.GothamBlack
titleLbl.TextSize=isMobile and 20 or 18
titleLbl.TextXAlignment=Enum.TextXAlignment.Left; titleLbl.Parent=header

local subLbl=Instance.new("TextLabel")
subLbl.Size=UDim2.new(1,-110,0,13)
subLbl.Position=UDim2.fromOffset(logoSize+10, isMobile and 34 or 27)
subLbl.BackgroundTransparency=1; subLbl.Text="v5.1  ·  EnanoTop1 (stx)  ·  "..player.Name
subLbl.TextColor3=C_DIM; subLbl.Font=Enum.Font.GothamMedium
subLbl.TextSize=isMobile and 10 or 9
subLbl.TextXAlignment=Enum.TextXAlignment.Left; subLbl.Parent=header

-- botón X — más grande en móvil
local closeBtnSz = isMobile and 42 or 34
local closeBtn=Instance.new("TextButton")
closeBtn.Size=UDim2.fromOffset(closeBtnSz,closeBtnSz)
closeBtn.Position=UDim2.new(1,-(closeBtnSz+4),0.5,-(closeBtnSz/2))
closeBtn.BackgroundColor3=Color3.fromRGB(35,8,8); closeBtn.BorderSizePixel=0
closeBtn.Text="✕"; closeBtn.TextColor3=Color3.fromRGB(255,80,80)
closeBtn.Font=Enum.Font.GothamBold; closeBtn.TextSize=isMobile and 16 or 13
closeBtn.AutoButtonColor=false; closeBtn.Parent=header
stroke(closeBtn,Color3.fromRGB(120,30,30),1)
closeBtn.MouseButton1Click:Connect(function()
    TweenService:Create(main,TweenInfo.new(0.15,Enum.EasingStyle.Quad),{BackgroundTransparency=1}):Play()
    task.delay(0.15,function() main.Visible=false; main.BackgroundTransparency=0 end)
end)

-- ── TAB BAR ─────────────────────────────────────────────────
local tabBarH = isMobile and 38 or 30
local tabBar=Instance.new("Frame")
tabBar.Size=UDim2.new(1,0,0,tabBarH); tabBar.Position=UDim2.fromOffset(0,headerH)
tabBar.BackgroundColor3=C_DARK; tabBar.BorderSizePixel=0; tabBar.Parent=main

local tabBarLine=Instance.new("Frame")
tabBarLine.Size=UDim2.new(1,0,0,1); tabBarLine.Position=UDim2.new(0,0,1,-1)
tabBarLine.BackgroundColor3=C_ACCENT; tabBarLine.BorderSizePixel=0; tabBarLine.Parent=tabBar

-- indicador deslizante de tab activo
local tabIndicator=Instance.new("Frame")
tabIndicator.Size=UDim2.new(1/4,0,0,2); tabIndicator.Position=UDim2.new(0,0,1,-2)
tabIndicator.BackgroundColor3=C_ACCENT; tabIndicator.BorderSizePixel=0; tabIndicator.ZIndex=3; tabIndicator.Parent=tabBar

local contentY=headerH+tabBarH+2
local contentH=panelH-contentY-6
local tabNames={"Aimbot","Visuals","Extras","Settings"}
local tabBtns={}; local tabPages={}

local function makeTabPage()
    local page=Instance.new("ScrollingFrame")
    page.Size=UDim2.new(1,-2,0,contentH); page.Position=UDim2.fromOffset(1,contentY)
    page.BackgroundTransparency=1; page.BorderSizePixel=0
    page.ScrollBarThickness=isMobile and 5 or 3; page.ScrollBarImageColor3=C_ACCENT
    page.CanvasSize=UDim2.new(0,0,0,0); page.AutomaticCanvasSize=Enum.AutomaticSize.Y
    page.Visible=false; page.Parent=main
    local pad=Instance.new("UIPadding")
    pad.PaddingTop=UDim.new(0,isMobile and 8 or 6)
    pad.PaddingLeft=UDim.new(0,isMobile and 10 or 8)
    pad.PaddingRight=UDim.new(0,isMobile and 10 or 8)
    pad.PaddingBottom=UDim.new(0,isMobile and 10 or 8); pad.Parent=page
    local lay=Instance.new("UIListLayout")
    lay.SortOrder=Enum.SortOrder.LayoutOrder
    lay.Padding=UDim.new(0,isMobile and 6 or 4); lay.Parent=page
    return page
end

for i,name in ipairs(tabNames) do
    local btn=Instance.new("TextButton")
    btn.Size=UDim2.new(1/#tabNames,0,1,-2); btn.Position=UDim2.new((i-1)/#tabNames,0,0,1)
    btn.BackgroundTransparency=1; btn.BorderSizePixel=0
    btn.Text=name; btn.Font=Enum.Font.GothamBold
    btn.TextSize=isMobile and 13 or 11
    btn.TextColor3=(i==1) and C_ACCENT or C_DIM
    btn.AutoButtonColor=false; btn.Parent=tabBar
    tabBtns[i]=btn; tabPages[i]=makeTabPage()

    btn.MouseButton1Click:Connect(function()
        for j,p in ipairs(tabPages) do
            p.Visible=(j==i)
            tabBtns[j].TextColor3=(j==i) and C_ACCENT or C_DIM
        end
        TweenService:Create(tabIndicator,TWEENI,{Position=UDim2.new((i-1)/#tabNames,0,1,-2)}):Play()
    end)
end
tabPages[1].Visible=true

-- ══════════════════════════════════════════════════════════════
-- UI HELPERS  (adaptados a móvil)
-- ══════════════════════════════════════════════════════════════
local ROW_H     = isMobile and 40 or 30
local SLIDER_H  = isMobile and 52 or 42
local TXT_SIZE  = isMobile and 13 or 11
local SEC_SIZE  = isMobile and 10 or 9
local TOG_W     = isMobile and 48 or 36
local TOG_H     = isMobile and 24 or 18
local DOT_SZ    = isMobile and 18 or 14

local function secLabel(page,text)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,isMobile and 20 or 16)
    f.BackgroundTransparency=1; f.Parent=page
    local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,0,1,0); l.BackgroundTransparency=1
    l.Text="— "..text.." —"; l.TextColor3=C_ACCENT; l.Font=Enum.Font.GothamBlack
    l.TextSize=SEC_SIZE; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=f
    return f
end

local function makeToggle(page,text,key,cb)
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,ROW_H); row.BackgroundColor3=C_ROW
    row.BorderSizePixel=0; row.Parent=page
    stroke(row,Color3.fromRGB(0,60,90),1)

    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-(TOG_W+16),1,0); lbl.Position=UDim2.fromOffset(8,0)
    lbl.BackgroundTransparency=1; lbl.Text=text
    lbl.TextColor3=C_TEXT; lbl.Font=Enum.Font.GothamMedium
    lbl.TextSize=TXT_SIZE; lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.TextWrapped=true; lbl.Parent=row

    local tog=Instance.new("Frame")
    tog.Size=UDim2.fromOffset(TOG_W,TOG_H)
    tog.Position=UDim2.new(1,-(TOG_W+6),0.5,-(TOG_H/2))
    tog.BackgroundColor3=Color3.fromRGB(20,30,40); tog.BorderSizePixel=0; tog.Parent=row
    stroke(tog,Color3.fromRGB(0,80,120),1)

    local dot=Instance.new("Frame")
    dot.Size=UDim2.fromOffset(DOT_SZ,DOT_SZ); dot.BorderSizePixel=0
    dot.BackgroundColor3=Color3.fromRGB(60,80,100); dot.Parent=tog

    local function refresh()
        local on=Config[key]
        TweenService:Create(tog,TWEENI,{BackgroundColor3=on and Color3.fromRGB(0,40,70) or Color3.fromRGB(20,30,40)}):Play()
        TweenService:Create(dot,TWEENI,{
            Position=on and UDim2.fromOffset(TOG_W-DOT_SZ-2,2) or UDim2.fromOffset(2,2),
            BackgroundColor3=on and C_ACCENT or Color3.fromRGB(60,80,100),
        }):Play()
    end
    refresh()

    local hitbox=Instance.new("TextButton")
    hitbox.Size=UDim2.new(1,0,1,0); hitbox.BackgroundTransparency=1
    hitbox.Text=""; hitbox.Parent=row
    hitbox.MouseButton1Click:Connect(function()
        Config[key]=not Config[key]; refresh(); saveConfig()
        if cb then cb(Config[key]) end
    end)
    return row, refresh
end

local function makeSlider(page,text,key,mn,mx,cb)
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,SLIDER_H); row.BackgroundColor3=C_ROW
    row.BorderSizePixel=0; row.Parent=page
    stroke(row,Color3.fromRGB(0,60,90),1)

    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-8,0,isMobile and 20 or 17); lbl.Position=UDim2.fromOffset(8,4)
    lbl.BackgroundTransparency=1; lbl.Text=text..": "..tostring(Config[key])
    lbl.TextColor3=C_TEXT; lbl.Font=Enum.Font.GothamMedium
    lbl.TextSize=TXT_SIZE; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row

    local trackY = isMobile and 30 or 26
    local trackH = isMobile and 7 or 5
    local track=Instance.new("Frame")
    track.Size=UDim2.new(1,-16,0,trackH); track.Position=UDim2.fromOffset(8,trackY)
    track.BackgroundColor3=Color3.fromRGB(12,22,34); track.BorderSizePixel=0; track.Parent=row
    stroke(track,Color3.fromRGB(0,60,90),1)

    local fill=Instance.new("Frame")
    fill.BackgroundColor3=C_ACCENT; fill.BorderSizePixel=0; fill.Parent=track

    local function setVal(v)
        v=math.clamp(math.floor(v),mn,mx); Config[key]=v
        lbl.Text=text..": "..tostring(v)
        TweenService:Create(fill,TWEENSL,{Size=UDim2.new((v-mn)/(mx-mn),0,1,0)}):Play()
        if cb then cb(v) end
    end
    setVal(Config[key])

    local sliding=false
    local function slide(inp)
        local abs=track.AbsolutePosition; local sz=track.AbsoluteSize
        setVal(mn+math.clamp((inp.Position.X-abs.X)/sz.X,0,1)*(mx-mn))
    end
    track.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then sliding=true; slide(inp) end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if sliding and (inp.UserInputType==Enum.UserInputType.MouseMovement
        or inp.UserInputType==Enum.UserInputType.Touch) then slide(inp) end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            if sliding then sliding=false; saveConfig() end
        end
    end)
    return row
end

local function makeColorRow(page,text,rk,gk,bk)
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,ROW_H); row.BackgroundColor3=C_ROW
    row.BorderSizePixel=0; row.Parent=page
    stroke(row,Color3.fromRGB(0,60,90),1)

    local previewSz = isMobile and 28 or 22
    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-(previewSz+16),1,0); lbl.Position=UDim2.fromOffset(8,0)
    lbl.BackgroundTransparency=1; lbl.Text=text
    lbl.TextColor3=C_TEXT; lbl.Font=Enum.Font.GothamMedium
    lbl.TextSize=TXT_SIZE; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row

    local prev=Instance.new("TextButton")
    prev.Size=UDim2.fromOffset(previewSz,previewSz)
    prev.Position=UDim2.new(1,-(previewSz+6),0.5,-(previewSz/2))
    prev.BorderSizePixel=0; prev.BackgroundColor3=Color3.fromRGB(Config[rk],Config[gk],Config[bk])
    prev.Text=""; prev.AutoButtonColor=false; prev.Parent=row
    stroke(prev,C_ACCENT,1)

    local presets={{0,190,255},{255,80,80},{80,255,80},{255,215,0},{255,140,0},{200,80,255},{255,255,255},{0,255,200}}
    local ci=1
    prev.MouseButton1Click:Connect(function()
        ci=ci%#presets+1
        Config[rk]=presets[ci][1]; Config[gk]=presets[ci][2]; Config[bk]=presets[ci][3]
        TweenService:Create(prev,TWEENI,{BackgroundColor3=Color3.fromRGB(presets[ci][1],presets[ci][2],presets[ci][3])}):Play()
        saveConfig()
    end)
    return row
end

local function makeDropdown(page,text,key,options)
    local open=false
    local container=Instance.new("Frame")
    container.Size=UDim2.new(1,0,0,ROW_H); container.BackgroundTransparency=1
    container.BorderSizePixel=0; container.Parent=page
    local lay2=Instance.new("UIListLayout"); lay2.SortOrder=Enum.SortOrder.LayoutOrder
    lay2.Padding=UDim.new(0,1); lay2.Parent=container

    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,ROW_H); row.BackgroundColor3=C_ROW
    row.BorderSizePixel=0; row.Parent=container; stroke(row,Color3.fromRGB(0,60,90),1)

    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-36,1,0); lbl.Position=UDim2.fromOffset(8,0)
    lbl.BackgroundTransparency=1; lbl.Text=text..": "..Config[key]
    lbl.TextColor3=C_TEXT; lbl.Font=Enum.Font.GothamMedium
    lbl.TextSize=TXT_SIZE; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row

    local arr=Instance.new("TextLabel")
    arr.Size=UDim2.fromOffset(22,18); arr.Position=UDim2.new(1,-24,0.5,-9)
    arr.BackgroundTransparency=1; arr.Text="▾"; arr.TextColor3=C_ACCENT
    arr.Font=Enum.Font.GothamBold; arr.TextSize=13; arr.Parent=row

    local optH = isMobile and 34 or 26
    local dropFrame=Instance.new("Frame")
    dropFrame.BackgroundColor3=C_DARK; dropFrame.BorderSizePixel=0
    dropFrame.Visible=false; dropFrame.ZIndex=10
    dropFrame.Size=UDim2.new(1,0,0,0); dropFrame.Parent=container
    stroke(dropFrame,C_ACCENT,1)

    for idx,opt in ipairs(options) do
        local ob=Instance.new("TextButton")
        ob.Size=UDim2.new(1,0,0,optH); ob.Position=UDim2.fromOffset(0,(idx-1)*optH)
        ob.BackgroundColor3=C_ROW; ob.BorderSizePixel=0
        ob.Text=opt; ob.Font=Enum.Font.GothamMedium; ob.TextSize=TXT_SIZE
        ob.TextColor3=(Config[key]==opt) and C_ACCENT or C_TEXT
        ob.AutoButtonColor=false; ob.ZIndex=11; ob.Parent=dropFrame
        ob.MouseButton1Click:Connect(function()
            Config[key]=opt; lbl.Text=text..": "..opt
            for _,b in ipairs(dropFrame:GetChildren()) do
                if b:IsA("TextButton") then b.TextColor3=(b.Text==opt) and C_ACCENT or C_TEXT end
            end
            TweenService:Create(dropFrame,TWEENI,{Size=UDim2.new(1,0,0,0)}):Play()
            task.delay(0.18,function() dropFrame.Visible=false end)
            open=false; container.Size=UDim2.new(1,0,0,ROW_H); arr.Text="▾"
            saveConfig()
        end)
    end

    local hitbox=Instance.new("TextButton")
    hitbox.Size=UDim2.new(1,0,1,0); hitbox.BackgroundTransparency=1
    hitbox.Text=""; hitbox.ZIndex=2; hitbox.Parent=row
    hitbox.MouseButton1Click:Connect(function()
        open=not open
        if open then
            dropFrame.Visible=true
            dropFrame.Size=UDim2.new(1,0,0,0)
            TweenService:Create(dropFrame,TWEENI,{Size=UDim2.new(1,0,0,#options*optH)}):Play()
            container.Size=UDim2.new(1,0,0,ROW_H+#options*optH)
        else
            TweenService:Create(dropFrame,TWEENI,{Size=UDim2.new(1,0,0,0)}):Play()
            task.delay(0.18,function() dropFrame.Visible=false end)
            container.Size=UDim2.new(1,0,0,ROW_H)
        end
        arr.Text=open and "▴" or "▾"
    end)
    return container
end

-- ══════════════════════════════════════════════════════════════
-- TAB 1: AIMBOT
-- ══════════════════════════════════════════════════════════════
local pageAim=tabPages[1]
secLabel(pageAim,"Silent Aim")
makeToggle(pageAim,"Silent Aim",       "SilentAimEnabled")
makeToggle(pageAim,"VisibleCheck",     "VisibleCheck")
makeToggle(pageAim,"Manipulation",     "Manipulation")
makeSlider(pageAim,"HitChance %",      "HitChance",1,100)
secLabel(pageAim,"FOV")
makeToggle(pageAim,"FOV Circle",       "FovEnabled")
makeSlider(pageAim,"Fov Radius",       "FovRadius",10,800)
makeColorRow(pageAim,"FOV Color",      "FovColorR","FovColorG","FovColorB")
secLabel(pageAim,"Snapline")
makeToggle(pageAim,"Snapline",         "Snapline")
makeColorRow(pageAim,"Snap Color",     "SnapColorR","SnapColorG","SnapColorB")
secLabel(pageAim,"Target")
makeDropdown(pageAim,"Target Part",    "TargetPart",{"Head","UpperTorso","LowerTorso","Random"})

-- ══════════════════════════════════════════════════════════════
-- TAB 2: VISUALS
-- ══════════════════════════════════════════════════════════════
local pageVis=tabPages[2]
secLabel(pageVis,"ESP")
makeToggle(pageVis,"ESP Enabled",      "EspEnabled")
makeToggle(pageVis,"Box",              "EspBox")
makeColorRow(pageVis,"Box Color",      "BoxColorR","BoxColorG","BoxColorB")
makeToggle(pageVis,"Skeleton",         "EspSkeleton")
makeColorRow(pageVis,"Skel Color",     "SkelColorR","SkelColorG","SkelColorB")
makeToggle(pageVis,"Health Bar",       "EspHealthBar")
makeToggle(pageVis,"Distancia",        "EspDistance")
makeToggle(pageVis,"Nombres",          "EspNames")
makeColorRow(pageVis,"Name Color",     "NameColorR","NameColorG","NameColorB")
makeSlider(pageVis,"Dist Máx",         "EspMaxDist",50,1000)
secLabel(pageVis,"Extras Visuales")
makeToggle(pageVis,"Item en la Mano",  "ItemInHand")

-- ══════════════════════════════════════════════════════════════
-- TAB 3: EXTRAS
-- ══════════════════════════════════════════════════════════════
local pageExt=tabPages[3]
secLabel(pageExt,"Rage Mode")
makeToggle(pageExt,"🔴 Rage Mode","RageMode",function(on)
    if on then
        Config.SilentAimEnabled=true; Config.HitChance=100
        Config.FovRadius=999; Config.VisibleCheck=false
        Config.Manipulation=true; Config.TargetPart="Head"
        saveConfig()
    end
end)
secLabel(pageExt,"Fly")
makeToggle(pageExt,"Fly Enabled","FlyEnabled")
makeSlider(pageExt,"Velocidad Fly","FlySpeed",10,200)

-- ── INF STAMINA ──────────────────────────────────────────────
secLabel(pageExt,"Stamina")
makeToggle(pageExt,"♾ Inf Stamina","InfStamina",function(on)
    if not on then return end
end)

-- loop infinito de stamina
task.spawn(function()
    while true do
        task.wait(0.1)
        if Config.InfStamina then
            local char=player.Character
            if char then
                -- compatibilidad genérica: busca valores típicos de stamina
                for _,v in ipairs(char:GetDescendants()) do
                    if (v:IsA("NumberValue") or v:IsA("IntValue")) then
                        local nm=v.Name:lower()
                        if nm:find("stamina") or nm:find("energia") or nm:find("energy") or nm:find("sprint") then
                            if v.Value < (v:FindFirstChild("MaxValue") and v.MaxValue or 100) then
                                pcall(function() v.Value=100 end)
                            end
                        end
                    end
                end
                -- Humanoid.WalkSpeed no se toca; pero nos aseguramos de no limitar salto
                local hum=char:FindFirstChildOfClass("Humanoid")
                if hum then
                    pcall(function()
                        -- algunos juegos usan JumpPower o atributos custom
                        if hum:GetAttribute("Stamina") ~= nil then
                            hum:SetAttribute("Stamina", hum:GetAttribute("MaxStamina") or hum:GetAttribute("Stamina") or 100)
                        end
                        if hum:GetAttribute("Energy") ~= nil then
                            hum:SetAttribute("Energy", hum:GetAttribute("MaxEnergy") or 100)
                        end
                    end)
                end
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════
-- TAB 4: SETTINGS
-- ══════════════════════════════════════════════════════════════
local pageSet=tabPages[4]
secLabel(pageSet,"Whitelist")
do
    local inputRow=Instance.new("Frame")
    inputRow.Size=UDim2.new(1,0,0,ROW_H); inputRow.BackgroundColor3=C_ROW
    inputRow.BorderSizePixel=0; inputRow.Parent=pageSet; stroke(inputRow,Color3.fromRGB(0,60,90),1)

    local nameBox=Instance.new("TextBox")
    nameBox.Size=UDim2.new(1,-76,1,-8); nameBox.Position=UDim2.fromOffset(5,4)
    nameBox.BackgroundColor3=C_DARK; nameBox.BorderSizePixel=0
    nameBox.Text=""; nameBox.PlaceholderText="Nombre de usuario..."
    nameBox.PlaceholderColor3=C_DIM; nameBox.TextColor3=C_TEXT
    nameBox.Font=Enum.Font.GothamMedium; nameBox.TextSize=TXT_SIZE
    nameBox.ClearTextOnFocus=false; nameBox.Parent=inputRow
    stroke(nameBox,Color3.fromRGB(0,60,90),1)

    local addBtn=Instance.new("TextButton")
    addBtn.Size=UDim2.fromOffset(62,isMobile and 28 or 22)
    addBtn.Position=UDim2.new(1,-66,0.5,-(isMobile and 14 or 11))
    addBtn.BackgroundColor3=Color3.fromRGB(0,30,50); addBtn.BorderSizePixel=0
    addBtn.Text="+ Add"; addBtn.TextColor3=C_ACCENT
    addBtn.Font=Enum.Font.GothamBold; addBtn.TextSize=TXT_SIZE
    addBtn.AutoButtonColor=false; addBtn.Parent=inputRow
    stroke(addBtn,C_ACCENT,1)

    local wlFrame=Instance.new("Frame")
    wlFrame.Size=UDim2.new(1,0,0,0); wlFrame.BackgroundTransparency=1
    wlFrame.AutomaticSize=Enum.AutomaticSize.Y; wlFrame.Parent=pageSet
    local wlLay=Instance.new("UIListLayout"); wlLay.SortOrder=Enum.SortOrder.LayoutOrder
    wlLay.Padding=UDim.new(0,2); wlLay.Parent=wlFrame

    local WL_ENTRY_H = isMobile and 34 or 26
    local function rebuildWL()
        for _,c in ipairs(wlFrame:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        for _,name in ipairs(Config.Whitelist) do
            local e=Instance.new("Frame")
            e.Size=UDim2.new(1,0,0,WL_ENTRY_H); e.BackgroundColor3=C_ROW
            e.BorderSizePixel=0; e.Parent=wlFrame; stroke(e,Color3.fromRGB(0,60,90),1)
            local nl=Instance.new("TextLabel")
            nl.Size=UDim2.new(1,-38,1,0); nl.Position=UDim2.fromOffset(6,0)
            nl.BackgroundTransparency=1; nl.Text="✓ "..name
            nl.TextColor3=C_ACCENT; nl.Font=Enum.Font.GothamMedium
            nl.TextSize=TXT_SIZE; nl.TextXAlignment=Enum.TextXAlignment.Left; nl.Parent=e
            local dbSz = isMobile and 28 or 24
            local db=Instance.new("TextButton")
            db.Size=UDim2.fromOffset(dbSz,isMobile and 24 or 18)
            db.Position=UDim2.new(1,-(dbSz+4),0.5,-(isMobile and 12 or 9))
            db.BackgroundColor3=Color3.fromRGB(40,8,8); db.BorderSizePixel=0
            db.Text="✕"; db.TextColor3=Color3.fromRGB(255,80,80)
            db.Font=Enum.Font.GothamBold; db.TextSize=isMobile and 11 or 9
            db.AutoButtonColor=false; db.Parent=e
            stroke(db,Color3.fromRGB(100,20,20),1)
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
    saveBtn.Size=UDim2.new(1,0,0,ROW_H); saveBtn.BackgroundColor3=Color3.fromRGB(0,30,50)
    saveBtn.BorderSizePixel=0; saveBtn.Text="💾  Guardar Config"
    saveBtn.TextColor3=C_ACCENT; saveBtn.Font=Enum.Font.GothamBold
    saveBtn.TextSize=TXT_SIZE; saveBtn.AutoButtonColor=false; saveBtn.Parent=pageSet
    stroke(saveBtn,C_ACCENT,1)
    saveBtn.MouseButton1Click:Connect(function()
        saveConfig(); saveBtn.Text="✅  Guardado!"
        task.delay(1.5,function() saveBtn.Text="💾  Guardar Config" end)
    end)
end
do
    local rstBtn=Instance.new("TextButton")
    rstBtn.Size=UDim2.new(1,0,0,ROW_H); rstBtn.BackgroundColor3=Color3.fromRGB(35,8,8)
    rstBtn.BorderSizePixel=0; rstBtn.Text="🔄  Resetear Config"
    rstBtn.TextColor3=Color3.fromRGB(255,80,80); rstBtn.Font=Enum.Font.GothamBold
    rstBtn.TextSize=TXT_SIZE; rstBtn.AutoButtonColor=false; rstBtn.Parent=pageSet
    stroke(rstBtn,Color3.fromRGB(120,30,30),1)
    rstBtn.MouseButton1Click:Connect(function()
        Config=deepCopy(DefaultConfig); saveConfig()
        rstBtn.Text="✅  Reseteado"; task.delay(2,function() rstBtn.Text="🔄  Resetear Config" end)
    end)
end

-- ══════════════════════════════════════════════════════════════
-- DRAG
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
            main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
-- FAB  (botón flotante con logo)
-- ══════════════════════════════════════════════════════════════
local fabSz = isMobile and 62 or 48
-- En móvil lo ponemos abajo-derecha para no tapar el juego
local fab=Instance.new("ImageButton")
fab.Name="SyyFAB"; fab.Size=UDim2.fromOffset(fabSz,fabSz)
fab.Position= isMobile
    and UDim2.new(1,-(fabSz+14),1,-(fabSz+40))   -- abajo-derecha en móvil
    or  UDim2.new(1,-(fabSz+12),0.5,-(fabSz/2))  -- centro-derecha en PC
fab.BackgroundColor3=C_DARK; fab.BorderSizePixel=0
fab.AutoButtonColor=false
fab.Image="rbxassetid://1779405825649"
fab.ScaleType=Enum.ScaleType.Fit
fab.ZIndex=20; fab.Parent=gui
stroke(fab,C_ACCENT,2)

-- pulse animation on FAB
task.spawn(function()
    local fabStroke=fab:FindFirstChildOfClass("UIStroke")
    while fab.Parent do
        if fabStroke then
            TweenService:Create(fabStroke,TweenInfo.new(0.9,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Transparency=0.6}):Play()
        end
        task.wait(0.9)
        if fabStroke then
            TweenService:Create(fabStroke,TweenInfo.new(0.9,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Transparency=0}):Play()
        end
        task.wait(0.9)
    end
end)

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
                    Config.SilentAimEnabled=not Config.SilentAimEnabled; saveConfig()
                    -- feedback visual: borde verde=ON / azul=OFF
                    local fbStroke=fab:FindFirstChildOfClass("UIStroke")
                    if fbStroke then
                        TweenService:Create(fbStroke,TweenInfo.new(0.08),{
                            Color=Config.SilentAimEnabled and Color3.fromRGB(80,255,160) or C_ACCENT
                        }):Play()
                    end
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
                local nx=math.clamp(fabStartPos.X.Offset+delta.X,4,sc.X-fabSz-4)
                local ny=math.clamp(fabStartPos.Y.Offset+delta.Y,4,sc.Y-fabSz-4)
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
                    if main.Visible then
                        TweenService:Create(main,TweenInfo.new(0.15,Enum.EasingStyle.Quad),{BackgroundTransparency=1}):Play()
                        task.delay(0.15,function() main.Visible=false; main.BackgroundTransparency=0 end)
                    else
                        main.Visible=true
                        main.Size=UDim2.fromOffset(panelW,0)
                        TweenService:Create(main,TWEENI,{Size=UDim2.fromOffset(panelW,panelH)}):Play()
                    end
                end
                fabDrag=false; fabMoved=false
            end
        end
    end)
end

UserInputService.InputBegan:Connect(function(inp,proc)
    if proc then return end
    if inp.KeyCode==Enum.KeyCode.RightShift then
        if main.Visible then
            TweenService:Create(main,TweenInfo.new(0.15,Enum.EasingStyle.Quad),{BackgroundTransparency=1}):Play()
            task.delay(0.15,function() main.Visible=false; main.BackgroundTransparency=0 end)
        else
            main.Visible=true; main.Size=UDim2.fromOffset(panelW,0)
            TweenService:Create(main,TWEENI,{Size=UDim2.fromOffset(panelW,panelH)}):Play()
        end
    end
    if inp.KeyCode==Enum.KeyCode.RightControl then
        Config.SilentAimEnabled=not Config.SilentAimEnabled; saveConfig()
    end
end)

-- ══════════════════════════════════════════════════════════════
-- SCANLINE ANIM (ligera, 2s)
-- ══════════════════════════════════════════════════════════════
task.spawn(function()
    while gui.Parent do
        TweenService:Create(scanLine,TweenInfo.new(1.4,Enum.EasingStyle.Linear),
            {Position=UDim2.fromOffset(0,panelH),BackgroundTransparency=0.9}):Play()
        task.wait(1.4)
        scanLine.Position=UDim2.fromOffset(0,0); scanLine.BackgroundTransparency=0.5
        task.wait(0.1)
    end
end)

-- ══════════════════════════════════════════════════════════════
-- FLY
-- ══════════════════════════════════════════════════════════════
local flyActive=false
local function stopFly()
    flyActive=false
    local char=player.Character; if not char then return end
    local hum=char:FindFirstChildOfClass("Humanoid")
    local root=char:FindFirstChild("HumanoidRootPart")
    if hum then hum.PlatformStand=false end
    if root then
        local bp=root:FindFirstChild("SyyFlyBP"); local bg=root:FindFirstChild("SyyFlyBG")
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
    if not root:FindFirstChild("SyyFlyBP") then
        local bp=Instance.new("BodyPosition"); bp.Name="SyyFlyBP"
        bp.MaxForce=Vector3.new(1e5,1e5,1e5); bp.Position=root.Position
        bp.D=500; bp.P=10000; bp.Parent=root
    end
    if not root:FindFirstChild("SyyFlyBG") then
        local bg=Instance.new("BodyGyro"); bg.Name="SyyFlyBG"
        bg.MaxTorque=Vector3.new(1e5,1e5,1e5); bg.D=100; bg.P=10000
        bg.CFrame=root.CFrame; bg.Parent=root
    end
end
player.CharacterAdded:Connect(function()
    flyActive=false; task.wait(0.5); if Config.FlyEnabled then startFly() end
end)

-- ══════════════════════════════════════════════════════════════
-- DRAWINGS
-- ══════════════════════════════════════════════════════════════
local function getItemInHand(char)
    if not char then return nil end
    for _,v in ipairs(char:GetChildren()) do if v:IsA("Tool") then return v.Name end end
    return nil
end

local fovCircle=Drawing.new("Circle")
fovCircle.Visible=false; fovCircle.Thickness=1.5; fovCircle.Filled=false

local snapLineDraw=Drawing.new("Line")
snapLineDraw.Visible=false; snapLineDraw.Thickness=1.5

local SKEL={
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
}
local espObjects={}; local itemDrawings={}

local function newLine() local l=Drawing.new("Line"); l.Thickness=1; l.Visible=false; return l end
local function newText(sz) local t=Drawing.new("Text"); t.Size=sz or 12; t.Outline=true; t.Visible=false; return t end
local function newRect(fill) local r=Drawing.new("Square"); r.Filled=fill or false; r.Thickness=1.5; r.Visible=false; return r end

local function createEsp(p)
    if p==player then return end
    local obj={box=newRect(),nameTag=newText(13),distTag=newText(11),healthBg=newRect(true),healthBar=newRect(true),skeleton={}}
    for _=1,#SKEL do table.insert(obj.skeleton,newLine()) end
    espObjects[p]=obj
    local it=Drawing.new("Text"); it.Size=11; it.Color=Color3.fromRGB(255,215,0); it.Outline=true; it.Visible=false
    itemDrawings[p]=it
end
local function removeEsp(p)
    local obj=espObjects[p]; if not obj then return end
    obj.box:Remove(); obj.nameTag:Remove(); obj.distTag:Remove(); obj.healthBg:Remove(); obj.healthBar:Remove()
    for _,l in ipairs(obj.skeleton) do l:Remove() end; espObjects[p]=nil
    if itemDrawings[p] then itemDrawings[p]:Remove(); itemDrawings[p]=nil end
end
for _,p in ipairs(Players:GetPlayers()) do if p~=player then createEsp(p) end end
Players.PlayerAdded:Connect(createEsp); Players.PlayerRemoving:Connect(removeEsp)

-- ══════════════════════════════════════════════════════════════
-- SILENT AIM
-- ══════════════════════════════════════════════════════════════
local cachedTargetPos=nil
local isFiring=false
UserInputService.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1 then isFiring=true
    elseif inp.UserInputType==Enum.UserInputType.Touch then
        if inp.Position.X>camera.ViewportSize.X*0.35 then isFiring=true end
    end
end)
UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1
    or inp.UserInputType==Enum.UserInputType.Touch then
        task.delay(0.08,function() isFiring=false end)
    end
end)
local function watchTool(t) if not t then return end
    t.Activated:Connect(function() isFiring=true; task.delay(0.15,function() isFiring=false end) end)
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

pcall(function()
    local oldNC
    oldNC=hookmetamethod(game,"__namecall",newcclosure(function(...)
        local method=getnamecallmethod()
        if not Config.SilentAimEnabled then return oldNC(...) end
        if checkcaller() then return oldNC(...) end
        if not cachedTargetPos then return oldNC(...) end
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
            local o=args[2].Origin; args[2]=Ray.new(o,(cachedTargetPos-o).Unit*1000)
            if Config.Manipulation and method=="FindPartOnRayWithIgnoreList" then args[3]={} end
            return oldNC(table.unpack(args))
        end
        return oldNC(...)
    end))
end)

-- ══════════════════════════════════════════════════════════════
-- RENDER STEP ÚNICO
-- ══════════════════════════════════════════════════════════════
local frame=0
RunService.RenderStepped:Connect(function()
    frame=frame+1

    -- FLY
    if Config.FlyEnabled~=flyActive then
        if Config.FlyEnabled then startFly() else stopFly() end
    end
    if Config.FlyEnabled and flyActive then
        local char=player.Character
        local root=char and char:FindFirstChild("HumanoidRootPart")
        local bp=root and root:FindFirstChild("SyyFlyBP")
        local bg=root and root:FindFirstChild("SyyFlyBG")
        if bp and bg then
            local sp=Config.FlySpeed; local camCF=camera.CFrame; local mv=Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv=mv+camCF.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv=mv-camCF.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv=mv-camCF.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv=mv+camCF.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then mv=mv+Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.E) then mv=mv-Vector3.yAxis end
            local hum2=char:FindFirstChildOfClass("Humanoid")
            if hum2 and hum2.MoveDirection.Magnitude>0.1 then
                local wf=Vector3.new(hum2.MoveDirection.X,0,hum2.MoveDirection.Z)
                if wf.Magnitude>0.01 then mv=mv+wf.Unit end
            end
            if mv.Magnitude>0 then bp.Position=bp.Position+mv.Unit*sp*0.016
            else bp.Position=root.Position end
            bg.CFrame=CFrame.new(root.Position,root.Position+camCF.LookVector)
        end
    end

    -- TARGET CACHE (cada 2 frames)
    if frame%2==0 then
        local chars={}
        for _,p in ipairs(Players:GetPlayers()) do if p~=player and p.Character then table.insert(chars,p.Character) end end
        wallbreakParams.FilterDescendantsInstances=chars

        if Config.SilentAimEnabled then
            local center=Vector2.new(camera.ViewportSize.X/2,camera.ViewportSize.Y/2)
            local bestD=math.huge; local bestPos=nil
            for _,p in ipairs(Players:GetPlayers()) do
                if p==player or isWhitelisted(p) then continue end
                local char=p.Character; if not char then continue end
                local hum=char:FindFirstChildOfClass("Humanoid")
                local root=char:FindFirstChild("HumanoidRootPart")
                if not hum or hum.Health<=0 or not root then continue end
                local sp2,onS=camera:WorldToViewportPoint(root.Position)
                if not onS then continue end
                local d2=(Vector2.new(sp2.X,sp2.Y)-center).Magnitude
                if d2>Config.FovRadius then continue end
                if Config.VisibleCheck then
                    local lc=player.Character
                    if lc then
                        local ok,obs=pcall(function() return camera:GetPartsObscuringTarget({root.Position},{lc,char}) end)
                        if ok and #obs>0 then continue end
                    end
                end
                if d2<bestD then
                    bestD=d2
                    local pn=Config.TargetPart
                    if pn=="Random" then local r=math.random(100); pn=r<=30 and "Head" or (r<=80 and "UpperTorso" or "LowerTorso") end
                    local hp2=char:FindFirstChild(pn) or root
                    bestPos=hp2.Position
                end
            end
            cachedTargetPos=bestPos
        else cachedTargetPos=nil end
    end

    local vpSize=camera.ViewportSize
    local center2D=Vector2.new(vpSize.X/2,vpSize.Y/2)
    local myChar=player.Character
    local myRoot=myChar and myChar:FindFirstChild("HumanoidRootPart")

    -- FOV
    fovCircle.Visible=Config.FovEnabled and Config.SilentAimEnabled
    if fovCircle.Visible then
        fovCircle.Position=center2D; fovCircle.Radius=Config.FovRadius
        fovCircle.Color=Color3.fromRGB(Config.FovColorR,Config.FovColorG,Config.FovColorB)
    end

    local boxCol=Color3.fromRGB(Config.BoxColorR,Config.BoxColorG,Config.BoxColorB)
    local skelCol=Color3.fromRGB(Config.SkelColorR,Config.SkelColorG,Config.SkelColorB)
    local namCol=Color3.fromRGB(Config.NameColorR,Config.NameColorG,Config.NameColorB)
    local snapCol=Color3.fromRGB(Config.SnapColorR,Config.SnapColorG,Config.SnapColorB)

    local snapTargetP=nil
    if Config.Snapline and Config.SilentAimEnabled and cachedTargetPos then
        local bestD2=math.huge
        for _,p in ipairs(Players:GetPlayers()) do
            if p==player then continue end
            local char=p.Character; if not char then continue end
            local root=char:FindFirstChild("HumanoidRootPart"); if not root then continue end
            local sp2,onS=camera:WorldToViewportPoint(root.Position)
            if onS then
                local d=(Vector2.new(sp2.X,sp2.Y)-center2D).Magnitude
                if d<bestD2 then bestD2=d; snapTargetP=p end
            end
        end
    end

    -- ESP
    for p,obj in pairs(espObjects) do
        local char=p.Character
        local function allOff()
            obj.box.Visible=false; obj.nameTag.Visible=false; obj.distTag.Visible=false
            obj.healthBar.Visible=false; obj.healthBg.Visible=false
            for _,l in ipairs(obj.skeleton) do l.Visible=false end
            if itemDrawings[p] then itemDrawings[p].Visible=false end
        end
        if not Config.EspEnabled or not char then allOff(); continue end
        local root=char:FindFirstChild("HumanoidRootPart")
        local hum=char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then allOff(); continue end
        local screenPos,onScreen=camera:WorldToViewportPoint(root.Position)
        if not onScreen then allOff(); continue end
        local dist3D=myRoot and math.floor((root.Position-myRoot.Position).Magnitude) or 0
        if dist3D>Config.EspMaxDist then allOff(); continue end
        local sp=Vector2.new(screenPos.X,screenPos.Y)
        local head=char:FindFirstChild("Head"); local foot=char:FindFirstChild("LeftFoot") or root
        local topSP,botSP
        if head and foot then
            local t=camera:WorldToViewportPoint(head.Position+Vector3.new(0,0.6,0))
            local b=camera:WorldToViewportPoint(foot.Position-Vector3.new(0,0.2,0))
            topSP=Vector2.new(t.X,t.Y); botSP=Vector2.new(b.X,b.Y)
        else topSP=sp-Vector2.new(0,50); botSP=sp+Vector2.new(0,50) end
        local boxH=math.abs(botSP.Y-topSP.Y); local boxW=boxH*0.45
        obj.box.Visible=Config.EspBox; obj.box.Color=boxCol
        if Config.EspBox then obj.box.Position=Vector2.new(sp.X-boxW/2,topSP.Y); obj.box.Size=Vector2.new(boxW,boxH) end
        obj.nameTag.Visible=Config.EspNames; obj.nameTag.Color=namCol
        if Config.EspNames then obj.nameTag.Text=p.DisplayName; obj.nameTag.Position=Vector2.new(sp.X-boxW/2,topSP.Y-16) end
        obj.distTag.Visible=Config.EspDistance; obj.distTag.Color=C_DIM
        if Config.EspDistance then obj.distTag.Text=dist3D.."m"; obj.distTag.Position=Vector2.new(sp.X-boxW/2,botSP.Y+2) end
        local hp=hum.Health/math.max(hum.MaxHealth,1)
        obj.healthBg.Visible=Config.EspHealthBar; obj.healthBar.Visible=Config.EspHealthBar
        if Config.EspHealthBar then
            local bx=sp.X-boxW/2-7
            obj.healthBg.Position=Vector2.new(bx,topSP.Y); obj.healthBg.Size=Vector2.new(4,boxH); obj.healthBg.Color=Color3.fromRGB(20,20,20)
            local barH=boxH*hp
            obj.healthBar.Position=Vector2.new(bx,topSP.Y+boxH-barH); obj.healthBar.Size=Vector2.new(4,barH)
            obj.healthBar.Color=Color3.fromRGB(math.floor(255*(1-hp)),math.floor(255*hp),0)
        end
        for si,pair in ipairs(SKEL) do
            local pA=char:FindFirstChild(pair[1]); local pB=char:FindFirstChild(pair[2])
            local line=obj.skeleton[si]; line.Color=skelCol
            if Config.EspSkeleton and pA and pB then
                local sA,onA=camera:WorldToViewportPoint(pA.Position)
                local sB,onB=camera:WorldToViewportPoint(pB.Position)
                line.Visible=onA and onB
                if onA and onB then line.From=Vector2.new(sA.X,sA.Y); line.To=Vector2.new(sB.X,sB.Y) end
            else line.Visible=false end
        end
        local itDraw=itemDrawings[p]
        if itDraw then
            local iname=Config.ItemInHand and getItemInHand(char) or nil
            if iname then
                itDraw.Text="["..iname.."]"; itDraw.Position=Vector2.new(sp.X,topSP.Y-26); itDraw.Visible=true
            else itDraw.Visible=false end
        end
        if snapTargetP==p then
            snapLineDraw.Visible=true; snapLineDraw.From=center2D; snapLineDraw.To=sp; snapLineDraw.Color=snapCol
        end
    end
    if not snapTargetP then snapLineDraw.Visible=false end
end)

print("[SYY v5.1] Loaded — "..player.Name)