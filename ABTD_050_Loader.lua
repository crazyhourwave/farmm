-- Angry Birds TD v0.5.0 direct loader
if not game:IsLoaded() then game.Loaded:Wait() end

local EXPECT = "0.5.0"
local URL = "https://raw.githubusercontent.com/crazyhourwave/farmm/a78c4b423c856023d5c253b7bf81abc35682261a/AngryBirds.lua"

local ok, source = pcall(function()
    return game:HttpGet(URL .. "?v050=" .. tostring(os.clock()))
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

local fn, err = loadstring(source, "=ABTD_v0.5.0")
if not fn then
    warn("[ABTD] compile failed: " .. tostring(err))
    return
end

local ran, runtimeErr = pcall(fn)
if not ran then
    warn("[ABTD] runtime failed: " .. tostring(runtimeErr))
end
