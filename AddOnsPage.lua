-- Stormhide's entry in Blizzard's settings (Options → AddOns). Every setting lives in Stormhide's own
-- window, so the page only points there: the class icon, name and version, a button that closes
-- Blizzard's settings and opens ours, and the /stormhide command. Same idea as Leatrix Plus's page.
local addonName, ns = ...
local L = ns.L

if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
    return
end

local CLASS_ICON = "Interface\\Icons\\ClassIcon_Shaman" -- as the settings window's portrait

local page = CreateFrame("Frame")

local icon = page:CreateTexture(nil, "ARTWORK")
icon:SetSize(96, 96)
icon:SetPoint("TOP", 0, -64)
icon:SetTexture(CLASS_ICON)

local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
title:SetPoint("TOP", icon, "BOTTOM", 0, -20)
title:SetText("Stormhide")
local titleFont, _, titleFlags = title:GetFont()
title:SetFont(titleFont, 48, titleFlags)

local GetMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local version = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
version:SetPoint("TOP", title, "BOTTOM", 0, -8)
version:SetText(GetMetadata and GetMetadata(addonName, "Version") or "")

local open = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
open:SetSize(200, 32)
open:SetPoint("TOP", version, "BOTTOM", 0, -40)
open:SetText(L["Open Stormhide Settings"])
open:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel:IsShown() then
        HideUIPanel(SettingsPanel)
    end
    ns.ShowSettings()
end)

local command = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
command:SetPoint("TOP", open, "BOTTOM", 0, -16)
command:SetText(L["or type /stormhide"])

local category = Settings.RegisterCanvasLayoutCategory(page, "Stormhide")
Settings.RegisterAddOnCategory(category)
