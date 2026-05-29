--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║           SYY  —  SyyClient  V1                          ║
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
    -- TriggerBot: dispara solo cuando el cursor está ENCIMA de un enemigo
    TriggerBotEnabled=false,
    -- CamLock: bloquea la cámara al objetivo más cercano dentro del rango
    CamLockEnabled=false, CamLockStrength=10,
    CamLockRange=150, CamLockWallCheck=true,
    -- NPC Silent Aim
    NpcSilentAimEnabled=false, NpcTargetPart="UpperTorso",
    EspEnabled=false, EspBox=true, EspSkeleton=true, EspHealthBar=true,
    EspDistance=true, EspNames=true, EspMaxDist=500, ItemInHand=true,
    BoxColorR=0,  BoxColorG=220, BoxColorB=255,
    SkelColorR=0, SkelColorG=220,SkelColorB=255,
    NameColorR=255,NameColorG=255,NameColorB=255,
    DistColorR=70,DistColorG=160,DistColorB=210,
    ItemColorR=255,ItemColorG=215,ItemColorB=0,
    HealthLowColorR=255,HealthLowColorG=80,HealthLowColorB=80,
    HealthHighColorR=80,HealthHighColorG=255,HealthHighColorB=80,
    HealthBgColorR=20,HealthBgColorG=20,HealthBgColorB=20,
    FlyEnabled=false, FlySpeed=50, RageMode=false, InfStamina=false,
    StreamMode=false,
    TeamCheckEnabled=false,
    UniversalSAEnabled=false,
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

-- ── WHITELIST — Set O(1) para no iterar la lista entera en cada raycast ──
local wlSet = {}
local function rebuildWlSet()
    wlSet = {}
    for _,n in ipairs(Config.Whitelist) do wlSet[n:lower()]=true end
end
rebuildWlSet()

local function isWhitelisted(p)
    return wlSet[p.Name:lower()] == true
end
local function addWhitelist(name)
    if name=="" then return false end
    local nl=name:lower()
    if wlSet[nl] then return false end
    table.insert(Config.Whitelist,name); wlSet[nl]=true; saveConfig(); return true
end
local function removeWhitelist(name)
    local nl=name:lower()
    if not wlSet[nl] then return false end
    for i,n in ipairs(Config.Whitelist) do
        if n:lower()==nl then table.remove(Config.Whitelist,i); break end
    end
    wlSet[nl]=nil; saveConfig(); return true
end

-- shouldSkip: usado en TODOS los loops de aim/esp para saltar al jugador local,
-- jugadores en whitelist, y compañeros de equipo (si TeamCheck está ON).
local function shouldSkip(p)
    if p==player then return true end
    if wlSet[p.Name:lower()] then return true end
    if Config.TeamCheckEnabled and player.Team and player.Team==p.Team then return true end
    return false
end


-- ══════════════════════════════════════════════════════════════
-- GUI  —  StreamMode: oculta UI/drawings mientras grabas o transmites.
-- ══════════════════════════════════════════════════════════════

local old=playerGui:FindFirstChild("SyySystemUI"); if old then old:Destroy() end

local toggleRefreshers={}
local function refreshAllToggles()
    for _,refresh in pairs(toggleRefreshers) do pcall(refresh) end
end

local gui=Instance.new("ScreenGui")
gui.Name="SyySystemUI"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.DisplayOrder=99
gui.Parent=playerGui

local streamModeOn=false
local streamTouchToken=nil
local _streamHidden=false
local streamSaved={EspEnabled=nil,FovEnabled=nil,Snapline=nil,ItemInHand=nil}
local function applyStreamMode(on)
    on = on and true or false
    if streamModeOn == on then return end
    streamModeOn = on
    Config.StreamMode = on
    if on then
        streamSaved.EspEnabled=Config.EspEnabled
        streamSaved.FovEnabled=Config.FovEnabled
        streamSaved.Snapline=Config.Snapline
        streamSaved.ItemInHand=Config.ItemInHand
        Config.EspEnabled=false
        Config.FovEnabled=false
        Config.Snapline=false
        Config.ItemInHand=false
        gui.Enabled=false
    else
        if streamSaved.EspEnabled~=nil then Config.EspEnabled=streamSaved.EspEnabled end
        if streamSaved.FovEnabled~=nil then Config.FovEnabled=streamSaved.FovEnabled end
        if streamSaved.Snapline~=nil then Config.Snapline=streamSaved.Snapline end
        if streamSaved.ItemInHand~=nil then Config.ItemInHand=streamSaved.ItemInHand end
        gui.Enabled=true
    end
    refreshAllToggles()
    saveConfig()
end

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
local vp = camera.ViewportSize
local panelW = isMobile and math.min(math.floor(vp.X * 0.82), 380) or 314
local panelH = isMobile and math.min(math.floor(vp.Y * 0.72), 500) or 480

local main=Instance.new("Frame")
main.Name="SyyPanel"
main.Size=UDim2.fromOffset(panelW,panelH)
if isMobile then
    main.Position=UDim2.new(0.5,-panelW/2,0,math.floor(vp.Y*0.08))
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

-- logo image — con fallback a texto si el asset no está subido
local logoSize = isMobile and 38 or 34
local logoImg=Instance.new("ImageLabel")
logoImg.Size=UDim2.fromOffset(logoSize,logoSize)
logoImg.Position=UDim2.new(0,6,0.5,-(logoSize/2))
logoImg.BackgroundTransparency=1
logoImg.Image="rbxassetid://77130965021335"
logoImg.ScaleType=Enum.ScaleType.Fit
logoImg.ImageTransparency=0
logoImg.Parent=header
-- fallback: si la imagen no carga en 2s, muestra "⬡"
task.delay(2, function()
    if logoImg and logoImg.IsLoaded == false then
        logoImg.Image=""
        local fallLbl=Instance.new("TextLabel")
        fallLbl.Size=UDim2.fromOffset(logoSize,logoSize)
        fallLbl.Position=logoImg.Position
        fallLbl.BackgroundTransparency=1
        fallLbl.Text="⬡"; fallLbl.TextColor3=C_ACCENT
        fallLbl.Font=Enum.Font.GothamBlack
        fallLbl.TextSize=logoSize-4
        fallLbl.TextXAlignment=Enum.TextXAlignment.Center
        fallLbl.Parent=header
    end
end)

local titleLbl=Instance.new("TextLabel")
titleLbl.Size=UDim2.new(1,-110,0,isMobile and 26 or 24)
titleLbl.Position=UDim2.fromOffset(logoSize+10, isMobile and 6 or 4)
titleLbl.BackgroundTransparency=1; titleLbl.Text="SYY V1"
titleLbl.TextColor3=C_ACCENT; titleLbl.Font=Enum.Font.GothamBlack
titleLbl.TextSize=isMobile and 20 or 18
titleLbl.TextXAlignment=Enum.TextXAlignment.Left; titleLbl.Parent=header

local subLbl=Instance.new("TextLabel")
subLbl.Size=UDim2.new(1,-110,0,13)
subLbl.Position=UDim2.fromOffset(logoSize+10, isMobile and 22 or 27)
subLbl.BackgroundTransparency=1; subLbl.Text="V1  ·  EnanoTop1 (stx)  ·  "..player.Name
subLbl.TextColor3=C_DIM; subLbl.Font=Enum.Font.GothamMedium
subLbl.TextSize=isMobile and 10 or 9
subLbl.TextXAlignment=Enum.TextXAlignment.Left; subLbl.Parent=header

