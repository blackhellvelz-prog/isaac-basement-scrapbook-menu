-- localfixes: горячие клавиши модов (17.10, просьбы пользователя: «перераспределить Hotkeys — некоторые открывают
-- одной кнопкой сразу много»; «и сделать ещё так, что при паузе показывались хоткеи этих модов»). Полная таблица
-- клавиш всех модов и почему так — docs/HOTKEYS.md (tools/hotkeys_scan.py).
--
-- 1) Разовая перенастройка (флаг в данных localfixes: потом выбор игрока в меню модов не трогаем):
--    - энциклопедия «статья последнего предмета»: клавиша V → J (V открывает и дерево PST — открывались оба окна);
--      на геймпаде Select (это карта) → «только клавиша»;
--    - Dead Sea Scrolls на геймпаде: «любой стик» → «левый стик» (R3 открывает и Mod Config Menu).
-- 2) Обзор инвентаря EID (большая панель): на клавиатуре — держать I. На Tab висели ещё карта игры, MinimapAPI,
--    названия комнат FF, шкала веры IPECAC, вторые названия Mod Translator, название этажа StageAPI. На геймпаде —
--    как было (держать Select): свободных кнопок нет. Зовёт EID (apply_fixes: eid_reminder_key).
-- 3) Памятка на экране паузы (MC_POST_PAUSE_SCREEN_RENDER, только главное меню паузы): клавиши модов, которые
--    стоят, — справа, под мини-картой, русским шрифтом Team Meat (как у игры).
-- свой текст — на языке игры (19.10, «Один мод, по языку игры»): русский — в русской игре, иначе английский
local function L(ru, en)
	local H = LOCALFIXES and LOCALFIXES.HandFont
	if H and H.L then return H.L(ru, en) end
	local ok, l = pcall(function() return Options.Language end)
	return (ok and l == "ru") and ru or en
end
local mod = LOCALFIXES.Mod   -- мод localfixes (кладёт main.lua перед include)
local game = Game()
local M = {}

M.EID_REMINDER_KEY = Keyboard.KEY_I
local ENCY_KEY = Keyboard.KEY_J
local MIGRATION = "hotkeys1"

-- имя клавиши для памятки
local NAMES = { [Keyboard.KEY_TAB] = "Tab", [Keyboard.KEY_SPACE] = L("Пробел", "Space"), [Keyboard.KEY_ESCAPE] = "Esc",
	[Keyboard.KEY_LEFT_SHIFT] = "Shift", [Keyboard.KEY_RIGHT_SHIFT] = L("Пр. Shift", "R. Shift"), [Keyboard.KEY_LEFT_CONTROL] = "Ctrl",
	[Keyboard.KEY_LEFT_ALT] = "Alt" }
local function keyName(k)
	if type(k) ~= "number" or k < 0 then return nil end
	if NAMES[k] then return NAMES[k] end
	if k >= 65 and k <= 90 or k >= 48 and k <= 57 then return string.char(k) end
	if k >= Keyboard.KEY_F1 and k <= Keyboard.KEY_F12 then return "F" .. (k - Keyboard.KEY_F1 + 1) end
	local ih = InputHelper and InputHelper.KeyboardToString
	return ih and ih[k] or ("#" .. k)
end

-- 1) разовая перенастройка --------------------------------------------------------------------------------------
local function loadFlags()
	local ok, s = pcall(function() return mod:HasData() and mod:LoadData() or "" end)
	return ok and s or ""
end

