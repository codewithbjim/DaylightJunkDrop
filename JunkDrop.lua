-- Junk Drop (DaylightUI Plugin): one key press deletes the cheapest junk stack in the bags.
-- Junk = gray items, items on your own junk lists (one for this character, one
-- for all characters; both are read), plus anything marked as junk in Daylight
-- UI's bags (when that's switched on). Items locked in Daylight UI's bags are
-- never touched.
-- Built on DaylightUI.API only; Daylight UI's own files are not changed.

local NAME = "DaylightJunkDrop"

local DEFAULTS = {
    maxSilver = 10,         -- only stacks worth this much or less (0 = no cap)
    includeMarked = true,   -- items marked as junk in Daylight UI's bags count too
    confirm = false,        -- ask before each delete
}

_G.BINDING_NAME_DAYLIGHTJUNKDROP_DROP = "Drop cheapest junk"

local API = DaylightUI and DaylightUI.API
local me

local function say(msg)
    print("|cffa335eeJunk Drop|r: " .. msg)
end

local function setting(key)
    local v = API and API.GetSetting(NAME, key)
    if v == nil then return DEFAULTS[key] end
    return v
end

local function bagsSetting(key)
    if not (API and API.IsModuleEnabled("Bags")) then return nil end
    return API.GetSetting("Bags", key)
end

local coins = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString

local function sellPrice(link, itemID)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not getInfo then return nil end
    local ok, _, _, _, _, _, _, _, _, _, _, price = pcall(getInfo, link or itemID)
    if ok and type(price) == "number" then return price end
    return nil
end

-- Your lists: itemID -> true. DaylightJunkDropDB is shared by all your
-- characters, DaylightJunkDropCharDB is this character's own. Both junk lists
-- count. The ignored list (shared) is never deleted and never suggested.
local lists = { char = {}, all = {}, ignore = {} }

local function loadLists()
    if type(DaylightJunkDropDB) ~= "table" then DaylightJunkDropDB = {} end
    if type(DaylightJunkDropCharDB) ~= "table" then DaylightJunkDropCharDB = {} end
    if type(DaylightJunkDropDB.items) ~= "table" then DaylightJunkDropDB.items = {} end
    if type(DaylightJunkDropDB.ignored) ~= "table" then DaylightJunkDropDB.ignored = {} end
    if type(DaylightJunkDropCharDB.items) ~= "table" then DaylightJunkDropCharDB.items = {} end
    lists.all = DaylightJunkDropDB.items
    lists.ignore = DaylightJunkDropDB.ignored
    lists.char = DaylightJunkDropCharDB.items
end

local function onList(itemID)
    return lists.char[itemID] == true or lists.all[itemID] == true
end

local function inEquipmentSet(bag, slot)
    local fn = C_Container.GetContainerItemEquipmentSetInfo
    if type(fn) ~= "function" then return false end
    local ok, yes = pcall(fn, bag, slot)
    return ok and yes == true
end

local function lastBag()
    return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
end

-- Is this slot's item junk we may delete? Returns its stack value in copper.
local function junkValue(bag, slot, info, pins, locks, lockSets)
    if info.isLocked or type(info.itemID) ~= "number" then return nil end
    if locks and locks[info.itemID] == true then return nil end
    if lists.ignore[info.itemID] then return nil end   -- ignored: never deleted, even gray
    if lockSets and inEquipmentSet(bag, slot) then return nil end

    local marked = pins and pins[info.itemID] == "junk"
    if info.quality ~= 0 and not onList(info.itemID)
        and not (marked and setting("includeMarked")) then return nil end

    local count = info.stackCount or 1
    if info.hasNoValue then return 0 end
    local price = sellPrice(info.hyperlink, info.itemID)
    if not price then return nil end   -- not loaded yet: can't check it against the cap
    return price * count
end

-- The cheapest junk stack under the cap: { bag, slot, itemID, link, count, value }.
local function findCheapest()
    local pins = bagsSetting("pins")
    local locks = bagsSetting("locks")
    local lockSets = bagsSetting("lockSets") == true
    if type(pins) ~= "table" then pins = nil end
    if type(locks) ~= "table" then locks = nil end

    local cap = tonumber(setting("maxSilver")) or 0
    cap = cap > 0 and cap * 100 or nil

    local best
    for bag = 0, lastBag() do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if type(info) == "table" then
                local value = junkValue(bag, slot, info, pins, locks, lockSets)
                -- Items on your own lists skip the cap: you picked them yourself.
                local capped = cap and not onList(info.itemID)
                if value and (not capped or value <= cap) and (not best or value < best.value) then
                    best = { bag = bag, slot = slot, itemID = info.itemID, link = info.hyperlink,
                             count = info.stackCount or 1, value = value }
                end
            end
        end
    end
    return best
