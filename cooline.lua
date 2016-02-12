local cooline = CreateFrame('Button', nil, UIParent)
cooline:SetScript('OnEvent', function()
	this[event]()
end)
cooline:RegisterEvent('VARIABLES_LOADED')
cooline:RegisterEvent('SPELL_UPDATE_COOLDOWN')
cooline:RegisterEvent('BAG_UPDATE_COOLDOWN')

cooline_settings = {}

local frame_pool = {}
local cooldowns = {}

function cooline.hyperlink_name(hyperlink)
    local _, _, name = strfind(hyperlink, '|Hitem:%d+:%d+:%d+:%d+|h[[]([^]]+)[]]|h')
    return name
end

function cooline.detect_cooldowns()
	
	local function start_cooldown(name, texture, start_time, duration)
		local end_time = start_time + duration
			
		if cooldowns[name] and cooldowns[name].end_time == end_time then
			return
		end

		cooldowns[name] = cooldowns[name] or tremove(frame_pool) or cooline.cooldown_frame()
		local frame = cooldowns[name]
		frame:SetWidth(22)
		frame:SetHeight(22)
		frame.icon:SetTexture(texture)
		frame:SetAlpha((end_time - GetTime() > 360) and 0.6 or 1)
		frame.end_time = end_time
		frame:Show()
	end
	
    for bag = 0,4 do
        if GetBagName(bag) then
            for slot = 1, GetContainerNumSlots(bag) do
				local start_time, duration, enabled = GetContainerItemCooldown(bag, slot)
				if enabled == 1 then
					local name = cooline.hyperlink_name(GetContainerItemLink(bag, slot))
					if duration > 3 and duration < 3601 then
						start_cooldown(
							name,
							GetContainerItemInfo(bag, slot),
							start_time,
							duration
						)
					elseif duration == 0 then
						cooline.clear_cooldown(name)
					end
				end
            end
        end
    end
	
	for slot=0,19 do
		local start_time, duration, enabled = GetInventoryItemCooldown('player', slot)
		if enabled == 1 then
			local name = cooline.hyperlink_name(GetInventoryItemLink('player', slot))
			if duration > 3 and duration < 3601 then
				start_cooldown(
					name,
					GetInventoryItemTexture('player', slot),
					start_time,
					duration
				)
			elseif duration == 0 then
				cooline.clear_cooldown(name)
			end
		end
	end
	
	local _, _, offset, spell_count = GetSpellTabInfo(GetNumSpellTabs())
	local total_spells = offset + spell_count
	for id=1,total_spells do
		local start_time, duration, enabled = GetSpellCooldown(id, BOOKTYPE_SPELL)
		local name = GetSpellName(id, BOOKTYPE_SPELL)
		if enabled == 1 and duration > 2.5 then
			start_cooldown(
				name,
				GetSpellTexture(id, BOOKTYPE_SPELL),
				start_time,
				duration
			)
		elseif duration == 0 then
			cooline.clear_cooldown(name)
		end
	end
	
	cooline.on_update(true)
end

function cooline.cooldown_frame()
	local frame = CreateFrame('Frame', nil, cooline.border)
	frame:SetBackdrop({ bgFile=[[Interface\AddOns\cooline\backdrop.tga]] })
	frame:SetBackdropColor(0.8, 0.4, 0, 1)
	frame.icon = frame:CreateTexture(nil, 'ARTWORK')
	frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	frame.icon:SetPoint('TOPLEFT', 1, -1)
	frame.icon:SetPoint('BOTTOMRIGHT', -1, 1)
	return frame
end

local function place_H(this, v, just)
	this:SetPoint(just or 'CENTER', cooline, 'LEFT', v, 0)
end
local function place_HR(this, v, just)
	this:SetPoint(just or 'CENTER', cooline, 'LEFT', 360 - v, 0)
