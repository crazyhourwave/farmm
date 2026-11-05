-- DRIVE: Highway v0.2.0 direct loader
if not game:IsLoaded() then game.Loaded:Wait() end

local EXPECT="0.2.0"
local URL="https://raw.githubusercontent.com/crazyhourwave/farmm/5853fd5bb1e0a92642a8ffa4471fac23cfc6638a/DriveHighway.lua"

local pg=game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
local old=rawget(_G,"HOUR_DRIVE")
local gui=pg and pg:FindFirstChild("HourHub_DRIVE")

if old and old.alive and tostring(old.VERSION)==EXPECT and gui and gui:IsA("ScreenGui") then
    gui.Enabled=not gui.Enabled
    return
end

pcall(function()
    if old and old.unload then old.unload() end
end)
_G.HOUR_DRIVE=nil
pcall(function()
    if gui then gui:Destroy() end
end)

local ok,src=pcall(function()
    return game:HttpGet(URL.."?drive020="..tostring(os.clock()).."_"..tostring(math.random(100000,999999)))
end)
if not ok or type(src)~="string" or #src<1000 then
    warn("[DRIVE] download failed: "..tostring(src))
    return
end

local got=src:match('local%s+VERSION%s*=%s*"([^"]+)"')
if got~=EXPECT then
    warn("[DRIVE] expected v"..EXPECT..", got "..tostring(got))
    return
end

local fn,err=loadstring(src,"=DRIVE_v"..EXPECT)
if not fn then
    warn("[DRIVE] compile failed: "..tostring(err))
    return
end

local ran,rerr=pcall(fn)
if not ran then
    warn("[DRIVE] runtime failed: "..tostring(rerr))
    return
end

print("[Hour Hub] DRIVE direct loader active v"..EXPECT)
