local _G = getfenv(0)

-- load or create tables (.toc SavedVariables)
ITLog = ITLog or {}
ITLSettings = ITLSettings or {
    ItemLinkString = false,
    ItemType = false,
    SubType = false,
    ItemID = true,
    TooltipText = false,
    Name = true,
    StackSize = false,
    ItemLink = false,
    Rarity = false,
    RequiredLevel = false,
    Slot = false,
    Icon = false,
    CSVMode = false,
    lootOnly = false
}

local isLogging = false
local scanningActive = false
local scanLastUpdate = 0
local scanCurrentItemID = 0
local scanMaxRange = 0
local currentItemID = nil
local minRange, maxRange
local scanInterval = 0.025
local lastUpdate = 0
local scanTimer = 0
local skippedItems = 0

-- frame linked to GameTooltip (triggers OnUpdate for mouseover logging)-------------------------
local tooltipITLFrame = CreateFrame("Frame", "tooltipITLFrame", GameTooltip)

-- dropdown menu entries
local menuEntries = { "Name", "ItemID", "ItemLink", "ItemLinkString", "RequiredLevel", "Rarity", "ItemType", "SubType", "StackSize", "Slot", "Icon", "TooltipText" }

-- discards “junk” values-------------------------------------------------------
local function discardJunk(value)
    if value == " \n" then
        return nil
    elseif value == nil or (string.len(tostring(value)) <= 2 and not tonumber(value)) then
        return "nil"
    else
        return value
    end
end

local function GetTooltipLines()
    local leftLines = {}
    local rightLines = {}
    local numLines = GameTooltip:NumLines()
    for i = 1, numLines do
        local leftLine = _G["GameTooltipTextLeft" .. i]
        if leftLine and leftLine.GetText and leftLine:IsShown() then
            local leftText = leftLine:GetText()
            if leftText and leftText ~= "" then
                leftLines[i] = leftText
            end
        end

        local rightLine = _G["GameTooltipTextRight" .. i]
        if rightLine and rightLine.GetText and rightLine:IsShown() then
            local rightText = rightLine:GetText()
            if rightText and rightText ~= "" then
                rightLines[i] = rightText
            end
        end
    end
    return leftLines, rightLines
end


-- stores item info to ITLog----------------------------------------------------
local function logItemData(itemID, itemName, sLink, itemRarity, itemMinLevel, 
                             itemType, itemSubType, itemStackCount, itemEquipLoc, 
                             itemTexture, tooltipLeft, tooltipRight, itemLinkString)
    if ITLog[itemID] then return end  -- already logged

    ITLog[itemID] = {}
    local csvEntry = {}

    local function filterSelected(option, value)
        local filteredValue = discardJunk(value)
        if ITLSettings[option] then
            ITLog[itemID][option] = filteredValue
            if ITLSettings.csvMode then
                table.insert(csvEntry, filteredValue)
            end
        end
    end

    filterSelected("Name", itemName)
    filterSelected("ItemID", itemID)
    filterSelected("ItemLink", sLink)
    filterSelected("ItemLinkString", itemLinkString)
    filterSelected("Rarity", itemRarity)
    filterSelected("ItemType", itemType)
    filterSelected("SubType", itemSubType)
    filterSelected("StackSize", itemStackCount)
    filterSelected("RequiredLevel", itemMinLevel)
    filterSelected("Slot", itemEquipLoc)
    filterSelected("Icon", itemTexture)

	if ITLSettings.TooltipText and tooltipLeft then
		ITLog[itemID].TooltipTextLeft = {}
		for line, text in pairs(tooltipLeft) do
			if discardJunk(text) then
				ITLog[itemID].TooltipTextLeft[line] = text
				if ITLSettings.csvMode then
					table.insert(csvEntry, text)
				end
			end
		end
	
		ITLog[itemID].TooltipTextRight = {}
		for line, text in pairs(tooltipRight) do
			if discardJunk(text) then
				ITLog[itemID].TooltipTextRight[line] = text
				if ITLSettings.csvMode then
					table.insert(csvEntry, text)
				end
			end
		end
	end
	
    if ITLSettings.csvMode then
        ITLog[itemID] = table.concat(csvEntry, ",")
    end
end


-- info from GetItemInfo and/or the tooltip,calls logItemData-------------------
local function ProcessItemLog(itemID)
    if ITLog[itemID] then return false end  -- already logged

    local itemName, sLink, itemRarity, itemMinLevel, itemType, itemSubType, 
          itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemID)
    if not itemName then return false end

    local itemLinkString = ""
    if GameTooltip.itemLink then
        itemLinkString = string.gsub(GameTooltip.itemLink, "\124", "\124\124")
    elseif sLink then
        itemLinkString = string.gsub(sLink, "\124", "\124\124")
    end

    local tooltipLeft, tooltipRight = GetTooltipLines()

    logItemData(itemID,itemName,sLink,itemRarity,itemMinLevel,itemType,itemSubType,itemStackCount,itemEquipLoc,itemTexture,tooltipLeft,tooltipRight,itemLinkString)
				
    return true, itemLinkString , itemRarity, itemName
