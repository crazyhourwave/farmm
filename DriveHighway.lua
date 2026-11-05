-- Hour Hub // DRIVE: Highway // Performance Edition
-- Only: Target Speed + Anti-Flip
if not game:IsLoaded() then game.Loaded:Wait() end

local VERSION="0.4.0"

local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local Http=game:GetService("HttpService")

local LP=Players.LocalPlayer
local PG=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")

local old=rawget(_G,"HOUR_DRIVE")
if old and old.alive then
    pcall(function()
        if old.unload then old.unload() else old.alive=false end
    end)
end

local S={
    VERSION=VERSION,
    alive=true,
    vehicle=nil,
    seat=nil,
    root=nil,
    status={},
    lastVehicleScan=0,
}
_G.HOUR_DRIVE=S

local CFG={
    speedEnabled=true,
    targetMph=120,
    antiFlip=true,
}
local FOLDER="HourHub_DRIVE"
local SETTINGS=FOLDER.."/settings.json"

pcall(function()
    if isfile and isfile(SETTINGS) then
        local t=Http:JSONDecode(readfile(SETTINGS))
        for k,v in pairs(CFG) do
            if t[k]~=nil and type(t[k])==type(v) then CFG[k]=t[k] end
        end
    end
end)

local function save()
    pcall(function()
        if makefolder and not (isfolder and isfolder(FOLDER)) then makefolder(FOLDER) end
        if writefile then writefile(SETTINGS,Http:JSONEncode(CFG)) end
    end)
end

local MPH_PER_STUD=0.626342
local function mphToStuds(mph) return mph/MPH_PER_STUD end
local function studsToMph(studs) return studs*MPH_PER_STUD end
local function flat(v) return Vector3.new(v.X,0,v.Z) end
local function unitFlat(v)
    local f=flat(v)
    return f.Magnitude>.001 and f.Unit or Vector3.new(0,0,-1)
end

local function getVehicle()
    local ch=LP.Character
    local h=ch and ch:FindFirstChildOfClass("Humanoid")
    local seat=h and h.SeatPart
    if not seat or not seat:IsA("BasePart") then
        S.vehicle,S.seat,S.root=nil,nil,nil
        return
    end

    local model=seat:FindFirstAncestorOfClass("Model")
    local root=seat.AssemblyRootPart or (model and model.PrimaryPart) or seat

    S.vehicle,S.seat,S.root=model,seat,root
    S.status.vehicle=model and model.Name or seat.Name
    return model,seat,root
end

local function forceTargetSpeed(root)
    if not CFG.speedEnabled or not root then return end

    local current=root.AssemblyLinearVelocity
    local horizontal=flat(current)
    local dir

    if horizontal.Magnitude>4 then
        dir=horizontal.Unit
    else
        dir=unitFlat(root.CFrame.LookVector)
    end

    local target=mphToStuds(CFG.targetMph)
    root.AssemblyLinearVelocity=dir*target+Vector3.new(0,current.Y,0)

    S.status.actual=studsToMph(flat(root.AssemblyLinearVelocity).Magnitude)
    S.status.speed=string.format("%.0f / %.0f MPH",S.status.actual or 0,CFG.targetMph)
end

local function antiFlip(root)
    if not CFG.antiFlip or not root then return end
    if root.CFrame.UpVector.Y>=.45 then return end

    local forward=unitFlat(root.CFrame.LookVector)
    local pos=root.Position+Vector3.new(0,1.5,0)

    root.CFrame=CFrame.lookAt(pos,pos+forward,Vector3.yAxis)
    root.AssemblyAngularVelocity=Vector3.zero
    S.status.flip="corrected"
end

-- Low-frequency worker: 20 Hz maximum. No Heartbeat/RenderStepped hooks.
task.spawn(function()
    while S.alive do
        local now=os.clock()

        if now-(S.lastVehicleScan or 0)>=.5 or not S.root or not S.root.Parent then
            S.lastVehicleScan=now
            getVehicle()
        end

        local root=S.root
        if root and root.Parent then
            pcall(forceTargetSpeed,root)
            pcall(antiFlip,root)
        else
            S.status.vehicle="not seated"
            S.status.speed="waiting"
        end

        task.wait(.08)
    end
end)

-- UI
pcall(function()
    local oldGui=PG:FindFirstChild("HourHub_DRIVE")
    if oldGui then oldGui:Destroy() end
end)

