-- Hour Hub - Angry Birds Tower Defense [BETA] v0.1.0
if not game:IsLoaded() then game.Loaded:Wait() end
local VERSION="0.2.4"
if game.PlaceId~=95568014894521 then warn("[Hour Hub / ABTD] wrong place "..tostring(game.PlaceId)) return end

local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local VIM=game:GetService("VirtualInputManager")
local VU=game:GetService("VirtualUser")
local GuiService=game:GetService("GuiService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local LP=Players.LocalPlayer
local PG=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")
local Cam=workspace.CurrentCamera

local old=_G.HOUR_ABTD
if old and old.alive then pcall(function() if old.unload then old.unload() else old.alive=false end end) end

local S={VERSION=VERSION,alive=true,busy=false,last={},tracks={},spawn={},path={},placed={},ranges={},placedBySlot={},status={}}
_G.HOUR_ABTD=S

local CFG={master=true,autoSkip=true,autoStart=true,auto2x=true,autoContinue=true,autoPlace=true,autoUpgrade=true,autoMerge=true,placementMode="smart",rangeFallback=30,placementInterval=.75,upgradeInterval=1.1}
local FOLDER="HourHub_ABTD"; local SETTINGS=FOLDER.."/settings.json"
pcall(function()
    if isfile and isfile(SETTINGS) then
        local t=Http:JSONDecode(readfile(SETTINGS))
        for k,v in pairs(CFG) do if t[k]~=nil and type(t[k])==type(v) then CFG[k]=t[k] end end
    end
end)
local saveBusy=false
local function save()
    if saveBusy then return end
    saveBusy=true
    task.delay(.25,function()
        saveBusy=false
        pcall(function()
            if makefolder and not (isfolder and isfolder(FOLDER)) then makefolder(FOLDER) end
            if writefile then writefile(SETTINGS,Http:JSONEncode(CFG)) end
        end)
    end)
end
local function setcfg(k,v) CFG[k]=v save() end
local function norm(s) return tostring(s or ""):upper():gsub("<.->"," "):gsub("[%c]"," "):gsub("[^%w%s/%.,X%-]"," "):gsub("%s+"," ") end
local function vis(o)
    if not o or not o.Parent then return false end
    local p=o
    while p and p~=PG do if p:IsA("GuiObject") and not p.Visible then return false end p=p.Parent end
    return true
end
local function ancestorButton(o)
    local p=o
    for _=1,8 do if not p then break end if p:IsA("GuiButton") then return p end p=p.Parent end
end
local function matchButton(words)
    local best
    for _,d in ipairs(PG:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and vis(d) then
            local t=norm(d.Text)
            for _,w in ipairs(words) do
                local n=norm(w)
                if t==n or t:find(n,1,true) then
                    local b=d:IsA("GuiButton") and d or ancestorButton(d)
                    if b and vis(b) and (not best or b.AbsoluteSize.X*b.AbsoluteSize.Y>best.AbsoluteSize.X*best.AbsoluteSize.Y) then best=b end
                end
            end
        end
    end
    return best
end
local function clickGui(b)
    if not b or not vis(b) then return false end
    if firesignal then
        local ok=pcall(function() firesignal(b.Activated) end)
        if ok then return true end
    end
    local p=b.AbsolutePosition+b.AbsoluteSize/2
    return pcall(function()
        VIM:SendMouseButtonEvent(p.X,p.Y,0,true,game,0)
        task.wait(.04)
        VIM:SendMouseButtonEvent(p.X,p.Y,0,false,game,0)
    end)
end
local function clickAtXY(x,y,method)
    if method=="executor" then
        local mover=rawget(_G,"mousemoveabs") or rawget((getgenv and getgenv()) or _G,"mousemoveabs")
        local clicker=rawget(_G,"mouse1click") or rawget((getgenv and getgenv()) or _G,"mouse1click")
        local press=rawget(_G,"mouse1press") or rawget((getgenv and getgenv()) or _G,"mouse1press")
        local release=rawget(_G,"mouse1release") or rawget((getgenv and getgenv()) or _G,"mouse1release")
        if type(mover)=="function" and (type(clicker)=="function" or (type(press)=="function" and type(release)=="function")) then
            mover(math.floor(x),math.floor(y))
            task.wait(.16)
            if type(clicker)=="function" then clicker()
            else press() task.wait(.06) release() end
            return true
        end
        return false
    elseif method=="virtualuser" then
        VU:CaptureController()
        local pt=Vector2.new(x,y)
        VU:Button1Down(pt,Cam.CFrame)
        task.wait(.06)
        VU:Button1Up(pt,Cam.CFrame)
        return true
    else
        VIM:SendMouseMoveEvent(x,y,game)
        task.wait(.16)
        VIM:SendMouseButtonEvent(x,y,0,true,game,0)
        task.wait(.06)
        VIM:SendMouseButtonEvent(x,y,0,false,game,0)
        return true
    end
end

local function clickWorld(p,verify)
    Cam=workspace.CurrentCamera or Cam
    if not Cam then return false end

    local screen,screenOn=Cam:WorldToScreenPoint(p)
    local view,viewOn=Cam:WorldToViewportPoint(p)
    if (not screenOn and not viewOn) or (screen.Z<=0 and view.Z<=0) then
        S.status.click="candidate off-screen"
        return false
    end

    local hub=PG:FindFirstChild("HourHub_ABTD")
    local wasEnabled=hub and hub.Enabled
    if hub then hub.Enabled=false end

    local attempts={
        {"executor-screen", "executor",screen.X,screen.Y},
        {"executor-view",   "executor",view.X,view.Y},
        {"vu-screen",       "virtualuser",screen.X,screen.Y},
        {"vu-view",         "virtualuser",view.X,view.Y},
        {"vim-screen",      "vim",screen.X,screen.Y},
        {"vim-view",        "vim",view.X,view.Y},
    }

    local ok,lastErr,tried={}
    for _,a in ipairs(attempts) do
        local tag,m,x,y=a[1],a[2],a[3],a[4]
        local success,res=pcall(clickAtXY,x,y,m)
        table.insert(tried,tag)
        if success and res then
            S.status.click=string.format("%s @ %.0f,%.0f • verifying",tag,x,y)
            task.wait(.18)
            local accepted=true
            if type(verify)=="function" then
                local vok,vres=pcall(verify)
                accepted=vok and vres==true
            end
            if accepted then
                ok=true
                S.status.click=string.format("%s @ %.0f,%.0f • ACCEPTED",tag,x,y)
                break
            else
                S.status.click=string.format("%s @ %.0f,%.0f • ignored; trying next",tag,x,y)
                task.wait(.08)
            end
        else
            lastErr=res
        end
    end

    if hub and hub.Parent then hub.Enabled=wasEnabled~=false end
    if not ok then
        S.status.click="rejected all: "..table.concat(tried," > ")..(lastErr and (" • "..tostring(lastErr)) or "")
    end
    return ok==true
end
local function due(k,sec)
    local n=os.clock()
    if n-(S.last[k] or 0)<sec then return false end
    S.last[k]=n
    return true
end

local function allText(o)
    local a={}
    if o:IsA("TextButton") or o:IsA("TextLabel") then table.insert(a,o.Text) end
    for _,d in ipairs(o:GetDescendants()) do if d:IsA("TextButton") or d:IsA("TextLabel") then table.insert(a,d.Text) end end
    return table.concat(a," ")
end
local function money()
    Cam=workspace.CurrentCamera or Cam
    local vp=Cam and Cam.ViewportSize or Vector2.new(1920,1080)
    local best=0
    for _,d in ipairs(PG:GetDescendants()) do
        if d:IsA("TextLabel") and vis(d) and d.AbsolutePosition.Y>vp.Y*.45 then
            local raw=tostring(d.Text or "")
            if not raw:find("/") then
                local n=tonumber(raw:gsub("[^%d]",""))
                if n and n>best and n<100000000 then best=n end
            end
        end
    end
    return best
end
local function center2(o)
    return o.AbsolutePosition+o.AbsoluteSize/2
end
local function nearestButtonTo(pos,vp)
    local best,bd
    for _,b in ipairs(PG:GetDescendants()) do
        if b:IsA("GuiButton") and vis(b) and b.AbsoluteSize.X>=42 and b.AbsoluteSize.Y>=42 and b.AbsolutePosition.Y>vp.Y*.48 then
            local c=center2(b)
            local dx,dy=c.X-pos.X,c.Y-pos.Y
            local d=dx*dx+dy*dy*.55
            if math.abs(dx)<120 and math.abs(dy)<180 and (not bd or d<bd) then best,bd=b,d end
        end
    end
    return best
end
local function costNear(pos,vp)
    local best,bd
    for _,d in ipairs(PG:GetDescendants()) do
        if d:IsA("TextLabel") and vis(d) and d.AbsolutePosition.Y>vp.Y*.48 then
            local raw=tostring(d.Text or "")
            if not raw:find("/") then
                local n=tonumber(raw:gsub("[^%d]",""))
                if n and n>=25 and n<=100000 then
                    local c=center2(d)
                    local dx,dy=c.X-pos.X,c.Y-pos.Y
                    -- Cost is normally below the cap/card. Prefer the closest number in the same column.
                    if math.abs(dx)<82 and dy>-30 and dy<220 then
                        local score=dx*dx+dy*dy*.35
                        if not bd or score<bd then best,bd=n,score end
                    end
                end
            end
        end
    end
    return best
end
local function cards()
    Cam=workspace.CurrentCamera or Cam
    local vp=Cam and Cam.ViewportSize or Vector2.new(1920,1080)
    local out={}
    -- ABTD's cap label and price are not guaranteed to be descendants of the clickable ImageButton.
    -- Treat each visible "0/3", "3/3", etc. near the hotbar as the anchor for one tower card.
    for _,d in ipairs(PG:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and vis(d) and d.AbsolutePosition.Y>vp.Y*.50 then
            local a,z=tostring(d.Text or ""):match("(%d+)%s*/%s*(%d+)")
            a,z=tonumber(a),tonumber(z)
            if a and z and z>0 and z<=20 and a<=z then
                local p=center2(d)
                local dup=false
                for _,c in ipairs(out) do if math.abs(c.x-p.X)<28 then dup=true break end end
                if not dup then
                    local b=ancestorButton(d) or nearestButtonTo(p,vp)
                    if b then
                        local cost=costNear(p,vp) or math.huge
                        table.insert(out,{button=b,current=a,max=z,cost=cost,text=allText(b),x=p.X,capLabel=d})
                    end
                end
            end
        end
    end
    table.sort(out,function(a,b)return a.x<b.x end)
    for i,c in ipairs(out) do c.index=i end
    return out
end

local function modelPos(m)
    if not m or not m.Parent then return end
    if m:IsA("BasePart") then return m.Position end
    if m:IsA("Model") then
        local p=m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart",true)
        return p and p.Position
    end
end
local function enemyModel(lbl)
    local p=lbl
    for _=1,12 do
        if not p then break end
        if p:IsA("BillboardGui") and p.Adornee then
            local a=p.Adornee
            return a:IsA("Model") and a or a:FindFirstAncestorOfClass("Model") or a
        end
        if p:IsA("Model") then return p end
        p=p.Parent
    end
end
local function playerCharacter(m)
    return m and m:IsA("Model") and Players:GetPlayerFromCharacter(m)~=nil
end
local function enemyEvidence(m)
    if not m or playerCharacter(m) then return false end
    local n=norm(m.Name)
    if n:find("PIG",1,true) or n:find("HUNGRY",1,true) or n:find("RUNNER",1,true) or n:find("BOSS",1,true) then return true end
    local checked=0
    for _,d in ipairs(m:GetDescendants()) do
        if d:IsA("TextLabel") then
            checked+=1
            local t=norm(d.Text)
            if t:find("PIG",1,true) or t:find("HUNGRY",1,true) or t:find("RUNNER",1,true) then return true end
            local a,z=t:match("(%d+)%s*/%s*(%d+)")
            if a and z and tonumber(z) and tonumber(z)>0 then return true end
            if checked>=18 then break end
        end
    end
    return false
end
local function enemies()
    local out={}
    -- First: overhead BillboardGuis, which is where ABTD renders the Pig/Hungry Pig/Runner Pig labels.
    for _,g in ipairs(workspace:GetDescendants()) do
        if g:IsA("BillboardGui") then
            local hit=false
            for _,d in ipairs(g:GetDescendants()) do
                if d:IsA("TextLabel") then
                    local t=norm(d.Text)
                    if t:find("PIG",1,true) or t:find("HUNGRY",1,true) or t:find("RUNNER",1,true) or t:match("%d+%s*/%s*%d+") then hit=true break end
                end
            end
            if hit then
                local m=enemyModel(g)
                if m and modelPos(m) and not playerCharacter(m) then out[m]=true end
            end
        end
    end
    -- Fallback: model/name/health evidence. This survives UI hierarchy changes in the beta.
    if next(out)==nil then
        for _,m in ipairs(workspace:GetDescendants()) do
            if m:IsA("Model") and enemyEvidence(m) and modelPos(m) then out[m]=true end
        end
    end
    return out
end
local function spawnPoint()
    local best,bn
    for _,a in ipairs(S.spawn) do
        local n=0; local sum=Vector3.zero
        for _,b in ipairs(S.spawn) do if (a-b).Magnitude<=14 then n+=1 sum+=b end end
        if not bn or n>bn then bn=n best=sum/math.max(1,n) end
    end
    return best,bn or 0
end
local function learn()
    for m in pairs(enemies()) do
        local p=modelPos(m)
        if p then
            local tr=S.tracks[m]
            if not tr then tr={} S.tracks[m]=tr table.insert(S.spawn,p) if #S.spawn>50 then table.remove(S.spawn,1) end end
            local l=tr[#tr]
            if not l or (p-l).Magnitude>1.15 then table.insert(tr,p) if #tr>180 then table.remove(tr,1) end end
            if #tr>#S.path then
                local sp=spawnPoint()
                if not sp or (tr[1]-sp).Magnitude<25 then S.path=tr end
            end
        end
    end
    for m,tr in pairs(S.tracks) do
        if not m.Parent then
            if #tr>#S.path then S.path=tr end
            S.tracks[m]=nil
        end
    end
end

local function ground(p)
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances=LP.Character and {LP.Character} or {}
    local r=workspace:Raycast(p+Vector3.new(0,120,0),Vector3.new(0,-260,0),rp)
    return r and r.Position or p
end
local function previewRange()
    local best
    for _,d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") then
            local n=d.Name:lower()
            local s=math.max(d.Size.X,d.Size.Z)
            if (n:find("range") or n:find("radius") or n:find("circle") or n:find("placement")) and s>=10 and s<=220 then
                -- Range circles are normally very flat. Prefer those over unrelated world parts.
                local flat=math.min(d.Size.Y,d.Size.X,d.Size.Z)
                local score=s+(flat<=3 and 1000 or 0)
                if not best or score>best.score then best={range=s/2,score=score,name=d.Name} end
            end
        end
    end
    if best then S.status.range="detected "..best.name.." ≈"..math.floor(best.range+.5) return best.range end
    S.status.range="fallback "..tostring(CFG.rangeFallback)
end
local function nearestPlaced(p)
    local d=math.huge
    for _,q in ipairs(S.placed) do d=math.min(d,(p-q).Magnitude) end
    return d
end
local function score(p,r,mode,path,sp)
    if #path<4 then return -1e9 end
    local first=#path+1; local cov=0
    for i,q in ipairs(path) do
        if (Vector3.new(p.X,q.Y,p.Z)-q).Magnitude<=r then first=math.min(first,i) cov+=1.25-.45*(i/#path) end
    end
    if cov<=0 then return -1e9 end
    local spread=nearestPlaced(p)
    spread=spread==math.huge and 1 or math.clamp(spread/math.max(8,r*.7),0,1)
    if mode=="spawn" and sp then
        local dist=(Vector3.new(p.X,sp.Y,p.Z)-sp).Magnitude
        local target=r*.80
        local close=math.max(0,r*.52-dist)
        local early=1-math.clamp((first-1)/math.max(1,#path-1),0,1)
        return early*1150-math.abs(dist-target)*5.2-close*15+cov*5+spread*18
    end
    return cov*10+spread*16-(first/#path)*10
end
local function candidates(r,mode)
    local path=S.path
    if #path<4 then
        local best={}
        for _,tr in pairs(S.tracks) do if #tr>#best then best=tr end end
        path=best
    end
    if #path<4 then return {} end
    local sp=spawnPoint() or path[1]
    local out={}
    local maxI=mode=="spawn" and math.max(4,math.floor(#path*.38)) or #path
    local step=math.max(1,math.floor(maxI/18))
    for i=1,maxI,step do
        local q=path[i]; local q2=path[math.min(#path,i+2)] or q
        local dir=Vector3.new(q2.X-q.X,0,q2.Z-q.Z)
        if dir.Magnitude>.1 then
            dir=dir.Unit
            local perp=Vector3.new(-dir.Z,0,dir.X)
            for _,m in ipairs({.48,.62,.78,.94,1.10,1.26}) do
                for _,sgn in ipairs({-1,1}) do
                    local p=ground(q+perp*(r*m*sgn))
                    table.insert(out,{pos=p,score=score(p,r,mode,path,sp)})
                end
            end
        end
    end
    table.sort(out,function(a,b)return a.score>b.score end)
    return out
end
local function chooseCard()
    local cash=money(); local cs=cards(); local best
    for _,c in ipairs(cs) do
        if c.current<c.max and c.cost<=cash then
            local v=(S.placedBySlot[c.index] or 0)*100000+c.cost
            if not best or v<best.v then best={c=c,v=v} end
        end
    end
    return best and best.c,cs,cash
end
local function currentCard(i)
    local cs=cards()
    return cs[i]
end
local function likelyPlacementRemotes()
    local names={}
    for _,d in ipairs(ReplicatedStorage:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
            local n=d.Name:lower()
            if n:find("place") or n:find("deploy") or n:find("tower") or n:find("unit") or n:find("spawn") then
                table.insert(names,d:GetFullName():gsub("^ReplicatedStorage%.",""))
            end
        end
    end
    table.sort(names)
    S.status.remotes=#names>0 and table.concat(names,", ",1,math.min(3,#names)) or "none found"
    return names
end

local function modelsNear(p,r)
    local out={}
    for _,m in ipairs(workspace:GetDescendants()) do
        if m:IsA("Model") and not playerCharacter(m) then
            local q=modelPos(m)
            if q and (q-p).Magnitude<=r and not enemyEvidence(m) then out[m]=true end
        end
    end
    return out
end
local function place(c)
    if S.busy then return false,"another tower action is running" end
    S.busy=true
    local function done(a,b) S.busy=false return a,b end
    if not clickGui(c.button) then return done(false,"card click failed") end
    task.wait(.1)
    local r=previewRange() or S.ranges[c.index] or CFG.rangeFallback
    S.ranges[c.index]=r
    local opts=candidates(r,CFG.placementMode)
    if #opts==0 then return done(false,"learning pig path") end
    local before=c.current
    for i=1,math.min(14,#opts) do
        local p=opts[i].pos
        if nearestPlaced(p)>5 then
            S.status.place=string.format("trying candidate %d/%d",i,math.min(14,#opts))
            local beforeModels=modelsNear(p,11)
            local function verifyPlaced()
                local c2=currentCard(c.index)
                if c2 and c2.current>before then return true end
                for m in pairs(modelsNear(p,11)) do
                    if not beforeModels[m] then return true end
                end
                return false
            end
            local placed=clickWorld(p,verifyPlaced)
            task.wait(.12)
            if not placed then
                S.status.place="candidate "..tostring(i).." rejected by every input method"
            end
            if placed then
                table.insert(S.placed,p)
                S.placedBySlot[c.index]=(S.placedBySlot[c.index] or 0)+1
                S.status.place=string.format("slot %d • %s • range %.0f",c.index,CFG.placementMode=="spawn" and "near spawner" or "smart",r)
                return done(true)
            end
            -- Keep the card selected for the next candidate; if the game cancelled placement, reselect it.
            local c3=currentCard(c.index)
            if c3 then clickGui(c3.button) task.wait(.10) end
        end
    end
    return done(false,"no accepted spot")
end
local function upgrade()
    if S.busy then return false end
    S.busy=true
    local function done(v) S.busy=false return v end
    for _,p in ipairs(S.placed) do
        if clickWorld(p) then
            task.wait(.08)
            if CFG.autoMerge then local b=matchButton({"MERGE","COMBINE"}) if b and clickGui(b) then S.status.upgrade="merged" return done(true) end end
            if CFG.autoUpgrade then local b=matchButton({"UPGRADE","LEVEL UP"}) if b and clickGui(b) then S.status.upgrade="upgraded" return done(true) end end
        end
    end
    return done(false)
end

task.spawn(function()
    while S.alive do
        pcall(learn)
        if due("remoteScan",5) then pcall(likelyPlacementRemotes) end
        task.wait(.18)
    end
end)
task.spawn(function()
    while S.alive do
        if CFG.master then
            if CFG.autoSkip and due("skip",.55) then local b=matchButton({"SKIP TO NEXT WAVE"}) if b and clickGui(b) then S.status.wave="skip pressed" end end
            if CFG.autoStart and due("start",.7) then local b=matchButton({"START WAVE","START ROUND","READY"}) if b and clickGui(b) then S.status.wave="start pressed" end end
            if CFG.auto2x and due("speed",2) then local b=matchButton({"2X"}) if b then clickGui(b) S.status.speed="2X requested" end end
            if CFG.autoContinue and due("cont",1.2) then local b=matchButton({"PLAY AGAIN","REPLAY","CONTINUE","NEXT LEVEL","NEXT MAP","NEXT STAGE"}) if b and clickGui(b) then S.status.match="continue/replay pressed" end end
        end
        task.wait(.12)
    end
end)
task.spawn(function()
    while S.alive do
        if CFG.master and CFG.autoPlace and due("place",CFG.placementInterval) then
            local c,cs,cash=chooseCard()
            S.status.cards=string.format("%d cards • $%s",#cs,tostring(cash))
            if c then
                local ok,a,b=pcall(place,c)
                if not ok then S.status.place="error: "..tostring(a) elseif not a then S.status.place="waiting: "..tostring(b) end
            else S.status.place=#S.path>=6 and "no affordable open card" or "learning pig path..." end
        end
        task.wait(.15)
    end
end)
task.spawn(function() while S.alive do if CFG.master and (CFG.autoUpgrade or CFG.autoMerge) and due("up",CFG.upgradeInterval) then pcall(upgrade) end task.wait(.25) end end)

local C={bg=Color3.fromRGB(12,12,17),panel=Color3.fromRGB(24,24,32),card=Color3.fromRGB(35,35,45),text=Color3.fromRGB(250,250,252),sub=Color3.fromRGB(170,170,185),red=Color3.fromRGB(255,91,62),gold=Color3.fromRGB(255,190,57),green=Color3.fromRGB(81,224,147),cyan=Color3.fromRGB(71,206,255),border=Color3.fromRGB(82,82,104)}
local function corner(o,r)local x=Instance.new("UICorner")x.CornerRadius=UDim.new(0,r or 12)x.Parent=o end
local function stroke(o)local x=Instance.new("UIStroke")x.Color=C.border x.Transparency=.55 x.Parent=o end
local function label(p,t,z,col,font)local l=Instance.new("TextLabel")l.BackgroundTransparency=1 l.Text=t or"" l.TextSize=z or 11 l.TextColor3=col or C.text l.Font=font or Enum.Font.Gotham l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=p return l end

pcall(function() local g=PG:FindFirstChild("HourHub_ABTD") if g then g:Destroy() end end)
local sg=Instance.new("ScreenGui")sg.Name="HourHub_ABTD"sg.ResetOnSpawn=false sg.DisplayOrder=999999 sg.Parent=PG
local main=Instance.new("Frame")main.Size=UDim2.fromOffset(680,500)main.Position=UDim2.new(.5,-340,.5,-250)main.BackgroundColor3=C.bg main.BorderSizePixel=0 main.Active=true main.Parent=sg corner(main,18)stroke(main)
local top=Instance.new("Frame")top.Size=UDim2.new(1,0,0,72)top.BackgroundColor3=C.panel top.BorderSizePixel=0 top.Parent=main corner(top,18)
local title=label(top,"🐦  HOUR HUB // ANGRY BIRDS TD",18,C.text,Enum.Font.GothamBlack)title.Position=UDim2.fromOffset(18,10)title.Size=UDim2.new(1,-150,0,26)
local sub=label(top,"LIVE PATH AI • v"..VERSION,9,C.sub,Enum.Font.GothamBold)sub.Position=UDim2.fromOffset(20,39)sub.Size=UDim2.new(1,-150,0,18)
local active=label(top,"● ACTIVE",10,C.green,Enum.Font.GothamBold)active.Position=UDim2.new(1,-146,0,26)active.Size=UDim2.fromOffset(92,20)active.TextXAlignment=Enum.TextXAlignment.Center
local close=Instance.new("TextButton")close.Size=UDim2.fromOffset(32,32)close.Position=UDim2.new(1,-42,0,20)close.BackgroundColor3=Color3.fromRGB(48,48,61)close.BorderSizePixel=0 close.Text="×" close.TextColor3=C.text close.Font=Enum.Font.GothamBold close.TextSize=20 close.AutoButtonColor=false close.Parent=top corner(close,10)stroke(close)
local body=Instance.new("ScrollingFrame")body.Position=UDim2.fromOffset(14,84)body.Size=UDim2.new(1,-28,1,-98)body.BackgroundTransparency=1 body.BorderSizePixel=0 body.AutomaticCanvasSize=Enum.AutomaticSize.Y body.CanvasSize=UDim2.new()body.ScrollBarThickness=3 body.ScrollBarImageColor3=C.red body.Parent=main
local ll=Instance.new("UIListLayout")ll.Padding=UDim.new(0,8)ll.Parent=body
local order=0
local function row(h)order+=1 local r=Instance.new("Frame")r.Size=UDim2.new(1,-4,0,h or 58)r.BackgroundColor3=C.card r.BackgroundTransparency=.05 r.BorderSizePixel=0 r.LayoutOrder=order r.Parent=body corner(r,13)stroke(r)return r end
local function sec(t)order+=1 local r=Instance.new("Frame")r.Size=UDim2.new(1,-4,0,26)r.BackgroundTransparency=1 r.LayoutOrder=order r.Parent=body local l=label(r,t,9,C.red,Enum.Font.GothamBlack)l.Size=UDim2.fromScale(1,1)end
local function toggle(n,d,k)
    local r=row()local a=label(r,n,12,C.text,Enum.Font.GothamBold)a.Position=UDim2.fromOffset(14,7)a.Size=UDim2.new(1,-115,0,20)
    local q=label(r,d,9,C.sub)q.Position=UDim2.fromOffset(14,30)q.Size=UDim2.new(1,-120,0,16)q.TextTruncate=Enum.TextTruncate.AtEnd
    local b=Instance.new("TextButton")b.Size=UDim2.fromOffset(70,30)b.Position=UDim2.new(1,-84,.5,-15)b.BorderSizePixel=0 b.Font=Enum.Font.GothamBold b.TextSize=10 b.Parent=r corner(b,999)
    local function draw()b.Text=CFG[k]and"ON"or"OFF"b.BackgroundColor3=CFG[k]and C.red or C.panel b.TextColor3=C.text end
    b.Activated:Connect(function()setcfg(k,not CFG[k])draw()end)draw()
end
local function mode()
    local r=row(92)local a=label(r,"Placement Brain",12,C.text,Enum.Font.GothamBold)a.Position=UDim2.fromOffset(14,7)a.Size=UDim2.new(1,-28,0,20)
    local d=label(r,"Choose broad road coverage or range-aware placement beside the pig spawner",9,C.sub)d.Position=UDim2.fromOffset(14,29)d.Size=UDim2.new(1,-28,0,16)
    local a1=Instance.new("TextButton")a1.Size=UDim2.new(.5,-20,0,32)a1.Position=UDim2.fromOffset(12,51)a1.Text="🧠 SMART PLAY"a1.Font=Enum.Font.GothamBold a1.TextSize=10 a1.TextColor3=C.text a1.BorderSizePixel=0 a1.Parent=r corner(a1,10)
    local a2=Instance.new("TextButton")a2.Size=UDim2.new(.5,-20,0,32)a2.Position=UDim2.new(.5,8,0,51)a2.Text="🚩 NEAR SPAWNER (RANGE)"a2.Font=Enum.Font.GothamBold a2.TextSize=10 a2.TextColor3=C.text a2.BorderSizePixel=0 a2.Parent=r corner(a2,10)
    local function draw()local sm=CFG.placementMode=="smart"a1.BackgroundColor3=sm and C.cyan or C.panel a2.BackgroundColor3=sm and C.panel or C.gold end
    a1.Activated:Connect(function()setcfg("placementMode","smart")draw()end)a2.Activated:Connect(function()setcfg("placementMode","spawn")draw()end)draw()
end
sec("MASTER")toggle("Smart Hub","Master switch for Angry Birds automation","master")mode()
sec("WAVES")toggle("⚡ Auto Skip Next Wave","Presses the real SKIP TO NEXT WAVE button","autoSkip")toggle("▶ Auto Start","Presses START WAVE / READY when visible","autoStart")toggle("⏩ Auto 2X","Keeps the normal unlocked 2X selected","auto2x")toggle("🔁 Auto Continue / Replay","NEXT / CONTINUE / REPLAY after results","autoContinue")
sec("TOWERS")toggle("🧠 Auto Place","Reads visible tower cards, costs and caps and places affordable towers","autoPlace")toggle("⬆ Auto Upgrade","Best-effort upgrades towers placed by the hub","autoUpgrade")toggle("🔄 Auto Merge","Best-effort merge/combine when exposed by the selected tower","autoMerge")
sec("LIVE BRAIN")
local dr=row(126)local dt=label(dr,"Learning...",10,C.text,Enum.Font.Code)dt.Position=UDim2.fromOffset(14,10)dt.Size=UDim2.new(1,-28,1,-20)dt.TextWrapped=true dt.TextYAlignment=Enum.TextYAlignment.Top
task.spawn(function()
    while S.alive and sg.Parent do
        local _,conf=spawnPoint()
        local es=enemies(); local en=0 for _ in pairs(es)do en+=1 end
        local rs={}for i,r in pairs(S.ranges)do table.insert(rs,string.format("S%d=%.0f",i,r))end table.sort(rs)
        active.Text=CFG.master and"● ACTIVE"or"● PAUSED"active.TextColor3=CFG.master and C.green or C.sub
        dt.Text=table.concat({
            string.format("Money: %s    Enemies: %d    Pig path: %d samples    Spawn confidence: %d",tostring(money()),en,#S.path,conf),
            string.format("Placement: %s    Ranges: %s",CFG.placementMode=="spawn"and"Near Spawner (80% range)"or"Smart coverage + spread",#rs>0 and table.concat(rs,"  ")or tostring(S.status.range or ("learning / fallback "..CFG.rangeFallback))),
            "Waves: "..tostring(S.status.wave or"watching").."    Speed: "..tostring(S.status.speed or"watching"),
            "Placement: "..tostring(S.status.place or"learning").."    Cards: "..tostring(S.status.cards or"scanning"),
            "Click: "..tostring(S.status.click or"waiting"),
            "Placement remotes: "..tostring(S.status.remotes or"scanning"),
            "Upgrade: "..tostring(S.status.upgrade or"idle").."    Match: "..tostring(S.status.match or"active"),
        },"\n")
        task.wait(.35)
    end
end)

local dragging,ds,dp=false
top.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true ds=i.Position dp=main.Position end end)
UIS.InputChanged:Connect(function(i)if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-ds main.Position=UDim2.new(dp.X.Scale,dp.X.Offset+d.X,dp.Y.Scale,dp.Y.Offset+d.Y)end end)
UIS.InputEnded:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)

function S.setMenuVisible(v)
    if not sg.Parent then return false end
    sg.Enabled=v==true
    return sg.Enabled
end
function S.isMenuVisible()
    return sg.Parent~=nil and sg.Enabled==true
end
function S.toggleMenu()
    if not sg.Parent then return false end
    sg.Enabled=not sg.Enabled
    print("[Hour Hub] ABTD menu "..(sg.Enabled and "opened" or "closed"))
    return sg.Enabled
end
close.Activated:Connect(function()
    S.setMenuVisible(false)
    print("[Hour Hub] ABTD menu closed • execute the loader again to reopen")
end)

function S.unload()
    S.alive=false
    pcall(function()if sg.Parent then sg:Destroy()end end)
    if _G.HOUR_ABTD==S then _G.HOUR_ABTD=nil end
end

pcall(function()
    local q=queue_on_teleport or queueonteleport or(syn and syn.queue_on_teleport)
    if type(q)=="function"then q([[loadstring(game:HttpGet("https://raw.githubusercontent.com/crazyhourwave/farmm/main/Hub.lua?force="..tostring(os.time())))()]])end
end)
print("[Hour Hub] Angry Birds TD active v"..VERSION)