end

local function describe(item)
    local text = item.link or ("item " .. item.itemID)
    if item.count > 1 then text = text .. "x" .. item.count end
    return text .. " (" .. (item.value > 0 and coins(item.value) or "no value") .. ")"
end

-- Deletes the item, checking right before that the slot still holds it and the
-- cursor really picked it up. Never deletes anything else.
local function destroy(item)
    if InCombatLockdown() or GetCursorInfo() then return end
    local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
    if type(info) ~= "table" or info.itemID ~= item.itemID or info.isLocked then
        say("that item moved; press again.")
        return
    end
    C_Container.PickupContainerItem(item.bag, item.slot)
    local kind, id = GetCursorInfo()
    if kind ~= "item" or id ~= item.itemID then
        ClearCursor()
        return
    end
    DeleteCursorItem()
    say("deleted " .. describe(item) .. ".")
end

StaticPopupDialogs["DAYLIGHTJUNKDROP_CONFIRM"] = {
    text = "Delete %s?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, item) destroy(item) end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
}

function DaylightJunkDrop_Drop()
    if InCombatLockdown() then
        say("not during a fight.")
        return
    end
    if GetCursorInfo() then
        say("your cursor is holding something.")
        return
    end
    local item = findCheapest()
    if not item then
        local cap = tonumber(setting("maxSilver")) or 0
        say(cap > 0 and ("no junk worth " .. coins(cap * 100) .. " or less.") or "no junk to delete.")
        return
    end
    if setting("confirm") then
        StaticPopup_Show("DAYLIGHTJUNKDROP_CONFIRM", describe(item), nil, item)
    else
        destroy(item)
    end
end

-- A "Junk Drop" macro for the action bars. Making it again reuses the one already
-- there, so it can be picked up as often as you like.
local MACRO_NAME = "Junk Drop"
local MACRO_ICON = "INV_Misc_Bag_08"
local MACRO_BODY = "/dropjunk"

function DaylightJunkDrop_MakeMacro()
    if InCombatLockdown() then
        say("not during a fight.")
        return
    end
    if type(CreateMacro) ~= "function" then return end

    local index = GetMacroIndexByName(MACRO_NAME)
    if index and index > 0 then
        local body = GetMacroBody(index)
        if type(body) == "string" and strtrim(body) ~= MACRO_BODY then
            say("you already have a different macro named " .. MACRO_NAME .. ". Rename it in /macro first.")
            return
        end
    else
        local account, perChar = GetNumMacros()
        local maxAccount = MAX_ACCOUNT_MACROS or 120
        local maxChar = MAX_CHARACTER_MACROS or 18
        local forChar
        if (account or 0) < maxAccount then
            forChar = nil
        elseif (perChar or 0) < maxChar then
            forChar = 1
        else
            say("your macro list is full. Delete one in /macro and try again.")
            return
        end
        local ok, made = pcall(CreateMacro, MACRO_NAME, MACRO_ICON, MACRO_BODY, forChar)
        if not ok or not made or made == 0 then
            say("couldn't make the macro.")
            return
        end
        index = made
        say("made the |cffffd200" .. MACRO_NAME .. "|r macro" .. (forChar and " (this character only)" or "") .. ".")
    end

    if GetCursorInfo() then ClearCursor() end
    pcall(PickupMacro, index)
    say("click an action bar slot to put it there. It's also in /macro.")
end


-- Junk lists ------------------------------------------------------------------
-- An item sits on one list at a time. The shared list already covers this
-- character, so putting an item there takes it off this character's list.

local LIST_NAME = { char = "this character's junk list", all = "the junk list for all characters",
    ignore = "your ignored items" }
local OTHER = { char = "all", all = "char" }

-- name, link, quality, icon, sell price. The name is nil until the game has the item.
local function itemInfo(itemID)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local ok, name, link, quality, _, _, _, _, _, _, icon, price = pcall(getInfo, itemID)
    if not ok then name, link, quality, icon, price = nil, nil, nil, nil, nil end
    if not icon then
        local iconOf = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
        if iconOf then
            local ok2, tex = pcall(iconOf, itemID)
            if ok2 then icon = tex end
        end
    end
    return name, link, quality, icon, price
end

local function itemLabel(itemID)
    local _, link = itemInfo(itemID)
    return link or ("item " .. itemID)
end

