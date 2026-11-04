-- Angry Birds TD v0.3.2 direct loader
if not game:IsLoaded() then game.Loaded:Wait() end

local EXPECT = "0.3.2"
local URL = "https://raw.githubusercontent.com/crazyhourwave/farmm/72182eb36f176909688efc550c9975b812231be1/AngryBirds.lua"

local ok, source = pcall(function()
    return game:HttpGet(URL .. "?v032=" .. tostring(os.clock()))
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

local fn, err = loadstring(source, "=ABTD_v0.3.2")
if not fn then
    warn("[ABTD] compile failed: " .. tostring(err))
    return
end

local ran, runtimeErr = pcall(fn)
if not ran then
    warn("[ABTD] runtime failed: " .. tostring(runtimeErr))
end
