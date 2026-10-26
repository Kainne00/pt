local mq      = require('mq')
local ImGui   = require('ImGui')
local network = require('network')
local gather  = require('gather')

local M = {}

M.state = { open = false } -- starts closed on every client; click PT to open

local COLOR_BG = {
    BLACK   = { 0.4,  0.4,  0.4,  0.25 },
    BLUE    = { 0.2,  0.35, 0.7,  0.25 },
    GOLDEN  = { 0.6,  0.5,  0.1,  0.25 },
    GREEN   = { 0.1,  0.5,  0.1,  0.25 },
    MOONLIT = { 0.4,  0.4,  0.7,  0.25 },
    PURPLE  = { 0.4,  0.1,  0.6,  0.25 },
    ROSE    = { 0.6,  0.2,  0.3,  0.25 },
    SILVER  = { 0.4,  0.4,  0.5,  0.25 },
    SLATE   = { 0.22, 0.35, 0.4,  0.25 },
}

local COLOR_GROUP = {
    BLACK  = { 0.6,  0.6,  0.6,  1.0 },
    BLUE   = { 0.4,  0.6,  1.0,  1.0 },
    GOLDEN = { 1.0,  0.85, 0.2,  1.0 },
    GREEN  = { 0.3,  0.9,  0.3,  1.0 },
    MOONLIT= { 0.8,  0.8,  1.0,  1.0 },
    PURPLE = { 0.8,  0.3,  1.0,  1.0 },
    ROSE   = { 1.0,  0.5,  0.6,  1.0 },
    SILVER = { 0.8,  0.8,  0.9,  1.0 },
    SLATE  = { 0.45, 0.68, 0.75, 1.0 },
}

local pushedColors = 0
local ptDragging = false -- true while the PT toggle button is being dragged
local ptWinX, ptWinY = nil, nil -- last known position of the PT toggle window

-- Some MQ ImGui bindings return position/vector values as two plain
-- numbers; others return a single ImVec2-style object with .x/.y fields.
-- Normalize either shape to two plain numbers before doing arithmetic on
-- them, since arithmetic on an unwrapped object is what was throwing the
-- "no matching function call" error here.
local function asXY(a, b)
    if type(a) == 'number' then
        return a, b
    elseif type(a) == 'table' or type(a) == 'userdata' then
        return a.x, a.y
    end
    return 0, 0
end

local function pushColor(idx, r, g, b, a)
    ImGui.PushStyleColor(idx, r, g, b, a)
    pushedColors = pushedColors + 1
end

local function popAllColors()
    while pushedColors > 0 do
        ImGui.PopStyleColor()
        pushedColors = pushedColors - 1
    end
end

function M.doRefresh()
    network.broadcastMyData()
    network.requestAllData()
end

local function getSortedToons()
    local names = {}
    for k in pairs(network.peer_data) do
        table.insert(names, k)
    end
    table.sort(names)
    return names
end

-- Color used for the "ready to combine" state: all 4 dull pearls on hand
-- but not yet turned into a Flawless pearl. Distinct from both the
-- in-progress amber/green count text and the gold Flawless text.
local READY_COLOR = { 0.4, 0.85, 1.0, 1.0 }

local function renderContent()
    if ImGui.Button('Refresh') then M.doRefresh() end
    ImGui.SameLine()
    ImGui.TextColored(0.6, 0.6, 0.6, 1.0, '(click the arrow to expand a color)')

    ImGui.Separator()

    local toons = getSortedToons()
    local numToons = #toons

