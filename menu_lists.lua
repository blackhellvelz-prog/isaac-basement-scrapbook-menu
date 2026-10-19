-- localfixes: остальные экраны меню в стиле образца (план — docs/MENU_PLAN.md; 18.10: «В общем все меню должно быть
-- выполнено в этом стиле который я тебе скинул»; «Продолжай разработку до финального этапа»; «И смотри чтобы все кнопки в
-- новом меню соответствовали тому куда они ведут»). Управление и переходы — игровые: экран читает выбранное у игры и
-- рисуется поверх своего меню (MenuScreens.Register), действия (Enter, TAB, Esc) выполняет сама игра — подписи
-- кнопок проверены нажатием каждой.
-- свой мод — при загрузке (19.10: в Мастерской части — отдельные моды, LOCALFIXES.Mod потом перезаписывает другой)
local LFMOD = LOCALFIXES.Mod
local HF = LOCALFIXES.HandFont
local CS = LOCALFIXES.CharSelect
local SC = LOCALFIXES.MenuScreens
if not (CS and CS.art and HF and SC and SC.Register) then return end
local art, text, ART = CS.art, CS.text, CS.ART
local MF = LOCALFIXES.MenuFX
local L = {}
LOCALFIXES.MenuLists = L

local INK = Color(55 / 255, 43 / 255, 45 / 255, 1)
local BLACK = Color(22 / 255, 17 / 255, 19 / 255, 1)
local SOFT = Color(110 / 255, 98 / 255, 100 / 255, 1)
local DISABLED = Color(0.62, 0.59, 0.59, 0.85)
local BLOODC = Color(112 / 255, 8 / 255, 11 / 255, 1)
local T = 0
local function sway(seed, amp) return math.sin(T * 0.021 + seed * 1.7) * (amp or 0.5) end
local function bg(o, id)
	art(ART.bg_game and "bg_game" or "bg_wall", o.X + 240, o.Y + 135, 494, 284, nil, 0, nil, nil, true)
	if MF then MF.run(id .. "_back", o, { dust = 4, moth = 0.0008, fall = 0.0008 }) end
end
local function banner(o, s)
	art("cs.title_banner", o.X + 240, o.Y + 20, 150, nil, nil, sway(1, 0.3))
	text(s, o.X + 236, o.Y + 24, HF.Fit(s, 120, { "gL", "gM" }), INK, "c")
