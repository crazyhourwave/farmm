-- Angry Birds TD v0.6.2 direct loader
if not game:IsLoaded() then game.Loaded:Wait() end

local EXPECT = "0.6.2"
local URL = "https://raw.githubusercontent.com/crazyhourwave/farmm/9318cb9dbde9dea3b7a3438671aeca4467199c0c/AngryBirds.lua"

local ok, source = pcall(function()
    return game:HttpGet(URL .. "?v062=" .. tostring(os.clock()))
end)

if not ok or type(source) ~= "string" then
    warn("[ABTD] download failed: " .. tostring(source))
    return
end

local got = source:match('local%s+VERSION%s*=%s*"([^"]+)"')
if got ~= EXPECT then
    warn("[ABTD] expected v" .. EXPECT .. ", got " .. tostring(got))
    return
end

local fn, err = loadstring(source, "=ABTD_v0.6.2")
if not fn then
    warn("[ABTD] compile failed: " .. tostring(err))
    return
end

local ran, runtimeErr = pcall(fn)
if not ran then
    warn("[ABTD] runtime failed: " .. tostring(runtimeErr))
end