-- Instagram interactivo: toca para copiar @itzstxx al portapapeles
local igBtn=Instance.new("TextButton")
igBtn.Size=UDim2.new(0,isMobile and 110 or 90,0,isMobile and 14 or 11)
igBtn.Position=UDim2.fromOffset(logoSize+10, isMobile and 37 or 31)
igBtn.BackgroundTransparency=1; igBtn.BorderSizePixel=0
igBtn.Text="📷 @itzstxx"; igBtn.TextColor3=Color3.fromRGB(200,140,255)
igBtn.Font=Enum.Font.GothamBold; igBtn.TextSize=isMobile and 10 or 9
igBtn.TextXAlignment=Enum.TextXAlignment.Left
igBtn.AutoButtonColor=false; igBtn.Parent=header
local igCopied=false
igBtn.MouseButton1Click:Connect(function()
    if igCopied then return end; igCopied=true
    pcall(function() setclipboard("@itzstxx") end)
    igBtn.Text="✅ Copiado!"; igBtn.TextColor3=Color3.fromRGB(80,255,140)
    task.delay(1.8,function() igBtn.Text="📷 @itzstxx"; igBtn.TextColor3=Color3.fromRGB(200,140,255); igCopied=false end)
end)
igBtn.MouseEnter:Connect(function() if not igCopied then igBtn.TextColor3=Color3.fromRGB(255,180,255) end end)
igBtn.MouseLeave:Connect(function() if not igCopied then igBtn.TextColor3=Color3.fromRGB(200,140,255) end end)

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

-- ── SLIDER INPUT GLOBAL — UN SOLO InputChanged para todos los sliders ──
-- Antes: cada slider creaba su propio .InputChanged → 15+ conexiones disparando
-- cada movimiento del dedo. Ahora: una sola conexión global O(1).
local _activeSlide = nil  -- función activa mientras se arrastra
UserInputService.InputChanged:Connect(function(inp)
    if _activeSlide and (inp.UserInputType==Enum.UserInputType.MouseMovement
    or inp.UserInputType==Enum.UserInputType.Touch) then
        _activeSlide(inp)
    end
end)
UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1
    or inp.UserInputType==Enum.UserInputType.Touch then
        if _activeSlide then _activeSlide=nil end
    end
end)

local function makeSection(page,text)
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
    toggleRefreshers[key]=refresh

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
        or inp.UserInputType==Enum.UserInputType.Touch then sliding=true; _activeSlide=slide; slide(inp) end
    end)
    -- InputChanged y InputEnded manejados por el dispatcher global
    -- (se limpia _activeSlide en el InputEnded global, y llama saveConfig)
    local _origActive=nil
    track.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch then
            _origActive=_activeSlide
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if sliding and (inp.UserInputType==Enum.UserInputType.MouseButton1
        or inp.UserInputType==Enum.UserInputType.Touch) then
            sliding=false; _activeSlide=nil; saveConfig()
        end
    end)
    return row
end

local function makeColorRow(page,text,rk,gk,bk)
    local open=false
    local container=Instance.new("Frame")
    container.Size=UDim2.new(1,0,0,ROW_H); container.BackgroundTransparency=1
    container.BorderSizePixel=0; container.ClipsDescendants=true; container.Parent=page
    local lay2=Instance.new("UIListLayout"); lay2.SortOrder=Enum.SortOrder.LayoutOrder
    lay2.Padding=UDim.new(0,1); lay2.Parent=container

    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,ROW_H); row.BackgroundColor3=C_ROW
    row.BorderSizePixel=0; row.Parent=container
    stroke(row,Color3.fromRGB(0,60,90),1)

    local previewSz = isMobile and 28 or 22
    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-(previewSz+42),1,0); lbl.Position=UDim2.fromOffset(8,0)
    lbl.BackgroundTransparency=1; lbl.Text=text
    lbl.TextColor3=C_TEXT; lbl.Font=Enum.Font.GothamMedium
    lbl.TextSize=TXT_SIZE; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=row

    local arr=Instance.new("TextLabel")
    arr.Size=UDim2.fromOffset(16,ROW_H); arr.Position=UDim2.new(1,-(previewSz+26),0,0)
    arr.BackgroundTransparency=1; arr.Text="▾"; arr.TextColor3=C_ACCENT
    arr.Font=Enum.Font.GothamBold; arr.TextSize=TXT_SIZE; arr.Parent=row

    local prev=Instance.new("TextButton")
    prev.Size=UDim2.fromOffset(previewSz,previewSz)
    prev.Position=UDim2.new(1,-(previewSz+6),0.5,-(previewSz/2))
    prev.BorderSizePixel=0; prev.Text=""; prev.AutoButtonColor=false; prev.Parent=row
    stroke(prev,C_ACCENT,1)

    local function color()
        return Color3.fromRGB(Config[rk],Config[gk],Config[bk])
    end
    local function refreshPreview()
        TweenService:Create(prev,TWEENI,{BackgroundColor3=color()}):Play()
    end
    prev.BackgroundColor3=color()

    local function makeRgbSlider(label,key)
        local sr=Instance.new("Frame")
        sr.Size=UDim2.new(1,0,0,ROW_H); sr.BackgroundColor3=C_ROW
        sr.BorderSizePixel=0; sr.Parent=container
        stroke(sr,Color3.fromRGB(0,50,80),1)

        local sl=Instance.new("TextLabel")
        sl.Size=UDim2.new(0,56,1,0); sl.Position=UDim2.fromOffset(8,0)
        sl.BackgroundTransparency=1; sl.TextColor3=C_TEXT; sl.Font=Enum.Font.GothamMedium
        sl.TextSize=TXT_SIZE; sl.TextXAlignment=Enum.TextXAlignment.Left; sl.Parent=sr

        local trackH2 = isMobile and 9 or 6
        local track=Instance.new("Frame")
        track.Size=UDim2.new(1,-76,0,trackH2)
        track.Position=UDim2.new(0,66,0.5,-(trackH2/2))
        track.BackgroundColor3=Color3.fromRGB(20,35,50); track.BorderSizePixel=0; track.Parent=sr
        local fill=Instance.new("Frame")
        fill.Size=UDim2.new(0,0,1,0); fill.BackgroundColor3=C_ACCENT
        fill.BorderSizePixel=0; fill.Parent=track

        local function setVal(v)
            v=math.clamp(math.floor(v),0,255)
            Config[key]=v
            sl.Text=label..": "..v
            fill.Size=UDim2.new(v/255,0,1,0)
            refreshPreview()
        end
        setVal(Config[key])

        -- Botón invisible encima del track — funciona en móvil sin que ScrollingFrame robe el touch
        local hitT=Instance.new("TextButton")
        hitT.Size=UDim2.new(1,-76,1,0); hitT.Position=UDim2.new(0,66,0,0)
        hitT.BackgroundTransparency=1; hitT.Text=""; hitT.ZIndex=5; hitT.Parent=sr

        local sliding=false
        local function slide(inp)
            local abs=track.AbsolutePosition; local sz=track.AbsoluteSize
            if sz.X<=0 then return end
            setVal(math.clamp((inp.Position.X-abs.X)/sz.X,0,1)*255)
        end
        hitT.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1
            or inp.UserInputType==Enum.UserInputType.Touch then sliding=true; _activeSlide=slide; slide(inp) end
        end)
        UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1
            or inp.UserInputType==Enum.UserInputType.Touch then
                if sliding then sliding=false; _activeSlide=nil; saveConfig() end
            end
        end)
    end

    makeRgbSlider("R",rk)
    makeRgbSlider("G",gk)
    makeRgbSlider("B",bk)

    local function toggleOpen()
        open=not open
        arr.Text=open and "▴" or "▾"
        container.Size=UDim2.new(1,0,0,open and (ROW_H*4+3) or ROW_H)
    end

    local hitbox=Instance.new("TextButton")
    hitbox.Size=UDim2.new(1,-(previewSz+32),1,0); hitbox.BackgroundTransparency=1
    hitbox.Text=""; hitbox.Parent=row
    hitbox.MouseButton1Click:Connect(toggleOpen)

    local presets={{0,190,255},{255,80,80},{80,255,80},{255,215,0},{255,140,0},{200,80,255},{255,255,255},{0,255,200}}
    local ci=1
    prev.MouseButton1Click:Connect(function()
        ci=ci%#presets+1
        Config[rk]=presets[ci][1]; Config[gk]=presets[ci][2]; Config[bk]=presets[ci][3]
        refreshPreview()
        saveConfig()
    end)
    return container
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
makeDropdown(pageAim,"Target Part",    "TargetPart",{"Head","UpperTorso","LowerTorso","Pierna","Pecho","Combo","Random"})
secLabel(pageAim,"Trigger Bot")
makeToggle(pageAim,"TriggerBot",       "TriggerBotEnabled")
secLabel(pageAim,"Cam Lock")
makeToggle(pageAim,"Cam Lock",         "CamLockEnabled")
makeSlider(pageAim,"CamLock Fuerza",   "CamLockStrength",1,20)
makeSlider(pageAim,"Rango Detección",  "CamLockRange",10,600)
makeToggle(pageAim,"Wall Check",       "CamLockWallCheck")
secLabel(pageAim,"NPC Silent Aim")
makeToggle(pageAim,"NPC Silent Aim",   "NpcSilentAimEnabled")
makeDropdown(pageAim,"NPC Part",       "NpcTargetPart",{"Head","UpperTorso","LowerTorso","HumanoidRootPart"})
secLabel(pageAim,"General")
makeToggle(pageAim,"Team Check",       "TeamCheckEnabled")
secLabel(pageAim,"Universal Silent Aim")
makeToggle(pageAim,"Universal SA",     "UniversalSAEnabled")

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
local rageSaved=nil
makeToggle(pageExt,"🔴 Rage Mode","RageMode",function(on)
    if on then
        rageSaved={
            SilentAimEnabled=Config.SilentAimEnabled,HitChance=Config.HitChance,
            FovRadius=Config.FovRadius,VisibleCheck=Config.VisibleCheck,
            Manipulation=Config.Manipulation,TargetPart=Config.TargetPart,
        }
        Config.SilentAimEnabled=true; Config.HitChance=100
        Config.FovRadius=999; Config.VisibleCheck=false
        Config.Manipulation=true; Config.TargetPart="Head"
        saveConfig()
        refreshAllToggles()
    else
        if rageSaved then
            for k,v in pairs(rageSaved) do Config[k]=v end
            rageSaved=nil; saveConfig(); refreshAllToggles()
        end
    end
end)
secLabel(pageExt,"Fly")
makeToggle(pageExt,"Fly Enabled","FlyEnabled")
makeSlider(pageExt,"Velocidad Fly","FlySpeed",10,200)

