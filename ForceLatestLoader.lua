-- CKD Smart Farm - FORCE LATEST loader
-- Clears stale v2.3.x runtime state/cache, then loads the newest Farm.lua from main.

local EXPECT = "2.4.0"
local BASE = "https://raw.githubusercontent.com/crazyhourwave/farmm/main/Farm.lua"
local CACHE = "CKD_SmartFarm/runtime.lua"

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local env = (getgenv and getgenv()) or _G

-- Best-effort removal of old queued teleport scripts on executors that expose a clear function.
local function tryClearTeleportQueue()
    local names = {
        "clear_on_teleport",
        "clearteleportqueue",
        "clear_teleport_queue",
        "clearqueue_on_teleport",
    }
    for _, name in ipairs(names) do
        local f = rawget(env, name) or rawget(_G, name)
        if type(f) == "function" then
            pcall(f)
        end
    end
    pcall(function()
        if syn and type(syn.clear_on_teleport) == "function" then
            syn.clear_on_teleport()
        end
    end)
end

tryClearTeleportQueue()

-- Kill the currently running Smart Farm, even if it is an older pinned build.
local old = rawget(_G, "CKD_SF")
if old then
    pcall(function()
        if type(old.unload) == "function" then
            old.unload()
        else
            old.alive = false
        end
    end)
end

_G.CKD_SF = nil
_G.CKD_SF_QUEUED_VERSION = nil
_G.CKD_SF_URL = nil
_G.CKD_SF_SOURCE = nil

pcall(function()
    env.CKD_SF_URL = nil
    env.CKD_SF_SOURCE = nil
end)

-- Remove the old exact-version cache so a teleport cannot revive v2.3.8.
pcall(function()
    if isfile and isfile(CACHE) and delfile then
        delfile(CACHE)
    end
end)

-- Remove any leftover GUI from the old instance.
pcall(function()
    local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local g = pg and pg:FindFirstChild("CKD_LiquidGlass")
    if g then g:Destroy() end
end)

task.wait(0.25)

local fetchUrl = BASE .. "?force=" .. tostring(os.time())
local ok, source = pcall(function()
    return game:HttpGet(fetchUrl)
end)

if not ok or type(source) ~= "string" or #source < 1000 then
    warn("[CKD] FORCE LATEST download failed: " .. tostring(source))
    return
end

local got = source:match('local%s+VERSION%s*=%s*"([^"]+)"')
if got ~= EXPECT then
    warn("[CKD] FORCE LATEST refused: expected v" .. EXPECT .. ", got " .. tostring(got))
    return
end

-- Farm.lua will persist this exact source into CKD_SmartFarm/runtime.lua for teleport reloads.
env.CKD_SF_URL = BASE
env.CKD_SF_SOURCE = source
_G.CKD_SF_URL = BASE
_G.CKD_SF_SOURCE = source

local fn, compileErr = loadstring(source, "=CKD_SmartFarm_v" .. EXPECT)
if not fn then
    warn("[CKD] compile failed: " .. tostring(compileErr))
    return
end

local ran, runtimeErr = pcall(fn)
if not ran then
    warn("[CKD] runtime failed: " .. tostring(runtimeErr))
    return
end

task.delay(1.5, function()
    local live = rawget(_G, "CKD_SF")
    if live and live.alive then
        print("[CKD] FORCE LATEST active: v" .. tostring(live.VERSION))
        if tostring(live.VERSION) ~= EXPECT then
            warn("[CKD] another loader replaced v" .. EXPECT .. " with v" .. tostring(live.VERSION))
        end
    else
        warn("[CKD] v" .. EXPECT .. " did not stay active")
    end
end)
