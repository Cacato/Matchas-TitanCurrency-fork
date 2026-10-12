-- Matcha's TitanCurrency fork for Everfresh 0.8.1, for the original Wrath 3.3.5 client.
-- Original addon by Greenhorns @ Vek'Nilash.
local ID = "Currency"
local LB = LibStub("AceLocale-3.0"):GetLocale("Titan_Currency", true)
local ready = false
local layoutHooked = false

local function Settings()
    if type(TitanCurrencyDB) ~= "table" then TitanCurrencyDB = {} end
    local db = TitanCurrencyDB
    if db.showIcons == nil then db.showIcons = true end
    if db.showZero == nil then db.showZero = false end
    if db.sortByName == nil then db.sortByName = false end
    if db.sortEmblems == nil then db.sortEmblems = true end
    if type(db.hidden) ~= "table" then db.hidden = {} end
    if type(db.barCurrencies) ~= "table" then db.barCurrencies = {} end
    if type(db.barOrder) ~= "table" then db.barOrder = {} end
    return db
end

local function Refresh()
    if TitanPanelButton_UpdateButton then TitanPanelButton_UpdateButton(ID) end
    if TitanCurrency_LayoutDragTargets then TitanCurrency_LayoutDragTargets() end
    if TitanPanelButton_UpdateTooltip then TitanPanelButton_UpdateTooltip(_G.TitanPanelCurrencyButton) end
end

-- List positions change when currencies are moved; save selections by item ID.
local function Currencies()
    local emblemRanks = { [49426] = 1, [47241] = 2, [45624] = 3, [40753] = 4, [40752] = 5 }
    local entries = {}
    for index = 1, GetCurrencyListSize() do
        local name, header, expanded, unused, watched, count, kind, icon, itemID = GetCurrencyListInfo(index)
        if name and not header then
            local key
            if kind == 1 or kind == 2 then key = "pvp:" .. kind
            elseif itemID and itemID > 0 then key = "item:" .. itemID
            else key = "name:" .. name end
            if kind == 1 then
                icon = "Interface\\PVPFrame\\PVP-ArenaPoints-Icon"
            elseif kind == 2 then
                icon = "Interface\\TargetingFrame\\UI-PVP-" .. (UnitFactionGroup("player") or "Alliance")
            end
            entries[#entries + 1] = { name = name, count = count or 0, icon = icon, key = key, kind = kind,
                index = index, emblemRank = emblemRanks[itemID] }
        end
    end
    local db = Settings()
    if db.sortByName or db.sortEmblems then
        table.sort(entries, function(a, b)
            if db.sortEmblems and (a.emblemRank or b.emblemRank) then
                return (a.emblemRank or 100) < (b.emblemRank or 100)
            end
            if db.sortByName then return a.name < b.name end
            return a.index < b.index
        end)
    end
    return entries
end

local function IconText(entry)
    local icon = entry.icon
    if not icon or icon == "" then icon = "Interface\\Icons\\INV_Misc_QuestionMark" end
    if entry.kind == 2 then return "|T" .. icon .. ":16:16:0:0:64:64:2:38:2:38|t " end
    return "|T" .. icon .. ":16:16:0:0|t "
end

function TitanPanelCurrencyButton_OnLoad(self)
    if hooksecurefunc and not layoutHooked then
        hooksecurefunc("TitanPanelButton_SetComboButtonWidth", function(id)
            if id == ID then TitanCurrency_AlignContents() end
        end)
        layoutHooked = true
    end
    self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    self.registry = {
        id = ID, category = "Information", version = "0.8.1",
        menuText = "Matcha's TitanCurrency fork for Everfresh", tooltipTitle = LB["TITAN_CURRENCY_TOOLTIP"],
        tooltipTextFunction = "TitanPanelCurrencyButton_GetTooltipText",
        buttonTextFunction = "TitanPanelCurrencyButton_GetButtonText",
        icon = "Interface\\Icons\\INV_Misc_Coin_02", iconWidth = 16,
        savedVariables = {ShowIcon = 1, ShowLabelText = 1},
    }
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
end