local colCount = 1 + numToons
    ---@diagnostic disable-line: param-type-mismatch
    local tableFlags = ImGuiTableFlags.Borders + ImGuiTableFlags.RowBg +
                       ImGuiTableFlags.ScrollX + ImGuiTableFlags.ScrollY +
                       ImGuiTableFlags.SizingFixedFit

    local _, availH = ImGui.GetContentRegionAvail()
    if ImGui.BeginTable('##pearltable', colCount, tableFlags, 0, math.max(100, availH)) then
        local ok, err = pcall(function()
            ImGui.TableSetupScrollFreeze(1, 1)
            ImGui.TableSetupColumn('Pearl', ImGuiTableColumnFlags.WidthFixed, 100)
            for _, toon in ipairs(toons) do
                local d = network.peer_data[toon]
                local dispName = (d and d.name) or toon
                ImGui.TableSetupColumn(dispName, ImGuiTableColumnFlags.WidthFixed, 60)
            end
            ImGui.TableHeadersRow()

            -- Total row: how many colors this toon has fully flawless out
            -- of the total color count. Frozen in place along with the
            -- header row via TableSetupScrollFreeze(1, 1) above.
            ImGui.TableNextRow()
            ImGui.TableSetColumnIndex(0)
            ImGui.Text('Total Flawless')
            for i, toon in ipairs(toons) do
                ImGui.TableSetColumnIndex(i)
                local d = network.peer_data[toon]
                local done, total = gather.totalFlawless(d)
                if total > 0 and done == total then
                    pushColor(ImGuiCol.Text, 0.2, 0.9, 0.2, 1.0)
                    ImGui.Text(string.format('%d/%d', done, total))
                    popAllColors()
                else
                    ImGui.Text(string.format('%d/%d', done, total))
                end
            end

            -- One summary row per color, expandable into its 4 individual
            -- pearls via a native ImGui tree node (built-in arrow, ImGui
            -- tracks open/closed state itself). Order comes from gather.COLORS.
            local nodeFlags = ImGuiTreeNodeFlags.SpanFullWidth
            for _, color in ipairs(gather.COLORS) do
                local c = COLOR_GROUP[color] or { 1, 1, 1, 1 }
                local bg = COLOR_BG[color] or { 0.5, 0.5, 0.5, 0.25 }

                ImGui.TableNextRow()
                ImGui.TableSetBgColor(ImGuiTableBgTarget.RowBg0, bg[1], bg[2], bg[3], 0.35)
                ImGui.TableSetColumnIndex(0)
                pushColor(ImGuiCol.Text, c[1], c[2], c[3], c[4])
                local expanded = ImGui.TreeNodeEx(color .. '##row_' .. color, nodeFlags)
                popAllColors()

                for i, toon in ipairs(toons) do
                    ImGui.TableSetColumnIndex(i)
                    local d = network.peer_data[toon]
                    local status = gather.colorStatus(d, color)

                    if status.flawless then
                        ImGui.TableSetBgColor(ImGuiTableBgTarget.CellBg, bg[1], bg[2], bg[3], bg[4])
                        pushColor(ImGuiCol.Text, 1.0, 0.85, 0.2, 1.0)
                        ImGui.Text('F')
                        popAllColors()
                    elseif status.total > 0 and status.have == status.total then
                        ImGui.TableSetBgColor(ImGuiTableBgTarget.CellBg, bg[1], bg[2], bg[3], bg[4])
                        pushColor(ImGuiCol.Text, READY_COLOR[1], READY_COLOR[2], READY_COLOR[3], READY_COLOR[4])
                        ImGui.Text(string.format('%d/%d', status.have, status.total))
                        popAllColors()
                    elseif status.have > 0 then
                        ImGui.Text(string.format('%d/%d', status.have, status.total))
                    else
                        pushColor(ImGuiCol.Text, 0.45, 0.45, 0.45, 1.0)
                        ImGui.Text('-')
                        popAllColors()
                    end
                end

                if expanded then
                    for _, entry in ipairs(gather.PEARLS) do
                        if entry.color == color then
                            ImGui.TableNextRow()
                            ImGui.TableSetBgColor(ImGuiTableBgTarget.RowBg0, bg[1], bg[2], bg[3], 0.12)
                            ImGui.TableSetColumnIndex(0)
                            ImGui.Text('    ' .. gather.shortLabel(entry))

                            for i, toon in ipairs(toons) do
                                ImGui.TableSetColumnIndex(i)
                                local d = network.peer_data[toon]
                                local hasFlawless = d and d.flawless and d.flawless[color]
                                if d and d.pearls and d.pearls[entry.name] then
                                    if hasFlawless then
                                        pushColor(ImGuiCol.Text, 1.0, 0.85, 0.2, 1.0)
                                    else
                                        pushColor(ImGuiCol.Text, 0.2, 0.9, 0.2, 1.0)
                                    end
                                    ImGui.Text('Y')
                                    popAllColors()
                                else
                                    pushColor(ImGuiCol.Text, 0.45, 0.45, 0.45, 1.0)
                                    ImGui.Text('-')
                                    popAllColors()
                                end
                            end
                        end
                    end
                    -- Only pop if the node actually opened -- TreeNodeEx/TreePop
                    -- must stay balanced.
                    ImGui.TreePop()
                end
            end
        end)
        ImGui.EndTable()
        if not ok then printf('\arPearlTracker table error: %s', tostring(err)) end
    end
