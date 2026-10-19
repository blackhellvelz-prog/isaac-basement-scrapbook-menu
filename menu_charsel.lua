-- localfixes: экран выбора сложности и персонажа в стиле образца пользователя (18.10, слова пользователя: «Сделай как на
-- этой картинке»; «Соответственно добавь на него то что связанно с нашими модами»; «Соответственно и главное меню
-- переделай с титульным экраном и экраном выбора сложности тоже»; «Общий стиль я тебе скинул картинку»; «элементы
-- экрана ... выбора персонажа должны иметь какую то анимацию»; «У тебя ещё блок с талантами не забывай»; «Так же нужно
-- будет чтобы любой другой мод который добавляет персонажей тоже имел возможность так добавлять персонажей в этот
-- экран / Проще говоря подключаемые модули автоматически»; «если он заблокирован ... Где то заперт»). План —
-- docs/MENU_PLAN.md, облик персонажей — docs/sources/charselect_poses.md, арт — tools/menu_pack.py (menu_art.lua).
--
-- Два шага на одном меню игры (MainMenuType.CHARACTER):
--   «сложность»: 4 карточки (Обычный, Сложный, Жадность, Жадность+; закрытые — рубашкой с замком), ←/→ — выбор,
--     Enter — дальше, Esc — назад в главное меню (как в игре); Q — пасхалки, TAB — сид (родные экраны игры).
--   «персонаж»: список слева (↑/↓ и ←/→), большая карточка (рисунок, стрелки, вещи, пояснение), карточки версий
--     (обычный / порченый / потускневший Epiphany — E), справа статистика, отметки боссов, блок талантов PST, «Начать»;
--     сверху — логотип, заголовок, закладки модов (LT/RT, клавиатура X/C). Esc — назад к сложности.
-- Персонажи модов — сами: список колеса игры (REPENTOGON), рисунок — наш HD (menu_art) или, если его нет, портрет
-- меню мода; API: LOCALFIXES.CharSelect.Register(тип_игрока_или_имя, { anm2 = путь, anim = имя, locked_anim = имя })
-- — свой HD-рисунок для чужого мода. Нет мода — нет его элементов (Epiphany, PST, закладки).
local mod = LOCALFIXES.Mod
local HF = LOCALFIXES.HandFont
local game = Game()
local sfx = SFXManager()
local C = { active = false, phase = "diff", custom = {} }
LOCALFIXES.CharSelect = C

local ZERO = Vector.Zero
local FULLMASK = 0xFFFFFFFF
-- «Сцена» — где стоит экран меню 480×270 на экране игры. В полноэкранном 16:9 это (0, 0), а в окне другой формы
-- игра показывает больше мира меню и ставит активный экран по центру (20.10, отзыв в Мастерской: «is completely broken
-- in windowed mode» — в широком окне экран выбора и экраны в переходе рисовались от левого края, по бокам были видны
-- соседние экраны и родное меню). Все наши экраны «на месте» рисуются от C.stage().
function C.stage()
	local w, h = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
	return Vector(math.floor((w - 480) / 2 + 0.5), math.floor((h - 270) / 2 + 0.5))
end
local INK = Color(55 / 255, 43 / 255, 45 / 255, 1)
local SOFT = Color(110 / 255, 98 / 255, 100 / 255, 1)
local CREAM = Color(244 / 255, 236 / 255, 208 / 255, 1)
local BLOODC = Color(112 / 255, 8 / 255, 11 / 255, 1)
local TARNC = Color(94 / 255, 6 / 255, 9 / 255, 1)

-- ------------------------------------------------------------------ арт (tools/menu_pack.py → menu_art.lua)
local okA, ART = pcall(include, "menu_art")
if not okA or type(ART) ~= "table" then ART = {} end
local SPR = {}
local function sprOf(anm)
	local sp = SPR[anm]
	if sp == nil then
		sp = Sprite()
		sp:Load(anm, true)
		if not sp:IsLoaded() then sp = false end
		SPR[anm] = sp
	end
	return sp or nil
end
-- переворот всего экрана при смене обычный / порченый / потускневший (18.10: «Сделай более плавный экран
-- переключения между обычным/порченным/потускневшим / Как в оригинале»): 1 — лист раскрыт, 0 — ребром
local FLIP, FLIPX = 1, 240
-- кусок по центру (x, y): ширина w (или высота h, если w = nil); обе — растянуть; kx/ky — доп. сжатие.
-- Игра уменьшает спрайты без сглаживания — берётся уровень уменьшения (menu_pack: имя@2, @4, @8), чтобы на пиксель
-- экрана приходилось не больше ~1,4 пикселя текстуры (18.10: «Головы персонажей слишком пиксельные»).
local function art(name, x, y, w, h, color, rot, kx, ky, noflip)
	local a = ART[name]
	if not a then return false, 0, 0 end
	local tw, th = a[2], a[3]
	local k = w and (w / tw) or (h / th)
	local k2 = (w and h) and (h / th) or k
	local anm, anim, lv = a[1], name, 1
	if a[4] then
		local want = 0.175 / math.max(1e-4, math.sqrt(k * k2))   -- по средней оси: вытянутое не мылится
		for i, m in ipairs(a[4]) do
			if lv < want then lv, anm, anim = 2 ^ i, m, name .. "@" .. math.floor(2 ^ i) end
		end
	end
	local s = sprOf(anm)
	if not s then return false, 0, 0 end
	if FLIP < 1 and not noflip then
		x = FLIPX + (x - FLIPX) * FLIP
		kx = (kx or 1) * math.max(0.01, FLIP)
		local c = color or Color.Default
		local sh = 1                                      -- 20.10: без затемнения листа в изгибе
		color = Color(c.R * sh, c.G * sh, c.B * sh, c.A)
	end
	s:SetFrame(anim, 0)
	s.Scale = Vector(k * lv * (kx or 1), k2 * lv * (ky or 1))
	s.Color = color or Color.Default
	s.Rotation = rot or 0
	s:Render(Vector(x, y), ZERO, ZERO)
	s.Rotation = 0
	return true, tw * k, th * k2
