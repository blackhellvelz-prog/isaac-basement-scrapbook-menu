-- localfixes: карточка персонажа на экране выбора (18.10, просьбы пользователя: «Так же переделай экран выбора
-- персонажа / Сделав его удобнее и впиши туда интерфейсы других модов»; «…более удобные для пользователя и с
-- картинками!»).
-- Внизу экрана выбора — строка вместо подписи PST: «<имя> · <мод>   [I] подробнее   [V] дерево навыков: ур. N».
-- Пока держишь I (на геймпаде — RT), поверх бумаги персонажа — лист игры (правая бумага бестиария) со всем, что
-- моды знают о персонаже:
--   имя и мод-источник (REPENTOGON XMLData: sourceid → имя мода);
--   начальные вещи и здоровье (энциклопедия: раздел «Начальные данные», уже по-русски);
--   особенности и право первородства (EID: CharacterInfo, birthright — со значками EID через EID:renderString);
--   дерево навыков PST: уровень, опыт, свободные очки и клавиша.
-- Подпись PST внизу («<имя> — ур. N (V / LB — открыть дерево)») прячет ru/ui_pst.lua — её сведения здесь.
local mod = LOCALFIXES.Mod
local M = {}

M.HOLD_KEY = Keyboard.KEY_I
local PAD_HOLD = 12   -- RT
local INK = KColor(54 / 255, 47 / 255, 45 / 255, 1)
local SOFT = KColor(54 / 255, 47 / 255, 45 / 255, 0.7)
local KEYC = KColor(0.55, 0.12, 0.10, 1)
local LIGHT = KColor(1, 0.95, 0.9, 1)   -- строка внизу: светлый текст (у LanaPixel своя чёрная обводка — читается на любом фоне)

local fonts = {}
local function font(path)
	if fonts[path] == nil then
		local f = Font()
		f:Load(path)
		fonts[path] = f:IsLoaded() and f or false
	end
	return fonts[path] or nil
end
local function small() return font("font/cjk/lanapixel.fnt") end
local function title() return font("font/teammeatex/teammeatex16.fnt") or small() end

-- имя мода по sourceid (REPENTOGON: записи модов — XMLData.GetEntryById(XMLNode.MOD, 1..N): id, name);
-- короткие имена модов с персонажами
local MOD_SHORT = { ["3778123093"] = "Fiend Folio", ["3012430463"] = "Epiphany", ["3503885496"] = "Heaven's Call",
	["3440586497"] = "Lost and Forgotten", ["1925867065"] = "IPECAC", ["2627014611"] = "Repentance+",
	["3513706025"] = "Furtherance", ["3134600246"] = "Reshaken", ["3343815332"] = "Last Judgement" }
local modNames
local function modName(src)
	if src == nil or src == "BaseGame" then return "игра" end
	if not modNames then
		modNames = {}
		local ok, n = pcall(XMLData.GetNumEntries, XMLNode.MOD)
		for i = 1, (ok and n or 0) do
			local e = XMLData.GetEntryById(XMLNode.MOD, i)
			if e and e.id then
				-- имена в metadata.xml с метками сортировки и версий: «Damn, Fiend Folio: RELOADED», «[Rep] …»,
				-- «Heaven's Call [Solar Update](RGON)» — чистка
				local nm = tostring(e.name or e.id):gsub("^[!~'%s%p]*%b[]%s*", ""):gsub("^%b()%s*", "")
					:gsub("^[!~'%s]+", ""):gsub("%s*%b()$", ""):gsub("%s*%b[]$", ""):gsub("%s*%b()$", "")
				modNames[tostring(e.id)] = nm
			end
		end
	end
	return MOD_SHORT[tostring(src)] or modNames[tostring(src)] or tostring(src)
end

-- энциклопедия: статья персонажа (обычный — 'a', порченый — 'b')
local function encyChar(pt)
	if type(Encyclopedia) ~= "table" or not Encyclopedia.GetCharacter then return nil end
	for _, v in ipairs({ "a", "b" }) do
		local ok, c = pcall(Encyclopedia.GetCharacter, pt, v)
		if ok and type(c) == "table" and (c.CharacterId == nil or c.CharacterId == pt) then return c end
	end
end

