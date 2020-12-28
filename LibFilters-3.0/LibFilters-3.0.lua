--[LibFilters] Main version: 3
--Created by: ingeniousclown - 2014 (LibFilters 1)
--Contributors: Baertram, Randactly, Votan, sirinsidiator, Scootworks
--Current maintainer: Baertram (since 2018-02)

--This library is used to filter inventory items (show/hide) at the different panels/inventories.
--Supported panels got a unique constant LF_<pnaleName> which is used to add filterFunctions of different addons to this
--inventory. See table libFiltersFilterConstants for the value = "filterPanel name" constants.
--The registered filterFunctions will run as the invntories are refreshed/updated, either by internal update routines as
--the inventory's "dirty" flag was set to true. Or via function SafeUpdateList (see below).
--LibFilters3 will use the inventory/fragment (normal hooks), or some special hooks (e.g. ENCHANTING -> OnModeUpdated) to
--add the LF* constant to the inventory/fragment/variables.
--The filterFunctions will be placed at the inventory.additionalFilter entry, and will enhance existing functions, so
--that filter funtions sumarize (e.g. addon1 registers a "Only show stolen filter" and addon2 registers "only show level
--10 items filter" -> Only level 10 stolen items will be shown then.
--The function InstallHelpers below will call special code from the file "helper.lua". In this file you define the
--variable(s) and function name(s) which LibFilters should "REPLACE" -> Means it will overwrite those functions to add
--the call to the LibFilters internal filterFunctions (e.g. at SMITHING crafting tables, function
--EnumerateInventorySlotsAndAddToScrollData -> ZOs vanilla UI code + usage of self.additionalFilter where Libfilters
--added it's filterFunctions).
--
--Important: You need to call LibFilters3:InitializeLibFilters() once to create the hooks and init the library properly

--**********************************************************************************************************************
-- LibFilters information
--**********************************************************************************************************************
--The libraries global name and version information
local MAJOR, GlobalLibName, MINOR = "LibFilters-3.0", "LibFilters3", 1.8
local libPreText = "[" .. MAJOR .."]"

--**********************************************************************************************************************
-- LibFilters global variable and version check -> Only load this library once
--**********************************************************************************************************************
--Was the library loaded already, and if so:
--Was it fully initilaized already?
--Or is the version a newer than the loaded one?
--Abort here then as we do not need to run the code below twice. Should be handled by the txt file's ## AddOnVersion:
--already, so this is just a security check if someone ships this lib without the correct txt file and hardcodes the
--call in it's addon's manifest txt
local lfGlobal = _G[GlobalLibName]
if lfGlobal ~= nil then
    if lfGlobal.isInitialized == true then return end
    if lfGlobal.name ~= nil and lfGlobal.name == MAJOR
        and lfGlobal.version ~= nil and lfGlobal.version >= MINOR then return end
end


--**********************************************************************************************************************
-- LibFilters local variable pointing to global LibFiltersX
--**********************************************************************************************************************
--Local library variable pointer to global LibFilters variable
local libFilters = {}


--**********************************************************************************************************************
-- LibFilters debugging
--**********************************************************************************************************************
--Debugging output
local function debugMessage(text, textType)
    if not text or text == "" then return end
    textType = textType or 'I'
    local logger = libFilters.logger
    if logger ~= nil then
        if textType == 'D' then
            logger:Debug(text)
        elseif textType == 'E' then
            logger:Error(text)
        elseif textType == 'I' then
            logger:Info(text)
        elseif textType == 'V' then
            logger:Verbose(text)
        elseif textType == 'W' then
            logger:Warn(text)
        end
    else
        local textTypeToPrefix = {
            ["D"] = "Debug",
            ["E"] = "Error",
            ["I"] = "Info",
            ["V"] = "Verbose",
            ["W"] = "Warning",
        }
        d(libPreText ..  tostring(textTypeToPrefix[textType]) .. ": ".. tostring(text))
    end
end

--Information debug
local function df(...)
    debugMessage(string.format(...), 'I')
end
--Error debug
local function dfe(...)
    debugMessage(string.format(...), 'E')
end

--Check for old LibFilters 1 / LibFilters 2 versions and deactivate them
local function checkforOldLibFiltersVersionAndDeactive()
    --Are any older versions of libFilters loaded?
    local libFiltersOldVersionErrorText = "Please do not use the library \'%s\' anymore! Deinstall this library and switch to the newest version \'" .. MAJOR .. "\'.\nPlease also inform the author of the addons, which still use \'%s\', to update their addon code immediately!"
    if LibFilters ~= nil then
        LibFilters = nil
        local lf1 = "LibFilters 1"
        dfe(libFiltersOldVersionErrorText, lf1, lf1)
    elseif LibFilters2 ~= nil then
        LibFilters2 = nil
        local lf2 = "LibFilters 2"
        dfe(libFiltersOldVersionErrorText, lf2, lf2)
    end
end


--**********************************************************************************************************************
-- LibFilters filterPanel constants value = "name"
--**********************************************************************************************************************
--The possible libFilters filterPanelIds
local libFiltersFilterConstants = {
    [1]   = "LF_INVENTORY",
    [2]   = "LF_BANK_WITHDRAW",
    [3]   = "LF_BANK_DEPOSIT",
    [4]   = "LF_GUILDBANK_WITHDRAW",
    [5]   = "LF_GUILDBANK_DEPOSIT",
    [6]   = "LF_VENDOR_BUY",
    [7]   = "LF_VENDOR_SELL",
    [8]   = "LF_VENDOR_BUYBACK",
    [9]   = "LF_VENDOR_REPAIR",
    [10]  = "LF_GUILDSTORE_BROWSE",
    [11]  = "LF_GUILDSTORE_SELL",
    [12]  = "LF_MAIL_SEND",
    [13]  = "LF_TRADE",
    [14]  = "LF_SMITHING_REFINE",
    [15]  = "LF_SMITHING_CREATION",
    [16]  = "LF_SMITHING_DECONSTRUCT",
    [17]  = "LF_SMITHING_IMPROVEMENT",
    [18]  = "LF_SMITHING_RESEARCH",
    [19]  = "LF_ALCHEMY_CREATION",
    [20]  = "LF_ENCHANTING_CREATION",
    [21]  = "LF_ENCHANTING_EXTRACTION",
    [22]  = "LF_PROVISIONING_COOK",
    [23]  = "LF_PROVISIONING_BREW",
    [24]  = "LF_FENCE_SELL",
    [25]  = "LF_FENCE_LAUNDER",
    [26]  = "LF_CRAFTBAG",
    [27]  = "LF_QUICKSLOT",
    [28]  = "LF_RETRAIT",
    [29]  = "LF_HOUSE_BANK_WITHDRAW",
    [30]  = "LF_HOUSE_BANK_DEPOSIT",
    [31]  = "LF_JEWELRY_REFINE",
    [32]  = "LF_JEWELRY_CREATION",
    [33]  = "LF_JEWELRY_DECONSTRUCT",
    [34]  = "LF_JEWELRY_IMPROVEMENT",
    [35]  = "LF_JEWELRY_RESEARCH",
    [36]  = "LF_SMITHING_RESEARCH_DIALOG",
    [37]  = "LF_JEWELRY_RESEARCH_DIALOG",
    [38]  = "LF_INVENTORY_QUEST",
}
--register the filterConstants for the filterpanels in the global table _G
for value, filterConstantName in ipairs(libFiltersFilterConstants) do
    _G[filterConstantName] = value
end
libFilters.filterPanels = libFiltersFilterConstants

--Get the min and max filterPanelIds
LF_FILTER_MIN               = LF_INVENTORY
LF_FILTER_MAX               = #libFiltersFilterConstants


--**********************************************************************************************************************
-- LibFilters registered filters array -> Addons will register their filter callbackFunctions into this table, for each
-- LibFilters filterPanel LF_*
--**********************************************************************************************************************
--The filters of the different FilterPanelIds will be registered to these sub-tables
libFilters.filters = {}
local filters = libFilters.filters
for _, filterConstantName in ipairs(libFiltersFilterConstants) do
    filters[_G[filterConstantName]] = {}
end

--**********************************************************************************************************************
-- LibFilters mapping tables for some special filter constants
--**********************************************************************************************************************
--Mapping tables for crafting modes to libFilters constants
--ENCHANTING
local enchantingModeToLibFilters = {
    [ENCHANTING_MODE_CREATION]      = LF_ENCHANTING_CREATION,
    [ENCHANTING_MODE_EXTRACTION]    = LF_ENCHANTING_EXTRACTION,
    [ENCHANTING_MODE_RECIPES]       = nil --not supported yet
}


--**********************************************************************************************************************
-- LibFilters local variables and constants for the inventory classes/inventories
--**********************************************************************************************************************
--Some inventory variables
local playerInventory =     PLAYER_INVENTORY
local inventories =         playerInventory.inventories

local quickslots =          QUICKSLOT_WINDOW

local vendor =              STORE_WINDOW
local buyBack =             BUY_BACK_WINDOW
local repair =              REPAIR_WINDOW

--Some crafting variables
local alchemyClass =        ZO_Alchemy
local alchemy =             ALCHEMY

local smithing =            SMITHING
local refinementPanel =     smithing.refinementPanel
local deconstructionPanel = smithing.deconstructionPanel
local improvementPanel =    smithing.improvementPanel
local researchPanel =       smithing.researchPanel
local researchDialogSelect= SMITHING_RESEARCH_SELECT

local enchantingClass =     ZO_Enchanting
local enchanting =          ENCHANTING

local retraitClass =        ZO_RetraitStation_Retrait_Base      --or ZO_RETRAIT_KEYBOARD?

--Inventory types
local invBackPack   = INVENTORY_BACKPACK
local invBank       = INVENTORY_BANK
local invHouseBank  = INVENTORY_HOUSE_BANK
local invGuildBank  = INVENTORY_GUILD_BANK
local invQuestItem  = INVENTORY_QUEST_ITEM
local invCraftBag   = INVENTORY_CRAFT_BAG


--**********************************************************************************************************************
-- LibFilters local variables and constants for the fragments which are added to some inventory scenes
--**********************************************************************************************************************
--Scene fragments of the inventories/filterPanels
local menuBarInvFragment        = BACKPACK_MENU_BAR_LAYOUT_FRAGMENT
local bankInvFragment           = BACKPACK_BANK_LAYOUT_FRAGMENT
local houseBankInvFragment      = BACKPACK_HOUSE_BANK_LAYOUT_FRAGMENT
local guildBankInvFragment      = BACKPACK_GUILD_BANK_LAYOUT_FRAGMENT
local tradingHouseInvFragment   = BACKPACK_TRADING_HOUSE_LAYOUT_FRAGMENT
local mailInvFragment           = BACKPACK_MAIL_LAYOUT_FRAGMENT
local playerTradeInvFragment    = BACKPACK_PLAYER_TRADE_LAYOUT_FRAGMENT
local storeInvFragment          = BACKPACK_STORE_LAYOUT_FRAGMENT
local fenceInvFragment          = BACKPACK_FENCE_LAYOUT_FRAGMENT
local launderInvFragment        = BACKPACK_LAUNDER_LAYOUT_FRAGMENT


--**********************************************************************************************************************
-- LibFilters local constants for the update of the inventories. Each filterPanelId needs one updaterName. Inventories
-- which are shared (like player backpack is the same at mail, trade, bank deposit, guild bank deposit, etc.) should
-- use the same name in order to be able to throttle the updater calls for the same inventory.
-- Below the table you'll find the updater functions for the player inventories, crafting inventories and others
--**********************************************************************************************************************
--The fixed updater names for the libFilters unique updater string
local filterTypeToUpdaterNameFixed = {
    [LF_BANK_WITHDRAW]              = "BANK_WITHDRAW",
    [LF_GUILDBANK_WITHDRAW]         = "GUILDBANK_WITHDRAW",
    [LF_VENDOR_BUY]                 = "VENDOR_BUY",
    [LF_VENDOR_BUYBACK]             = "VENDOR_BUYBACK",
    [LF_VENDOR_REPAIR]              = "VENDOR_REPAIR",
    [LF_GUILDSTORE_BROWSE]          = "GUILDSTORE_BROWSE",
    [LF_ALCHEMY_CREATION]           = "ALCHEMY_CREATION",
    [LF_PROVISIONING_COOK]          = "PROVISIONING_COOK",
    [LF_PROVISIONING_BREW]          = "PROVISIONING_BREW",
    [LF_CRAFTBAG]                   = "CRAFTBAG",
    [LF_QUICKSLOT]                  = "QUICKSLOT",
    [LF_RETRAIT]                    = "RETRAIT",
    [LF_HOUSE_BANK_WITHDRAW]        = "HOUSE_BANK_WITHDRAW",
    [LF_INVENTORY_QUEST]            = "INVENTORY_QUEST"
}
--The updater names which are shared with others
local filterTypeToUpdaterNameDynamic = {
    ["INVENTORY"] = {
        [LF_INVENTORY] = true,
    },
    ["BANK_DEPOSIT"] = {
        [LF_BANK_DEPOSIT]=true,
    },
    ["GUILDBANK_DEPOSIT"] = {
        [LF_GUILDBANK_DEPOSIT]=true,
    },
    ["VENDOR_SELL"] = {
        [LF_VENDOR_SELL]=true,
    },
    ["GUILDSTORE_SELL"] = {
        [LF_GUILDSTORE_SELL]=true,
    },
    ["MAIL_SEND"] = {
        [LF_MAIL_SEND]=true,
    },
    ["TRADE"] = {
        [LF_TRADE]=true,
    },
    ["FENCE_SELL"] = {
        [LF_FENCE_SELL]=true,
    },
    ["FENCE_LAUNDER"] = {
        [LF_FENCE_LAUNDER]=true,
    },
    ["HOUSE_BANK_DEPOSIT"] = {
        [LF_HOUSE_BANK_DEPOSIT]=true,
    },
    ["SMITHING_REFINE"] = {
        [LF_SMITHING_REFINE]=true,
        [LF_JEWELRY_REFINE]=true,
    },
    ["SMITHING_CREATION"] = {
        [LF_SMITHING_CREATION]=true,
        [LF_JEWELRY_CREATION]=true,
    },
    ["SMITHING_DECONSTRUCT"] = {
        [LF_SMITHING_DECONSTRUCT]=true,
        [LF_JEWELRY_DECONSTRUCT]=true,
    },
    ["SMITHING_IMPROVEMENT"] = {
        [LF_SMITHING_IMPROVEMENT]=true,
        [LF_JEWELRY_IMPROVEMENT]=true,
    },
    ["SMITHING_RESEARCH"] = {
        [LF_SMITHING_RESEARCH]=true,
        [LF_JEWELRY_RESEARCH]=true,
    },
    ["SMITHING_RESEARCH_DIALOG"] = {
        [LF_SMITHING_RESEARCH_DIALOG]=true,
        [LF_JEWELRY_RESEARCH_DIALOG]=true,
    },
    ["ENCHANTING"] = {
        [LF_ENCHANTING_CREATION]=true,
        [LF_ENCHANTING_EXTRACTION]=true,
    },
}
--The filterType to unique updater String table. Will be filled with the fixed updater names and the dynamic afterwards
local filterTypeToUpdaterName = {}
--Add the fixed updaterNames of the filtertypes
filterTypeToUpdaterName = filterTypeToUpdaterNameFixed
--Then dynamically add the other updaterNames from the above table filterTypeToUpdaterNameDynamic
for updaterName, filterTypesTableForUpdater in pairs(filterTypeToUpdaterNameDynamic) do
    if updaterName ~= "" then
        for filterType, isEnabled in pairs(filterTypesTableForUpdater) do
            if isEnabled then
                filterTypeToUpdaterName[filterType] = updaterName
            end
        end
    end
end
libFilters.filterTypeToUpdaterName = filterTypeToUpdaterName

--Update the inventory lists
--if the mouse is enabled, cycle its state to refresh the integrity of the control beneath it
local function SafeUpdateList(object, ...)
--d("[LibFilters3]SafeUpdateList, inv: " ..tostring(...))
    local isMouseVisible = SCENE_MANAGER:IsInUIMode()

    if isMouseVisible then HideMouse() end

    object:UpdateList(...)

    if isMouseVisible then ShowMouse() end
end

local function updateActiveInventoryType(invType)
    libFilters.activeInventoryType = invType
end

local function updateInventoryBase(inventoryOrFragmentVar, inventoryId, callbackFunc)
    local invId = inventoryId or inventoryOrFragmentVar
    updateActiveInventoryType(invId)
    if callbackFunc ~= nil then callbackFunc() end
end

local function updatePlayerInventoryType(inventoryOrFragmentVar, inventoryId, callbackFunc)
    updateInventoryBase(inventoryOrFragmentVar, inventoryId, callbackFunc)
    SafeUpdateList(playerInventory, inventoryOrFragmentVar)
end

local function updateCraftingInventoryType(craftingInventoryOrFragmentVar, inventoryId, callbackFunc, craftingInvRefreshFunc)
    updateInventoryBase(craftingInventoryOrFragmentVar, inventoryId, callbackFunc)
    if craftingInvRefreshFunc ~= nil then
        craftingInvRefreshFunc()
    else
        if craftingInventoryOrFragmentVar.HandleDirtyEvent then
            craftingInventoryOrFragmentVar:HandleDirtyEvent()
        end
    end
end

local function updateOtherInventoryType(otherInventoryOrFragmentVar, inventoryId, callbackFunc)
    updateInventoryBase(otherInventoryOrFragmentVar, inventoryId, callbackFunc)
    SafeUpdateList(otherInventoryOrFragmentVar)
end

--Function to update a ZO_ListDialog1 dialog's list contents
local function dialogUpdaterFunc(listDialogControl)
    if listDialogControl == nil then return nil end
    --Get & Refresh the list dialog
    local listDialog = ZO_InventorySlot_GetItemListDialog()
    if listDialog ~= nil and listDialog.control ~= nil then
        local data = listDialog.control.data
        if not data then return end
        --Update the research dialog?
        if listDialogControl == researchDialogSelect then
            updateActiveInventoryType(researchDialogSelect)
            if data.craftingType and data.researchLineIndex and data.traitIndex then
                --Re-Call the dialog's setup function to clear the list, check available data and filter the items (see helper.lua, helpers["SMITHING_RESEARCH_SELECT"])
                listDialogControl.SetupDialog(listDialogControl, data.craftingType, data.researchLineIndex, data.traitIndex)
            end
        end
    end
end

--The updater functions for the inventories
local inventoryUpdaters = {
    --Inventory backpack variables
    INVENTORY = function()
        updatePlayerInventoryType(invBackPack, nil, nil)
    end,
    CRAFTBAG = function()
        updatePlayerInventoryType(invCraftBag, nil, nil)
    end,
    QUICKSLOT = function()
        updateOtherInventoryType(quickslots, nil, nil)
    end,
    HOUSE_BANK_WITHDRAW = function()
        updatePlayerInventoryType(invHouseBank, nil, nil)
    end,
    INVENTORY_QUEST = function()
        updatePlayerInventoryType(invQuestItem, nil, nil)
    end,
    BANK_WITHDRAW = function()
        updatePlayerInventoryType(invBank, nil, nil)
    end,
    GUILDBANK_WITHDRAW = function()
        updatePlayerInventoryType(invGuildBank, nil, nil)
    end,

    --Fragments
    BANK_DEPOSIT = function()
        updatePlayerInventoryType(invBackPack, bankInvFragment, nil)
    end,
    GUILDBANK_DEPOSIT = function()
        updatePlayerInventoryType(invBackPack, guildBankInvFragment, nil)
    end,
    HOUSE_BANK_DEPOSIT = function()
        updatePlayerInventoryType(invBackPack, houseBankInvFragment, nil)
    end,
    VENDOR_SELL = function()
        updatePlayerInventoryType(invBackPack, storeInvFragment, nil)
    end,
    GUILDSTORE_SELL = function()
        updatePlayerInventoryType(invBackPack, tradingHouseInvFragment, nil)
    end,
    MAIL_SEND = function()
        updatePlayerInventoryType(invBackPack, mailInvFragment, nil)
    end,
    TRADE = function()
        updatePlayerInventoryType(invBackPack, playerTradeInvFragment, nil)
    end,
    FENCE_SELL = function()
        updatePlayerInventoryType(invBackPack, fenceInvFragment, nil)
    end,
    FENCE_LAUNDER = function()
        updatePlayerInventoryType(invBackPack, launderInvFragment, nil)
    end,

    --Other inventory variables
    VENDOR_BUY = function()
        if tradingHouseInvFragment.state ~= SCENE_SHOWN then --"shown"
            updateOtherInventoryType(vendor, nil, function() vendor:GetStoreItems() end)
        end
    end,
    VENDOR_BUYBACK = function()
        updateOtherInventoryType(buyBack, nil, nil)
    end,
    VENDOR_REPAIR = function()
        updateOtherInventoryType(repair, nil, nil)
    end,
    SMITHING_REFINE = function()
        updateCraftingInventoryType(refinementPanel.inventory, nil, nil, nil)
    end,
    SMITHING_CREATION = function()
    end,
    SMITHING_DECONSTRUCT = function()
        updateCraftingInventoryType(deconstructionPanel.inventory, nil, nil, nil)
    end,
    SMITHING_IMPROVEMENT = function()
        updateCraftingInventoryType(improvementPanel.inventory, nil, nil, nil)
    end,
    SMITHING_RESEARCH = function()
        updateCraftingInventoryType(researchPanel, nil, nil, function() researchPanel:Refresh() end)
    end,
    ALCHEMY_CREATION = function()
        updateCraftingInventoryType(alchemy.inventory, nil, nil, nil)
    end,
    ENCHANTING = function()
        updateCraftingInventoryType(enchanting.inventory, nil, nil, nil)
    end,
    RETRAIT = function()
        updateCraftingInventoryType(retraitClass.inventory, nil, nil, nil)
    end,
    SMITHING_RESEARCH_DIALOG = function()
        dialogUpdaterFunc(researchDialogSelect)
    end,

    --Todo: Add support in the future maybe
    PROVISIONING_COOK = function()
    end,
    PROVISIONING_BREW = function()
    end,
    GUILDSTORE_BROWSE = function()
    end,
}
libFilters.inventoryUpdaters = inventoryUpdaters


--**********************************************************************************************************************
--  LibFilters local filter execution functions
--**********************************************************************************************************************
--Run the applied filters at a libFilters filterType (LF_*) now, using the ... parameters (e.g. inventorySlot)
local function runFilters(filterType, ...)
--d("[LibFilters3]runFilters, filterType: " ..tostring(filterType))
    for tag, filter in pairs(filters[filterType]) do
        if not filter(...) then
            return false
        end
    end
    return true
end
libFilters.RunFilters = runFilters

--The filter function, using the inventory/fragment.additionalFilter function/value and the registered filter function at
--the filterType (e.g. LF_INVENTORY) via function runFilters
local function callFilterFunc(p_inventory, filterType)
    local originalFilter = p_inventory.additionalFilter
    local additionalFilterType = type(originalFilter)
    if additionalFilterType == "function" then
        p_inventory.additionalFilter = function(...)
            return originalFilter(...) and runFilters(filterType, ...)
        end
    else
        p_inventory.additionalFilter = function(...)
            return runFilters(filterType, ...)
        end
    end
end
libFilters.CallFilterFunc = callFilterFunc


--**********************************************************************************************************************
--  LibFilters global library functions
--**********************************************************************************************************************
--Returns the minimum possible filterPanelId
function libFilters:GetMinFilter()
    return LF_FILTER_MIN
end


--Returns the maxium possible filterPanelId
function libFilters:GetMaxFilter()
    return LF_FILTER_MAX
end


--Returns the filterPanel connstants table: value = "name"
function libFilters:GetFilterPanels()
    return libFiltersFilterConstants
end


--Hook the inventory layout or inventory to apply additional filter functions
function libFilters:HookAdditionalFilter(filterType, inventoryOrFragment)
    local layoutData = inventoryOrFragment.layoutData or inventoryOrFragment
    layoutData.libFilters3_filterType = filterType
    callFilterFunc(layoutData, filterType)
end


--Hook the inventory in a special way, e.g. at ENCHANTING or ALCHEMY where there is only 1 inventory variable and no
--extra fragment for the different modes (creation, extraction)
-->("enchanting", enchantingInventory, enchanting, "SetEnchantingMode", enchanting.enchantingMode)
function libFilters:HookAdditionalFilterSpecial(specialType, inventory)
    if specialType == "alchemy" then
--[[
        local function onSetAlchemyMode(alchemyVar, alchemyMode)
d("[LibFilters3]Alchemy SetMode: " ..tostring(alchemyMode))
            updateActiveInventoryType(alchemyVar.inventory)
            local libFilters3EnchantingConstant = alchemyModeToLibFilters[alchemyMode]
            inventory.libFilters3_filterType = libFilters3EnchantingConstant
            callFilterFunc(alchemyVar.inventory)
        end
        SecurePostHook(alchemyClass, "SetMode", onSetAlchemyMode)
]]
    elseif specialType == "enchanting" then
        local function onEnchantingModeUpdated(enchantingVar, enchantingMode)
            updateActiveInventoryType(enchanting.inventory)
            local libFilters3EnchantingConstant = enchantingModeToLibFilters[enchantingMode]
            inventory.libFilters3_filterType = libFilters3EnchantingConstant
            if libFilters3EnchantingConstant == nil then return end
            callFilterFunc(inventory, libFilters3EnchantingConstant)
        end
        SecurePostHook(enchantingClass, "OnModeUpdated", function(selfEnchanting)
            onEnchantingModeUpdated(selfEnchanting, selfEnchanting.enchantingMode)
        end)
    end

end


--Get the current libFilters filterType for the inventoryType, where inventoryType would be e.g. INVENTORY_BACKPACK or
--INVENTORY_BANK
function libFilters:GetCurrentFilterTypeForInventory(inventoryType)
    if not inventoryType then return end
    if inventoryType == invBackPack then
        local layoutData = playerInventory.appliedLayout
        if layoutData and layoutData.libFilters3_filterType then
            return layoutData.libFilters3_filterType
        else
            return
        end
    end
    local inventory = inventories[inventoryType] or inventoryType
    if not inventory or not inventory.libFilters3_filterType then return end
    return inventory.libFilters3_filterType
end


--Get the current libFilters filterType for the active inventory. Active inventory will be set as the hook of the supported
--inventories gets applied and as it's updaterFunction is run. The activeInventory will be e.g. INVENTORY_BACKPACK
function libFilters:GetCurrentFilterTypeForActiveInventory()
    local activeInventoryType = libFilters.activeInventoryType
    local currentFilterType = libFilters:GetCurrentFilterTypeForInventory(libFilters.activeInventoryType)
d("[LibFilters3]GetCurrentFilterTypeForActiveInventory-activeInventoryType: " ..tostring(activeInventoryType) .. ", currentFilterType: " ..tostring(currentFilterType))
    return currentFilterType
end


--Requests to call the update function of the inventory/fragment of filterType LF*
function libFilters:RequestUpdate(filterType)
--d("[LibFilters3]RequestUpdate-filterType: " ..tostring(filterType))
    local updaterName = filterTypeToUpdaterName[filterType]
    if not updaterName or updaterName == "" then
        dfe("Invalid arguments to RequestUpdate(%s).\n>Needed format is: number filterPanelId", tostring(filterType))
        return
    end
    local callbackName = "LibFilters_updateInventory_" .. updaterName
    local function Update()
--d(">[LibFilters3]RequestUpdate->Update called")
        EVENT_MANAGER:UnregisterForUpdate(callbackName)
        inventoryUpdaters[updaterName]()
    end
    --cancel previously scheduled update, if any
    EVENT_MANAGER:UnregisterForUpdate(callbackName)
    --register a new one
    EVENT_MANAGER:RegisterForUpdate(callbackName, 10, Update)
end


--Returns the filter callbackFunction for the specified filterTag e.g. <addonName> and filterType LF*
function libFilters:GetFilterCallback(filterTag, filterType)
    if not libFilters:IsFilterRegistered(filterTag, filterType) then return end

    return filters[filterType][filterTag]
end


--Checks if a filter function is already registered for the filterTag e.g. <addonName> and the filterType LF*
function libFilters:IsFilterRegistered(filterTag, filterType)
    if filterType == nil then
        --check whether there's any filter with this tag
        for _, callbacks in pairs(filters) do
            if callbacks[filterTag] ~= nil then
                return true
            end
        end

        return false
    else
        --check only the specified filter type
        local callbacks = filters[filterType]

        return callbacks[filterTag] ~= nil
    end
end


--Registers the filter callbackFunction for the specified filterTag e.g. <addonName> and filterType LF*
function libFilters:RegisterFilter(filterTag, filterType, filterCallback)
    local callbacks = filters[filterType]

    if not filterTag or not callbacks or type(filterCallback) ~= "function" then
        dfe("Invalid arguments to RegisterFilter(%q, %s, %s).\n>Needed format is: String uniqueFilterTag, number libFiltersLF_*FilterPanelConstant, function filterCallbackFunction",
            tostring(filterTag), tostring(filterType), tostring(filterCallback))
        return
    end

    if callbacks[filterTag] ~= nil then
        dfe("filterTag \'%q\' filterType \'%s\' filterCallback function is already in use",
            tostring(filterTag), tostring(filterType))
        return
    end

    callbacks[filterTag] = filterCallback
end


--Un-Registers the filter callbackFunction for the specified filterTag e.g. <addonName> and filterType LF*
function libFilters:UnregisterFilter(filterTag, filterType)
    if not filterTag or filterTag == "" then
        dfe("Invalid arguments to UnregisterFilter(%s, %s).\n>Needed format is: String filterTag, number filterPanelId", tostring(filterTag), tostring(filterType))
        return
    end
    if filterType == nil then
        --unregister all filters with this tag
        for _, callbacks in pairs(filters) do
            if callbacks[filterTag] ~= nil then
                callbacks[filterTag] = nil
            end
        end
    else
        --unregister only the specified filter type
        local callbacks = filters[filterType]

        if callbacks[filterTag] ~= nil then
            callbacks[filterTag] = nil
        end
    end
end


--Used for the SMITHING table -> research panel: Set some values of the currently selected research horizontal scroll list
--etc. so that loops are able to start at these values
function libFilters:SetResearchLineLoopValues(fromResearchLineIndex, toResearchLineIndex, skipTable)
    local craftingType = GetCraftingInteractionType()
    if craftingType == CRAFTING_TYPE_INVALID then return false end
    if not fromResearchLineIndex or fromResearchLineIndex <= 0 then fromResearchLineIndex = 1 end
    if not toResearchLineIndex or toResearchLineIndex > GetNumSmithingResearchLines(craftingType) then
        toResearchLineIndex = GetNumSmithingResearchLines(craftingType)
    end
    local helpers = libFilters.helpers
    if not helpers then return end
    local smithingResearchPanel = helpers["SMITHING.researchPanel:Refresh"].locations[1]
    if smithingResearchPanel then
        smithingResearchPanel.libFilters_3ResearchLineLoopValues = {
            from        =fromResearchLineIndex,
            to          =toResearchLineIndex,
            skipTable   =skipTable,
        }
    end
end


--**********************************************************************************************************************
-- LibFilters hooks into inventories/fragments/LayoutData
--**********************************************************************************************************************
--Hook all the filters at the different inventory panels (libFilters filterPanelIds) now
local function HookAdditionalFilters()
    --[NORMAL INVENTORY / FRAGMENT HOOKS]
    libFilters:HookAdditionalFilter(LF_INVENTORY, inventories[invBackPack])
    libFilters:HookAdditionalFilter(LF_INVENTORY, menuBarInvFragment)

    libFilters:HookAdditionalFilter(LF_BANK_WITHDRAW, inventories[invBank])
    libFilters:HookAdditionalFilter(LF_BANK_DEPOSIT, bankInvFragment)

    libFilters:HookAdditionalFilter(LF_GUILDBANK_WITHDRAW, inventories[invGuildBank])
    libFilters:HookAdditionalFilter(LF_GUILDBANK_DEPOSIT, guildBankInvFragment)

    libFilters:HookAdditionalFilter(LF_VENDOR_BUY, vendor)
    libFilters:HookAdditionalFilter(LF_VENDOR_SELL, storeInvFragment)
    libFilters:HookAdditionalFilter(LF_VENDOR_BUYBACK, buyBack)
    libFilters:HookAdditionalFilter(LF_VENDOR_REPAIR, repair)

    libFilters:HookAdditionalFilter(LF_GUILDSTORE_SELL, tradingHouseInvFragment)

    libFilters:HookAdditionalFilter(LF_MAIL_SEND, mailInvFragment)

    libFilters:HookAdditionalFilter(LF_TRADE, playerTradeInvFragment)

    libFilters:HookAdditionalFilter(LF_SMITHING_REFINE, refinementPanel.inventory)
    --libFilters:HookAdditionalFilter(LF_SMITHING_CREATION, )
    libFilters:HookAdditionalFilter(LF_SMITHING_DECONSTRUCT, deconstructionPanel.inventory)
    libFilters:HookAdditionalFilter(LF_SMITHING_IMPROVEMENT, improvementPanel.inventory)
    libFilters:HookAdditionalFilter(LF_SMITHING_RESEARCH, researchPanel)
    libFilters:HookAdditionalFilter(LF_JEWELRY_REFINE, refinementPanel.inventory)
    --libFilters:HookAdditionalFilter(LF_JEWELRY_CREATION, )
    libFilters:HookAdditionalFilter(LF_JEWELRY_DECONSTRUCT, deconstructionPanel.inventory)
    libFilters:HookAdditionalFilter(LF_JEWELRY_IMPROVEMENT, improvementPanel.inventory)
    libFilters:HookAdditionalFilter(LF_JEWELRY_RESEARCH, researchPanel)

    libFilters:HookAdditionalFilter(LF_ALCHEMY_CREATION, alchemy.inventory)

    libFilters:HookAdditionalFilter(LF_FENCE_SELL, fenceInvFragment)
    libFilters:HookAdditionalFilter(LF_FENCE_LAUNDER, launderInvFragment)

    libFilters:HookAdditionalFilter(LF_CRAFTBAG, inventories[invCraftBag])

    libFilters:HookAdditionalFilter(LF_QUICKSLOT, quickslots)

    libFilters:HookAdditionalFilter(LF_RETRAIT, retraitClass)

    libFilters:HookAdditionalFilter(LF_HOUSE_BANK_WITHDRAW, inventories[invHouseBank])
    libFilters:HookAdditionalFilter(LF_HOUSE_BANK_DEPOSIT, houseBankInvFragment)

    libFilters:HookAdditionalFilter(LF_SMITHING_RESEARCH_DIALOG, researchDialogSelect)
    libFilters:HookAdditionalFilter(LF_JEWELRY_RESEARCH_DIALOG, researchDialogSelect)

    libFilters:HookAdditionalFilter(LF_INVENTORY_QUEST, inventories[invQuestItem])

    --[SPECIAL HOOKS]
    --HookAdditionalFilter: Does not work for enchanting as all filter constants LF_ENCHANTNG* use ENCHANTING.inventory
    --and thus the last call to it (currently LF_ENCHANTING_EXTRACTION) will override the value of before registered ones
    libFilters:HookAdditionalFilterSpecial("enchanting", enchanting.inventory)

    --libFilters:HookAdditionalFilter(LF_PROVISIONING_COOK, )
    --libFilters:HookAdditionalFilter(LF_PROVISIONING_BREW, )
end

--Register all the helper functions of LibFilters, for some panels like the Research or ResearchDialog, or even
-- deconstruction and improvement, etc.
--These helper functions will overwrite original vanilla UI ESO functions in order to add and use the LibFilters
--"predicate"/"filterFunction" within the ZOs code. If the vanilla UI function updates this versions here need to be
--updated as well!
--> See file helper.lua
libFilters.helpers = {}
local helpers = libFilters.helpers

--Install the helpers from table helpers now -> See file helper.lua, table "helpers"
local function InstallHelpers()
    for _, package in pairs(helpers) do
        local funcName = package.helper.funcName
        local func = package.helper.func

        for _, location in pairs(package.locations) do
            --e.g. ZO_SmithingExtractionInventory["GetIndividualInventorySlotsAndAddToScrollData"] = overwritten
            --function from helpers table, param "func"
            location[funcName] = func
        end
    end
end


--Function needed to be called from your addon to start the libFilters instance and enable the filtering!
function libFilters:InitializeLibFilters()
    checkforOldLibFiltersVersionAndDeactive()

    if libFilters.isInitialized == true then return end

    InstallHelpers()
    HookAdditionalFilters()

    libFilters.isInitialized = true
end


--**********************************************************************************************************************
-- LibFilters global variable and initialization
--**********************************************************************************************************************
function libFilters:Initialize()
    libFilters.name     = MAJOR
    libFilters.version  = MINOR
    libFilters.author   = "ingeniousclown, Randactyl, Baertram"

    libFilters.isInitialized = false
    libFilters.activeInventoryType = nil

    --LibDebugLogger - Debugging output
    if LibDebugLogger then libFilters.logger = LibDebugLogger(MAJOR) end

    --Create the global library variable
    _G[GlobalLibName] = libFilters
end
libFilters:Initialize()
