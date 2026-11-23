local ADDON, ns = ...
ns.PREFIX = "|cff33ff99GamePad Toggler|r"

-- The console variable this addon switches per character: the one behind
-- Forever's "Options > Gamepad (Beta) > Enable Gamepad UI (Beta)" checkbox.
ns.CVAR = "InputDeviceInterfaceStyle"
ns.ON, ns.OFF = "1", "0"

local f = CreateFrame("Frame")
local pending, ready

-- Account-wide DB so every character's setting is visible from any character.
-- GamePadTogglerDB = { defaultEnabled = false,
--                      chars = { ["First Surname-"] = { enabled, name, realm, class, ruleset } } }

-- Forever characters have a first name and a surname; UnitName returns both.
-- The key uses the full name (plus realm, which is blank on Forever) so two
-- characters with the same first name don't share a setting.
function ns.GetCharKey()
    local first, surname = UnitName("player")
    if surname == "" then surname = nil end
    local realm = GetNormalizedRealmName() or GetRealmName() or ""
    local full = surname and (first .. " " .. surname) or first
    return full .. "-" .. realm, full, realm, first .. "-" .. realm
end

function ns.Current()
    return GamePadTogglerDB.chars[ns.charKey]
end

local function RuleActive(ruleName)
    local id = Enum and Enum.GameRule and Enum.GameRule[ruleName]
    if not id or not (C_GameRules and C_GameRules.IsGameRuleActive) then return false end
    local ok, on = pcall(C_GameRules.IsGameRuleActive, id)
    return ok and on and true or false
end

-- The character's ruleset. Forever marks non-Normal rulesets with game rules:
-- PvP = PvPRuleset, Roleplay = RPRuleset, Roleplay PvP = both.
function ns.GetRuleset()
    if C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive() then
        return "Hardcore"
    end
    local rp, pvp = RuleActive("RPRuleset"), RuleActive("PvPRuleset")
    if rp and pvp then return "Roleplay PvP" end
    if rp then return "Roleplay" end
    if pvp then return "PvP" end
    return "Normal"
end

-- Reload prompt. Forever blocks addons from calling ReloadUI(), so the
-- "Reload UI" button is a secure button that runs the /reload macro command.
local prompt = CreateFrame("Frame", "GamePadTogglerReloadPrompt", UIParent, "BackdropTemplate")
prompt:SetSize(340, 110)
prompt:SetPoint("TOP", 0, -160)
prompt:SetFrameStrata("FULLSCREEN_DIALOG")
prompt:SetToplevel(true)
prompt:EnableMouse(true)
prompt:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
prompt:Hide()

prompt.text = prompt:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
prompt.text:SetPoint("TOP", 0, -20)
prompt.text:SetWidth(300)
prompt.text:SetText("GamePad Toggler changed the Gamepad UI setting for this character.\nReload the UI to apply it.")

local reloadBtn = CreateFrame("Button", "GamePadTogglerReloadButton", prompt,
    "SecureActionButtonTemplate, UIPanelButtonTemplate")
reloadBtn:SetSize(130, 24)
reloadBtn:SetPoint("BOTTOMRIGHT", prompt, "BOTTOM", -6, 16)
reloadBtn:SetText(RELOADUI or "Reload UI")
reloadBtn:RegisterForClicks("AnyUp", "AnyDown")
reloadBtn:SetAttribute("type", "macro")
reloadBtn:SetAttribute("macrotext", "/reload")

local laterBtn = CreateFrame("Button", nil, prompt, "UIPanelButtonTemplate")
laterBtn:SetSize(130, 24)
laterBtn:SetPoint("BOTTOMLEFT", prompt, "BOTTOM", 6, 16)
laterBtn:SetText(LATER or "Later")
laterBtn:SetScript("OnClick", function() prompt:Hide() end)

function ns.ShowReloadPrompt()
    if InCombatLockdown() then return end
    prompt:Show()
    prompt:Raise()
end

