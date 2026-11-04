-- Hour Hub - Multi-Game Loader v1.0.0
if not game:IsLoaded() then game.Loaded:Wait() end

local VERSION="1.0.1"
local RAW="https://raw.githubusercontent.com/crazyhourwave/farmm/main/"
local PLACE=game.PlaceId
local ROUTES={
    [111053011787075]={name="Candy Kingdom Defense",file="Farm.lua"},
    [90286053025127]={name="Candy Kingdom Defense",file="Farm.lua"},
    [95568014894521]={name="Angry Birds Tower Defense",file="AngryBirds.lua"},
}

local old=_G.HOUR_HUB
if old and old.alive then
    if type(old.toggleMenu)=="function" then
        local ok=pcall(old.toggleMenu)
        if ok then return end
    end
    pcall(function() if old.unload then old.unload() else old.alive=false end end)
end

local H={VERSION=VERSION,alive=true,place=PLACE,route=ROUTES[PLACE]}
_G.HOUR_HUB=H

function H.toggleMenu()
    if _G.HOUR_ABTD and _G.HOUR_ABTD.alive and type(_G.HOUR_ABTD.toggleMenu)=="function" then
        return _G.HOUR_ABTD.toggleMenu()
    end
    return false
end
function H.setMenuVisible(v)
    if _G.HOUR_ABTD and _G.HOUR_ABTD.alive and type(_G.HOUR_ABTD.setMenuVisible)=="function" then
        return _G.HOUR_ABTD.setMenuVisible(v)
    end
    return false
end
function H.unload()
    H.alive=false
    pcall(function() if _G.CKD_SF and _G.CKD_SF.unload then _G.CKD_SF.unload() end end)
    pcall(function() if _G.HOUR_ABTD and _G.HOUR_ABTD.unload then _G.HOUR_ABTD.unload() end end)
    if _G.HOUR_HUB==H then _G.HOUR_HUB=nil end
end

local route=ROUTES[PLACE]
if route then
    local ok,src=pcall(function() return game:HttpGet(RAW..route.file.."?force="..tostring(os.time())) end)
    if not ok or type(src)~="string" or #src<500 then
        warn("[Hour Hub] download failed for "..route.file..": "..tostring(src))
        return
    end
    local fn,err=loadstring(src,"=HourHub/"..route.file)
    if not fn then warn("[Hour Hub] compile failed for "..route.file..": "..tostring(err)) return end
    local ran,rerr=pcall(fn)
    if not ran then warn("[Hour Hub] runtime failed for "..route.file..": "..tostring(rerr)) return end
    print("[Hour Hub] loaded "..route.name.." via "..route.file)
else
    local Players=game:GetService("Players")
    local pg=Players.LocalPlayer:FindFirstChildOfClass("PlayerGui") or Players.LocalPlayer:WaitForChild("PlayerGui")
    pcall(function() local x=pg:FindFirstChild("HourHub_Unsupported") if x then x:Destroy() end end)
    local sg=Instance.new("ScreenGui")sg.Name="HourHub_Unsupported"sg.ResetOnSpawn=false sg.DisplayOrder=999999 sg.Parent=pg
    local f=Instance.new("Frame")f.Size=UDim2.fromOffset(470,210)f.Position=UDim2.new(.5,-235,.5,-105)f.BackgroundColor3=Color3.fromRGB(15,15,22)f.BorderSizePixel=0 f.Parent=sg
    local c=Instance.new("UICorner")c.CornerRadius=UDim.new(0,16)c.Parent=f
    local s=Instance.new("UIStroke")s.Color=Color3.fromRGB(255,97,72)s.Transparency=.35 s.Parent=f
    local t=Instance.new("TextLabel")t.BackgroundTransparency=1 t.Position=UDim2.fromOffset(22,18)t.Size=UDim2.new(1,-44,0,34)t.Font=Enum.Font.GothamBlack t.TextSize=20 t.TextColor3=Color3.fromRGB(255,255,255)t.TextXAlignment=Enum.TextXAlignment.Left t.Text="HOUR HUB // UNSUPPORTED GAME"t.Parent=f
    local b=Instance.new("TextLabel")b.BackgroundTransparency=1 b.Position=UDim2.fromOffset(22,64)b.Size=UDim2.new(1,-44,0,112)b.Font=Enum.Font.Gotham b.TextSize=13 b.TextWrapped=true b.TextYAlignment=Enum.TextYAlignment.Top b.TextXAlignment=Enum.TextXAlignment.Left b.TextColor3=Color3.fromRGB(190,190,205)b.Text="PlaceId: "..tostring(PLACE).."\n\nSupported:\n• Candy Kingdom Defense\n• Angry Birds Tower Defense [BETA]\n\nUse the same Hub.lua loader in either game."b.Parent=f
end

pcall(function()
    local q=queue_on_teleport or queueonteleport or(syn and syn.queue_on_teleport)
    if type(q)=="function"then
        q([[loadstring(game:HttpGet("https://raw.githubusercontent.com/crazyhourwave/farmm/main/Hub.lua?force="..tostring(os.time())))()]])
    end
end)