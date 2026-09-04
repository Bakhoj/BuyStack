local addonName, addon = ...
local blockNextStackSplit = false

-- Session storage: itemID -> boolean (true = always buy max)
local sessionAutoBuy = {}

-- Block the stack split dialog
local orig_OpenStackSplitFrame = OpenStackSplitFrame
function OpenStackSplitFrame(maxStack, parent, anchor, anchorTo, ...)
    if blockNextStackSplit then
        blockNextStackSplit = false
        return
    end
    return orig_OpenStackSplitFrame(maxStack, parent, anchor, anchorTo, ...)
end

-- Create confirmation dialog
StaticPopupDialogs["BUYSTACK_CONFIRM_AUTO_BUY_MAX_STACK"] = {
    text = "Always buy max stack of %s for this session?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        sessionAutoBuy[data.itemID] = true
        BuyMerchantItem(data.index, data.toBuy)
    end,
    OnCancel = function(self, data)
        sessionAutoBuy[data.itemID] = false
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Hook merchant buttons
local function HookMerchantButtons()
    for i = 1, MERCHANT_ITEMS_PER_PAGE do
        local button = _G["MerchantItem"..i.."ItemButton"]
        if button and not button.hookedForMaxBuy then
            button.hookedForMaxBuy = true

            button:HookScript("OnMouseDown", function(self, btn)
                if btn == "RightButton" and IsShiftKeyDown() and IsAltKeyDown() then
                    local index = self:GetID()
                    local link = GetMerchantItemLink(index)
                    local itemID = link and tonumber(link:match("item:(%d+)"))
                    local maxStack = GetMerchantItemMaxStack(index)
                    local _,_,_,quantity = GetMerchantItemInfo(index)

                    if not itemID then return end
                    if maxStack <= 1 then return end

                    local choice = sessionAutoBuy[itemID]
                    blockNextStackSplit = true
                    local toBuy = maxStack

                    local partialMissing = maxStack - (GetItemCount(itemID, false) % maxStack)
                    if partialMissing > 0 then
                        local quantitiesToBuy = math.floor(partialMissing / quantity)
                        if quantitiesToBuy > 0 then
                            toBuy = quantitiesToBuy * quantity
                        end
                    end
                    
                    if choice == nil or choice == false then
                        -- show dialog
                        StaticPopup_Show("BUYSTACK_CONFIRM_AUTO_BUY_MAX_STACK",
                            GetMerchantItemInfo(index),
                            nil,
                            {index = index, maxStack = maxStack, itemID = itemID, toBuy = toBuy})
                    elseif choice == true then
                        -- auto buy max
                        BuyMerchantItem(index, toBuy)
                    end
                end
            end)
        end
    end
end

-- Hook buttons when merchant opens
local f = CreateFrame("Frame")
f:RegisterEvent("MERCHANT_SHOW")
f:SetScript("OnEvent", HookMerchantButtons)

if MerchantFrame and MerchantFrame:IsShown() then
    HookMerchantButtons()
end
