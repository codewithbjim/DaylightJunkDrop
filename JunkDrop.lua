-- Junk Drop (DaylightUI Plugin): one key press deletes the cheapest junk stack in the bags.
-- Junk = gray items, plus anything marked as junk in Daylight UI's bags (when
-- that's switched on). Items locked in Daylight UI's bags are never touched.
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
    if lockSets and inEquipmentSet(bag, slot) then return nil end

    local marked = pins and pins[info.itemID] == "junk"
    if info.quality ~= 0 and not (marked and setting("includeMarked")) then return nil end

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
                if value and (not cap or value <= cap) and (not best or value < best.value) then
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
                  } },
                  { label = "What counts", items = {
                      { type = "slider", key = "maxSilver", label = "Most it may be worth", min = 0, max = 200, step = 1,
                        desc = "In silver, for the whole stack. Pricier junk is left for a vendor. 0 = no cap." },
                      { type = "toggle", key = "includeMarked", label = "Include items marked as junk",
                        desc = "Items you put in the Junk group of Daylight UI's bags count too, not just gray ones." },
                      { type = "text", label = "Items you lock in Daylight UI's bags are never deleted." },
                  } },
                  { label = "Safety", items = {
                      { type = "toggle", key = "confirm", label = "Ask before deleting",
                        desc = "A yes/no box names the item before it goes." },
                  } },
              } },
        } },
    })
    me = API.For(NAME)

    me.RegisterCommand("dropjunk", function() DaylightJunkDrop_Drop() end, "Delete the cheapest junk stack.")
end

SLASH_DAYLIGHTJUNKDROP1 = "/dropjunk"
SlashCmdList.DAYLIGHTJUNKDROP = function() DaylightJunkDrop_Drop() end