end
-- «живой» кусок (18.10: «Анимируй более детально менюшки чтобы персонажи чуть двигались … Не просто простые анимации
-- типа плавно вверх вниз а прям полноценные / У персонажей чуть чуть совсем»; «Легкая не значит что банальное плавное
-- движение вверх вниз»): кусок рисуется полосами — строками (dir "h") или столбцами ("v"), у каждой полосы свой сдвиг
-- и растяжение. Так тело дышит, гнётся, голова отстаёт, крылья машут, глаз моргает — деформацией, без смены кадров и
-- без ряби. fn(u) → dx, dy, sx, sy: u — 0..1 поперёк полос (сверху вниз / слева направо), dx, dy — в точках меню,
-- sx, sy — растяжение полосы, m (необязательно) — яркость полосы (мерцание света). anchor — что стоит на месте при
-- растяжении (0 — верх/лево, 0,5 — центр, 1 — низ/право).
local LIVE_N = 32
local function artLive(name, x, y, w, h, color, dir, fn, anchor, kx, ky, n)
	local a = ART[name]
	if not a then return false end
	local tw, th = a[2], a[3]
	local k = w and (w / tw) or (h / th)
	local k2 = (w and h) and (h / th) or k
	local anm, anim, lv = a[1], name, 1
	if a[4] then
		local want = 0.175 / math.max(1e-4, math.sqrt(k * k2))   -- по средней оси: вытянутое не мылится
		for i, m in ipairs(a[4]) do
			if lv < want then lv, anm, anim = 2 ^ i, m, name .. "@" .. math.floor(2 ^ i) end
		end
	end
	local s = sprOf(anm)
	if not s then return false end
	kx = kx or 1
	if FLIP < 1 then
		x = FLIPX + (x - FLIPX) * FLIP
		kx = kx * math.max(0.01, FLIP)
		local c = color or Color.Default
		local sh = 1
		color = Color(c.R * sh, c.G * sh, c.B * sh, c.A)
	end
	s:SetFrame(anim, 0)
	local base = color or Color.Default
	s.Color = base
	s.Rotation = 0
	local fw, fh = math.floor(tw / lv), math.floor(th / lv)          -- кадр уровня (menu_pack.half: целые половины)
	local pvx, pvy = math.floor(fw / 2), math.floor(fh / 2)          -- опора кадра — центр
	local bx, by = k * lv * kx, k2 * lv * (ky or 1)
	local horiz = dir ~= "v"
	local N = horiz and fh or fw
	n = math.min(n or LIVE_N, N)
	local parts, total = {}, 0
	for i = 0, n - 1 do
		local c0, c1 = math.floor(N * i / n), math.floor(N * (i + 1) / n)
		local dx, dy, sx, sy, m = fn((c0 + c1) * 0.5 / N)
		dx, dy, sx, sy = dx or 0, dy or 0, sx or 1, sy or 1
		parts[#parts + 1] = { c0, c1, dx, dy, sx, sy, m }
		total = total + (c1 - c0) * (horiz and by * sy or bx * sx)
	end
	local len0 = N * (horiz and by or bx)
	local cur = (horiz and (y - pvy * by) or (x - pvx * bx)) - (total - len0) * (anchor or 0.5)
	for i, pt in ipairs(parts) do
		local c0, c1, dx, dy, sx, sy, m = pt[1], pt[2], pt[3], pt[4], pt[5], pt[6], pt[7]
		local ov = 0     -- без нахлёста: края соседних полос считаются из одной суммы и совпадают; нахлёст на полупрозрачных
		                 -- рисунках давал светлые швы (двойное наложение)
		s.Scale = Vector(bx * sx, by * sy)
		s.Color = m and Color(base.R * m, base.G * m, base.B * m, base.A) or base
		if horiz then
			local py = cur - (c0 - pvy) * by * sy
			s:Render(Vector(x + dx, py + dy), Vector(0, c0), Vector(0, fh - c1 - ov))
			cur = cur + (c1 - c0) * by * sy
		else
			local px = cur - (c0 - pvx) * bx * sx
			s:Render(Vector(px + dx, y + dy), Vector(c0, 0), Vector(fw - c1 - ov, 0))
			cur = cur + (c1 - c0) * bx * sx
		end
	end
	s.Scale = Vector.One
	s.Color = Color.Default
	return true
end

-- движения персонажей — по их позам (docs/sources/charselect_poses.md); всё «чуть-чуть»: доли точки меню
local function bump(u, c, w) local d = (u - c) / w return math.exp(-d * d) end
local function smooth01(v) v = math.max(0, math.min(1, v)) return v * v * (3 - 2 * v) end
local function breath(t, rate, seed)                                    -- вдох быстрее выдоха
	local p = t * (rate or 0.033) + (seed or 0)
	p = p + 0.35 * math.sin(p)
	return (1 - math.cos(p)) * 0.5
end
local function hash(a, b) local v = math.sin(a * 12.9898 + b * 78.233) * 43758.5453 return v - math.floor(v) end
local MOTION_OF = {}
for kind, keys in pairs({
	float = { "azazel", "thelost", "thelost_c", "judas_b", "judas_c", "moses_b", "miriam_b" },
	rage = { "samson", "samson_b", "samson_c", "magdalene_b", "fiend_b" },
	glitch = { "eden_b", "eden_c" },
	lie = { "bluebaby", "bluebaby_c", "joseph_b", "robot_b" },
	hang = { "peter_b" },
	robot = { "robot" },
	heart = { "magdalene_c", "leah_b", "leah" },
	cough = { "azazel_b" },
	sob = { "isaac", "isaac_b", "eve", "inaba", "jacob_b", "thelost_b" },
	dance = { "miriam" },
	still = { "keeper_c" },
	heavy = { "golem", "golem_b", "keeper_b" },
}) do for _, k in ipairs(keys) do MOTION_OF[k] = kind end end
-- Персонаж двигается ЦЕЛИКОМ, одной картинкой (18.10: «Сделай более нормальную анимацию персонажам / Потому что я
-- вижу полосы при движении картинки» — полосы artLive на границах давали ступеньки и линии): поза кадра — растяжение
-- sx, sy, наклон rot (градусы), сдвиг dx, dy вокруг опоры (ax, ay — доли рисунка: 0,5/1 — ступни). Вдох: тело чуть
-- вытягивается от ступней и раздаётся в груди; наклон и перенос веса — медленнее и с запаздыванием; у каждого вида —
-- своё (всхлипы, дрожь, парение, маятник, удары сердца, рывки робота). Полосы — только у сбоев «глючащих».
local function pose(sx, sy, rot, dx, dy, ax, ay)
	return { sx = sx or 1, sy = sy or 1, rot = rot or 0, dx = dx or 0, dy = dy or 0, ax = ax or 0.5, ay = ay or 1 }
end
-- Кадры (18.10: «Сделай анимацию как у партиклей / Чтобы две картинки просто сменяли друг друга / Но только
-- качественно»; «Не резкая смена а плавная»; «Своими силами»; «Просто измени картинку»): у рисунка есть второй кадр
-- «имя~b» — тот же рисунок, плавно деформированный (tools/anim_frames.py: вдох, всхлип, взмах, толчок сердца, сбой…).
-- fk — доля второго кадра (0 — первый, 1 — второй): кадры перетекают друг в друга. Поза (растяжение, наклон, сдвиг)
-- остаётся только там, где движение целиком: парение, дрожь, маятник, танец.
local MOTION = {}
MOTION.breath = function(t, sd)       -- вдох-выдох
	local P = pose()
	P.fk = breath(t, 0.033, sd)
	return P
end
MOTION.float = function(t, sd)        -- парит: всплывает (кадр B — выше, хвост качнулся) и чуть покачивается целиком
	local hov = math.sin(t * 0.037 + sd)
	local P = pose(1, 1, 1.0 * math.sin(t * 0.023 + sd), 0.3 * math.sin(t * 0.019 + sd), -0.6 * hov, 0.5, 0.5)
	P.fk = (hov + 1) * 0.5
	return P
end
MOTION.lie = function(t, sd)          -- лежит: медленно поднимается живот
	local P = pose()
	P.fk = breath(t, 0.022, sd)
	return P
end
MOTION.rage = function(t, sd)         -- ярость: частое тяжёлое дыхание и мелкая дрожь
	local P = pose(1, 1, 0.5 * math.sin(t * 2.3 + sd), 0.3 * math.sin(t * 1.9 + sd) + 0.15 * math.sin(t * 3.1), 0)
	P.fk = breath(t, 0.075, sd)
	return P
end
MOTION.glitch = function(t, sd)       -- глючит: кадр B — сбой, вспыхивает рывками (сбою плавность не нужна)
	local P = pose(1, 1 + 0.008 * breath(t, 0.033, sd), 0, 0, 0)
	P.fk = (hash(t // 24, sd) < 0.35 and hash(t // 3, sd + 1) < 0.5) and 1 or 0
	P.hard = true
	return P
end
MOTION.hang = function(t, sd)         -- висит: маятник от верхней точки (целиком)
	return pose(1, 1, 2.0 * math.sin(t * 0.029 + sd), 0, 0, 0.5, 0)
end
MOTION.robot = function(t, sd)        -- робот: изредка наклоняет голову (кадр B) и возвращает, мелкая вибрация
	local ph = (t + math.floor(sd * 40)) % 300
	local P = pose(1, 1, 0, 0.06 * math.sin(t * 2.3), 0)
	P.fk = ph < 90 and math.sin(ph / 90 * math.pi) or 0
	return P
end
local function heartbeat(t, sd)
	local ph = (t + math.floor(sd * 30)) % 54
	return math.exp(-((ph - 4) / 2.5) ^ 2) + 0.6 * math.exp(-((ph - 13) / 2.5) ^ 2)
end
MOTION.heart = function(t, sd)        -- сердце бьётся: «тук-тук» (кадр B — грудь раздалась)
	local P = pose()
	P.fk = math.min(1, heartbeat(t, sd) + 0.25 * breath(t, 0.033, sd))
	return P
end
MOTION.cough = function(t, sd)        -- кашляет: раз в несколько секунд — три толчка (кадр B — согнулся)
	local P = pose()
	local ph = (t + math.floor(sd * 50)) % 200
	local c = ph < 36 and math.max(0, math.sin(ph / 12 * math.pi * 2)) or 0
	P.fk = math.max(c, 0.4 * breath(t, 0.033, sd))
	return P
end
MOTION.sob = function(t, sd)          -- всхлипывает: дыхание и короткие судорожные вдохи
	local P = pose()
	local ph = (t + math.floor(sd * 60)) % 150
	local h = 0
	for _, c in ipairs({ 8, 20, 30 }) do h = h + math.exp(-((ph - c) / 3) ^ 2) end
	P.fk = math.min(1, 0.6 * breath(t, 0.033, sd) + h)
	return P
end
MOTION.dance = function(t, sd)        -- танцует: в такт пружинит и наклоняется (целиком; кадр B — наклон)
	local beat = t * 0.09 + sd
	local up = math.abs(math.sin(beat))
	local P = pose(1 + 0.015 * (1 - up), 1 - 0.02 * (1 - up), 2.5 * math.sin(beat), 0, -1.0 * up)
	return P
end
MOTION.still = function() return pose() end
MOTION.heavy = function(t, sd)        -- тяжёлый: медленный глубокий вдох
	local P = pose()
	P.fk = breath(t, 0.022, sd)
	return P
end
-- рисунок в позе P: (x, y) — центр рисунка в покое, w или h — размер в покое; опора (ax, ay) остаётся на месте
-- рисунок в позе P: (x, y) — центр рисунка в покое, w или h — размер в покое; опора (ax, ay) остаётся на месте.
-- P.fk — доля второго кадра: A рисуется, поверх проявляется B, потом под ним гаснет A (без провала прозрачности);
-- второй кадр есть только в полном размере — когда рисунок мелкий (берётся уровень уменьшения), рисуется только A.
local function artPose(name, x, y, w, h, color, P, kx, ky)
	local a = ART[name]
	if not a then return false end
	if not P then return art(name, x, y, w, h, color, 0, kx, ky) end
	local W = w or (h * a[2] / a[3])
	local H = (w and h) or (W * a[3] / a[2])
	local ox, oy = (P.ax - 0.5) * W, (P.ay - 0.5) * H                  -- опора от центра в покое
	local r = math.rad(P.rot)
	local c, s = math.cos(r), math.sin(r)
	local qx, qy = ox * P.sx, oy * P.sy * (ky or 1)
	local cx = x + ox + P.dx - (qx * c - qy * s)
	local cy = y + oy + P.dy - (qx * s + qy * c)
	local nb = name .. "~b"
	local fk = P.fk
	if fk and fk > 0.002 and ART[nb] and math.min(W * P.sx / a[2], H * P.sy / a[3]) >= 0.175 then
		local e = P.hard and fk or fk * fk * (3 - 2 * fk)
		local aA, aB = math.min(1, 2 - 2 * e), math.min(1, 2 * e)
		local col = color or Color.Default
		if aA > 0.003 then art(name, cx, cy, W * P.sx, H * P.sy, Color(col.R, col.G, col.B, col.A * aA), P.rot, kx, ky) end
		return art(nb, cx, cy, W * P.sx, H * P.sy, Color(col.R, col.G, col.B, col.A * aB), P.rot, kx, ky)
	end
	return art(name, cx, cy, W * P.sx, H * P.sy, color, P.rot, kx, ky)
end
local function motionOf(key)
	local base = key and key:gsub("^lk_", "") or ""
	return MOTION[MOTION_OF[base] or "breath"], (#base * 1.37) % 6.28
end

-- рисунок, обрезанный по высоте экрана: видно только между yMin и yMax (длинный лист над полосой подсказок)
local function artClipY(name, x, y, w, h, color, yMin, yMax)
	local a = ART[name]
	if not a then return false end
	local tw, th = a[2], a[3]
	local k = w and (w / tw) or (h / th)
	local k2 = (w and h) and (h / th) or k
	local anm, anim, lv = a[1], name, 1
	if a[4] then
		local want = 0.175 / math.max(1e-4, math.sqrt(k * k2))
		for i, m in ipairs(a[4]) do
			if lv < want then lv, anm, anim = 2 ^ i, m, name .. "@" .. math.floor(2 ^ i) end
		end
	end
	local s = sprOf(anm)
	if not s then return false end
	local H = th * k2
	local top, bottom = y - H / 2, y + H / 2
	if bottom <= yMin or top >= yMax then return true end
	local fh = math.floor(th / lv)
	local sy = k2 * lv                                       -- точек меню на строку кадра
	local ct = math.max(0, math.floor((yMin - top) / sy))
	local cb = math.max(0, math.floor((bottom - yMax) / sy))
	if ct + cb >= fh then return true end
	s:SetFrame(anim, 0)
	s.Scale = Vector(k * lv, k2 * lv)
	s.Color = color or Color.Default
	s.Rotation = 0
	s:Render(Vector(x, y), Vector(0, ct), Vector(0, cb))
	s.Scale = Vector.One
	return true
end
local function artSize(name, w)
	local a = ART[name]
	if not a then return 0, 0 end
	return w, a[3] * w / a[2]
end

-- покачивание бумажек: у каждой своя фаза, едва заметно (поворот в градусах)
local T = 0
local function sway(seed, amp)
	return math.sin(T * 0.021 + seed * 1.7) * (amp or 0.5)
end
local function text(s, x, y, size, color, align, scale)
	if FLIP < 1 then                                         -- надписи на перевороте тают и сжимаются к центру
		if FLIP < 0.35 then return 0 end
		local c = color or INK
		color = Color(c.R, c.G, c.B, c.A * (FLIP - 0.35) / 0.65)
		x = FLIPX + (x - FLIPX) * FLIP
	end
	return HF.Draw(s, x, y, size, color or INK, align, scale)
end

-- ------------------------------------------------------------------ персонажи колеса (как в игре, с модами)
local function modOf(pt)
	local xml = XMLData and XMLData.GetEntryById(XMLNode.PLAYER, pt)
	return xml and xml.sourceid or "BaseGame"
end
local function charcard() return LOCALFIXES.CharCard end
local function modLabel(src)
	local cc = charcard()
	if src == "BaseGame" then return "Игра" end
	return (cc and cc.modName and cc.modName(src)) or tostring(src)
end
local function unlocked(pt)
	local cfg = EntityConfig.GetPlayer(pt)
	if not cfg then return false end
	local ach = cfg:GetAchievementID()
	if not ach or ach == -1 then return true end
	return Isaac.GetPersistentGameData():Unlocked(ach)
end

local listCache = {}
local function wheel()
	local page = CharacterMenu.GetSelectedCharacterMenu()
	local n = CharacterMenu.GetNumCharacters()
	local key = page .. ":" .. n
	if listCache.key == key then return listCache.list, listCache.groups end
	local list, groups, byMod = {}, {}, {}
	for id = 0, n - 1 do
		local pt = CharacterMenu.GetPlayerTypeFromCharacterMenuID(id)
		local E = Epiphany
		local technical = type(E) == "table" and E.technical_character == pt
		if id == 0 then pt = -1 end                       -- «Случайный»: у игры без типа игрока
		if pt and (pt >= 0 or id == 0) and not technical then
			local src = id == 0 and "BaseGame" or modOf(pt)
			local e = { id = id, pt = pt, src = src, random = id == 0 }
			list[#list + 1] = e
			local g = byMod[src]
			if not g then
				g = { src = src, name = modLabel(src), items = {} }
				byMod[src] = g
				groups[#groups + 1] = g
			end
			g.items[#g.items + 1] = e
			e.group = g
		end
	end
	listCache = { key = key, list = list, groups = groups }
	return list, groups
end

-- тип игрока → ключ HD-рисунка (tools/charsel_chars.py)
local VAN = { [0] = "isaac", "magdalene", "cain", "judas", "bluebaby", "eve", "samson", "azazel", "lazarus", "eden",
	"thelost", [13] = "lilith", [14] = "keeper", [15] = "apollyon", [16] = "theforgotten", [18] = "bethany", [19] = "jacob" }
-- порченые: тип игрока → обычный (21–31 подряд, дальше игра нумерует по-своему)
local TAINT_BASE = { [21] = 0, [22] = 1, [23] = 2, [24] = 3, [25] = 4, [26] = 5, [27] = 6, [28] = 7, [29] = 8, [30] = 9,
	[31] = 10, [32] = 13, [33] = 14, [34] = 15, [35] = 16, [36] = 18, [37] = 19, [38] = 8, [39] = 19, [40] = 16 }
local MODKEY = { Fiend = "fiend", Golem = "golem", Friend = "friend", Inaba = "inaba", Leah = "leah", Peter = "peter",
	Miriam = "miriam", Moses = "moses", Robot = "robot", Joseph = "joseph", Slippy = "slippy", China = "china",
	Craig = "craig", ["Classic Fiend"] = "classic_fiend", Image = "image", Fend = "fend", Frond = "frond", Fient = "fient",
	Mi = "mi", ["Freezer Jr."] = "freezer", Peat = "peat" }
local RU = { isaac = "Исаак", magdalene = "Магдалина", cain = "Каин", judas = "Иуда", bluebaby = "???", eve = "Ева",
	samson = "Самсон", azazel = "Азазель", lazarus = "Лазарь", eden = "Эдем", thelost = "Потерянный", lilith = "Лилит",
	keeper = "Хранитель", apollyon = "Аполлион", theforgotten = "Забытый", bethany = "Вифания", jacob = "Иаков и Исав",
	fiend = "Изверг", golem = "Голем", friend = "Френд", inaba = "Инаба", leah = "Лия", peter = "Пётр", miriam = "Мириам",
	moses = "Моисей", robot = "Робот", joseph = "Иосиф", slippy = "Слиппи", china = "Чайна", craig = "Крейг",
	classic_fiend = "Кл. Изверг", image = "Имидж", fend = "Фенд", frond = "Фронд", fient = "Фиент", mi = "Ми",
	freezer = "Фризер-мл.", peat = "Пит" }
local keyCache = {}
local function charKey(pt)
	local k = keyCache[pt]
	if k ~= nil then return k or nil end
	if pt <= 40 then
		local base = pt >= 21 and TAINT_BASE[pt] or pt
		k = base and VAN[base] and (VAN[base] .. (pt >= 21 and "_b" or "")) or false
	else
		local cfg = EntityConfig.GetPlayer(pt)
		local nm = cfg and cfg:GetName()
		local tainted = false
		if cfg then pcall(function() tainted = cfg:IsTainted() end) end
		k = nm and MODKEY[nm] and (MODKEY[nm] .. (tainted and "_b" or "")) or false
	end
	keyCache[pt] = k
	return k or nil
end
local FEM = { magdalene = true, eve = true, lilith = true, bethany = true, leah = true, miriam = true, inaba = true,
	china = true, mi = true, freezer = true, friend = true }
local function charName(e, key, full)
	local bare = key and key:gsub("_b$", ""):gsub("_c$", "")
	-- 19.10, «Один мод, по языку игры»: русские имена — только в русской игре, в английской — имена игры и модов
	local ru = not (HF and HF.IsRu) or HF.IsRu()
	local base = ru and bare and RU[bare]
	if base then
		if full and key:sub(-2) == "_b" then return (FEM[bare] and "Порченая " or "Порченый ") .. base end
		return base
	end
	local cfg = EntityConfig.GetPlayer(e.pt)
	local nm = cfg and cfg:GetName() or "?"
	if nm:sub(1, 1) == "#" then
		local ok, s
		if Isaac.GetLocalizedString and HF and HF.Lang then   -- строка игры на языке нашего текста (не только игры)
			ok, s = pcall(Isaac.GetLocalizedString, "Players", nm:sub(2), HF.Lang())
		end
		if not (ok and s and s ~= "" and s ~= "StringTable::InvalidKey") then ok, s = pcall(Isaac.GetString, "Players", nm:sub(2)) end
		if ok and s and s ~= "StringTable::InvalidKey" then nm = s end
	end
	if not ru and full and key and key:sub(-2) == "_b" and not nm:find("^Tainted") then nm = "Tainted " .. nm end
	return nm
end

-- рисунок колеса игры / портрет меню мода (если HD-рисунка нет) — как в книге
local VAN_ANIM = { [0] = "01_Isaac", "02_Magdalene", "03_Cain", "04_Judas", "06_Bluebaby", "05_Eve", "07_Samson",
	"08_Azazel", "09_Lazarus", "10_Eden", "11_TheLost", [13] = "12_Lilith", [14] = "13_Keeper", [15] = "15_Apollyon",
	[16] = "16_TheForgotten", [18] = "17_Bethany", [19] = "18_JacobEsau" }
local VSP = {}
local function vspr(k, anm)
	if VSP[k] == nil then
		local s = Sprite()
		s:Load(anm, true)
		VSP[k] = s:IsLoaded() and s or false
	end
	return VSP[k] or nil
end
local function drawWheelPortrait(e, pos, scale, locked)
	local pt, s, anim = e.pt, nil, nil
	if e.random then
		s, anim = vspr("van", "gfx/ui/main menu/characterportraits.anm2"), "00_Random"
	elseif pt <= 40 then
		local base = pt >= 21 and pt - 21 or pt
		anim = VAN_ANIM[base]
		s = pt >= 21 and vspr("alt", "gfx/ui/main menu/characterportraitsalt.anm2")
			or vspr("van", "gfx/ui/main menu/characterportraits.anm2")
	else
		local cfg = EntityConfig.GetPlayer(pt)
		s = cfg and cfg:GetModdedMenuPortraitSprite()
		if s then
			local nm = cfg:GetName()
			anim = (pcall(s.GetAnimationData, s, nm) and nm) or s:GetDefaultAnimation()
		end
	end
	if not (s and anim) then return end
	s:SetFrame(anim, 0)
	local lf = locked and pt > 40 and 1 or 0
	pcall(s.SetLayerFrame, s, 0, lf)
	s.Scale = Vector(scale, scale)
	s.Color = (locked and pt <= 40) and Color(0.3, 0.27, 0.27, 0.75) or Color.Default
	s:Render(pos, ZERO, ZERO)
	s.Scale = Vector.One
	s.Color = Color.Default
	if lf == 1 then pcall(s.SetLayerFrame, s, 0, 0) end
end

-- HD-рисунок персонажа (или закрытого — «взаперти») по низу (x, yb), вписан в w×h; дыхание и покачивание
local function drawHero(e, key, x, yb, w, h, locked, kx)
	local cust = C.custom[e.pt] or C.custom[charName(e, nil)]
	local name = key and ((locked and ART["lk_" .. key]) and ("lk_" .. key) or key)
	if cust and cust.anm2 then
		local s = cust.spr
		if s == nil then
			s = Sprite()
			s:Load(cust.anm2, true)
			cust.spr = s:IsLoaded() and s or false
			s = cust.spr
		end
		if s then
			s:SetFrame(locked and cust.locked_anim or cust.anim or s:GetDefaultAnimation(), 0)
			s.Scale = Vector(kx or 1, 1)
			s:Render(Vector(x, yb), ZERO, ZERO)
			s.Scale = Vector.One
			return true
		end
	end
	if name and ART[name] then
		local a = ART[name]
		local k = math.min(w / a[2], h / a[3])
		-- персонаж неподвижен (18.10: «Нет лучше вообще убери анимацию с персонажей / Оставь только партикли»)
		art(name, x, yb - a[3] * k / 2, a[2] * k, nil, locked and not ART["lk_" .. key] and Color(0.3, 0.28, 0.3, 1)
			or nil, 0, kx or 1)
		local MF = LOCALFIXES.MenuFX         -- частицы по характеру (у закрытых — нет: они взаперти)
		if MF and FLIP > 0.6 then MF.hero(not locked and key or nil, x, yb - a[3] * k / 2, a[2] * k, a[3] * k, ZERO, T) end
		return true
	end
	drawWheelPortrait(e, Vector(x, yb - h / 2), math.min(w, h) / 40, locked)
	return false
end

-- ------------------------------------------------------------------ потускневшие (Epiphany)
local TARN = {   -- дверь Epiphany → ключ рисунка, русские тексты (свойства, вещь, условие открытия)
	[0] = { "isaac_c", "Исаак", "Тесная комната · Обречён гнить", "Гнилой кубик",
		"Взорвать первый предмет сокровищницы и вернуться домой за порченого Исаака" },
	[1] = { "magdalene_c", "Магдалина", "Прилив адреналина · Неудержимая любовь", "Остановка сердца",
		"Пожертвовать «Ням-сердце», затем пройти главу 4 за порченую Магдалину" },
	[2] = { "cain_c", "Каин", "Холодное сердце", "Бросательный мешок",
		"Взять острый камень на этаже 1, затем пожертвовать урожай за порченого Каина" },
	[3] = { "judas_c", "Иуда", "Двойная боль · Между раем и адом", "Нисхождение",
		"Пройти этаж 1 без «Тёмных искусств», затем увидеть пророчество за порченого Иуду" },
	[4] = { "bluebaby_c", "???", "Нет бомб, только лужи · Запас луж", "Смесь",
		"Затаскать «Держать» в первой комнате, затем встретить судьбу за порченого ???" },
	[6] = { "samson_c", "Самсон", "Кровь даёт скорость · Бессмертная ярость", "Инстинкт убийцы",
		"Пройти 3 комнаты испытаний, затем обрушить всё за порченого Самсона" },
	[9] = { "eden_c", "Эдем", "Крайняя энтропия", "Отладка",
		"Победить босса меньше чем за минуту за порченого Эдема, затем ...!?#" },
	[10] = { "thelost_c", "Потерянный", "Заряд испытаний", "Божественные остатки",
		"Оставить карту на старте, затем собрать её в спальне за порченого Потерянного" },
	[12] = { "keeper_c", "Хранитель", "Проклятие Мидаса", "Товарооборот",
		"Открыть хранилище Мидаса в режиме «Алчнее!» за порченого Хранителя" },
}
local function epiphany()
	local E = Epiphany
	if type(E) == "table" and type(E.table_aside_type_id) == "table" and type(E.table_name) == "table"
		and E.technical_character and E.GetAchievement then
		return E
	end
end
local tarnList
local function tarnished()
	local E = epiphany()
	if not E then return nil end
	if tarnList then return tarnList end
	-- список не запоминается пустым: при первом вызове Epiphany может ещё не заполнить свои таблицы (18.10: «У тебя в
	-- целом потускневших нельзя сейчас выбрать вообще даже если есть иконка» — пустой список кэшировался навсегда)
	tarnList = {}
	for door = 0, (E.num_valid_doors or 17) - 1 do
		local pt = E.table_aside_type_id[door]
		local name = pt and E.table_name[pt]
		if pt and name and name ~= "NOT_MADE" and pt ~= E.technical_character and TARN[door] then
			tarnList[#tarnList + 1] = { door = door, pt = pt, name = name, ru = TARN[door] }
		end
	end
	if #tarnList == 0 then tarnList = nil end
	return tarnList
end
local function tarnUnlocked(t)
	local E = epiphany()
	local ok, v = pcall(E.GetAchievement, E, "CHARACTER_" .. t.name)
	return ok and (v or 0) > 0
end
-- потускневший того же персонажа, что и выбранный (для карточки версии). Двери Epiphany идут своим порядком: 0–10 —
-- как типы игроков, дальше 11 Лилит (13), 12 Хранитель (14), 13 Аполлион (15), 14 Забытый (16), 15 Вифания (18),
-- 16 Иаков (19) (18.10: «ты не добавил некоторых потускневших» — у Хранителя карточка показывала «нет»)
local DOOR_PT = { [11] = 13, [12] = 14, [13] = 15, [14] = 16, [15] = 18, [16] = 19 }
local function tarnFor(pt)
	local tl = tarnished()
	if not tl or not pt then return nil end
	local base = (pt >= 21 and pt <= 37) and TAINT_BASE[pt] or pt
	for i, t in ipairs(tl) do if (DOOR_PT[t.door] or t.door) == base then return t, i end end
end

-- ------------------------------------------------------------------ бумажки игры по краям: спрятать / вернуть
local SIDE = { "GetDifficultyPageSprite", "GetSeedPageSprite", "GetEastereggPageSprite", "GetPageSwapWidgetSprite",
	"GetWinStreakPageSprite", "GetCompletionMarksSprite", "GetDifficultyOverlaySprite", "GetGreedDecoSprite" }
local HIDE = Vector(-4000, 0)
local hidden = false
local function hideSides(on)
	if on == hidden then return end
	hidden = on
	for _, f in ipairs(SIDE) do
		local ok, s = pcall(CharacterMenu[f])
		if ok and s then s.Offset = on and HIDE or Vector.Zero end
	end
end
local function withSide(f, fn)
	local ok, s = pcall(CharacterMenu[f])
	if not (ok and s) then return end
	local o = s.Offset
	s.Offset = Vector.Zero
	pcall(fn, s)
	s.Offset = o
end
local function layerTL(s, name)
	local ok, r = pcall(function()
		local id = s:GetLayer(name):GetLayerID()
		local fr = s:GetCurrentAnimationData():GetLayer(id):GetFrame(s:GetFrame())
		if not fr or not fr:IsVisible() or fr:GetWidth() == 0 then return nil end
		return { id = id, x = fr:GetPos().X - fr:GetPivot().X, y = fr:GetPos().Y - fr:GetPivot().Y, w = fr:GetWidth(),
			h = fr:GetHeight() }
	end)
	return ok and r or nil
end
local function layerAt(s, name, p, scale)
	local t = layerTL(s, name)
	if t then
		local sc = s.Scale
		if scale then s.Scale = Vector(scale, scale) end
		s:RenderLayer(t.id, p - Vector(t.x, t.y) * (scale or 1))
		s.Scale = sc
	end
	return t
end

-- ------------------------------------------------------------------ ввод (свои края нажатий)
local prev = {}
local function edge(action)
	local p = false
	for i = 0, 3 do
		if Input.IsActionPressed(action, i) then p = true break end
	end
	local was = prev[action]
	prev[action] = p
	return p and not was
end
local function bit(a) return 1 << a end
local prevKey = {}
local function edgeKey(k)
	local p = Input.IsButtonPressed(k, 0)
	local was = prevKey[k]
	prevKey[k] = p
	return p and not was
end

-- ------------------------------------------------------------------ тон меню (тьма)
local tones = {}
-- Тон меню у порченых и потускневших убран (20.10, пользователь: «А нам обязательно вообще это затенение? В целом у нас
-- интерфейс и так меняется на более порванный. Зачем оно нам»): режим и так видно по фону (порванный лист, проклятый
-- фон), а затемнение всего меню через ColorModifier делало экран тёмным, а при сбое — тёмным навсегда (отзыв в
-- Мастерской про Ctrl). Всегда — обычный тон меню (тот, что был у игры).
local function setTone(kind)
	if not (MenuManager.SetColorModifier and ColorModifier) then return end
	local t = tones.normal
	if t then pcall(MenuManager.SetColorModifier, t, true, 0.04) end
end

-- ------------------------------------------------------------------ состояние
C.mode = "normal"          -- normal | tainted | tarnished
C.tIdx = 1
C.diffSel = 0
C.fx = nil                 -- переход режима: { kind, t }
C.flip = nil               -- переворот карточки при смене персонажа
C.slide = 0                -- переход сложность ↔ персонаж (0..1)
local function page() return CharacterMenu.GetSelectedCharacterMenu() end
local function curMode()
	if C.tarn then return "tarnished" end
	return page() == 1 and "tainted" or "normal"
end
C.curMode = curMode

-- ------------------------------------------------------------------ сложности
local DIFF = {
	{ 0, "Обычный", "Как задумано: обычные этажи и боссы", "difficulty_00", "badge_heart" },
	{ 1, "Сложный", "Больше врагов и чемпионов, меньше наград", "difficulty_01", "badge_pentagram" },
	{ 2, "Жадность", "Волны врагов в лавке, монеты решают всё", "difficulty_02", "badge_coin" },
	{ 3, "Жадность+", "Ещё злее: волны сильнее, лавка дороже", "difficulty_03", "badge_bag" },
}
local function diffOpen(d)
	if d <= 1 then return true end
	local pg = Isaac.GetPersistentGameData()
	local ach = d == 2 and (Achievement.GREED_MODE or 0) or (Achievement.GREEDIER or 0)
	if ach == 0 then return true end
	local ok, v = pcall(pg.Unlocked, pg, ach)
	return not ok or v
end

-- ------------------------------------------------------------------ переходы режимов (кровь, тьма, звуки)
local FX = { taint = 30, tarnish = 36, clean = 26, cleanse = 30 }
local function startFx(kind, action)
	C.fx = { kind = kind, t = 0, action = action }   -- action — сама смена версии, на середине переворота
	Isaac.DebugString("[localfixes] выбор: переход " .. kind .. " (страница " .. tostring(page()) .. ", потускн. "
		.. tostring(tarnished() ~= nil) .. ")")
	if kind == "taint" then
		sfx:Play(SoundEffect.SOUND_MENU_FLIP_DARK, 1, 0, false, 0.9)
		sfx:Play(SoundEffect.SOUND_HEARTBEAT, 1, 0, false, 0.85)
		sfx:Play(SoundEffect.SOUND_LAZARUS_FLIP_DEAD, 0.8, 0, false, 0.8)
	elseif kind == "tarnish" then
		sfx:Play(SoundEffect.SOUND_MENU_RIP, 1, 0, false, 0.7)
		sfx:Play(SoundEffect.SOUND_HEARTBEAT_FASTEST, 1, 0, false, 0.7)
		sfx:Play(SoundEffect.SOUND_UNHOLY, 0.7, 0, false, 0.6)
	else
		sfx:Play(SoundEffect.SOUND_MENU_FLIP_LIGHT, 1, 0, false, 1)
		sfx:Play(SoundEffect.SOUND_LAZARUS_FLIP_ALIVE, 0.7, 0, false, 1)
	end
end

-- ------------------------------------------------------------------ старт забега потускневшим (как в книге)
function C.startTarnished(t)
	local E = epiphany()
	if not (E and t) then return end
	C.pendingDoor = t.door
	local ok, seeds = pcall(MenuManager.GetSeeds)
	local diff = CharacterMenu.GetDifficulty()
	MenuManager.SetInputMask(FULLMASK)
	if ok and seeds then
		Isaac.StartNewGame(E.technical_character, Challenge.CHALLENGE_NULL, diff, seeds)
	else
		Isaac.StartNewGame(E.technical_character, Challenge.CHALLENGE_NULL, diff)
	end
end
mod:AddCallback(ModCallbacks.MC_POST_RENDER, function()
	local door = C.pendingDoor
	if not door then return end
	local E = epiphany()
	if not E then C.pendingDoor = nil return end
	if not E.character_menu_visible then return end
	C.pendingDoor = nil
	local player = Isaac.GetPlayer(0)
	local ok, err = pcall(function()
		E.current_door = door
		E:LoadMenuCharacter(player, E.table_aside_type_id[door])
		if E.DoorToPlayerReload then E:DoorToPlayerReload(player) end
		game.TimeCounter = 0
		game:Update()
		game:Fadein(0.026)
	end)
	if not ok then Isaac.DebugString("[localfixes] выбор: потускневший — " .. tostring(err)) end
end)

-- ------------------------------------------------------------------ подписи клавиш внизу
local function keycap(label, x, y)
	if label == "arrows" then                     -- все четыре стрелки (сетка: альбом предметов)
		art("cs.key2", x + 11, y - 2, 22, 9)
		art("cs.tri_up", x + 4.5, y - 2, 4, nil, nil, -90)
		art("cs.tri_up", x + 9, y - 2, 4)
		art("cs.tri_down", x + 13, y - 2, 4)
		art("cs.tri_up", x + 17.5, y - 2, 4, nil, nil, 90)
		return 22
	end
	if label == "updown" then
		art("cs.key2", x + 8, y - 2, 16, 9)
		art("cs.tri_up", x + 5, y - 2, 4)
		art("cs.tri_down", x + 11, y - 2, 4)
		return 16
	end
	local w = math.max(9, HF.Width(label, "gT") + 6)
	local piece = w <= 11 and "cs.key1" or (w <= 22 and "cs.key2" or "cs.key3")
	art(piece, x + w / 2, y - 2, w, 9)
	text(label, x + w / 2, y + 1, "gT", INK, "c")
	return w
end
local function hints(o, list)
	local x = o.X + 10
	local y = o.Y + 264
	for _, h in ipairs(list) do
		x = x + keycap(h[1], x, y) + 3
		x = x + text(HF.upper(h[2]), x, y + 1, "gT", CREAM) + 9
	end
end

-- ------------------------------------------------------------------ фон
local function drawBg(o, mode)
	local main = mode == "tarnished" and "bg_cursed" or (mode == "tainted" and "bg_tainted" or "bg_wall")
	art(main, o.X + 240, o.Y + 135, 494, 284, nil, 0, nil, nil, true)
	local MF = LOCALFIXES.MenuFX           -- за листами: пылинки, у порченых и потускневших — пепел и искры, изредка мотылёк
	if MF then
		MF.run("cs_back", o, mode == "normal" and { dust = 5, moth = 0.0012 }
			or { dust = 3, dustImg = "pa.ash", embers = mode == "tarnished" and 3 or 2, moth = 0.0006 })
	end
	local fx = C.fx
	if fx then   -- старый фон тает поверх нового
		local k = math.min(1, fx.t / FX[fx.kind])
		k = k * k * (3 - 2 * k)
		local from = (fx.kind == "taint") and "bg_wall" or (fx.kind == "tarnish" and "bg_tainted")
			or (fx.kind == "clean" and "bg_tainted" or "bg_cursed")
		art(from, o.X + 240, o.Y + 135, 494, 284, Color(1, 1, 1, 1 - k), 0, nil, nil, true)
	end
end

-- ------------------------------------------------------------------ шаг «сложность»
local function drawDifficulty(o, a)
	local t = T
	art("logo", o.X + 58, o.Y + 27, 86, nil, Color(1, 1, 1, a))
	art("cs.title_banner", o.X + 240, o.Y + 26, 170, nil, Color(1, 1, 1, a), sway(1, 0.4))
	text("ВЫБОР СЛОЖНОСТИ", o.X + 230, o.Y + 27, HF.Fit("ВЫБОР СЛОЖНОСТИ", 132, { "gL", "gM" }), Color(INK.R, INK.G, INK.B, a), "c")
	text("Насколько больно будет?", o.X + 232, o.Y + 37, "gS", Color(SOFT.R, SOFT.G, SOFT.B, a), "c")
	for i, d in ipairs(DIFF) do
		local cx = o.X + 72 + (i - 1) * 112
		local on = C.diffSel == d[1]
		local open = diffOpen(d[1])
		local lift = on and (-6 + math.sin(t * 0.08) * 1.2) or math.sin(t * 0.03 + i) * 0.6
		local cy = o.Y + 140 + lift
		local wcard = on and 100 or 92
		local lit = on and (1.1 + 0.05 * math.sin(t * 0.1)) or 0.62
		if open then
			art(d[4], cx, cy, wcard, nil, Color(lit, lit * (on and 0.98 or 1), lit * (on and 0.9 or 1), a),
				sway(i * 3, on and 0.8 or 0.4))
			text(HF.upper(d[2]), cx, cy + wcard * 0.47, on and "gM" or "gS", Color(INK.R, INK.G, INK.B, a), "c")
		else
			art("difficulty_05", cx, cy, wcard * 0.78, nil, Color(1, 1, 1, a), sway(i * 3, 0.3))
			text("ЗАКРЫТО", cx, cy + wcard * 0.47, "gS", Color(CREAM.R, CREAM.G, CREAM.B, a), "c")
		end
	end
	local d = DIFF[C.diffSel + 1]
	if d then
		art("cs.panel_wide", o.X + 240, o.Y + 236, 230, nil, Color(1, 1, 1, a), sway(7, 0.3))
		text(d[3], o.X + 240, o.Y + 239, "gS", Color(INK.R, INK.G, INK.B, a), "c")
	end
	-- пасхалки и сид — записками (родные экраны игры по Q и TAB)
	local okS, seeds = pcall(Game().GetSeeds, Game())
	local eggs = 0
	if okS and seeds and seeds.CountSeedEffects then eggs = seeds:CountSeedEffects() end
	art("cs.note_egg", o.X + 22, o.Y + 236, 26, nil, Color(1, 1, 1, a), sway(9, 1))
	text(eggs > 0 and ("x" .. eggs) or "", o.X + 30, o.Y + 248, "gS", INK)
	art("cs.note_seed", o.X + 458, o.Y + 236, 26, nil, Color(1, 1, 1, a), sway(11, 1))
	hints(o, { { "<>", "Выбор" }, { "Enter", "Дальше" }, { "Esc", "Назад" }, { "Q", "Пасхалки" }, { "Tab", "Сид" } })
end

-- ------------------------------------------------------------------ шаг «персонаж»
-- Раскладка — по образцу пользователя (docs/sources/charselect_ref/user_concept_1810.png; 18.10: «Ещё раз изучи / И
-- пойми что у тебя не так»): заглавные рукописные надписи, список слева со строкой выбранного в две строки, большая
-- карточка (бумажки отметок боссов сверху, имя, рисунок, стрелки, сердца / бомбы / ключи, «стартовые предметы»,
-- пояснение, рукописная заметка), крупные карточки версий с персонажем, справа статистика полосками, таланты PST,
-- заметки, «Начать». Ничего из меню игры (18.10: «В целом не должно быть элементов из оригинального меню Айзека») —
-- только наш арт, предметы — их спрайты в игре. Числа — замер в игре (charstats_data.lua), тексты — charsel_text.lua.
local okD, STATS_DATA = pcall(include, "charstats_data")
if not okD or type(STATS_DATA) ~= "table" then STATS_DATA = { pt = {}, door = {} } end
local okX, TEXTS = pcall(include, "charsel_text")
if not okX or type(TEXTS) ~= "table" then TEXTS = {} end
local UP = HF.upper

local L = {
	list = { x = 14, w = 110, top = 56, row = 12, sel = 25, bottom = 252 },
	card = { x = 246, y = 112, w = 214 },
	vers = { y = 212, w = 48, step = 58 },
	right = { x = 414, w = 104 },
}

-- радуга (Эдем: всё случайно — 18.10: «Окрась радужным цветом»)
local function rainbow(i)
	local h = (T * 0.012 + i * 0.13) % 1
	local r = math.abs(h * 6 - 3) - 1
	local g = 2 - math.abs(h * 6 - 2)
	local b = 2 - math.abs(h * 6 - 4)
	local cl = function(v) return math.max(0, math.min(1, v)) end
	return Color(0.35 + 0.65 * cl(r), 0.35 + 0.65 * cl(g), 0.35 + 0.65 * cl(b), 1)
end
local RANDOM = { eden = true, eden_b = true }

-- картинки модов из Workshop (tools/mod_thumbs.py → modthumbs_index.lua, лист modthumbs.anm2): по id мода
local okT, THUMBS = pcall(include, "modthumbs_index")
if not okT or type(THUMBS) ~= "table" then THUMBS = { mods = {} } end
local thumbSpr
local function thumbFrame(src)
	for _, m in ipairs(THUMBS.mods or {}) do
		if m.id == tostring(src) then return m.frame end
	end
end
local function drawThumb(src, x, y, size)
	local f = thumbFrame(src)
	if not f then return false end
	if thumbSpr == nil then
		thumbSpr = Sprite()
		thumbSpr:Load("gfx/ui/localfixes/modthumbs.anm2", true)
		if not thumbSpr:IsLoaded() then thumbSpr = false end
	end
	if not thumbSpr then return false end
	thumbSpr:SetFrame(thumbSpr:GetDefaultAnimation(), f)
	local k = size / (THUMBS.cell or 44)
	thumbSpr.Scale = Vector(k * math.max(0.01, FLIP), k)
	thumbSpr:Render(Vector(FLIPX + (x - FLIPX) * FLIP, y), ZERO, ZERO)
	thumbSpr.Scale = Vector.One
	return true
end
local SHORT = { ["3778123093"] = "FF", ["3513706025"] = "FURTH.", ["1925867065"] = "IPECAC", ["3440586497"] = "LNF",
	["3012430463"] = "EPIPHANY" }
local function tabLabel(g)
	if g.src == "BaseGame" then return "ИГРА" end
	return SHORT[tostring(g.src)] or UP(g.name):sub(1, 7)
end

-- предметы: их спрайт в игре (не меню)
local ITEMSPR = {}
local function drawItem(id, x, y, size)
	local s = ITEMSPR[id]
	if s == nil then
		local cfg = Isaac.GetItemConfig():GetCollectible(id)
		s = false
		if cfg and cfg.GfxFileName then
			s = Sprite()
			s:Load("gfx/005.100_collectible.anm2", false)
			s:ReplaceSpritesheet(1, cfg.GfxFileName)
			s:LoadGraphics()
			s:SetFrame("Idle", 0)
		end
		ITEMSPR[id] = s
	end
	if not s then return end
	s.Scale = Vector(size / 32 * math.max(0.01, FLIP), size / 32)
	s:RenderLayer(1, Vector(FLIPX + (x - FLIPX) * FLIP, y + size / 2))
end

-- данные персонажа: замер в игре
local function statsOf(e, tarn)
	if tarn then
		local d = STATS_DATA.door[tarn.door]
		return d and d[1]
	end
	local d = e and STATS_DATA.pt[e.pt]
	return d and d[1]
end
local function textsOf(key) return key and TEXTS[key] end
local function split(s) local t = {} for p in tostring(s):gmatch("[^|]+") do t[#t + 1] = p end return t end

-- отметки боссов: значок, тип отметки игры (REPENTOGON CompletionType), ключ Epiphany
local MARKS = { { "momsheart", 0, "MOMSHEART" }, { "isaac", 1, "ISAAC" }, { "satan", 2, "SATAN" }, { "bossrush", 3, "BOSSRUSH" },
	{ "bluebaby", 4, "BLUEBABY" }, { "lamb", 5, "LAMB" }, { "megasatan", 6, "MEGASATAN" }, { "greed", 7, "GREED", 11 },
	{ "hush", 9, "HUSH" }, { "delirium", 12, "DELIRIUM" }, { "mother", 13, "MOTHER" }, { "beast", 14, "BEAST" } }
local function markOf(e, tarn, m)
	if tarn then
		local E = epiphany()
		local ok, v = pcall(E.GetCompletionMark, E, tarn.name, m[3])
		return ok and (v or 0) or 0
	end
	if not e or e.random then return 0 end
	local ok, v = pcall(Isaac.GetCompletionMark, e.pt, m[2])
	v = ok and v or 0
	if m[4] then   -- «Жадность+» засчитывает и обычную «Жадность» как сложную отметку
		local ok2, v2 = pcall(Isaac.GetCompletionMark, e.pt, m[4])
		if ok2 and (v2 or 0) > 0 then v = 2 end
	end
	return v
end

-- ------------------------------------------------------------------ закладки модов и талантов
local function drawTabs(o, groups, active)
	local list = {}
	for _, g in ipairs(groups) do list[#list + 1] = { kind = "mod", g = g } end
	local cc = charcard()
	local hasPST = PST and PST.modData and cc and cc.pst and cc.pst()
	list[#list + 1] = { kind = "talents", off = not hasPST }
	local step = math.min(30, 168 / math.max(1, #list))
	local x = o.X + 466 - (#list - 1) * step - 13
	for i, it in ipairs(list) do
		local on = it.kind == "mod" and it.g == active
		local cx = x + (i - 1) * step
		local cy = o.Y + (on and 15 or 17) + math.sin(T * 0.04 + i) * 0.4
		if it.kind == "talents" then
			art(it.off and "g_cs.tab_talents" or "cs.tab_talents", cx, cy, 26, nil, nil, sway(i, 0.6))
			if not it.off then
				art("cs.tab_talents", cx, cy, 26, nil, Color(1.4, 1.4, 1.8, 0.12 + 0.1 * math.sin(T * 0.08)), sway(i, 0.6))
			end
			text("ТАЛАНТЫ", cx, o.Y + 35, "gT", it.off and SOFT or CREAM, "c")
		else
			art(on and "cs.tab_on" or "cs.tab", cx, cy, on and 28 or 25, nil, on and nil or Color(0.7, 0.66, 0.66, 1),
				sway(i, 0.5))
			if it.g.src == "BaseGame" then
				art("isaac", cx, cy + 2, nil, 15)
			elseif not drawThumb(it.g.src, cx, cy + 2, 14) then
				text(tabLabel(it.g):sub(1, 2), cx, cy + 5, "gS", CREAM, "c")
			end
			text(tabLabel(it.g), cx, o.Y + 35, "gT", on and CREAM or Color(0.72, 0.66, 0.64, 1), "c")
		end
	end
end

-- ------------------------------------------------------------------ список слева
local function rowSubtitle(e, mode)
	if e.random then return "СЛУЧАЙНЫЙ ПЕРСОНАЖ" end
	if e.locked then return "ЕЩЁ НЕ ОТКРЫТ" end
	if e.tarn then return "ПОТУСКНЕВШИЙ · EPIPHANY" end
	if mode == "tainted" then return "ПОРЧЕНЫЙ" end
	if e.src == "BaseGame" then return "БАЗОВЫЙ ПЕРСОНАЖ" end
	return UP(modLabel(e.src))
end
local function drawList(o, items, sel, mode)
	local Ls = L.list
	local selIdx = 1
	for i, e in ipairs(items) do if e == sel then selIdx = i end end
	local visible = math.floor((Ls.bottom - Ls.top - Ls.sel) / Ls.row) + 1
	local first = math.max(1, math.min(selIdx - math.floor(visible / 2), #items - visible + 1))
	C.scroll = C.scroll and (C.scroll + (first - C.scroll) * 0.25) or first
	local y = o.Y + Ls.top - (C.scroll - 1) * Ls.row
	for i, e in ipairs(items) do
		local on = e == sel
		local h = on and Ls.sel or Ls.row
		local cy = y + h / 2
		if cy > o.Y + Ls.top - 6 and cy < o.Y + Ls.bottom + 4 then
			local dx = on and 3 or 0
			local cx = o.X + Ls.x + Ls.w / 2 + dx
			art(on and "cs.row_sel" or (e.locked and "cs.row_locked" or "cs.row"), cx, cy, on and Ls.w + 6 or Ls.w, h - 1,
				nil, sway(i, 0.2))
			local key = e.tarn and e.tarn.ru[1] or charKey(e.pt)
			local hx = o.X + Ls.x + 11 + dx
			if e.random then
				text("?", hx, cy + 4, "gM", rainbow(i), "c")
			elseif key and ART["hd_" .. key] then
				art("hd_" .. key, hx, cy, nil, on and 15 or 11, e.locked and Color(0.3, 0.27, 0.28, 1) or nil)
			end
			local nm = e.random and "СЛУЧАЙНЫЙ" or UP(e.tarn and e.tarn.ru[2] or charName(e, key))
			local tc = e.tarn and TARNC or (e.locked and Color(0.42, 0.39, 0.39, 1) or INK)
			if on then
				text(nm, hx + 9, cy + 1.5, HF.Fit(nm, 80, { "gM", "gS" }), tc)
				text(rowSubtitle(e, mode), hx + 9, cy + 8.5, "gT", SOFT)
			else
				text(nm, hx + 9, cy + 3, HF.Fit(nm, 80, { "gS", "gT" }), tc)
			end
			if e.locked and on then art("cs.padlock", o.X + Ls.x + Ls.w - 9 + dx, cy, 7) end
		end
		y = y + h
	end
	-- полоса прокрутки
	local top, bot = o.Y + Ls.top, o.Y + Ls.bottom
	art("cs.scroll_track", o.X + 7, (top + bot) / 2, nil, bot - top, Color(0.55, 0.45, 0.4, 1))
	local frac = (#items > 1) and ((selIdx - 1) / (#items - 1)) or 0
	art("cs.scroll_thumb", o.X + 7, top + 8 + frac * (bot - top - 16), nil, 16)
	art("cs.tri_up", o.X + 7, top - 5, 6)
	art("cs.tri_down", o.X + 7, bot + 5, 6)
end

-- ------------------------------------------------------------------ большая карточка
local function drawMarkTags(cx, top, e, tarn)
	for i, m in ipairs(MARKS) do
		local left = i <= 6
		local x = left and (cx - 98 + (i - 1) * 13.5) or (cx + 30 + (i - 7) * 13.5)
		local v = markOf(e, tarn, m)
		local swing = math.sin(T * 0.03 + i * 1.3) * 2
		local tag = v == 2 and "bo.tag_red" or (v == 1 and "bo.tag" or "bo.tag_dirty")
		art(tag, x, top + 4, 12, nil, v == 0 and Color(0.62, 0.58, 0.56, 0.85) or nil, swing)
		local ra = math.rad(swing)
		local ix, iy = x - 1.5 * math.sin(ra), top + 4 + 1.5 * math.cos(ra)   -- центр бумажки + (0, 1.5) с поворотом
		x = ix
		-- не пройдено — блёклая тень значка; обычная сложность — значок; сложная — кровавый значок (пульсирует)
		if v == 2 then
			local pul = 1 + 0.08 * math.sin(T * 0.09 + i)
			art("bo.h_" .. m[1], x, iy, 8 * pul, nil, nil, swing)
		else
			art("bo." .. m[1], x, iy, 7.5, nil, v == 0 and Color(0.25, 0.23, 0.23, 0.4) or nil, swing)
		end
	end
end

local function drawResources(x, y, st, random)
	art("cs.panel_wide_pin", x + 17, y + 9, 54, 34, nil, sway(25, 0.6))
	x, y = x - 2, y + 3
	if random then
		text("? ? ?", x + 16, y + 3, "gM", rainbow(1), "c")
		text("? ? ?", x + 16, y + 15, "gM", rainbow(4), "c")
		return
	end
	if not st then return end
	-- сердца: красные (половинки по 2), синие, чёрные, костяные — значки по одному на целое сердце
	local list = {}
	for _ = 1, math.floor(st.red / 2) do list[#list + 1] = "st.heart_red" end
	for _ = 1, math.floor(st.soul / 2) do list[#list + 1] = "st.heart_soul" end
	for _ = 1, math.floor((st.black or 0) / 2) do list[#list + 1] = "st.heart_black" end
	for _ = 1, st.bone or 0 do list[#list + 1] = "st.heart_bone" end
	local n = 0
	for i, nm in ipairs(list) do
		if i > 8 then break end
		local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
		art(nm, x + col * 8.5, y + row * 8, 8, nil, nil, math.sin(T * 0.05 + i) * 3)
		n = row
	end
	local yy = y + (n + 1) * 8 + 4
	local res = { { "st.bomb", st.bombs }, { "st.key", st.keys }, { "st.coin", st.coins } }
	local xx = x
	for _, r in ipairs(res) do
		art(r[1], xx, yy, 6.5)
		xx = xx + 4 + text(tostring(r[2]), xx + 4, yy + 3, "gS", INK) + 6
	end
end

local function drawCard(o, e, key, mode, tarn)
	local Lc = L.card
	local f = C.flip
	local kx = 1
	if f then
		f.t = f.t + (LOCALFIXES.MenuDT or 1)
		kx = math.abs(math.cos(math.min(1, f.t / 12) * math.pi))
		if f.t >= 12 then C.flip = nil end
	end
	local cx, cy = o.X + Lc.x, o.Y + Lc.y
	-- лист по версии (18.10: «сам листик на котором персонаж надо тоже менять в зависимости от обычной/порченной/
	-- потускневшей версией / Просто сделай чуть рванее»): порченый — рванее, потускневший — рваный и обугленный
	-- (tools/paper_tear.py; верх и места, где что-то приколото, не рвутся)
	local sheet = (tarn or mode == "tarnished") and "cs.card_x" or (mode == "tainted" and "cs.card_t" or "cs.card")
	if not ART[sheet] then sheet = "cs.card" end
	local _, W, H = art(sheet, cx, cy, Lc.w, nil, nil, sway(21, 0.25), math.max(0.02, kx), 1)
	H = H > 0 and H or 145
	if kx < 0.2 then return end
	local top = cy - H / 2
	local locked = (tarn and tarn.locked) or (e and e.locked)
	local random = (not tarn) and (e and (e.random or RANDOM[key or ""]))
	drawMarkTags(cx, top, e, tarn)
	-- имя
	local nm = tarn and ("ПОТУСКН. " .. UP(tarn.ru[2])) or (e and (e.random and "СЛУЧАЙНЫЙ" or UP(charName(e, key, true)))) or "?"
	text(nm, cx - 12, top + 30, HF.Fit(nm, 128, { "gL", "gM" }), tarn and TARNC or INK, "c")
	-- рисунок
	local hk = tarn and tarn.ru[1] or key
	if e and e.random and not tarn then
		text("?", cx - 14, cy + 22, "gX", rainbow(2), "c", 2)
	elseif hk and (ART[hk] or ART["lk_" .. hk]) then
		drawHero(tarn and { pt = tarn.pt } or e, hk, cx - 20, cy + 40, 90, 72, locked, kx)
	elseif e then
		drawHero(e, nil, cx - 20, cy + 40, 90, 72, locked, kx)
	end
	-- стрелки ‹ › покачиваются навстречу
	local pulse = math.sin(T * 0.1) * 1.5
	art("cs.arrow_l", cx - 78 - pulse, cy + 4, 11)
	art("cs.arrow_r", cx + 38 + pulse, cy + 4, 11)
	-- сердца, бомбы, ключи, монеты
	local st = statsOf(e, tarn)
	if not locked then drawResources(cx + 58, cy - 33, st, random) end
	-- стартовые предметы (коробочка на карточке)
	local bx, by = cx + 70, cy + 18
	text("СТАРТОВЫЕ", bx, by - 6, "gT", SOFT, "c")
	text("ПРЕДМЕТЫ", bx, by, "gT", SOFT, "c")
	if random then
		text("?  ?  ?", bx, by + 18, "gM", rainbow(3), "c")
	elseif locked then
		art("cs.padlock", bx, by + 15, 9)
	elseif st then
		local ids = {}
		for _, id in ipairs(st.actives or {}) do ids[#ids + 1] = id end
		for _, id in ipairs(st.items or {}) do ids[#ids + 1] = id end
		local n = math.min(3, #ids)
		for i = 1, n do drawItem(ids[i], bx - (n - 1) * 7.5 + (i - 1) * 15 - 7, by + 7, 14) end
		if n == 0 then text(HF.L("НЕТ", "NONE"), bx, by + 18, "gS", SOFT, "c") end
	end
	-- пояснение (полоска внизу) и рукописная заметка
	local tx = textsOf(tarn and tarn.ru[1] or key)
	art("cs.panel_wide", cx - 8, cy + 48, 128, 18, nil, sway(23, 0.2))
	local lines
	if locked then
		lines = { "ЕЩЁ НЕ ОТКРЫТ", "КАК ОТКРЫТЬ — В ЗАМЕТКАХ" }
	elseif e and e.random then
		lines = { "КТО УГОДНО", "ИЗ ОТКРЫТЫХ" }
	else
		lines = tx and split(UP(tx[1])) or { UP(modLabel(e and e.src or "BaseGame")) }
	end
	for i = 1, math.min(2, #lines) do
		local s = lines[i]
		text(s, cx - 8, cy + 46 + (i - 1) * 7 + (#lines == 1 and 3 or 0), HF.Fit(s, 120, { "gT" }), locked and TARNC or INK, "c")
	end
	if tx and tx[2] and not locked then
		local nl = HF.Wrap(tx[2], "gS", 44, 2)
		for i, s in ipairs(nl) do text(s, cx - 101, cy - 22 + (i - 1) * 8, "gS", SOFT) end
	end
end

-- ------------------------------------------------------------------ карточки версий
local function versionsOf(e)
	if not e or e.random then return nil end
	local cfg = EntityConfig.GetPlayer(e.pt)
	local okT2, other = pcall(function() return cfg:GetTaintedCounterpart() end)
	local otherPt = okT2 and other and other:GetPlayerType() or nil
	local nPt, tPt = e.pt, otherPt
	if page() == 1 then nPt, tPt = otherPt, e.pt end
	return nPt, tPt
end
local function drawVersions(o, e, mode, tl)
	local nPt, tPt = versionsOf(e)
	local tarnT = mode == "tarnished" and tl and tl[C.tIdx] or (nPt and tarnFor(nPt))
	local hasEp = epiphany() ~= nil
	local cards = {
		{ "normal", "ОБЫЧНЫЙ", "cs.vcard", nPt },
		{ "tainted", "ПОРЧЕНЫЙ", "cs.vcard_tainted", tPt, missing = not tPt },
		{ "tarnished", "ПОТУСКНЕВШИЙ", hasEp and "cs.vcard_tarnished" or "g_cs.vcard_tarnished", tarn = tarnT,
			missing = not hasEp or not tarnT, nomod = not hasEp },
	}
	local V = L.vers
	for i, c in ipairs(cards) do
		local cx, cy = o.X + L.card.x - V.step + (i - 1) * V.step, o.Y + V.y
		local on = c[1] == mode
		local bob = on and math.sin(T * 0.08) * 0.8 or 0
		local lit = on and (1.12 + 0.05 * math.sin(T * 0.1)) or 0.62
		local w = on and V.w + 4 or V.w
		local col = c.nomod and Color(0.8, 0.8, 0.8, 1) or Color(lit, lit * (on and 0.97 or 1), lit * (on and 0.88 or 1), 1)
		art(c[3], cx, cy + bob - (on and 2 or 0), w, nil, col, sway(30 + i, on and 0.6 or 0.25))
		local key, locked
		if c[1] == "tarnished" and c.tarn then
			key = c.tarn.ru[1]
			locked = not tarnUnlocked(c.tarn)
		elseif c[4] then
			key = charKey(c[4])
			locked = not unlocked(c[4])
		end
		if c.nomod then
			text("ТОЛЬКО С", cx, cy - 1, "gT", CREAM, "c")
			text("EPIPHANY", cx, cy + 6, "gT", CREAM, "c")
		elseif c.missing then
			text(HF.L("НЕТ", "NONE"), cx, cy + 3, "gS", Color(0.6, 0.56, 0.55, 1), "c")
		elseif key and ART[key] then
			local a = ART[key]
			local fw, fh = w * 0.5, w * 0.56
			local k = math.min(fw / a[2], fh / a[3])
			art(key, cx, cy + bob - 2, a[2] * k, nil, locked and Color(0.22, 0.2, 0.22, 1) or (on and nil or Color(0.7, 0.68, 0.68, 1)))
			if locked then art("cs.padlock", cx, cy + bob + 2, 9) end
		end
		text(c[2], cx, cy + 30, "gT", on and CREAM or Color(0.72, 0.66, 0.64, 1), "c")
	end
	if C.canSwap ~= false then           -- у персонажа без порченой версии переключать нечего — значка E нет
		local kx = o.X + L.card.x - V.step - 38
		art("cs.key1", kx, o.Y + V.y, 11)
		text("E", kx, o.Y + V.y + 3, "gS", INK, "c")
	end
end

-- ------------------------------------------------------------------ правая колонка
local STAT_ROWS = {
	{ "st.heart_red", "ЗДОРОВЬЕ", function(s) return ((s.red or 0) + (s.soul or 0) + (s.black or 0)) / 2 + (s.bone or 0) end },
	{ "st.damage", "УРОН", function(s) return s.damage / 1.5 end },
	{ "st.speed", "СКОРОСТЬ", function(s) return s.speed * 2 end },
	{ "st.range", "ДАЛЬНОСТЬ", function(s) return s.range / 3 end },
	{ "st.tears", "СКОРОСТРЕЛ.", function(s) return s.tears * 1.3 end },
	{ "st.luck", "УДАЧА", function(s) return (s.luck or 0) + 1 end },
}
local function drawStats(x, y, st, random, locked)
	art("cs.panel_redpin", x, y, L.right.w, 88, nil, sway(41, 0.25))
	-- заголовок по центру, ниже булавки (18.10: «Сделай по сверху по центру статистику и заметки и чуть чуть сдвинь вниз
	-- / Чтобы оно не наезжала на булавку»)
	text("СТАТИСТИКА", x, y - 15, "gM", INK, "c")
	for i, r in ipairs(STAT_ROWS) do
		local yy = y - 4 + (i - 1) * 7.6
		art(r[1], x - 44, yy, 8)
		text(r[2], x - 38, yy + 2.5, "gT", INK)
		local n = 0
		if st and not locked and not random then n = math.max(0, math.min(8, math.floor(r[3](st) + 0.5))) end
		for k = 1, 8 do
			local sx = x + 6 + (k - 1) * 5.4
			if random then
				art("cs.seg", sx, yy, 5, 4, rainbow(i + k * 0.35))
			else
				art(k <= n and "cs.seg_full" or "cs.seg", sx, yy, 5, 4, k <= n and nil or Color(0.85, 0.82, 0.82, 1))
			end
		end
	end
	if random then text("СЛУЧАЙНО!", x + 27, y + 40, "gT", rainbow(9), "c") end
end

local function drawTalents(x, y)
	local cc = charcard()
	local pd = PST and PST.modData and cc and cc.pst and cc.pst()
	if not pd then
		art("g_cs.cosmic_wide", x, y, L.right.w, 34, nil, sway(45, 0.25))
		text("ТАЛАНТЫ", x - 44, y - 3, "gM", Color(0.85, 0.85, 0.85, 1))
		text("ТОЛЬКО С МОДОМ PASSIVE SKILL TREES", x, y + 9, "gT", Color(0.9, 0.9, 0.9, 1), "c")
		return
	end
	art("cs.cosmic_wide", x, y, L.right.w, 34, nil, sway(45, 0.25))
	art("cs.cosmic_wide", x, y, L.right.w, 34, Color(1.3, 1.3, 1.6, 0.16 * (0.5 + 0.5 * math.sin(T * 0.07))), sway(45, 0.25))
	text("ТАЛАНТЫ", x - 44, y + 1, "gM", CREAM)
	text("УР. " .. pd.level .. (pd.sp > 0 and (" · ОЧКОВ " .. pd.sp) or ""), x - 44, y + 11, "gS", CREAM)
	text("V — ДЕРЕВО", x + 46, y + 11, "gT", Color(0.8, 0.82, 1, 1), "r")
end

local function notesOf(e, key, tarn)
	local cc = charcard()
	if e and not tarn and not e.random and cc and cc.info then
		local ok, d = pcall(cc.info, e.pt)
		local tr = ok and d and d.traits
		if type(tr) == "string" and tr ~= "" then
			tr = tr:gsub("{{.-}}", ""):gsub("%s*#%s*", "|"):gsub("^|", "")
			return split(tr)
		end
	end
	local tx = textsOf(tarn and tarn.ru[1] or key)
	return tx and split(tx[3]) or {}
end
local function drawNotes(x, y, e, key, tarn, locked)
	art("cs.notes", x, y, L.right.w, 72, nil, sway(43, 0.25))
	text("ЗАМЕТКИ", x, y - 6, "gM", INK, "c")            -- по центру, ниже булавки
	if locked then
		local how = tarn and tarn.ru[5] or (TEXTS.unlock and TEXTS.unlock[key or ""])
			or ("Открывается в моде " .. modLabel(e and e.src or "BaseGame") .. ".")
		text("КАК ОТКРЫТЬ:", x - 45, y + 4, "gS", TARNC)
		-- не влезает в 4 строки (английский длиннее) — мельче, до 5 строк
		local size, lh, lines = "gS", 7.5, HF.Wrap(how, "gS", 90)
		if #lines > 4 then size, lh, lines = "gT", 6, HF.Wrap(how, "gT", 90, 5) end
		local yy = y + 12
		for _, s2 in ipairs(lines) do
			text(s2, x - 45, yy, size, INK)
			yy = yy + lh
		end
		return
	end
	-- заметки: 4 строки кеглем gS; не влезают (английский длиннее) — кеглем gT, до 6 строк
	local size, lh, all = "gS", 7.5, {}
	for _, para in ipairs(notesOf(e, key, tarn)) do
		for _, s in ipairs(HF.Wrap(para, "gS", 90, 3)) do all[#all + 1] = s end
	end
	if #all > 4 then
		size, lh, all = "gT", 6, {}
		for _, para in ipairs(notesOf(e, key, tarn)) do
			for _, s in ipairs(HF.Wrap(para, "gT", 90, 3)) do all[#all + 1] = s end
		end
	end
	local yy = y + 4
	for _, s in ipairs(all) do
		if yy > y + 34 then return end
		text(s, x - 45, yy, size, INK)
		yy = yy + lh
	end
end

local function drawStart(x, y, ready)
	art("cs.start", x, y, L.right.w, nil, ready and nil or Color(0.6, 0.55, 0.55, 1), sway(47, 0.4))
	text("НАЧАТЬ", x - 2, y + 5, "gL", ready and INK or SOFT, "c")
	local d = DIFF[CharacterMenu.GetDifficulty() + 1]
	if d then art("cs." .. d[5], x - 44, y, 12, nil, nil, sway(49, 2)) end
end

-- ------------------------------------------------------------------ главный цикл
local custom
local enabled = true
local wasOn = false

local function screenOn()
	if not enabled or not (CharacterMenu and MenuManager and MenuManager.IsActive and MenuManager.IsActive()) then return false end
	return CharacterMenu.GetActiveStatus() ~= 1          -- набор сида — родной экран
end

mod:AddCallback(ModCallbacks.MC_PRE_RENDER_CHARACTER_SELECT_PAGE, function(_, pt, pos, vanilla, cus)
	custom = cus
	if screenOn() then return false end
end)
mod:AddCallback(ModCallbacks.MC_PRE_RENDER_CHARACTER_SELECT_PORTRAIT, function()
	if screenOn() then return false end
end)

local TAINTED = {}
local function taintedOf(pt)
	if TAINTED[pt] == nil then
		local ok, r = pcall(function()
			local c = EntityConfig.GetPlayer(pt)
			return c ~= nil and (c:IsTainted() or c:GetTaintedCounterpart() ~= nil)
		end)
		TAINTED[pt] = ok and r or false
	end
	return TAINTED[pt]
end
local function input(onMenu, mode, sel, list, groups, tl, hasTainted)
	-- поверх открыто дерево Passive Skill Trees (V / LB на выбранном персонаже): клавиши — его, маску ввода меню ставит
	-- PST при открытии; своя маска каждый кадр её перебивала, и Q («дерево персонажа» в PST) открывал у игры «Пасхалки»
	-- (19.10, пользователь: «таланты должны открываться на персонажах в меню выбора персонажа / Чтобы каждое дерево
	-- соответствовало нужному»)
	local P = rawget(_G, "PST")
	if type(P) == "table" and type(P.treeScreen) == "table" and P.treeScreen.open then
		C.ePress = false
		C.treeHold = Isaac.GetFrameCount() + 3   -- клавиша, которой дерево закрыли (Esc), не должна дойти до нас
		return
	end
	if C.treeHold and Isaac.GetFrameCount() < C.treeHold then
		C.ePress = false
		return
	end
	-- Страницу «обычный ↔ порченый» переворачивает сама игра (её кнопка — MENURB: E на клавиатуре, RB на геймпаде,
	-- или как игрок переназначил), её не перехватить. Переходы и тон меню запускаются по тому, что страница ПРАВДА
	-- перевернулась, а не по клавише (20.10, отзыв в Мастерской: «pressing ctrl on the character select makes it
	-- spin which seems to do nothing other than play a noise and permanently darken the menu» — раньше переход
	-- запускали E или MENUEX, а MENUEX — это Ctrl: начинался переход к потускневшим, игра страницу не переворачивала,
	-- и тёмный тон оставался навсегда). Поверх — третий режим «потускневший»: игра перевернула порченых на обычных, а у
	-- Epiphany есть потускневшие → мы возвращаем страницу порченых и включаем потускневших; с потускневших игра
	-- переворачивает на обычных.
	-- переворот засчитывается, только если страница сменилась вскоре после кнопки переворота игры (MENURB: E на
	-- клавиатуре, RB на геймпаде): страницу меняет и сама игра (вход на экран, старт забега), это не переход
	-- игра переворачивает страницу не сразу, а после своей анимации (20.10: с окном в 20 кадров переход не
	-- засчитывался — «Теперь в целом не работает переключение на потускневших»): нажатие и смена страницы
	-- сводятся в пределах секунды в любом порядке
	local fc = Isaac.GetFrameCount()
	if edge(ButtonAction.ACTION_MENURB) or edgeKey(Keyboard.KEY_E) then C.flipAt = fc end
	local pg = page()
	if C.lastPage ~= nil and pg ~= C.lastPage then C.pageAt = fc end
	C.lastPage = pg
	if C.flipAt and fc - C.flipAt > 60 then C.flipAt = nil end
	if C.pageAt and fc - C.pageAt > 60 then C.pageAt = nil end
	local flipped = C.flipAt ~= nil and C.pageAt ~= nil
	if flipped then C.flipAt, C.pageAt = nil, nil end
	C.ePress = flipped
	if onMenu and C.phase == "char" and flipped and not C.fx then
		if C.tarn then
			startFx("cleanse", function() C.tarn = false setTone("normal") end)
		elseif pg == 0 and tl then
			local _, idx = tarnFor(sel and sel.pt or -1)
			C.pendingTarn = idx or C.tIdx
			startFx("tarnish", function() setTone("tarnished") end)
		elseif pg == 0 then
			startFx("clean", function() setTone("normal") end)
		elseif hasTainted then
			startFx("taint", function() setTone("tainted") end)
		end
	end
	if not (onMenu and CharacterMenu.GetActiveStatus() == 0) then
		if not onMenu then
			MenuManager.SetInputMask(FULLMASK)
			C.tarn = false
		end
		return
	end
	local A = ButtonAction
	if C.phase == "diff" then
		MenuManager.SetInputMask(FULLMASK & ~bit(A.ACTION_MENULEFT) & ~bit(A.ACTION_MENURIGHT) & ~bit(A.ACTION_MENUUP)
			& ~bit(A.ACTION_MENUDOWN) & ~bit(A.ACTION_MENUCONFIRM) & ~bit(A.ACTION_MENUEX))
		local d = C.diffSel
		if edge(A.ACTION_MENULEFT) then d = (d - 1) % 4 elseif edge(A.ACTION_MENURIGHT) then d = (d + 1) % 4 end
		if d ~= C.diffSel then
			C.diffSel = d
			sfx:Play(SoundEffect.SOUND_MENU_SCROLL, 1, 0, false, 1)
		end
		if edge(A.ACTION_MENUCONFIRM) then
			if diffOpen(C.diffSel) then
				CharacterMenu.SetDifficulty(C.diffSel)
				C.phase = "char"
				C.slideT = 0
				sfx:Play(SoundEffect.SOUND_BOOK_PAGE_TURN_12, 1, 0, false, 1)
			else
				sfx:Play(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.6, 0, false, 1.2)
			end
		end
		return
	end
	-- шаг «персонаж»: ↑/↓ — по списку (сложность — на своём шаге), Esc — назад к сложности
	local mask = FULLMASK & ~bit(A.ACTION_MENUUP) & ~bit(A.ACTION_MENUDOWN) & ~bit(A.ACTION_MENUBACK)
		& ~bit(A.ACTION_MENULEFT) & ~bit(A.ACTION_MENURIGHT)
	if not hasTainted then        -- нет порченой версии: игре не отдаём переворот страницы (E — действие «бомба», геймпад — RT)
		mask = mask & ~bit(A.ACTION_BOMB) & ~bit(A.ACTION_MENURT)
	end
	if C.tarn then mask = mask & ~bit(A.ACTION_MENUCONFIRM) end
	MenuManager.SetInputMask(mask)
	if edge(A.ACTION_MENUBACK) then
		C.phase = "diff"
		C.slideT = 0
		sfx:Play(SoundEffect.SOUND_BOOK_PAGE_TURN_12, 0.9, 0, false, 0.9)
		return
	end
	-- игра перевернула порченых на обычных — вернуть страницу порченых и включить потускневших
	if C.pendingTarn and CharacterMenu.GetActiveStatus() == 0 and page() == 0 then
		pcall(CharacterMenu.SetSelectedCharacterMenu, 1, true)
		C.lastPage, C.pageAt = 1, nil          -- свой переворот — не переход
		C.tarn, C.tIdx, C.pendingTarn = true, C.pendingTarn, nil
	end
	local function step(dir)
		if C.tarn and tl then
			C.tIdx = (C.tIdx - 1 + dir) % #tl + 1
		elseif sel then
			local i = 1
			for k, e in ipairs(list) do if e == sel then i = k end end
			local ne = list[(i - 1 + dir) % #list + 1]
			if ne then CharacterMenu.SetSelectedCharacterID(ne.id) end
		end
		sfx:Play(SoundEffect.SOUND_MENU_SCROLL, 1, 0, false, 0.95)
	end
	local up, lf, dn, rt = edge(A.ACTION_MENUUP), edge(A.ACTION_MENULEFT), edge(A.ACTION_MENUDOWN), edge(A.ACTION_MENURIGHT)
	if not sel and not C.tarn and list[1] then CharacterMenu.SetSelectedCharacterID(list[1].id) end   -- служебная позиция
	if up or lf then step(-1) elseif dn or rt then step(1) end
	if C.tarn and tl then
		if edge(A.ACTION_MENUCONFIRM) then
			local t = tl[C.tIdx]
			if t and tarnUnlocked(t) then
				sfx:Play(SoundEffect.SOUND_MENU_CHARACTER_SELECT, 1, 0, false, 0.8)
				C.startTarnished(t)
			else
				sfx:Play(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.6, 0, false, 1.2)
			end
		end
	elseif sel then
		local dir = (edge(A.ACTION_MENULT) and -1) or (edge(A.ACTION_MENURT) and 1) or 0
		if dir ~= 0 then
			for i, g in ipairs(groups) do
				if g == sel.group then
					local ng = groups[(i - 1 + dir) % #groups + 1]
					if ng and ng.items[1] then CharacterMenu.SetSelectedCharacterID(ng.items[1].id) end
					break
				end
			end
		end
	end
end

local lastSel
local function render()
	if not screenOn() then
		hideSides(false)
		C.active = false
		if wasOn then wasOn = false end
		return
	end
	-- пока открыт экран выбора — он с первого кадра стоит на месте, даже если камера игры ещё едет; ушли с него — сразу
	-- не рисуется (18.10: «Там дергается между переходами меню / Примерно на 1 кадр и пропадает»; «Между главный меню и
	-- новым забегом этот баг видно явнее» — запись 60 кадров/с: в первом кадре перехода экран рисовался по камере, внизу,
	-- а сверху на 2 кадра проглядывало родное главное меню: этот колбэк идёт раньше, чем menu_screens ставит MenuFixed)
	local o = C.stage()
	if MenuManager.GetActiveMenu() ~= MainMenuType.CHARACTER then
		C.active = false
		MenuManager.SetInputMask(FULLMASK)
		-- ушли с экрана: при следующем входе — снова с выбора сложности (18.10: «При выборе нового забега у тебя сразу
		-- выходит экран выбора персонажа а не выбор сложности»); но из пасхалок (Q) — назад к персонажу, где были (19.10)
		local m = MenuManager.GetActiveMenu()
		if wasOn then
			C.backToChar = m == MainMenuType.SPECIALSEEDS and C.phase == "char"
		elseif m ~= MainMenuType.SPECIALSEEDS then
			C.backToChar = nil
		end
		wasOn = false
		return
	end
	if o.X > Isaac.GetScreenWidth() or o.X < -480 or o.Y > Isaac.GetScreenHeight() or o.Y < -270 then
		C.active = false
		return
	end
	T = T + (LOCALFIXES.MenuDT or 1)
	hideSides(true)
	local onMenu = MenuManager.GetActiveMenu() == MainMenuType.CHARACTER
	if onMenu and not wasOn then           -- зашли на экран — начинаем со сложности (как выбрана в игре)
		for _, a in ipairs({ ButtonAction.ACTION_MENUCONFIRM, ButtonAction.ACTION_MENUBACK, ButtonAction.ACTION_MENULEFT,
			ButtonAction.ACTION_MENURIGHT, ButtonAction.ACTION_MENUUP, ButtonAction.ACTION_MENUDOWN, ButtonAction.ACTION_MENUEX,
			ButtonAction.ACTION_MENULT, ButtonAction.ACTION_MENURT }) do
			edge(a)                            -- нажатие, которым сюда пришли, не считается новым
		end
		C.phase = C.backToChar and "char" or "diff"
		C.backToChar = nil
		C.lastPage, C.pageAt, C.flipAt = nil, nil, nil   -- страница, с которой пришли, — не переворот
		C.diffSel = CharacterMenu.GetDifficulty()
		C.slideT = 30
	end
	wasOn = onMenu
	C.active = onMenu
	if page() == 0 and not C.tarn and not tones.normal and MenuManager.GetTargetColorModifier then
		local ok, t = pcall(MenuManager.GetTargetColorModifier)
		if ok and t then tones.normal = ColorModifier(t.R, t.G, t.B, t.A, t.Brightness, t.Contrast) end
	end
	local mode = curMode()
	local list, groups = wheel()
	local selId = CharacterMenu.GetSelectedCharacterID()
	local sel
	for _, e in ipairs(list) do
		if e.id == selId then sel = e end
		e.locked = not e.random and not unlocked(e.pt)
	end
	-- нет порченой версии, а игра всё же перевернула страницу (клавишу E она читает сама, маской не закрыть) — сразу
	-- назад на обычную (18.10: «Если персонаж не имеет порченной и потускневший версии то он не должен переключаться»)
	if onMenu and page() == 1 and not C.tarn and not C.pendingTarn and sel and not sel.random
		and CharacterMenu.GetActiveStatus() == 0 and not taintedOf(sel.pt) then
		pcall(CharacterMenu.SetSelectedCharacterMenu, 0, true)
		C.lastPage, C.pageAt = 0, nil
		C.fx = nil
		mode = curMode()
	end
	local tl = tarnished()
	-- есть ли у выбранного порченая версия — по данным игры (18.10: «Если персонаж не имеет порченной и потускневший
	-- версии то он не должен переключаться»); значок переворота игра показывает у всех, поэтому по нему нельзя
	local hasTainted = mode ~= "normal" or (sel and (sel.random or taintedOf(sel.pt))) or false
	C.canSwap = hasTainted and true or false
	input(onMenu, mode, sel, list, groups, tl, hasTainted)
	mode = curMode()
	FLIP = 1
	if C.fx then
		local fx = C.fx
		fx.t = fx.t + (LOCALFIXES.MenuDT or 1)
		local half = FX[fx.kind] / 2
		if fx.action and fx.t >= half then fx.action() fx.action = nil end
		local k = fx.t < half and (1 - fx.t / half) or ((fx.t - half) / half)
		FLIP = math.max(0, math.min(1, math.sin(k * math.pi / 2)))
		if fx.t >= FX[fx.kind] then C.fx = nil FLIP = 1 end
	end
	FLIPX = o.X + 240
	C.slideT = (C.slideT or 30) + (LOCALFIXES.MenuDT or 1)
	local slide = math.min(1, C.slideT / 14)

	drawBg(o, mode)
	if C.phase == "diff" then
		drawDifficulty(o, slide)
		return
	end
	-- шаг «персонаж»
	local tarnMode = mode == "tarnished" and tl
	local tsel = tarnMode and tl[C.tIdx]
	if tsel then tsel.locked = not tarnUnlocked(tsel) end
	local cur = tarnMode and ("t" .. C.tIdx) or (sel and sel.id)
	if lastSel ~= nil and cur ~= lastSel and not C.flip and not C.fx then
		C.flip = { t = 0 }
		sfx:Play(SoundEffect.SOUND_BOOK_PAGE_TURN_12, 0.6, 0, false, 1.1 + math.random() * 0.1)
	end
	lastSel = cur
	local dy = (1 - slide) * 30
	local oo = o + Vector(0, dy)
	art("logo", o.X + 58, o.Y + 27, 86)
	art("cs.title_banner", o.X + 196, o.Y + 20, 150, nil, nil, sway(1, 0.3))
	text("ВЫБОР ПЕРСОНАЖА", o.X + 186, o.Y + 22, HF.Fit("ВЫБОР ПЕРСОНАЖА", 118, { "gL", "gM" }), INK, "c")
	text("Кто же я?", o.X + 190, o.Y + 32, "gS", SOFT, "c")
	local epTab = { name = "Epiphany", src = "3012430463", items = {} }
	drawTabs(o, tarnMode and { epTab } or groups, tarnMode and epTab or (sel and sel.group))
	local items
	if tarnMode then
		items = {}
		for i, t in ipairs(tl) do items[i] = { pt = t.pt, tarn = t, locked = not tarnUnlocked(t), id = -i } end
		drawList(oo, items, items[C.tIdx], mode)
	else
		items = sel and sel.group and sel.group.items or list
		drawList(oo, items, sel, mode)
	end
	local key = sel and charKey(sel.pt)
	local tcur = tarnMode and tsel or nil
	drawCard(oo, sel, key, mode, tcur)
	drawVersions(oo, sel, mode, tl)
	local R = L.right
	local who = tcur or sel
	local locked = who and who.locked
	local random = (not tcur) and sel and (sel.random or RANDOM[key or ""])
	drawStats(oo.X + R.x, oo.Y + 84, statsOf(sel, tcur), random, locked)
	drawTalents(oo.X + R.x, oo.Y + 145)
	drawNotes(oo.X + R.x, oo.Y + 198, sel, key, tcur, locked)
	drawStart(oo.X + R.x, oo.Y + 245, who and not locked)
	local hl = { { "updown", "Выбор" }, { "E", "Версия" }, { "X C", "Мод" }, { "Enter", "Начать" }, { "Esc", "Сложность" },
		{ "Tab", "Сид" }, { "Q", "Пасхалки" } }
	if C.canSwap == false then table.remove(hl, 2) end
	hints(o, hl)
end

-- шаг времени меню (18.10): меню рисуется в каждом кадре, и при 144 кадрах промежуточные кадры между кадрами логики
-- (60 в секунду) не должны ускорять анимации — счётчики меню прибавляют MenuDT: 1 на новом кадре логики, 0 на
-- промежуточном. Считается здесь: этот колбэк меню подключён раньше остальных наших.
local lastFc = -1
mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER, function()
	local fc = Isaac.GetFrameCount()
	LOCALFIXES.MenuDT = fc ~= lastFc and 1 or 0
	lastFc = fc
	local ok, err = pcall(render)
	if not ok and not C.err then
		C.err = true
		Isaac.DebugString("[localfixes] экран выбора: " .. tostring(err))
	end
end)

-- Строка Passive Skill Trees «<персонаж> LV n (V / LB to open tree)» внизу меню выбора ложилась поверх наших подсказок
-- клавиш (19.10, снимки для Мастерской); уровень талантов у нас — на карточке «Таланты». На время кадра меню выбора
-- PST.config.charSelectInfoText выключается (раньше колбэка PST) и возвращается после него — в его сохранение не
-- попадает; без PST — ничего.
local pstInfo
mod:AddPriorityCallback(ModCallbacks.MC_MAIN_MENU_RENDER, CallbackPriority.IMPORTANT, function()
	local P = rawget(_G, "PST")
	if enabled and type(P) == "table" and type(P.config) == "table" and P.config.charSelectInfoText
		and MenuManager.GetActiveMenu() == MainMenuType.CHARACTER then
		pstInfo = true
		P.config.charSelectInfoText = false
	end
end)
mod:AddPriorityCallback(ModCallbacks.MC_MAIN_MENU_RENDER, CallbackPriority.LATE, function()
	if pstInfo then
		pstInfo = nil
		local P = rawget(_G, "PST")
		if type(P) == "table" and type(P.config) == "table" then P.config.charSelectInfoText = true end
	end
end)

function C.SetEnabled(v)   -- для сравнения с классическим видом (проверки)
	enabled = v and true or false
	if not enabled then
		hideSides(false)
		MenuManager.SetInputMask(FULLMASK)
	end
end

-- общие средства для других экранов меню (menu_screens.lua): арт с уровнями уменьшения, надписи, подписи клавиш, фон
C.art, C.text, C.hints, C.ART, C.live, C.motion, C.hash, C.motionOf, C.pose = art, text, hints, ART, artLive, MOTION, hash,
	motionOf, artPose
C.drawItem, C.artClipY = drawItem, artClipY
C.CharKey = charKey
function C.NameOf(pt)
	local key = charKey(pt)
	return charName({ pt = pt }, key, true)
end

-- API для других модов: свой HD-рисунок персонажа на этом экране
function C.Register(who, def)
	if type(def) ~= "table" then return end
	C.custom[who] = def
end

return C