-- ── INF STAMINA ──────────────────────────────────────────────
secLabel(pageExt,"Stamina")

local staminaConns = {}
local staminaWatched = {}
local staminaKeys = {"stamina","sprint","energy","endur","breath"}
local staminaLoop  = false   -- controla el loop rápido

local function isStaminaName(name)
    name = tostring(name or ""):lower()
    for _, key in ipairs(staminaKeys) do
        if name:find(key, 1, true) then return true end
    end
    return false
end

local function hasStaminaContext(obj)
    local cur = obj
    for _ = 1, 4 do
        if not cur or typeof(cur) ~= "Instance" then break end
        if isStaminaName(cur.Name) then return true end
        cur = cur.Parent
    end
    return false
end

local function isStaminaValue(obj)
    return obj and typeof(obj) == "Instance"
        and (obj:IsA("NumberValue") or obj:IsA("IntValue") or obj:IsA("DoubleConstrainedValue"))
        and hasStaminaContext(obj)
end

local function staminaMax(stVal)
    if stVal:IsA("DoubleConstrainedValue") then
        return stVal.MaxValue
    end
    return stVal:GetAttribute("MaxStamina")
        or stVal:GetAttribute("StaminaMax")
        or stVal:GetAttribute("MaxSprint")
        or stVal:GetAttribute("SprintMax")
        or stVal:GetAttribute("MaxEnergy")
        or stVal:GetAttribute("EnergyMax")
        or stVal:GetAttribute("Max")
        or 100
end

local function keepStaminaFull(stVal)
    if not isStaminaValue(stVal) then return end
    pcall(function()
        stVal.Value = staminaMax(stVal)
    end)
end

local function watchStaminaValue(stVal)
    if not isStaminaValue(stVal) or staminaWatched[stVal] then return end
    staminaWatched[stVal] = true
    keepStaminaFull(stVal)
    table.insert(staminaConns, stVal.Changed:Connect(function()
        keepStaminaFull(stVal)
    end))
end

local function keepStaminaAttributes(obj)
    if not obj or typeof(obj) ~= "Instance" then return end
    pcall(function()
        for attr, val in pairs(obj:GetAttributes()) do
            local attrLower = tostring(attr):lower()
            if type(val) == "number" and (isStaminaName(attr) or (hasStaminaContext(obj) and attrLower == "value")) and not attrLower:find("max", 1, true) then
                local maxVal = obj:GetAttribute("Max"..attr)
                    or obj:GetAttribute(attr.."Max")
                    or obj:GetAttribute("MaxStamina")
                    or obj:GetAttribute("StaminaMax")
                    or 100
                obj:SetAttribute(attr, maxVal)
            end
        end
    end)
end

local function watchStaminaAttributes(obj)
    if not obj or typeof(obj) ~= "Instance" then return end
    keepStaminaAttributes(obj)
    pcall(function()
        for attr, val in pairs(obj:GetAttributes()) do
            local attrLower = tostring(attr):lower()
            if type(val) == "number" and (isStaminaName(attr) or (hasStaminaContext(obj) and attrLower == "value")) and not attrLower:find("max", 1, true) then
                table.insert(staminaConns, obj:GetAttributeChangedSignal(attr):Connect(function()
                    keepStaminaAttributes(obj)
                end))
            end
        end
    end)
end

local function scanStamina(container)
    if not container then return end
    watchStaminaValue(container)
    watchStaminaAttributes(container)
    pcall(function()
        for _, desc in ipairs(container:GetDescendants()) do
            watchStaminaValue(desc)
            if desc:IsA("Humanoid") or isStaminaName(desc.Name) then
                watchStaminaAttributes(desc)
            end
        end
    end)
end

local function watchStaminaContainer(container)
    if not container then return end
    scanStamina(container)
    table.insert(staminaConns, container.DescendantAdded:Connect(function(desc)
        watchStaminaValue(desc)
        if desc:IsA("Humanoid") or isStaminaName(desc.Name) then
            watchStaminaAttributes(desc)
        end
    end))
end

local staminaMetaHooked = false
local function installStaminaMetaHook()
    if staminaMetaHooked then return end
    staminaMetaHooked = true
    pcall(function()
        if not hookmetamethod then return end
        local oldNewIndex
        oldNewIndex = hookmetamethod(game, "__newindex", function(self, key, value)
            if Config.InfStamina and key == "Value" and type(value) == "number" and isStaminaValue(self) then
                local maxVal = staminaMax(self)
                if value < maxVal then
                    return oldNewIndex(self, key, maxVal)
                end
            end
            return oldNewIndex(self, key, value)
        end)
    end)
end

local function disconnectStamina()
    staminaLoop = false
    for _, c in ipairs(staminaConns) do pcall(function() c:Disconnect() end) end
    staminaConns = {}
    staminaWatched = {}
end