end

-- mouseover Logging------------------------------------------------------------
function logItemInfo()
    if isLogging then
        DEFAULT_CHAT_FRAME:AddMessage("Item Logging Started.")

        tooltipITLFrame:SetScript("OnShow", function()
            if GameTooltip.itemLink then
                local _, _, itemLinkExtract = string.find(GameTooltip.itemLink, "(item:%d+:%d+:%d+:%d+)")
                local _, _, itemID = string.find(GameTooltip.itemLink, "item:(%d+)")
                itemID = tonumber(itemID)
                if not itemID then return end

                -- if Loot Only mode is enabled, check tooltip comes from loot frame
                if ITLSettings.lootOnly then
                    local mouseOverItem = GetMouseFocus()
                    if mouseOverItem then
                        local parentFrame = mouseOverItem:GetParent()
                        if parentFrame then
                            if parentFrame:GetName() == "LootFrame" then
                            elseif parentFrame:GetParent() and parentFrame:GetParent():GetName() == "XLootFrame" then
                            else
                                return  -- not a loot frame
                            end
                        else
                            return
                        end
                    else
                        return
                    end
                end

				local success, itemLinkString, itemRarity, itemName = ProcessItemLog(itemID)
				if success and itemLinkString and itemRarity and itemName then
					local r, g, b, hex = GetItemQualityColor(itemRarity);
					DEFAULT_CHAT_FRAME:AddMessage(itemID.." - "..hex.."\124H".."item:"..itemID..":0:0:0"..":::::60:::::\124h["..itemName.."]\124h\124r")
					--/run local r, g, b, hex = GetItemQualityColor(5);print(hex.." test");DEFAULT_CHAT_FRAME:AddMessage(hex.."\124H".."item:22589:0:0:0"..":::::60:::::\124h[".."fing".."]\124h\124r")
				end
			end
        end)
    else
        DEFAULT_CHAT_FRAME:AddMessage("Item Logging Stopped.")
        tooltipITLFrame:SetScript("OnShow", nil)

        local numberOfLoggedItems = 0
        for _ in pairs(ITLog) do
            numberOfLoggedItems = numberOfLoggedItems + 1
        end
        DEFAULT_CHAT_FRAME:AddMessage("Items in Log: " .. numberOfLoggedItems)
		-- clear and hide the tooltip
		GameTooltip:ClearLines()
		GameTooltip:Hide()
    end
end

-- range scanning---------------------------------------------------------------
local function scan(minRange, maxRange)
    skippedItems = 0
    isLogging = true
    currentItemID = minRange
    if not scanFrame then
        scanFrame = CreateFrame("Frame")
    end
    scanFrame:Show()

    local function ScanItemsOnUpdate()
        scanTimer = scanTimer + arg1
        if scanTimer >= scanInterval then
            currentItemID = currentItemID + 1
            if currentItemID <= maxRange then
                GameTooltip:ClearLines()
                GameTooltip:SetOwner(UIParent, "TOPLEFT")
                GameTooltip:SetHyperlink("item:" .. currentItemID .. ":0:0:0")
                GameTooltip:Show()

                local itemName, sLink = GetItemInfo(currentItemID)
                if not itemName then 
                    skippedItems = skippedItems + 1
                    if skippedItems >= 100 then 
                        DEFAULT_CHAT_FRAME:AddMessage("itemID "..currentItemID..", "..string.format("%.4f",(scanTimer/100)).." seconds per skipped item")
                        scanTimer = 0
                        skippedItems = 0
                    end
                    return 
                end

				local success, itemLinkString, itemRarity, itemName = ProcessItemLog(currentItemID)
				if success and itemLinkString and itemRarity and itemName then
					local r, g, b, hex = GetItemQualityColor(itemRarity);
					DEFAULT_CHAT_FRAME:AddMessage(currentItemID.." - "..hex.."\124H".."item:"..currentItemID..":0:0:0"..":::::60:::::\124h["..itemName.."]\124h\124r")
					--/run local r, g, b, hex = GetItemQualityColor(5);print(hex.." test");DEFAULT_CHAT_FRAME:AddMessage(hex.."\124H".."item:22589:0:0:0"..":::::60:::::\124h[".."fing".."]\124h\124r")
				end
				scanTimer = 0
            else
                local numberOfLoggedItems = 0
                for _ in pairs(ITLog) do
                    numberOfLoggedItems = numberOfLoggedItems + 1
                end
                DEFAULT_CHAT_FRAME:AddMessage("Items in Log: " .. numberOfLoggedItems)
                scanFrame:SetScript("OnUpdate", nil)
                skippedItems = 0
                isLogging = false
				-- clear and hide the tooltip
				GameTooltip:ClearLines()
				GameTooltip:Hide()
                return
            end
        end
    end

    scanFrame:SetScript("OnUpdate", ScanItemsOnUpdate)
