DEFAULT_CHAT_FRAME:AddMessage("Data...too much data...slowly going |cffff0000CRAZY!!!|r")
-- Load or create tables (.toc SavedVariables)
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
    	LootOnly = false
}

local isLogging = false

-- frame linked to GameTooltip, so we can trigger when tooltip shows
local tooltipITLFrame = CreateFrame("Frame", "tooltipITLFrame", GameTooltip)

-- menu entries
local menuEntries = { "Name", "ItemID", "ItemLink", "ItemLinkString", "RequiredLevel", "Rarity", "ItemType", "SubType", "StackSize", "Slot", "Icon", "TooltipText" }

-- check for junk (any non-number string 2 character or less, nil and "" returns "nil")
local function discardJunk(value)
	if value == " \n" then
		return nil
	elseif value == nil or (string.len(tostring(value)) <= 2 and not tonumber(value)) then
		return "nil"
	else
		return value
	end
end

-- logging function
function logItemInfo()
    if isLogging then
        DEFAULT_CHAT_FRAME:AddMessage("Item Logging Started.")
        tooltipITLFrame:SetScript("OnShow", function()
            if GameTooltip.itemLink then
			
                local _, _, itemLink = string.find(GameTooltip.itemLink, "(item:%d+:%d+:%d+:%d+)")
                local itemLinkString = gsub(GameTooltip.itemLink, "\124", "\124\124")
                local _, _, itemID = string.find(GameTooltip.itemLink, "item:(%d+)")

                local itemName, sLink, itemRarity, itemMinLeveL, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemLink)

                if not itemName then return end
				
				if ITLSettings.lootOnly then  -- check parent frames if Loot only is enabled
                    local mouseOverItem = GetMouseFocus()
                    if mouseOverItem then
                        local parentFrame = mouseOverItem:GetParent()
                        if parentFrame then
                            if parentFrame:GetName() == "LootFrame" then -- if LootFrame, then log                              
                            elseif parentFrame:GetParent() and parentFrame:GetParent():GetName() == "XLootFrame" then -- if XLoot's LootFrame, then log 
                            else
                                return  -- not loot frame, skip logging and exit the OnShow script
                            end
                        else
                            return -- No parent (possible?), exit the OnShow script
                        end
                    else
                        return -- No frame (possible?), exit the OnShow script
                    end
                end

                if not ITLog[itemID] then -- items are logged by their itemID, this checks if itemID is already logged
                    DEFAULT_CHAT_FRAME:AddMessage(GameTooltip.itemLink .. " logged")
                    ITLog[itemID] = {} -- itemID as key

                    -- CSV table for CSV mode
                    local csvEntry = {}

					-- called below, adds entries to log that are selected and not junk
                    local function filterSelectedValues(selectedOption, value)
						local filteredValue = discardJunk(value)
						if ITLSettings[selectedOption] then
							ITLog[itemID][selectedOption] = filteredValue  -- Store the transformed value
							if ITLSettings.csvMode then
								table.insert(csvEntry, filteredValue)
							end
						end
					end

                    -- send selectedOptions to the log func
                    filterSelectedValues("Name", itemName)
                    filterSelectedValues("ItemID", itemID)
                    filterSelectedValues("ItemLink", sLink)
                    filterSelectedValues("ItemLinkString", itemLinkString)
                    filterSelectedValues("Rarity", itemRarity)
                    filterSelectedValues("ItemType", itemType)
                    filterSelectedValues("SubType", itemSubType)
                    filterSelectedValues("StackSize", itemStackCount)
					filterSelectedValues("RequiredLevel", itemMinLeveL)	
					--if not itemEquipLoc or itemEquipLoc == "" then itemEquipLoc = "0" end
					filterSelectedValues("Slot", itemEquipLoc)
					filterSelectedValues("Icon", itemTexture)

                    -- tooltip text processing (iterate over lines)
                    if ITLSettings.TooltipText then
                        ITLog[itemID].TooltipText = {} -- Use itemID as the key
                        for i = 1, GameTooltip:NumLines() do
                            local TText = _G["GameTooltipTextLeft" .. i]:GetText()
                            if discardJunk(TText) then
                                table.insert(ITLog[itemID].TooltipText, TText) -- Use itemID as the key
                                if ITLSettings.csvMode then
                                    table.insert(csvEntry, TText)
                                end
                            end
                        end
                    end

                    -- adds CSVs to log if selected
                    if ITLSettings.csvMode then
                        ITLog[itemID] = table.concat(csvEntry, ",") -- Use itemID as the key
                    end
                end
            end
        end)
    else
        DEFAULT_CHAT_FRAME:AddMessage("Item Logging Stopped.")
        tooltipITLFrame:SetScript("OnShow", nil)
		
		-- displays number of items in log when logging stopped
        local numberOfLoggedItems = 0
        for _ in pairs(ITLog) do
            numberOfLoggedItems = numberOfLoggedItems + 1
        end
        DEFAULT_CHAT_FRAME:AddMessage("Items in Log: " .. numberOfLoggedItems)
    end