local function hookStamina(char)
    if not char then return end
    installStaminaMetaHook()
    staminaLoop = true
    watchStaminaContainer(char)
    watchStaminaContainer(player)

    -- ── LOOP RÁPIDO (0.01s) ─────────────────────────────────
    -- Esto cubre el caso donde el juego baja la stamina mientras corres.
    -- El .Changed llega DESPUÉS de que ya bajó; el loop la sube antes de que
    -- el servidor la vuelva a bajar en el siguiente frame.
    task.spawn(function()
        while staminaLoop and Config.InfStamina do
            pcall(function()
                local c2 = player.Character
                if not c2 then return end

                -- PlaceId 455366377 — tiene el objeto "Stamina" directo en el char
                if game.PlaceId == 455366377 then
                    watchStaminaValue(c2:FindFirstChild("Stamina", true))
                end

                -- Genérico — busca cualquier valor de stamina/sprint/energy
                for stVal in pairs(staminaWatched) do
                    keepStaminaFull(stVal)
                end
                -- Atributos Humanoid
                local hum = c2:FindFirstChildOfClass("Humanoid")
                if hum then
                    keepStaminaAttributes(hum)
                end
                keepStaminaAttributes(c2)
            end)
            task.wait(0.05)  -- antes 0.01 (100/s) → ahora 20/s, indetectable
        end
    end)

    -- ── HOOK .Changed (respaldo instantáneo) ────────────────
    if game.PlaceId == 455366377 then
        local stVal = char:WaitForChild("Stamina", 4)
        watchStaminaValue(stVal)
        table.insert(staminaConns, char.ChildAdded:Connect(function(child)
            if child.Name == "Stamina" then
                watchStaminaValue(child)
            end
        end))
    end
end

makeToggle(pageExt,"♾ Inf Stamina","InfStamina",function(on)
    if on then
        hookStamina(player.Character)
    else
        disconnectStamina()
    end
end)

-- re-hookear al respawnear
player.CharacterAdded:Connect(function(char)
    if not Config.InfStamina then return end
    disconnectStamina()
    task.wait(0.5)
    hookStamina(char)
end)

task.defer(function()
    if Config.InfStamina then
        hookStamina(player.Character or player.CharacterAdded:Wait())
    end
end)

-- ══════════════════════════════════════════════════════════════
-- TAB 4: SETTINGS
-- ══════════════════════════════════════════════════════════════
local pageSet=tabPages[4]

-- ── STREAM MODE ─────────────────────────────────────────────
secLabel(pageSet,"🎥 Stream / Discord")
makeToggle(pageSet,"📵 Stream Mode","StreamMode",function(on)
    applyStreamMode(on)
end)
-- Indicador visual de estado
do
    local infoRow=Instance.new("Frame")
    infoRow.Size=UDim2.new(1,0,0,ROW_H); infoRow.BackgroundColor3=C_ROW
    infoRow.BorderSizePixel=0; infoRow.Parent=pageSet
    stroke(infoRow,Color3.fromRGB(0,60,90),1)
    local infoLbl=Instance.new("TextLabel")
    infoLbl.Size=UDim2.new(1,-8,1,0); infoLbl.Position=UDim2.fromOffset(8,0)
    infoLbl.BackgroundTransparency=1; infoLbl.TextWrapped=true
    infoLbl.Text="ON → oculta GUI/ESP/FOV/Snapline. En móvil mantén cualquier esquina 2s para volver."
    infoLbl.TextColor3=C_DIM; infoLbl.Font=Enum.Font.GothamMedium
    infoLbl.TextSize=isMobile and 10 or 9
    infoLbl.TextXAlignment=Enum.TextXAlignment.Left; infoLbl.Parent=infoRow
end

