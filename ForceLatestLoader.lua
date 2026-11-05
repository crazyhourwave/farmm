-- Hour Hub - FORCE LATEST
-- One loader for every supported game. Hub.lua detects game.PlaceId and dispatches the correct module.

if not game:IsLoaded() then game.Loaded:Wait() end

if game.GameId==10768476566 or game.PlaceId==120511086614436 then
    local pg=game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local dr=rawget(_G,"HOUR_DRIVE")
    local gui=pg and pg:FindFirstChild("HourHub_DRIVE")
    if dr and dr.alive and gui and gui:IsA("ScreenGui") and type(dr.toggleMenu)=="function" then
        pcall(dr.toggleMenu)
        return
    end
end

-- ABTD: bypass Hub.lua completely so stale hub instances/caches cannot preserve an old module.
local EXPECT_ABTD="0.6.2"
if game.PlaceId==95568014894521 then
    local pg=game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local ab=rawget(_G,"HOUR_ABTD")
    local gui=pg and pg:FindFirstChild("HourHub_ABTD")

    if ab and ab.alive and tostring(ab.VERSION)==EXPECT_ABTD and gui and gui:IsA("ScreenGui") then
        gui.Enabled=not gui.Enabled
        print("[Hour Hub] ABTD menu "..(gui.Enabled and "OPENED" or "CLOSED").." directly")
        return
    end

    -- Tear down every stale copy first.
    pcall(function() if _G.HOUR_HUB and _G.HOUR_HUB.unload then _G.HOUR_HUB.unload() end end)
    pcall(function() if _G.HOUR_ABTD and _G.HOUR_ABTD.unload then _G.HOUR_ABTD.unload() end end)
    _G.HOUR_HUB=nil
    _G.HOUR_ABTD=nil
    pcall(function()
        if pg then
            local g=pg:FindFirstChild("HourHub_ABTD")
            if g then g:Destroy() end
        end
    end)

    task.wait(.12)

    local url="https://raw.githubusercontent.com/crazyhourwave/farmm/main/AngryBirds.lua?force="..tostring(os.time()).."_"..tostring(math.random(100000,999999))
    local ok,src=pcall(function() return game:HttpGet(url) end)
    if not ok or type(src)~="string" or #src<1000 then
        warn("[Hour Hub] direct ABTD download failed: "..tostring(src))
        return
    end

    local got=src:match('local%s+VERSION%s*=%s*"([^"]+)"')
    if got~=EXPECT_ABTD then
        warn("[Hour Hub] REFUSED stale ABTD source: expected v"..EXPECT_ABTD..", got "..tostring(got))
        return
    end

    local fn,err=loadstring(src,"=HourHub/AngryBirds_v"..EXPECT_ABTD)
    if not fn then
        warn("[Hour Hub] ABTD compile failed: "..tostring(err))
        return
    end
    local ran,rerr=pcall(fn)
    if not ran then
        warn("[Hour Hub] ABTD runtime failed: "..tostring(rerr))
        return
    end

    -- Minimal hub wrapper so future executions can still toggle cleanly.
    local H={VERSION="1.0.2",alive=true,place=game.PlaceId,route={name="Angry Birds Tower Defense",file="AngryBirds.lua"}}
    function H.toggleMenu()
        local g=pg and pg:FindFirstChild("HourHub_ABTD")
        if g and g:IsA("ScreenGui") then g.Enabled=not g.Enabled return g.Enabled end
        return false
    end
    function H.unload()
        H.alive=false
        pcall(function() if _G.HOUR_ABTD and _G.HOUR_ABTD.unload then _G.HOUR_ABTD.unload() end end)
        if _G.HOUR_HUB==H then _G.HOUR_HUB=nil end
    end
    _G.HOUR_HUB=H

    task.delay(.5,function()
        local live=rawget(_G,"HOUR_ABTD")
        if live and live.alive then
            print("[Hour Hub] DIRECT ABTD active v"..tostring(live.VERSION))
        else
            warn("[Hour Hub] direct ABTD build did not stay active")
        end
    end)
    return
end

local env=(getgenv and getgenv()) or _G

-- Best-effort clear of stale teleport loaders.
for _,name in ipairs({"clear_on_teleport","clearteleportqueue","clear_teleport_queue","clearqueue_on_teleport"}) do
    local fn=rawget(env,name) or rawget(_G,name)
    if type(fn)=="function" then pcall(fn) end
end
pcall(function() if syn and type(syn.clear_on_teleport)=="function" then syn.clear_on_teleport() end end)

-- Unload whichever supported module is currently alive.
pcall(function() if _G.HOUR_HUB and _G.HOUR_HUB.unload then _G.HOUR_HUB.unload() end end)
pcall(function() if _G.CKD_SF and _G.CKD_SF.unload then _G.CKD_SF.unload() end end)
pcall(function() if _G.HOUR_ABTD and _G.HOUR_ABTD.unload then _G.HOUR_ABTD.unload() end end)
pcall(function() if _G.HOUR_DRIVE and _G.HOUR_DRIVE.unload then _G.HOUR_DRIVE.unload() end end)
_G.HOUR_HUB=nil

-- Remove leftover game-specific windows before the hub recreates the correct one.
pcall(function()
    local pg=game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    for _,name in ipairs({"CKD_LiquidGlass","HourHub_ABTD","HourHub_DRIVE","HourHub_Unsupported"}) do
        local g=pg:FindFirstChild(name)
        if g then g:Destroy() end
    end
end)

task.wait(.15)

local URL="https://raw.githubusercontent.com/crazyhourwave/farmm/main/Hub.lua?force="..tostring(os.time())
local ok,src=pcall(function() return game:HttpGet(URL) end)
if not ok or type(src)~="string" or #src<500 then
    warn("[Hour Hub] FORCE LATEST download failed: "..tostring(src))
    return
end

local fn,err=loadstring(src,"=HourHub_ForceLatest")
if not fn then warn("[Hour Hub] compile failed: "..tostring(err)) return end
local ran,rerr=pcall(fn)
if not ran then warn("[Hour Hub] runtime failed: "..tostring(rerr)) return end

if legacyAbShouldHide then
    pcall(function()
        local ab=rawget(_G,"HOUR_ABTD")
        if ab and type(ab.setMenuVisible)=="function" then
            ab.setMenuVisible(false)
            print("[Hour Hub] upgraded ABTD and kept the menu closed")
        end
    end)
end

task.delay(1,function()
    local h=_G.HOUR_HUB
    if h and h.alive then
        print("[Hour Hub] active v"..tostring(h.VERSION).." • PlaceId "..tostring(game.PlaceId))
    else
        warn("[Hour Hub] did not stay active")
    end
end)