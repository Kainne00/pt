local mq     = require('mq')
local actors = require('actors')
local gather = require('gather')

local M = {}

M.peer_data    = {}
M.MAILBOX_NAME = 'pearltracker_exchange'

local actor_mailbox = nil
local MSG = { UPDATE = 'pt_update', REQUEST = 'pt_request' }

local function messageHandler(message)
    local ok, err = pcall(function()
        local content = message()
        if type(content) ~= 'table' then return end
        if content.type == MSG.UPDATE then
            local d = content.data
            if d and d.name then M.peer_data[d.name:lower()] = d end
        elseif content.type == MSG.REQUEST then
            if actor_mailbox then
                local myData = gather.gatherMyPearls()
                M.peer_data[myData.name:lower()] = myData
                actor_mailbox:send({ mailbox = M.MAILBOX_NAME }, { type = MSG.UPDATE, data = myData })
            end
        end
    end)
    if not ok then printf('\arPearlTracker messageHandler error: %s', tostring(err)) end
end

function M.init()
    local ok, mb = pcall(function() return actors.register(M.MAILBOX_NAME, messageHandler) end)
    if not ok or not mb then
        printf('\arPearlTracker: failed to register actor mailbox: %s', tostring(mb))
        return false
    end
    actor_mailbox = mb
    return true
end

function M.broadcastMyData()
    if not actor_mailbox then return end
    local myData = gather.gatherMyPearls()
    M.peer_data[myData.name:lower()] = myData
    actor_mailbox:send({ mailbox = M.MAILBOX_NAME }, { type = MSG.UPDATE, data = myData })
end

function M.requestAllData()
    if not actor_mailbox then return end
    actor_mailbox:send({ mailbox = M.MAILBOX_NAME }, { type = MSG.REQUEST })
end

function M.broadcastLuaRun()
    local scriptName = 'pt'
    local ok, name = pcall(function()
        return mq.TLO.Script.Name()
    end)
    if ok and name and name ~= '' then
        scriptName = tostring(name)
    end

    local cmd = string.format('/lua run %s background', scriptName)

    if mq.TLO.Plugin('MQ2Mono').IsLoaded() then
        mq.cmdf('/e3bcaa %s', cmd)
    elseif mq.TLO.Plugin('MQ2DanNet').IsLoaded() then
        mq.cmdf('/dgaexecute %s', cmd)
    elseif mq.TLO.Plugin('MQ2EQBC').IsLoaded() and mq.TLO.EQBC.Connected() then
        mq.cmdf('/bca /%s', cmd)
    end
end

return M