end
local function place_V(this, v, just)
	this:SetPoint(just or 'CENTER', cooline, 'BOTTOM', 0, v)
end
local function place_VR(this, v, just)
	this:SetPoint(just or 'CENTER', cooline, 'BOTTOM', 0, 18 - v)
end

function cooline.label(f, text, offset, just)
	local fs = f or cooline.overlay:CreateFontString(nil, 'OVERLAY')
	fs:SetFont([[Fonts\FRIZQT__.TTF]], 10)
	fs:SetTextColor(1, 1, 1, 0.8)
	fs:SetText(text)
	fs:SetWidth(10 * 3)
	fs:SetHeight(10 + 2)
	fs:SetShadowColor(0, 0, 0, 0.5)
	fs:SetShadowOffset(1, -1)
	if just then
		fs:ClearAllPoints()
		if cooline_settings.reverse then
			just = (just == 'LEFT' and 'RIGHT') or 'LEFT'
			offset = offset + ((just == 'LEFT' and 1) or -1)
			fs:SetJustifyH(just)
		else
			offset = offset + ((just == 'LEFT' and 1) or -1)
			fs:SetJustifyH(just)
		end
	else
		fs:SetJustifyH('CENTER')
	end
	cooline.place(fs, offset, just)
	return fs
end

function cooline.clear_cooldown(name)
	if cooldowns[name] then
		cooldowns[name]:Hide()
		tinsert(frame_pool, cooldowns[name])
		cooldowns[name] = nil
	end
end

local relevel, throt = false, 0

function cooline.update_cooldown(frame, position, tthrot, relevel)
	throt = min(throt, tthrot)
	if relevel then
		frame:SetFrameLevel(random(1,5) + 2)
	end
	cooline.place(frame, position)
end

do
	local last_update, last_relevel = GetTime(), GetTime()
	
	function cooline.on_update(force)
		if GetTime() - last_update < throt and not force then return end
		last_update = GetTime()
		
		relevel = false
		if GetTime() - last_relevel > 0.4 then
			relevel, last_relevel = true, GetTime()
		end
		isactive, throt = false, 1.5
		for name, frame in pairs(cooldowns) do
			local time_left = frame.end_time - GetTime()
			isactive = isactive or time_left < 360
			
			if time_left < -1 then
				throt = min(throt, 0.2)
				isactive = true
				cooline.clear_cooldown(name)
			elseif time_left < 0 then
				cooline.update_cooldown(frame, 0, 0, relevel)
				frame:SetAlpha(1 + time_left)  -- fades
			elseif time_left < 0.3 then
				local size = cooline.iconsize * (0.5 - time_left) * 5  -- iconsize + iconsize * (0.3 - time_left) / 0.2
				frame:SetWidth(size)
				frame:SetHeight(size)
				cooline.update_cooldown(frame, cooline.section * time_left, 0, relevel)
			elseif time_left < 1 then
				cooline.update_cooldown(frame, cooline.section * time_left, 0, relevel)
			elseif time_left < 3 then
				cooline.update_cooldown(frame, cooline.section * (time_left + 1) * 0.5, 0.02, relevel)  -- 1 + (time_left - 1) / 2
			elseif time_left < 10 then
				cooline.update_cooldown(frame, cooline.section * (time_left + 11) * 0.14286, time_left > 4 and 0.05 or 0.02, relevel)  -- 2 + (time_left - 3) / 7
			elseif time_left < 30 then
				cooline.update_cooldown(frame, cooline.section * (time_left + 50) * 0.05, 0.06, relevel)  -- 3 + (time_left - 10) / 20
			elseif time_left < 120 then
				cooline.update_cooldown(frame, cooline.section * (time_left + 330) * 0.011111, 0.18, relevel)  -- 4 + (time_left - 30) / 90
			elseif time_left < 360 then
				cooline.update_cooldown(frame, cooline.section * (time_left + 1080) * 0.0041667, 1.2, relevel)  -- 5 + (time_left - 120) / 240
				frame:SetAlpha(1)
			else
				cooline.update_cooldown(frame, 6 * cooline.section, 2, relevel)
			end
		end
		cooline:SetAlpha(isactive and 1 or 0.5)
	end