local C={
    bg=Color3.fromRGB(12,14,18),
    panel=Color3.fromRGB(20,24,31),
    card=Color3.fromRGB(29,34,43),
    text=Color3.fromRGB(245,248,252),
    sub=Color3.fromRGB(155,165,181),
    accent=Color3.fromRGB(70,165,255),
    green=Color3.fromRGB(80,225,150),
    red=Color3.fromRGB(255,92,82),
    border=Color3.fromRGB(72,82,99),
}

local function corner(o,r)
    local x=Instance.new("UICorner")
    x.CornerRadius=UDim.new(0,r or 10)
    x.Parent=o
end

local function stroke(o)
    local x=Instance.new("UIStroke")
    x.Color=C.border
    x.Transparency=.5
    x.Parent=o
end

local function label(p,t,z,col,font)
    local l=Instance.new("TextLabel")
    l.BackgroundTransparency=1
    l.Text=t or ""
    l.TextSize=z or 12
    l.TextColor3=col or C.text
    l.Font=font or Enum.Font.Gotham
    l.TextXAlignment=Enum.TextXAlignment.Left
    l.Parent=p
    return l
end

local sg=Instance.new("ScreenGui")
sg.Name="HourHub_DRIVE"
sg.ResetOnSpawn=false
sg.DisplayOrder=999999
sg.Parent=PG

local main=Instance.new("Frame")
main.Size=UDim2.fromOffset(500,390)
main.Position=UDim2.new(.5,-250,.5,-195)
main.BackgroundColor3=C.bg
main.BorderSizePixel=0
main.Active=true
main.Parent=sg
corner(main,16)
stroke(main)

local top=Instance.new("Frame")
top.Size=UDim2.new(1,0,0,68)
top.BackgroundColor3=C.panel
top.BorderSizePixel=0
top.Parent=main
corner(top,16)

local title=label(top,"HOUR HUB // DRIVE: HIGHWAY",19,C.text,Enum.Font.GothamBlack)
title.Position=UDim2.fromOffset(18,12)
title.Size=UDim2.new(1,-120,0,24)

local sub=label(top,"PERFORMANCE EDITION • v"..VERSION,10,C.sub,Enum.Font.GothamBold)
sub.Position=UDim2.fromOffset(18,38)
sub.Size=UDim2.new(1,-120,0,18)

local close=Instance.new("TextButton")
close.Size=UDim2.fromOffset(38,38)
close.Position=UDim2.new(1,-50,0,15)
close.BackgroundColor3=C.red
close.Text="×"
close.TextSize=22
close.TextColor3=Color3.new(1,1,1)
close.Font=Enum.Font.GothamBold
close.AutoButtonColor=false
close.Parent=top
corner(close,10)

local body=Instance.new("Frame")
body.Position=UDim2.fromOffset(14,82)
body.Size=UDim2.new(1,-28,1,-96)
body.BackgroundTransparency=1
body.Parent=main

local layout=Instance.new("UIListLayout")
layout.Padding=UDim.new(0,10)
layout.Parent=body

local function toggleRow(text,desc,key)
    local r=Instance.new("Frame")
    r.Size=UDim2.new(1,0,0,60)
    r.BackgroundColor3=C.card
    r.BorderSizePixel=0
    r.Parent=body
    corner(r,11)

    local a=label(r,text,13,C.text,Enum.Font.GothamBold)
    a.Position=UDim2.fromOffset(14,9)
    a.Size=UDim2.new(1,-105,0,20)

    local b=label(r,desc,10,C.sub)
    b.Position=UDim2.fromOffset(14,32)
    b.Size=UDim2.new(1,-105,0,17)

    local btn=Instance.new("TextButton")
    btn.Size=UDim2.fromOffset(70,30)
    btn.Position=UDim2.new(1,-84,.5,-15)
    btn.AutoButtonColor=false
    btn.TextSize=11
    btn.Font=Enum.Font.GothamBold
    btn.Parent=r
    corner(btn,15)

    local function draw()
        btn.Text=CFG[key] and "ON" or "OFF"
        btn.BackgroundColor3=CFG[key] and C.green or Color3.fromRGB(52,58,68)
        btn.TextColor3=CFG[key] and Color3.fromRGB(10,30,20) or C.text
    end

    btn.Activated:Connect(function()
        CFG[key]=not CFG[key]
        save()
        draw()
    end)

    draw()
end

