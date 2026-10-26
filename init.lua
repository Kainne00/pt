--[[
    pearltracker - Track which toons have collected which quest pearls
    Usage: /lua run <scriptname>

    The toon that runs this manually gets the window open right away.
    Toons launched via network.broadcastLuaRun() (i.e. everyone else on
    the box) start with just the PT button -- click it to show/hide.

    Commands:
        /<scriptname>         - show the window
        /pt show | hide | refresh (or whatever your command alias is)
]]

local mq = require('mq')

-- Dynamically resolve script directory so folder name/naming doesn't matter
local str = debug.getinfo(1, "S").source
local dir = str:match("^@?(.*[/\\])")
if dir then
    package.path = package.path .. ";" .. dir .. "?.lua;" .. dir .. "?/init.lua"
end

local network = require('network')
local ui      = require('ui')

-- network.broadcastLuaRun() launches this script on every other connected
-- toon with a trailing 'background' arg so they can tell they were started
-- remotely rather than typed by hand. No such arg = manual launch = open.
local launchArgs = { ... }
local launchedInBackground = false
for _, a in ipairs(launchArgs) do
    if tostring(a):lower() == 'background' then
        launchedInBackground = true
    end
end
if not launchedInBackground then
    ui.state.open = true
end

local function handlePt(...)
    local args = { ... }
    local sub  = (args[1] or ''):lower()
    if sub == '' or sub == 'show' then
        ui.state.open = true
    elseif sub == 'hide' then
        ui.state.open = false
    elseif sub == 'refresh' then
        ui.doRefresh()
    else
        printf('\ayPearlTracker: show | hide | refresh')
    end
end

mq.bind('/pearltracker', function() ui.state.open = true end)
mq.bind('/pt', handlePt)

if not network.init() then mq.exit() end

mq.imgui.init('PearlTracker', function()
    ui.renderToggleButton()
    ui.renderWindow()
end)

network.broadcastMyData()
if not launchedInBackground then
    -- Only the toon that started this manually tells peers to launch too.
    -- Toons started BY that broadcast must not also re-broadcast it, or
    -- every toon ends up telling every other toon to launch, producing an
    -- all-to-all storm of "already running" messages.
    network.broadcastLuaRun()
end
mq.delay(1500)
network.requestAllData()

printf('\agPearlTracker loaded. Use /pt or your script shortcut to show the window.')

while true do
    mq.doevents()
    mq.delay(100)
end