end

function cooline.initialize()
	cooline:SetWidth(360)
	cooline:SetHeight(18)
	cooline:SetPoint('CENTER', cooline_settings.x or 0, cooline_settings.y or -240)
	
	cooline.bg = cooline.bg or cooline:CreateTexture(nil, 'ARTWORK')
	cooline.bg:SetTexture([[Interface\TargetingFrame\UI-StatusBar]])
	cooline.bg:SetVertexColor(0, 0, 0, 0.5)
	cooline.bg:SetAllPoints(cooline)
	cooline.bg:SetTexCoord(0, 1, 0, 1)

	cooline.border = cooline.border or CreateFrame('Frame', nil, cooline)
	cooline.border:SetPoint('TOPLEFT', -4, 4)
	cooline.border:SetPoint('BOTTOMRIGHT', 4, -4)
	cooline.border:SetBackdrop({
		edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
		edgeSize = 16,
	})
	cooline.border:SetBackdropBorderColor(1, 1, 1, 1)

	cooline.overlay = cooline.overlay or CreateFrame('Frame', nil, cooline.border)
	cooline.overlay:SetFrameLevel(24)

	cooline.section = 360 / 6
	cooline.iconsize = 18 + 4
	cooline.place = cooline_settings.reverse and place_HR or place_H

	cooline.tick0 = cooline.label(cooline.tick0, '0', 0, 'LEFT')
	cooline.tick1 = cooline.label(cooline.tick1, '1', cooline.section)
	cooline.tick3 = cooline.label(cooline.tick3, '3', cooline.section * 2)
	cooline.tick10 = cooline.label(cooline.tick10, '10', cooline.section * 3)
	cooline.tick30 = cooline.label(cooline.tick30, '30', cooline.section * 4)
	cooline.tick120 = cooline.label(cooline.tick120, '2m', cooline.section * 5)
	cooline.tick300 = cooline.label(cooline.tick300, '6m', cooline.section * 6, 'RIGHT')
end

function cooline.BAG_UPDATE_COOLDOWN()
	cooline.detect_cooldowns()
end

function cooline.SPELL_UPDATE_COOLDOWN()
	cooline.detect_cooldowns()
end

function cooline.VARIABLES_LOADED()

	cooline:SetClampedToScreen(true)
	cooline:EnableMouse(true)
	cooline:SetMovable(true)
	cooline:SetResizable(true)
	cooline:RegisterForDrag('LeftButton')
	cooline:RegisterForClicks('LeftButtonUp', 'RightButtonUp', 'RightButtonDown')
	cooline:SetScript('OnDragStart', function() this:StartMoving() end)
	cooline:SetScript('OnDragStop', function()
		this:StopMovingOrSizing()
		local x, y = this:GetCenter()
		local ux, uy = UIParent:GetCenter()
		cooline_settings.x, cooline_settings.y = floor(x - ux + 0.5), floor(y - uy + 0.5)
	end)
	cooline:SetScript('OnUpdate', function()
		this:EnableMouse(IsAltKeyDown())
		cooline.on_update()
	end)
	cooline:SetScript('OnDoubleClick', function()
		cooline_settings.reverse = not cooline_settings.reverse
		cooline.initialize()
	end)
	-- cooline:SetScript('OnMouseDown', function()
		-- if arg1 == 'RightButton' then
			-- this:StartSizing('BOTTOMRIGHT')
		-- end
	-- end)
	-- cooline:SetScript('OnMouseUp', function()
		-- if arg1 == 'RightButton' then
			-- this:StopMovingOrSizing()
		-- end
	-- end)

	cooline.initialize()
	cooline.detect_cooldowns()
end