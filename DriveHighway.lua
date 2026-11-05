-- Hour Hub // DRIVE: Highway
-- Auto Drive + Force MPH + Near-Miss Weaving
if not game:IsLoaded() then game.Loaded:Wait() end

local VERSION="0.3.3"
local GAME_ID=10768476566
local ROOT_PLACE=120511086614436
-- Do not hard-return here. The loader already routes this module, and we want the UI to
-- remain visible even if DRIVE moves players into a new/sub-place after an update.

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
    laneOffset=nil,baseLaneOffset=0,targetLaneOffset=0,targetTraffic=nil,
    highwayOrigin=nil,highwayForward=nil,highwayRight=nil,
    laneCenters={},detectedLaneWidth=nil,laneCenterLocked=false,dodge=nil,nearMissSide=1,
    status={},lastTrafficScan=0,lastRoadScan=0,lastLineScan=0
}
_G.HOUR_DRIVE=S

local CFG={
    master=true,
    autoDrive=true,
    forceSpeed=true,
    targetMph=120,
    nearMiss=true,
    nearMissGap=5.5,
    antiFlip=true,
    laneStrength=2.15,
    maxLateralMph=52,
    laneWidth=11.5,
    dodgeLookahead=145,
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

-- DRIVE module is a farm: every execution starts automation enabled.
CFG.master=true
CFG.autoDrive=true
CFG.forceSpeed=true
CFG.nearMiss=true

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
local function flat(v) return Vector3.new(v.X,0,v.Z) end
local function unitFlat(v)
    v=flat(v)
    return v.Magnitude>.001 and v.Unit or Vector3.new(0,0,-1)
end
local function mphToStuds(mph) return mph/(S.mphPerStud or MPH_PER_STUD) end
local function studsToMph(studs) return studs*(S.mphPerStud or MPH_PER_STUD) end

local function externalMphReadout()
    for _,d in ipairs(PG:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible and not d:FindFirstAncestor("HourHub_DRIVE") then
            local txt=tostring(d.Text or ""):upper():gsub(",","")
            local n=txt:match("(%d+%.?%d*)%s*MPH")
            n=tonumber(n)
            if n and n>=0 and n<=500 then return n end
        end
    end
end

local function calibrateMph(root)
    if not root or os.clock()-(S.lastMphCalibration or 0)<.45 then return end
    S.lastMphCalibration=os.clock()
    local shown=externalMphReadout()
    local studs=flat(root.AssemblyLinearVelocity).Magnitude
    if shown and shown>=5 and studs>=5 then
        local ratio=shown/studs
        if ratio>=.15 and ratio<=3 then
            S.mphPerStud=S.mphPerStud and (S.mphPerStud*.78+ratio*.22) or ratio
            S.status.scale=string.format("%.3f MPH/stud",S.mphPerStud)
        end
    end
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
        local root=seat.AssemblyRootPart or (model and model.PrimaryPart) or seat
        return model,seat,root
    end

    for _,d in ipairs(workspace:GetDescendants()) do
        if d:IsA("VehicleSeat") and d.Occupant==h then
            local model=d:FindFirstAncestorOfClass("Model")
            local root=d.AssemblyRootPart or (model and model.PrimaryPart) or d
            return model,d,root
        end
    end
end

local function promptDistance(prompt)
    local parent=prompt and prompt.Parent
    local part=parent and (parent:IsA("BasePart") and parent or parent:FindFirstAncestorWhichIsA("BasePart"))
    local ch=LP.Character
    local hrp=ch and ch:FindFirstChild("HumanoidRootPart")
    return part and hrp and (part.Position-hrp.Position).Magnitude or math.huge
end

local function tryAutoEnter()
    local h=humanoid()
    if not h or h.SeatPart then return false end
    if os.clock()-(S.lastEnterTry or 0)<1.25 then return false end
    S.lastEnterTry=os.clock()

    local env=(getgenv and getgenv()) or _G
    local firePrompt=rawget(env,"fireproximityprompt") or rawget(_G,"fireproximityprompt")
    local best,bestD
    for _,d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then
            local a=tostring(d.ActionText or ""):lower()
            local o=tostring(d.ObjectText or ""):lower()
            if a:find("drive",1,true) or a:find("enter",1,true) or o:find("car",1,true) or o:find("vehicle",1,true) then
                local dist=promptDistance(d)
                if dist<=35 and (not bestD or dist<bestD) then best,bestD=d,dist end
            end
        end
    end
    if best and type(firePrompt)=="function" then
        local ok=pcall(firePrompt,best)
        S.status.enter=ok and ("fired Drive prompt • "..string.format("%.0f studs",bestD or 0)) or "Drive prompt call failed"
        if ok then return true end
    end

    local ch=LP.Character
    local hrp=ch and ch:FindFirstChild("HumanoidRootPart")
    local nearest,nd
    if hrp then
        for _,d in ipairs(workspace:GetDescendants()) do
            if d:IsA("VehicleSeat") and not d.Occupant then
                local dist=(d.Position-hrp.Position).Magnitude
                if dist<=28 and (not nd or dist<nd) then nearest,nd=d,dist end
            end
        end
    end
    if nearest then
        local ok=pcall(function() nearest:Sit(h) end)
        S.status.enter=ok and ("seat fallback • "..string.format("%.0f studs",nd or 0)) or "seat fallback failed"
        return ok
    end
    S.status.enter="waiting for nearby Drive prompt/car"
    return false
end

local function refreshVehicle()
    local model,seat,root=findVehicle()
    if model~=S.vehicle or seat~=S.seat or root~=S.root then
        S.vehicle,S.seat,S.root=model,seat,root
        S.roadPart=nil
        S.laneOffset=nil
        S.baseLaneOffset=0
        S.targetLaneOffset=0
        S.targetTraffic=nil
        S.highwayOrigin=nil
        S.highwayForward=nil
        S.highwayRight=nil
        S.laneCenters={}
        S.detectedLaneWidth=nil
        S.laneCenterLocked=false
        S.dodge=nil
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

    if not S.highwayForward or not S.highwayRight or not S.highwayOrigin then
        -- The user is already lined up with the highway when Auto Drive is enabled.
        -- Lock EXACTLY to the car's current facing; never derive heading from road-part axes.
        local axis=unitFlat(root.CFrame.LookVector)*CFG.direction
        S.highwayForward=unitFlat(axis)
        S.highwayRight=Vector3.new(-S.highwayForward.Z,0,S.highwayForward.X)
        S.highwayOrigin=root.Position
        S.baseLaneOffset=0
        S.targetLaneOffset=0
        S.laneOffset=0
        S.laneCenters={}
        S.dodge=nil
        S.status.heading="LOCKED TO CURRENT HIGHWAY"
    end

    S.roadPart=part
    return S.highwayForward,S.highwayRight,part
end

local function laneOffsetFor(pos,road,right)
    if not S.highwayOrigin then return 0 end
    right=right or S.highwayRight
    return (pos-S.highwayOrigin):Dot(right)
end

local function initLane(root,fwd,right,road)
    S.laneOffset=laneOffsetFor(root.Position,road,right)
    if S.baseLaneOffset==nil then S.baseLaneOffset=0 end
    if S.targetLaneOffset==nil then S.targetLaneOffset=S.baseLaneOffset end
end

local function brightLaneColor(c)
    if typeof(c)~="Color3" then return false end
    local white=c.R>.62 and c.G>.62 and c.B>.62
    local yellow=c.R>.62 and c.G>.46 and c.B<.45
    return white or yellow
end

local function isLaneMarkerPart(p,fwd)
    if not p:IsA("BasePart") then return false end
    if S.vehicle and p:IsDescendantOf(S.vehicle) then return false end
    if LP.Character and p:IsDescendantOf(LP.Character) then return false end
    if p.Transparency>.75 then return false end

    local n=p.Name:lower()
    local nameHint=n:find("lane",1,true) or n:find("line",1,true) or n:find("stripe",1,true)
        or n:find("mark",1,true) or n:find("divider",1,true)

    local thin=math.min(p.Size.X,p.Size.Z)<=3.2 and math.max(p.Size.X,p.Size.Z)>=3.5 and p.Size.Y<=3.5
    if not thin and not nameHint then return false end

    local a=unitFlat(p.CFrame.LookVector)
    local b=unitFlat(p.CFrame.RightVector)
    local align=math.max(math.abs(a:Dot(fwd)),math.abs(b:Dot(fwd)))
    if align<.72 then return false end
    return nameHint or brightLaneColor(p.Color)
end

local function clusteredOffsets(parts,right)
    local vals={}
    for _,p in ipairs(parts) do
        local off=laneOffsetFor(p.Position,nil,right)
        local merged=false
        for _,v in ipairs(vals) do
            if math.abs(v.off-off)<1.35 then
                v.off=(v.off*v.n+off)/(v.n+1)
                v.n+=1
                merged=true
                break
            end
        end
        if not merged then vals[#vals+1]={off=off,n=1} end
    end
    table.sort(vals,function(a,b)return a.off<b.off end)
    return vals
end

local function scanPaintedLaneCenter(root,fwd,right)
    if os.clock()-(S.lastLineScan or 0)<.22 then return end
    S.lastLineScan=os.clock()

    local op=OverlapParams.new()
    op.FilterType=Enum.RaycastFilterType.Exclude
    local ex={}
    if LP.Character then ex[#ex+1]=LP.Character end
    if S.vehicle then ex[#ex+1]=S.vehicle end
    op.FilterDescendantsInstances=ex

    local scanCF=CFrame.lookAt(root.Position,root.Position+fwd,Vector3.yAxis)
    local ok,parts=pcall(function()
        return workspace:GetPartBoundsInBox(scanCF,Vector3.new(72,16,150),op)
    end)
    if not ok or type(parts)~="table" then
        S.status.lines="scan unavailable"
        return
    end

    local markers={}
    for _,p in ipairs(parts) do
        if isLaneMarkerPart(p,fwd) then
            local ahead=(p.Position-root.Position):Dot(fwd)
            if ahead>-35 and ahead<115 then markers[#markers+1]=p end
        end
    end

    local vals=clusteredOffsets(markers,right)
    if #vals<2 then
        S.status.lines="no stripe pair • "..tostring(#vals).." marker groups"
        return
    end

    local ref=(S.dodge and (S.baseLaneOffset or 0)) or (S.laneOffset or 0)
    local best,bestScore
    for i=1,#vals-1 do
        local l,r=vals[i].off,vals[i+1].off
        local width=r-l
        if width>=7 and width<=18.5 then
            local center=(l+r)*.5
            local contains=ref>=l-1 and ref<=r+1
            local score=math.abs(center-ref)+(contains and -8 or 0)+math.abs(width-(S.detectedLaneWidth or 11.5))*.35
            if not bestScore or score<bestScore then
                best,bestScore={left=l,right=r,center=center,width=width},score
            end
        end
    end

    if not best then
        S.status.lines="markers found • no realistic lane pair"
        return
    end

    S.detectedLaneWidth=best.width
    if not S.dodge then
        if not S.laneCenterLocked then
            S.baseLaneOffset=best.center
            S.laneCenterLocked=true
        else
            S.baseLaneOffset=(S.baseLaneOffset or best.center)*.78+best.center*.22
        end
        S.targetLaneOffset=S.baseLaneOffset
    end

    S.status.lines=string.format("LEFT %.1f • RIGHT %.1f • CENTER %.1f • WIDTH %.1f",
        best.left,best.right,best.center,best.width)
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

    local ok,cf,size=pcall(m.GetBoundingBox,m)
    if not ok then return false end
    if size.X<1.5 or size.Z<2 or size.X>28 or size.Z>45 then return false end

    local seat=m:FindFirstChildWhichIsA("VehicleSeat",true)
    local part=m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart",true)
    local moving=part and flat(part.AssemblyLinearVelocity).Magnitude>8 or false
    local n=m.Name:lower()
    local named=n:find("car") or n:find("traffic") or n:find("vehicle") or n:find("truck") or n:find("bike") or n:find("motor")
    if not seat and not named and not moving then return false end
    return true,cf,size
end

local function roadHalfWidth(road)
    if not road then return 28 end
    local cross=road.Size.Z>=road.Size.X and road.Size.X or road.Size.Z
    return math.max(8,cross*.5-4.5)
end

local function buildLaneCenters(road,current)
    local width=math.max(8.5,S.detectedLaneWidth or CFG.laneWidth or 11.5)
    local base=S.baseLaneOffset or 0
    local centers={base-width,base,base+width}
    S.laneCenters=centers

    local cur=current or base
    local best,bd=base,math.huge
    for _,x in ipairs(centers) do
        local d=math.abs(x-cur)
        if d<bd then best,bd=x,d end
    end
    return best
end

local function trafficList(root,fwd,right,road)
    local out={}
    local _,carSize=rootBounds(S.vehicle,root)
    local carHalf=carSize and math.min(carSize.X,carSize.Z)*.5 or 3.2

    for _,m in ipairs(workspace:GetDescendants()) do
        if m:IsA("Model") then
            local ok,cf,size=vehicleLike(m)
            if ok then
                local rel=cf.Position-root.Position
                local ahead=rel:Dot(fwd)
                local lateral=laneOffsetFor(cf.Position,road,right)
                if ahead>-35 and ahead<230 and math.abs(lateral-(S.baseLaneOffset or 0))<45 then
                    local part=m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart",true)
                    local vel=part and flat(part.AssemblyLinearVelocity) or Vector3.zero
                    table.insert(out,{
                        model=m,pos=cf.Position,size=size,ahead=ahead,lateral=lateral,
                        width=math.min(size.X,size.Z),length=math.max(size.X,size.Z),
                        carHalf=carHalf,velocity=vel,
                    })
                end
            end
        end
    end
    table.sort(out,function(a,b)return a.ahead<b.ahead end)
    return out
end

local function trafficInfoFor(model,root,fwd,right)
    if not model or not model.Parent then return end
    local ok,cf,size=pcall(model.GetBoundingBox,model)
    if not ok then return end
    local rel=cf.Position-root.Position
    return {
        model=model,pos=cf.Position,size=size,
        ahead=rel:Dot(fwd),lateral=laneOffsetFor(cf.Position,nil,right),
        width=math.min(size.X,size.Z),length=math.max(size.X,size.Z),
    }
end

local function clampRoadOffset(off,road)
    local base=S.baseLaneOffset or 0
    local span=math.max(10,(S.detectedLaneWidth or CFG.laneWidth or 11.5)*1.35)
    return math.clamp(off,base-span,base+span)
end

local function corridorRisk(off,list,ignore,road)
    local risk=0
    local base=S.baseLaneOffset or 0
    local span=math.max(10,(S.detectedLaneWidth or CFG.laneWidth or 11.5)*1.35)
    local edge=span-math.abs(off-base)
    if edge<2 then risk+=(2-edge)*500 end

    for _,t in ipairs(list) do
        if t.model~=ignore and t.ahead>-8 and t.ahead<105 then
            local clearance=math.abs(off-t.lateral)-(t.width*.5+t.carHalf)
            if clearance<2.5 then
                risk+=(2.5-clearance)*1200 + math.max(0,105-t.ahead)*8
            elseif clearance<7 then
                risk+=(7-clearance)*90
            end
        end
    end
    return risk
end

local function nearestCruiseLane(current,road,list)
    local centers=S.laneCenters
    if #centers==0 then buildLaneCenters(road,current) centers=S.laneCenters end
    local best,bestScore
    for _,off in ipairs(centers) do
        local score=math.abs(off-current)*2+corridorRisk(off,list,nil,road)
        if not bestScore or score<bestScore then best,bestScore=off,score end
    end
    return best or current
end

local function chooseTarget(list,road)
    local best,bestScore
    for _,t in ipairs(list) do
        if t.ahead>18 and t.ahead<(CFG.dodgeLookahead or 145) then
            local score=t.ahead + math.abs(t.lateral-(S.laneOffset or 0))*.7
            if not bestScore or score<bestScore then best,bestScore=t,score end
        end
    end
    return best
end

local function choosePassOffset(target,list,road)
    if not target then return end
    local sep=target.width*.5+target.carHalf+math.max(2,CFG.nearMissGap)
    local left=clampRoadOffset(target.lateral-sep,road)
    local rightOff=clampRoadOffset(target.lateral+sep,road)

    local leftRisk=corridorRisk(left,list,target.model,road)
    local rightRisk=corridorRisk(rightOff,list,target.model,road)

    -- Prefer the lower-risk side. If both are nearly equal, alternate sides.
    local chosen,side
    if math.abs(leftRisk-rightRisk)<25 then
        if S.nearMissSide<0 then chosen,side=left,-1 else chosen,side=rightOff,1 end
        S.nearMissSide=-S.nearMissSide
    elseif leftRisk<rightRisk then
        chosen,side=left,-1
    else
        chosen,side=rightOff,1
    end

    return chosen,side,math.min(leftRisk,rightRisk)
end

local function signedHeadingError(current,target)
    local c=unitFlat(current)
    local t=unitFlat(target)
    local cross=c.X*t.Z-c.Z*t.X
    local dot=math.clamp(c:Dot(t),-1,1)
    return math.atan2(cross,dot)
end

local function updateDodge(root,fwd,right,road,list)
    if not CFG.nearMiss then
        S.dodge=nil
        S.targetTraffic=nil
        return S.baseLaneOffset or 0,"CRUISE • LOCKED LANE"
    end

    if S.dodge and S.dodge.model then
        local t=trafficInfoFor(S.dodge.model,root,fwd,right)
        if not t or t.ahead<-14 or os.clock()-(S.dodge.startedAt or 0)>6 then
            S.status.nearMiss="PASS COMPLETE • recentering"
            S.dodge=nil
        else
            S.targetTraffic=t
            return clampRoadOffset(S.dodge.offset,road),
                string.format("DODGE %s • %.0f studs",S.dodge.side<0 and "LEFT" or "RIGHT",t.ahead)
        end
    end

    local target=chooseTarget(list,road)
    if target then
        local off,side,risk=choosePassOffset(target,list,road)
        if off then
            S.dodge={model=target.model,offset=off,side=side,startedAt=os.clock(),risk=risk}
            S.targetTraffic=target
            S.status.nearMiss=string.format("TARGET %s • pass %s • gap %.1f",
                target.model.Name,side<0 and "LEFT" or "RIGHT",CFG.nearMissGap)
            return off,string.format("DODGE %s • %.0f studs",side<0 and "LEFT" or "RIGHT",target.ahead)
        end
    end

    S.targetTraffic=nil
    return S.baseLaneOffset or 0,"CRUISE • LOCKED LANE • hunting traffic"
end

local function controlStep(dt)
    if not S.alive or not CFG.master then return end
    local model,seat,root=refreshVehicle()
    if not root or not root.Parent then
        S.status.drive="auto-entering nearby car..."
        tryAutoEnter()
        return
    end

    calibrateMph(root)
    local fwd,right,road=roadBasis(root)
    initLane(root,fwd,right,road)
    scanPaintedLaneCenter(root,fwd,right)

    if #S.laneCenters==0 then
        buildLaneCenters(road,S.laneOffset or 0)
        if not S.laneCenterLocked then
            S.baseLaneOffset=S.baseLaneOffset or 0
            S.targetLaneOffset=S.baseLaneOffset
        end
    end

    local list={}
    if os.clock()-S.lastTrafficScan>.08 then
        S.lastTrafficScan=os.clock()
        S._traffic=trafficList(root,fwd,right,road)
    end
    list=S._traffic or {}

    local targetOff,mode=updateDodge(root,fwd,right,road,list)
    S.targetLaneOffset=targetOff or S.baseLaneOffset or S.laneOffset or 0
    S.status.traffic=S.targetTraffic and
        string.format("%s • %.0f ahead",S.targetTraffic.model.Name,S.targetTraffic.ahead)
        or string.format("clear • %d tracked",#list)

    local target=clampRoadOffset(S.targetLaneOffset,road)
    local err=target-(S.laneOffset or 0)

    if CFG.autoDrive then
        local current=root.AssemblyLinearVelocity
        local targetSpeed=mphToStuds(CFG.targetMph)

        -- If both sides around the target are dangerously occupied, briefly ease off instead of ramming.
        local speedScale=1
        if S.dodge and (S.dodge.risk or 0)>1400 and S.targetTraffic and S.targetTraffic.ahead<48 then
            speedScale=.70
            S.status.recovery="blocked pass • easing speed"
        end

        -- Keep forward travel and lane correction separate. Previous builds tilted the velocity
        -- vector toward +right/-right, which could become a permanent diagonal drive.
        local forwardSpeed=CFG.forceSpeed and targetSpeed*speedScale or math.max(0,flat(current):Dot(fwd))
        local lateralLimit=mphToStuds(math.min(CFG.maxLateralMph or 30,28))
        local lateralSpeed=math.clamp(err*1.55,-lateralLimit,lateralLimit)
        if math.abs(err)<0.35 then lateralSpeed=0 end

        root.AssemblyLinearVelocity=fwd*forwardSpeed + right*lateralSpeed + Vector3.new(0,current.Y,0)

        -- Kill the game's chassis steering/yaw while farming. The car stays pointed down the
        -- locked highway; near-miss dodges are lateral translations, not permanent turns.
        if seat then
            pcall(function() seat.Steer=0 end)
            pcall(function() seat.SteerFloat=0 end)
        end
        root.AssemblyAngularVelocity=Vector3.zero

        local up=root.CFrame.UpVector
        if CFG.antiFlip and up.Y<.55 then
            S.status.recovery="anti-flip corrected"
        end
        local pos=root.Position
        root.CFrame=CFrame.lookAt(pos,pos+fwd,Vector3.yAxis)

        S.status.drive=string.format("%s • %.0f MPH • lane err %.1f • lateral %.1f",mode,CFG.targetMph,err,lateralSpeed)
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
    S.status.lane=string.format("%.1f -> %.1f • %d lanes",S.laneOffset or 0,target,#S.laneCenters)
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

pcall(function()
    local boot=PG:FindFirstChild("HourHub_DRIVE_BOOT")
    if boot then boot:Destroy() end
end)

local sg=Instance.new("ScreenGui")
sg.Name="HourHub_DRIVE" sg.ResetOnSpawn=false sg.DisplayOrder=999999 sg.IgnoreGuiInset=false sg.Parent=PG
S.status.boot="UI mounted • auto farm enabled"

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
            S.highwayOrigin=nil S.highwayForward=nil S.highwayRight=nil
            S.baseLaneOffset=0 S.targetLaneOffset=0 S.laneOffset=nil
            S.laneCenters={} S.detectedLaneWidth=nil S.laneCenterLocked=false S.dodge=nil
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
toggle("Auto Drive","Hard-locks forward highway heading; only dodges sideways for traffic","autoDrive")
toggle("Force Speed","Maintains the selected MPH even without holding W","forceSpeed")
slider("Target Speed",20,350,"targetMph"," MPH")

section("NEAR MISSES")
toggle("Force Near Misses","Weaves beside detected AI traffic, then returns to your lane","nearMiss")
slider("Near-Miss Gap",2,12,"nearMissGap"," studs")
slider("Lane Strength",0.5,3.5,"laneStrength","x")

section("SAFETY / CONTROL")
toggle("Anti Flip","Rights the vehicle if it rolls far enough to stop farming","antiFlip")
button("↔ RESET / RE-LOCK CURRENT LANE",function()
    S.highwayOrigin=nil S.highwayForward=nil S.highwayRight=nil
    S.baseLaneOffset=0 S.targetLaneOffset=0 S.laneOffset=nil
    S.laneCenters={} S.detectedLaneWidth=nil S.laneCenterLocked=false S.dodge=nil S.targetTraffic=nil
    S.status.drive="highway/lane lock reset"
end)
button("⇄ FLIP DRIVING DIRECTION",function()
    CFG.direction=CFG.direction*-1
    S.highwayOrigin=nil S.highwayForward=nil S.highwayRight=nil
    S.baseLaneOffset=0 S.targetLaneOffset=0 S.laneOffset=nil
    S.laneCenters={} S.detectedLaneWidth=nil S.laneCenterLocked=false S.dodge=nil
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
            "Auto Enter: "..tostring(S.status.enter or "armed"),
            "Drive: "..tostring(S.status.drive or "waiting"),
            "Lane: "..tostring(S.status.lane or "waiting"),
            "Lane Lines: "..tostring(S.status.lines or "scanning painted boundaries"),
            "Heading: "..tostring(S.status.heading or "locking current highway"),
            "Traffic: "..tostring(S.status.traffic or "scanning"),
            "Near Miss AI: "..tostring(S.status.nearMiss or "hunting traffic"),
            "MPH scale: "..tostring(S.status.scale or string.format("%.3f default",MPH_PER_STUD)),
            "Recovery: "..tostring(S.status.recovery or "idle"),
            S.status.error and ("Error: "..S.status.error) or "",
        },"\\n")
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