function TitanCurrency_AlignContents()
    local parent, text, icon = _G.TitanPanelCurrencyButton, _G.TitanPanelCurrencyButtonText, _G.TitanPanelCurrencyButtonIcon
    if not parent or not text or not icon then return end
    local label = parent.currencyLabel
    if not label then
        label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        parent.currencyLabel = label
    end
    label:SetFont(text:GetFont())
    -- A longer show-all string must not inherit the previous selection's width
    -- and wrap into multiple lines before Titan resizes the button.
    if text.SetWordWrap then text:SetWordWrap(false) end
    if text.SetNonSpaceWrap then text:SetNonSpaceWrap(false) end
    text:SetWidth(0)
    text:SetHeight(16)
    text:SetJustifyV("MIDDLE")
    label:SetHeight(16)
    label:SetJustifyV("MIDDLE")
    local labelText, values = TitanPanelCurrencyButton_GetButtonText()
    local showLabel = TitanGetVar(ID, "ShowLabelText")
    label:SetText(showLabel and "Currency:" or "")
    text:SetText(values)
    local valueWidth = text:GetStringWidth()
    text:SetWidth(valueWidth)
    local offset = 0
    icon:ClearAllPoints()
    icon:SetPoint("LEFT", parent, "LEFT", 0, 0)
    if TitanGetVar(ID,"ShowIcon") then offset = icon:GetWidth() + 8 end
    label:ClearAllPoints()
    label:SetPoint("LEFT", parent, "LEFT", offset, 0)
    if showLabel then offset = offset + label:GetStringWidth() + 8 end
    text:ClearAllPoints()
    text:SetPoint("LEFT", parent, "LEFT", offset, 0)
    local width = math.max(16, offset + valueWidth)
    if math.abs(parent:GetWidth() - width) > 0.1 then
        parent:SetWidth(width)
        TitanPanelButton_Justify()
    end
    TitanCurrency_LayoutDragTargets()
end