end
local function list(s)                      -- «4,78,340» → { 4, 78, 340 }
	local t = {}
	for n in tostring(s or ""):gmatch("%-?%d+") do t[#t + 1] = tonumber(n) end
	return t
end

-- ------------------------------------------------------------------ испытания (MainMenuType.CHALLENGE)
-- Названия — официальные русские игры (лист испытаний из repentance_ru.a, «Список дел»); данные — challenges.xml игры
-- (XMLData): персонаж, конечный этап, стартовые вещи, проклятия, запрещённые комнаты, нужные достижения.
local CH_RU = {
	"Кромешная тьма", "Сноб", "Травма головы", "Тьма наступает", "Танк", "Солнечная система", "Король-самоубийца",
	"Язык проглотил", "Подрывник", "Проклят!", "Стеклянная пушка", "Когда жизнь даёт тебе лимоны", "Бобы!",
	"Дело в картах", "Медленный бросок", "Комп. смекалка", "Вака-вака", "Хозяин", "Семьянин", "Чистейший", "XXXXXXXXL",
	"Скорость!", "Синий бомбер", "Заплати и играй", "Имей сердце", "Легенда об Исааке!", "Мозги!", "День гордости!",
	"Струя Онана", "Защитник", "Задом наперёд", "День дурака", "Покемоны", "Ультра сложно", "Понг", "Дерьмодемон",
	"Кровавая Мэри", "Крещение огнём", "Пробуждение Исаака", "Двоится в глазах", "Извращение вкуса", "Горячая картошка",
	"Заколдованный!", "Красное искупление", "Удали это",
}
L.CH_RU = CH_RU
local CURSES = { [1] = "тьма", [2] = "лабиринт", [4] = "потерянный", [8] = "неизвестность", [16] = "проклятый",
	[32] = "блуждание", [64] = "слепота", [128] = "великан" }
local ROOMS = { [2] = "магазинов", [4] = "сокровищниц", [7] = "секретных", [9] = "аркад", [10] = "проклятых комнат",
	[12] = "библиотек", [13] = "жертвенных", [14] = "сделок с дьяволом", [15] = "ангелов" }
local function goalOf(e)
	if tostring(e.megasatan) == "true" then return "победить Мега Сатану" end
	local alt = tostring(e.altpath) == "true"
	local s = tonumber(e.endstage) or 0
	local G = { [1] = "пройти Подвал I", [2] = "пройти Подвал II", [3] = "пройти Пещеры I", [4] = "пройти Пещеры II",
		[5] = "пройти Глубины I", [6] = "победить Маму", [7] = "пройти Утробу I", [8] = "победить Сердце мамы",
		[9] = "победить Хаша", [10] = alt and "победить Исаака" or "победить Сатану",
		[11] = alt and "победить ???" or "победить Агнца", [12] = "победить Делириума", [13] = "победить Зверя" }
	return G[s] or ("дойти до этапа " .. s)
end
local chCache = {}
local function challenge(id)
	local c = chCache[id]
	if c == nil then
		local ok, e = pcall(XMLData.GetEntryById, XMLNode.CHALLENGE, id)
		c = ok and e or false
		chCache[id] = c
	end
	return c or nil
end
local function achList(s)                  -- «407,489» или «FF_NO_OFFENSE» → номера достижений
	local t = {}
	for part in tostring(s or ""):gmatch("[^,]+") do
		local nm = part:match("^%s*(.-)%s*$")
		local n = tonumber(nm)
		if not n and nm ~= "" and Isaac.GetAchievementIdByName then
			local ok, v = pcall(Isaac.GetAchievementIdByName, nm)
			n = ok and v and v > 0 and v or nil
		end
		if n then t[#t + 1] = n end
	end
	return t
end
local function chLocked(e)
	local pgd = Isaac.GetPersistentGameData()
	for _, a in ipairs(achList(e.achievements)) do
		local ok, u = pcall(pgd.Unlocked, pgd, a)
		if ok and not u then return true end
	end
	return false
end
local function chDone(id)
	local pgd = Isaac.GetPersistentGameData()
	local ok, d = pcall(pgd.IsChallengeCompleted, pgd, id)
	return ok and d
end
local modChallenges
local function hasModChallenges()
	if modChallenges == nil then
		modChallenges = challenge(46) ~= nil
	end
	return modChallenges
end
local function strike(cx, y, w, id, color)    -- вычеркнуто маркером: неровная линия, у каждого своя
	local r = ((id * 37) % 7 - 3) * 0.5
	art("ma.highlight", cx, y, w, 2.4, color or Color(0.22, 0.16, 0.17, 0.9), r)
end
local CDSPR, CARDANIMS = {}, nil
local function cardNorm(nm)                  -- «#THE_STARS_NAME», «17_TheStars» → «stars»; «2» → «two»
	nm = tostring(nm or ""):lower():gsub("^#", ""):gsub("_name$", ""):gsub("^%d+_", ""):gsub("[_%s]", "")
	return (nm:gsub("2", "two"):gsub("^the", ""))
end
local function cardAnim(id, cfg)             -- лицевая сторона в gfx/ui/ui_cardfronts.anm2 (у карт Rep+ HudAnim пустой):
	if not CARDANIMS then                      -- Таро 1–22 — по порядку («00_TheFool» — карта 1), остальные — по имени
		CARDANIMS = {}
		local s = Sprite()
		s:Load("gfx/ui/ui_cardfronts.anm2", true)
		local ok, all = pcall(s.GetAllAnimationData, s)
		for _, a in ipairs(ok and all or {}) do
			local n = a:GetName()
			CARDANIMS[#CARDANIMS + 1] = { n, cardNorm(n), tonumber(n:match("^(%d+)_")) }
		end
	end
	if id >= 1 and id <= 22 then
		for _, a in ipairs(CARDANIMS) do if a[3] == id - 1 then return a[1] end end
	end
	local want = cardNorm(cfg and cfg.Name)
	if want == "" then return nil end
	for _, a in ipairs(CARDANIMS) do
		if a[2] ~= "" and a[2] ~= "outline" and (a[2] == want or want:find(a[2], 1, true) or a[2]:find(want, 1, true)) then
			return a[1]
		end
	end
	return nil
end
local function drawCard(id, x, y, size)       -- стартовая карта: лицевая сторона, как в кармане у игры
	local c = CDSPR[id]
	if c == nil then
		c = false
		local ok, cfg = pcall(function() return Isaac.GetItemConfig():GetCard(id) end)
		cfg = ok and cfg or nil
		local mod = cfg and cfg.ModdedCardFront
		if mod then                              -- карта мода — свой спрайт лицевой стороны
			c = { mod, mod:GetAnimation() ~= "" and mod:GetAnimation() or mod:GetDefaultAnimation() }
		else
			local anim = cardAnim(id, cfg)
			if anim then
				local s = Sprite()
				s:Load("gfx/ui/ui_cardfronts.anm2", true)
				if s:IsLoaded() then c = { s, anim } end
			end
		end
		CDSPR[id] = c
	end
	if not c then return false end
	local spr, anim = c[1], c[2]
	spr:SetFrame(anim, 0)
	spr.Scale = Vector(size / 24, size / 24)
	spr:Render(Vector(x, y + 1))
	spr.Scale = Vector.One
	return true
end
local function drawChallengeCard(o, id, e)
	local cx, cy = o.X + 352, o.Y + 150
	art(ART["hd.note_sq"] and "hd.note_sq" or "cs.notes", cx, cy, 196, 214, nil, sway(7, 0.25))
	local name = CH_RU[id] or tostring(e.name)
	local locked, done = chLocked(e), chDone(id)
	local up = HF.upper(name)                  -- ниже булавки (она закрывает верх листа до ~17% высоты)
	text(up, cx, cy - 50, HF.Fit(up, 170, { "gL", "gM", "gS" }), BLACK, "c")
	text("ИСПЫТАНИЕ № " .. id, cx, cy - 39, "gT", SOFT, "c")
	-- персонаж
	local pt = tonumber(e.playertype) or 0
	local key = CS.CharKey and CS.CharKey(pt)
	if key and ART[key] then
		local a = ART[key]
		art(key, cx - 62, cy - 14, nil, 46, locked and Color(0.3, 0.28, 0.3, 1) or nil)
	end
	local nm = CS.NameOf and CS.NameOf(pt) or "?"
	text("ПЕРСОНАЖ:", cx - 30, cy - 30, "gT", SOFT)
	text(HF.upper(nm), cx - 30, cy - 21, HF.Fit(HF.upper(nm), 110, { "gM", "gS" }), INK)
	text("ЦЕЛЬ:", cx - 30, cy - 8, "gT", SOFT)
	local g = HF.upper(goalOf(e))
	text(g, cx - 30, cy + 1, HF.Fit(g, 112, { "gS", "gT" }), INK)
	-- стартовые вещи
	local items = {}
	for _, it in ipairs(list(e.startingitems)) do if it > 0 then items[#items + 1] = it end end
	local card = tonumber(e.startingcard) or 0
	local y = cy + 22
	text("С СОБОЙ:", cx - 82, y, "gT", SOFT)
	if #items == 0 and card <= 0 then
		text("НИЧЕГО", cx - 40, y, "gT", INK)
	else
		local n = math.min(card > 0 and 6 or 7, #items)
		if CS.drawItem then for i = 1, n do CS.drawItem(items[i], cx - 44 + (i - 1) * 17, y - 1, 15) end end
		if card > 0 then drawCard(card, cx - 44 + n * 17, y - 1, 15) end
	end
	-- правила
	local rules = {}
	local gc = tonumber(e.getcurse) or 0
	if gc > 0 then
		local cs = {}
		for bitv, nmc in pairs(CURSES) do if gc & bitv ~= 0 then cs[#cs + 1] = nmc end end
		table.sort(cs)
		rules[#rules + 1] = "ПРОКЛЯТИЯ: " .. HF.upper(table.concat(cs, ", "))
	end
	local rf = {}
	for _, r in ipairs(list(e.roomfilter)) do if ROOMS[r] then rf[#rf + 1] = ROOMS[r] end end
	if #rf > 0 then rules[#rules + 1] = "БЕЗ " .. HF.upper(table.concat(rf, ", ")) end
	if tonumber(e.difficulty) == 1 then rules[#rules + 1] = "СЛОЖНЫЙ РЕЖИМ" end
	for i, r in ipairs(rules) do
		if i > 3 then break end
		text(r, cx - 82, cy + 38 + (i - 1) * 9, HF.Fit(r, 168, { "gT" }), INK)
	end
	-- отметка
	if locked then
		art("cs.padlock", cx + 60, cy + 70, 12)
		text("ЗАКРЫТО", cx + 38, cy + 72, "gM", BLOODC, "r")
	elseif done then
		local r = sway(9, 1.5) - 8
		text("ВЫПОЛНЕНО!", cx + 44, cy + 70, "gM", BLOODC, "c", nil, r)
	end
end
-- длинный лист для заметок (18.10: «Испытания оформи как длинную бумагу для заметок»): tools/long_paper.py — части
-- lp.top, lp.mid, lp.bot и линии линовки в них (menu_paper.lua); 19.10 — лист любой длины: середина повторяется
-- столько раз, сколько нужно строк (испытаний модов у каждого игрока своё число). Строки пишутся по линиям, номер —
-- перед красными полями, лист плавно прокручивается так, чтобы выбранное было у середины экрана.
local okP, PAPER = pcall(include, "menu_paper")
if not okP or type(PAPER) ~= "table" or not PAPER.mid then PAPER = nil end
local scroll = {}
local layouts = {}
local function paperLayout(n)              -- части { имя, верх, высота } и линии (пиксели текстуры) для n строк + шапки
	local L0 = layouts[n]
	if L0 then return L0 end
	local nt, nm, nb = #PAPER.top.lines, #PAPER.mid.lines, #PAPER.bot.lines
	local k = math.max(0, math.ceil((n + 2 - nt - nb) / nm))
	local parts, lines, y = {}, {}, 0
	local function add(name, part)
		parts[#parts + 1] = { name, y, part.h }
		for _, l in ipairs(part.lines) do lines[#lines + 1] = y + l end
		y = y + part.h
	end
	add("lp.top", PAPER.top)
	for _ = 1, k do add("lp.mid", PAPER.mid) end
	add("lp.bot", PAPER.bot)
	L0 = { parts = parts, lines = lines, h = y }
	layouts[n] = L0
	return L0
end
local function longList(o, id, x, w, n, sel, row)    -- row(i, y, xNum, xText, wText, on) рисует строку i
	if not (PAPER and ART["lp.top"] and ART["lp.mid"] and ART["lp.bot"]) then return end
	local lay = paperLayout(n)
	local k = w / PAPER.w
	local H = lay.h * k
	local lines = lay.lines
	local selY = lines[math.min(#lines, sel + 2)] * k
	local target = math.max(0, math.min(H - 226, selY - 112))
	local cur = scroll[id] or target
	cur = cur + (target - cur) * 0.2 * (LOCALFIXES.MenuDT or 1)
	scroll[id] = cur
	local top = o.Y + 26 - cur
	local clipT, clipB = o.Y - 20, o.Y + 254                -- лист кончается над полосой подсказок
	for _, pt in ipairs(lay.parts) do
		local y0, hh = top + pt[2] * k, pt[3] * k
		if y0 + hh > clipT and y0 < clipB then
			if CS.artClipY then
				CS.artClipY(pt[1], o.X + x, y0 + hh / 2, w, hh, nil, clipT, clipB)
			else
				art(pt[1], o.X + x, y0 + hh / 2, w, hh)
			end
		end
	end
	local xMargin = o.X + x - w / 2 + PAPER.w * 0.205 * k
	for i = 1, n do
		local ly = top + lines[math.min(#lines, i + 2)] * k
		if ly > o.Y + 18 and ly < clipB then row(i, ly - 2, xMargin - 3, xMargin + 4, w - PAPER.w * 0.205 * k - 12, i == sel) end
	end
	return top, k, lines
end
L.longList = longList

local function drawChallenges(o)
	T = T + (LOCALFIXES.MenuDT or 1)
	bg(o, "ch")
	local sel = ChallengeMenu.GetSelectedChallengeID()
	if MF then MF.sel("challenges", sel) end
	local wob = MF and MF.wob("challenges", sel) or 0
	local N = #CH_RU
	local top, k, lines = longList(o, "ch", 128, 196, N, sel, function(id, y, xn, xt, wt, on)
		local e = challenge(id)
		if not e then return end
		local locked = chLocked(e)
		local nm = HF.upper(CH_RU[id] or tostring(e.name))
		local dx = on and (math.sin(T * 0.12) * 1.2 + wob * 0.3) or 0
		if on then art("ma.highlight", xt + wt / 2 - 4, y - 4, wt + 14, 14, Color(1, 1, 1, 0.75)) end
		text(id .. ".", xn + dx, y - 5, "gS", locked and DISABLED or INK, "r")
		local size = HF.Fit(nm, wt, { "gM", "gS", "gT" })
		text(nm, xt + dx, y - 5, size, locked and DISABLED or (on and BLACK or INK))
		local tw = HF.Width(nm, size)
		if locked then
			art("cs.padlock", xt + tw + 6 + dx, y - 6, 7)
		elseif chDone(id) then
			strike(xt + tw / 2 + dx, y - 9, tw + 4, id)
		end
		if on then art("ma.cursor", xn - HF.Width(id .. ".", "gS") - 7 + dx, y - 6, 8) end
	end)
	if top then        -- заголовок на шапке листа (рядом с пометкой «список дел»)
		text("СПИСОК ДЕЛ", o.X + 150, top + lines[2] * k - 7, "gL", INK, "c")      -- на первой линии, ниже булавки
	end
	-- шапка экрана — над карточкой (над листом она закрывала названия)
	art("cs.title_banner", o.X + 345, o.Y + 22, 140, nil, nil, sway(1, 0.3))
	text("ИСПЫТАНИЯ", o.X + 341, o.Y + 26, "gL", INK, "c")
	-- карточка выбранного
	local e = challenge(sel)
	if e then drawChallengeCard(o, sel, e) end
	-- TAB — испытания модов (только если они есть)
	if hasModChallenges() then
		art(ART["hd.note_wide"] and "hd.note_wide" or "ma.note_pin", o.X + 446, o.Y + 32, 64, 54, nil, sway(4, 0.5))
		text("TAB —", o.X + 446, o.Y + 38, "gS", INK, "c")
		text("МОДЫ", o.X + 446, o.Y + 47, "gS", INK, "c")
	end
	if MF then MF.run("ch", o) end
	local h = { { "updown", "Выбор" }, { "Enter", "Начать" }, { "Esc", "Назад" } }
	if hasModChallenges() then table.insert(h, 3, { "Tab", "Испытания модов" }) end
	CS.hints(o, h)
end
SC.Register(MainMenuType.CHALLENGE, drawChallenges, true)    -- игра прокручивает список камерой — экран стоит на месте

-- ------------------------------------------------------------------ ввод своих курсоров
local rep = {}
local function press(action)                     -- край нажатия + автоповтор при удержании (по кадрам логики)
	local p = false
	for i = 0, 3 do
		if Input.IsActionPressed(action, i) then p = true break end
	end
	local r = rep[action]
	if not r then r = { down = false, t = 0 }; rep[action] = r end
	local fire = false
	local dt = LOCALFIXES.MenuDT or 1
	if p then
		if not r.down then
			fire, r.t = true, 0
		elseif dt > 0 then
			r.t = r.t + 1
			if r.t >= 20 and (r.t - 20) % 4 == 0 then fire = true end
		end
	end
	r.down = p
	return fire
end
-- шаг по сетке из n клеток по cols в ряд (19.10: «управление стрелочками полноценное»): ←/→ — соседняя клетка (с
-- переходом на соседний ряд и по кругу), ↑/↓ — та же колонка рядом выше/ниже; вниз из предпоследнего ряда, где под
-- клеткой пусто, — на последнюю клетку; с последнего ряда вниз — наверх в ту же колонку, с первого вверх — в ту же
-- колонку последнего ряда (если там пусто — рядом выше)
local function gridMove(sel, n, cols, dx, dy)
	if n <= 0 then return 1 end
	if dx ~= 0 then sel = (sel - 1 + dx) % n + 1 end
	if dy ~= 0 then
		local col = (sel - 1) % cols + 1
		local row, lastRow = (sel - 1) // cols, (n - 1) // cols
		local t = sel + dy * cols
		if t > n then
			t = row < lastRow and n or col
		elseif t < 1 then
			t = lastRow * cols + col
			if t > n then t = t - cols end
		end
		sel = math.max(1, math.min(n, t))
	end
	return sel
end
local function gridKeys(sel, n, cols)          -- стрелки → gridMove; вернёт новый номер и было ли движение
	local A = ButtonAction
	local dx = (press(A.ACTION_MENURIGHT) and 1 or 0) - (press(A.ACTION_MENULEFT) and 1 or 0)
	local dy = (press(A.ACTION_MENUDOWN) and 1 or 0) - (press(A.ACTION_MENUUP) and 1 or 0)
	if (dx == 0 and dy == 0) or n <= 0 then return sel, false end
	return gridMove(sel, n, cols, dx, dy), true
end

-- ------------------------------------------------------------------ моды (MainMenuType.MODS)
-- 18.10: «Экран модов оформи как Blueprint / И пусть моды будут как в нашем DSS квадратиками с иконками из Workshop
-- (чтобы они автоматом подгружались) / Соответственно в этом меню все цветное - включено / Черное белое - выключено».
-- Синяя калька (bg_blueprint), белые чертёжные рамки (bl.*). Список — живой, из самой игры (19.10: «Ты же понимаешь
-- что это меню должно быть динамичный от количества скаченных модов?»): все её моды (XMLData, запись MOD — имя как в
-- metadata.xml, папка, номер Workshop, включён ли при запуске), в порядке её меню; сколько модов — столько квадратиков.
-- Картинка мода: картинку Workshop Lua в игре не скачать и файл вне ресурсов не прочитать (Renderer.LoadImage — только
-- ресурсы; путь к картинке в папке другого мода тоже не грузится — проверено 19.10), поэтому — готовый лист
-- (tools/mod_thumbs.py: моды этого ПК и популярные моды Мастерской, страницы modthumbs_hd_<k> по 256 картинок;
-- выключенный мод — серым окраской), картинка — по номеру мода в Мастерской; у остальных — чертёжная монограмма
-- (буквы названия). На экране — только установленные у игрока моды (19.10: «Моды которых нет на компьютере вообще не
-- должны отображаться даже картинкой»).
local okT, THUMBS = pcall(include, "modthumbs_index")
if not okT or type(THUMBS) ~= "table" then THUMBS = { mods = {} } end
local WHITE = Color(0.95, 0.97, 1, 1)
local WSOFT = Color(0.78, 0.86, 1, 0.9)
local hdSpr = {}
local function hdThumb(i, gray, x, y, size, alpha)
	local per = THUMBS.hdper or 256
	local page = i // per
	local s = hdSpr[page]
	if s == nil then
		s = Sprite()
		s:Load("gfx/ui/localfixes/modthumbs_hd_" .. page .. ".anm2", true)
		if not s:IsLoaded() then s = false end
		hdSpr[page] = s
	end
	if not s then return false end
	s:SetFrame("Thumbs", i % per)
	s.Scale = Vector(size / 128, size / 128)
	local c = Color(1, 1, 1, alpha or 1)
	if gray then c:SetColorize(1, 1, 1, 1) end        -- выключенный мод — чёрно-белый
	s.Color = c
	s:Render(Vector(x, y))
	s.Scale = Vector.One
	return true
end
do   -- выбор на экране модов: свои переменные блока не занимают места у остального файла (у Lua — 200 на функцию)
	-- Выбор и Enter (19.10: «Реализуй на экране модов управление стрелочками полноценное»; «Сейчас там при попытке
	-- вверх/вниз он двигает влево и вправо»): у игры список модов вертикальный (↑/↓ — соседний мод), у нас — сетка. Курсор
	-- свой: ←/→ — соседний мод, ↑/↓ — ряд выше/ниже, PgUp/PgDn (LT/RT) — страница; стрелки у игры закрыты маской, выбор
	-- передаётся игре, чтобы Enter (вкл/выкл делает игра) переключал мод под нашим курсором.
	-- Список игры (REPENTOGON 1.1.3, Patches/ModsMenuStuff.cpp, Menu_Mods::Render): сначала включённые, потом выключенные,
	-- каждые — в порядке менеджера модов (по имени из metadata.xml побайтно, с ведущими пробелами; сверено 18.10); номер
	-- «N.» — место в показанном списке;
	-- поиск (Ctrl) оставляет тех, у кого «N.имя» в нижнем регистре содержит набранное. Enter (Menu_Mods::Update)
	-- переключает мод по указателю _pointerToSelectedMod и сразу пишет или стирает disable.it; ModsMenu.SetSelectedElement
	-- ставит этот указатель НЕВЕРНО (сдвиг на 4 записи мода вместо 4 байт — 18.10 так выключились четыре чужих мода),
	-- отрисовка меню игры исправляет его по номеру в каждом кадре. Поэтому после каждой смены выбора Enter у игры закрыт
	-- маской на 2 кадра — пока указатель не исправлен. Backspace (не в поиске) — у REPENTOGON «отменить все изменения».
	local toggled = {}            -- [папка мода] = true: Enter в этом меню переключил мод
	-- список модов игры: { raw = имя из metadata.xml, name = без крайних пробелов, folder, id, base = включён при запуске
	-- (в меню не меняется — меняет только Enter), hd = кадр картинки этого ПК или nil, islocal }; пересобирается, если
	-- число модов у игры стало другим
	local LIST
	local function bytesLess(a, b)             -- как сравнение строк в C: по байтам без знака, короче — раньше
		for i = 1, math.min(#a, #b) do
			local x, y = a:byte(i), b:byte(i)
			if x ~= y then return x < y end
		end
		return #a < #b
	end
	local function modList()
		local okN, n = pcall(XMLData.GetNumEntries, XMLNode.MOD)
		n = (okN and type(n) == "number") and n or 0
		if LIST and LIST.n == n then return LIST end
		local byId, byFolder = {}, {}
		for _, m in ipairs(THUMBS.mods or {}) do
			if m.id and m.id ~= "" then byId[m.id] = m elseif m.folder and m.folder ~= "" then byFolder[m.folder] = m end
		end
		local t = {}
		for i = 1, n do
			local ok, e = pcall(XMLData.GetEntryById, XMLNode.MOD, i)
			if ok and type(e) == "table" and e.name then
				local folder = tostring(e.realdirectory or e.directory or "")
				local id = tostring(e.id or "")
				local th = (id ~= "" and byId[id]) or byFolder[folder]
				t[#t + 1] = { raw = tostring(e.name), name = tostring(e.name):match("^%s*(.-)%s*$"), folder = folder, id = id,
					base = tostring(e.enabled) == "true", hd = th and th.hd, islocal = not id:match("^%d+$") }
			end
		end
		table.sort(t, function(a, b)
			if a.raw ~= b.raw then return bytesLess(a.raw, b.raw) end
			return bytesLess(a.folder, b.folder)
		end)
		t.n = n
		LIST = t
		return t
	end
	local function modEnabled(i, m)
		local en = m.base
		if toggled[m.folder] then en = not en end
		return en
	end
	-- монограмма мода без картинки: буквы названия (без меток [REP], (RGON), «!!» и служебных слов), как шифр детали на
	-- чертеже; шифр у каждого мода свой (19.10: на виде без картинок повторялись «MI», «BE», «LJ») — при совпадении
	-- берётся следующий вариант: две буквы → три
	local SKIPW = { the = true, of = true, a = true, an = true, ["and"] = true, ["for"] = true, ["in"] = true, mod = true,
		mods = true, isaac = true, binding = true, rep = true, rgon = true, beta = true, v = true }
	local function monoVariants(name)
		local clean = name:gsub("%b[]", " "):gsub("%b()", " ")
		local words = {}
		for w in clean:gmatch("[%w\128-\255][%w\128-\255']*") do
			if not SKIPW[w:lower()] and not w:match("^%d") then words[#words + 1] = w end
		end
		local function ch(w, k)                  -- k-я буква слова (UTF-8)
			local i = 0
			for c in w:gmatch("[\0-\127\194-\244][\128-\191]*") do
				i = i + 1
				if i == k then return c end
			end
			return ""
		end
		local w1, w2, w3 = words[1], words[2], words[3]
		local v
		if not w1 then
			v = { "?" }
		elseif not w2 then
			v = { ch(w1, 1) .. ch(w1, 2), ch(w1, 1) .. ch(w1, 2) .. ch(w1, 3), ch(w1, 1) .. ch(w1, 3) .. ch(w1, 4) }
		else
			v = { ch(w1, 1) .. ch(w2, 1), ch(w1, 1) .. ch(w2, 1) .. (w3 and ch(w3, 1) or ch(w2, 2)),
				ch(w1, 1) .. ch(w1, 2) .. ch(w1, 3), ch(w1, 1) .. ch(w1, 2) .. ch(w2, 1) }
		end
		for i, x in ipairs(v) do v[i] = HF.upper(x) end
		return v
	end
	-- шифры всего списка: по порядку, первый свободный вариант (раз на список)
	local function monoOf(mods, m)
		if not mods.monoDone then
			local used = {}
			for _, x in ipairs(mods) do
				local v = monoVariants(x.name)
				x.mono = v[1]
				for _, c in ipairs(v) do
					if c ~= "" and not used[c] then x.mono = c break end
				end
				used[x.mono] = true
			end
			mods.monoDone = true
		end
		return m.mono or "?"
	end
	-- порядок списка игры: номера модов THUMBS по местам игры (1 — первый в её списке)
	local function gameOrder(mods, query)
		local list, num = {}, 1
		for pass = 1, 2 do
			for i, m in ipairs(mods) do
				if modEnabled(i, m) == (pass == 1) then
					if query == "" or (num .. "." .. (m.raw or m.name or "")):lower():find(query, 1, true) then
						list[#list + 1] = i
						num = num + 1
					end
				end
			end
		end
		return list
	end
	-- зеркало поиска REPENTOGON (Ctrl): тот же разбор клавиш, что в Menu_Mods::Render, в том же кадре — чтобы знать его
	-- отбор (иначе номер игры и мод под нашим курсором разойдутся). Набор: цифры, латиница, пробел; Backspace — стереть;
	-- Ctrl, Enter, Esc — закрыть поиск (отбор остаётся). Задержка клавиш — 20 кадров, при удержании — повтор.
	local SR = { on = false, str = "", last = {} }
	local KEYDELAY = 20
	local searchFont
	local function searchWidth(s)
		if not searchFont then
			searchFont = Font()
			pcall(searchFont.Load, searchFont, "font/teammeatex/teammeatex10.fnt")
		end
		if searchFont:IsLoaded() then return searchFont:GetStringWidth(s) end
		return #s * 6
	end
	local function mirrorSearch(nMods)
		if nMods <= 15 then return false end         -- у REPENTOGON поиск — только если модов больше 15
		local K = Keyboard
		local now = Isaac.GetFrameCount()
		local last = SR.last
		local did = false
		if SR.on then
			for i = 32, 347 do
				if Input.IsButtonPressed(i, 0) then
					if now - (last[i] or 0) >= KEYDELAY then
						if i == K.KEY_LEFT_CONTROL or i == K.KEY_ENTER or i == K.KEY_ESCAPE then
							SR.on = false
							last[i] = now
							break
						elseif i == K.KEY_BACKSPACE then
							if SR.str ~= "" then SR.str = SR.str:sub(1, -2); did = true end
						elseif searchWidth(SR.str) < 225 and ((i >= 48 and i <= 57) or (i >= 65 and i <= 90) or i == 32) then
							SR.str = SR.str .. string.char(i):lower()
							did = true
						end
						if did then last[i] = (last[i] or 0) > 0 and now - math.floor(KEYDELAY * 0.7) or now end
					end
				else
					last[i] = 0
				end
			end
		elseif Input.IsButtonTriggered(K.KEY_LEFT_CONTROL, 0) and now - (last[K.KEY_LEFT_CONTROL] or 0) > KEYDELAY then
			SR.on = true
			last[K.KEY_LEFT_CONTROL] = now
		end
		return did
	end
	local MS = { mod = 1, pend = 0, open = true }   -- наш курсор (номер в THUMBS); кадры, пока Enter игры закрыт
	local MODS_MASK
	local function anyPressed(action)
		for i = 0, 3 do
			if Input.IsActionPressed(action, i) then return true end
		end
		return false
	end
	local confirmWas, planeT = false, 0
	local COLS, ROWS, STEP, SIZE = 9, 4, 42, 30
	-- квадратики проходами: картинки модов (их листы: цветные, потом чёрно-белые) → значки и рамки (атлас) → монограммы
	-- (шрифт); z — масштаб (1 — на экран, масштаб точек — в картинку-кэш, где единица — пиксель). Вперемешку по
	-- квадратикам смена текстуры на каждом шаге стоила ~10 к/с (19.10: 130 против 139 в главном меню)
	local GEAR_ON, GEAR_OFF, MONO_OFF = Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.3), Color(0.6, 0.65, 0.75, 1)
	local function tilePasses(tiles, mods, z)
		local AR, TQ = {}, {}
		local function placeholder(t)              -- нет картинки: монограмма и шестерёнка в углу — шифр детали на чертеже
			AR[#AR + 1] = { n = 7, "bl.gear", (t.cx + t.sz * 0.3) * z, (t.cy + t.sz * 0.3) * z, t.sz * 0.32 * z, nil,
				t.en and GEAR_ON or GEAR_OFF, t.rot or 0 }
			local mo = monoOf(mods, t.m)
			TQ[#TQ + 1] = { mo, t.cx * z, (t.cy + 3) * z, HF.Fit(mo, t.sz - 6, { "gX", "gL", "gM" }), t.en and WHITE or MONO_OFF }
		end
		for pass = 1, 2 do
			for _, t in ipairs(tiles) do
				if t.en == (pass == 1) then
					local ok = t.m.hd and not LOCALFIXES_MODS_NOHD     -- флаг: вид без листа этого ПК (как у игрока из Workshop)
						and hdThumb(t.m.hd, not t.en, t.cx * z, t.cy * z, t.sz * z)
					if not ok then placeholder(t) end
				end
			end
		end
		for _, t in ipairs(tiles) do
			if not t.en then AR[#AR + 1] = { n = 6, "bl.cross", (t.cx + t.sz * 0.32) * z, (t.cy + t.sz * 0.32) * z, 10 * z, nil, WHITE } end
			-- рамка — по квадрату внутри рисунка (18.10: «рамка вокруг модов съехала при выборе»): у рамки выбора стрелки-
			-- размеры сверху, снизу и справа, квадрат смещён от центра картинки на (−16; −4,5) пикселя, сторона 180 из 222;
			-- у простой рамки сторона 178 из 205, смещение (−0,5; +3,5)
			if t.sel then
				local W = (t.sz + 8) * 222 / 180
				local k = W / 222
				AR[#AR + 1] = { n = 7, "bl.selframe", (t.cx + 16 * k) * z, (t.cy + 4.5 * k) * z, W * z, nil, WHITE, t.wob or 0 }
			else
				local W = (t.sz + 6) * 205 / 178
				local k = W / 205
				AR[#AR + 1] = { n = 6, "bl.frame", (t.cx + 0.5 * k) * z, (t.cy - 3.5 * k) * z, W * z, nil, WHITE }
			end
		end
		for _, a in ipairs(AR) do art(table.unpack(a, 1, a.n)) end
		for _, q in ipairs(TQ) do text(q[1], q[2], q[3], q[4], q[5], "c", z) end
	end
	-- неподвижные квадратики (все, кроме выбранного) — в картинку (REPENTOGON Renderer.RenderToImage, как сетка альбома
	-- предметов): перерисовка только при смене выбора, ряда, поиска, переключении мода; в кадре — одна картинка.
	-- 19.10: без картинок модов (как у игрока из Workshop) 36 монограмм шрифтом стоили 16 к/с (122 против 138)
	local tilesImg, tilesW, tilesH, tilesKey, tilesOff, SRCQ_M
	local function drawTiles(tiles, mods, key)
		local canImg = Renderer and Renderer.RenderToImage and Renderer.CreateImage and SourceQuad and DestinationQuad
		if not canImg or tilesOff then return tilePasses(tiles, mods, 1) end
		local sw, sh = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
		local z = Isaac.GetScreenPointScale and Isaac.GetScreenPointScale() or 1
		local W, H = math.floor(sw * z + 0.5), math.floor(sh * z + 0.5)
		if not tilesImg or tilesW ~= W or tilesH ~= H then
			local ok, img = pcall(Renderer.CreateImage, W, H, "localfixes_mods_tiles_" .. W .. "x" .. H)
			if not ok or not img then
				tilesOff = true
				return tilePasses(tiles, mods, 1)
			end
			tilesImg, tilesW, tilesH, tilesKey = img, W, H, nil
		end
		key = key .. ":" .. z
		if key ~= tilesKey then
			local ok, err = pcall(Renderer.RenderToImage, tilesImg, function(ctl)
				ctl:Clear()
				tilePasses(tiles, mods, z)
			end)
			if not ok then
				Isaac.DebugString("[localfixes] моды: квадратики в картинку не рисуются — " .. tostring(err))
				tilesOff = true
				return tilePasses(tiles, mods, 1)
			end
			tilesKey = key
		end
		SRCQ_M = SRCQ_M or SourceQuad.NewFromBounds(Vector(0, 0), Vector(1, 1), true)
		tilesImg:Render(SRCQ_M, DestinationQuad.NewFromBounds(Vector(0, 0), Vector(sw, sh)), KColor(1, 1, 1, 1))
	end
	local function drawMods(o)
		T = T + (LOCALFIXES.MenuDT or 1)
		local A = ButtonAction
		local mods = modList()
		local N = #mods
		local active = MenuManager.GetActiveMenu() == MainMenuType.MODS
		local own = N > 0 and N == mods.n                    -- свой курсор — если список игры прочитан целиком
		if not (ModsMenu.WasListEdited and ModsMenu.WasListEdited()) then toggled = {} end   -- Backspace игры: всё назад
		local newFrame = (LOCALFIXES.MenuDT or 1) > 0
		if active then
			-- Enter, который игра обработала в этом кадре логики: не в поиске, не закрыт маской, список не пуст, не Ctrl
			local wasSearching = SR.on
			local conf = anyPressed(A.ACTION_MENUCONFIRM)
			if newFrame then
				if conf and not confirmWas and MS.open and not wasSearching and own and N > 0
					and not Input.IsButtonTriggered(Keyboard.KEY_LEFT_CONTROL, 0) then
					local G0 = gameOrder(mods, SR.str)
					local cur = G0[ModsMenu.GetSelectedElement() or 0]
					if cur then toggled[mods[cur].folder] = not toggled[mods[cur].folder] end
				end
				confirmWas = conf
			end
			mirrorSearch(N)
		else
			SR.on = false
		end
		local G = gameOrder(mods, SR.str)
		local V = {}                                         -- видимые в сетке: найденные, в нашем порядке
		if SR.str == "" then
			for i = 1, N do V[i] = i end
		else
			local inG = {}
			for _, i in ipairs(G) do inG[i] = true end
			for i = 1, N do if inG[i] then V[#V + 1] = i end end
		end
		local pos
		for p, i in ipairs(V) do if i == MS.mod then pos = p break end end
		if active and own then
			if not MS.on then                                  -- вход в меню: курсор — на выбранный игрой
				MS.on = true
				MS.mod = G[ModsMenu.GetSelectedElement() or 1] or V[1] or 1
				for _, a in ipairs({ A.ACTION_MENULEFT, A.ACTION_MENURIGHT, A.ACTION_MENUUP, A.ACTION_MENUDOWN,
					A.ACTION_MENULT, A.ACTION_MENURT }) do press(a) end
				pos = nil
				for p, i in ipairs(V) do if i == MS.mod then pos = p break end end
			end
			pos = pos or 1
			local moved
			pos, moved = gridKeys(pos, #V, COLS)
			-- «нажата» у клавиш держится весь кадр логики, а рисуем мы 2–3 раза за него — PgUp/PgDn только в первом
			local pgDn = newFrame and Input.IsButtonTriggered(Keyboard.KEY_PAGE_DOWN, 0)
			local pgUp = newFrame and Input.IsButtonTriggered(Keyboard.KEY_PAGE_UP, 0)
			local page = ((press(A.ACTION_MENURT) or pgDn) and 1 or 0) - ((press(A.ACTION_MENULT) or pgUp) and 1 or 0)
			if page ~= 0 and #V > 0 then pos = math.max(1, math.min(#V, pos + page * COLS * ROWS)); moved = true end
			if V[pos] then MS.mod = V[pos] end
			-- выбор игре: номер мода в её списке; после смены — Enter у игры закрыт, пока она не исправит указатель
			local gi
			for k, i in ipairs(G) do if i == MS.mod then gi = k break end end
			if gi and ModsMenu.GetSelectedElement() ~= gi then
				ModsMenu.SetSelectedElement(gi)
				MS.pend = 2
			end
			MODS_MASK = MODS_MASK or (0xFFFFFFFF & ~(1 << A.ACTION_MENUUP) & ~(1 << A.ACTION_MENUDOWN)
				& ~(1 << A.ACTION_MENULEFT) & ~(1 << A.ACTION_MENURIGHT))
			local mask = MODS_MASK
			if MS.pend > 0 or not gi then mask = mask & ~(1 << A.ACTION_MENUCONFIRM) end
			MS.open = MS.pend <= 0 and gi ~= nil
			if MS.pend > 0 then MS.pend = MS.pend - 1 end
			MenuManager.SetInputMask(mask)
		elseif active then
			-- список игры не совпал с нашим (поставили или убрали мод после сборки картинок): выбор — игры, как у неё
			MS.mod = G[ModsMenu.GetSelectedElement() or 1] or 1
			MS.open = true
		end
		pos = nil
		for p, i in ipairs(V) do if i == MS.mod then pos = p break end end
		if MF then MF.sel("mods", MS.mod) end
		if LOCALFIXES_MODS_PEEK then return end              -- отладка: показать список игры под экраном (мост)
		art(ART.bg_blueprint and "bg_blueprint" or "bg_wall", o.X + 240, o.Y + 135, 494, 284, nil, 0, nil, nil, true)
		-- заголовок
		-- надписи — в чистой полосе сетки, между пометками кальки (размерная стрелка слева, линейка справа) и первым рядом
		-- (18.10: «надо поднять надпись моды и включено 57 из 57»; «Они у тебя наслаиваются на разметку»)
		-- подчёркивание кончается выше рамки выбора первого ряда (верх её размерной стрелки — y 58,5; 19.10, снимок)
		text("МОДЫ", o.X + 62, o.Y + 48, "gL", WHITE)
		art("bl.underline", o.X + 82, o.Y + 52, 60, nil, WHITE)
		local on = 0
		for i, m in ipairs(mods) do if modEnabled(i, m) then on = on + 1 end end
		text(("ВКЛЮЧЕНО %d ИЗ %d"):format(on, N), o.X + 424, o.Y + 48, "gS", WSOFT, "r")
		if SR.on or SR.str ~= "" then                        -- поиск: набранное, мигающий курсор, пока набирают
			local q = "ПОИСК: " .. SR.str:upper()
			local qs = HF.Fit(q, 150, { "gS", "gT" })
			text(q, o.X + 246, o.Y + 48, qs, SR.on and WHITE or WSOFT, "c")
			if SR.on and (T // 20) % 2 == 0 then          -- курсор — штрих (у рукописного шрифта нет «_», выходил «?»)
				art("ma.highlight", o.X + 246 + HF.Width(q, qs) / 2 + 3, o.Y + 44, 1.6, 9, WHITE)
			end
		end
		-- сетка квадратиков: прокрутка рядами, выбранный — в видимой части
		local x0, y0 = o.X + 72, o.Y + 84
		local selRow = ((pos or 1) - 1) // COLS
		scroll.mods = scroll.mods or 0
		local first = scroll.mods
		if selRow < first then first = selRow elseif selRow >= first + ROWS then first = selRow - ROWS + 1 end
		first = math.max(0, math.min(first, math.max(0, (#V - 1) // COLS - ROWS + 1)))
		scroll.mods = first
		local wob = MF and MF.wob("mods", MS.mod) or 0
		local static, selT = {}, nil
		for p = first * COLS + 1, math.min(#V, (first + ROWS) * COLS) do
			local i = V[p]
			local r, c = (p - 1) // COLS - first, (p - 1) % COLS
			local t = { m = mods[i], en = modEnabled(i, mods[i]), cx = x0 + c * STEP, cy = y0 + r * STEP, sz = SIZE }
			if i == MS.mod then
				t.sel, t.sz, t.wob, t.rot = true, SIZE + 4 + math.sin(T * 0.12) * 0.6, wob * 1.5, T * 0.6
				selT = t
			else
				static[#static + 1] = t
			end
		end
		local onKey = {}
		for _, t in ipairs(static) do onKey[#onKey + 1] = t.en and "1" or "0" end
		drawTiles(static, mods, table.concat({ first, MS.mod, #V, SR.str, LOCALFIXES_MODS_NOHD and 1 or 0,
			table.concat(onKey), math.floor(o.X * 8), math.floor(o.Y * 8) }, ":"))
		if selT then tilePasses({ selT }, mods, 1) end
		if #V == 0 then text("НИЧЕГО НЕ НАЙДЕНО", o.X + 240, o.Y + 140, "gM", WSOFT, "c") end
		-- полоса прокрутки: какая часть списка видна
		local rowsAll = math.max(1, (#V + COLS - 1) // COLS)
		if rowsAll > ROWS then
			art("bl.ruler", o.X + 448, o.Y + 140, 140, 14, Color(1, 1, 1, 0.7), 90)          -- линейка вдоль края
			art("bl.cursor", o.X + 462, o.Y + 76 + (first / math.max(1, rowsAll - ROWS)) * 128, 9, nil, WHITE, 180)
		end
		-- выбранный мод
		local m = pos and mods[MS.mod]
		if m then
			local en = modEnabled(MS.mod, m)
			local nm = HF.upper(m.name or "?")
			-- строка — ниже рамки выбора нижнего ряда (её размерная стрелка доходит до y 239; 19.10, снимок проверки)
			text(nm, o.X + 64, o.Y + 250, HF.Fit(nm, 250, { "gM", "gS", "gT" }), WHITE)
			art(en and "bl.check" or "bl.cross", o.X + 334, o.Y + 246, 12, nil, WHITE)
			local wEn = text(en and "ВКЛЮЧЁН" or "ВЫКЛЮЧЕН", o.X + 344, o.Y + 250, "gM", en and WHITE or WSOFT)
			if m.islocal then text("ЛОКАЛЬНЫЙ", o.X + 350 + (tonumber(wEn) or 56), o.Y + 249, "gT", WSOFT) end
		end
		local edited = ModsMenu.WasListEdited and ModsMenu.WasListEdited()
		if edited or next(toggled) then
			-- справа в строке подсказок: под листом места нет (там название выбранного)
			text("ИЗМЕНЕНИЯ ВСТУПЯТ В СИЛУ ПОСЛЕ ПЕРЕЗАПУСКА", o.X + 470, o.Y + 265, "gT", Color(0.96, 0.93, 0.82, 1), "r")
		end
		-- бумажный самолётик изредка перелетает через чертёж
		planeT = planeT + (LOCALFIXES.MenuDT or 1)
		local ph = planeT % 1500
		if ph < 260 then              -- нос рисунка — в правом верхнем углу, смотрит под −35°: поворот = угол пути + 35, чтобы
			local k = ph / 260            -- носик шёл туда же, куда летит (18.10: «Самолетик у тебя летит боком вправо / Просто
			local dx, dy = 540, -150 + 54 * math.cos(k * 9)   -- сделай так чтобы его носик двигался в ту же сторону»)
			local ang = math.deg(math.atan(dy, dx))
			art("bl.plane", o.X - 30 + k * 540, o.Y + 200 - k * 150 + math.sin(k * 9) * 6, 22, nil, Color(1, 1, 1, 0.8), ang + 35)
		end
		if SR.on then
			CS.hints(o, { { "arrows", "Выбор" }, { "Bksp", "Стереть" }, { "Ctrl", "Готово" } })
		else
			local h = { { "arrows", "Выбор" }, { "Enter", "Вкл / выкл" }, { "Ctrl", "Поиск" } }
			if edited then h[#h + 1] = { "Bksp", "Отменить всё" } end
			h[#h + 1] = { "Esc", "Назад" }
			CS.hints(o, h)
		end
	end
	SC.Register(MainMenuType.MODS, drawMods, true)
	-- для проверок (мост, имитатор): наш курсор, зеркало поиска и номера модов по местам списка игры
	LOCALFIXES.ModsNav = { MS = MS, SR = SR, order = function() return gameOrder(modList(), SR.str) end,
		names = function() local t = {} for i, m in ipairs(modList()) do t[i] = m.name end return t end,
		mono = function() local L = modList() local t = {} for i, m in ipairs(L) do t[i] = monoOf(L, m) end return t end }
	LFMOD:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER, function()
		if MS.on and MenuManager.GetActiveMenu() ~= MainMenuType.MODS then
			MS.on, MS.pend = false, 0
			SR.on = false
			MenuManager.SetInputMask(0xFFFFFFFF)
		end
	end)
end

-- ------------------------------------------------------------------ испытания модов (MainMenuType.MODCHALLENGES)
-- 18.10 (выбор пользователя): тот же длинный лист для заметок, что у испытаний игры. 19.10: «Там в [] указано что за
-- мод» — у каждой строки метка мода, как в имени у самого мода ([FF], [Epiph] …; модам без метки — своя короткая).
-- Список и номера — как в меню игры: испытания с номера 46 по порядку, без скрытых (hidden="true"); выбранное —
-- CustomChallengeMenu.GetSelectedChallengeID (это номер испытания; при входе игра отдаёт 1 — стрелка на первом).
-- Названия — ru/mod_challenges.lua; данные — challenges.xml модов (XMLData): персонаж (номер или имя), цель, вещи и
-- брелоки (номера или имена), правила, нужные достижения (номера или имена достижений мода).
local okM, MCH = pcall(include, "ru.mod_challenges")
if not okM or type(MCH) ~= "table" then MCH = {} end
MCH.TAGS, MCH.MODS, MCH.NAMES, MCH.SPECIAL = MCH.TAGS or {}, MCH.MODS or {}, MCH.NAMES or {}, MCH.SPECIAL or {}
MCH.PLAYERS = MCH.PLAYERS or {}
L.ModChallengeNames = MCH.NAMES
local modList
local function modChallengeList()
	if modList then return modList end
	modList = {}
	local miss = 0
	for id = 46, 4000 do
		local e = challenge(id)
		if e then
			miss = 0
			if tostring(e.hidden) ~= "true" then modList[#modList + 1] = id end
		else
			miss = miss + 1
			if miss > 8 then break end
		end
	end
	return modList
end
local modInfo = {}
local function modOf(src)                  -- короткое имя мода и номер значка Workshop (modthumbs_hd) по sourceid
	src = tostring(src or "")
	local m = modInfo[src]
	if m then return m end
	m = { name = MCH.MODS[src] }
	if not m.name then
		local ok, x = pcall(XMLData.GetModById, src)
		local raw = ok and x and x.name or src
		raw = tostring(raw):gsub("%b[]", ""):gsub("%b()", ""):gsub("^[%s%p]+", ""):gsub("%s+$", "")
		m.name = raw ~= "" and raw or src
	end
	for _, t in ipairs(THUMBS.mods or {}) do
		if (t.id ~= "" and t.id == src) or (t.folder ~= "" and t.folder == src) then m.hd = t.hd break end
	end
	m.tag = MCH.TAGS[src] or (m.name:match("^(%S+)") or m.name):sub(1, 8)
	modInfo[src] = m
	return m
end
local function modChallengeName(e)          -- метка, русское название, английское без метки
	local raw = tostring(e.name or "?")
	local tag, en = raw:match("^%[(.-)%]%s*(.*)$")
	en = en or raw
	return tag or modOf(e.sourceid).tag, (HF.IsRu and not HF.IsRu() and en) or MCH.NAMES[en] or en, en   -- англ. игра — имя мода
end
local function idsOf(s, byName)             -- «Planet X,233,WNIC» → номера (имена — через игру)
	local t = {}
	for part in tostring(s or ""):gmatch("[^,]+") do
		local nm = part:match("^%s*(.-)%s*$")
		local n = tonumber(nm)
		if not n and nm ~= "" then
			local ok, v = pcall(byName, nm)
			n = ok and v and v > 0 and v or nil
		end
		if n and n > 0 then t[#t + 1] = n end
	end
	return t
end
local TRSPR = {}
local function drawTrinket(id, x, y, size)    -- брелок — его спрайт в игре
	local s = TRSPR[id]
	if s == nil then
		local cfg = Isaac.GetItemConfig():GetTrinket(id)
		s = false
		if cfg and cfg.GfxFileName then
			s = Sprite()
			s:Load("gfx/005.350_trinket.anm2", false)
			s:ReplaceSpritesheet(0, cfg.GfxFileName)
			s:LoadGraphics()
			s:SetFrame("Idle", 0)
		end
		TRSPR[id] = s
	end
	if not s then return end
	s.Scale = Vector(size / 32, size / 32)
	s:Render(Vector(x, y + size / 2))
end
local function playerOf(v)                   -- playertype: номер или имя персонажа мода («Classic Fiend», «Sol (HC)»)
	local n = tonumber(v)
	if n then return n end
	if v == nil or v == "" then return 0 end
	for _, tainted in ipairs({ false, true }) do
		local ok, t = pcall(Isaac.GetPlayerTypeByName, tostring(v), tainted)
		if ok and t and t >= 0 then return t end
	end
	return nil, tostring(v)
end
local function drawModChallengeCard(o, id, e)
	local cx, cy = o.X + 352, o.Y + 150
	art(ART["hd.note_sq"] and "hd.note_sq" or "cs.notes", cx, cy, 196, 214, nil, sway(7, 0.25))
	local tag, name, en = modChallengeName(e)
	local mod = modOf(e.sourceid)
	local locked, done = chLocked(e), chDone(id)
	local up = HF.upper(name)                  -- ниже булавки (она закрывает верх листа до ~17% высоты)
	text(up, cx, cy - 50, HF.Fit(up, 170, { "gL", "gM", "gS" }), BLACK, "c")
	local sub = "ИСПЫТАНИЕ МОДА " .. HF.upper(mod.name)
	local subSize = HF.Fit(sub, 150, { "gT" })
	text(sub, cx + (mod.hd and 7 or 0), cy - 39, subSize, SOFT, "c")
	if mod.hd then                             -- значок мода из Workshop — какой это мод, видно сразу
		hdThumb(mod.hd, false, cx + 7 - HF.Width(sub, subSize) / 2 - 9, cy - 41, 11)
	end
	local special = MCH.SPECIAL[en]
	if special then                            -- меню мода под видом испытания (IPECAC)
		if mod.hd then hdThumb(mod.hd, false, cx - 58, cy + 2, 40) end
		local words, lines, cur = {}, {}, ""
		for w in HF.upper(special):gmatch("%S+") do words[#words + 1] = w end
		for _, w in ipairs(words) do
			local try = cur == "" and w or (cur .. " " .. w)
			if HF.Width(try, "gS") > 100 then lines[#lines + 1] = cur; cur = w else cur = try end
		end
		if cur ~= "" then lines[#lines + 1] = cur end
		for i, l in ipairs(lines) do text(l, cx - 30, cy - 18 + (i - 1) * 10, "gS", INK) end
		return
	end
	cy = cy + 5                                -- подпись с именем мода длинная — блок ниже неё (иначе касается «Персонаж»)
	-- персонаж
	local pt, rawName = playerOf(e.playertype)
	local key = pt and CS.CharKey and CS.CharKey(pt)
	if key and ART[key] then
		art(key, cx - 62, cy - 14, nil, 46, locked and Color(0.3, 0.28, 0.3, 1) or nil)
	elseif mod.hd then
		hdThumb(mod.hd, locked, cx - 62, cy - 12, 38)
	end
	local nm = pt and CS.NameOf and CS.NameOf(pt) or rawName or "?"
	nm = (HF.IsRu() and MCH.PLAYERS[nm]) or nm:gsub("%s*%b()", "")   -- «Sol (HC)» → «Сол» (рус. игра); метка мода в скобках — не часть имени
	text("ПЕРСОНАЖ:", cx - 30, cy - 30, "gT", SOFT)
	text(HF.upper(nm), cx - 30, cy - 21, HF.Fit(HF.upper(nm), 110, { "gM", "gS" }), INK)
	text("ЦЕЛЬ:", cx - 30, cy - 8, "gT", SOFT)
	local g = HF.upper(e.endstage and goalOf(e) or "по правилам мода")
	text(g, cx - 30, cy + 1, HF.Fit(g, 112, { "gS", "gT" }), INK)
	-- стартовые вещи и брелоки (у модов — номерами или именами)
	local items = idsOf(e.startingitems, Isaac.GetItemIdByName)
	local trinkets = idsOf(e.startingtrinkets, Isaac.GetTrinketIdByName)
	local card = tonumber(e.startingcard) or 0
	local y = cy + 22
	text("С СОБОЙ:", cx - 82, y, "gT", SOFT)
	if #items + #trinkets == 0 and card <= 0 then
		text("НИЧЕГО", cx - 40, y, "gT", INK)
	else
		local slot = 0
		if card > 0 and drawCard(card, cx - 44, y - 1, 15) then slot = 1 end
		for _, it in ipairs(items) do
			if slot >= 7 then break end
			if CS.drawItem then CS.drawItem(it, cx - 44 + slot * 17, y - 1, 15) end
			slot = slot + 1
		end
		for _, tr in ipairs(trinkets) do
			if slot >= 7 then break end
			drawTrinket(tr, cx - 44 + slot * 17, y - 1, 15)
			slot = slot + 1
		end
	end
	-- правила
	local rules = {}
	if tostring(e.canshoot) == "false" then rules[#rules + 1] = "БЕЗ СТРЕЛЬБЫ" end
	local gc = tonumber(e.getcurse) or 0
	if gc > 0 then
		local cs = {}
		for bitv, nmc in pairs(CURSES) do if gc & bitv ~= 0 then cs[#cs + 1] = nmc end end
		table.sort(cs)
		rules[#rules + 1] = "ПРОКЛЯТИЯ: " .. HF.upper(table.concat(cs, ", "))
	end
	local rf = {}
	for _, r in ipairs(list(e.roomfilter)) do if ROOMS[r] then rf[#rf + 1] = ROOMS[r] end end
	if #rf > 0 then rules[#rules + 1] = "БЕЗ " .. HF.upper(table.concat(rf, ", ")) end
	if tonumber(e.difficulty) == 1 then rules[#rules + 1] = "СЛОЖНЫЙ РЕЖИМ" end
	for i, r in ipairs(rules) do
		if i > 3 then break end
		text(r, cx - 82, cy + 38 + (i - 1) * 9, HF.Fit(r, 168, { "gT" }), INK)
	end
	-- отметка
	if locked then
		art("cs.padlock", cx + 60, cy + 70, 12)
		text("ЗАКРЫТО", cx + 38, cy + 72, "gM", BLOODC, "r")
	elseif done then
		local r = sway(9, 1.5) - 8
		text("ВЫПОЛНЕНО!", cx + 44, cy + 70, "gM", BLOODC, "c", nil, r)
	end
end
local function drawModChallenges(o)
	T = T + (LOCALFIXES.MenuDT or 1)
	bg(o, "mch")
	local ids = modChallengeList()
	local selId = CustomChallengeMenu.GetSelectedChallengeID()
	local sel = 1
	for i, id in ipairs(ids) do if id == selId then sel = i break end end
	if MF then MF.sel("modchallenges", sel) end
	local wob = MF and MF.wob("modchallenges", sel) or 0
	local top, k, lines = longList(o, "mch", 128, 196, math.max(1, #ids), sel, function(i, y, xn, xt, wt, on)
		local id = ids[i]
		local e = id and challenge(id)
		if not e then return end
		local locked = chLocked(e)
		local tag, name = modChallengeName(e)
		local tg = "[" .. HF.upper(tag) .. "]"
		local nm = HF.upper(name)
		local dx = on and (math.sin(T * 0.12) * 1.2 + wob * 0.3) or 0
		if on then art("ma.highlight", xt + wt / 2 - 4, y - 4, wt + 14, 14, Color(1, 1, 1, 0.75)) end
		text(i .. ".", xn + dx, y - 5, "gS", locked and DISABLED or INK, "r")
		local tgW = HF.Width(tg, "gT")
		text(tg, xt + dx, y - 4, "gT", locked and DISABLED or BLOODC)     -- метка мода — красным карандашом
		local xx, ww = xt + tgW + 3, wt - tgW - 3
		local size = HF.Fit(nm, ww, { "gS", "gT" })     -- один размер на весь список (разные выглядели неровно)
		text(nm, xx + dx, y - 5, size, locked and DISABLED or (on and BLACK or INK))
		local tw = HF.Width(nm, size)
		if locked then
			art("cs.padlock", xx + tw + 6 + dx, y - 6, 7)
		elseif chDone(id) then
			strike(xx + tw / 2 + dx, y - 9, tw + 4, id)
		end
		if on then art("ma.cursor", xn - HF.Width(i .. ".", "gS") - 7 + dx, y - 6, 8) end
	end)
	if top then
		text("МОДЫ", o.X + 150, top + lines[2] * k - 7, "gL", INK, "c")              -- на первой линии, ниже булавки
		if #ids == 0 then text("НЕТ ИСПЫТАНИЙ МОДОВ", o.X + 150, top + lines[3] * k - 7, "gM", SOFT, "c") end
	end
	local ttl = "ИСПЫТАНИЯ МОДОВ"
	art("cs.title_banner", o.X + 345, o.Y + 22, 150, nil, nil, sway(1, 0.3))
	text(ttl, o.X + 341, o.Y + 26, HF.Fit(ttl, 124, { "gL", "gM" }), INK, "c")
	local e = ids[sel] and challenge(ids[sel])
	if e then drawModChallengeCard(o, ids[sel], e) end
	if MF then MF.run("mch", o) end
	CS.hints(o, { { "updown", "Выбор" }, { "Enter", "Начать" }, { "Esc", "Назад" } })
end
SC.Register(MainMenuType.MODCHALLENGES, drawModChallenges, true)

-- ------------------------------------------------------------------ предметы (MainMenuType.COLLECTION)
-- 18.10, выбор пользователя: «Альбом наклеек» — найденные — цветные наклейки, ненайденные — карандашный контур,
-- карточка справа; «Новые иконки для предметов НЕ ГЕНЕРИРУЙ / Используй те что используются уже внутри забега / Как
-- полноценные предметы». Сетка — как у игры (20 × 6 на страницу, стрелки двигают выбор игры — раскладка та же, иначе
-- «вниз» уводил бы не туда): CollectionMenu.GetSelectedPage (с 0) и GetSelectedElement (0–119); предметы — по номерам,
-- без несуществующих и скрытых (как у игры и EID). Найден ли — PersistentGameData.IsItemInCollection (игра ведёт
-- только свои предметы; предметы модов показывает найденными — так же и здесь). Имя и цитата — из конфига предмета
-- (у игры — ключи таблицы строк, у модов — наш перевод, ru_items.lua), описание — EID, если он стоит (его собственная
-- подсказка на этом экране спрятана — EID.isHidden на время экрана, потом прежнее значение).
local PER, COLS = 120, 20
local NUMV = (CollectibleType and CollectibleType.NUM_COLLECTIBLES) or 733
local itemList, vanTotal
local function collectionList()
	if itemList then return itemList end
	itemList, vanTotal = {}, 0
	local ic = Isaac.GetItemConfig()
	local okN, all = pcall(ic.GetCollectibles, ic)
	local n = okN and all and all.Size and (all.Size - 1) or (NUMV - 1)
	for id = 1, n do
		local okC, cfg = pcall(ic.GetCollectible, ic, id)
		if okC and cfg and not cfg.Hidden then
			itemList[#itemList + 1] = id
			if id < NUMV then vanTotal = vanTotal + 1 end
		end
	end
	return itemList
end
local foundOf = {}                               -- id → найден (сбрасывается при входе на экран: могли найти в забеге)
local function itemFound(id)
	if L.forceUnfound and L.forceUnfound[id] then return false end   -- проверка вида в лаборатории (мост)
	if id >= NUMV then return true end
	local v = foundOf[id]
	if v == nil then
		local pgd = Isaac.GetPersistentGameData()
		local ok, f = pcall(pgd.IsItemInCollection, pgd, id)
		v = not ok or f == true
		foundOf[id] = v
	end
	return v
end
local foundCache = { t = -1000 }
local function foundCount()                     -- пересчёт при входе на экран (перебор ~730 предметов)
	if foundCache.n == nil then
		local n = 0
		for _, id in ipairs(collectionList()) do if id < NUMV and itemFound(id) then n = n + 1 end end
		foundCache.n = n
	end
	return foundCache.n
end
local function locStr(s, cat)
	s = tostring(s or "")
	if s:sub(1, 1) == "#" then
		local ok, r = pcall(Isaac.GetString, cat, s:sub(2))
		if ok and r and r ~= "" and r ~= "StringTable::InvalidKey" then return r end
		return ""
	end
	return s
end
local function plain(s)                         -- знаки, которых нет в шрифте меню, — на близкие (↑ ↓ — плюс и минус)
	return (tostring(s):gsub("—", "-"):gsub("–", "-"):gsub("«", "'"):gsub("»", "'"):gsub("…", "..."):gsub('"', "'")
		:gsub("↑", "+"):gsub("↓", "-"))
end
local eidCache = {}
local function eidLines(id)                      -- описание EID без значков и цветовых меток, строки по «#»
	if not (EID and EID.getDescriptionObj) then return nil end
	local c = eidCache[id]
	if c == nil then
		c = false
		local ok, obj = pcall(EID.getDescriptionObj, EID, 5, 100, id, nil, false)
		if ok and type(obj) == "table" and obj.Description then
			local d = tostring(obj.Description):gsub("{{.-}}", ""):gsub("%[%[.-%]%]", "")
			c = {}
			for part in d:gmatch("[^#]+") do
				-- стрелка в начале строки EID — значок-маркер (знак числа и так есть: «↑ +0.7 …»)
				part = plain(part:gsub("^%s*↑%s*", ""):gsub("^%s*↓%s*", "")):gsub("%s+", " "):match("^%s*(.-)%s*$")
				if part ~= "" and part ~= "+" and part ~= "-" then c[#c + 1] = part end
			end
		end
		eidCache[id] = c
	end
	return c or nil
end
local itemMod = {}
local function modOfItem(id)                     -- предмет мода: какой мод (XMLData, sourceid)
	local m = itemMod[id]
	if m == nil then
		m = false
		if id >= NUMV then
			local ok, e = pcall(XMLData.GetEntryById, XMLNode.ITEM, id)
			if ok and e and e.sourceid and e.sourceid ~= "BaseGame" then m = modOf(e.sourceid) end
		end
		itemMod[id] = m
	end
	return m or nil
end
-- наклейка: спрайт предмета из игры (как в забеге) с белой вырубкой по контуру и лёгкой тенью; ненайденный —
-- тонкий карандашный контур силуэта, внутри — бумага страницы
local ISPR = {}
local function itemSpr(id)
	local s = ISPR[id]
	if s == nil then
		s = false
		local ok, cfg = pcall(function() return Isaac.GetItemConfig():GetCollectible(id) end)
		if ok and cfg and cfg.GfxFileName and cfg.GfxFileName ~= "" then
			s = Sprite()
			s:Load("gfx/005.100_collectible.anm2", false)
			s:ReplaceSpritesheet(1, cfg.GfxFileName)
			s:LoadGraphics()
			s:SetFrame("Idle", 0)
		end
		ISPR[id] = s
	end
	return s or nil
end
local C_PENCIL = Color(0, 0, 0, 0.85, 0.33, 0.3, 0.32)
local C_PAPER = Color(0, 0, 0, 1, 0.93, 0.88, 0.88)       -- внутри контура: бумага карточки
local C_SLOTFILL = Color(0, 0, 0, 1, 0.81, 0.76, 0.79)    -- внутри контура в сетке: цвет ячейки (иначе — белое пятно)
-- наклейка — белая карточка из атласа (al.sticker, tools/sticker_gen.py: край, блик, тень) и спрайт предмета на ней —
-- одна отрисовка спрайта (19.10: вырубка по силуэту — 3–10 отрисовок, у каждого предмета своя текстура, 120 наклеек
-- роняли меню до 61 к/с; детали атласа почти бесплатны). Ненайденный — карандашный контур силуэта: тот же силуэт
-- чуть крупнее карандашом и внутри — бумага (две отрисовки; ненайденных обычно немного)
-- pass: "card" — только подложки (атлас), "item" — только спрайты; nil — всё. Сетка рисует проходами: сначала все
-- подложки, потом все предметы — атлас и текстуры предметов не чередуются на каждой наклейке
local function sticker(id, x, y, size, found, rot, lift, pass, fill)
	local s = itemSpr(id)
	if not s then return end
	local k = size / 32
	rot = rot or 0
	if found then
		local w = size * 0.9
		if pass ~= "item" then
			if lift and lift > 0 then            -- приподнята — тень ниже и мягче
				art("al.sticker", x + lift * 0.6, y + lift * 0.9, w * 1.02, w * 128 / 112 * 1.02, Color(0, 0, 0, 0.35), rot)
			end
			art("al.sticker", x, y, w, w * 128 / 112, nil, rot)
		end
		if pass == "card" then return end
		s.Scale = Vector(k * 1.02, k * 1.02)      -- рисунок предмета в кадре 32 × 32 с полями — чуть крупнее подложки
		s.Rotation = rot
		s:RenderLayer(1, Vector(x, y + size * 0.48))
	else
		if pass == "card" then return end
		local f = fill and 1.16 or 1.1               -- в сетке наклейки мелкие — контур толще
		s.Rotation = rot
		s.Scale = Vector(k * f, k * f)
		s.Color = C_PENCIL
		s:RenderLayer(1, Vector(x, y + size / 2 + size * (f - 1) * 0.5))
		s.Scale = Vector(k, k)
		s.Color = fill or C_PAPER
		s:RenderLayer(1, Vector(x, y + size / 2))
		s.Color = Color.Default
	end
	s.Rotation = 0
	s.Scale = Vector.One
end
local function tiltOf(id) return ((id * 37) % 9 - 4) * 1.4 end
local QUALITY_RU = { [0] = "ХЛАМ", "ОБЫЧНЫЙ", "ХОРОШИЙ", "ОТЛИЧНЫЙ", "РЕДКИЙ" }
-- английский — отдельной таблицей: «ОБЫЧНЫЙ» в словаре — сложность и версия персонажа («NORMAL»), а здесь качество
local QUALITY_EN = { [0] = "JUNK", "COMMON", "GOOD", "GREAT", "RARE" }
local function drawItemCard(o, id, found)
	local cx, top = o.X + 402, o.Y + 46
	art(ART["hd.note_sq"] and "hd.note_sq" or "cs.notes", cx, top + 100, 150, 200, nil, sway(7, 0.25))
	text("№ " .. id, cx + 58, top + 34, "gT", SOFT, "r")
	local cfg = Isaac.GetItemConfig():GetCollectible(id)
	local bob = math.sin(T * 0.05) * 0.8
	sticker(id, cx, top + 50 + bob, 34, found, tiltOf(id) * 0.5, 1.2)
	if not found then
		text("???", cx, top + 82, "gM", BLACK, "c")
		text("ЕЩЁ НЕ НАЙДЕН", cx, top + 93, "gT", SOFT, "c")
		local pg = "Найди его в забеге, и наклейка займёт своё место."
		for i, l in ipairs(HF.Wrap(pg, "gT", 126)) do text(l, cx, top + 112 + (i - 1) * 9, "gT", INK, "c") end
		return
	end
	local name = HF.upper(plain(locStr(cfg and cfg.Name, "Items")))
	text(name, cx, top + 82, HF.Fit(name, 134, { "gM", "gS", "gT" }), BLACK, "c")
	local quote = locStr(cfg and cfg.Description, "Items")
	if quote ~= "" then
		local q = HF.upper(plain(quote))
		text(q, cx, top + 92, HF.Fit(q, 134, { "gT" }), SOFT, "c")
	end
	-- качество — звёзды (0–4), вид предмета
	local qn = cfg and tonumber(cfg.Quality) or 0
	for i = 1, 4 do
		art(i <= qn and "al.star" or "al.star_empty", cx - 52 + (i - 1) * 9, top + 104, 8)
	end
	text((HF.IsRu() and QUALITY_RU or QUALITY_EN)[qn] or "", cx - 14, top + 106, "gT", INK)
	local kind
	if cfg and cfg.Type == ItemType.ITEM_ACTIVE then
		local ch = tonumber(cfg.MaxCharges) or 0
		if cfg.ChargeType == 1 then kind = "АКТИВНЫЙ · ПО ВРЕМЕНИ"
		elseif cfg.ChargeType == 2 then kind = "АКТИВНЫЙ · ОСОБЫЙ ЗАРЯД"
		else kind = ch > 0 and ("АКТИВНЫЙ · ЗАРЯДОВ " .. ch) or "АКТИВНЫЙ" end
	elseif cfg and cfg.Type == ItemType.ITEM_FAMILIAR then
		kind = "СПУТНИК"
	else
		kind = "ПАССИВНЫЙ"
	end
	text(kind, cx + 56, top + 106, "gT", SOFT, "r")
	-- описание EID (если EID стоит)
	local y = top + 118
	local bottom = top + 178
	local lines = eidLines(id)
	if lines then
		local out = {}
		for _, part in ipairs(lines) do
			for _, l in ipairs(HF.Wrap(part, "gT", 128)) do out[#out + 1] = l end
		end
		for i, l in ipairs(out) do
			if y > bottom then break end
			if y + 8.5 > bottom and i < #out then l = l .. "..." end
			text(l, cx - 64, y, "gT", INK)
			y = y + 8.5
		end
	end
	-- предмет мода — какой мод
	local m = modOfItem(id)
	if m then
		local t2 = "МОД " .. HF.upper(m.name)
		local sz = HF.Fit(t2, 118, { "gT" })
		local w = HF.Width(t2, sz)
		if m.hd then hdThumb(m.hd, false, cx - w / 2 - 7, top + 185, 10) end
		text(t2, cx + (m.hd and 6 or 0), top + 187, sz, SOFT, "c")
	end
end
local eidHid, eidPrev = false, nil
local function eidHide(on)                       -- своя подсказка EID поверх альбома — не нужна (описание — в карточке)
	if on and not eidHid then                    -- вход на экран: находки — заново
		foundOf, foundCache.n = {}, nil
		L.gridKey = nil
	end
	if not EID then eidHid = on; return end
	if on and not eidHid then
		eidPrev, eidHid = EID.isHidden, true
		EID.isHidden = true
	elseif not on and eidHid then
		EID.isHidden, eidHid = eidPrev, false
	end
end
-- сетка наклеек: z — масштаб (1 — прямо на экран; в картинку-кэш — пиксели, z = точек → пикселей)
local C_SLOT, C_SLOTSEL = Color(0.86, 0.83, 0.86, 1), Color(0.8, 0.68, 0.68, 1)
local function gridPasses(ids, page, el, x0, y0, STX, STY, z)
	for i = 0, PER - 1 do                        -- проход 1: ячейки — серее страницы (печатный фон под наклейку)
		art("al.slot", (x0 + (i % COLS) * STX) * z, (y0 + (i // COLS) * STY) * z, 12.6 * z, 15.6 * z,
			i == el and C_SLOTSEL or C_SLOT)
	end
	for _, pass in ipairs({ "card", "item" }) do -- проходы 2–3: подложки, потом спрайты предметов
		for i = 0, PER - 1 do
			local id = ids[page * PER + i + 1]
			if id and i ~= el then
				sticker(id, (x0 + (i % COLS) * STX) * z, (y0 + (i // COLS) * STY - 0.5) * z, 11.5 * z, itemFound(id),
					tiltOf(id), nil, pass, C_SLOTFILL)
			end
		end
	end
end
-- 19.10: 120 наклеек — 120 разных текстур предметов в каждом кадре (у пользователя 144 к/с: меню падало до 61, после
-- проходов — 88). Сетка меняется только со страницей, выбором, находками и местом экрана — она рисуется в картинку
-- (REPENTOGON Renderer.RenderToImage: внутри картинки единица — пиксель, поэтому всё × масштаб точек), а каждый кадр
-- кладётся одна картинка. Нет RenderToImage (старый REPENTOGON) — рисуется прямо, как раньше.
local gridImg, gridW, gridH
local SRCQ
local function drawGrid(ids, page, el, x0, y0, STX, STY, o)
	local canImg = Renderer and Renderer.RenderToImage and Renderer.CreateImage and SourceQuad and DestinationQuad
	if not canImg or L.gridOff then
		gridPasses(ids, page, el, x0, y0, STX, STY, 1)
		return
	end
	local sw, sh = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
	local z = Isaac.GetScreenPointScale and Isaac.GetScreenPointScale() or 1
	local W, H = math.floor(sw * z + 0.5), math.floor(sh * z + 0.5)
	if not gridImg or gridW ~= W or gridH ~= H then
		local ok, img = pcall(Renderer.CreateImage, W, H, "localfixes_album_grid_" .. W .. "x" .. H)
		if not ok or not img then
			L.gridOff = true
			gridPasses(ids, page, el, x0, y0, STX, STY, 1)
			return
		end
		gridImg, gridW, gridH, L.gridKey = img, W, H, nil
	end
	local key = page .. ":" .. el .. ":" .. #ids .. ":" .. math.floor(o.X * 8) .. ":" .. math.floor(o.Y * 8) .. ":" .. z
	if key ~= L.gridKey then
		local ok, err = pcall(Renderer.RenderToImage, gridImg, function(ctl)
			ctl:Clear()
			gridPasses(ids, page, el, x0, y0, STX, STY, z)
		end)
		if not ok then
			Isaac.DebugString("[localfixes] альбом: сетка в картинку не рисуется — " .. tostring(err))
			L.gridOff = true
			gridPasses(ids, page, el, x0, y0, STX, STY, 1)
			return
		end
		L.gridKey = key
	end
	SRCQ = SRCQ or SourceQuad.NewFromBounds(Vector(0, 0), Vector(1, 1), true)
	gridImg:Render(SRCQ, DestinationQuad.NewFromBounds(Vector(0, 0), Vector(sw, sh)), KColor(1, 1, 1, 1))
end
local function drawCollection(o)
	T = T + (LOCALFIXES.MenuDT or 1)
	bg(o, "col")
	eidHide(true)
	local ids = collectionList()
	local page = CollectionMenu.GetSelectedPage() or 0
	local el = CollectionMenu.GetSelectedElement() or 0
	local pages = math.max(1, math.ceil(#ids / PER))
	if MF then MF.sel("collection", page * PER + el) end
	local wob = MF and MF.wob("collection", page * PER + el) or 0
	-- страница альбома
	local PX, PY = o.X + 168, o.Y + 145
	art("al.page", PX, PY, 318, nil, nil, sway(3, 0.15))
	art("al.ribbon", PX + 124, o.Y + 44, 9)
	art("al.tape", o.X + 26, o.Y + 236, 34, nil, nil, -32)
	text("ТО, ЧТО Я НАШЁЛ", PX, o.Y + 74, "gL", INK, "c")              -- ниже колец пружины (до y≈59)
	local STX, STY = 14.2, 18.6
	local x0, y0 = PX - 9.5 * STX, o.Y + 90
	local sel = ids[page * PER + el + 1]
	drawGrid(ids, page, el, x0, y0, STX, STY, o)
	if sel then                                  -- выбранная — приподнята над страницей, покачивается
		local r, c = el // COLS, el % COLS
		local cx, cy = x0 + c * STX, y0 + r * STY
		sticker(sel, cx, cy - 2 + math.sin(T * 0.1) * 0.6, 15, itemFound(sel), tiltOf(sel) + wob * 4, 1.6, nil, C_SLOTFILL)
	end
	-- страница и находки
	local f = foundCount()
	text(("СТРАНИЦА %d ИЗ %d"):format(page + 1, pages), PX - 134, o.Y + 207, "gS", INK)
	text(("НАЙДЕНО %d ИЗ %d"):format(f or 0, vanTotal or 0), PX + 134, o.Y + 207, "gS", INK, "r")
	local mods = #ids - (vanTotal or 0)
	if mods > 0 then
		text(("И ЕЩЁ %d ПРЕДМЕТОВ ИЗ МОДОВ"):format(mods), PX + 134, o.Y + 217, "gT", SOFT, "r")
	end
	-- карточка выбранного
	art("cs.title_banner", o.X + 402, o.Y + 22, 130, nil, nil, sway(1, 0.3))
	text("ПРЕДМЕТЫ", o.X + 398, o.Y + 26, "gL", INK, "c")
	if sel then drawItemCard(o, sel, itemFound(sel)) end
	if MF then MF.run("col", o) end
	CS.hints(o, { { "arrows", "Выбор" }, { "Esc", "Назад" } })
end
SC.Register(MainMenuType.COLLECTION, drawCollection, true)
LFMOD:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER, function()
	if eidHid and MenuManager.GetActiveMenu() ~= MainMenuType.COLLECTION then eidHide(false) end
end)
LFMOD:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function() eidHide(false) end)

-- ------------------------------------------------------------------ концовки (MainMenuType.ENDINGS)
-- 18.10, выбор пользователя: «Видеокассеты» — полка VHS с подписанными корешками, выбранная выдвигается, телевизор
-- показывает кадр. Раскладка — как у игры (CutscenesMenu: 4 столбца по 6, номер — по столбцам): 4 стопки по 6 кассет,
-- «вниз» — кассета ниже, «вправо» — соседняя стопка. Данные и подписи — ru/endings.lua (вики «Endings» + cutscenes.xml).
-- Телевизор: ролики-анимации (Эпилог, Финал, Титры) идут в нём прямо из игры (их anm2, кадр 427 × 240 рисуется в
-- картинку и кладётся в окно экрана); у роликов-видео — свой рисунок кадра (vh.f<номер>, если есть), иначе «снег»;
-- у закрытой концовки (слой меню игры скрыт) — пыльная кассета и «снег».
local okE, ENDS = pcall(include, "ru.endings")
if not okE or type(ENDS) ~= "table" then ENDS = nil end
local function endingOpen(i)
	local e = ENDS and ENDS[i]
	if not e then return false end
	local ok, spr = pcall(CutscenesMenu.GetSprite)
	if not ok or not spr then return true end
	local okL, l = pcall(spr.GetLayer, spr, e.layer)
	if okL and l then return l:IsVisible() end
	return true
end
local tv = { spr = {} }
local function tvLive(e, hx, hy, hw, hh)        -- кадр ролика-анимации в окне экрана (letterbox 16:9)
	local path, anim = e.live[1], e.live[2]
	local s = tv.spr[path]
	if s == nil then
		s = Sprite()
		s:Load(path, true)
		if not s:IsLoaded() then s = false end
		tv.spr[path] = s
	end
	if not s or not (Renderer and Renderer.RenderToImage and Renderer.CreateImage) then return false end
	if tv.cur ~= e then
		tv.cur, tv.tick, tv.last = e, 0, nil
		s:Play(anim, true)
	end
	if (LOCALFIXES.MenuDT or 1) > 0 then          -- ролик — 30 кадров в секунду: шаг на каждом втором кадре логики
		tv.tick = tv.tick + 1
		if tv.tick % 2 == 0 then
			s:Update()
			if s:IsFinished(anim) then s:Play(anim, true) end
		end
	end
	if not tv.img then
		local ok, img = pcall(Renderer.CreateImage, 427, 240, "localfixes_tv_427x240")
		if not ok or not img then return false end
		tv.img = img
	end
	local fr = s:GetFrame()
	if tv.last ~= fr then
		local ok = pcall(Renderer.RenderToImage, tv.img, function(ctl)
			ctl:Clear()
			s:Render(Vector(0, 0))
		end)
		if not ok then return false end
		tv.last = fr
	end
	local h2 = hw * 240 / 427
	local y0 = hy + (hh - h2) / 2
	SRCQ = SRCQ or SourceQuad.NewFromBounds(Vector(0, 0), Vector(1, 1), true)
	tv.img:Render(SRCQ, DestinationQuad.NewFromBounds(Vector(hx, y0), Vector(hx + hw, y0 + h2)), KColor(1, 1, 1, 1))
	tv.secs = fr / 30
	return true
end
local TAPES = { "vh.tape1", "vh.tape2", "vh.tape3" }
-- надписи на кадрах (в роликах — «The End», «MISSING!» на плакате, «MOTHER» на рисунке): текст, x, y (доли кадра),
-- кегль, цвет, поворот
local TV_TEXT = {
	[14] = { "КОНЕЦ", 0.5, 0.36, "gL", Color(0.95, 0.95, 0.92, 1), -4 },
	[15] = { "ПРОПАЛ!", 0.22, 0.66, "gT", Color(0.2, 0.15, 0.15, 1), -3 },
	[21] = { "МАТЬ", 0.5, 0.17, "gM", Color(0.3, 0.12, 0.1, 0.9), -2 },
}
local function drawEndings(o)
	T = T + (LOCALFIXES.MenuDT or 1)
	bg(o, "end")
	if not ENDS then return end
	local sel = CutscenesMenu.GetSelectedElement() or 0
	if MF then MF.sel("endings", sel) end
	local wob = MF and MF.wob("endings", sel) or 0
	local open, total = 0, 0
	for i = 0, 23 do if ENDS[i] then total = total + 1; if endingOpen(i) then open = open + 1 end end end
	-- шапка и счётчик
	art("cs.title_banner", o.X + 228, o.Y + 32, 150, nil, nil, sway(1, 0.3))
	text("МУЛЬТЫ!", o.X + 224, o.Y + 36, "gL", INK, "c")
	text(("ОТКРЫТО %d ИЗ %d"):format(open, total), o.X + 228, o.Y + 62, "gS", CS.CREAM or Color(0.93, 0.88, 0.8, 1), "c")
	-- полка и стопки кассет (4 × 6, номер — по столбцам, как у игры)
	art("vh.shelf", o.X + 160, o.Y + 225, 300, 15)
	local TW, TH, STEP = 66, 14, 14.3
	local function tape(i, x, y, rot)
		local e = ENDS[i]
		local isOpen = endingOpen(i)
		local h = (i * 2654435761) % 1000
		local piece = isOpen and TAPES[h % 3 + 1] or "vh.tape_dust"
		art(piece, x, y, TW, TH, nil, rot)
		local lbl = isOpen and e.label or "???"
		local size = HF.Fit(lbl, TW * 0.6, { "gS", "gT" })
		text(lbl, x + TW * 0.067, y + 2.6, size, isOpen and INK or DISABLED, "c", nil, rot)
	end
	for c = 0, 3 do
		for r = 0, 5 do
			local i = c * 6 + r
			if ENDS[i] and i ~= sel then
				local h = (i * 2654435761) % 1000
				tape(i, o.X + 52 + c * 72 + (h % 5 - 2) * 0.8, o.Y + 211 - (5 - r) * STEP, ((h // 7) % 5 - 2) * 0.6)
			end
		end
	end
	if ENDS[sel] then                            -- выбранная — выдвинута из стопки к телевизору, поверх соседей
		local c, r = sel // 6, sel % 6
		local x = o.X + 52 + c * 72 + 10 + math.sin(T * 0.08) * 0.8
		local y = o.Y + 211 - (5 - r) * STEP
		tape(sel, x, y, -1.5 + wob * 2)
		art("ma.cursor", x - TW / 2 - 6, y - 1, 8)
	end
	-- телевизор на видеомагнитофоне; окно экрана — x 72–483, y 204–557 из 684 × 708 (vhs: tv)
	local TVX, TVY, TVW = o.X + 392, o.Y + 116, 156
	local k = TVW / 684
	local left, top = TVX - TVW / 2, TVY - 708 * k / 2
	local hx, hy, hw, hh = left + 70 * k, top + 202 * k, 415 * k, 357 * k
	local e = ENDS[sel]
	local isOpen = e and endingOpen(sel)
	art("vh.noise1", hx + hw / 2, hy + hh / 2, hw, hh, Color(0.05, 0.05, 0.06, 1))   -- погасший экран
	local shown = false
	if e and isOpen then
		if e.live then
			shown = tvLive(e, hx, hy, hw, hh)
		elseif ART["en.f" .. sel] then         -- свой кадр ролика-видео (16:9, как у живых роликов — с полями)
			local h2 = hw * 9 / 16
			local cy = hy + hh / 2
			art("en.f" .. sel, hx + hw / 2, cy, hw, h2)
			local ov = TV_TEXT[sel]                    -- надпись кадра — шрифтом меню, по-русски
			if ov then text(ov[1], hx + hw * ov[2], cy - h2 / 2 + h2 * ov[3], ov[4], ov[5], "c", nil, ov[6]) end
			shown = true
		end
	end
	if not shown then                              -- «снег»: кадры шума сменяются
		local n = (T // 3) % 3 + 1
		art("vh.noise" .. n, hx + hw / 2, hy + hh / 2, hw, hh, Color(1, 1, 1, 0.9))
		if e and isOpen then text(e.label, hx + hw / 2, hy + hh / 2 + 3, "gM", Color(0.9, 1, 0.9, 0.85), "c") end
	else                                           -- лёгкая рябь кинескопа поверх кадра
		art("vh.noise" .. ((T // 2) % 3 + 1), hx + hw / 2, hy + hh / 2, hw, hh, Color(1, 1, 1, 0.07))
	end
	art("vh.tv", TVX, TVY, TVW)
	art("vh.vcr", TVX, o.Y + 224, 142)
	local vk = 142 / 584
	local led = (T // 30) % 2 == 0 and isOpen
	if led then art("pa.ember", TVX - 246 * vk, o.Y + 224 - 21 * vk, 4) end      -- огонёк «воспроизведение»
	local secs = math.floor((shown and e and e.live and tv.secs) or 0)
	local clock = isOpen and ("%d:%02d"):format(secs // 60, secs % 60) or "--:--"
	text(clock, TVX + 195 * vk, o.Y + 224 - 10 * vk, "gT", Color(0.55, 1, 0.6, 0.9), "c")
	-- записка: что за концовка и как открыть
	art(ART["hd.note_wide"] and "hd.note_wide" or "ma.note_wide", o.X + 78, o.Y + 74, 130, 96, nil, sway(4, 0.4))
	if e then
		local lbl = isOpen and e.label or "???"
		text(lbl, o.X + 78, o.Y + 53, "gM", BLACK, "c")
		local y = o.Y + 62
		text("КАК ОТКРЫТЬ:", o.X + 20, y, "gT", SOFT)
		y = y + 8
		for _, l in ipairs(HF.Wrap(e.how, "gT", 112, 2)) do text(l, o.X + 20, y, "gT", INK); y = y + 7.5 end
		if isOpen then
			y = y + 2
			for _, l in ipairs(HF.Wrap(e.what, "gT", 112, 4)) do text(l, o.X + 20, y, "gT", SOFT); y = y + 7.5 end
		end
	end
	if MF then MF.run("end", o) end
	CS.hints(o, { { "arrows", "Выбор" }, { "Enter", "Смотреть" }, { "Esc", "Назад" } })
end
SC.Register(MainMenuType.ENDINGS, drawEndings, true)

-- ------------------------------------------------------------------ секреты (внутри статистики)
-- 18.10, выбор пользователя: «Альбом марок» — открытые — цветные марки с зубцами, закрытые — серый оттиск; карточка
-- «как открыть». У игры «Секреты» — слой статистики (StatsMenu.IsSecretsMenuVisible): ←/→ по списку, ↑/↓ — раздел
-- (игра и моды с достижениями), выбранное достижение Lua не отдаёт (у закрытого и картинки нет — «Закрыто»). Поэтому
-- выбор свой: на время экрана стрелки и LT/RT у игры закрыты маской ввода (Esc — её: закрывает «Секреты»), по альбому
-- ходим сами — по настоящей сетке (← → ↑ ↓), разделы — LT/RT. Данные — XMLData (узел ACHIEVEMENT: картинка, раздел по
-- sourceid), открыто ли — PersistentGameData.Unlocked. Марка — бумажка достижения игры (achievements.anm2: слои
-- «Paper» и «Achievement», 272 × 176) в перфорированной рамке; закрытое — серая марка с замком (картинку игра не
-- раскрывает — и мы); на карточке — сама бумажка крупно (у закрытого — «Закрыто» игры) и как открыть (L.AchHow).
local SEC = { cat = 1, pos = {}, built = false }
-- как открыть: ru/ach_how.lua — { [номер достижения] = "условие по-русски" } (игра — по вики, таблица achievement;
-- моды — по их таблицам открытий); нет файла или строки — на карточке нет и пункта «как открыть»
local okH, ACH_HOW = pcall(include, "ru.ach_how")
if not okH or type(ACH_HOW) ~= "table" then ACH_HOW = {} end
function L.AchHow(id) return ACH_HOW[id] end
local SEC_TAG = { ["3778123093"] = "FF", ["3012430463"] = "EPIPH", ["3440586497"] = "LNF", ["1925867065"] = "IPECAC",
	["3513706025"] = "FURTH", ["3503885496"] = "HC", ["3134600246"] = "RESH", ["3343815332"] = "LASTJ" }
local function secBuild()
	if SEC.built then return end
	SEC.built = true
	SEC.cats = {}
	local byKey = {}
	local id, miss = 0, 0
	while miss < 40 and id < 8000 do
		id = id + 1
		local ok, e = pcall(XMLData.GetEntryById, XMLNode.ACHIEVEMENT, id)
		if ok and e and e.gfx then
			miss = 0
			if tostring(e.hidden) ~= "true" then
				local src = tostring(e.sourceid or "")
				if src == "" then src = "BaseGame" end
				local c = byKey[src]
				if not c then
					c = { src = src, ids = {} }
					if src == "BaseGame" then
						c.name, c.tag = "ИГРА", "ИГРА"
					else
						local m = modOf(src)
						c.name, c.tag, c.hd = m.name, SEC_TAG[src] or m.tag, m.hd
					end
					byKey[src] = c
					SEC.cats[#SEC.cats + 1] = c
				end
				c.ids[#c.ids + 1] = id
			end
		else
			miss = miss + 1
		end
	end
end
local achUnl = {}
local function achOpen(id)
	local v = achUnl[id]
	if v == nil then
		local pgd = Isaac.GetPersistentGameData()
		local ok, u = pcall(pgd.Unlocked, pgd, id)
		v = ok and u == true
		achUnl[id] = v
	end
	return v
end
local ASPR = {}
local function achSpr(id, path)                  -- бумажка достижения (path — своя картинка: «Закрыто» игры)
	local key = path or id
	local s = ASPR[key]
	if s == nil then
		s = false
		local root, gfx, back = "gfx/ui/achievement/", path, nil
		if not path then
			local ok, e = pcall(XMLData.GetEntryById, XMLNode.ACHIEVEMENT, id)
			if ok and e and e.gfx then root, gfx, back = e.gfxroot or root, e.gfx, e.gfxback end
		end
		if gfx then
			s = Sprite()
			s:Load("gfx/ui/achievement/achievements.anm2", false)
			local img = path and gfx or (root .. gfx)
			-- русская игра — русская картинка игры, если есть (ru_images.lua: игра свой русский архив не грузит)
			img = (LOCALFIXES.RuImage and LOCALFIXES.RuImage(img)) or img
			s:ReplaceSpritesheet(3, img)
			if back and back ~= "" then s:ReplaceSpritesheet(2, root .. back) end
			s:LoadGraphics()
			s:SetFrame("Idle", 0)
		end
		ASPR[key] = s
	end
	return s or nil
end
local function drawAch(id, x, y, w, rot, path)   -- бумажка по центру (x, y) шириной w (кадр 272 × 176, опора 130; 88)
	local s = achSpr(id, path)
	if not s then return end
	local k = w / 272
	s.Scale = Vector(k, k)
	s.Rotation = rot or 0
	local p = Vector(x - 6 * k, y)
	s:RenderLayer(2, p)
	s:RenderLayer(3, p)
	s.Scale = Vector.One
	s.Rotation = 0
end
local SW = 40                                    -- марка: рамка повёрнута (бумажки достижений — горизонтальные)
local SH = SW * 205 / 246
local function stamp(id, x, y, open, rot, lift)
	rot = rot or 0
	if lift then
		art(open and "st.frame" or "st.locked", x + lift * 0.7, y + lift, SH, SW, Color(0, 0, 0, 0.35), 90 + rot)
	end
	if open then
		art("st.frame", x, y, SH, SW, nil, 90 + rot)
		drawAch(id, x, y, SW * 0.76, rot)
		if id % 3 ~= 0 then                       -- гашение — не на всех, у каждой своё
			art("st.postmark", x + SW * 0.2, y - SH * 0.1, SW * 0.62, nil, Color(1, 1, 1, 0.75), (id * 37) % 50 - 25)
		end
	else
		art("st.locked", x, y, SH, SW, nil, 90 + rot)
	end
end
local PER_ROW, ROWS = 4, 4
local SEC_MASK
function SC.drawSecrets(o)
	T = T + (LOCALFIXES.MenuDT or 1)
	secBuild()
	local A = ButtonAction
	if not SEC.on then                           -- вход: находки — заново, нажатие входа не считается
		SEC.on, achUnl = true, {}
		for _, a in ipairs({ A.ACTION_MENULEFT, A.ACTION_MENURIGHT, A.ACTION_MENUUP, A.ACTION_MENUDOWN, A.ACTION_MENULT,
			A.ACTION_MENURT }) do press(a) end
	end
	SEC_MASK = SEC_MASK or (0xFFFFFFFF & ~(1 << A.ACTION_MENULEFT) & ~(1 << A.ACTION_MENURIGHT) & ~(1 << A.ACTION_MENUUP)
		& ~(1 << A.ACTION_MENUDOWN) & ~(1 << A.ACTION_MENULT) & ~(1 << A.ACTION_MENURT))
	MenuManager.SetInputMask(SEC_MASK)
	local cats = SEC.cats
	if #cats == 0 then return end
	SEC.cat = math.max(1, math.min(#cats, SEC.cat))
	local c = cats[SEC.cat]
	-- ввод: сетка 4 × 4 на странице, страницы — подряд; LT/RT — раздел
	local n = #c.ids
	local i = SEC.pos[SEC.cat] or 1
	-- стрелки — по сетке: ряд выше/ниже в том же столбце (19.10: «управление стрелочками полноценное»)
	i = gridKeys(math.max(1, math.min(n, i)), n, PER_ROW)
	SEC.pos[SEC.cat] = i
	local dc = (press(A.ACTION_MENURT) and 1 or 0) - (press(A.ACTION_MENULT) and 1 or 0)
	if dc ~= 0 and #cats > 1 then
		SEC.cat = (SEC.cat - 1 + dc) % #cats + 1
		c = cats[SEC.cat]
		n = #c.ids
		i = SEC.pos[SEC.cat] or 1
		if MF then MF.page() end
	end
	local id = c.ids[i]
	if MF then MF.sel("secrets", SEC.cat * 100000 + i) end
	local wob = MF and MF.wob("secrets", SEC.cat * 100000 + i) or 0
	art(ART.bg_game and "bg_game" or "bg_wall", o.X + 240, o.Y + 135, 494, 284, nil, 0, nil, nil, true)
	if MF then MF.run("sec_back", o, { dust = 4, moth = 0.0008 }) end
	-- страница кляссера
	local PH = 230
	local PW = PH * 633 / 730
	local px, py = o.X + 118, o.Y + 145
	local left, top = px - PW / 2, py - PH / 2
	art("st.page", px, py, PW, PH)
	local per = PER_ROW * ROWS
	local page = (i - 1) // per
	local pages = math.max(1, math.ceil(n / per))
	text(c.tag .. ("  %d / %d"):format(i, n), px, top + 22, "gS", Color(0.86, 0.84, 0.8, 0.9), "c")
	local STRIP = { 0.216, 0.426, 0.634, 0.845 }
	local x0, xw = left + PW * 0.062, PW * (0.943 - 0.062)
	local stepX = xw / PER_ROW
	local selX, selY
	for r = 0, ROWS - 1 do
		for col = 0, PER_ROW - 1 do
			local k = page * per + r * PER_ROW + col + 1
			local aid = c.ids[k]
			if aid then
				local x = x0 + stepX * (col + 0.5)
				local y = top + PH * STRIP[r + 1] - 4
				if k == i then
					selX, selY = x, y
				else
					stamp(aid, x, y, achOpen(aid), ((aid * 13) % 7 - 3) * 0.6)
				end
			end
		end
	end
	if selX then                                 -- выбранная — приподнята пинцетом
		local bob = math.sin(T * 0.09) * 0.7
		stamp(id, selX, selY - 3 + bob, achOpen(id), -2 + wob * 3, 2)
		art("st.tweezers", selX + 20, selY - 16 + bob, 46, nil, nil, -32)
	end
	if pages > 1 then
		text(("СТР. %d ИЗ %d"):format(page + 1, pages), px, top + PH - 6, "gT", Color(0.8, 0.78, 0.74, 0.85), "c")
	end
	-- закладки разделов справа от страницы
	local TABS = { "st.tab_red", "st.tab_green", "st.tab_blue" }
	local ty0 = o.Y + 44
	local tstep = math.min(26, 200 / math.max(1, #cats))
	for k, cc in ipairs(cats) do
		local on = k == SEC.cat
		local tx = left + PW + (on and 14 or 9)
		local tyy = ty0 + (k - 1) * tstep
		art(TABS[(k - 1) % 3 + 1], tx, tyy, 19, 30, on and nil or Color(0.7, 0.68, 0.68, 1), 90)
		text(cc.tag, tx + 2, tyy + 2.5, HF.Fit(cc.tag, 26, { "gT" }), on and Color(1, 1, 1, 1) or Color(0.9, 0.88, 0.86, 0.85), "c")
	end
	-- карточка выбранного: бумажка крупно, лупа
	art("cs.title_banner", o.X + 362, o.Y + 20, 140, nil, nil, sway(1, 0.3))
	text("СЕКРЕТЫ", o.X + 358, o.Y + 24, "gL", INK, "c")
	local open = id and achOpen(id)
	if id then
		local cx, cy = o.X + 358, o.Y + 108
		art("st.frame", cx + 2, cy + 3, 152, 226, Color(0, 0, 0, 0.3), 90)
		art("st.frame", cx, cy, 152, 226, nil, 90)
		if open then
			drawAch(id, cx, cy, 178)
		else
			drawAch(nil, cx, cy, 178, 0, "gfx/ui/achievement/Achievement_Locked.png")
		end
		art("st.lens", cx + 96, cy + 58, 34, nil, nil, -15 + math.sin(T * 0.03) * 3)
		local y = o.Y + 200
		text(("№ %d · %s"):format(id, HF.upper(c.name)), cx - 104, y, HF.Fit(("№ %d · %s"):format(id, HF.upper(c.name)), 150, { "gT" }), SOFT)
		text(open and "ОТКРЫТО" or "ЗАКРЫТО", cx + 104, y + 1, "gM", open and Color(0.92, 0.3, 0.26, 1)
			or Color(0.75, 0.72, 0.7, 1), "r", nil, -4)
		local how = L.AchHow and L.AchHow(id)
		if how then
			y = y + 12
			text("КАК ОТКРЫТЬ:", cx - 104, y, "gT", SOFT)
			for _, l in ipairs(HF.Wrap(how, "gT", 208, 3)) do
				y = y + 8
				text(l, cx - 104, y, "gT", Color(0.92, 0.88, 0.82, 1))
			end
		end
		local on = 0
		for _, aid in ipairs(c.ids) do if achOpen(aid) then on = on + 1 end end
		text(("В РАЗДЕЛЕ ОТКРЫТО %d ИЗ %d"):format(on, n), cx, o.Y + 252, "gT", Color(0.86, 0.82, 0.76, 0.9), "c")
	end
	if MF then MF.run("sec", o) end
	local h = { { "arrows", "Выбор" } }
	if #cats > 1 then h[#h + 1] = { "X C", "Раздел" } end
	h[#h + 1] = { "Esc", "Назад" }
	CS.hints(o, h)
end
LFMOD:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER, function()
	if SEC.on and not (MenuManager.GetActiveMenu() == MainMenuType.STATS and StatsMenu.IsSecretsMenuVisible
		and StatsMenu.IsSecretsMenuVisible()) then
		SEC.on = false
		MenuManager.SetInputMask(0xFFFFFFFF)
	end
end)

-- ------------------------------------------------------------------ бестиарий (MainMenuType.BESTIARY)
-- 18.10, выбор пользователя: «Полевой журнал» — сетка монстров (их спрайты из игры), карточка с живым монстром,
-- встречено/убито; план: «убрать розовые служебные подписи». У игры кто стоит на какой клетке, Lua не узнать (есть
-- только спрайт выбранного), а порядок её списка по XML не повторяется — поэтому список и выбор свои (как у «Секретов»):
-- враги (тип 10–999) игры, кроме bestiary="false", и модов, у которых бестиарий отмечен (bestiary="true" или узел
-- <bestiary>), по типу и варианту; монстры и боссы — отдельно. Стрелки у игры закрыты маской, Q/E — страницы, TAB —
-- монстры/боссы (как у игры: её листание идёт за нашим экраном), Esc — её. Имя — ключ из EntityConfig → таблица строк
-- игры («#FROWNING_GAPER» → «Хмурый Зевака»), у модов — их имя; спрайт — анимация и оверлей бестиария (EntityConfig);
-- числа — PersistentGameData (встречено, убито, «убил тебя»), ОЗ — XML.
local BEST = { tab = 1, sel = { 1, 1 }, built = false }
local function bestBuild()
	if BEST.built then return end
	BEST.built = true
	local all, seen = {}, {}
	local okN, n = pcall(XMLData.GetNumEntries, XMLNode.ENTITY)
	for i = 1, okN and n or 0 do
		local ok, e = pcall(XMLData.GetEntryByOrder, XMLNode.ENTITY, i)
		if ok and e then
			local t = tonumber(e.type) or 0
			local src = tostring(e.sourceid or "")
			local base = src == "" or src == "BaseGame"
			if t >= 10 and t < 1000 and ((base and e.bestiary ~= "false") or e.bestiary == "true" or type(e.bestiary) == "table") then
				local v = tonumber(e.variant) or 0
				local key = t .. "." .. v
				if not seen[key] then
					seen[key] = true
					all[#all + 1] = { t = t, v = v, boss = tostring(e.boss) == "1", hp = tonumber(e.basehp) or 0,
						anm = tostring(e.anm2root or "gfx/") .. tostring(e.anm2path or ""), src = (not base) and src or nil,
						xname = e.name }
				end
			end
		end
	end
	table.sort(all, function(x, y) if x.t ~= y.t then return x.t < y.t end return x.v < y.v end)
	BEST.lists = { {}, {} }
	for _, r in ipairs(all) do
		local l = BEST.lists[r.boss and 2 or 1]
		l[#l + 1] = r
	end
end
local function bestName(r)
	if r.name then return r.name end
	local nm
	local ok, c = pcall(EntityConfig.GetEntity, r.t, r.v)
	local raw = ok and c and c:GetName() or r.xname or "?"
	if tostring(raw):sub(1, 1) == "#" then
		local ok2, s2 = pcall(Isaac.GetString, "Entities", raw:sub(2))
		nm = ok2 and s2 and s2 ~= "" and s2 ~= "StringTable::InvalidKey" and s2 or raw:sub(2):gsub("_", " ")
	else
		nm = raw
	end
	r.name = plain(nm):gsub("^%s*%b()%s*", "")       -- «(IPECAC) Drooler» → «Drooler»: мод и так на карточке
	return r.name
end
local function bestCounts(r)
	local pgd = Isaac.GetPersistentGameData()
	local function g(f) local ok, v = pcall(f, pgd, r.t, r.v) return ok and tonumber(v) or 0 end
	return g(pgd.GetBestiaryEncounterCount), g(pgd.GetBestiaryKillCount), g(pgd.GetBestiaryDeathCount)
end
local BSPR = {}
local function bestSpr(r)                        -- спрайт бестиария; рамка кадра (для вписывания в клетку) — по слоям
	local key = r.t .. "." .. r.v
	local b = BSPR[key]
	if b == nil then
		b = false
		local ok, c = pcall(EntityConfig.GetEntity, r.t, r.v)
		if ok and c then
			local path = c:GetBestiaryAnm2Path()
			if not path or path == "" then path = r.anm end
			local anim = c:GetBestiaryAnimation()
			local ov = c:GetBestiaryOverlay()
			local s = Sprite()
			s:Load(path, true)
			if s:IsLoaded() then
				if not anim or anim == "" then anim = s:GetDefaultAnimation() end
				s:Play(anim, true)
				if ov and ov ~= "" then pcall(s.PlayOverlay, s, ov, true) end
				-- рамка нулевого кадра по всем слоям: где рисунок относительно точки опоры
				local x0, y0, x1, y1 = 1e9, 1e9, -1e9, -1e9
				local okA, ad = pcall(s.GetCurrentAnimationData, s)
				if okA and ad then
					for li = 0, s:GetLayerCount() - 1 do
						local okL, l = pcall(ad.GetLayer, ad, li)
						local f = okL and l and l:GetFrame(0)
						if f and f:IsVisible() then
							local pos, piv = f:GetPos(), f:GetPivot()
							local sc = f:GetScale()
							local fx, fy = pos.X - piv.X * sc.X, pos.Y - piv.Y * sc.Y
							x0, y0 = math.min(x0, fx), math.min(y0, fy)
							x1, y1 = math.max(x1, fx + f:GetWidth() * sc.X), math.max(y1, fy + f:GetHeight() * sc.Y)
						end
					end
				end
				if x1 <= x0 then x0, y0, x1, y1 = -16, -32, 16, 0 end
				local okS, bs = pcall(c.GetBestiaryScale, c)
				local okO, bo = pcall(c.GetBestiaryOffset, c)
				b = { s = s, anim = anim, ov = ov, box = { x0, y0, x1, y1 }, bs = okS and tonumber(bs) or 1, bo = okO and bo or Vector.Zero }
			end
		end
		BSPR[key] = b
	end
	return b or nil
end
local C_UNSEEN = Color(0, 0, 0, 0.55, 0.35, 0.32, 0.33)
local function bestDraw(r, cx, cy, w, h, seen, frame0)   -- вписать спрайт в рамку w × h с центром (cx, cy)
	local b = bestSpr(r)
	if not b then return end
	local bw, bh = b.box[3] - b.box[1], b.box[4] - b.box[2]
	local k = math.min(w / math.max(1, bw), h / math.max(1, bh), 1.9)
	local s = b.s
	if frame0 then
		s:SetFrame(b.anim, 0)
		if b.ov and b.ov ~= "" then pcall(s.SetOverlayFrame, s, b.ov, 0) end
	end
	s.Scale = Vector(k, k)
	s.Color = seen and Color.Default or C_UNSEEN     -- не встречен — тёмный силуэт карандашом
	local mx, my = (b.box[1] + b.box[3]) / 2, (b.box[2] + b.box[4]) / 2
	s:Render(Vector(cx - mx * k, cy - my * k))
	s.Color = Color.Default
	s.Scale = Vector.One
end
local bestImg, bestImgW, bestImgH
local BCOLS, BROWS = 3, 4
local function bestGrid(list, page, sel, gx, gy, cw, chh, z)
	for i = 0, BCOLS * BROWS - 1 do
		local idx = page * BCOLS * BROWS + i + 1
		local r = list[idx]
		if r then
			local cx = (gx + (i % BCOLS) * cw) * z
			local cy = (gy + (i // BCOLS) * chh) * z
			local on = idx == sel
			art("jo.corners", cx, cy - 4 * z, (cw - 10) * z, (chh - 16) * z, on and Color(0.85, 0.3, 0.28, 1) or nil)
			local enc = bestCounts(r)
			if enc > 0 then
				bestDraw(r, cx, cy - 4 * z, (cw - 18) * z, (chh - 24) * z, true, true)
			else
				text("?", cx, cy + 1 * z, "gL", Color(0.45, 0.4, 0.42, 0.8), "c", z)
			end
			local nm = enc > 0 and HF.upper(bestName(r)) or "???"
			text(nm, cx, cy + (chh / 2 - 3) * z, HF.Fit(nm, cw - 4, { "gT" }), INK, "c", z)
		end
	end
end
local BEST_MASK
local function drawBestiary(o)
	T = T + (LOCALFIXES.MenuDT or 1)
	bestBuild()
	local A = ButtonAction
	if not BEST.on then
		BEST.on = true
		for _, a in ipairs({ A.ACTION_MENULEFT, A.ACTION_MENURIGHT, A.ACTION_MENUUP, A.ACTION_MENUDOWN, A.ACTION_MENUTAB,
			A.ACTION_BOMB, A.ACTION_PILLCARD }) do press(a) end
		BEST.key = nil
	end
	BEST_MASK = BEST_MASK or (0xFFFFFFFF & ~(1 << A.ACTION_MENULEFT) & ~(1 << A.ACTION_MENURIGHT) & ~(1 << A.ACTION_MENUUP)
		& ~(1 << A.ACTION_MENUDOWN))
	MenuManager.SetInputMask(BEST_MASK)
	if press(A.ACTION_MENUTAB) then BEST.tab = 3 - BEST.tab end
	local list = BEST.lists[BEST.tab]
	local n = #list
	local per = BCOLS * BROWS
	local sel = math.max(1, math.min(n, BEST.sel[BEST.tab] or 1))
	if n > 0 then
		-- стрелки — по сетке: ряд выше/ниже в том же столбце (19.10: «управление стрелочками полноценное»); Q/E — страница
		sel = gridKeys(sel, n, BCOLS)
		if press(A.ACTION_BOMB) then sel = math.min(n, (((sel - 1) // per) + 1) * per + 1) end
		if press(A.ACTION_PILLCARD) then sel = math.max(1, (((sel - 1) // per) - 1) * per + 1) end
	end
	BEST.sel[BEST.tab] = sel
	if MF then MF.sel("bestiary", BEST.tab * 100000 + sel) end
	art(ART.bg_game and "bg_game" or "bg_wall", o.X + 240, o.Y + 135, 494, 284, nil, 0, nil, nil, true)
	if MF then MF.run("best_back", o, { dust = 4, moth = 0.0012 }) end
	-- журнал
	local BW = 412
	local k = BW / 696
	local bx, by = o.X + 236, o.Y + 136
	local left, top = bx - BW / 2, by - 428 * k / 2
	-- закладки «монстры» / «боссы» — из-под правой обложки
	local tabs = { { "jo.tab_red", "МОНСТРЫ" }, { "jo.tab_purple", "БОССЫ" } }
	for ti, tb in ipairs(tabs) do                -- закладка — из-под обложки, видна её часть справа от блокнота
		local on = ti == BEST.tab
		art(tb[1], left + BW + (on and 6 or 2), top + 46 + (ti - 1) * 36, 22, 52, on and nil or Color(0.72, 0.7, 0.7, 1), -90)
	end
	art("jo.book", bx, by, BW)
	for ti, tb in ipairs(tabs) do                -- подпись — поверх, в видимой части закладки
		local on = ti == BEST.tab
		local tx = left + BW + (on and 18 or 14)
		text(tb[2], tx, top + 48 + (ti - 1) * 36, HF.Fit(tb[2], 30, { "gT" }), Color(1, 1, 1, on and 1 or 0.8), "c")
	end
	art("jo.clip", left + 70 * k + 20, top + 14, 16, nil, nil, 20)
	-- левая страница: 12 образцов
	local pl, pr = left + 50 * k, left + 340 * k
	local pt = top + 20 * k
	local page = (sel - 1) // per
	local pages = math.max(1, math.ceil(n / per))
	text(BEST.tab == 1 and "МОНСТРЫ" or "БОССЫ", (pl + pr) / 2, pt + 16, "gL", INK, "c")
	text(("СТР. %d ИЗ %d"):format(page + 1, pages), (pl + pr) / 2, top + 361 * k, "gS", INK, "c")   -- над обрезом страниц
	local cw = (pr - pl) / BCOLS
	local chh = 42
	local gx, gy = pl + cw / 2, pt + 44
	local canImg = Renderer and Renderer.RenderToImage and Renderer.CreateImage and SourceQuad and DestinationQuad
	if canImg and not L.gridOff then
		local sw, sh = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
		local z = Isaac.GetScreenPointScale and Isaac.GetScreenPointScale() or 1
		local W, H = math.floor(sw * z + 0.5), math.floor(sh * z + 0.5)
		if not bestImg or bestImgW ~= W or bestImgH ~= H then
			local okI, img = pcall(Renderer.CreateImage, W, H, "localfixes_bestiary_" .. W .. "x" .. H)
			bestImg = okI and img or nil
			bestImgW, bestImgH, BEST.key = W, H, nil
		end
		local key = BEST.tab .. ":" .. page .. ":" .. sel .. ":" .. math.floor(o.X * 8) .. ":" .. math.floor(o.Y * 8) .. ":" .. z
		if bestImg and key ~= BEST.key then
			local okR = pcall(Renderer.RenderToImage, bestImg, function(ctl)
				ctl:Clear()
				bestGrid(list, page, sel, gx, gy, cw, chh, z)
			end)
			BEST.key = okR and key or nil
		end
		if bestImg and BEST.key then
			SRCQ = SRCQ or SourceQuad.NewFromBounds(Vector(0, 0), Vector(1, 1), true)
			bestImg:Render(SRCQ, DestinationQuad.NewFromBounds(Vector(0, 0), Vector(sw, sh)), KColor(1, 1, 1, 1))
		else
			bestGrid(list, page, sel, gx, gy, cw, chh, 1)
		end
	else
		bestGrid(list, page, sel, gx, gy, cw, chh, 1)
	end
	-- правая страница: живой образец и записи
	local r = list[sel]
	local rl, rr = left + 355 * k, left + 655 * k
	local rc = (rl + rr) / 2
	if r then
		local enc, kills, deaths = bestCounts(r)
		local seen = enc > 0
		local b = seen and bestSpr(r)
		if b then
			if (LOCALFIXES.MenuDT or 1) > 0 and T % 2 == 0 then
				b.s:Update()
				if b.s:IsFinished(b.anim) then b.s:Play(b.anim, true) end
			end
			bestDraw(r, rc, pt + 52, 120, 72, true, false)
		else
			text("?", rc, pt + 62, "gX", Color(0.45, 0.4, 0.42, 0.85), "c")
		end
		local nm = seen and HF.upper(bestName(r)) or "???"
		text(nm, rc, pt + 108, HF.Fit(nm, rr - rl - 10, { "gL", "gM", "gS" }), BLACK, "c")
		local y = pt + 122
		local lines = seen and {
			{ "ОЗ", tostring(math.floor(r.hp + 0.5)) },
			{ "ВСТРЕЧЕНО", tostring(enc) },
			{ "УБИТО", tostring(kills) },
			{ "УБИЛ ТЕБЯ", tostring(deaths) },
		} or { { "ЕЩЁ НЕ ВСТРЕЧЕН", "" } }
		for _, ln in ipairs(lines) do
			text(ln[1], rl + 18, y, "gS", SOFT)
			text(ln[2], rr - 16, y, "gS", INK, "r")
			y = y + 11
		end
		if r.src then
			local m = modOf(r.src)
			local t2 = "МОД " .. HF.upper(m.name)
			if m.hd then hdThumb(m.hd, false, rl + 22, y + 6, 10) end
			text(t2, rl + 30, y + 8, HF.Fit(t2, rr - rl - 40, { "gT" }), SOFT)
		end
		art("jo.pencil", rr - 18, top + 380 * k, 34, nil, nil, -25)
	end
	if MF then MF.run("best", o) end
	CS.hints(o, { { "arrows", "Выбор" }, { "Q E", "Страница" }, { "Tab", "Монстры / боссы" }, { "Esc", "Назад" } })
end
SC.Register(MainMenuType.BESTIARY, drawBestiary, true)

-- ------------------------------------------------------------------ онлайн-награды (MainMenuType.ONLINEAWARDS, «Sins!»)
-- 18.10, выбор пользователя: «Список грехов» — лист «Грехи!» с наградами и счётчиками, записка «с модами онлайн
-- недоступен». У игры 21 награда (3 столбца по 7), открываются в онлайн-забегах; с модами онлайн закрыт — у игры все
-- «??????» и 0 (Lua-доступа к этому меню нет). Выбирать нечего — курсора нет; Esc — назад (игра).
local function drawSins(o)
	T = T + (LOCALFIXES.MenuDT or 1)
	art(ART.bg_game and "bg_game" or "bg_wall", o.X + 240, o.Y + 135, 494, 284, nil, 0, nil, nil, true)
	if MF then MF.run("sins_back", o, { dust = 4, embers = 1, moth = 0.0008 }) end
	local cx, cy = o.X + 198, o.Y + 140
	art(ART["hd.note_wide"] and "hd.note_wide" or "ma.note_wide", cx, cy, 312, 246, nil, sway(4, 0.2))
	text("ГРЕХИ!", cx, cy - 72, "gX", BLOODC, "c")
	art("ma.highlight", cx, cy - 64, 120, 4, Color(0.45, 0.06, 0.06, 0.85))
	for c = 0, 2 do
		for r = 0, 6 do
			local x = cx - 122 + c * 88
			local y = cy - 44 + r * 15
			text("??????", x, y, "gS", DISABLED)
			text("0", x + 72, y, "gS", DISABLED, "r")
		end
	end
	text("??????", cx, cy + 74, "gM", DISABLED, "c")
	-- записка: почему всё закрыто
	art(ART["hd.note_sq"] and "hd.note_sq" or "ma.note_pin", o.X + 418, o.Y + 112, 112, 122, nil, sway(9, 0.6))
	local lines = HF.Wrap("С модами онлайн недоступен: грехи открываются в онлайн-забегах без модов.", "gT", 88, 6)
	for i, l in ipairs(lines) do text(l, o.X + 418, o.Y + 100 + (i - 1) * 8, "gT", INK, "c") end
	art("cs.title_banner", o.X + 412, o.Y + 22, 130, nil, nil, sway(1, 0.3))
	text("НАГРАДЫ", o.X + 408, o.Y + 26, "gL", INK, "c")
	if MF then MF.run("sins", o) end
	CS.hints(o, { { "Esc", "Назад" } })
end
SC.Register(MainMenuType.ONLINEAWARDS or 22, drawSins, true)

-- ------------------------------------------------------------------ настройки (MainMenuType.OPTIONS)
-- 18.10, выбор пользователя: «Анкета-бланк» — шкалы-деления, галочки в квадратиках карандашом. Пункты и их номера —
-- как у игры (OptionsMenu.GetSelectedElement, 23 пункта; сверено с меню игры 19.10), значения — Options (меняет сама
-- игра: ←/→ и Enter; экран только показывает). Лист — длинный лист для заметок (как у испытаний), справа — записка
-- «что это» о выбранном пункте.
local OPT = {
	{ "УПРАВЛЕНИЕ", "go", nil, "Клавиши и геймпад: что на какой кнопке." },
	{ "ЗВУК", "bar", "SFXVolume", "Громкость звуков игры." },
	{ "МУЗЫКА", "bar", "MusicVolume", "Громкость музыки." },
	{ "НЕПРОЗР. КАРТЫ", "bar", "MapOpacity", "Насколько плотная миникарта в углу экрана." },
	{ "ПОЛНЫЙ ЭКРАН", "bool", "Fullscreen", "Игра на весь экран или в окне." },
	{ "ФИЛЬТР", "bool", "Filter", "Сглаживание картинки: мягче, но без чётких пикселей." },
	{ "ЯРКОСТЬ", "gamma", "Gamma", "Гамма: светлее или темнее вся картинка." },
	{ "ВИБРАЦИЯ", "bool", "RumbleEnabled", "Отдача геймпада." },
	{ "ВСПЛЫВАШКИ", "enum", "DisplayPopups", "Надписи о предметах и событиях посреди экрана.",
		{ [0] = "ВЫКЛ", "БОЛЬШИЕ", "МАЛЕНЬКИЕ" } },
	{ "АКТИВ. КАМЕРА", "enum", "CameraStyle", "Камера следует за Исааком в больших комнатах.", { "ВКЛ", "ВЫКЛ" } },
	{ "ДОП. ИНТЕРФЕЙС", "enum", "ExtraHUDStyle", "Список предметов забега сбоку экрана.",
		{ [0] = "ВЫКЛ", "ОБЫЧНЫЙ", "МИНИ" } },
	{ "СМЕСТИТЬ ИНТЕРФЕЙС", "bar", "HUDOffset", "Отступ интерфейса от краёв экрана." },
	{ "ХАРАКТЕРИСТИКИ", "bool", "FoundHUD", "Характеристики Исаака (скорость, урон, слёзы…) на экране." },
	{ "ПОЛОСА ЗАРЯДА", "bool", "ChargeBars", "Полоска заряда у оружия с накоплением." },
	{ "ВИДИМОСТЬ СЛЁЗ", "enum", "BulletVisibility", "Обводка вражеских снарядов.", { [false] = "ОБЫЧНАЯ", [true] = "СИЛЬНАЯ" } },
	{ "ИАКОВ И ИСАВ", "enum", "JacobEsauControls", "Как управлять двумя братьями.", { [0] = "КЛАССИКА", "УДОБНОЕ" } },
	{ "КООП. ИНТЕРФЕЙС", "enum", "OnlineHUD", "Интерфейс игроков в совместной игре.", { [0] = "ОБЫЧНЫЙ", "МИНИ" } },
	{ "РЕЖИМ СТРИМЕРА", "bool", "StreamerMode", "Прячет имена игроков в сетевой игре." },
	{ "ВКЛЮЧИТЬ ЧАТ", "bool", "OnlineChatEnabled", "Чат сетевой игры (с модами онлайн недоступен)." },
	{ "ЗВУК ИГРОКОВ", "bar10", "OnlinePlayerVolume", "Громкость других игроков в сетевой игре." },
	{ "НЕПРОЗР. ИГРОКОВ", "bar10", "OnlinePlayerOpacity", "Насколько видны другие игроки в сетевой игре." },
	{ "ЦВЕТА ИГРОКОВ", "num", "OnlineColorSet", "Набор цветов игроков в сетевой игре." },
	{ "ЗАДЕРЖКА ВВОДА", "bar10", "OnlineInputDelay", "Задержка ввода в сетевой игре." },
}
local function optVal(key)
	local ok, v = pcall(function() return Options[key] end)
	return ok and v or nil
end
local C_PEN = Color(0.3, 0.27, 0.28, 0.92)
local C_TICK = Color(0.16, 0.12, 0.12, 1)
local function boxes(x, y, n, filled)            -- шкала: n клеточек, закрашено filled — карандашом
	for i = 1, n do
		local bx = x + (i - 1) * 6.6
		art("al.slot", bx, y, 5.8, 6.6, Color(0.6, 0.56, 0.58, 1))
		if i <= filled then art("ma.highlight", bx, y, 5, 5, C_PEN, ((i * 37) % 9 - 4) * 4) end
	end
end
local function checkbox(x, y, on)
	art("al.slot", x, y, 7, 7.6, Color(0.6, 0.56, 0.58, 1))
	if on then art("bl.check", x + 1, y - 1.5, 10, nil, C_TICK, -8) end
end
local function drawOptions(o)
	T = T + (LOCALFIXES.MenuDT or 1)
	bg(o, "opt")
	local sel = (OptionsMenu.GetSelectedElement() or 0) + 1
	if MF then MF.sel("options", sel) end
	local wob = MF and MF.wob("options", sel) or 0
	local top, k, lines = longList(o, "opt", 170, 250, #OPT, sel, function(i, y, xn, xt, wt, on)
		local it = OPT[i]
		local dx = on and (math.sin(T * 0.12) * 1.0 + wob * 0.3) or 0
		if on then art("ma.highlight", xt + wt / 2 - 4, y - 4, wt + 14, 14, Color(1, 1, 1, 0.75)) end
		text(it[1], xt + dx, y - 5, HF.Fit(it[1], 94, { "gS", "gT" }), on and BLACK or INK)
		if on then art("ma.cursor", xn - 8 + dx, y - 6, 8) end
		local vx = xt + 100
		local v = it[3] and optVal(it[3])
		local kind = it[2]
		if kind == "go" then
			text("ОТКРЫТЬ ЛИСТ", vx, y - 5, "gT", SOFT)
		elseif kind == "bar" or kind == "bar10" then
			local f = tonumber(v) or 0
			if kind == "bar" then f = math.floor(f * 10 + 0.5) end
			boxes(vx + 4, y - 7, 10, f)
		elseif kind == "gamma" then
			local g = tonumber(v) or 1
			boxes(vx + 4, y - 7, 10, math.floor((g - 0.5) / 1.5 * 10 + 0.5))
			text(("%.2f"):format(g), vx + 72, y - 5, "gT", INK)
		elseif kind == "bool" then
			checkbox(vx + 4, y - 7, v == true)
			text("ДА", vx + 11, y - 5, "gT", INK)
			checkbox(vx + 30, y - 7, v == false)
			text("НЕТ", vx + 37, y - 5, "gT", INK)
		elseif kind == "enum" then
			local words = it[5] or {}
			local xx = vx
			local keys = {}
			for kk in pairs(words) do keys[#keys + 1] = kk end
			table.sort(keys, function(a2, b2) return tostring(a2) < tostring(b2) end)
			if type(next(words)) == "number" then table.sort(keys) end
			for _, kk in ipairs(keys) do
				local w = words[kk]
				local chosen = kk == v
				local tw = text(w, xx, y - 5, "gT", chosen and BLACK or DISABLED)
				if chosen then art("ma.highlight", xx + tw / 2, y - 1, tw + 3, 2.2, Color(0.75, 0.12, 0.12, 0.9), -2) end
				xx = xx + tw + 5
			end
		elseif kind == "num" then
			text("НАБОР " .. tostring((tonumber(v) or 0) + 1), vx, y - 5, "gT", INK)
		end
	end)
	if top then
		text("АНКЕТА", o.X + 170, top + lines[2] * k - 7, "gL", INK, "c")
	end
	art("cs.title_banner", o.X + 412, o.Y + 22, 130, nil, nil, sway(1, 0.3))
	text("НАСТРОЙКИ", o.X + 408, o.Y + 26, HF.Fit("НАСТРОЙКИ", 110, { "gL", "gM" }), INK, "c")
	-- записка «что это»
	local it = OPT[sel]
	if it then
		art(ART["hd.note_sq"] and "hd.note_sq" or "cs.notes", o.X + 412, o.Y + 116, 112, 124, nil, sway(9, 0.6))
		text(it[1], o.X + 412, o.Y + 88, HF.Fit(it[1], 92, { "gS", "gT" }), BLACK, "c")
		for i2, l in ipairs(HF.Wrap(it[4], "gT", 88, 6)) do text(l, o.X + 412, o.Y + 100 + (i2 - 1) * 8, "gT", INK, "c") end
	end
	if MF then MF.run("opt", o) end
	local h = { { "updown", "Выбор" }, { "<>", "Изменить" } }
	if sel == 1 then h[#h + 1] = { "Enter", "Открыть" } end
	h[#h + 1] = { "Esc", "Назад" }
	CS.hints(o, h)
end
SC.Register(MainMenuType.OPTIONS, drawOptions, true)

-- ------------------------------------------------------------------ пасхалки (MainMenuType.SPECIALSEEDS, Q на выборе персонажа)
-- 19.10, выбор пользователя: «Длинный лист с галочками». Список и порядок — как у игры (таблица строк SeedMenu/SEED_<n>
-- в том же порядке; группы — через пустую строку, как в её списке; сверено снимками), «Подтвердить (N)» и «Отменить
-- все» сверху. Включённые игра хранит в MenuManager.GetSeeds() (проверено) — экран включает их сам: Enter —
-- Add/RemoveSeedEffect (запрещённое сочетание — IsSeedComboBanned: не включается), «Отменить все» — ClearSeedEffects,
-- «Подтвердить» — назад к выбору персонажа. Выбор игры в REPENTOGON 1.1.3 не читается (SpecialSeedsMenu
-- .GetSelectedElement отдаёт мусор) — выбор свой, стрелки и Enter у игры закрыты; Esc — её (назад).
local SEED_GROUPS = {
	{ 16, 11, 72, 33, 25, 32, 71, 24, 73, 55 }, { 56, 57, 58, 59, 60, 61, 62 }, { 63, 64, 65, 66, 67, 68, 70 },
	{ 47, 48, 26, 27, 28 }, { 52, 74, 75, 12, 76 }, { 3, 4, 5, 6, 14, 15 }, { 46, 53, 54, 35, 36, 37 }, { 38, 23 },
	{ 8, 9, 10, 29, 30 }, { 13, 17, 18, 19, 20, 21 }, { 7 }, { 1, 2, 41, 42, 43, 44 },
}
-- значок у пасхалки в списке игры (перечёркнутый круг): с ней достижения не открываются (по снимкам её списка)
local SEED_NOACH = {}
for _, e in ipairs({ 16, 11, 33, 25, 32, 24, 73, 55, 57, 63, 64, 65, 66, 67, 68, 70, 38, 13, 17, 18, 19, 20, 21 }) do
	SEED_NOACH[e] = true
end
local SEEDROWS
local function seedRows()
	if SEEDROWS then return SEEDROWS end
	SEEDROWS = { { kind = "confirm" }, { kind = "reset" } }
	for _, g in ipairs(SEED_GROUPS) do
		SEEDROWS[#SEEDROWS + 1] = { kind = "gap" }
		for _, e in ipairs(g) do SEEDROWS[#SEEDROWS + 1] = { kind = "seed", e = e } end
	end
	return SEEDROWS
end
local seedNames = {}
local function seedName(e)
	local n = seedNames[e]
	if not n then
		local ok, str
		if Isaac.GetLocalizedString then                -- строка игры на языке нашего текста (как имена персонажей)
			ok, str = pcall(Isaac.GetLocalizedString, "SeedMenu", "SEED_" .. e, HF.Lang())
		end
		if not (ok and str and str ~= "" and str ~= "StringTable::InvalidKey") then
			ok, str = pcall(Isaac.GetString, "SeedMenu", "SEED_" .. e)
		end
		n = (ok and str and str ~= "" and str ~= "StringTable::InvalidKey") and plain(str) or ("ПАСХАЛКА " .. e)
		seedNames[e] = n
	end
	return n
end
local function seedsObj()
	local ok, sd = pcall(MenuManager.GetSeeds)
	return ok and sd or nil
end
local SEED = { sel = 1 }
local SEED_MASK
local sfx = SFXManager()
local function drawSeeds(o)
	T = T + (LOCALFIXES.MenuDT or 1)
	local A = ButtonAction
	local rows = seedRows()
	if not SEED.on then
		SEED.on, SEED.sel = true, 1
		for _, a2 in ipairs({ A.ACTION_MENUUP, A.ACTION_MENUDOWN, A.ACTION_MENUCONFIRM }) do press(a2) end
	end
	SEED_MASK = SEED_MASK or (0xFFFFFFFF & ~(1 << A.ACTION_MENUUP) & ~(1 << A.ACTION_MENUDOWN) & ~(1 << A.ACTION_MENUCONFIRM)
		& ~(1 << A.ACTION_MENULEFT) & ~(1 << A.ACTION_MENURIGHT))
	MenuManager.SetInputMask(SEED_MASK)
	local sd = seedsObj()
	-- ввод: ↑/↓ — по строкам (пустые пропускаются), Enter — действие
	local function step(d)
		local i = SEED.sel
		repeat i = (i - 1 + d) % #rows + 1 until rows[i].kind ~= "gap"
		SEED.sel = i
	end
	if press(A.ACTION_MENUDOWN) then step(1) end
	if press(A.ACTION_MENUUP) then step(-1) end
	if press(A.ACTION_MENUCONFIRM) and sd then
		local r = rows[SEED.sel]
		if r.kind == "confirm" then
			sfx:Play(SoundEffect.SOUND_BOOK_PAGE_TURN_12, 1, 0, false, 1)
			MenuManager.SetActiveMenu(MainMenuType.CHARACTER)
		elseif r.kind == "reset" then
			pcall(sd.ClearSeedEffects, sd)
			sfx:Play(SoundEffect.SOUND_PAPER_OUT, 1, 0, false, 1)
		elseif r.kind == "seed" then
			if sd:HasSeedEffect(r.e) then
				sd:RemoveSeedEffect(r.e)
				sfx:Play(SoundEffect.SOUND_PAPER_OUT, 0.8, 0, false, 1.1)
			else
				local okC, can = pcall(sd.CanAddSeedEffect, sd, r.e)
				if not okC or can ~= false then sd:AddSeedEffect(r.e) end
				local okB, banned = pcall(sd.IsSeedComboBanned, sd)
				if (okC and can == false) or (okB and banned) then
					if sd:HasSeedEffect(r.e) then sd:RemoveSeedEffect(r.e) end
					sfx:Play(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.6, 0, false, 1.2)
				else
					sfx:Play(SoundEffect.SOUND_PAPER_IN, 0.8, 0, false, 1)
				end
			end
		end
	end
	local count = sd and sd:CountSeedEffects() or 0
	if MF then MF.sel("seeds", SEED.sel) end
	local wob = MF and MF.wob("seeds", SEED.sel) or 0
	bg(o, "seeds")
	local TQ = {}
	local top, k, lines = longList(o, "seeds", 140, 220, #rows, SEED.sel, function(i, y, xn, xt, wt, on)
		local r = rows[i]
		if r.kind == "gap" then return end
		local dx = on and (math.sin(T * 0.12) * 1.0 + wob * 0.3) or 0
		if on then art("ma.highlight", xt + wt / 2 - 4, y - 4, wt + 14, 14, Color(1, 1, 1, 0.75)) end
		if on then art("ma.cursor", xn - 8 + dx, y - 6, 8) end
		if r.kind == "confirm" then
			TQ[#TQ + 1] = { ("ПОДТВЕРДИТЬ (%d)"):format(count), xt + dx, y - 5, "gS", on and BLACK or INK }
		elseif r.kind == "reset" then
			TQ[#TQ + 1] = { "ОТМЕНИТЬ ВСЕ", xt + dx, y - 5, "gS", count > 0 and (on and BLACK or INK) or DISABLED }
		else
			local onE = sd and sd:HasSeedEffect(r.e)
			checkbox(xt + 3 + dx, y - 7, onE)
			local nm = HF.upper(seedName(r.e))
			local size = HF.Fit(nm, wt - 30, { "gS", "gT" })
			TQ[#TQ + 1] = { nm, xt + 12 + dx, y - 5, size, onE and BLACK or (on and BLACK or INK) }
			if SEED_NOACH[r.e] then
				local tw = HF.Width(nm, size)
				art("ma.i_trophy", xt + 12 + tw + 8 + dx, y - 7, 8, nil, Color(0.5, 0.45, 0.45, 0.9))
				art("ma.highlight", xt + 12 + tw + 8 + dx, y - 7, 10, 1.6, Color(0.7, 0.12, 0.12, 0.95), -40)
			end
		end
	end)
	for _, q in ipairs(TQ) do text(q[1], q[2], q[3], q[4], q[5]) end
	if top then text("ПАСХАЛКИ", o.X + 140, top + lines[2] * k - 7, "gL", INK, "c") end
	-- записка о выбранной
	art("cs.title_banner", o.X + 392, o.Y + 22, 130, nil, nil, sway(1, 0.3))
	text("ОСОБЫЕ СИДЫ", o.X + 388, o.Y + 26, HF.Fit("ОСОБЫЕ СИДЫ", 110, { "gL", "gM" }), INK, "c")
	local r = rows[SEED.sel]
	art(ART["hd.note_sq"] and "hd.note_sq" or "cs.notes", o.X + 392, o.Y + 122, 130, 146, nil, sway(9, 0.6))
	local cx, y = o.X + 392, o.Y + 92
	if r.kind == "seed" then
		local nm = HF.upper(seedName(r.e))
		for i2, l in ipairs(HF.Wrap(nm, "gM", 108, 2)) do text(l, cx, y + (i2 - 1) * 11, "gM", BLACK, "c") end
		y = y + 26
		local onE = sd and sd:HasSeedEffect(r.e)
		text(onE and "ВКЛЮЧЕНА" or "ВЫКЛЮЧЕНА", cx, y, "gS", onE and BLOODC or SOFT, "c", nil, -3)
		y = y + 14
		if SEED_NOACH[r.e] then
			for i2, l in ipairs(HF.Wrap("С этой пасхалкой достижения не открываются.", "gT", 104, 3)) do
				text(l, cx, y + (i2 - 1) * 8, "gT", INK, "c")
			end
		end
	elseif r.kind == "confirm" then
		text("ГОТОВО", cx, y, "gM", BLACK, "c")
		for i2, l in ipairs(HF.Wrap("Вернуться к выбору персонажа: включённые пасхалки будут в забеге.", "gT", 104, 4)) do
			text(l, cx, y + 16 + (i2 - 1) * 8, "gT", INK, "c")
		end
	else
		text("СБРОС", cx, y, "gM", BLACK, "c")
		for i2, l in ipairs(HF.Wrap("Выключить все пасхалки сразу.", "gT", 104, 3)) do
			text(l, cx, y + 16 + (i2 - 1) * 8, "gT", INK, "c")
		end
	end
	text(("ВКЛЮЧЕНО: %d"):format(count), cx, o.Y + 186, "gS", count > 0 and BLOODC or SOFT, "c")
	if MF then MF.run("seeds", o) end
	CS.hints(o, { { "updown", "Выбор" }, { "Enter", "Вкл / выкл" }, { "Esc", "Назад" } })
end
SC.Register(MainMenuType.SPECIALSEEDS, drawSeeds, true)
LFMOD:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER, function()
	if SEED.on and MenuManager.GetActiveMenu() ~= MainMenuType.SPECIALSEEDS then
		SEED.on = false
		MenuManager.SetInputMask(0xFFFFFFFF)
	end
end)

-- ------------------------------------------------------------------ управление (CONTROLS) и клавиши (KEYCONFIG)
-- 18.10, выбор пользователя: «Схема с выносками» — клавиатура/геймпад от руки, к действиям — выноски. Список устройств и
-- строк — как у игры (ControllerSelectMenu / KeyConfigMenu: строка и столбец, правку ведёт игра — Enter, новая клавиша).
-- Какая клавиша на каком действии: Input.GetActionButtons (REPENTOGON новее 1.1.3); в 1.1.3 его нет — раскладка по
-- умолчанию (сверена с меню игры 19.10) и переназначения, которые экран сам видит в режиме правки (новая нажатая
-- клавиша, хранится в данных мода: «kb=строка.столбец.клавиша,…;»); «По умолчанию» сбрасывает. Геймпад без
-- GetActionButtons — привязок не узнать: на экране клавиш остаётся родной список игры.
local KC_ROWS = {   -- строка меню игры → действие, подпись, клавиша по умолчанию
	{ 2, "ИДТИ ВВЕРХ", 87 }, { 3, "ИДТИ ВНИЗ", 83 }, { 0, "ИДТИ ВЛЕВО", 65 }, { 1, "ИДТИ ВПРАВО", 68 },
	{ 6, "СТРЕЛЯТЬ ВВЕРХ", 265 }, { 7, "СТРЕЛЯТЬ ВНИЗ", 264 }, { 4, "СТРЕЛЯТЬ ВЛЕВО", 263 }, { 5, "СТРЕЛЯТЬ ВПРАВО", 262 },
	{ 8, "БОМБА", 69 }, { 9, "ПРЕДМЕТ", 32 }, { 10, "ПИЛЮЛЯ / КАРТА", 81 }, { 11, "БРОСИТЬ", 341 }, { 13, "КАРТА", 258 },
	{ 30, "ЭМОЦИИ", 342 }, { 16, "ПОЛНЫЙ ЭКРАН", 70 }, { 18, "РЕСТАРТ", 82 }, { 17, "БЕЗ ЗВУКА", 77 }, { 12, "ПАУЗА", 80 },
}
local KEYNAME = { [32] = "ПРОБЕЛ", [39] = "'", [44] = ",", [45] = "-", [46] = ".", [47] = "/", [59] = ";", [61] = "=",
	[91] = "[", [92] = "", [93] = "]", [96] = "Ё", [256] = "ESC", [257] = "ENTER", [258] = "TAB", [259] = "BKSP",
	[262] = "ВПРАВО", [263] = "ВЛЕВО", [264] = "ВНИЗ", [265] = "ВВЕРХ", [280] = "CAPS", [340] = "SHIFT", [341] = "CTRL", [342] = "ALT",
	[343] = "WIN", [344] = "SHIFT", [345] = "CTRL", [346] = "ALT", [348] = "MENU" }
local function keyLabel(k)
	if type(k) ~= "number" or k < 0 then return nil end
	if KEYNAME[k] then return KEYNAME[k] end
	if (k >= 65 and k <= 90) or (k >= 48 and k <= 57) then return string.char(k) end
	if k >= 290 and k <= 301 then return "F" .. (k - 289) end
	return "#" .. k
end
-- схема клавиатуры: { клавиша, ширина в клетках }, ряды сверху вниз; 0 — пустой промежуток
local KB_ROWS = {
	{ { 96, 1 }, { 49, 1 }, { 50, 1 }, { 51, 1 }, { 52, 1 }, { 53, 1 }, { 54, 1 }, { 55, 1 }, { 56, 1 }, { 57, 1 },
		{ 48, 1 }, { 45, 1 }, { 61, 1 }, { 259, 2 } },
	{ { 258, 1.5 }, { 81, 1 }, { 87, 1 }, { 69, 1 }, { 82, 1 }, { 84, 1 }, { 89, 1 }, { 85, 1 }, { 73, 1 }, { 79, 1 },
		{ 80, 1 }, { 91, 1 }, { 93, 1 }, { 92, 1.5 } },
	{ { 280, 1.75 }, { 65, 1 }, { 83, 1 }, { 68, 1 }, { 70, 1 }, { 71, 1 }, { 72, 1 }, { 74, 1 }, { 75, 1 }, { 76, 1 },
		{ 59, 1 }, { 39, 1 }, { 257, 2.25 } },
	{ { 340, 2.25 }, { 90, 1 }, { 88, 1 }, { 67, 1 }, { 86, 1 }, { 66, 1 }, { 78, 1 }, { 77, 1 }, { 44, 1 }, { 46, 1 },
		{ 47, 1 }, { 344, 2.75 } },
	{ { 341, 1.25 }, { 343, 1.25 }, { 342, 1.25 }, { 32, 6.25 }, { 346, 1.25 }, { 348, 1.25 }, { 345, 1.25 } },
}
local KB_ARROWS = { { 265, 1, 3 }, { 263, 0, 4 }, { 264, 1, 4 }, { 262, 2, 4 } }   -- клавиша, столбец, ряд (справа)
local kbData
local function kbLoad()
	if kbData then return kbData end
	kbData = {}
	local ok, d = pcall(function() return LFMOD:HasData() and LFMOD:LoadData() or "" end)
	local f = ok and type(d) == "string" and d:match("kb=([%d%.,]*);") or ""
	for r, c, k in f:gmatch("(%d+)%.(%d+)%.(%d+)") do
		kbData[tonumber(r) .. "." .. tonumber(c)] = tonumber(k)
	end
	return kbData
end
local function kbSave()
	local parts = {}
	for key, k in pairs(kbData or {}) do parts[#parts + 1] = key .. "." .. k end
	table.sort(parts)
	pcall(function()
		local m = LFMOD
		local d = m:HasData() and m:LoadData() or ""
		d = d:gsub("kb=[%d%.,]*;", "")
		m:SaveData(d .. "kb=" .. table.concat(parts, ",") .. ";")
	end)
end
local function binding(row, col, dev)              -- клавиша (или кнопка) действия строки row в столбце col
	local def = KC_ROWS[row + 1]
	if not def then return nil end
	if Input.GetActionButtons then
		local ok, b1, b2 = pcall(Input.GetActionButtons, def[1], dev or 0)
		if ok then
			local v = (col == 0) and b1 or b2
			return (v and v >= 0) and v or nil, true
		end
	end
	if (dev or 0) ~= 0 then return nil, false end
	local t = kbLoad()[row .. "." .. col]
	if t then return t >= 0 and t or nil, false end
	if col == 0 then return def[3], false end
	return nil, false
end
-- правка без GetActionButtons: смотрим, какую клавишу нажмут, пока игра ждёт новую
local kc = { edit = false }
local KEYS
local function kcWatch(row, col)
	local editing = KeyConfigMenu.IsEditActive and KeyConfigMenu.IsEditActive()
	if Input.GetActionButtons then kc.edit = editing return end
	if editing then
		if not kc.edit then
			kc.edit, kc.row, kc.col, kc.got = true, row, col, nil
			kc.held = {}
			KEYS = KEYS or (function() local t = {} for _, v in pairs(Keyboard) do t[#t + 1] = v end return t end)()
			for _, k in ipairs(KEYS) do kc.held[k] = Input.IsButtonPressed(k, 0) end
		end
		for _, k in ipairs(KEYS) do
			local p = Input.IsButtonPressed(k, 0)
			if p and not kc.held[k] and not kc.got then kc.got = k end
			kc.held[k] = p
		end
	elseif kc.edit then
		kc.edit = false
		if not kc.got then                        -- игра закончила правку в том же кадре: клавиша ещё нажата
			for _, k in ipairs(KEYS) do
				if Input.IsButtonPressed(k, 0) and k ~= Keyboard.KEY_ENTER and not kc.held[k] then kc.got = k break end
			end
		end
		if kc.got and kc.got ~= Keyboard.KEY_ESCAPE then
			kbLoad()[kc.row .. "." .. kc.col] = kc.got
			kbSave()
		end
	end
end
-- клавиатура: x, y — левый верх, u — клетка; hot[k] — подсветка; boxes — куда класть центры клавиш (для выносок)
local C_KEYHOT = Color(1, 0.62, 0.58, 1)
local C_KEYSEL = Color(1, 0.38, 0.34, 1)
-- отрисовка — двумя проходами: сначала все клавиши (атлас меню), потом все подписи (атлас шрифта): по очереди
-- «клавиша — подпись» видеокарта переключала текстуры сотни раз за кадр (19.10: экран клавиш — 60 к/с)
local ARR = { [265] = 0, [262] = 90, [264] = 180, [263] = -90 }   -- стрелки — треугольником (в шрифте их нет)
local function drawKeyboard(x, y, u, hot, centers)
	local h = u * 0.92
	local keys = {}
	for r, row in ipairs(KB_ROWS) do
		local kx = x
		for _, kd in ipairs(row) do
			keys[#keys + 1] = { kd[1], kx, y + (r - 1) * u, kd[2] }
			kx = kx + kd[2] * u
		end
	end
	local ax = x + 15.4 * u
	for _, a2 in ipairs(KB_ARROWS) do keys[#keys + 1] = { a2[1], ax + a2[2] * u, y + a2[3] * u, 1 } end
	for _, kd in ipairs(keys) do                 -- проход 1: клавиши и треугольники стрелок
		local k, kx, ky, w = kd[1], kd[2], kd[3], kd[4]
		local ww = w * u - u * 0.08
		local piece = w <= 1.3 and "cs.key1" or (w <= 2.3 and "cs.key2" or "cs.key3")
		local c = hot[k]
		art(piece, kx + ww / 2, ky + h / 2, ww, h, c == 2 and C_KEYSEL or (c == 1 and C_KEYHOT) or nil)
		if ARR[k] then art("cs.tri_up", kx + ww / 2, ky + h / 2, u * 0.32, nil, c and BLACK or SOFT, ARR[k]) end
		centers[k] = { kx + ww / 2, ky + h / 2 }
		kd[5] = ww
	end
	for _, kd in ipairs(keys) do                 -- проход 2: подписи
		local k = kd[1]
		local lbl = not ARR[k] and keyLabel(k)
		if lbl and lbl ~= "" then
			text(lbl, kd[2] + kd[5] / 2, kd[3] + h / 2 + 2.2, HF.Fit(lbl, kd[5] - 2, { "gT" }), hot[k] and BLACK or SOFT, "c")
		end
	end
	return 18.4 * u, 5 * u
end
local C_LINE = Color(0.25, 0.2, 0.21, 0.9)
local function callout(x1, y1, x2, y2)            -- выноска карандашом: линия и точка у клавиши
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	if len < 1 then return end
	art("ma.highlight", (x1 + x2) / 2, (y1 + y2) / 2, len, 1.6, C_LINE, math.deg(math.atan(dy, dx)))
	art("ma.highlight", x2, y2, 3, 3, C_LINE)
end
local function deviceName(i)
	if i == 0 then return "КЛАВИАТУРА" end
	local ok, n = pcall(Input.GetDeviceNameByIdx, i)
	return ok and n and HF.upper(tostring(n)) or ("ГЕЙМПАД " .. i)
end
local function drawControls(o)
	T = T + (LOCALFIXES.MenuDT or 1)
	bg(o, "ctl")
	local sel = ControllerSelectMenu.GetSelectedElement() or 0
	if MF then MF.sel("controls", sel) end
	art("cs.title_banner", o.X + 240, o.Y + 20, 150, nil, nil, sway(1, 0.3))
	text("УПРАВЛЕНИЕ", o.X + 236, o.Y + 24, "gL", INK, "c")
	-- список устройств
	art(ART["hd.note_sq"] and "hd.note_sq" or "cs.notes", o.X + 72, o.Y + 128, 118, 150, nil, sway(9, 0.5))
	text("ЧЕМ ИГРАТЬ", o.X + 72, o.Y + 82, "gS", BLACK, "c")
	local n = 0
	for i = 0, 7 do
		local ok, nm = pcall(Input.GetDeviceNameByIdx, i)
		if i > 0 and not (ok and nm) then break end
		n = i + 1
		local y = o.Y + 98 + i * 13
		local on = i == sel
		local lbl = deviceName(i)
		if on then art("ma.highlight", o.X + 72, y - 3, 96, 11, Color(1, 1, 1, 0.75)) end
		text(lbl, o.X + 72, y, HF.Fit(lbl, 92, { "gS", "gT" }), on and BLACK or INK, "c")
		if on then art("ma.cursor", o.X + 20, y - 3, 7) end
	end
	-- схема выбранного устройства на листе в клетку
	art("co.grid", o.X + 306, o.Y + 140, 300, 200, nil, sway(4, 0.15))
	if sel == 0 then
		local centers, hot = {}, {}
		local U = 13.5
		local kx, ky = o.X + 182, o.Y + 116
		for r = 0, #KC_ROWS - 1 do local k = binding(r, 0, 0) if k then hot[k] = 1 end end
		drawKeyboard(kx, ky, U, hot, centers)
		-- выноски: подписи сверху (верхние ряды) и снизу (нижние ряды и стрелки)
		local GROUPS = { { 87, "ИДТИ", 0 }, { 265, "СТРЕЛЯТЬ", 4 }, { 69, "БОМБА", 8 }, { 32, "ПРЕДМЕТ", 9 },
			{ 81, "ПИЛЮЛЯ / КАРТА", 10 }, { 341, "БРОСИТЬ", 11 }, { 258, "КАРТА", 12 }, { 342, "ЭМОЦИИ", 13 },
			{ 82, "РЕСТАРТ", 15 }, { 80, "ПАУЗА", 17 } }
		local top, bot = {}, {}
		for _, g in ipairs(GROUPS) do
			local k = binding(g[3], 0, 0) or g[1]
			local c = centers[k]
			if c then
				local rec = { c[1], c[2], g[2] }
				if c[2] < ky + 2.5 * U then top[#top + 1] = rec else bot[#bot + 1] = rec end
			end
		end
		local function place(list, ly, up)       -- подпись — над/под своей клавишей, соседи раздвигаются, чтобы не налезать
			table.sort(list, function(p1, p2) return p1[1] < p2[1] end)
			local x0, x1 = o.X + 170, o.X + 444
			local xs, ws = {}, {}
			for i2, rec in ipairs(list) do ws[i2] = HF.Width(rec[3], "gT") + 6; xs[i2] = rec[1] end
			for i2 = 2, #list do xs[i2] = math.max(xs[i2], xs[i2 - 1] + (ws[i2 - 1] + ws[i2]) / 2) end
			local over = (xs[#list] or 0) + (ws[#list] or 0) / 2 - x1
			if over > 0 then for i2 = 1, #list do xs[i2] = xs[i2] - over end end
			for i2 = 1, #list do
				xs[i2] = math.max(xs[i2], x0 + ws[i2] / 2)
				if i2 > 1 then xs[i2] = math.max(xs[i2], xs[i2 - 1] + (ws[i2 - 1] + ws[i2]) / 2) end
			end
			for i2, rec in ipairs(list) do
				local lx = xs[i2]
				-- чередуем высоту подписей, если соседи близко (чтобы линии не шли через чужие подписи)
				local yy = ly + ((i2 % 2 == 0 and #list > 4) and (up and -9 or 9) or 0)
				text(rec[3], lx, yy, "gT", BLACK, "c")
				callout(lx, yy + (up and 3 or -7), rec[1], rec[2] + (up and -U * 0.3 or U * 0.3))
			end
		end
		place(top, ky - 12, true)
		place(bot, ky + 5 * U + 16, false)
	else
		art("co.pad", o.X + 306, o.Y + 140, 190, nil, nil, math.sin(T * 0.02) * 1.5)
		text("КНОПКИ — НА СЛЕДУЮЩЕМ ЛИСТЕ", o.X + 306, o.Y + 222, "gT", INK, "c")
	end
	if MF then MF.run("ctl", o) end
	CS.hints(o, { { "updown", "Выбор" }, { "Enter", "Настроить" }, { "Esc", "Назад" } })
end
SC.Register(MainMenuType.CONTROLS, drawControls, true)

local KQ = { t = {} }
local function drawKeyConfig(o)
	local dev = ControllerSelectMenu.GetSelectedElement and ControllerSelectMenu.GetSelectedElement() or 0
	local row = KeyConfigMenu.GetSelectedElement() or 0
	local col = KeyConfigMenu.GetSelectedColumn() or 0
	kcWatch(row, col)
	if dev ~= 0 and not Input.GetActionButtons then return end   -- геймпад: привязок не узнать — родной список игры
	T = T + (LOCALFIXES.MenuDT or 1)
	bg(o, "key")
	if MF then MF.sel("keyconfig", row * 2 + col) end
	-- лист: действия и две клавиши (основная, запасная), как у игры; последняя строка — «По умолчанию»
	local N = #KC_ROWS + 1
	KQ.t = {}
	local top, k, lines = longList(o, "key", 124, 210, N, row + 1, function(i, y, xn, xt, wt, on)
		local r = i - 1
		local dx = on and math.sin(T * 0.12) * 1.0 or 0
		if r == #KC_ROWS then                       -- «По умолчанию»
			if on then art("ma.highlight", xt + wt / 2 - 4, y - 4, wt + 14, 14, Color(1, 1, 1, 0.75)) end
			text("ПО УМОЛЧАНИЮ", xt + dx, y - 5, "gS", on and BLACK or INK)
			if on then art("ma.cursor", xn - 8 + dx, y - 6, 8) end
			return
		end
		local def = KC_ROWS[i]
		KQ.t[#KQ.t + 1] = { def[2], xt + dx, y - 5, HF.Fit(def[2], 70, { "gS", "gT" }), on and BLACK or INK }
		for c = 0, 1 do                            -- две клетки — в пределах листа (он кончается у xt + ~160); как у игры:
			local cx = xt + 76 + (1 - c) * 34        -- столбец 0 (основная) — справа, 1 (запасная) — слева («влево» → 1)
			local key = binding(r, c, dev)
			local lbl = key and (dev == 0 and keyLabel(key) or ("#" .. key)) or "-"
			local here = on and c == col
			art("cs.key2", cx + 14, y - 6, 29, 10, here and C_KEYSEL or (key and nil or Color(0.75, 0.72, 0.72, 1)))
			KQ.t[#KQ.t + 1] = { lbl, cx + 14, y - 3.5, HF.Fit(lbl, 26, { "gT" }), here and BLACK or (key and INK or DISABLED), "c" }
			if here then art("ma.cursor", cx - 5 + dx, y - 6, 6) end
		end
	end)
	for _, q in ipairs(KQ.t) do text(q[1], q[2], q[3], q[4], q[5], q[6]) end   -- подписи листа — одним проходом
	if top then
		text("КЛАВИШИ", o.X + 124, top + lines[2] * k - 7, "gL", INK, "c")

	end
	-- схема: клавиатура, выбранное действие — выноской
	art("co.grid", o.X + 360, o.Y + 132, 216, 150, nil, sway(4, 0.15))
	local centers, hot = {}, {}
	local U = 10.5
	local kx, ky = o.X + 264, o.Y + 108
	local def = KC_ROWS[row + 1]
	for c = 0, 1 do
		local key = binding(row, c, 0)
		if key then hot[key] = (c == col) and 2 or 1 end
	end
	drawKeyboard(kx, ky, U, hot, centers)
	if def then
		text(def[2], o.X + 360, ky - 16, "gM", BLACK, "c")
		for c = 0, 1 do
			local key = binding(row, c, 0)
			local cc = key and centers[key]
			if cc then callout(o.X + 360 + (c == 1 and -10 or 10), ky - 10, cc[1], cc[2] - U * 0.3) end
		end
	else
		text("ВСЁ КАК БЫЛО", o.X + 360, ky - 16, "gM", BLACK, "c")
	end
	art("cs.title_banner", o.X + 360, o.Y + 20, 130, nil, nil, sway(1, 0.3))
	text("НАСТРОЙКА", o.X + 356, o.Y + 24, "gL", INK, "c")
	if kc.edit or (KeyConfigMenu.IsEditActive and KeyConfigMenu.IsEditActive()) then
		art(ART["hd.note_wide"] and "hd.note_wide" or "ma.note_wide", o.X + 360, o.Y + 222, 160, 60, nil, sway(7, 0.6))
		text("НАЖМИ НОВУЮ КЛАВИШУ", o.X + 360, o.Y + 220, "gS", BLOODC, "c")
		text("ESC — ОТМЕНА", o.X + 360, o.Y + 231, "gT", INK, "c")
	end
	if MF then MF.run("key", o) end
	local h = { { "arrows", "Выбор" }, { "Enter", row == #KC_ROWS and "Сбросить" or "Назначить" }, { "Esc", "Назад" } }
	CS.hints(o, h)
end
SC.Register(MainMenuType.KEYCONFIG, drawKeyConfig, true)
-- «По умолчанию» (Enter на последней строке): игра сбрасывает раскладку — и наши отметки переназначений
LFMOD:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER, function()
	if MenuManager.GetActiveMenu() ~= MainMenuType.KEYCONFIG then kc.confirm = nil return end
	local p = false
	for i = 0, 3 do if Input.IsActionPressed(ButtonAction.ACTION_MENUCONFIRM, i) then p = true break end end
	if p and not kc.confirm and (KeyConfigMenu.GetSelectedElement() or 0) == #KC_ROWS
		and not (KeyConfigMenu.IsEditActive and KeyConfigMenu.IsEditActive()) then
		kbData = {}
		kbSave()
	end
	kc.confirm = p
end)
LFMOD:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER, function()
	if BEST.on and MenuManager.GetActiveMenu() ~= MainMenuType.BESTIARY then
		BEST.on = false
		MenuManager.SetInputMask(0xFFFFFFFF)
	end
end)

return L
