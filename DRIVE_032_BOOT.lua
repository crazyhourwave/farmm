-- DRIVE: Highway v0.3.2 never-silent bootstrap
if not game:IsLoaded() then game.Loaded:Wait() end

local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local PG=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")
local EXPECT="0.3.2"
local URL="https://raw.githubusercontent.com/crazyhourwave/farmm/4042d23fe51441a5af4b3b86a2b868d1fb9d0e0a/DriveHighway.lua"

pcall(function()
    local old=PG:FindFirstChild("HourHub_DRIVE_BOOT")
    if old then old:Destroy() end
end)

local boot=Instance.new("ScreenGui")
boot.Name="HourHub_DRIVE_BOOT"
boot.ResetOnSpawn=false
boot.DisplayOrder=1000000
boot.Parent=PG

local box=Instance.new("Frame")
box.Size=UDim2.fromOffset(430,118)
box.Position=UDim2.new(.5,-215,.18,0)
box.BackgroundColor3=Color3.fromRGB(14,17,22)
box.BorderSizePixel=0
box.Parent=boot
local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,14) c.Parent=box
local st=Instance.new("UIStroke") st.Color=Color3.fromRGB(70,165,255) st.Transparency=.25 st.Parent=box

local title=Instance.new("TextLabel")
title.BackgroundTransparency=1
title.Position=UDim2.fromOffset(16,13)
title.Size=UDim2.new(1,-32,0,24)
title.Font=Enum.Font.GothamBlack
title.TextSize=17
title.TextXAlignment=Enum.TextXAlignment.Left
title.TextColor3=Color3.fromRGB(245,248,252)
title.Text="HOUR HUB // DRIVE FARM"
title.Parent=box

local status=Instance.new("TextLabel")
status.BackgroundTransparency=1
status.Position=UDim2.fromOffset(16,43)
status.Size=UDim2.new(1,-32,0,58)
status.Font=Enum.Font.Code
status.TextSize=12
status.TextWrapped=true
status.TextXAlignment=Enum.TextXAlignment.Left
status.TextYAlignment=Enum.TextYAlignment.Top
status.TextColor3=Color3.fromRGB(180,190,205)
status.Text="BOOT 1/4 • loader executed\nPlaceId: "..tostring(game.PlaceId).."  GameId: "..tostring(game.GameId)
status.Parent=box

local function fail(msg)
    status.TextColor3=Color3.fromRGB(255,110,100)
    status.Text="FAILED • "..tostring(msg).."\nPlaceId: "..tostring(game.PlaceId).."  GameId: "..tostring(game.GameId)
    warn("[DRIVE BOOT] "..tostring(msg))
end

local old=rawget(_G,"HOUR_DRIVE")
pcall(function() if old and old.unload then old.unload() end end)
_G.HOUR_DRIVE=nil
pcall(function()
    local g=PG:FindFirstChild("HourHub_DRIVE")
    if g then g:Destroy() end
end)

status.Text="BOOT 2/4 • downloading DRIVE v"..EXPECT
local ok,src=pcall(function()
    return game:HttpGet(URL.."?boot032="..tostring(os.clock()).."_"..tostring(math.random(100000,999999)))
end)
if not ok or type(src)~="string" or #src<1000 then
    fail("download failed: "..tostring(src))
    return
end

local got=src:match('local%s+VERSION%s*=%s*"([^"]+)"')
if got~=EXPECT then
    fail("version mismatch • expected "..EXPECT.." got "..tostring(got))
    return
end

status.Text="BOOT 3/4 • compiling v"..EXPECT
local fn,err=loadstring(src,"=DRIVE_v"..EXPECT)
if not fn then
    fail("compile error: "..tostring(err))
    return
end

status.Text="BOOT 4/4 • starting hard-heading farm v"..EXPECT
local ran,rerr=pcall(fn)
if not ran then
    fail("runtime error: "..tostring(rerr))
    return
end

task.delay(1,function()
    local live=rawget(_G,"HOUR_DRIVE")
    local gui=PG:FindFirstChild("HourHub_DRIVE")
    if live and live.alive and gui then
        if boot and boot.Parent then boot:Destroy() end
        print("[Hour Hub] DRIVE FARM READY v"..EXPECT)
    else
        fail("module returned but HourHub_DRIVE UI/state was not created")
    end
end)