local function lines(sec)
	local out = {}
	for _, ln in ipairs(sec or {}) do
		local s = type(ln) == "table" and ln.str or ln
		out[#out + 1] = type(s) == "string" and s:gsub("^%s+", ""):gsub("%s+$", "") or ""
	end
	return out
end

-- характеристики энциклопедии → короткие подписи карточки (порядок вывода — STATS)
local STAT_SHORT = { ["Урон"] = "урон", ["Скорострельность"] = "слёзы", ["Слёзы"] = "слёзы", ["Скорость"] = "скор.",
	["Дальность"] = "дальн.", ["Скорость снаряда"] = "полёт", ["Скорость слёз"] = "полёт", ["Удача"] = "удача" }
local STATS = { "урон", "слёзы", "скор.", "дальн.", "полёт", "удача" }

-- «Начальные данные»: вещи (строки «- …» после «Предметы:», без «-- [UNLOCK] …») и здоровье (с продолжением строки)
local function startData(c)
	local L = lines(c and c.WikiDesc and c.WikiDesc[1])
	local items, health = {}, nil
	local inItems = false
	for i, s in ipairs(L) do
		if s:find("^Предметы") then
			inItems = true
		elseif inItems and s:find("^%- ") and not s:find("^%-%-") then
			items[#items + 1] = s:sub(3)
		elseif inItems and s ~= "" and not s:find("^%-") then
			inItems = false
		end
		local h = s:match("Здоровье:%s*(.*)$")
		if h and not health then
			health = h
			local j = i + 1
			while L[j] and L[j] ~= "" and not L[j]:find(":") and not L[j]:find("^%-") do
				health = health .. " " .. L[j]
				j = j + 1
			end
			health = health:gsub("%.$", "")
		end
	end
	-- характеристики: «- Урон: 3.50» / «Урон: 4.20.» → { {«Урон», «3.50»}, … } в порядке STATS
	local stats = {}
	for _, s in ipairs(L) do
		local k, v = s:match("^%-?%s*([^:%-][^:]-):%s*([%-%d][%d%.]*)")
		if k and STAT_SHORT[k] and not stats[STAT_SHORT[k]] then   -- 3.50 → 3.5, 1.00 → 1
			stats[STAT_SHORT[k]] = v:gsub("%.$", ""):gsub("(%.%d-)0+$", "%1"):gsub("%.$", "")
		end
	end
	return items, health, stats
end

local cache = {}
local function info(pt)
	if cache[pt] then return cache[pt] end
	local d = {}
	local cfg = EntityConfig and EntityConfig.GetPlayer(pt)
	local xml = XMLData and XMLData.GetEntryById(XMLNode.PLAYER, pt)
	d.mod = modName(xml and xml.sourceid)
	local c = encyChar(pt)
	-- картинка персонажа: описание спрайта энциклопедии (anm2, анимация, кадр) — тот же рисунок, что на бумаге
	local sd = c and c.Spr
	if type(sd) == "table" and sd.Anm2Root then
		local sp = Sprite()
		sp:Load(sd.Anm2Root, true)
		if sp:IsLoaded() then
			sp:SetFrame(sd.AnmName or sp:GetDefaultAnimation(), sd.AnmFrame or 0)
			d.spr = sp
		end
	end
	local eidName
	if EID and EID.getDescriptionEntry then
		local ci = EID:getDescriptionEntry("CharacterInfo")
		local e = ci and ci[pt]
		d.traits = e and e[2] ~= "" and e[2] or nil
		local br = EID:getDescriptionEntry("birthright")
		local b = br and br[pt + 1]
		d.birthright = b and b[3] ~= "" and b[3] or nil
		eidName = (b and b[1] ~= "" and b[1]) or (e and e[1] ~= "" and e[1]) or nil
	end
	-- имя — как в игре: таблица строк по ключу из XML (#ISAAC_NAME → «Исаак»); у модов ключа нет
	-- («StringTable::InvalidKey») — имя из EID (то же, что в описаниях: «Изверг»), иначе перевод PST, иначе XML
	local ok, loc = pcall(Isaac.GetLocalizedString, "Players", xml and xml.untranslatedname or "", Options.Language)
	local good = ok and type(loc) == "string" and loc ~= "" and not loc:find("^#") and not loc:find("StringTable")
	d.name = (pt <= 40 and good and loc) or eidName or (good and loc)
		or (cfg and LOCALFIXES.RuCharName and LOCALFIXES.RuCharName(cfg:GetName())) or (c and c.Name)
		or (cfg and cfg:GetName()) or "?"
	if pt >= 21 and pt <= 40 and not d.name:find("^П") then   -- порченые игры: имя в XML то же, что у обычного
		local female = ({ [22] = true, [26] = true, [32] = true, [36] = true })[pt]
		d.name = (pt == 37 and "Порченые " or female and "Порченая " or "Порченый ") .. d.name
	end
	d.items, d.health, d.stats = startData(c)
	cache[pt] = d
	return d
end

-- дерево навыков PST для выбранного персонажа
local function pst()
	if not (PST and PST.modData and PST.selectedMenuChar and PST.selectedMenuChar ~= -1) then return nil end
	local n = PST.charNames and PST.charNames[1 + PST.selectedMenuChar]
	if n and PST.modData.charLoadedProfile and PST.modData.charLoadedProfile[n] then
		n = PST.modData.charLoadedProfile[n]
	end
	local d = n and PST.modData.charData and PST.modData.charData[n]
	if not d then return nil end
	return { level = d.level or 1, sp = d.skillPoints or 0, xp = math.floor(d.xp or 0), need = d.xpRequired,
		off = PST.modData.treeDisabled }
end

local function onPad()
	for i = 1, 4 do
		if Input.IsButtonPressed(PAD_HOLD, i) then return true end
	end
end

local function held()
	return Input.IsButtonPressed(M.HOLD_KEY, 0) or onPad()
end

-- строка из частей: {текст, цвет} или {key = {клавиши}} — картинка клавиши (hotkeys.lua: своя клавиша в стиле
-- значков игры, кнопки геймпада — значки игры); без картинок — «[I]» другим цветом
local HALO = KColor(0.93, 0.9, 0.87, 0.9)
local function keyText(p) return "[" .. table.concat(p.key, "/"):gsub("pad:", "") .. "]" end
local function drawParts(f, parts, x, y, halo)
	for _, p in ipairs(parts) do
		if p.key and LOCALFIXES.DrawKeys then
			x = x + LOCALFIXES.DrawKeys(f, p.key, x, y - 1) + 1
		else
			local s, c = p[1] or keyText(p), p[2] or KEYC
			if halo then   -- светлая кайма: строка читается и на тёмном фоне порченых
				for _, o in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
					f:DrawStringUTF8(s, x + o[1], y + o[2], HALO, 0, false)
				end
			end
			f:DrawStringUTF8(s, x, y, c, 0, false)
			x = x + f:GetStringWidthUTF8(s)
		end
	end
end
local function partsWidth(f, parts)
	local w = 0
	for _, p in ipairs(parts) do
		if p.key and LOCALFIXES.DrawKeys then
			w = w + LOCALFIXES.DrawKeys(f, p.key, 0, 0, true) + 1
		else
			w = w + f:GetStringWidthUTF8(p[1] or keyText(p))
		end
	end
	return w
end

local SHEET   -- правая бумага бестиария: слой Paper2 (2), кадр 230x230, верх-лево = позиция + (248, 40)
local function sheet()
	if SHEET == nil then
		SHEET = Sprite()
		SHEET:Load("gfx/ui/main menu/bestiarymenu.anm2", true)
		SHEET:SetFrame("Idle", 0)
		if not SHEET:IsLoaded() then SHEET = false end
	end
	return SHEET or nil
end

local function renderPanel(base, d, p)
	local T = base + Vector(84, 18)   -- верх-лево листа поверх бумаги персонажа (мир меню)
	local s = sheet()
	if s then s:RenderLayer(2, T - Vector(248, 40)) end
	local x, y, W = T.X + 20, T.Y + 18, 188
	local tf, sf = title(), small()
	if not sf then return end
	if d.spr and d.spr.Render then   -- картинка персонажа из энциклопедии — в правом верхнем углу листа
		pcall(d.spr.Render, d.spr, Vector(T.X + 178, T.Y + 40))
	end
	-- имя: до картинки персонажа (~150); длинное — шрифтом мельче
	for _, f in ipairs({ tf, font("font/teammeatex/teammeatex12.fnt"), sf }) do
		if f and (f:GetStringWidthUTF8(d.name) <= 150 or f == sf) then
			f:DrawStringUTF8(d.name, x, y, INK, 0, false)
			y = y + f:GetLineHeight() - (f == sf and 0 or 2)
			break
		end
	end
	y = y + 2   -- мод — в строке внизу экрана («<имя> · <мод>»)
	local lh = sf:GetLineHeight()
	local function line(label, text, maxLines)
		if not text or text == "" then return end
		local s1 = label .. text
		local words, cur = {}, ""
		for w in s1:gmatch("%S+") do
			local t = cur == "" and w or (cur .. " " .. w)
			if sf:GetStringWidthUTF8(t) > W and cur ~= "" then words[#words + 1] = cur; cur = w else cur = t end
		end
		if cur ~= "" then words[#words + 1] = cur end
		for i = 1, math.min(#words, maxLines or 2) do
			sf:DrawStringUTF8(words[i], x, y, INK, 0, false)
			y = y + lh
		end
	end
	if d.items and #d.items > 0 then line("Вещи: ", table.concat(d.items, ", ")) end
	line("Здоровье: ", d.health)
	if d.stats then   -- точные характеристики (полоски на бумаге персонажа под листом не видны)
		local parts = {}
		for _, k in ipairs(STATS) do
			if d.stats[k] then parts[#parts + 1] = k .. "\u{a0}" .. d.stats[k] end   -- название не отрывается от числа
		end
		if #parts > 0 then line("", table.concat(parts, "\u{a0}· "), 2) end   -- «·» не переносится в начало строки
	end
	y = y + 3
	-- EID: особенности и право первородства — со значками; не ниже строки дерева навыков (bottom). Места мало —
	-- строки делятся: праву первородства не меньше 2, особенностям остальное; обрезанное — с многоточием.
	local bottom = T.Y + 196 - lh - 3
	local function eidLines(text)
		local all = {}
		if text and EID and EID.renderString and EID.fitTextToWidth then
			for part in (EID:replaceShortMarkupStrings(text) .. "#"):gmatch("(.-)#") do   -- «#» — новая строка EID
				if part ~= "" then
					for _, ln in ipairs(EID:fitTextToWidth(part, W - 10, false)) do all[#all + 1] = ln end
				end
			end
		end
		return all
	end
	local tr, br = eidLines(d.traits), eidLines(d.birthright)
	local labels = (#tr > 0 and 1 or 0) + (#br > 0 and 1 or 0)
	local avail = math.floor((bottom - y - labels * lh) / 10)
	local brN = math.min(#br, math.max(2, avail - math.min(#tr, 2)), avail)
	local trN = math.min(#tr, 3, avail - brN)
	if #tr > 0 and trN < 1 then trN, brN = 1, math.min(#br, avail - 1) end
	local function block(label, all, n)
		if #all == 0 or n < 1 then return end
		if #all > n then   -- не влезло — последняя строка с многоточием
			all = { table.unpack(all, 1, n) }
			all[n] = all[n]:gsub("[%s%.,;:]+$", "") .. "..."
		end
		sf:DrawStringUTF8(label, x, y, SOFT, 0, false)
		y = y + lh
		for _, ln in ipairs(all) do
			EID:renderString(ln, Vector(x + 4, y), Vector(1, 1), INK)
			y = y + 10
		end
	end
	block("Особенности:", tr, trN)
	block("Право первородства:", br, brN)
	if p then
		local t = "Дерево навыков: ур. " .. p.level .. (p.need and (" (" .. p.xp .. "/" .. p.need .. ")") or "")
			.. (p.sp > 0 and (", очков: " .. p.sp) or "")
		drawParts(sf, { { t .. "  ", INK }, { key = { "V" } } }, x, bottom + 3)
	end
end

M.info, M.pst, M.modName, M.small = info, pst, modName, small   -- книга выбора (charsel_book.lua) берёт те же сведения
function M.render()
	if LOCALFIXES.CharBook and LOCALFIXES.CharBook.active then return end   -- книга сама показывает всё это
	if LOCALFIXES.CharSelect and LOCALFIXES.CharSelect.active then return end   -- новый экран выбора — тоже
	if MenuManager.GetActiveMenu() ~= MainMenuType.CHARACTER then return end
	if PST and PST.treeScreen and PST.treeScreen.open then return end
	local pt = CharacterMenu.GetSelectedCharacterPlayerType()
	if type(pt) ~= "number" or pt < 0 then return end
	local base = Isaac.WorldToMenuPosition(MainMenuType.CHARACTER, Vector(0, 0))
	local d, p = info(pt), pst()
	local sf = small()
	if not sf then return end
	if held() then
		renderPanel(base, d, p)
	end
	-- строка внизу: имя · мод   [I/RT] подробнее   [V/LB] дерево навыков: ур. N (клавиши — картинками)
	local parts = { { d.name .. " · " .. d.mod .. "    ", LIGHT }, { key = { "I", "pad:RT" } }, { " подробнее", LIGHT } }
	if p then
		parts[#parts + 1] = { "    ", LIGHT }
		parts[#parts + 1] = { key = { "V", "pad:LB" } }
		parts[#parts + 1] = { " дерево навыков: ур. " .. p.level .. (p.sp > 0 and (" (+" .. p.sp .. ")") or "")
			.. (p.off and " — выкл." or ""), LIGHT }
	end
	local c = base + Vector(200.5, 234.5)
	drawParts(sf, parts, c.X - partsWidth(sf, parts) / 2, c.Y)
end

mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER, function()
	local ok, err = pcall(M.render)
	if not ok and not M.err then
		M.err = true
		Isaac.DebugString("[localfixes] карточка персонажа: " .. tostring(err))
	end
end)

return M
