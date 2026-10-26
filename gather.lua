local mq = require('mq')

local M = {}

-- Display/iteration order for colors. MOONLIT and ROSE intentionally sort
-- last (they're the ones most toons finish last), everything else stays
-- alphabetical. ui.lua iterates M.PEARLS directly, so the grouping here
-- IS the on-screen order -- no separate sort step needed elsewhere.
M.COLORS = { 'BLACK', 'BLUE', 'GOLDEN', 'SLATE', 'GREEN', 'PURPLE', 'SILVER', 'MOONLIT', 'ROSE' }

M.PEARLS = {
    { color = 'BLACK',  name = 'Dull Black Pearl of a Goblin' },
    { color = 'BLACK',  name = 'Dull Black Pearl of a Golem' },
    { color = 'BLACK',  name = 'Dull Black Pearl of a Vortex' },
    { color = 'BLACK',  name = 'Dull Black Pearl of an Insect' },
    { color = 'BLUE',   name = 'Dull Blue Pearl of a Colossus' },
    { color = 'BLUE',   name = 'Dull Blue Pearl of a Combatant' },
    { color = 'BLUE',   name = 'Dull Blue Pearl of a Dragon' },
    { color = 'BLUE',   name = 'Dull Blue Pearl of an Aristocrat' },
    { color = 'GOLDEN', name = 'Dull Golden Pearl of a Drake' },
    { color = 'GOLDEN', name = 'Dull Golden Pearl of a Giant' },
    { color = 'GOLDEN', name = 'Dull Golden Pearl of a Wildcat' },
    { color = 'GOLDEN', name = 'Dull Golden Pearl of an Element' },
    { color = 'SLATE',  name = 'Dull Slate Pearl of a Beast' },
    { color = 'SLATE',  name = 'Dull Slate Pearl of a Steed' },
    { color = 'SLATE',  name = 'Dull Slate Pearl of a Wizard' },
    { color = 'SLATE',  name = 'Dull Slate Pearl of an Undead' },
    { color = 'GREEN',  name = 'Dull Green Pearl of a Fungus' },
    { color = 'GREEN',  name = 'Dull Green Pearl of a Gargoyle' },
    { color = 'GREEN',  name = 'Dull Green Pearl of a Reptile' },
    { color = 'GREEN',  name = 'Dull Green Pearl of a Tree' },
    { color = 'PURPLE', name = 'Dull Purple Pearl of a Knight' },
    { color = 'PURPLE', name = 'Dull Purple Pearl of a Shade' },
    { color = 'PURPLE', name = 'Dull Purple Pearl of a Treasure Chest' },
    { color = 'PURPLE', name = 'Dull Purple Pearl of a Vampire' },
    { color = 'SILVER', name = 'Dull Silver Pearl of Dominance' },
    { color = 'SILVER', name = 'Dull Silver Pearl of Fire' },
    { color = 'SILVER', name = 'Dull Silver Pearl of Growth' },
    { color = 'SILVER', name = 'Dull Silver Pearl of Rage' },
    { color = 'MOONLIT', name = 'Dull Moonlit Pearl of Singularity' },
    { color = 'MOONLIT', name = 'Dull Moonlit Pearl of the Mightforge' },
    { color = 'MOONLIT', name = 'Dull Moonlit Pearl of the Primewyrm' },
    { color = 'MOONLIT', name = 'Dull Moonlit Pearl of the Warshaper' },
    { color = 'ROSE',   name = 'Dull Rose Pearl of a Forsaken Duelist' },
    { color = 'ROSE',   name = 'Dull Rose Pearl of a Grand Dame' },
    { color = 'ROSE',   name = 'Dull Rose Pearl of a Phantom Hunter' },
    { color = 'ROSE',   name = 'Dull Rose Pearl of an Eternal Warlord' },
}

M.FLAWLESS_SEARCH = {
    BLACK   = 'Flawless Black Pearl',
    BLUE    = 'Flawless Blue Pearl',
    GOLDEN  = 'Flawless Golden Pearl',
    GREEN   = 'Flawless Green Pearl',
    MOONLIT = 'Flawless Moonlit Pearl',
    PURPLE  = 'Flawless Purple Pearl',
    ROSE    = 'Flawless Rose Pearl',
    SILVER  = 'Flawless Silver Pearl',
    SLATE   = 'Flawless Slate Pearl', -- Added missing Slate search entry
}

-- Strips "Dull <Color> Pearl of a/an/the " down to just the source name,
-- e.g. "Dull Black Pearl of an Insect" -> "Insect". Used only for display
-- in the expanded per-color breakdown.
function M.shortLabel(entry)
    local label = entry.name:gsub('^Dull %a+ Pearl of ', '')
    label = label:gsub('^an? ', '')
    label = label:gsub('^the ', '')
    return label
end

-- Returns { have = n, total = 4, flawless = bool } for one toon's data
-- and one color. `toonData` may be nil (toon not seen yet / no data).
function M.colorStatus(toonData, color)
    local have, total = 0, 0
    for _, entry in ipairs(M.PEARLS) do
        if entry.color == color then
            total = total + 1
            if toonData and toonData.pearls and toonData.pearls[entry.name] then
                have = have + 1
            end
        end
    end
    local flawless = toonData ~= nil and toonData.flawless ~= nil and toonData.flawless[color] == true
    return { have = have, total = total, flawless = flawless }
end

-- Returns done, total flawless-colors-completed counts for one toon.
function M.totalFlawless(toonData)
    local done = 0
    for _, color in ipairs(M.COLORS) do
        if toonData and toonData.flawless and toonData.flawless[color] then
            done = done + 1
        end
    end
    return done, #M.COLORS
end

function M.gatherMyPearls()
    local result = { name = mq.TLO.Me.Name(), pearls = {}, flawless = {} }
    for _, entry in ipairs(M.PEARLS) do
        local item = mq.TLO.FindItem('=' .. entry.name)
        if item and item() then
            result.pearls[entry.name] = true
        end
    end
    for color, searchStr in pairs(M.FLAWLESS_SEARCH) do
        local item = mq.TLO.FindItem(searchStr)
        if item and item() then
            result.flawless[color] = true
        end
    end
    return result
end

return M