end

-- scan range frame----------------------------------------------------------
local ScanRangeFrame = CreateFrame("Frame", "ScanRangeFrame", UIParent)
ScanRangeFrame:SetWidth(130)
ScanRangeFrame:SetHeight(100)
ScanRangeFrame:SetPoint("TOPRIGHT", DropDownList1, "TOPLEFT", -10, 0)
ScanRangeFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
ScanRangeFrame:Hide()



local scanCloseButton = CreateFrame("Button", nil, ScanRangeFrame, "UIPanelCloseButton")
scanCloseButton:SetPoint("TOPRIGHT", ScanRangeFrame, "TOPRIGHT", -1, -1)
scanCloseButton:SetScript("OnClick", function() ScanRangeFrame:Hide() end)

local scanTitle = ScanRangeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
scanTitle:SetPoint("TOPLEFT", ScanRangeFrame, "TOPLEFT", 10, -10)
scanTitle:SetText("Range to scan")

local remText = ScanRangeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
remText:SetText("Filters on MM menu")
remText:SetPoint("BOTTOM", ScanRangeFrame, "BOTTOM", 0, 12)

local function NumericOnly()
    local text = this:GetText()
    if string.find(text, "[^0-9]") then
        this:SetText(string.gsub(text, "[^0-9]", ""))
    end
end

local editBox1 = CreateFrame("EditBox", "ScanRangeEditBox1", ScanRangeFrame, "InputBoxTemplate")
editBox1:SetWidth(50)
editBox1:SetHeight(20)
editBox1:SetPoint("TOPLEFT", ScanRangeFrame, "TOPLEFT", 12, -30)
editBox1:SetAutoFocus(false)
editBox1:SetText("0")
editBox1:SetScript("OnTextChanged", NumericOnly)
editBox1:SetTextInsets(0, 10, 0, 0)
editBox1:SetJustifyH("RIGHT")

local editBox2 = CreateFrame("EditBox", "ScanRangeEditBox2", ScanRangeFrame, "InputBoxTemplate")
editBox2:SetWidth(50)
editBox2:SetHeight(20)
editBox2:SetPoint("LEFT", editBox1, "RIGHT", 10, 0)
editBox2:SetAutoFocus(false)
editBox2:SetText("0")
editBox2:SetScript("OnTextChanged", NumericOnly)
editBox2:SetTextInsets(0, 10, 0, 0)
editBox2:SetJustifyH("RIGHT")

local scanButton = CreateFrame("Button", "ScanRangeButton", ScanRangeFrame, "UIPanelButtonTemplate")
scanButton:SetWidth(40)
scanButton:SetHeight(20)
scanButton:SetPoint("BOTTOM", ScanRangeFrame, "BOTTOM", -22, 30)
scanButton:SetText("Scan")
scanButton:SetScript("OnClick", function()
    editBox1:ClearFocus()
    editBox2:ClearFocus()
    skippedItems = 0
    minRange = tonumber(editBox1:GetText()) or 0
    maxRange = tonumber(editBox2:GetText()) or 0
	if minRange >= maxRange then
        DEFAULT_CHAT_FRAME:AddMessage("Ensure left editbox < right editbox")
        return
    end
	
    scan(minRange, maxRange)
end)

local stopButton = CreateFrame("Button", "stopScanButton", ScanRangeFrame, "UIPanelButtonTemplate")
stopButton:SetWidth(40)
stopButton:SetHeight(20)
stopButton:SetPoint("LEFT", scanButton, "RIGHT", 4, 0)
stopButton:SetText("Stop")
stopButton:SetScript("OnClick", function()
    if scanFrame then
        scanFrame:SetScript("OnUpdate", nil)
    end
    scanningActive = false
    isLogging = false
    DEFAULT_CHAT_FRAME:AddMessage("Scan stopped.")
	 -- clear and hide the tooltip
     GameTooltip:ClearLines()
     GameTooltip:Hide()
end)

ScanRangeFrame:SetMovable(true)
ScanRangeFrame:EnableMouse(true)
ScanRangeFrame:RegisterForDrag("LeftButton")
ScanRangeFrame:SetScript("OnDragStart", function() this:StartMoving() end)
ScanRangeFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

