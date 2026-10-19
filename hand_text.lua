-- localfixes: рукописные шрифты меню. Три набора, выбор — по кеглю:
--   S, M, L        — пиксельный «маркер» (tools/hand_font.py → gfx/ui/localfixes/charsel/hand.anm2, hand_font.lua);
--                    заглавная 8 / 10 / 14 px; строчные приводятся к заглавным;
--   hT hS hM hL hX — тот же маркер в высоком разрешении (tools/hand_font_hd.py → menu/hand_hd.anm2, hand_font_hd.lua);
--   gT gS gM gL gX — шрифт меню из алфавитов Meshy под стиль образца (tools/alpha_font.py → menu/font_g.anm2,
--                    menu_font.lua): заглавные и строчные, рус. и англ.; заглавная 4.5 / 6 / 9 / 13 / 20 px.
-- HD-наборы — текстура 4× со Scale 0.25 (проверено 18.10: гладко на 1080p), позиции — дробные.
-- Буквы белые, цвет — при выводе.
--   LOCALFIXES.HandFont.Draw(text, x, y, size, color, align, scale) — y — базовая линия; align: "l" | "c" | "r"; → ширина
--   LOCALFIXES.HandFont.Width(text, size, scale)
--   LOCALFIXES.HandFont.Fit(text, maxw, sizes) — первый кегль из списка, где строка влезает (иначе последний)
--   LOCALFIXES.HandFont.Wrap(text, size, maxw, maxlines) — строки по ширине; лишнее — с многоточием
local H = {}

local SETS = {
	base = { idx = "hand_font", anm = "gfx/ui/localfixes/charsel/hand.anm2", dens = 1, upper = true },
	h = { idx = "hand_font_hd", anm = "gfx/ui/localfixes/menu/hand_hd.anm2", dens = 4, upper = true },
	g = { idx = "menu_font", anm = "gfx/ui/localfixes/menu/font_g.anm2", dens = 4, upper = false },
}
for _, set in pairs(SETS) do
	local ok, t = pcall(include, set.idx)
	set.t = ok and type(t) == "table" and t or nil
end
local function setOf(size)
	local c = size:sub(1, 1)
	if c == "h" then return SETS.h elseif c == "g" then return SETS.g end
	return SETS.base
end

local function sprite(set)
	if set.spr == nil then
		local s = Sprite()
		s:Load(set.anm, true)
		set.spr = s:IsLoaded() and s or false
		if set.spr and set.dens ~= 1 then set.spr.Scale = Vector(1 / set.dens, 1 / set.dens) end
	end
	return set.spr or nil
end

-- заглавные: латиница — string.upper, кириллица UTF-8: а-п (D0 B0–BF) → А-П (D0 90–9F), р-я (D1 80–8F) → Р-Я
-- (D0 A0–AF), ё (D1 91) → Ё (D0 81)
local function upper(s)
	s = s:upper()
	s = s:gsub("\208([\176-\191])", function(c) return "\208" .. string.char(c:byte() - 32) end)
	s = s:gsub("\209([\128-\143])", function(c) return "\208" .. string.char(c:byte() + 32) end)
	s = s:gsub("\209\145", "\208\129")
	return s
end
H.upper = upper

-- знаки, которых нет в рукописных алфавитах, — ближайшими («&» в именах модов: «Mod Fixes & Speedups», «Jacob & Esau»)
local SUBST = { ["—"] = "-", ["–"] = "-", ["«"] = '"', ["»"] = '"', ["…"] = ".", ["’"] = "'", ["‘"] = "'", ["&"] = "+" }

-- Язык (19.10, решение пользователя: «Один мод, по языку игры»; «У тех игроков что поставят английский - должен быть
-- английский»): наш текст меню написан по-русски; при другом языке игры строка до замера ширины, переноса и вывода
-- заменяется английской по словарю en/menu_en.lua — точные строки (в любом регистре: «Выбор» и «ВЫБОР») и шаблоны с
-- числами и вставками (вставки переводятся тем же словарём, списки «а, б» — по частям). Язык — Options.Language
-- («ru» — русский, иначе английский); отладка — глобальная LOCALFIXES_FORCE_LANG («en» / «ru»).
local okEN, EN = pcall(include, "en.menu_en")
if not okEN or type(EN) ~= "table" then EN = {} end
EN.exact, EN.patterns = EN.exact or {}, EN.patterns or {}
local okCS, CSEN = pcall(include, "en.charsel_en")    -- экран выбора персонажа: заметки, условия открытия
if okCS and type(CSEN) == "table" then
	for ru, en in pairs(CSEN) do
		if EN.exact[ru] == nil then EN.exact[ru] = en end
	end