local function speedSlider()
    local r=Instance.new("Frame")
    r.Size=UDim2.new(1,0,0,84)
    r.BackgroundColor3=C.card
    r.BorderSizePixel=0
    r.Parent=body
    corner(r,11)

    local a=label(r,"Target Speed",13,C.text,Enum.Font.GothamBold)
    a.Position=UDim2.fromOffset(14,9)
    a.Size=UDim2.new(.6,0,0,20)

    local value=label(r,"",12,C.accent,Enum.Font.GothamBold)
    value.Position=UDim2.new(.6,0,0,9)
    value.Size=UDim2.new(.4,-14,0,20)
    value.TextXAlignment=Enum.TextXAlignment.Right

    local bar=Instance.new("Frame")
    bar.Position=UDim2.fromOffset(14,52)
    bar.Size=UDim2.new(1,-28,0,8)
    bar.BackgroundColor3=Color3.fromRGB(50,57,68)
    bar.BorderSizePixel=0
    bar.Parent=r
    corner(bar,5)

    local fill=Instance.new("Frame")
    fill.BackgroundColor3=C.accent
    fill.BorderSizePixel=0
    fill.Parent=bar
    corner(fill,5)

    local knob=Instance.new("Frame")
    knob.Size=UDim2.fromOffset(16,16)
    knob.AnchorPoint=Vector2.new(.5,.5)
    knob.BackgroundColor3=C.text
    knob.BorderSizePixel=0
    knob.Parent=bar
    corner(knob,8)

    local dragging=false
    local function draw()
        local alpha=math.clamp((CFG.targetMph-20)/(350-20),0,1)
        fill.Size=UDim2.new(alpha,0,1,0)
        knob.Position=UDim2.new(alpha,0,.5,0)
        value.Text=string.format("%d MPH",math.floor(CFG.targetMph+.5))
    end

    local function setX(x)
        local alpha=math.clamp((x-bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1)
        CFG.targetMph=math.floor(20+(350-20)*alpha+.5)
        save()
        draw()
    end

    bar.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true
            setX(i.Position.X)
        end
    end)

    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
            setX(i.Position.X)
        end
    end)

    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
    end)

    draw()
end

toggleRow("Target Speed","Hold the selected MPH while seated","speedEnabled")
speedSlider()
toggleRow("Anti-Flip","Automatically rights the vehicle if it flips","antiFlip")

local live=Instance.new("Frame")
live.Size=UDim2.new(1,0,0,70)
live.BackgroundColor3=C.card
live.BorderSizePixel=0
live.Parent=body
corner(live,11)

local liveText=label(live,"Starting...",11,C.text,Enum.Font.Code)
liveText.Position=UDim2.fromOffset(14,10)
liveText.Size=UDim2.new(1,-28,1,-20)
liveText.TextWrapped=true
liveText.TextYAlignment=Enum.TextYAlignment.Top

task.spawn(function()
    while S.alive and sg.Parent do
        liveText.Text=table.concat({
            "Vehicle: "..tostring(S.status.vehicle or "not seated"),
            "Speed: "..tostring(S.status.speed or "waiting"),
            "Anti-Flip: "..tostring(S.status.flip or (CFG.antiFlip and "armed" or "off")),
        },"\n")
        task.wait(.5)
    end
end)

local forceClose=Instance.new("TextButton")
forceClose.Size=UDim2.new(1,0,0,42)
forceClose.BackgroundColor3=C.red
forceClose.BorderSizePixel=0
forceClose.Text="FORCE CLOSE SCRIPT"
forceClose.TextColor3=Color3.new(1,1,1)
forceClose.TextSize=12
forceClose.Font=Enum.Font.GothamBold
forceClose.AutoButtonColor=false
forceClose.Parent=body
corner(forceClose,11)

local dragging,dragStart,startPos=false
top.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true
        dragStart=i.Position
        startPos=main.Position
    end
end)

UIS.InputChanged:Connect(function(i)
    if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
        local d=i.Position-dragStart
        main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)

UIS.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
end)

function S.unload()
    if not S.alive then return end
    S.alive=false
    pcall(function() if sg then sg:Destroy() end end)
    if _G.HOUR_DRIVE==S then _G.HOUR_DRIVE=nil end
    print("[Hour Hub] DRIVE script fully stopped")
end

function S.forceClose()
    S.unload()
end

function S.setMenuVisible(v)
    if not sg.Parent then return false end
    sg.Enabled=v==true
    return sg.Enabled
end

function S.toggleMenu()
    if not sg.Parent then return false end
    sg.Enabled=not sg.Enabled
    return sg.Enabled
end

-- X now REALLY closes the script instead of hiding it.
close.Activated:Connect(S.unload)
forceClose.Activated:Connect(S.unload)

print("[Hour Hub] DRIVE Performance Edition active v"..VERSION)