-- Sets the CVar to match the current character, then offers a reload.
-- Returns true if it changed.
function ns.Apply()
    if not ready or not ns.supported then return end
    if InCombatLockdown() then
        pending = true
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    local want = ns.Current().enabled and ns.ON or ns.OFF
    if GetCVar(ns.CVAR) == want then return false end
    SetCVar(ns.CVAR, want)
    ns.ShowReloadPrompt()
    return true
end

-- Set any character's value; applies immediately if it's the logged-in one.
function ns.SetEnabled(key, enabled)
    local c = GamePadTogglerDB.chars[key]
    if not c then return end
    c.enabled = enabled and true or false
    if ns.RefreshOptions then ns.RefreshOptions() end
    if key == ns.charKey then ns.Apply() end
end

function ns.RemoveChar(key)
    if key == ns.charKey then return end
    GamePadTogglerDB.chars[key] = nil
    if ns.RefreshOptions then ns.RefreshOptions() end
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CVAR_UPDATE")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        GamePadTogglerDB = GamePadTogglerDB or {}
        GamePadTogglerDB.chars = GamePadTogglerDB.chars or {}
        if GamePadTogglerDB.defaultEnabled == nil then
            GamePadTogglerDB.defaultEnabled = false
        end
        -- Clean up data left by the old debug tools.
        GamePadTogglerDB.debug, GamePadTogglerDB.cvarLog = nil, nil
    elseif event == "PLAYER_LOGIN" then
        local key, name, realm, oldKey = ns.GetCharKey()
        ns.charKey = key
        local chars = GamePadTogglerDB.chars
        -- Move this character's entry from the old first-name-only key.
        if oldKey ~= key and chars[oldKey] and not chars[key] then
            chars[key], chars[oldKey] = chars[oldKey], nil
        end
        local c = chars[key]
        if not c then
            c = { enabled = GamePadTogglerDB.defaultEnabled }
            chars[key] = c
        end
        local _, class = UnitClass("player")
        c.name, c.realm, c.class, c.ruleset = name, realm, class, ns.GetRuleset()
        c.level = nil

        ready = true
        ns.supported = GetCVar(ns.CVAR) ~= nil
        if not ns.supported then
            print(ns.PREFIX .. " this client has no " .. ns.CVAR .. " setting; Gamepad UI can't be toggled.")
        end
        ns.Apply()
    elseif event == "CVAR_UPDATE" then
        -- Keep in sync if Gamepad UI is toggled from Blizzard's own settings.
        if ready and arg1 and arg1:lower() == ns.CVAR:lower() then
            local on = GetCVar(ns.CVAR) == ns.ON
            if ns.Current().enabled ~= on then
                ns.Current().enabled = on
                if ns.RefreshOptions then ns.RefreshOptions() end
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" and pending then
        pending = nil
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        ns.Apply()
    end
end)

SLASH_GAMEPADTOGGLER1 = "/gpt"
SLASH_GAMEPADTOGGLER2 = "/gamepadtoggler"
SlashCmdList.GAMEPADTOGGLER = function(msg)
    msg = tostring(msg or ""):match("^%s*(.-)%s*$"):lower()
    local c = GamePadTogglerDB and ns.charKey and GamePadTogglerDB.chars[ns.charKey]
    if not c then
        print(ns.PREFIX .. " not ready yet; try again in a moment.")
        return
    end
    if msg == "on" then
        ns.SetEnabled(ns.charKey, true)
    elseif msg == "off" then
        ns.SetEnabled(ns.charKey, false)
    elseif msg == "toggle" then
        ns.SetEnabled(ns.charKey, not c.enabled)
    elseif msg == "status" then
        print(ns.PREFIX .. " Gamepad UI is " .. (c.enabled and "ON" or "OFF") .. " for "
            .. (c.name or ns.charKey) .. " (" .. (c.ruleset or "?") .. ").")
        return
    elseif msg == "" or msg == "options" or msg == "config" then
        ns.OpenOptions()
        return
    else
        print(ns.PREFIX .. " usage: /gpt [options] | on | off | toggle | status")
        return
    end
    print(ns.PREFIX .. " Gamepad UI " .. (c.enabled and "ON" or "OFF") .. " for this character.")
end