secLabel(pageSet,"🔒 Whitelist")
do
    local WL_ENTRY_H = isMobile and 34 or 26

    -- ── Fila: "Jugadores en servidor" + botón Refresh ────────────
    local headerRow=Instance.new("Frame")
    headerRow.Size=UDim2.new(1,0,0,WL_ENTRY_H); headerRow.BackgroundColor3=C_ROW
    headerRow.BorderSizePixel=0; headerRow.Parent=pageSet
    stroke(headerRow,Color3.fromRGB(0,60,90),1)
    local hdrLbl=Instance.new("TextLabel")
    hdrLbl.Size=UDim2.new(1,-84,1,0); hdrLbl.Position=UDim2.fromOffset(8,0)
    hdrLbl.BackgroundTransparency=1; hdrLbl.Text="Jugadores en servidor"
    hdrLbl.TextColor3=C_DIM; hdrLbl.Font=Enum.Font.GothamMedium
    hdrLbl.TextSize=TXT_SIZE; hdrLbl.TextXAlignment=Enum.TextXAlignment.Left; hdrLbl.Parent=headerRow
    local rfW=isMobile and 74 or 64
    local refreshBtn=Instance.new("TextButton")
    refreshBtn.Size=UDim2.fromOffset(rfW,isMobile and 26 or 20)
    refreshBtn.Position=UDim2.new(1,-(rfW+4),0.5,-(isMobile and 13 or 10))
    refreshBtn.BackgroundColor3=Color3.fromRGB(0,30,50); refreshBtn.BorderSizePixel=0
    refreshBtn.Text="🔄 Refresh"; refreshBtn.TextColor3=C_ACCENT
    refreshBtn.Font=Enum.Font.GothamBold; refreshBtn.TextSize=isMobile and 10 or 9
    refreshBtn.AutoButtonColor=false; refreshBtn.Parent=headerRow
    stroke(refreshBtn,C_ACCENT,1)

    -- ── Lista de jugadores del servidor ──────────────────────────
    local serverListFrame=Instance.new("Frame")
    serverListFrame.Size=UDim2.new(1,0,0,0); serverListFrame.BackgroundTransparency=1
    serverListFrame.AutomaticSize=Enum.AutomaticSize.Y; serverListFrame.Parent=pageSet
    local slLay=Instance.new("UIListLayout"); slLay.SortOrder=Enum.SortOrder.LayoutOrder
    slLay.Padding=UDim.new(0,2); slLay.Parent=serverListFrame

    -- ── Whitelist guardada ───────────────────────────────────────
    secLabel(pageSet,"En Whitelist")
    local wlFrame=Instance.new("Frame")
    wlFrame.Size=UDim2.new(1,0,0,0); wlFrame.BackgroundTransparency=1
    wlFrame.AutomaticSize=Enum.AutomaticSize.Y; wlFrame.Parent=pageSet
    local wlLay=Instance.new("UIListLayout"); wlLay.SortOrder=Enum.SortOrder.LayoutOrder
    wlLay.Padding=UDim.new(0,2); wlLay.Parent=wlFrame

    -- Forward declarations para que rebuildWL y rebuildServerList se llamen mutuamente
    local rebuildWL, rebuildServerList

    rebuildWL = function()
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
            local dbSz=isMobile and 28 or 24
            local db=Instance.new("TextButton")
            db.Size=UDim2.fromOffset(dbSz,isMobile and 24 or 18)
            db.Position=UDim2.new(1,-(dbSz+4),0.5,-(isMobile and 12 or 9))
            db.BackgroundColor3=Color3.fromRGB(40,8,8); db.BorderSizePixel=0
            db.Text="✕"; db.TextColor3=Color3.fromRGB(255,80,80)
            db.Font=Enum.Font.GothamBold; db.TextSize=isMobile and 11 or 9
            db.AutoButtonColor=false; db.Parent=e
            stroke(db,Color3.fromRGB(100,20,20),1)
            db.MouseButton1Click:Connect(function()
                removeWhitelist(name); rebuildWL(); rebuildServerList()
            end)
        end
    end

    rebuildServerList = function()
        for _,c in ipairs(serverListFrame:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        for _,p in ipairs(Players:GetPlayers()) do
            if p==player then continue end
            local e=Instance.new("Frame")
            e.Size=UDim2.new(1,0,0,WL_ENTRY_H); e.BackgroundColor3=C_ROW
            e.BorderSizePixel=0; e.Parent=serverListFrame; stroke(e,Color3.fromRGB(0,60,90),1)
            local namLbl=Instance.new("TextLabel")
            namLbl.Size=UDim2.new(1,-90,1,0); namLbl.Position=UDim2.fromOffset(6,0)
            namLbl.BackgroundTransparency=1; namLbl.Text=p.Name
            namLbl.TextColor3=C_TEXT; namLbl.Font=Enum.Font.GothamMedium
            namLbl.TextSize=TXT_SIZE; namLbl.TextXAlignment=Enum.TextXAlignment.Left; namLbl.Parent=e
            local togW=isMobile and 76 or 66
            local togBtn=Instance.new("TextButton")
            togBtn.Size=UDim2.fromOffset(togW,isMobile and 26 or 20)
            togBtn.Position=UDim2.new(1,-(togW+4),0.5,-(isMobile and 13 or 10))
            togBtn.BorderSizePixel=0; togBtn.AutoButtonColor=false; togBtn.Parent=e
            togBtn.Font=Enum.Font.GothamBold; togBtn.TextSize=isMobile and 10 or 9
            local function refreshTogBtn()
                if isWhitelisted(p) then
                    togBtn.BackgroundColor3=Color3.fromRGB(40,8,8)
                    togBtn.TextColor3=Color3.fromRGB(255,80,80); togBtn.Text="✕ Quitar"
                    stroke(togBtn,Color3.fromRGB(100,20,20),1)
                else
                    togBtn.BackgroundColor3=Color3.fromRGB(0,30,50)
                    togBtn.TextColor3=C_ACCENT; togBtn.Text="+ Añadir"
                    stroke(togBtn,C_ACCENT,1)
                end
            end
            refreshTogBtn()
            togBtn.MouseButton1Click:Connect(function()
                if isWhitelisted(p) then removeWhitelist(p.Name) else addWhitelist(p.Name) end
                refreshTogBtn(); rebuildWL()
            end)
        end
    end

    rebuildServerList(); rebuildWL()

    refreshBtn.MouseButton1Click:Connect(function()
        rebuildServerList()
        refreshBtn.Text="✅"; task.delay(0.8,function() refreshBtn.Text="🔄 Refresh" end)
    end)
    -- Auto-actualizar al entrar/salir jugadores del servidor
    Players.PlayerAdded:Connect(function() rebuildServerList() end)
    Players.PlayerRemoving:Connect(function() task.wait(0.05); rebuildServerList() end)
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
        Config=deepCopy(DefaultConfig); saveConfig(); rebuildWlSet()
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
local fab=Instance.new("ImageButton")
fab.Name="SyyFAB"; fab.Size=UDim2.fromOffset(fabSz,fabSz)
fab.Position= isMobile
    and UDim2.new(1,-(fabSz+14),1,-(fabSz+40))
    or  UDim2.new(1,-(fabSz+12),0.5,-(fabSz/2))
fab.BackgroundColor3=C_DARK; fab.BorderSizePixel=0
fab.AutoButtonColor=false
fab.Image="rbxassetid://77130965021335"
fab.ScaleType=Enum.ScaleType.Fit
fab.ZIndex=20; fab.Parent=gui
stroke(fab,C_ACCENT,2)
-- fallback texto si no carga imagen
task.delay(2, function()
    if fab and fab.IsLoaded == false then
        fab.Image=""
        local ftxt=Instance.new("TextLabel")
        ftxt.Size=UDim2.new(1,0,1,0); ftxt.BackgroundTransparency=1
        ftxt.Text="SYY"; ftxt.TextColor3=C_ACCENT
        ftxt.Font=Enum.Font.GothamBlack; ftxt.TextSize=isMobile and 14 or 11
        ftxt.ZIndex=21; ftxt.Parent=fab
    end
end)

-- pulse animation on FAB — un solo tween almacenado, no crea nuevos cada 0.9s
do
    local fabStroke=fab:FindFirstChildOfClass("UIStroke")
    if fabStroke then
        local pulseOut=TweenService:Create(fabStroke,TweenInfo.new(0.9,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,0,true,0),{Transparency=0.65})
        local function pulseTick()
            pulseOut:Play()
        end
        task.spawn(function()
            while fab.Parent do pulseTick(); task.wait(1.85) end
        end)
    end
end

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
                    refreshAllToggles()
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
    if inp.UserInputType==Enum.UserInputType.Touch and streamModeOn then
        local vp=camera.ViewportSize
        local x,y=inp.Position.X,inp.Position.Y
        local corner=(x<=90 and y<=90) or (x>=vp.X-90 and y<=90)
            or (x<=90 and y>=vp.Y-90) or (x>=vp.X-90 and y>=vp.Y-90)
        if not corner then return end
        local token=os.clock()
        streamTouchToken=token
        task.delay(2,function()
            if streamTouchToken==token and streamModeOn then applyStreamMode(false) end
        end)
        return
    end
    if proc then return end
    if inp.KeyCode==Enum.KeyCode.RightAlt then
        applyStreamMode(not streamModeOn)
        return
    end
    if inp.KeyCode==Enum.KeyCode.RightShift then
        if streamModeOn then return end
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
        refreshAllToggles()
    end
end)

UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.Touch then
        streamTouchToken=nil
    end
end)

-- ══════════════════════════════════════════════════════════════
-- SCANLINE ANIM — un solo tween repetido, no crea objetos cada 1.4s
-- ══════════════════════════════════════════════════════════════
do
    local scanTween=TweenService:Create(scanLine,
        TweenInfo.new(1.5,Enum.EasingStyle.Linear,Enum.EasingDirection.Out,0,false,0),
        {Position=UDim2.fromOffset(0,panelH),BackgroundTransparency=0.92})
    local function restartScan()
        scanLine.Position=UDim2.fromOffset(0,0)
        scanLine.BackgroundTransparency=0.5
        scanTween:Play()
    end
    scanTween.Completed:Connect(restartScan)
    restartScan()
end

-- ══════════════════════════════════════════════════════════════
-- FLY  (LinearVelocity + AlignOrientation — no kickea)
-- ══════════════════════════════════════════════════════════════
local flyActive=false
local function stopFly()
    flyActive=false
    local char=player.Character; if not char then return end
    local hum=char:FindFirstChildOfClass("Humanoid")
    local root=char:FindFirstChild("HumanoidRootPart")
    if hum then hum.PlatformStand=false end
    if root then
        for _,name in ipairs({"SyyFlyLV","SyyFlyAO","SyyFlyAtt"}) do
            local obj=root:FindFirstChild(name); if obj then obj:Destroy() end
        end
        -- limpiar también los legacy por si quedan
        for _,name in ipairs({"SyyFlyBP","SyyFlyBG"}) do
            local obj=root:FindFirstChild(name); if obj then obj:Destroy() end
        end
    end