local function migrate()
	local flags = loadFlags()
	if flags:find(MIGRATION, 1, true) then return end
	local done = {}
	if type(Encyclopedia) == "table" then
		if Encyclopedia.KeyLastPickup == Keyboard.KEY_V then
			Encyclopedia.KeyLastPickup = ENCY_KEY
			if type(Encyclopedia.savedata) == "table" then Encyclopedia.savedata.KeyLastPickup = ENCY_KEY end
			done[#done + 1] = "энциклопедия V→J"
		end
		if Encyclopedia.GamepadLastPickup == 5 then
			Encyclopedia.GamepadLastPickup = 7
			if type(Encyclopedia.savedata) == "table" then Encyclopedia.savedata.GamepadLastPickup = 7 end
			done[#done + 1] = "энциклопедия Select→клавиша"
		end
		if Encyclopedia.SaveData then pcall(Encyclopedia.SaveData, Encyclopedia) end
	end
	local dss = DeadSeaScrollsMenu
	if dss and dss.GetGamepadToggleSetting and dss.SaveGamepadToggleSetting then
		local ok, cur = pcall(dss.GetGamepadToggleSetting)
		if ok and (cur == 1 or cur == nil) then
			pcall(dss.SaveGamepadToggleSetting, 2)
			done[#done + 1] = "DSS геймпад: левый стик"
		end
	end
	pcall(function() mod:SaveData(flags .. MIGRATION .. ";") end)
	Isaac.DebugString("[localfixes] горячие клавиши: " .. (#done > 0 and table.concat(done, ", ") or "без изменений"))
end

-- Разовые правки интерфейса (18.10, шаг «интерфейсы модов»), флаг «ui1» — потом настройки в MCM не трогаем:
-- - подсказка PST «V / LB — открыть дерево» на экране паузы пряталась под листом паузы — выключена (клавиша есть
--   в памятке «Клавиши модов»);
-- - описания EID (и заголовок обзора инвентаря) наезжали на полоску опыта PST слева вверху — EID ниже на 12.
local MIGRATION_UI = "ui1"
local function migrateUI()
	local flags = loadFlags()
	if flags:find(MIGRATION_UI, 1, true) then return end
	local done = {}
	if PST and PST.config and PST.config.drawPauseText then
		PST.config.drawPauseText = false
		done[#done + 1] = "подсказка PST на паузе выкл."
	end
	if EID and EID.Config and PST and EID.Config["YPosition"] == 45 then
		EID.Config["YPosition"] = 57
		if EID.SaveConfig then pcall(EID.SaveConfig, EID) end
		done[#done + 1] = "EID ниже на 12"
	end
	pcall(function() mod:SaveData(loadFlags() .. MIGRATION_UI .. ";") end)
	Isaac.DebugString("[localfixes] интерфейс: " .. (#done > 0 and table.concat(done, ", ") or "без изменений"))
end
mod:AddPriorityCallback(ModCallbacks.MC_POST_GAME_STARTED, 100002, function() pcall(migrate); pcall(migrateUI) end)

-- 2) обзор инвентаря EID ----------------------------------------------------------------------------------------
-- Как EID:PlayersActionPressed: (true, номер игрока) или false. Клавиатура (индекс 0) — держать I; геймпады —
-- кнопка EID (по умолчанию карта/Select).
function M.EIDReminderHeld(eid)
	for idx, num in pairs(eid.controllerIndexes or {}) do
		if idx == 0 then
			if Input.IsButtonPressed(M.EID_REMINDER_KEY, 0) then return true, num end
		elseif Input.IsActionPressed(eid.Config["BagOfCraftingToggleKey"], idx) then
			return true, num
		end
	end
	return false
end

-- 3) памятка на экране паузы ------------------------------------------------------------------------------------
-- Место: полоса справа от листа паузы (его правый край — ~0.80 ширины экрана), под мини-картой. Шрифт — LanaPixel
-- (кириллица, им же пишет PST): Team Meat в эту полосу (~99 точек при 521) не влезает.
local font
local function getFont()
	if font == nil then
		if PST and PST.miniFont and PST.miniFont.IsLoaded and PST.miniFont:IsLoaded() then
			font = PST.miniFont
		else
			font = Font()
			font:Load("font/cjk/lanapixel.fnt")
			if not font:IsLoaded() then font = false end
		end
	end
	return font or nil
end

local function onPad()
	local p = Isaac.GetPlayer(0)
	return p and p.ControllerIndex and p.ControllerIndex > 0
end

-- строки памятки: { {клавиши}, что делает } — только то, что стоит. Клавиши клавиатуры — строки («C», «F1»),
-- кнопки геймпада — «pad:L3» и т. п. (значки игры)
local function memoLines()
	local L, pad = {}, onPad()
	local function add(keys, what) if keys and keys[1] then L[#L + 1] = { keys, what } end end
	if DeadSeaScrollsMenu then
		local k = DeadSeaScrollsMenu.GetMenuKeybindSetting and keyName(DeadSeaScrollsMenu.GetMenuKeybindSetting())
		add(pad and { "pad:L3" } or ((k and k ~= "F1") and { k, "F1" } or { "F1" }), L("меню DSS", "DSS menu"))
	end
	if ModConfigMenu then
		local cfg = ModConfigMenu.Config and ModConfigMenu.Config["Mod Config Menu"] or {}
		local k = keyName(cfg.OpenMenuKeyboard)
		add(pad and { "pad:R3" } or ((k and k ~= "F10") and { k, "F10" } or { "F10" }), "MCM")
	end
	if PST then add(pad and { "pad:LB" } or { "V" }, L("дерево навыков", "skill tree")) end
	if type(Encyclopedia) == "table" and not pad then
		add({ keyName(Encyclopedia.KeyLastPickup) }, L("энциклопедия", "encyclopedia"))
	end
	if EID then
		add(pad and { "pad:Select" } or { keyName(M.EID_REMINDER_KEY) }, L("обзор (держ.)", "overview (hold)"))
		if not pad then add({ keyName(EID.Config and EID.Config["HideKey"]) }, L("описания EID", "EID descriptions")) end
	end
	add(pad and { "pad:Select" } or { "Tab" }, L("карта", "map"))
	return L
end

-- картинки клавиш: клавиатура — своя клавиша в стиле значков игры (tools/gen_keycap.py: края 4 px + середина 1 px,
-- высота 14); геймпад — значки игры gfx/ui/buttons.anm2 (анимация XboxOne, кадры слоя: L3 8, R3 9, LB 10, RB 11,
-- LT 12, RT 13, Select 14, Start 15; опора — центр 16, 8)
local PAD_FRAME = { L3 = 8, R3 = 9, LB = 10, RB = 11, LT = 12, RT = 13, Select = 14, Start = 15 }
local capSpr, padSpr
local function sprites()
	if capSpr == nil then
		capSpr = Sprite()
		capSpr:Load("gfx/ui/localfixes/keycap.anm2", true)
		if not capSpr:IsLoaded() then capSpr = false end
		padSpr = Sprite()
		padSpr:Load("gfx/ui/buttons.anm2", true)
		if padSpr:IsLoaded() then padSpr:SetFrame("XboxOne", 0) else padSpr = false end
	end
	return capSpr or nil, padSpr or nil
end

local CAP_TEXT = KColor(0.86, 0.86, 0.86, 1)

-- одна клавиша в (x, y) — верх строки; ширина
function M.drawKey(f, key, x, y)
	local cap, padS = sprites()
	local p = key:match("^pad:(.+)$")
	if p then
		if padS and PAD_FRAME[p] then
			padS:SetLayerFrame(0, PAD_FRAME[p])
			padS:Render(Vector(x + 8, y + 9))
			return 17
		end
		key = p
	end
	local tw = f:GetStringWidthUTF8(key)
	local w = math.max(14, tw + 8)
	if cap then
		cap:SetFrame("Left", 0)
		cap.Scale = Vector(1, 1)
		cap:Render(Vector(x, y))
		cap:SetFrame("Mid", 0)
		cap.Scale = Vector(w - 8, 1)
		cap:Render(Vector(x + 4, y))
		cap.Scale = Vector(1, 1)
		cap:SetFrame("Right", 0)
		cap:Render(Vector(x + w - 4, y))
		f:DrawStringUTF8(key, x + (w - tw) / 2, y + 7 - f:GetLineHeight() / 2, CAP_TEXT, 0, false)
	else
		f:DrawStringUTF8("[" .. key .. "]", x, y, KColor(1, 0.85, 0.35, 1), 0, false)
		w = f:GetStringWidthUTF8("[" .. key .. "]")
	end
	return w
end

-- несколько клавиш через «/»; ширина
function M.drawKeys(f, keys, x, y, dry)
	local x1 = x
	for i, k in ipairs(keys) do
		if i > 1 then
			if not dry then f:DrawStringUTF8("/", x1 + 1, y + 1, KColor(0.8, 0.8, 0.8, 1), 0, false) end
			x1 = x1 + f:GetStringWidthUTF8("/") + 2
		end
		if dry then
			local p = k:match("^pad:(.+)$")
			x1 = x1 + ((p and PAD_FRAME[p]) and 17 or math.max(14, f:GetStringWidthUTF8(p or k) + 8))
		else
			x1 = x1 + M.drawKey(f, k, x1, y)
		end
	end
	return x1 - x
end

local TEXT_COLOR, HEAD_COLOR = KColor(1, 1, 1, 0.95), KColor(0.8, 0.8, 0.8, 1)
local cache, cacheFrame = nil, -1

function M.renderPauseMemo()
	if not (PauseMenu and PauseMenu.GetState and PauseMenu.GetState() == 1) then return end
	local f = getFont()
	if not f then return end
	local fc = Isaac.GetFrameCount()
	if not cache or fc - cacheFrame > 30 then cache, cacheFrame = memoLines(), fc end
	if #cache == 0 then return end
	local W = Isaac.GetScreenWidth()
	local lh = f:GetLineHeight()
	local x0 = math.floor(W * 0.805) + 2
	local boxW = W - x0 - 3
	local y = 52
	f:DrawStringUTF8(L("Клавиши модов", "Mod hotkeys"), x0, y, HEAD_COLOR, 0, false)
	y = y + lh + 3
	for _, ln in ipairs(cache) do
		local kw = M.drawKeys(f, ln[1], x0, y) + 4
		if kw + f:GetStringWidthUTF8(ln[2]) <= boxW then
			f:DrawStringUTF8(ln[2], x0 + kw, y + 1, TEXT_COLOR, 0, false)
			y = y + 16
		else   -- не влезло рядом — подпись под клавишей
			f:DrawStringUTF8(ln[2], x0 + 2, y + 14, TEXT_COLOR, 0, false)
			y = y + 14 + lh + 2
		end
	end
end
mod:AddCallback(ModCallbacks.MC_POST_PAUSE_SCREEN_RENDER, function() pcall(M.renderPauseMemo) end)

return M