end

-- create minimap button frame
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

-- create dropdown menu frame
local ILMenu = CreateFrame("Frame", "ITLMenu", UIParent, "UIDropDownMenuTemplate")

local function ILMenu_OnLoad()
    -- menu entries setup
    for _, menuOptions in ipairs(menuEntries) do
        local info = {} 
        info.text = menuOptions
        info.func = function()
            local selectedField = info.text
            if selectedField then
                ITLSettings[selectedField] = not ITLSettings[selectedField]
            end
        end
        info.arg1 = menuOptions
        info.checked = ITLSettings[menuOptions]
        info.isNotRadio = false
		info.keepShownOnClick = true
        UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
    end

    -- -----------------
    local info = {}
    info.text = "-----------------" 
    info.isTitle = true  -- sets to gold color and prevents clicking
    UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

 
    -- CSV menu entry
    local info = {}
    info.text = "CSV"
    info.func = function()
        local selectedField = info.text
        if selectedField == "CSV" then
            ITLSettings.csvMode = not ITLSettings.csvMode
            DEFAULT_CHAT_FRAME:AddMessage("CSV Mode " .. (ITLSettings.csvMode and "enabled" or "disabled") .. ".")
        end
    end
    info.checked = ITLSettings.csvMode
    info.isNotRadio = false
	info.keepShownOnClick = true
    UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

    -- Loot only menu entry
    local info = {}
    info.text = "Loot only"
    info.func = function()
        local selectedField = info.text
        if selectedField == "Loot only" then
            ITLSettings.lootOnly = not ITLSettings.lootOnly
            DEFAULT_CHAT_FRAME:AddMessage("Loot only mode " .. (ITLSettings.lootOnly and "enabled" or "disabled") .. ".")
        end
    end
    info.checked = ITLSettings.lootOnly
    info.isNotRadio = false
	info.keepShownOnClick = true
    UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)

    -- Clear Log menu entry
    local info = {}
    info.text = "|cffff0000Clear Log|r"
    info.func = function()
        ITLog = {}
        DEFAULT_CHAT_FRAME:AddMessage("ToolTip log cleared.")
        CloseDropDownMenus()
    end 
    UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
end

minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapButton:SetScript("OnClick", function()
    if arg1 == "LeftButton" then
        isWaitingIcon = not isWaitingIcon -- switches between the two icons when logging is started/stoped
        icon:SetTexture(isWaitingIcon and "Interface\\Addons\\ItemTooltipLogger\\zzzt-zzzt-zzzt.tga" or "Interface\\Addons\\ItemTooltipLogger\\waiting.tga")
		isLogging = not isLogging
		logItemInfo() --starts logging function
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

-- dropdown menu
UIDropDownMenu_Initialize(ILMenu, ILMenu_OnLoad, "MENU")