end
local function startFly()
    flyActive=true
    local char=player.Character; if not char then return end
    local hum=char:FindFirstChildOfClass("Humanoid")
    local root=char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end
    hum.PlatformStand=true
    -- Attachment raíz
    if not root:FindFirstChild("SyyFlyAtt") then
        local att=Instance.new("Attachment"); att.Name="SyyFlyAtt"; att.Parent=root
    end
    local att=root:FindFirstChild("SyyFlyAtt")
    -- LinearVelocity (no genera detección de velocidad anormal como BodyPosition)
    if not root:FindFirstChild("SyyFlyLV") then
        local lv=Instance.new("LinearVelocity"); lv.Name="SyyFlyLV"
        lv.Attachment0=att
        lv.MaxForce=math.huge
        lv.VectorVelocity=Vector3.zero
        lv.RelativeTo=Enum.ActuatorRelativeTo.World
        lv.Parent=root
    end
    -- AlignOrientation para mantener upright
    if not root:FindFirstChild("SyyFlyAO") then
        local ao=Instance.new("AlignOrientation"); ao.Name="SyyFlyAO"
        ao.Attachment0=att
        ao.MaxTorque=math.huge; ao.MaxAngularVelocity=math.huge
        ao.Responsiveness=50
        ao.CFrame=root.CFrame
        ao.Parent=root
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
local cachedNpcPos=nil       -- NPC silent aim
local npcSilentVisible=true  -- true=visible, false=detrás de pared (FOV rojo)

-- ── Cache de NPCs: se refresca cada 90 frames (no más GetDescendants cada frame) ──
local cachedNpcHumanoids={}
local npcCacheFrame=0
local function rebuildNpcCache()
    local tbl={}
    for _,obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Humanoid") then
            local isPlayer=false
            for _,pl in ipairs(Players:GetPlayers()) do
                if pl.Character==obj.Parent then isPlayer=true; break end
            end
            if not isPlayer then table.insert(tbl,obj) end
        end
    end
    cachedNpcHumanoids=tbl
end
rebuildNpcCache()
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

        -- ── UNIVERSAL SILENT AIM: FireServer / InvokeServer ──────────
        -- En stream mode se salta (no queremos intervenir remotes), pero
        -- el raycast silent aim sigue activo siempre.
        if Config.UniversalSAEnabled and not checkcaller() and not streamModeOn
           and (method=="FireServer" or method=="InvokeServer") then
            local usePos2=nil
            if Config.SilentAimEnabled and cachedTargetPos then usePos2=cachedTargetPos end
            if Config.NpcSilentAimEnabled and cachedNpcPos and not usePos2 then usePos2=cachedNpcPos end
            if usePos2 and math.random(100)<=Config.HitChance then
                local args={...}
                local myC=player.Character
                local myR=myC and myC:FindFirstChild("HumanoidRootPart")
                local replaced=false
                for i=2,math.min(#args,8) do
                    if typeof(args[i])=="Vector3" then
                        local v=args[i]
                        -- Saltar vectores dirección (magnitud ~1) y vectores nulos
                        if v.Magnitude>2 then
                            if myR then
                                local d=(v-myR.Position).Magnitude
                                if d>5 and d<2000 then args[i]=usePos2; replaced=true end
                            end
                        end
                    end
                end
                if replaced then return oldNC(table.unpack(args)) end
            end
        end

        -- ── RAYCAST SILENT AIM ───────────────────────────────────────
        local usePos=nil
        if Config.SilentAimEnabled and cachedTargetPos then usePos=cachedTargetPos end
        if Config.NpcSilentAimEnabled and cachedNpcPos and not usePos then usePos=cachedNpcPos end
        if not usePos then return oldNC(...) end
        if checkcaller() then return oldNC(...) end
        if math.random(100)>Config.HitChance then return oldNC(...) end
        local args={...}
        if args[1]~=Workspace then return oldNC(...) end
        if method=="Raycast" then
            if typeof(args[2])~="Vector3" or typeof(args[3])~="Vector3" then return oldNC(...) end
            args[3]=(usePos-args[2]).Unit*1000
            if Config.Manipulation then args[4]=wallbreakParams end
            return oldNC(table.unpack(args))
        elseif method=="FindPartOnRayWithIgnoreList" or method=="FindPartOnRay" then
            if typeof(args[2])~="Ray" then return oldNC(...) end
            local o=args[2].Origin; args[2]=Ray.new(o,(usePos-o).Unit*1000)
            if Config.Manipulation and method=="FindPartOnRayWithIgnoreList" then args[3]={} end
            return oldNC(table.unpack(args))
        end
        return oldNC(...)
    end))
end)

-- ══════════════════════════════════════════════════════════════
-- CAM LOCK — BindToRenderStep prioridad Camera+1
--   Corre DESPUÉS del script de cámara nativo de Roblox (prio 200)
--   así no lo sobreescriben. Funciona en tercera persona móvil.
--   • Kill check    : descarta objetivos con Health <= 0
--   • Rango 3D      : Config.CamLockRange (studs)
--   • Wall check    : Config.CamLockWallCheck
--   • Whitelist     : isWhitelisted() igual que todo lo demás
-- ══════════════════════════════════════════════════════════════
local camLockTarget=nil   -- root del objetivo actualmente bloqueado

RunService:BindToRenderStep("SyyCamLock", Enum.RenderPriority.Camera.Value+1, function()
    if not Config.CamLockEnabled then camLockTarget=nil; return end

    local myChar=player.Character
    local myRoot=myChar and myChar:FindFirstChild("HumanoidRootPart")
    local bestRoot=nil; local bestDist=math.huge

    for _,p in ipairs(_plrList) do
        if shouldSkip(p) then continue end
        local char=p.Character; if not char then continue end
        local hum=char:FindFirstChildOfClass("Humanoid")
        local root=char:FindFirstChild("HumanoidRootPart")
        if not hum or hum.Health<=0 or not root then continue end
        local dist3D=myRoot and (root.Position-myRoot.Position).Magnitude or math.huge
        if dist3D>Config.CamLockRange then continue end
        if Config.CamLockWallCheck and myChar then
            local ok,obs=pcall(function()
                return camera:GetPartsObscuringTarget({root.Position},{myChar,char})
            end)
            if ok and #obs>0 then continue end
        end
        if dist3D<bestDist then bestDist=dist3D; bestRoot=root end
    end

    camLockTarget=bestRoot
    if not bestRoot then return end

    local camPos=camera.CFrame.Position
    local targetPos=Vector3.new(bestRoot.Position.X,bestRoot.Position.Y+1.5,bestRoot.Position.Z)
    local rawDir=targetPos-camPos
    if rawDir.Magnitude<0.1 then return end
    local strength=math.clamp(Config.CamLockStrength,1,20)*0.012
    local newLook=camera.CFrame.LookVector:Lerp(rawDir.Unit,strength)
    if newLook.Magnitude>0.01 then
        camera.CFrame=CFrame.lookAt(camPos,camPos+newLook.Unit)
    end
end)