end

---@diagnostic disable-line: param-type-mismatch
local TOGGLE_WIN_FLAGS = ImGuiWindowFlags.NoTitleBar + ImGuiWindowFlags.NoResize +
                         ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.AlwaysAutoResize +
                         ImGuiWindowFlags.NoFocusOnAppearing + ImGuiWindowFlags.NoBackground

function M.renderToggleButton()
    if ptWinX and ptWinY then
        ImGui.SetNextWindowPos(ptWinX, ptWinY, 0) -- 0 = ImGuiCond_None, applies every frame
    else
        ImGui.SetNextWindowPos(100, 100, ImGuiCond.FirstUseEver)
    end
    ImGui.Begin('##pt_toggle', nil, TOGGLE_WIN_FLAGS)
    local ok, err = pcall(function()
        ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 5)
        if M.state.open then
            ImGui.PushStyleColor(ImGuiCol.Button,        0.15, 0.72, 0.15, 0.9)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.25, 0.88, 0.25, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive,  0.10, 0.52, 0.10, 1.0)
        else
            ImGui.PushStyleColor(ImGuiCol.Button,        0.40, 0.40, 0.40, 0.85)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.58, 0.58, 0.58, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive,  0.28, 0.28, 0.28, 1.0)
        end
        local clicked = ImGui.Button('PT', 40, 22)
        ImGui.PopStyleColor(3)
        ImGui.PopStyleVar()

        -- Capture the window's actual position every frame -- this is our
        -- source of truth, and lets us seed ptWinX/ptWinY on the very
        -- first frame before any drag has happened.
        local wx, wy = asXY(ImGui.GetWindowPos())
        if not ptWinX then ptWinX, ptWinY = wx, wy end

        -- Drag-to-move: NoTitleBar means there's no title bar to grab, so
        -- movement is driven off the button itself. While the button is
        -- held (IsItemActive) and the mouse has moved past ImGui's drag
        -- threshold, update our tracked position; SetNextWindowPos above
        -- applies it on the following frame.
        if ImGui.IsItemActive() then
            if ImGui.IsMouseDragging(0, 3.0) then
                local dx, dy = asXY(ImGui.GetMouseDragDelta(0, 3.0))
                ptWinX = wx + dx
                ptWinY = wy + dy
                ImGui.ResetMouseDragDelta(0)
                ptDragging = true
            end
        elseif ptDragging then
            -- Button was just released after a drag -- don't also treat
            -- this as a click that toggles the window open/closed.
            clicked = false
            ptDragging = false
        end

        if clicked then M.state.open = not M.state.open end

        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            ImGui.Text('Pearl Tracker')
            local toonCount = 0
            for _ in pairs(network.peer_data) do toonCount = toonCount + 1 end
            ImGui.Text(string.format('%d toon(s) tracked', toonCount))
            ImGui.EndTooltip()
        end
    end)
    ImGui.End()
    if not ok then printf('\arPT toggle error: %s', tostring(err)) end
end

function M.renderWindow()
    if not M.state.open then return end

    ImGui.SetNextWindowSize(900, 600, ImGuiCond.FirstUseEver)
    local visible = ImGui.Begin('Pearl Tracker##pearltracker')
    if visible then
        local ok, err = pcall(renderContent)
        if not ok then
            popAllColors()
            printf('\arPearlTracker render error: %s', tostring(err))
        end
    end
    ImGui.End()
end

return M