function TitanPanelCurrencyButton_GetButtonText()
    local values = {}
    for _, entry in ipairs(TitanCurrency_BarEntries()) do
        if Settings().showAll or Settings().barCurrencies[entry.key] then
            values[#values + 1] = (Settings().showIcons and IconText(entry) or entry.name .. ": ") .. entry.count
        end
    end
    return "Currency:   ", table.concat(values, "  ")
end

function TitanCurrency_OnClick(self, button)
    if button == "RightButton" then
        local menu = _G.TitanPanelCurrencyButtonRightClickMenu
        if menu then
            -- This Titan release mistakes UIParent for a child button's parent.
            -- Bind our callback directly instead of its parent-based ID lookup.
            UIDropDownMenu_Initialize(menu, TitanPanelRightClickMenu_PrepareCurrencyMenu, "MENU")
            self.TitanMenuInit = true
        end
    end
    TitanPanelButton_OnClick(self, button)
end

function TitanCurrency_BarEntries()
    local entries, positions = {}, {}
    for index, key in ipairs(Settings().barOrder) do positions[key] = index end
    for _, entry in ipairs(Currencies()) do
        if Settings().showAll or Settings().barCurrencies[entry.key] then
            entry.defaultPosition = #entries + 1
            entries[#entries + 1] = entry
        end
    end
    table.sort(entries, function(a,b)
        return (positions[a.key] or (10000 + a.defaultPosition)) < (positions[b.key] or (10000 + b.defaultPosition))
    end)
    return entries
end

function TitanCurrency_MoveBarCurrency(source, target)
    if source == target then return end
    local order, from, to = {}, nil, nil
    for index, entry in ipairs(TitanCurrency_BarEntries()) do
        order[index] = entry.key
        if entry.key == source then from = index end
        if entry.key == target then to = index end
    end
    if not from or not to then return end
    table.remove(order, from)
    table.insert(order, to, source)
    Settings().barOrder = order
    Refresh()
end

-- Child hit areas consume currency drags; the label retains Titan's normal drag.
function TitanCurrency_HideDragIcon()
    local parent = _G.TitanPanelCurrencyButton
    if parent and parent.currencyDragIcon then parent.currencyDragIcon:Hide() end
end

function TitanCurrency_ShowDragIcon(entry)
    local parent = _G.TitanPanelCurrencyButton
    if not parent or not entry then return end
    local ghost = parent.currencyDragIcon
    if not ghost then
        ghost = CreateFrame("Frame", nil, UIParent)
        ghost:SetFrameStrata("TOOLTIP")
        ghost:EnableMouse(false)
        ghost:SetWidth(24)
        ghost:SetHeight(24)
        ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
        ghost.icon:SetAllPoints(ghost)
        ghost:SetScript("OnUpdate", function(self)
            if not IsMouseButtonDown("LeftButton") then self:Hide(); return end
            local x, y = GetCursorPosition()
            local scale = self:GetEffectiveScale()
            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        end)
        parent.currencyDragIcon = ghost
    end
    ghost.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    if entry.kind == 2 then ghost.icon:SetTexCoord(0.03125, 0.59375, 0.03125, 0.59375)
    else ghost.icon:SetTexCoord(0, 1, 0, 1) end
    if GameTooltip then GameTooltip:Hide() end
    ghost:Show()
    ghost:GetScript("OnUpdate")(ghost)
end

function TitanCurrency_LayoutDragTargets()
    local parent, text = _G.TitanPanelCurrencyButton, _G.TitanPanelCurrencyButtonText
    if not parent or not text or not CreateFrame then return end
    parent.currencyTargets = parent.currencyTargets or {}
    local measure = parent.currencyMeasure
    if not measure then
        measure = parent:CreateFontString(nil, "OVERLAY")
        parent.currencyMeasure = measure
        measure:Hide()
    end
    measure:SetFont(text:GetFont())
    measure:SetText((not parent.currencyLabel and (not TitanGetVar or TitanGetVar(ID,"ShowLabelText"))) and "Currency:   " or "")
    local offset = measure:GetStringWidth()
    local entries = TitanCurrency_BarEntries()
    for index, entry in ipairs(entries) do
        local target = parent.currencyTargets[index]
        if not target then
            target = CreateFrame("Button", nil, parent)
            target:RegisterForDrag("LeftButton")
            target:RegisterForClicks("RightButtonUp")
            target:SetScript("OnDragStart", function(self)
                parent.dragCurrency = self.currencyKey
                TitanCurrency_ShowDragIcon(self.currencyEntry)
            end)
            target:SetScript("OnDragStop", function()
                local source = parent.dragCurrency
                parent.dragCurrency = nil
                TitanCurrency_HideDragIcon()
                for _, candidate in ipairs(parent.currencyTargets) do
                    if candidate:IsShown() and MouseIsOver(candidate) then
                        TitanCurrency_MoveBarCurrency(source, candidate.currencyKey)
                        break
                    end
                end
            end)
            target:SetScript("OnClick", function(_, button) TitanCurrency_OnClick(parent, button) end)
            target:SetScript("OnEnter", function() if not parent.dragCurrency then TitanPanelButton_OnEnter(parent) end end)
            target:SetScript("OnLeave", function() TitanPanelButton_OnLeave(parent) end)
            parent.currencyTargets[index] = target
        end
        local value = (Settings().showIcons and IconText(entry) or entry.name .. ": ") .. entry.count
        measure:SetText(value)
        local width = measure:GetStringWidth()
        target.currencyKey = entry.key
        target.currencyEntry = entry
        target:ClearAllPoints()
        target:SetPoint("LEFT", text, "LEFT", offset, 0)
        target:SetWidth(math.max(1,width))
        target:SetHeight(16)
        target:Show()
        measure:SetText("  ")
        offset = offset + width + measure:GetStringWidth()
    end
    for index = #entries + 1, #parent.currencyTargets do parent.currencyTargets[index]:Hide() end
end

function TitanCurrency_OnEvent(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        Settings().gold = nil
        ready = true
    end
    if ready then Refresh() end
end

function TitanPanelCurrencyButton_GetTooltipText()
    local db = Settings()
    local lines = {}
    for _, entry in ipairs(Currencies()) do
        if db.showAll or (not db.hidden[entry.key] and (db.showZero or entry.count ~= 0)) then
            lines[#lines + 1] = (db.showIcons and IconText(entry) or "") .. entry.name .. "\t" .. entry.count .. "|r"
        end
    end
    if #lines == 0 then lines[1] = "No currencies to display." end
    return table.concat(lines, "\n")
end

-- Wrath Titan versions use either Blizzard's dropdown or Titan's library copy.
local function AddButton(info, level)
    local add = UIDropDownMenu_AddButton
    add(info, level)
end

local function ToggleOption(text, key, level)
    local db = Settings()
    AddButton({ text = text, checked = db[key], keepShownOnClick = true,
        func = function() db[key] = not db[key]; Refresh() end }, level)
end

function TitanPanelRightClickMenu_PrepareCurrencyMenu()
    local level = _G.UIDROPDOWNMENU_MENU_LEVEL or 1
    local value = _G.UIDROPDOWNMENU_MENU_VALUE
    local db = Settings()
    if level > 1 and (value == "TitanCurrencySelection" or value == "TitanCurrencyBarSelection") then
        local onBar = value == "TitanCurrencyBarSelection"
        local entries = Currencies()
        if #entries == 0 then
            AddButton({ text = "No currencies discovered yet", disabled = true, notCheckable = true }, level)
        end
        for _, entry in ipairs(entries) do
            local key = entry.key
            AddButton({ text = IconText(entry) .. entry.name,
                checked = db.showAll or (onBar and db.barCurrencies[key]) or (not onBar and not db.hidden[key]), keepShownOnClick = true,
                func = function()
                    if db.showAll then
                        -- Adopt the visible selection when editing individual currencies.
                        for _, currency in ipairs(Currencies()) do db.barCurrencies[currency.key] = true end
                        db.hidden = {}
                        db.showZero = true
                        db.showAll = false
                    end
                    if onBar then db.barCurrencies[key] = not db.barCurrencies[key]
                    else db.hidden[key] = not db.hidden[key] end
                    Refresh()
                end }, level)
        end
        return
    end
    if level ~= 1 then return end
    TitanPanelRightClickMenu_AddTitle(LB["TITAN_CURRENCY_MENU_TEXT"], level)
    ToggleOption("Show currency icons", "showIcons", level)
    ToggleOption("Show zero balances", "showZero", level)
    ToggleOption("Sort currencies by name", "sortByName", level)
    ToggleOption("Sort emblems by raid tier (Frost first)", "sortEmblems", level)
    AddButton({ text = "Currencies in tooltip", hasArrow = true, notCheckable = true, value = "TitanCurrencySelection" }, level)
    AddButton({ text = "Currencies on Titan bar", hasArrow = true, notCheckable = true, value = "TitanCurrencyBarSelection" }, level)
    AddButton({ text = "Show all currencies", checked = db.showAll == true, keepShownOnClick = true,
        func = function()
            db.showAll = not db.showAll
            Refresh()
        end }, level)
    TitanPanelRightClickMenu_AddSpacer(level)
    if level == 1 then
        TitanPanelRightClickMenu_AddToggleIcon(ID)
        TitanPanelRightClickMenu_AddToggleLabelText(ID)
    end
    local L = LibStub("AceLocale-3.0"):GetLocale("Titan", true)
    if level == 1 then TitanPanelRightClickMenu_AddCommand(L["TITAN_PANEL_MENU_HIDE"], ID, TITAN_PANEL_MENU_FUNC_HIDE) end
end