-- Redraws Daylight UI's options page when it's open, so the list editor shows
-- changes made from chat too. Daylight UI has no API call for it, so it's
-- checked before use and skipped if it ever changes.
local function refreshPanel()
    local panel = DaylightUI and DaylightUI.OptionsPanel
    if type(panel) ~= "table" or type(panel.IsShown) ~= "function" or type(panel.Refresh) ~= "function" then return end
    local ok, shown = pcall(panel.IsShown)
    if ok and shown then pcall(panel.Refresh) end
end

local refreshQueued
local function refreshSoon()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0.2, function()
        refreshQueued = nil
        refreshPanel()
    end)
end

-- List changes. Each returns ok, and a sentence for the player.
local function listAdd(scope, id)
    if lists[scope][id] then
        return false, itemLabel(id) .. " is already on " .. LIST_NAME[scope] .. "."
    end
    if scope == "char" and lists.all[id] then
        return false, itemLabel(id) .. " is already on the list for all characters, which covers this one."
    end
    local was = lists.ignore[id] and " (no longer ignored)" or ""
    lists.ignore[id] = nil
    lists[OTHER[scope]][id] = nil
    lists[scope][id] = true
    refreshPanel()
    return true, "added " .. itemLabel(id) .. " to " .. LIST_NAME[scope] .. was .. "."
end

-- Ignored: off both junk lists, out of the bag picker, never deleted.
local function listIgnore(id)
    if lists.ignore[id] then return false, itemLabel(id) .. " is already ignored." end
    lists.char[id], lists.all[id] = nil, nil
    lists.ignore[id] = true
    refreshPanel()
    return true, "ignoring " .. itemLabel(id) .. ": Junk Drop won't suggest or delete it."
end

local function listMove(id, to)
    lists[OTHER[to]][id] = nil
    lists[to][id] = true
    refreshPanel()
end