-- ── RENDER STEP ÚNICO
-- ══════════════════════════════════════════════════════════════
-- Colores ESP cacheados — evita Color3.fromRGB() cada frame
local _boxCol=Color3.fromRGB(Config.BoxColorR,Config.BoxColorG,Config.BoxColorB)
local _skelCol=Color3.fromRGB(Config.SkelColorR,Config.SkelColorG,Config.SkelColorB)
local _namCol=Color3.fromRGB(Config.NameColorR,Config.NameColorG,Config.NameColorB)
local _snapCol=Color3.fromRGB(Config.SnapColorR,Config.SnapColorG,Config.SnapColorB)
local _fovCol=Color3.fromRGB(Config.FovColorR,Config.FovColorG,Config.FovColorB)
local _lbR,_lbG,_lbB=Config.BoxColorR,Config.BoxColorG,Config.BoxColorB
local _lsR,_lsG,_lsB=Config.SkelColorR,Config.SkelColorG,Config.SkelColorB
local _lnR,_lnG,_lnB=Config.NameColorR,Config.NameColorG,Config.NameColorB
local _lsnR,_lsnG,_lsnB=Config.SnapColorR,Config.SnapColorG,Config.SnapColorB
local _lfR,_lfG,_lfB=Config.FovColorR,Config.FovColorG,Config.FovColorB
local function _refreshColors()
    if Config.BoxColorR~=_lbR  or Config.BoxColorG~=_lbG  or Config.BoxColorB~=_lbB  then _boxCol=Color3.fromRGB(Config.BoxColorR,Config.BoxColorG,Config.BoxColorB);_lbR,_lbG,_lbB=Config.BoxColorR,Config.BoxColorG,Config.BoxColorB end
    if Config.SkelColorR~=_lsR or Config.SkelColorG~=_lsG or Config.SkelColorB~=_lsB then _skelCol=Color3.fromRGB(Config.SkelColorR,Config.SkelColorG,Config.SkelColorB);_lsR,_lsG,_lsB=Config.SkelColorR,Config.SkelColorG,Config.SkelColorB end
    if Config.NameColorR~=_lnR or Config.NameColorG~=_lnG or Config.NameColorB~=_lnB then _namCol=Color3.fromRGB(Config.NameColorR,Config.NameColorG,Config.NameColorB);_lnR,_lnG,_lnB=Config.NameColorR,Config.NameColorG,Config.NameColorB end
    if Config.SnapColorR~=_lsnR or Config.SnapColorG~=_lsnG or Config.SnapColorB~=_lsnB then _snapCol=Color3.fromRGB(Config.SnapColorR,Config.SnapColorG,Config.SnapColorB);_lsnR,_lsnG,_lsnB=Config.SnapColorR,Config.SnapColorG,Config.SnapColorB end
    if Config.FovColorR~=_lfR  or Config.FovColorG~=_lfG  or Config.FovColorB~=_lfB  then _fovCol=Color3.fromRGB(Config.FovColorR,Config.FovColorG,Config.FovColorB);_lfR,_lfG,_lfB=Config.FovColorR,Config.FovColorG,Config.FovColorB end
end
local frame=0
local _plrList={}  -- lista de jugadores cacheada, se actualiza con events
local function _rebuildPlrList()
    _plrList=Players:GetPlayers()
end
_rebuildPlrList()
Players.PlayerAdded:Connect(_rebuildPlrList)
Players.PlayerRemoving:Connect(function() task.defer(_rebuildPlrList) end)

