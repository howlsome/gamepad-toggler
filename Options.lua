local ADDON, ns = ...

local panel = CreateFrame("Frame")
panel.name = "GamePad Toggler"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("GamePad Toggler")

local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
desc:SetPoint("RIGHT", -16, 0)
desc:SetJustifyH("LEFT")
desc:SetText("Choose which characters use the Gamepad UI. Changing the current character asks you to reload the UI; "
    .. "other characters switch the next time they log in. Characters appear here after logging in once with the addon enabled.")

local defaultCB = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
defaultCB:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", -4, -12)
local defaultLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
defaultLabel:SetPoint("LEFT", defaultCB, "RIGHT", 4, 0)
defaultLabel:SetText("Enable Gamepad UI by default for new characters")
defaultCB:SetScript("OnClick", function(self)
    GamePadTogglerDB.defaultEnabled = self:GetChecked() and true or false
end)

local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
header:SetPoint("TOPLEFT", defaultCB, "BOTTOMLEFT", 4, -16)
header:SetText("Characters")

local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
scroll:SetPoint("BOTTOMRIGHT", -32, 16)

local content = CreateFrame("Frame", nil, scroll)
content:SetSize(1, 1)
scroll:SetScrollChild(content)
scroll:SetScript("OnSizeChanged", function(self, w) content:SetWidth(w) end)

local ROW_HEIGHT = 28
local rows = {}

StaticPopupDialogs["GAMEPADTOGGLER_REMOVE"] = {
    text = "Remove %s from GamePad Toggler?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, key) ns.RemoveChar(key) end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local function GetRow(i)
    local row = rows[i]
    if row then return row end
    row = CreateFrame("Frame", nil, content)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT")

    row.cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.cb:SetPoint("LEFT")
    row.cb:SetScript("OnClick", function(self)
        ns.SetEnabled(row.key, self:GetChecked())
    end)

    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.label:SetPoint("LEFT", row.cb, "RIGHT", 4, 0)
    row.label:SetJustifyH("LEFT")

    row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.remove:SetSize(80, 20)
    row.remove:SetPoint("RIGHT", -4, 0)
    row.remove:SetText("Remove")
    row.remove:SetScript("OnClick", function()
        StaticPopup_Show("GAMEPADTOGGLER_REMOVE", row.displayName, nil, row.key)
    end)

    rows[i] = row
    return row
end

function ns.RefreshOptions()
    if not GamePadTogglerDB or not panel:IsVisible() then return end
    defaultCB:SetChecked(GamePadTogglerDB.defaultEnabled)

    local keys = {}
    for key in pairs(GamePadTogglerDB.chars) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        local ca, cb = GamePadTogglerDB.chars[a], GamePadTogglerDB.chars[b]
        if (ca.ruleset or "") ~= (cb.ruleset or "") then return (ca.ruleset or "") < (cb.ruleset or "") end
        return (ca.name or a) < (cb.name or b)
    end)

    for i, key in ipairs(keys) do
        local c = GamePadTogglerDB.chars[key]
        local row = GetRow(i)
        row.key = key
        row.displayName = c.name or key
        row.cb:SetChecked(c.enabled)

        local color = c.class and RAID_CLASS_COLORS[c.class]
        local name = color and color:WrapTextInColorCode(c.name or key) or (c.name or key)
        local text = name
        if c.ruleset and c.ruleset ~= "" then text = text .. " |cff999999- " .. c.ruleset .. "|r" end
        if key == ns.charKey then text = text .. "  |cff33ff99(current)|r" end
        row.label:SetText(text)

        row.remove:SetShown(key ~= ns.charKey)
        row:Show()
    end
    for i = #keys + 1, #rows do rows[i]:Hide() end
    content:SetHeight(math.max(1, #keys * ROW_HEIGHT))
end

panel:SetScript("OnShow", ns.RefreshOptions)

-- Register with the options UI (modern Settings API, with legacy fallback).
local category
if Settings and Settings.RegisterCanvasLayoutCategory then
    category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
end

function ns.OpenOptions()
    if category and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end
