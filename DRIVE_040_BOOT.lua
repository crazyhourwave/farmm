-- DRIVE: Highway Performance Edition v0.4.0
if not game:IsLoaded() then game.Loaded:Wait() end

local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local PG=LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")
local EXPECT="0.4.0"
local URL="https://raw.githubusercontent.com/crazyhourwave/farmm/abef6358d57e3ab3b5fe6294515556320faed84a/DriveHighway.lua"

-- Hard-stop any previous DRIVE build first, including hidden old farms.
pcall(function()
    local old=rawget(_G,"HOUR_DRIVE")
    if old then
        old.alive=false
        if type(old.unload)=="function" then old.unload() end
    end
end)
_G.HOUR_DRIVE=nil

pcall(function()
    for _,name in ipairs({"HourHub_DRIVE","HourHub_DRIVE_BOOT"}) do
        local g=PG:FindFirstChild(name)
        if g then g:Destroy() end
    end
end)

local ok,src=pcall(function()
    return game:HttpGet(URL.."?perf040="..tostring(os.clock()).."_"..tostring(math.random(100000,999999)))
end)
if not ok or type(src)~="string" or #src<1000 then
    warn("[DRIVE] v0.4.0 download failed: "..tostring(src))
    return
end

local got=src:match('local%s+VERSION%s*=%s*"([^"]+)"')
if got~=EXPECT then
    warn("[DRIVE] expected v"..EXPECT..", got "..tostring(got))
    return
end

local fn,err=loadstring(src,"=DRIVE_Performance_v"..EXPECT)
if not fn then
    warn("[DRIVE] compile failed: "..tostring(err))
    return
end

local ran,rerr=pcall(fn)
if not ran then
    warn("[DRIVE] runtime failed: "..tostring(rerr))
    return
end

print("[Hour Hub] DRIVE Performance Edition loaded v"..EXPECT)