-- Dropdown Menu Frame----------------------------------------------------------
local ILMenu = CreateFrame("Frame", "ITLMenu", UIParent, "UIDropDownMenuTemplate")
local function ILMenu_OnLoad()
    for _, menuOption in ipairs(menuEntries) do
        local info = {}
        info.text = menuOption
        info.func = function(self)
			local selectedField = info.text
            if selectedField then
                ITLSettings[selectedField] = not ITLSettings[selectedField]
            end
        end
        info.value = menuOption
        info.checked = ITLSettings[menuOption]
        info.isNotRadio = true
        info.keepShownOnClick = true
        UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
    end

    local infoSep = { text = "-----------------", isTitle = true }
    UIDropDownMenu_AddButton(infoSep, UIDROPDOWNMENU_MENU_LEVEL)

    local infoCSV = {}
    infoCSV.text = "CSV"
    infoCSV.func = function()
        ITLSettings.csvMode = not ITLSettings.csvMode
        DEFAULT_CHAT_FRAME:AddMessage("CSV Mode " .. (ITLSettings.csvMode and "enabled" or "disabled") .. ".")
    end
    infoCSV.checked = ITLSettings.csvMode
    infoCSV.isNotRadio = true
    infoCSV.keepShownOnClick = true
    UIDropDownMenu_AddButton(infoCSV, UIDROPDOWNMENU_MENU_LEVEL)

    local infoLoot = {}
    infoLoot.text = "Loot only"
    infoLoot.func = function()
        ITLSettings.lootOnly = not ITLSettings.lootOnly
        DEFAULT_CHAT_FRAME:AddMessage("Loot only mode " .. (ITLSettings.lootOnly and "enabled" or "disabled") .. ".")
    end
    infoLoot.checked = ITLSettings.lootOnly
    infoLoot.isNotRadio = true
    infoLoot.keepShownOnClick = true
    UIDropDownMenu_AddButton(infoLoot, UIDROPDOWNMENU_MENU_LEVEL)

    local infoScanRange = {}
    infoScanRange.text = "Scan range"
    infoScanRange.func = function() ScanRangeFrame:Show() end
    infoScanRange.keepShownOnClick = false
    UIDropDownMenu_AddButton(infoScanRange, UIDROPDOWNMENU_MENU_LEVEL)

    local infoSep2 = { text = "-----------------", isTitle = true }
    UIDropDownMenu_AddButton(infoSep2, UIDROPDOWNMENU_MENU_LEVEL)

    local infoClear = {}
    infoClear.text = "|cffff0000Clear Log|r"
    infoClear.func = function()
        ITLog = {}
        DEFAULT_CHAT_FRAME:AddMessage("Log cleared.")
        CloseDropDownMenus()
    end
	UIDropDownMenu_AddButton(infoClear, UIDROPDOWNMENU_MENU_LEVEL)
end

-- Minimap Button---------------------------------------------------------------
local minimapButton = CreateFrame("Button", "MyAddonMinimapButton", Minimap)
minimapButton:SetWidth(32)
minimapButton:SetHeight(32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(10)
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Addons\\ItemTooltipLogger\\waiting.tga")
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)

local border = minimapButton:CreateTexture(nil, "ARTWORK")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetWidth(52)
border:SetHeight(52)
border:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)

minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapButton:SetScript("OnClick", function()
    if arg1 == "LeftButton" then
        isLogging = not isLogging
        if isLogging then
            icon:SetTexture("Interface\\Addons\\ItemTooltipLogger\\zzzt-zzzt-zzzt.tga")
        else
            icon:SetTexture("Interface\\Addons\\ItemTooltipLogger\\waiting.tga")
        end
        logItemInfo()
    elseif arg1 == "RightButton" then
        ToggleDropDownMenu(1, nil, ILMenu, minimapButton, 0, 0)
    end
end)

minimapButton:SetPoint("CENTER", Minimap, "CENTER", 80, -80)
minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetMovable(true)
minimapButton:SetScript("OnDragStart", function() this:StartMoving() end)
minimapButton:SetScript("OnDragStop", function()
	this:StopMovingOrSizing()
    local mx, my = Minimap:GetCenter()
    local x, y = this:GetCenter()
    local angle = math.atan2(y - my, x - mx)
    local radius = Minimap:GetWidth() / 2 + 10
	this:ClearAllPoints()
	this:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end)

-- dropdown menu init-------------------------------------------------------------
UIDropDownMenu_Initialize(ILMenu, ILMenu_OnLoad, "MENU")

DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Item Tooltip Logger Loaded.|r")