local function listRemove(id)
    local from = {}
    if lists.char[id] then lists.char[id] = nil; from[#from + 1] = LIST_NAME.char end
    if lists.all[id] then lists.all[id] = nil; from[#from + 1] = LIST_NAME.all end
    if lists.ignore[id] then lists.ignore[id] = nil; from[#from + 1] = LIST_NAME.ignore end
    if #from == 0 then return false, itemLabel(id) .. " isn't on your lists." end
    refreshPanel()
    return true, "removed " .. itemLabel(id) .. " from " .. table.concat(from, " and ") .. "."
end

-- A list's itemIDs, sorted by name.
local function sortedIds(scope)
    local ids = {}
    for id, on in pairs(lists[scope]) do
        if on == true and type(id) == "number" then ids[#ids + 1] = id end
    end
    table.sort(ids, function(a, b)
        local na, nb = (itemInfo(a) or ""):lower(), (itemInfo(b) or ""):lower()
        if na ~= nb then return na < nb end
        return a < b
    end)
    return ids
end

-- The itemID meant by what was typed: an item link (shift-click an item into the
-- chat line), an item ID, an item name in your bags, or nothing for the item
-- held on the cursor.
local function itemFromText(text)
    text = strtrim(tostring(text or ""))
    if text == "" then
        local kind, id = GetCursorInfo()
        if kind == "item" and type(id) == "number" then return id end
        return nil, "pick an item up, shift-click one into the chat line, or type its name."
    end
    local id = tonumber(text:match("|Hitem:(%d+)") or text:match("^item:(%d+)") or text:match("^(%d+)$"))
    if id then return id end

    local want = text:lower()
    for bag = 0, lastBag() do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local name = type(info) == "table" and type(info.hyperlink) == "string" and info.hyperlink:match("%[(.-)%]")
            if name and name:lower() == want then return info.itemID end
        end
    end
    return nil, "no item called \"" .. text .. "\" in your bags. Drop it in or shift-click it instead."
end

-- Chat commands ---------------------------------------------------------------

function DaylightJunkDrop_ListAdd(scope, text)
    local id, msg = itemFromText(text)
    if id then msg = select(2, listAdd(scope, id)) end
    say(msg)
    if GetCursorInfo() then ClearCursor() end
end

function DaylightJunkDrop_ListIgnore(text)
    local id, msg = itemFromText(text)
    if id then msg = select(2, listIgnore(id)) end
    say(msg)
    if GetCursorInfo() then ClearCursor() end
end

function DaylightJunkDrop_ListRemove(text)
    local id, msg = itemFromText(text)
    if id then msg = select(2, listRemove(id)) end
    say(msg)
    if GetCursorInfo() then ClearCursor() end
end

local function showList(scope, title)
    local ids = sortedIds(scope)
    if #ids == 0 then
        say(title .. ": empty.")
        return
    end
    say(title .. " (" .. #ids .. "):")
    for _, id in ipairs(ids) do print("   " .. itemLabel(id)) end
end

function DaylightJunkDrop_ListShow()
    showList("char", "This character")
    showList("all", "All characters")
    showList("ignore", "Ignored")
end

function DaylightJunkDrop_ListClear(scope)
    local n = 0
    for _ in pairs(lists[scope]) do n = n + 1 end
    wipe(lists[scope])
    refreshPanel()
    say("cleared " .. LIST_NAME[scope] .. " (" .. n .. " item" .. (n == 1 and "" or "s") .. ").")
end

-- The list editor on the options page ------------------------------------------
-- A box to drop an item into (or type its name) with Add / For all / Ignore.
-- Under it the white items in your bags, cheapest first, with the Ignored list
-- beside them when the window is wide enough (under them when it isn't), then
-- both junk lists. Rows are flat: icon, name, price, and quiet text actions
-- that light up on hover.

local PAD, TOP, INPUT_H, NOTE_H, HEAD_H, LINE = 14, 8, 24, 20, 28, 24
local BTN_H, ADD_W, ALL_W, IGN_W = 20, 44, 58, 56
local MAIN_W = 520            -- the main column stays this narrow on a wide window
local SIDE_W, SIDE_MIN, GAP = 250, 190, 24   -- the Ignored column, when it fits beside
local BAG_ROWS = 6            -- bag items shown before "Show all"

local function tint(region, key)
    local c = API.Colors()[key]
    if c then region:SetTextColor(c[1], c[2], c[3]) end
end

local function showTip(owner, text)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(text, 1, 1, 1, 1, true)
    GameTooltip:Show()
end

local function hoverTip(frame, text)
    frame:HookScript("OnEnter", function(self) showTip(self, text) end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function addFromEditor(row, scope, id)
    local ok, msg
    if scope == "ignore" then ok, msg = listIgnore(id) else ok, msg = listAdd(scope, id) end
    row.msg, row.msgOk = (msg or ""):gsub("^%l", string.upper), ok
    refreshPanel()
    return ok
end

-- What each kind of row can do: { key, label, tip, run(id, row) }, right to left.
local ACTIONS = {
    bag = {
        { "ignore", "Ignore", "Stop suggesting it. Junk Drop never deletes ignored items.",
          function(id, row) addFromEditor(row, "ignore", id) end },
        { "forAll", "For all", "Add it to the junk list all your characters read.",
          function(id, row) addFromEditor(row, "all", id) end },
        { "add", "Add", "Add it to this character's junk list.",
          function(id, row) addFromEditor(row, "char", id) end },
    },
    char = {
        { "remove", "Remove", "Take it off the list.", function(id) listRemove(id) end },
        { "move", "Share", "Move it to the list for all characters.", function(id) listMove(id, "all") end },
    },
    all = {
        { "remove", "Remove", "Take it off the list.", function(id) listRemove(id) end },
        { "move", "Only here", "Move it to this character's list, so your other characters keep it.",
          function(id) listMove(id, "char") end },
    },
    ignore = {
        { "remove", "Unignore", "Stop ignoring it: it can be suggested and deleted again.",
          function(id) listRemove(id) end },
    },
}

local SECTIONS = {
    char = { title = "This character", empty = "Nothing yet. Add an item above." },
    all = { title = "All characters", empty = "Nothing yet. Items here are junk on every character." },
    ignore = { title = "Ignored", empty = "Nothing ignored.", noPrice = true },
}

-- A quiet text button: label color at rest, white on hover.
local function textAction(line, label, tip, onClick)
    local b = CreateFrame("Button", nil, line)
    b:SetHeight(LINE)
    b.label = API.Text(b, "small", "CENTER")
    b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.label:SetText(label)
    local w = b.label:GetStringWidth()
    if type(w) ~= "number" or w <= 0 then w = #label * 6 end
    b:SetWidth(math.ceil(w) + 12)
    tint(b.label, "LABEL")
    b:SetScript("OnEnter", function(self)
        self.label:SetTextColor(1, 1, 1)
        line.hl:Show()
        showTip(self, tip)
    end)
    b:SetScript("OnLeave", function(self)
        tint(self.label, "LABEL")
        line.hl:Hide()
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", onClick)
    return b
end

-- One row: icon, name, price, then the kind's actions on the right.
local function makeLine(row, kind, noPrice)
    local line = CreateFrame("Frame", nil, row)
    line:SetHeight(LINE)
    line:EnableMouse(true)

    line.stripe = line:CreateTexture(nil, "BACKGROUND")
    line.stripe:SetAllPoints(line)
    line.stripe:SetColorTexture(1, 1, 1, 0.03)
    line.hl = line:CreateTexture(nil, "BORDER")
    line.hl:SetAllPoints(line)
    line.hl:SetColorTexture(1, 1, 1, 0.06)
    line.hl:Hide()

    line.icon = line:CreateTexture(nil, "ARTWORK")
    line.icon:SetSize(LINE - 6, LINE - 6)
    line.icon:SetPoint("LEFT", line, "LEFT", 4, 0)
    line.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    line.act = {}
    local right = nil
    for _, a in ipairs(ACTIONS[kind]) do
        local key, label, tip, run = a[1], a[2], a[3], a[4]
        local b = textAction(line, label, tip, function()
            if line.itemID then run(line.itemID, row) end
        end)
        if right then b:SetPoint("RIGHT", right, "LEFT", 0, 0) else b:SetPoint("RIGHT", line, "RIGHT", -2, 0) end
        line.act[key] = b
        right = b
    end

    line.name = API.Text(line, "body", "LEFT")
    line.name:SetPoint("LEFT", line.icon, "RIGHT", 8, 0)
    line.name:SetWordWrap(false)
    if noPrice then
        line.name:SetPoint("RIGHT", right, "LEFT", -6, 0)
    else
        line.price = API.Text(line, "small", "RIGHT")
        line.price:SetPoint("RIGHT", right, "LEFT", -8, 0)
        line.name:SetPoint("RIGHT", line.price, "LEFT", -8, 0)
    end

    line:SetScript("OnEnter", function(self)
        self.hl:Show()
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local _, link = itemInfo(self.itemID)
        GameTooltip:SetHyperlink(link or ("item:" .. self.itemID))
        GameTooltip:Show()
    end)
    line:SetScript("OnLeave", function(self)
        self.hl:Hide()
        GameTooltip:Hide()
    end)
    return line
end

-- name (quality color, or "Loading..." until the game has it), count, price text.
local function fillLine(line, id, count, price)
    line.itemID = id
    local name, _, quality, icon = itemInfo(id)
    line.icon:SetTexture(icon or 134400)
    local text
    if name then
        local q = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
        text = (q and q.hex or "|cffffffff") .. name .. "|r"
    else
        text = "|cff888888Loading item " .. id .. "...|r"
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    end
    if count and count > 1 then text = text .. "  |cff9d9d9dx" .. count .. "|r" end
    line.name:SetText(text)
    if line.price then
        line.price:SetText(type(price) == "number" and price > 0 and coins(price) or "")
    end
end

-- White items in the bags that could go on a list, one entry per item (stacks
-- added up), cheapest stack total first: { id, count, value }. Skips listed and
-- ignored items, items locked in Daylight UI's bags, quest items, and items
-- with no sell price (Hearthstone, conjured food, tools).
local function isQuestItem(bag, slot)
    local fn = C_Container.GetContainerItemQuestInfo
    if type(fn) ~= "function" then return false end
    local ok, q = pcall(fn, bag, slot)
    return ok and type(q) == "table" and (q.isQuestItem or q.questID) and true or false
end

local function whiteBagItems()
    local locks = bagsSetting("locks")
    if type(locks) ~= "table" then locks = nil end
    local byId, all = {}, {}
    for bag = 0, lastBag() do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = type(info) == "table" and info.itemID
            if type(id) == "number" and info.quality == 1 and not onList(id) and not lists.ignore[id]
                and not (locks and locks[id] == true) and not isQuestItem(bag, slot) then
                local e = byId[id]
                if not e then
                    e = { id = id, count = 0, noValue = info.hasNoValue }
                    byId[id] = e
                    all[#all + 1] = e
                end
                e.count = e.count + (info.stackCount or 1)
            end
        end
    end
    local out = {}
    for _, e in ipairs(all) do
        local name, _, _, _, price = itemInfo(e.id)
        e.name = name or ""
        e.value = price and price * e.count or nil
        if not e.noValue and price ~= 0 then out[#out + 1] = e end
    end
    table.sort(out, function(a, b)
        if (a.value == nil) ~= (b.value == nil) then return a.value ~= nil end   -- unknown prices last
        if a.value and a.value ~= b.value then return a.value < b.value end
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return out
end

-- Layout helpers: everything is placed from the row's top left, x across and y down.
local function place(row, frame, x, y, w)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", row, "TOPLEFT", PAD + x, -y)
    if w then frame:SetWidth(w) end
end

-- A section's small caps title and hairline; returns the y below it.
local function placeHead(row, sec, x, y, w, text)
    sec.head:ClearAllPoints()
    sec.head:SetPoint("BOTTOMLEFT", row, "TOPLEFT", PAD + x, -(y + HEAD_H - 8))
    sec.head:SetWidth(w)
    sec.head:SetText(text)
    place(row, sec.rule, x, y + HEAD_H - 4, w)
    return y + HEAD_H
end

-- Draws a list of rows from a pool; entries are { id, count, price }. Returns the y below.
local function placeLines(row, sec, kind, entries, x, y, w)
    for i, e in ipairs(entries) do
        local line = sec.pool[i]
        if not line then
            line = makeLine(row, kind, SECTIONS[kind] and SECTIONS[kind].noPrice)
            sec.pool[i] = line
        end
        place(row, line, x, y, w)
        fillLine(line, e.id, e.count, e.price)
        line.stripe:SetShown(i % 2 == 0)
        line.hl:Hide()
        line:Show()
        y = y + LINE
    end
    for i = #entries + 1, #sec.pool do
        sec.pool[i]:Hide()
        sec.pool[i].itemID = nil
    end
    if #entries == 0 then
        place(row, sec.empty, x + 4, y + 5, w - 4)
        sec.empty:Show()
        y = y + LINE
    else
        sec.empty:Hide()
    end
    return y
end

local function newSection(row, emptyText)
    local sec = { pool = {} }
    sec.head = API.Text(row, "small", "LEFT")
    tint(sec.head, "LABEL")
    sec.rule = row:CreateTexture(nil, "ARTWORK")
    sec.rule:SetHeight(1)
    sec.rule:SetColorTexture(1, 1, 1, 0.07)
    sec.empty = API.Text(row, "body", "LEFT")
    sec.empty:SetWordWrap(false)
    tint(sec.empty, "OFF")
    sec.empty:SetText(emptyText)
    return sec
end

-- Shift-clicking an item while the editor's box has focus puts it in the box,
-- like the chat line.
local editorRow
if type(hooksecurefunc) == "function" and type(ChatEdit_InsertLink) == "function" then
    hooksecurefunc("ChatEdit_InsertLink", function(link)
        local row = editorRow
        if type(link) == "string" and row and row.input:IsVisible() and row.input:HasFocus() then
            row.TakeLink(link)
        end
    end)
end

local listEditor = {
    type = "custom", label = "Your junk lists", noSearch = true,
    build = function(row)
        row.secs = {
            bag = newSection(row, "No sellable white items in your bags that aren't on a list."),
            char = newSection(row, SECTIONS.char.empty),
            all = newSection(row, SECTIONS.all.empty),
            ignore = newSection(row, SECTIONS.ignore.empty),
        }
        -- Lay out again when the options window is resized (one column or two).
        row:HookScript("OnSizeChanged", function(_, w)
            if type(w) == "number" and math.abs(w - (row.laidW or 0)) > 1 then refreshSoon() end
        end)

        row.input = API.Input(row, { hint = "Drop an item here, or type its name or item ID", maxLetters = 200 })
        row.ignore = API.Button(row, "Ignore", INPUT_H)
        row.ignore:SetWidth(IGN_W)
        hoverTip(row.ignore, "Junk Drop never deletes it (even if it's gray) and stops suggesting it.")
        row.addAll = API.Button(row, "For all", INPUT_H)
        row.addAll:SetWidth(ALL_W)
        row.addAll:SetPoint("RIGHT", row.ignore, "LEFT", -6, 0)
        hoverTip(row.addAll, "Add it to the junk list all your characters read.")
        row.add = API.Button(row, "Add", INPUT_H)
        row.add:SetWidth(ADD_W)
        row.add:SetPoint("RIGHT", row.addAll, "LEFT", -6, 0)
        hoverTip(row.add, "Add it to this character's junk list. Enter does the same.")
        row.note = API.Text(row, "small", "LEFT")

        -- An item dropped in (or clicked in while held) fills the box with its name.
        local function take()
            local kind, id = GetCursorInfo()
            if kind ~= "item" or type(id) ~= "number" then return end
            ClearCursor()
            local name = itemInfo(id)
            row.pending, row.pendingText = id, name or ("item:" .. id)
            row.input:SetText(row.pendingText)
            row.input:SetFocus()
        end
        row.input:HookScript("OnReceiveDrag", take)
        row.input:HookScript("OnMouseDown", take)
        function row.TakeLink(link)
            local id = tonumber(link:match("|Hitem:(%d+)"))
            if not id then return end
            row.pending, row.pendingText = id, link:match("%[(.-)%]") or ("item:" .. id)
            row.input:SetText(row.pendingText)
        end
        editorRow = row

        local function add(scope)
            local text = row.input:GetText()
            local id, msg
            if row.pending and text == row.pendingText then
                id = row.pending
            else
                id, msg = itemFromText(text)
            end
            if GetCursorInfo() then ClearCursor() end
            if not id then
                row.msg, row.msgOk = (msg or ""):gsub("^%l", string.upper), false
                refreshPanel()
                return
            end
            if addFromEditor(row, scope, id) then
                row.input:SetText("")
                row.pending, row.pendingText = nil, nil
            end
        end
        row.add:SetScript("OnClick", function() add("char") end)
        row.addAll:SetScript("OnClick", function() add("all") end)
        row.ignore:SetScript("OnClick", function() add("ignore") end)
        row.input:HookScript("OnEnterPressed", function() add("char") end)

        row.bagMore = API.Button(row, "Show all", BTN_H)
        row.bagMore:SetWidth(110)
        row.bagMore:SetScript("OnClick", function()
            row.bagAll = not row.bagAll
            refreshPanel()
        end)
    end,
    update = function(row)
        -- Column widths: the main column up to MAIN_W, the Ignored column beside
        -- it when there's room for at least SIDE_MIN.
        local rw = row:GetWidth()
        row.laidW = type(rw) == "number" and rw or 0
        local avail = row.laidW > 0 and (row.laidW - 2 * PAD) or MAIN_W
        local mainW = math.max(200, math.min(MAIN_W, avail))
        local sideW = math.min(SIDE_W, avail - mainW - GAP)
        local beside = sideW >= SIDE_MIN
        row.beside = beside

        -- The add box.
        place(row, row.input, 0, TOP, mainW - (IGN_W + 6 + ALL_W + 6 + ADD_W + 6))
        row.ignore:ClearAllPoints()
        row.ignore:SetPoint("TOPLEFT", row, "TOPLEFT", PAD + mainW - IGN_W, -TOP)
        local y = TOP + INPUT_H + 6
        if row.msg and row.msg ~= "" then
            place(row, row.note, 0, y + 4, mainW)
            row.note:SetText(row.msg)
            tint(row.note, row.msgOk and "GOOD" or "WARN")
            row.note:Show()
            y = y + NOTE_H
        else
            row.note:Hide()
        end

        -- White items in the bags, cheapest first.
        local secs = row.secs
        local bagItems = whiteBagItems()
        local top = y
        y = placeHead(row, secs.bag, 0, y, mainW, "WHITE ITEMS IN YOUR BAGS, CHEAPEST FIRST  |cffffffff" .. #bagItems .. "|r")
        local shown = {}
        for i = 1, (row.bagAll and #bagItems or math.min(#bagItems, BAG_ROWS)) do
            local e = bagItems[i]
            shown[i] = { id = e.id, count = e.count, price = e.value }
        end
        y = placeLines(row, secs.bag, "bag", shown, 0, y, mainW)
        if #bagItems > BAG_ROWS then
            if row.bagMore.text then
                row.bagMore.text:SetText(row.bagAll and "Show fewer" or ("Show all " .. #bagItems))
            end
            place(row, row.bagMore, 0, y + 4)
            row.bagMore:Show()
            y = y + BTN_H + 8
        else
            row.bagMore:Hide()
        end

        -- Ignored: beside the bag list, or under it.
        local function entries(scope)
            local out = {}
            for i, id in ipairs(sortedIds(scope)) do
                local _, _, _, _, price = itemInfo(id)
                out[i] = { id = id, price = price }
            end
            return out
        end
        local ignored = entries("ignore")
        if beside then
            local x = mainW + GAP
            local iy = placeHead(row, secs.ignore, x, top, sideW, "IGNORED  |cffffffff" .. #ignored .. "|r")
            iy = placeLines(row, secs.ignore, "ignore", ignored, x, iy, sideW)
            y = math.max(y, iy)
        else
            y = placeHead(row, secs.ignore, 0, y + 6, mainW, "IGNORED  |cffffffff" .. #ignored .. "|r")
            y = placeLines(row, secs.ignore, "ignore", ignored, 0, y, mainW)
        end
        y = y + 6

        -- The two junk lists.
        for _, scope in ipairs({ "char", "all" }) do
            local list = entries(scope)
            y = placeHead(row, secs[scope], 0, y, mainW,
                SECTIONS[scope].title:upper() .. "  |cffffffff" .. #list .. "|r")
            y = placeLines(row, secs[scope], scope, list, 0, y, mainW)
        end
        row.total = y + 10
    end,
    height = function(row) return row.total or 200 end,
}

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("GET_ITEM_INFO_RECEIVED")
loader:RegisterEvent("BAG_UPDATE_DELAYED")
loader:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" then
        if arg == NAME then loadLists() end
    elseif event == "BAG_UPDATE_DELAYED" then
        refreshSoon()   -- the bag picker follows what's in the bags
    elseif type(arg) == "number" and (lists.char[arg] or lists.all[arg]) then
        refreshSoon()   -- a listed item's name and icon just arrived
    end
end)

-- Daylight UI hookup: its own section under Plugins in /dui, and /dui dropjunk.
if API and API.major == 1 then
    DaylightUI:RegisterPlugin(NAME, {
        needs = { 1, 1 },
        icon = "Interface\\AddOns\\DaylightJunkDrop\\icon.png",
        color = "c9a66b",
        short = "Junk",
        blurb = "One key press deletes the cheapest junk stack.",
    })
    DaylightUI:RegisterModule(NAME, {
        plugin = NAME,
        label = "Junk Drop",
        defaults = DEFAULTS,
        options = { pages = {
            { id = "main", label = "Junk Drop",
              desc = "One key press deletes the cheapest junk stack in your bags.",
              groups = {
                  { label = "Key", items = {
                      { type = "text", label = "Set the key under Esc > Options > Keybindings > Daylight UI > Drop cheapest junk. Each press deletes one stack. /dui dropjunk does the same." },
                      { type = "button", label = "Action bar macro", text = "Make macro",
                        desc = "Makes a Junk Drop macro and puts it on your cursor: click an action bar slot to place it. Each click of the macro deletes one stack.",
                        func = function() DaylightJunkDrop_MakeMacro() end },
                  } },
                  { label = "What counts", items = {
                      { type = "slider", key = "maxSilver", label = "Most it may be worth", min = 0, max = 200, step = 1,
                        desc = "In silver, for the whole stack. Pricier junk is left for a vendor. 0 = no cap. Items on your junk lists ignore it." },
                      { type = "toggle", key = "includeMarked", label = "Include items marked as junk",
                        desc = "Items you put in the Junk group of Daylight UI's bags count too, not just gray ones." },
                      { type = "text", label = "Items you lock in Daylight UI's bags are never deleted." },
                  } },
                  { label = "Your junk lists",
                    desc = "Items on these lists count as junk whatever their color or price. Pick white items from your bags below, cheapest first, or drop any item in the box (or type its name). Add puts it on this character's list, For all on the list every character reads. Ignore hides it from the suggestions and keeps it safe from Junk Drop, even if it's gray.",
                    items = { listEditor } },
                  { label = "Safety", items = {
                      { type = "toggle", key = "confirm", label = "Ask before deleting",
                        desc = "A yes/no box names the item before it goes." },
                  } },
              } },
        } },
    })
    me = API.For(NAME)

    me.RegisterCommand("dropjunk", function(rest) DaylightJunkDrop_Command(rest) end,
        "Delete the cheapest junk stack. /dui dropjunk help lists the other commands.")
end

local HELP = {
    "/dropjunk - delete the cheapest junk stack.",
    "/dropjunk macro - make an action bar macro.",
    "/dropjunk add <item> - put an item on this character's junk list.",
    "/dropjunk addall <item> - put an item on the junk list for all characters.",
    "/dropjunk ignore <item> - never delete or suggest an item, even a gray one.",
    "/dropjunk remove <item> - take an item off every list (also stops ignoring it).",
    "/dropjunk list - show your lists.",
    "/dropjunk clear - empty this character's list. clearall empties the shared one, clearignored the ignored one.",
    "<item> = shift-click it into the chat line, its name, its item ID, or leave it out to use the item on your cursor.",
}

function DaylightJunkDrop_Command(rest)
    rest = strtrim(tostring(rest or ""))
    local word, arg = rest:match("^(%S+)%s*(.-)$")
    word = (word or ""):lower()
    if word == "macro" then
        DaylightJunkDrop_MakeMacro()
    elseif word == "add" then
        DaylightJunkDrop_ListAdd("char", arg)
    elseif word == "addall" then
        DaylightJunkDrop_ListAdd("all", arg)
    elseif word == "remove" or word == "rem" or word == "del" then
        DaylightJunkDrop_ListRemove(arg)
    elseif word == "ignore" then
        DaylightJunkDrop_ListIgnore(arg)
    elseif word == "clearignored" then
        DaylightJunkDrop_ListClear("ignore")
    elseif word == "list" then
        DaylightJunkDrop_ListShow()
    elseif word == "clear" then
        DaylightJunkDrop_ListClear("char")
    elseif word == "clearall" then
        DaylightJunkDrop_ListClear("all")
    elseif word == "help" or word == "?" then
        for _, line in ipairs(HELP) do say(line) end
    elseif word == "" then
        DaylightJunkDrop_Drop()
    else
        say("unknown command. /dropjunk help lists them.")
    end
end

SLASH_DAYLIGHTJUNKDROP1 = "/dropjunk"
SlashCmdList.DAYLIGHTJUNKDROP = function(msg) DaylightJunkDrop_Command(msg) end
