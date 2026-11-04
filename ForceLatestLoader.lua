-- Hour Hub - FORCE LATEST
-- One loader for every supported game. Hub.lua detects game.PlaceId and dispatches the correct module.

if not game:IsLoaded() then game.Loaded:Wait() end

-- Menu-toggle behavior: current build = hide/show. Outdated build = upgrade first.
local EXPECT_ABTD="0.2.3"
local legacyAbShouldHide=false
do
    local ab=rawget(_G,"HOUR_ABTD")
    local abStale=game.PlaceId==95568014894521 and ab and ab.alive and tostring(ab.VERSION)~=EXPECT_ABTD

    if not abStale then
        local h=rawget(_G,"HOUR_HUB")
        if h and h.alive and type(h.toggleMenu)=="function" then
            local ok=pcall(h.toggleMenu)
            if ok then return end
        end
        if ab and ab.alive and type(ab.toggleMenu)=="function" then
            local ok=pcall(ab.toggleMenu)
            if ok then return end
        elseif ab and ab.alive then
            legacyAbShouldHide=true
        end
    else
        print("[Hour Hub] ABTD v"..tostring(ab.VERSION).." is outdated; upgrading to v"..EXPECT_ABTD)
    end
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
_G.HOUR_HUB=nil

-- Remove leftover game-specific windows before the hub recreates the correct one.
pcall(function()
    local pg=game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    for _,name in ipairs({"CKD_LiquidGlass","HourHub_ABTD","HourHub_Unsupported"}) do
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