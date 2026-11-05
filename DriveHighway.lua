-- Hour Hub // DRIVE: Highway
-- Auto Drive + Force MPH + Near-Miss Weaving
if not game:IsLoaded() then game.Loaded:Wait() end

local VERSION="0.1.0"
local GAME_ID=10768476566
local ROOT_PLACE=120511086614436
if game.GameId~=GAME_ID and game.PlaceId~=ROOT_PLACE then
    warn("[Hour Hub / DRIVE] wrong experience "..tostring(game.GameId).." / "..tostring(game.PlaceId))
    return
end

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local Http=game:GetService("HttpService")
local LP=Players.LocalPlayer
local PG=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")

local old=_G.HOUR_DRIVE
if old and old.alive then
    if type(old.toggleMenu)=="function" then pcall(old.toggleMenu) return end
    pcall(function() if old.unload then old.unload() else old.alive=false end end)
end

local S={
    VERSION=VERSION,alive=true,vehicle=nil,seat=nil,root=nil,roadPart=nil,
    laneOffset=nil,baseLaneOffset=nil,targetLaneOffset=nil,targetTraffic=nil,
    nearMissSide=1,status={},lastTrafficScan=0,lastRoadScan=0
}
_G.HOUR_DRIVE=S

local CFG={
    master=true,
    autoDrive=false,
    forceSpeed=true,
    targetMph=120,
    nearMiss=false,
    nearMissGap=5.5,
    antiFlip=true,
    laneStrength=1.75,
    maxLateralMph=42,
    direction=1,
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

local saveQueued=false
local function save()
    if saveQueued then return end
    saveQueued=true
    task.delay(.2,function()
        saveQueued=false
        pcall(function()
            if makefolder and not (isfolder and isfolder(FOLDER)) then makefolder(FOLDER) end
            if writefile then writefile(SETTINGS,Http:JSONEncode(CFG)) end
        end)
    end)
end

local MPH_PER_STUD=0.626342
local function mphToStuds(mph) return mph/MPH_PER_STUD end
local function studsToMph(studs) return studs*MPH_PER_STUD end
local function flat(v) return Vector3.new(v.X,0,v.Z) end
local function unitFlat(v)
    v=flat(v)
    return v.Magnitude>.001 and v.Unit or Vector3.new(0,0,-1)
end

local function humanoid()
    local ch=LP.Character
    return ch and ch:FindFirstChildOfClass("Humanoid")
end

local function findVehicle()
    local h=humanoid()
    if not h then return end
    local seat=h.SeatPart
    if seat and seat:IsA("BasePart") then
        local model=seat:FindFirstAncestorOfClass("Model")
        local root=(model and model.PrimaryPart) or seat.AssemblyRootPart or seat
        return model,seat,root
    end

    for _,d in ipairs(workspace:GetDescendants()) do
        if d:IsA("VehicleSeat") and d.Occupant==h then
            local model=d:FindFirstAncestorOfClass("Model")
            local root=(model and model.PrimaryPart) or d.AssemblyRootPart or d
            return model,d,root
        end
    end
end

local function refreshVehicle()
    local model,seat,root=findVehicle()
    if model~=S.vehicle or seat~=S.seat or root~=S.root then
        S.vehicle,S.seat,S.root=model,seat,root
        S.roadPart=nil
        S.laneOffset=nil
        S.baseLaneOffset=nil
        S.targetLaneOffset=nil
        S.targetTraffic=nil
        S.status.vehicle=model and model.Name or "not seated"
    end
    return model,seat,root
end

local function rootBounds(model,root)
    if model then
        local ok,cf,size=pcall(model.GetBoundingBox,model)
        if ok then return cf,size end
    end
    if root then return root.CFrame,root.Size end
end

local function rayRoad(root)
    if not root then return end
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    local ex={}
    if LP.Character then table.insert(ex,LP.Character) end
    if S.vehicle then table.insert(ex,S.vehicle) end
    rp.FilterDescendantsInstances=ex
    local hit=workspace:Raycast(root.Position+Vector3.new(0,8,0),Vector3.new(0,-45,0),rp)
    return hit and hit.Instance,hit and hit.Position
end

local function roadBasis(root)
    local part=rayRoad(root)
    if not part or not part:IsA("BasePart") then
        local f=unitFlat(root.CFrame.LookVector)*CFG.direction
        local r=Vector3.new(-f.Z,0,f.X)
        return f,r,nil
    end

    S.roadPart=part
    local axis
    if part.Size.Z>=part.Size.X then axis=unitFlat(part.CFrame.LookVector)
    else axis=unitFlat(part.CFrame.RightVector) end

    local carForward=unitFlat(root.CFrame.LookVector)
    if axis:Dot(carForward)<0 then axis=-axis end
    axis*=CFG.direction
    local right=Vector3.new(-axis.Z,0,axis.X)
    return axis,right,part
end

local function laneOffsetFor(pos,road,right)
    if not road then return 0 end
    return (pos-road.Position):Dot(right)
end

local function initLane(root,fwd,right,road)
    local off=laneOffsetFor(root.Position,road,right)
    if S.baseLaneOffset==nil then
        S.baseLaneOffset=off
        S.targetLaneOffset=off
    end
    S.laneOffset=off
end

local function isOurModel(m)
    if not m then return true end
    if S.vehicle and (m==S.vehicle or m:IsDescendantOf(S.vehicle)) then return true end
    local ch=LP.Character
    if ch and (m==ch or m:IsDescendantOf(ch)) then return true end
    return false
end

local function vehicleLike(m)
    if not m:IsA("Model") or isOurModel(m) then return false end
    if Players:GetPlayerFromCharacter(m) then return false end

    local seat=m:FindFirstChildWhichIsA("VehicleSeat",true)
    local n=m.Name:lower()
    local named=n:find("car") or n:find("traffic") or n:find("vehicle") or n:find("truck") or n:find("bike") or n:find("motor")
    if not seat and not named then return false end

    local ok,cf,size=pcall(m.GetBoundingBox,m)
    if not ok then return false end
    if size.X<1.5 or size.Z<2 or size.X>28 or size.Z>45 then return false end
    return true,cf,size
end

local function scanTraffic(root,fwd,right,road)
    local best
    local carCF,carSize=rootBounds(S.vehicle,root)
    local carHalf=carSize and math.min(carSize.X,carSize.Z)*.5 or 3.2

    for _,m in ipairs(workspace:GetDescendants()) do
        if m:IsA("Model") then
            local ok,cf,size=vehicleLike(m)
            if ok then
                local rel=cf.Position-root.Position
                local ahead=rel:Dot(fwd)
                local lateral=rel:Dot(right)
                if ahead>10 and ahead<190 and math.abs(lateral)<34 then
                    local width=math.min(size.X,size.Z)
                    local moving=false
                    local part=m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart",true)
                    if part then moving=flat(part.AssemblyLinearVelocity).Magnitude>4 end
                    local score=ahead + math.abs(lateral)*2 + (moving and 0 or 45)
                    if not best or score<best.score then
                        best={model=m,pos=cf.Position,size=size,ahead=ahead,lateral=lateral,width=width,carHalf=carHalf,score=score}
                    end
                end
            end
        end
    end
    return best
end

local function chooseNearMissLane(root,fwd,right,road,traffic)
    if not traffic or not road then return S.baseLaneOffset end
    local trafficOffset=laneOffsetFor(traffic.pos,road,right)
    local trafficHalf=traffic.width*.5
    local desiredGap=CFG.nearMissGap
    local sep=trafficHalf+traffic.carHalf+desiredGap

    local left=trafficOffset-sep
    local rightOff=trafficOffset+sep
    local current=S.laneOffset or S.baseLaneOffset or 0

    local chosen
    if math.abs(left-current)<math.abs(rightOff-current) then chosen=left else chosen=rightOff end

    -- Alternate side when both options are roughly equal so farming doesn't look robotic.
    if math.abs(math.abs(left-current)-math.abs(rightOff-current))<3 then
        chosen=S.nearMissSide<0 and left or rightOff
        S.nearMissSide=-S.nearMissSide
    end
    return chosen
end

local function clampRoadOffset(off,road,fwd)
    if not road then return off end
    local cross=road.Size.Z>=road.Size.X and road.Size.X or road.Size.Z
    local margin=5
    local limit=math.max(4,cross*.5-margin)
    return math.clamp(off,-limit,limit)
end

local function signedHeadingError(current,target)
    local c=unitFlat(current)
    local t=unitFlat(target)
    local cross=c.X*t.Z-c.Z*t.X
    local dot=math.clamp(c:Dot(t),-1,1)
    return math.atan2(cross,dot)
end

local function controlStep(dt)
    if not S.alive or not CFG.master then return end
    local model,seat,root=refreshVehicle()
    if not root or not root.Parent then
        S.status.drive="sit in a vehicle"
        return
    end

    local fwd,right,road=roadBasis(root)
    initLane(root,fwd,right,road)

    if CFG.nearMiss and os.clock()-S.lastTrafficScan>.12 then
        S.lastTrafficScan=os.clock()
        S.targetTraffic=scanTraffic(root,fwd,right,road)
        if S.targetTraffic then
            S.targetLaneOffset=chooseNearMissLane(root,fwd,right,road,S.targetTraffic)
            S.status.traffic=string.format("%s • %.0f studs ahead",S.targetTraffic.model.Name,S.targetTraffic.ahead)
        else
            S.targetLaneOffset=S.baseLaneOffset
            S.status.traffic="clear"
        end
    elseif not CFG.nearMiss then
        S.targetTraffic=nil
        S.targetLaneOffset=S.baseLaneOffset
        S.status.traffic="near-miss off"
    end

    local targetOff=clampRoadOffset(S.targetLaneOffset or S.baseLaneOffset or S.laneOffset or 0,road,fwd)
    local err=targetOff-(S.laneOffset or 0)

    if CFG.autoDrive then
        local lateralMax=mphToStuds(CFG.maxLateralMph)
        local lateral=math.clamp(err*CFG.laneStrength,-lateralMax,lateralMax)
        local current=root.AssemblyLinearVelocity
        local targetSpeed=mphToStuds(CFG.targetMph)
        local forwardSpeed=CFG.forceSpeed and targetSpeed or math.max(0,flat(current):Dot(fwd))
        root.AssemblyLinearVelocity=fwd*forwardSpeed + right*lateral + Vector3.new(0,current.Y,0)

        local headingErr=signedHeadingError(root.CFrame.LookVector,fwd)
        local av=root.AssemblyAngularVelocity
        root.AssemblyAngularVelocity=Vector3.new(av.X,math.clamp(-headingErr*3.2,-2.2,2.2),av.Z)

        if CFG.antiFlip then
            local up=root.CFrame.UpVector
            if up.Y<.55 then
                local pos=root.Position
                root.CFrame=CFrame.lookAt(pos,pos+fwd,Vector3.yAxis)
                root.AssemblyAngularVelocity=Vector3.zero
                S.status.recovery="anti-flip corrected"
            end
        end

        S.status.drive=string.format("AUTO • target %.0f MPH • lane err %.1f",CFG.targetMph,err)
    elseif CFG.forceSpeed then
        local current=root.AssemblyLinearVelocity
        local targetSpeed=mphToStuds(CFG.targetMph)
        local look=unitFlat(root.CFrame.LookVector)*CFG.direction
        root.AssemblyLinearVelocity=look*targetSpeed+Vector3.new(0,current.Y,0)
        S.status.drive=string.format("FORCE SPEED • %.0f MPH",CFG.targetMph)
    else
        S.status.drive="manual"
    end

    S.status.actual=studsToMph(flat(root.AssemblyLinearVelocity).Magnitude)
    S.status.lane=string.format("%.1f -> %.1f",S.laneOffset or 0,targetOff)
end

local conn=RunService.Heartbeat:Connect(function(dt)
    local ok,err=pcall(controlStep,dt)
    if not ok then S.status.error=tostring(err) end
end)

-- UI
pcall(function() local g=PG:FindFirstChild("HourHub_DRIVE") if g then g:Destroy() end end)

local C={
    bg=Color3.fromRGB(12,14,18),panel=Color3.fromRGB(20,24,31),card=Color3.fromRGB(29,34,43),
    text=Color3.fromRGB(245,248,252),sub=Color3.fromRGB(157,166,181),
    accent=Color3.fromRGB(70,165,255),green=Color3.fromRGB(80,225,150),red=Color3.fromRGB(255,92,82),
    border=Color3.fromRGB(72,82,99)
}
local function corner(o,r) local x=Instance.new("UICorner") x.CornerRadius=UDim.new(0,r or 10) x.Parent=o end
local function stroke(o) local x=Instance.new("UIStroke") x.Color=C.border x.Transparency=.52 x.Parent=o end
local function label(p,t,z,col,font)
    local l=Instance.new("TextLabel")
    l.BackgroundTransparency=1 l.Text=t or"" l.TextSize=z or 12 l.TextColor3=col or C.text
    l.Font=font or Enum.Font.Gotham l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=p
    return l
end

local sg=Instance.new("ScreenGui")
sg.Name="HourHub_DRIVE" sg.ResetOnSpawn=false sg.DisplayOrder=999999 sg.Parent=PG

local main=Instance.new("Frame")
main.Size=UDim2.fromOffset(590,520) main.Position=UDim2.new(.5,-295,.5,-260)
main.BackgroundColor3=C.bg main.BorderSizePixel=0 main.Active=true main.Parent=sg
corner(main,16) stroke(main)

local top=Instance.new("Frame")
top.Size=UDim2.new(1,0,0,70) top.BackgroundColor3=C.panel top.BorderSizePixel=0 top.Parent=main
corner(top,16)

local title=label(top,"HOUR HUB // DRIVE: HIGHWAY",20,C.text,Enum.Font.GothamBlack)
title.Position=UDim2.fromOffset(20,13) title.Size=UDim2.new(1,-90,0,25)

local sub=label(top,"AUTO DRIVE • FORCE MPH • NEAR-MISS WEAVING • v"..VERSION,10,C.sub,Enum.Font.GothamBold)
sub.Position=UDim2.fromOffset(20,39) sub.Size=UDim2.new(1,-90,0,18)

local close=Instance.new("TextButton")
close.Size=UDim2.fromOffset(36,36) close.Position=UDim2.new(1,-50,0,17)
close.BackgroundColor3=C.card close.Text="×" close.TextSize=22 close.Font=Enum.Font.GothamBold
close.TextColor3=C.text close.AutoButtonColor=false close.Parent=top corner(close,9)

local body=Instance.new("ScrollingFrame")
body.Position=UDim2.fromOffset(14,82) body.Size=UDim2.new(1,-28,1,-96)
body.BackgroundTransparency=1 body.BorderSizePixel=0 body.ScrollBarThickness=4
body.AutomaticCanvasSize=Enum.AutomaticSize.Y body.CanvasSize=UDim2.new() body.Parent=main

local layout=Instance.new("UIListLayout")
layout.Padding=UDim.new(0,9) layout.Parent=body

local function section(txt)
    local l=label(body,txt,10,C.sub,Enum.Font.GothamBold)
    l.Size=UDim2.new(1,-4,0,18)
end

local function toggle(txt,desc,key)
    local r=Instance.new("Frame")
    r.Size=UDim2.new(1,-4,0,58) r.BackgroundColor3=C.card r.BorderSizePixel=0 r.Parent=body
    corner(r,11)
    local a=label(r,txt,13,C.text,Enum.Font.GothamBold)
    a.Position=UDim2.fromOffset(14,9) a.Size=UDim2.new(1,-110,0,20)
    local b=label(r,desc,10,C.sub)
    b.Position=UDim2.fromOffset(14,31) b.Size=UDim2.new(1,-110,0,17)
    local btn=Instance.new("TextButton")
    btn.Size=UDim2.fromOffset(72,30) btn.Position=UDim2.new(1,-86,.5,-15)
    btn.AutoButtonColor=false btn.TextSize=11 btn.Font=Enum.Font.GothamBold btn.Parent=r corner(btn,15)
    local function draw()
        btn.Text=CFG[key] and "ON" or "OFF"
        btn.BackgroundColor3=CFG[key] and C.green or Color3.fromRGB(52,58,68)
        btn.TextColor3=CFG[key] and Color3.fromRGB(10,30,20) or C.text
    end
    btn.Activated:Connect(function()
        CFG[key]=not CFG[key]
        if key=="autoDrive" and CFG[key] then
            S.baseLaneOffset=nil S.targetLaneOffset=nil
        end
        save() draw()
    end)
    draw()
    return r
end

local function slider(txt,min,max,key,suffix)
    local r=Instance.new("Frame")
    r.Size=UDim2.new(1,-4,0,76) r.BackgroundColor3=C.card r.BorderSizePixel=0 r.Parent=body
    corner(r,11)
    local a=label(r,txt,13,C.text,Enum.Font.GothamBold)
    a.Position=UDim2.fromOffset(14,9) a.Size=UDim2.new(.7,0,0,20)
    local value=label(r,"",12,C.accent,Enum.Font.GothamBold)
    value.Position=UDim2.new(.7,0,0,9) value.Size=UDim2.new(.3,-14,0,20) value.TextXAlignment=Enum.TextXAlignment.Right

    local bar=Instance.new("Frame")
    bar.Position=UDim2.fromOffset(14,47) bar.Size=UDim2.new(1,-28,0,8)
    bar.BackgroundColor3=Color3.fromRGB(50,57,68) bar.BorderSizePixel=0 bar.Parent=r corner(bar,5)

    local fill=Instance.new("Frame")
    fill.Size=UDim2.new(0,0,1,0) fill.BackgroundColor3=C.accent fill.BorderSizePixel=0 fill.Parent=bar corner(fill,5)

    local knob=Instance.new("Frame")
    knob.Size=UDim2.fromOffset(16,16) knob.AnchorPoint=Vector2.new(.5,.5)
    knob.Position=UDim2.new(0,0,.5,0) knob.BackgroundColor3=C.text knob.BorderSizePixel=0 knob.Parent=bar corner(knob,8)

    local dragging=false
    local function draw()
        local alpha=math.clamp((CFG[key]-min)/(max-min),0,1)
        fill.Size=UDim2.new(alpha,0,1,0)
        knob.Position=UDim2.new(alpha,0,.5,0)
        value.Text=string.format("%.1f%s",CFG[key],suffix or"")
        if math.floor(CFG[key])==CFG[key] then value.Text=string.format("%d%s",CFG[key],suffix or"") end
    end
    local function setX(x)
        local alpha=math.clamp((x-bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1)
        local v=min+(max-min)*alpha
        if max-min>100 then v=math.floor(v+.5) else v=math.floor(v*2+.5)/2 end
        CFG[key]=v save() draw()
    end
    bar.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true setX(i.Position.X) end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then setX(i.Position.X) end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
    end)
    draw()
end

local function button(txt,fn)
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(1,-4,0,42) b.BackgroundColor3=C.card b.BorderSizePixel=0
    b.Text=txt b.TextSize=12 b.TextColor3=C.text b.Font=Enum.Font.GothamBold b.AutoButtonColor=false b.Parent=body
    corner(b,11)
    b.Activated:Connect(fn)
    return b
end

section("DRIVING")
toggle("Auto Drive","Holds the highway direction and lane automatically","autoDrive")
toggle("Force Speed","Maintains the selected MPH even without holding W","forceSpeed")
slider("Target Speed",20,350,"targetMph"," MPH")

section("NEAR MISSES")
toggle("Force Near Misses","Weaves beside detected AI traffic, then returns to your lane","nearMiss")
slider("Near-Miss Gap",2,12,"nearMissGap"," studs")
slider("Lane Strength",0.5,3.5,"laneStrength","x")

section("SAFETY / CONTROL")
toggle("Anti Flip","Rights the vehicle if it rolls far enough to stop farming","antiFlip")
button("↔ RESET / RE-LOCK CURRENT LANE",function()
    S.baseLaneOffset=nil S.targetLaneOffset=nil S.targetTraffic=nil
    S.status.drive="lane lock reset"
end)
button("⇄ FLIP DRIVING DIRECTION",function()
    CFG.direction=CFG.direction*-1
    S.baseLaneOffset=nil S.targetLaneOffset=nil
    save()
    S.status.drive=CFG.direction==1 and "direction: current traffic" or "direction: opposite"
end)

section("LIVE DRIVE")
local live=Instance.new("Frame")
live.Size=UDim2.new(1,-4,0,126) live.BackgroundColor3=C.card live.BorderSizePixel=0 live.Parent=body corner(live,11)
local liveText=label(live,"Starting...",11,C.text,Enum.Font.Code)
liveText.Position=UDim2.fromOffset(14,10) liveText.Size=UDim2.new(1,-28,1,-20)
liveText.TextWrapped=true liveText.TextYAlignment=Enum.TextYAlignment.Top

task.spawn(function()
    while S.alive and sg.Parent do
        local actual=S.status.actual or 0
        liveText.Text=table.concat({
            string.format("Speed: %.0f MPH / %.0f target",actual,CFG.targetMph),
            "Vehicle: "..tostring(S.status.vehicle or "not seated"),
            "Drive: "..tostring(S.status.drive or "waiting"),
            "Lane: "..tostring(S.status.lane or "waiting"),
            "Traffic: "..tostring(S.status.traffic or "scanning"),
            "Recovery: "..tostring(S.status.recovery or "idle"),
            S.status.error and ("Error: "..S.status.error) or "",
        },"
")
        task.wait(.2)
    end
end)

local dragging,dragStart,startPos=false
top.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true dragStart=i.Position startPos=main.Position
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
function S.unload()
    S.alive=false
    if conn then pcall(function() conn:Disconnect() end) end
    pcall(function() if sg then sg:Destroy() end end)
    if _G.HOUR_DRIVE==S then _G.HOUR_DRIVE=nil end
end

close.Activated:Connect(function() S.setMenuVisible(false) end)

print("[Hour Hub] DRIVE: Highway active v"..VERSION)