RunService.RenderStepped:Connect(function()
    frame=frame+1

    -- Cache por frame — evita llamadas repetidas a la misma API
    local myChar=player.Character
    local myRoot=myChar and myChar:FindFirstChild("HumanoidRootPart")
    local vpSize=camera.ViewportSize
    local center2D=Vector2.new(vpSize.X*0.5, vpSize.Y*0.5)

    -- ══ TARGET CACHE — corre SIEMPRE, incluso con stream mode ON ══
    if frame%2==0 then
        -- wallbreakParams solo necesita actualizarse si Manipulation está ON
        if Config.Manipulation then
            local chars={}
            for _,p in ipairs(_plrList) do
                if p~=player and p.Character then chars[#chars+1]=p.Character end
            end
            wallbreakParams.FilterDescendantsInstances=chars
        end

        if Config.SilentAimEnabled then
            local center=center2D
            local bestD=math.huge; local bestPos=nil
            local myChar2=myChar
            local myRoot2=myRoot
            local camLook=camera.CFrame.LookVector
            local fovLimit = streamModeOn and math.huge or Config.FovRadius

            for _,p in ipairs(_plrList) do
                if shouldSkip(p) then continue end
                local char=p.Character; if not char then continue end
                local hum=char:FindFirstChildOfClass("Humanoid")
                local root=char:FindFirstChild("HumanoidRootPart")
                if not hum or hum.Health<=0 or not root then continue end

                local sp2,onS=camera:WorldToViewportPoint(root.Position)
                local d2=(Vector2.new(sp2.X,sp2.Y)-center).Magnitude

                if Config.VisibleCheck then
                    if not onS then continue end
                    if d2>fovLimit then continue end
                    if not Config.Manipulation then
                        local lc=player.Character
                        if lc then
                            local ok,obs=pcall(function() return camera:GetPartsObscuringTarget({root.Position},{lc,char}) end)
                            if ok and #obs>0 then continue end
                        end
                    end
                else
                    if not Config.Manipulation then
                        if not myRoot2 then continue end
                        local toTarget=(root.Position-myRoot2.Position)
                        local toFlat=Vector3.new(toTarget.X,0,toTarget.Z)
                        local camFlat=Vector3.new(camLook.X,0,camLook.Z)
                        local dot=toFlat.Magnitude>0.01 and camFlat:Dot(toFlat.Unit) or 0
                        if dot>=0 then continue end
                        local lc=player.Character
                        if lc then
                            local ok,obs=pcall(function() return camera:GetPartsObscuringTarget({root.Position},{lc,char}) end)
                            if ok and #obs>0 then continue end
                        end
                    end
                end

                if d2<bestD then
                    bestD=d2
                    local pn=Config.TargetPart
                    if pn=="Random" then local r=math.random(100); pn=r<=30 and "Head" or (r<=80 and "UpperTorso" or "LowerTorso")
                    elseif pn=="Pierna" then pn="LowerTorso"
                    elseif pn=="Pecho" then pn="UpperTorso"
                    elseif pn=="Combo" then local r=math.random(100); pn=r<=35 and "LowerTorso" or (r<=85 and "UpperTorso" or "Head") end
                    local hp2=char:FindFirstChild(pn) or root
                    bestPos=hp2.Position
                end
            end
            cachedTargetPos=bestPos
        else cachedTargetPos=nil end

        if Config.NpcSilentAimEnabled then
            npcCacheFrame=npcCacheFrame+1
            if npcCacheFrame>=90 then npcCacheFrame=0; rebuildNpcCache() end
            local center=center2D
            local bestD=math.huge; cachedNpcPos=nil; npcSilentVisible=true
            local myChar3=myChar
            local npcFovLimit = streamModeOn and math.huge or Config.FovRadius
            for _,hum in ipairs(cachedNpcHumanoids) do
                if not hum or not hum.Parent then continue end
                if hum.Health<=0 then continue end
                local npcRoot=hum.Parent:FindFirstChild("HumanoidRootPart")
                if not npcRoot then continue end
                local sp2,onS=camera:WorldToViewportPoint(npcRoot.Position)
                if not onS then continue end
                local d2=(Vector2.new(sp2.X,sp2.Y)-center).Magnitude
                if d2>npcFovLimit then continue end
                if d2<bestD then
                    bestD=d2
                    local pn=Config.NpcTargetPart
                    local part=hum.Parent:FindFirstChild(pn) or npcRoot
                    local visible=true
                    if not Config.Manipulation and myChar3 then
                        local ok,obs=pcall(function()
                            return camera:GetPartsObscuringTarget({part.Position},{myChar3,hum.Parent})
                        end)
                        if ok and #obs>0 then visible=false end
                    end
                    npcSilentVisible=visible
                    if visible or Config.Manipulation then cachedNpcPos=part.Position
                    else cachedNpcPos=nil end
                end
            end
        else cachedNpcPos=nil; npcSilentVisible=true end
    end

    -- ══ STREAM MODE — solo ocultar visuals, hacks siguen activos ══
    if streamModeOn then
        fovCircle.Visible=false
        snapLineDraw.Visible=false
        -- Solo iterar espObjects en el PRIMER frame de stream mode
        if not _streamHidden then
            _streamHidden=true
            for p,obj in pairs(espObjects) do
                obj.box.Visible=false; obj.nameTag.Visible=false; obj.distTag.Visible=false
                obj.healthBar.Visible=false; obj.healthBg.Visible=false
                for _,l in ipairs(obj.skeleton) do l.Visible=false end
                if itemDrawings[p] then itemDrawings[p].Visible=false end
            end
        end
        return
    end
    _streamHidden=false

    -- Actualizar colores cacheados
    if frame%6==0 then _refreshColors() end

    -- FLY
    if Config.FlyEnabled~=flyActive then
        if Config.FlyEnabled then startFly() else stopFly() end
    end
    if Config.FlyEnabled and flyActive then
        local root=myChar and myChar:FindFirstChild("HumanoidRootPart")
        local lv=root and root:FindFirstChild("SyyFlyLV")
        local ao=root and root:FindFirstChild("SyyFlyAO")
        if lv and ao then
            local sp=Config.FlySpeed; local camCF=camera.CFrame; local mv=Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv=mv+camCF.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv=mv-camCF.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv=mv-camCF.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv=mv+camCF.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then mv=mv+Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.E) then mv=mv-Vector3.yAxis end
            local hum2=myChar:FindFirstChildOfClass("Humanoid")
            if hum2 and hum2.MoveDirection.Magnitude>0.1 then
                local wf=Vector3.new(hum2.MoveDirection.X,0,hum2.MoveDirection.Z)
                if wf.Magnitude>0.01 then mv=mv+wf.Unit end
            end
            lv.VectorVelocity = mv.Magnitude>0 and mv.Unit*sp or Vector3.zero
            ao.CFrame=CFrame.new(root.Position, root.Position+Vector3.new(camCF.LookVector.X,0,camCF.LookVector.Z))
        end
    end

    -- FOV Circle
    fovCircle.Visible=Config.FovEnabled and (Config.SilentAimEnabled or Config.CamLockEnabled or Config.TriggerBotEnabled or Config.NpcSilentAimEnabled)
    if fovCircle.Visible then
        fovCircle.Position=center2D; fovCircle.Radius=Config.FovRadius
        fovCircle.Color=(Config.NpcSilentAimEnabled and not npcSilentVisible) and Color3.fromRGB(255,40,40) or _fovCol
    end

    -- TriggerBot
    if Config.TriggerBotEnabled then
        local triggerTarget=nil
        if cachedTargetPos and Config.SilentAimEnabled then
            triggerTarget=cachedTargetPos
        else
            local bestD3=math.huge
            for _,p in ipairs(_plrList) do
                if shouldSkip(p) then continue end
                local char=p.Character; if not char then continue end
                local hum=char:FindFirstChildOfClass("Humanoid")
                local root=char:FindFirstChild("HumanoidRootPart")
                if not hum or hum.Health<=0 or not root then continue end
                local sp2,onS=camera:WorldToViewportPoint(root.Position)
                if not onS then continue end
                local d=(Vector2.new(sp2.X,sp2.Y)-center2D).Magnitude
                if d<Config.FovRadius and d<bestD3 then bestD3=d; triggerTarget=root.Position end
            end
        end
        if triggerTarget and isFiring then
            local tool=myChar and myChar:FindFirstChildOfClass("Tool")
            if tool then pcall(function() tool:Activate() end) end
        end
    end

    local boxCol=_boxCol; local skelCol=_skelCol
    local namCol=_namCol; local snapCol=_snapCol

    -- Snapline target
    local snapTargetP=nil
    if Config.Snapline and Config.SilentAimEnabled and cachedTargetPos then
        local bestD2=math.huge
        for _,p in ipairs(_plrList) do
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
    local skelN=#SKEL
    for p,obj in pairs(espObjects) do
        local char=p.Character
        local sk=obj.skeleton
        local function allOff()
            obj.box.Visible=false; obj.nameTag.Visible=false; obj.distTag.Visible=false
            obj.healthBar.Visible=false; obj.healthBg.Visible=false
            for i=1,skelN do sk[i].Visible=false end
            local itd=itemDrawings[p]; if itd then itd.Visible=false end
        end
        if not Config.EspEnabled or not char then allOff(); continue end
        local root=char:FindFirstChild("HumanoidRootPart")
        local hum=char:FindFirstChild("Humanoid")
        if not root or not hum then allOff(); continue end
        local screenPos,onScreen=camera:WorldToViewportPoint(root.Position)
        if not onScreen then allOff(); continue end
        local dist3D=myRoot and (root.Position-myRoot.Position).Magnitude or 0
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
        if Config.EspBox then obj.box.Position=Vector2.new(sp.X-boxW*0.5,topSP.Y); obj.box.Size=Vector2.new(boxW,boxH) end
        obj.nameTag.Visible=Config.EspNames; obj.nameTag.Color=namCol
        if Config.EspNames then obj.nameTag.Text=p.Name; obj.nameTag.Position=Vector2.new(sp.X-boxW*0.5,topSP.Y-16) end
        obj.distTag.Visible=Config.EspDistance; obj.distTag.Color=_namCol
        if Config.EspDistance then obj.distTag.Text=math.floor(dist3D).."m"; obj.distTag.Position=Vector2.new(sp.X-boxW*0.5,botSP.Y+2) end
        local hp=hum.Health/math.max(hum.MaxHealth,1)
        obj.healthBg.Visible=Config.EspHealthBar; obj.healthBar.Visible=Config.EspHealthBar
        if Config.EspHealthBar then
            local bx=sp.X-boxW*0.5-7
            obj.healthBg.Position=Vector2.new(bx,topSP.Y); obj.healthBg.Size=Vector2.new(4,boxH); obj.healthBg.Color=Color3.fromRGB(20,20,20)
            local barH=boxH*hp
            -- Colores precalculados: evita 3 multiplicaciones de Color3 cada frame
            local r=hp<0.5 and 255 or math.floor(255*(1-hp)*2)
            local g=hp>0.5 and 255 or math.floor(255*hp*2)
            obj.healthBar.Position=Vector2.new(bx,topSP.Y+boxH-barH); obj.healthBar.Size=Vector2.new(4,barH)
            obj.healthBar.Color=Color3.fromRGB(r,g,0)
        end
        if Config.EspSkeleton then
            for si=1,skelN do
                local pair=SKEL[si]
                local pA=char:FindFirstChild(pair[1]); local pB=char:FindFirstChild(pair[2])
                local line=sk[si]; line.Color=skelCol
                if pA and pB then
                    local sA,onA=camera:WorldToViewportPoint(pA.Position)
                    local sB,onB=camera:WorldToViewportPoint(pB.Position)
                    line.Visible=onA and onB
                    if onA and onB then line.From=Vector2.new(sA.X,sA.Y); line.To=Vector2.new(sB.X,sB.Y) end
                else line.Visible=false end
            end
        else
            for i=1,skelN do sk[i].Visible=false end
        end
        local itDraw=itemDrawings[p]
        if itDraw then
            local iname=Config.ItemInHand and getItemInHand(char) or nil
            if iname then itDraw.Text="["..iname.."]"; itDraw.Position=Vector2.new(sp.X,topSP.Y-26); itDraw.Visible=true
            else itDraw.Visible=false end
        end
        if snapTargetP==p then
            snapLineDraw.Visible=true; snapLineDraw.From=center2D; snapLineDraw.To=sp; snapLineDraw.Color=snapCol
        end
    end
    if not snapTargetP then snapLineDraw.Visible=false end
end)

print("[SYY toop] Loaded — "..player.Name)

-- Reducir calidad de render en móvil para mejorar FPS
if isMobile then
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    pcall(function() settings().Rendering.EnableFRM = false end)
    pcall(function()
        local lighting = game:GetService("Lighting")
        lighting.GlobalShadows = false
        lighting.Technology = Enum.Technology.Compatibility
    end)
end

task.defer(function()
    if Config.StreamMode then
        streamModeOn=false
        applyStreamMode(true)
    end
end)