end
local EXACT_UP = {}
for ru, en in pairs(EN.exact) do EXACT_UP[upper(ru)] = en end
local function lang()
	local f = rawget(_G, "LOCALFIXES_FORCE_LANG")
	if f then return f end
	local ok, l = pcall(function() return Options.Language end)
	return ok and l or "en"
end
H.Lang = lang
H.IsRu = function() return lang() == "ru" end
local trCache = {}
local function tr(s, depth)
	if lang() == "ru" or type(s) ~= "string" or not s:find("[\208\209]") then return s end
	local r = trCache[s]
	if r then return r end
	r = EN.exact[s]
	if not r then
		local u = EXACT_UP[upper(s)]
		if u then r = (s == upper(s)) and upper(u) or u end
	end
	if not r and (depth or 0) < 3 then
		for _, p in ipairs(EN.patterns) do
			local caps = { s:match(p[1]) }
			if #caps > 0 then
				for i, c in ipairs(caps) do
					if c:find(", ", 1, true) then           -- список «тьма, лабиринт» — по частям
						local parts = {}
						for part in (c .. ", "):gmatch("(.-), ") do parts[#parts + 1] = tr(part, (depth or 0) + 1) end
						caps[i] = table.concat(parts, ", ")
					else
						caps[i] = tr(c, (depth or 0) + 1)
					end
				end
				local out = p[2]:gsub("%%(%d)", function(n) return caps[tonumber(n)] or "" end)
				r = (s == upper(s)) and upper(out) or out
				break
			end
		end
	end
	r = r or s
	trCache[s] = r
	return r
end
H.Tr = tr
-- строка на двух языках прямо в коде (там, где словарь неудобен): H.L("Назад", "Back")
function H.L(ru, en) return lang() == "ru" and ru or en end

local cache = {}
local function run(text, size)
	text = tr(text)
	local key = size .. "\0" .. text
	local r = cache[key]
	if r then return r end
	local set = setOf(size)
	local t = set.t and set.t[size]
	local sp = set.t and set.t.space and set.t.space[size] or 4
	local frames, xs, w = {}, {}, 0
	local src = set.upper and upper(text) or text
	for _, c in utf8.codes(src) do
		local ch = utf8.char(c)
		ch = SUBST[ch] or ch
		if ch == " " then
			w = w + sp
		else
			local g = t and (t[ch] or t[upper(ch)] or t["?"])
			if g then
				frames[#frames + 1] = g[1]
				xs[#xs + 1] = w
				w = w + g[2]
			end
		end
	end
	r = { w = w, frames = frames, xs = xs }
	cache[key] = r
	return r
end

function H.Width(text, size, scale) return run(tostring(text), size or "M").w * (scale or 1) end

local ZERO = Vector.Zero
local INK = Color(55 / 255, 43 / 255, 45 / 255, 1)
function H.Draw(text, x, y, size, color, align, scale)
	size = size or "M"
	scale = scale or 1
	local set = setOf(size)
	local s = sprite(set)
	if not s or not set.t then return 0 end
	local r = run(tostring(text), size)
	local w = r.w * scale
	if align == "c" then x = x - w / 2 elseif align == "r" then x = x - w end
	s.Color = color or INK
	local k = scale / set.dens
	s.Scale = Vector(k, k)
	for i, fr in ipairs(r.frames) do
		s:SetFrame(size, fr)
		if set.dens == 1 and scale == 1 then
			s:Render(Vector(math.floor(x + r.xs[i] + 0.5), math.floor(y + 0.5)), ZERO, ZERO)
		else
			s:Render(Vector(x + r.xs[i] * scale, y), ZERO, ZERO)
		end
	end
	return w
end

function H.Fit(text, maxw, sizes)
	sizes = sizes or { "L", "M", "S" }
	for _, sz in ipairs(sizes) do
		if H.Width(text, sz) <= maxw then return sz end
	end
	return sizes[#sizes]
end

function H.Wrap(text, size, maxw, maxlines)
	local lines, cur = {}, ""
	text = tr(tostring(text))                          -- перевод — целой фразой до разбивки на строки
	for word in text:gmatch("%S+") do
		local cand = cur == "" and word or (cur .. " " .. word)
		if H.Width(cand, size) <= maxw or cur == "" then
			cur = cand
		else
			lines[#lines + 1] = cur
			cur = word
		end
	end
	if cur ~= "" then lines[#lines + 1] = cur end
	if maxlines and #lines > maxlines then
		local keep = {}
		for i = 1, maxlines do keep[i] = lines[i] end
		local last = keep[maxlines]
		while #last > 1 and H.Width(last .. "...", size) > maxw do
			last = last:gsub("[%z\1-\127\194-\244][\128-\191]*$", "")
		end
		keep[maxlines] = last .. "..."
		lines = keep
	end
	return lines
end

LOCALFIXES.HandFont = H
return H
