-- localfixes: титульный экран, выбор файла и главное меню в стиле нового экрана выбора персонажа (18.10, слова
-- пользователя: «Соответственно и главное меню переделай с титульным экраном»; «Плюс я тебе говорил переделать под
-- стиль менюшки игры под стиль ЭКРАНА ПЕРСОНАЖА нового»; «В общем все меню должно быть выполнено в этом стиле который я
-- тебе скинул»; «Напоминаю что элементы экрана титульного, выбора файла сохранений, главного меню и выбора персонажа
-- должны иметь какую то анимацию»; «Там у титульного экрана кажется 2 картинки / И несколько картинок у слотов экрана
-- файлов с сохранениями»). План — docs/MENU_PLAN.md.
--
-- Как устроено: управление, курсор и переходы — игровые; поверх каждого из трёх меню (в его же месте мира меню, кадр
-- 480×270, поэтому всё едет вместе с камерой игры между меню) рисуется своё: фон-доска и бумажки из арта Meshy
-- (menu_art.lua), надписи — шрифт меню (HandFont g*). Что выбрано — читается у игры (SaveMenu, MainMenu); рисунок
-- прогресса файла — по картинке, которую игра выбрала для слота (SaveMenu.GetSaveNDrawingSprite).
local mod = LOCALFIXES.Mod
local HF = LOCALFIXES.HandFont
local CS = LOCALFIXES.CharSelect
if not (CS and CS.art and HF) then return end
local art, text, hints, ART = CS.art, CS.text, CS.hints, CS.ART
local S = { enabled = true }
LOCALFIXES.MenuScreens = S

local INK = Color(55 / 255, 43 / 255, 45 / 255, 1)
local BLACK = Color(22 / 255, 17 / 255, 19 / 255, 1)
local DISABLED = Color(0.62, 0.59, 0.59, 0.85)
local SOFT = Color(110 / 255, 98 / 255, 100 / 255, 1)
local CREAM = Color(244 / 255, 236 / 255, 208 / 255, 1)
local BLOODC = Color(112 / 255, 8 / 255, 11 / 255, 1)
local T = 0
local function sway(seed, amp) return math.sin(T * 0.021 + seed * 1.7) * (amp or 0.5) end
local contT, continueKey, hasContinue = 0, nil, nil
local function origin(m) return Isaac.WorldToMenuPosition(m, Vector(0, 0)) - Vector(39, 15) end
local function onScreen(o) return o.X > -480 and o.X < 480 and o.Y > -270 and o.Y < 270 end
-- рисунок от руки «дрожит» линиями: кадр меняется рывком раз в ~8 кадров (menu_pack: имя:b1, имя:b2), у каждого — свой сдвиг
local function boil(name, seed, rate)
	local k = (T // (rate or 8) + (seed or 0)) % 3
	if k == 0 then return name end
	local v = name .. ":b" .. k
	return ART[v] and v or name
end

-- ------------------------------------------------------------------ движение рисунков
-- (18.10: «Анимируй более детально менюшки… Чтобы картинки на титульном меню и сохранениях чуть чуть двигались / Не
-- просто простые анимации типа плавно вверх вниз а прям полноценные»; «А это партиклов немного и движение элементов»):
-- рисунки — «живые» (CS.live: полосы со своим сдвигом и растяжением): крылья машут, буквы идут волной, кресты гнутся
-- на ветру, глаз моргает, сердце бьётся, скелет гремит, сломанный файл глючит; частицы — LOCALFIXES.MenuFX.
local MF = LOCALFIXES.MenuFX
local POSE, MOTION = CS.pose, CS.motion or {}
-- рисунок двигается целиком (18.10: «я вижу полосы при движении картинки» — без полос): P — поза (CS.pose)
local function pose(name, x, y, w, h, color, P, kx, ky)
	if POSE and P then return POSE(name, x, y, w, h, color, P, kx, ky) end
	return art(name, x, y, w, h, color, 0, kx, ky)
end
local function P(sx, sy, rot, dx, dy, ax, ay)
	return { sx = sx or 1, sy = sy or 1, rot = rot or 0, dx = dx or 0, dy = dy or 0, ax = ax or 0.5, ay = ay or 0.5 }
end
local function heartbeat(t, seed)            -- двойной толчок «тук-тук»
	local ph = (t + (seed or 0)) % 70
	return math.exp(-((ph - 4) / 2.5) ^ 2) + 0.6 * math.exp(-((ph - 14) / 2.5) ^ 2)
end
local function cyc(sp, ph) return (1 - math.cos(T * sp + (ph or 0))) * 0.5 end
local function F(fk, P0) P0 = P0 or P() P0.fk = fk return P0 end
-- доля второго кадра (tools/anim_frames.py: у каждого рисунка свой вид) — по ритму этого вида
local function frameP(kind, i)
	i = i or 1
	if kind == "flap" then return F(cyc(0.11, i))                           -- крылья вверх-вниз
	elseif kind == "sway" then return F(cyc(0.018, i))                      -- качается на ветру
	elseif kind == "swing" then return F(cyc(0.035, i))                     -- замахивается мечом
	elseif kind == "look" then                                             -- переводит взгляд и возвращает
		local ph = (T + i * 53) % 420
		return F(ph < 160 and math.sin(math.min(1, ph / 40) * math.pi / 2) * math.min(1, (160 - ph) / 40) or 0)
	elseif kind == "heart_c" then return F(math.min(1, heartbeat(T, i * 9)))  -- «тук-тук»
	elseif kind == "flex" then return F(math.max(0, math.sin(T * 0.045 + i)) ^ 2)
	elseif kind == "crawl" or kind == "wave" then return F(cyc(0.05, i * 1.7))
	elseif kind == "burst" or kind == "rattle" then                        -- раз в несколько секунд — дребезг
		local ph = (T + i * 37) % 170
		return F(ph < 32 and (0.5 - 0.5 * math.cos(ph / 8 * math.pi * 2)) or 0)
	elseif kind == "glitch" then
		local hsh = CS.hash or function() return 1 end
		local P0 = F((hsh(T // 24, i) < 0.4 and hsh(T // 3, i + 1) < 0.5) and 1 or 0)
		P0.hard = true
		return P0
	elseif kind == "float" then return F(cyc(0.037, i), P(1, 1, 0, 0, -0.5 * math.sin(T * 0.037 + i)))
	elseif kind == "hole" then return MOTION.sob and MOTION.sob(T, i) or nil
	elseif MOTION[kind] then return MOTION[kind](T, i)
	end
	return nil
end
local function motionP(kind, seed)
	local m = MOTION[kind]
	return m and m(T, seed or 0) or nil
end

-- ------------------------------------------------------------------ титульный экран
-- рисунок листа — как у игры: обычный (Исаак в яме под светом) или «Хватит играть!» (толстый Исаак) у «Мёртвого бога»
local function titleDeadGod()
	local ok, s = pcall(TitleMenu.GetSprite)
	if not (ok and s) then return false end
	for i = 0, s:GetLayerCount() - 1 do
		local l = s:GetLayer(i)
		local p = l and l:GetSpritesheetPath() or ""
		if p:lower():find("titlemenu_2") then return true end
	end
	return false
end
local titleFlies = false
local function lampFlicker()                -- лампа над ямой иногда мигает: рисунок на миг темнеет
	local fl = T % 233
	return (fl < 3 or (fl > 6 and fl < 9)) and 0.86 or (1 + 0.015 * math.sin(T * 0.31))
end
local function drawTitle(o)
	art(ART.bg_title and "bg_title" or "bg_wall", o.X + 240, o.Y + 135, 494, 284, nil, 0, nil, nil, true)
	if MF then MF.run("title_back", o, { dust = 5, moth = 0.0015, light = { 240, 40 } }) end   -- мотылёк — к лучу лампы
	-- рисунки карандашом по стене — каждый живёт по-своему
	local A = Color(1, 1, 1, 0.55)
	pose("ti.angel", o.X + 52, o.Y + 70 + math.sin(T * 0.03) * 0.8, 34, nil, A, frameP("flap", 1))
	pose("ti.crosses", o.X + 420, o.Y + 66, 30, nil, A, frameP("sway", 1))
	art("ti.moon", o.X + 440, o.Y + 200, 22, nil, Color(1, 1, 1, 0.42 + 0.16 * math.sin(T * 0.025)), math.sin(T * 0.011) * 7)
	pose("ti.bear", o.X + 40, o.Y + 210, 26, nil, A, frameP("breath", 2))
	art(boil("ti.tally", 5), o.X + 120, o.Y + 238, 26, nil, A)
	pose("ti.stick1", o.X + 380, o.Y + 236, 30, nil, A, frameP("swing", 1))
	local bl = MF and MF.blink(T, 1) or 1                       -- глаз смотрит по сторонам, моргает и плачет
	pose("ti.eye", o.X + 96, o.Y + 140, 22, nil, A, frameP("look", 1), 1, bl)
	pose("ti.heart", o.X + 452, o.Y + 132, 18, nil, Color(1, 1, 1, 0.5), frameP("heart_c", 11))
	if MF and T % 310 == 40 then MF.drip("title_back", "pa.tear", 96, 150, { w = 3, life = 60, g = 0.04 }) end
	-- слизь: потёк тянется и срывается каплей
	local sc = T % 360
	local sk = sc < 300 and (sc / 300) ^ 2 or (1 - (sc - 300) / 8)
	pose("ti.slime", o.X + 360, o.Y + 225, 60, nil, Color(1, 1, 1, 0.85), F(math.max(0, math.min(1, sk))))
	if MF and sc == 300 then MF.drip("title_back", "pa.tear", 352, 246, { w = 4, life = 50, tint = { 0.65, 0.85, 0.45 } }) end
	-- логотип: буквы идут волной
	local lw = math.sin(T * 0.03)
	pose("logo", o.X + 240, o.Y + 46, 230, nil, nil, P(1 + 0.006 * lw, 1 + 0.01 * lw, 0.5 * math.sin(T * 0.013)))
	-- лист с рисунком
	local dg = titleDeadGod()
	art("ti.sheet", o.X + 240, o.Y + 160, 210, 128, nil, sway(3, 0.6))
	if dg then
		pose("ti.fat_isaac", o.X + 240, o.Y + 162, 96, nil, nil, frameP("rage", 3))   -- дрожит от ужаса
		if MF and T % 40 == 0 then MF.toss("title", "pa.tear", 240 + (math.random() - 0.5) * 50, 130) end   -- пот
		text("ХВАТИТ ИГРАТЬ!", o.X + 240, o.Y + 112, "gL", INK, "c")
	else
		local lf = lampFlicker()
		pose("ti.isaac_hole", o.X + 240, o.Y + 166, 110, nil, Color(lf, lf, lf, 1), frameP("hole", 1))
		if MF then
			if T % 52 == 0 then MF.drip("title", "pa.tear", 234.5 + (T % 104 == 0 and -2.5 or 2.5), 168, { w = 2.4, life = 24, vy = 0.05, g = 0.03 }) end
			if T % 90 == 0 then MF.mote("title", 240 + (math.random() - 0.5) * 24, 120 + math.random() * 30, "pa.dust") end
		end
	end
	-- нож воткнут в край листа, с ножа раз в долгую паузу срывается капля крови (нож при этом чуть вздрагивает)
	local cyc = T % 420
	art(boil("ti.knife", 1), o.X + 352, o.Y + 120, 48, nil, nil, 8 + (cyc < 8 and math.sin(cyc * 1.6) * 1.5 or 0))
	if cyc < 90 then
		local k = cyc / 90
		art("ti.blood", o.X + 340, o.Y + 140 + k * k * 60, 6, nil, Color(1, 1, 1, 1 - k * 0.6))
	end
	art(boil("ti.blood", 2), o.X + 335, o.Y + 132, 18, nil, Color(1, 1, 1, 0.9), 0)
	-- мухи вьются над листом и садятся на него и на Исаака
	if MF then
		if not titleFlies then
			titleFlies = true
			for _ = 1, 3 do
				MF.fly("title", 240, 150, 80, { img = "ti.fly1", w = 10,
					spots = { { 240, 178, 50 }, { 236, 150, 6 }, { 300, 120, 20 }, { 180, 200, 20 } } })
			end
		end
		MF.run("title", o)
	end
	-- «Нажмите…» — пульсирует
	local pul = 0.7 + 0.3 * math.sin(T * 0.08)
	art("cs.panel_wide", o.X + 240, o.Y + 249, 200, 26, nil, sway(5, 0.4))
	text("НАЖМИТЕ ПРОБЕЛ ИЛИ ENTER", o.X + 240, o.Y + 253, HF.Fit("НАЖМИТЕ ПРОБЕЛ ИЛИ ENTER", 180, { "gM", "gS" }),
		Color(INK.R, INK.G, INK.B, pul), "c")
end

-- ------------------------------------------------------------------ выбор файла
local DRAW = {   -- картинка игры для слота → наш рисунок
	["01_basement"] = "sa.d_basement", ["02_momkill"] = "sa.d_momkill", ["03_heart"] = "sa.d_heart",
	["04_everythingisterrible"] = "sa.d_crying", ["05_fetus"] = "sa.d_fetus", ["06_bluebaby"] = "sa.d_bluebaby",
	["07_goldengod"] = "sa.d_golden", ["13_lambskull"] = "sa.d_lamb", ["14_platinumgod"] = "sa.d_platinum",
	["15_realplatinumgod"] = "sa.d_realplatinum", ["16_killmegasatan"] = "sa.d_megasatan", ["17_1000percent"] = "sa.d_1000",
	["1savefiletogo"] = "sa.d_skeleton", ["2savefilestogo"] = "sa.d_skeleton", mother = "sa.d_mother", dogma = "sa.d_cross",
	beast = "sa.d_house", complete1 = "sa.d_eye1", complete2 = "sa.d_eye2", complete3 = "sa.d_eye3",
	deadgod = "sa.d_deadgod", corruptdata = "sa.d_corrupt", momsheartcheckmarks = "sa.d_smallcross",
	-- все три файла — «Мёртвый бог»: у игры одна картина на три листа (Infinity1–3) — у нас тоже
	infinity1 = "sa.inf1", infinity2 = "sa.inf2", infinity3 = "sa.inf3",
}
local function slotDrawing(i)
	local ok, s = pcall(SaveMenu["GetSave" .. i .. "DrawingSprite"])
	if not (ok and s) then return nil end
	local l = s:GetLayer(0)
	local p = (l and l:GetSpritesheetPath() or ""):lower():match("([^/]+)%.png$") or ""
	if p:find("photo") then return "sa.d_photo" end
	if p:find("negative") then return "sa.d_negative" end
	return DRAW[p]
end
local function saveLayerVisible(name)
	local ok, r = pcall(function()
		local s = SaveMenu.GetSaveSelectMenuSprite()
		local id = s:GetLayer(name):GetLayerID()
		local fr = s:GetCurrentAnimationData():GetLayer(id):GetFrame(s:GetFrame())
		return fr and fr:IsVisible() and fr:GetColor().A > 0.05
	end)
	return ok and r
end
-- как живёт рисунок файла (вид движения) и что вокруг него летает у выбранного файла
local SAVE_ANIM = {   -- вид — как PIECE_KIND в tools/anim_frames.py (там строится второй кадр); pin — без второго кадра
	["sa.d_basement"] = "hole", ["sa.d_crying"] = "sob", ["sa.d_fetus"] = "float", ["sa.d_golden"] = "flex",
	["sa.d_momkill"] = "crawl", ["sa.d_heart"] = "heart_c", ["sa.d_bluebaby"] = "float", ["sa.d_junk"] = "sob",
	["sa.d_photo"] = "pin", ["sa.d_negative"] = "pin", ["sa.d_megasatan"] = "heavy", ["sa.d_platinum"] = "flex",
	["sa.d_realplatinum"] = "flap", ["sa.d_lamb"] = "flap", ["sa.d_1001"] = "wave", ["sa.d_percent"] = "wave",
	["sa.d_1000"] = "burst", ["sa.d_skeleton"] = "rattle", ["sa.d_cross"] = "sway", ["sa.d_cross2"] = "sway",
	["sa.d_mother"] = "sob", ["sa.d_house"] = "heavy", ["sa.d_eye1"] = "look", ["sa.d_eye2"] = "look", ["sa.d_eye3"] = "look",
	["sa.d_smallcross"] = "sway", ["sa.d_ornatecross"] = "sway", ["sa.d_corrupt"] = "glitch", ["sa.d_deadgod"] = "heavy",
	["sa.inf1"] = "wave", ["sa.inf2"] = "wave", ["sa.inf3"] = "wave",
}
local function saveFx(d, x, y, w, h)        -- частицы у выбранного рисунка (координаты — в кадре экрана)
	if not MF then return end
	local t = T
	if d == "sa.d_crying" or d == "sa.d_mother" or d == "sa.d_junk" then
		if t % 50 == 0 then MF.drip("saves", "pa.tear", x + (t % 100 == 0 and -4 or 4), y - h * 0.1, { w = 3, life = 40 }) end
	elseif d == "sa.d_golden" or d == "sa.d_platinum" or d == "sa.d_realplatinum" then
		if t % 22 == 0 then MF.twinkle("saves", "pa.sparkle", x + (math.random() - 0.5) * w, y + (math.random() - 0.5) * h) end
	elseif d == "sa.d_lamb" then
		if t % 90 == 0 then MF.fall("saves", "pa.feather_black", x + (math.random() - 0.5) * w, y - h * 0.4) end
	elseif d == "sa.d_heart" then
		if t % 70 == 4 then MF.rise("saves", "pa.heart", x, y, { w = 5 }) end
	elseif d == "sa.d_bluebaby" or d == "sa.d_fetus" then
		if t % 80 == 0 then MF.rise("saves", "pa.soul", x + (math.random() - 0.5) * 10, y, { w = 6, a = 0.75 }) end
	elseif d == "sa.d_1000" then
		if (t % 170) == 2 then for _ = 1, 3 do MF.toss("saves", ({ "pa.penny", "pa.key", "pa.bomb", "pa.pill" })[math.random(4)], x, y) end end
	elseif d == "sa.d_corrupt" then
		if t % 9 == 0 then MF.glitch("saves", x + (math.random() - 0.5) * w, y + (math.random() - 0.5) * h, 6) end
	elseif d == "sa.d_house" then
		if t % 60 == 0 then MF.rise("saves", "pa.dust", x + w * 0.2, y - h * 0.35, { w = 4, vy = -0.2, a = 0.6 }) end
	elseif d == "sa.d_deadgod" or d == "sa.d_megasatan" then
		if t % 20 == 0 then MF.ember("saves", x + (math.random() - 0.5) * w, y + h * 0.35) end
	end
end
local function drawSaveDrawing(d, cx, cy, h, color, i, on)
	local kind = SAVE_ANIM[d] or "breath"
	if kind == "pin" and MF then
		MF.pinned(d, cx, cy, nil, h, color, 1.8 * math.sin(T * 0.02 + i), 0, -h * 0.45)
	elseif kind == "look" then pose(d, cx, cy, nil, h, color, frameP("look", i), 1, MF and MF.blink(T, i) or 1)
	else pose(d, cx, cy, nil, h, color, frameP(kind, i)) end
end
local function drawSaves(o)
	art(ART.bg_saves and "bg_saves" or "bg_wall", o.X + 240, o.Y + 135, 494, 284, nil, 0, nil, nil, true)
	if MF then MF.run("saves_back", o, { dust = 5, moth = 0.001 }) end
	art("cs.title_banner", o.X + 240, o.Y + 22, 150, nil, nil, sway(1, 0.3))
	text("ВЫБОР ФАЙЛА", o.X + 236, o.Y + 26, "gL", INK, "c")
	local sel = SaveMenu.GetSelectedElement()
	local del = SaveMenu.IsDeleteActive()
	if MF then MF.sel("saves", sel) end
	for i = 1, 3 do
		local on = sel == i - 1
		local cx = o.X + 240 + (i - 2) * 132
		local cy = o.Y + 128                   -- листы неподвижны (18.10: «А сами листки не должны двигаться»)
		local lit = on and 1.08 or 0.7
		art("sa.slot" .. i, cx, cy, 120, nil, Color(lit, lit, lit * (on and 0.95 or 1), 1))
		local d = slotDrawing(i)
		if d then
			-- рисунок «живёт» своим движением (без ряби: не сменой кадров, а деформацией)
			local big = d:find("^sa%.inf")            -- общая картина — во весь лист
			local hh = big and 80 or 70
			drawSaveDrawing(d, cx, cy - (big and 12 or 6), hh, on and nil or Color(0.75, 0.73, 0.73, 1), i, on)
			if on then
				local a = ART[d]
				saveFx(d, cx - o.X, cy - (big and 12 or 6) - o.Y, a and a[2] * hh / a[3] or hh, hh)
			end
		end
		text("ФАЙЛ " .. i, cx, cy + 54, "gL", on and INK or SOFT, "c")
		if del and on then
			art("sa.x", cx, cy, 90, nil, Color(1, 1, 1, 0.75 + 0.2 * math.sin(T * 0.15)))
		end
	end
	-- «Удалить файл»: выбран — ярче; режим удаления — красная планка
	local onDel = sel == 3
	art(del and "sa.strip_red" or "sa.strip", o.X + 240, o.Y + 232, onDel and 196 or 186, nil,
		onDel and Color(1.1, 1.05, 1, 1) or Color(0.8, 0.78, 0.78, 1), sway(9, 0.3))
	text("УДАЛИТЬ ФАЙЛ", o.X + 240, o.Y + 236, "gM", del and CREAM or INK, "c")
	if MF then MF.run("saves", o) end
	-- подтверждение удаления — своей бумажкой (выбор «да / нет» — у игры: курсор её слоя)
	if saveLayerVisible("Confirmation") then          -- окно игры поверх (её курсор «да / нет»)
		local s = SaveMenu.GetSaveSelectMenuSprite()
		local w = Isaac.WorldToMenuPosition(MainMenuType.SAVES, Vector(0, 0))
		art("bg_cursed", o.X + 240, o.Y + 135, 482, nil, Color(0, 0, 0, 0.45), 0, nil, nil, true)
		for _, n in ipairs({ "Confirmation", "Cursor" }) do
			local okL, l = pcall(s.GetLayer, s, n)
			if okL and l then s:RenderLayer(l:GetLayerID(), w) end
		end
	end
end

-- ------------------------------------------------------------------ персонаж забега для «Продолжить»
-- (18.10: «У тебя показывает элементы другого персонажа при «продолжить»»): игра не отдаёт, за кого сохранён забег, а
-- модовых персонажей рисует в карточке своим спрайтом. Наш мод запоминает это сам — в своих данных слота (флаги
-- hotkeys.lua: «…;run=60;»), при начале и продолжении забега.
local function loadFlags()
	local ok, d = pcall(function() return mod:HasData() and mod:LoadData() or "" end)
	return ok and type(d) == "string" and d or ""
end
local function saveRunType(pt)
	local f = loadFlags():gsub("run=%-?%d+;", "")
	pcall(function() mod:SaveData(f .. "run=" .. tostring(pt) .. ";") end)
end
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function()
	local p = Isaac.GetPlayer(0)
	if p then saveRunType(p:GetPlayerType()) end
end)
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, function(_, p)       -- смена персонажа в забеге (Epiphany: двери)
	if Game():GetFrameCount() > 0 and p and p.Index == Isaac.GetPlayer(0).Index then saveRunType(p:GetPlayerType()) end
end)
local runCache = {}
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function() runCache = {} end)
local function runType()
	local slot = SaveMenu.GetSelectedElement()
	if runCache[slot] == nil then
		runCache[slot] = tonumber(loadFlags():match("run=(%-?%d+);")) or false
	end
	return runCache[slot] or nil
end

-- ------------------------------------------------------------------ главное меню
local contKnown = {}       -- [номер файла] = true/false: есть ли забег (узнаётся при наведении на «Продолжить»)
local hoverT = 0
local function slotNo()
	local ok, n = pcall(function() return Isaac.GetPersistentGameData and Options and SaveMenu.GetSelectedElement() + 1 end)
	return ok and n or 0
end
hasContinue = function()
	local v = contKnown[slotNo()]
	return v ~= false
end
-- персонаж забега: место рисунка в листе колеса → анимация колеса → ключ нашего рисунка
local PKEY = { ["01_Isaac"] = "isaac", ["02_Magdalene"] = "magdalene", ["03_Cain"] = "cain", ["04_Judas"] = "judas",
	["05_Eve"] = "eve", ["06_Bluebaby"] = "bluebaby", ["07_Samson"] = "samson", ["08_Azazel"] = "azazel",
	["09_Lazarus"] = "lazarus", ["10_Eden"] = "eden", ["11_TheLost"] = "thelost", ["12_Lilith"] = "lilith",
	["13_Keeper"] = "keeper", ["15_Apollyon"] = "apollyon", ["16_TheForgotten"] = "theforgotten", ["17_Bethany"] = "bethany",
	["18_JacobEsau"] = "jacob" }
local cropMap
local function buildCrops()
	cropMap = { n = {}, a = {} }
	for kind, anm in pairs({ n = "gfx/ui/main menu/characterportraits.anm2", a = "gfx/ui/main menu/characterportraitsalt.anm2" }) do
		local s = Sprite()
		s:Load(anm, true)
		if s:IsLoaded() then
			for _, ad in ipairs(s:GetAllAnimationData()) do
				local f = ad:GetLayer(0) and ad:GetLayer(0):GetFrame(0)
				local key = PKEY[ad:GetName()]
				if f and key then cropMap[kind][f:GetCrop().X .. "," .. f:GetCrop().Y] = key .. (kind == "a" and "_b" or "") end
			end
		end
	end
end
local lastKey, candKey, candN = nil, nil, 0
continueKey = function(cw)
	if not cropMap then buildCrops() end
	local ok, key = pcall(function()
		local ad = cw:GetAnimationData("Character")
		local frame = (cw:GetAnimation() == "Character") and cw:GetFrame() or nil
		if not frame then return nil end
		for _, pair in ipairs({ { "CharacterAlt", "a" }, { "Character", "n" } }) do
			local id = cw:GetLayer(pair[1]):GetLayerID()
			local f = ad:GetLayer(id):GetFrame(frame)
			if f and f:IsVisible() and cw:GetLayer(pair[1]):IsVisible() then
				local k = cropMap[pair[2]][f:GetCrop().X .. "," .. f:GetCrop().Y]
				if k then return k end
			end
		end
	end)
	if ok and key then
		if key == candKey then candN = candN + (LOCALFIXES.MenuDT or 1) else candKey, candN = key, 1 end
		if candN >= 30 then lastKey = key end
	end
	return lastKey
end
contT = 0
-- пункты — по номерам игры (MainMenu.GetSelectedElement; проверено 18.10 нажатием каждого): 0 новый забег,
-- 1 продолжить, 2 онлайн (с модами недоступен — игра показывает окно), 3 испытания, 4 статистика, 5 настройки, 6 моды
-- (18.10: «У тебя кнопка «испытание» пытается открыть онлайн» — был неверный порядок)
local ITEMS = {
	{ "НОВЫЙ ЗАБЕГ", "ma.i_trapdoor" }, { "ПРОДОЛЖИТЬ", "ma.i_door" }, { "ОНЛАЙН", "ma.i_stars", online = true },
	{ "ИСПЫТАНИЯ", "ma.i_trophy" }, { "СТАТИСТИКА", "ma.i_stats" }, { "НАСТРОЙКИ", "ma.i_gear" },
}   -- «Моды» (номер 6) клавишами не выбирается — меню модов открывает TAB (18.10: «И зачем тебе в меню пункт моды если
    -- его нельзя выбрать а он включается на Tab»), поэтому в списке его нет; подсказка про TAB — бумажка справа
local function drawGame(o)
	art(ART.bg_game and "bg_game" or "bg_wall", o.X + 240, o.Y + 135, 494, 284, nil, 0, nil, nil, true)
	if MF then
		MF.run("game_back", o, { dust = 5, moth = 0.001, fall = 0.0012 })
		if T % 1400 == 200 then MF.spider("game_back", 300 + math.random() * 150, -6, 60 + math.random() * 60) end
	end
	-- висельник качается на верёвке (вокруг точки крепления), паук перебирает лапами, сундук «дышит»
	if MF then MF.pinned("ma.d_hanging", o.X + 70, o.Y + 90, 40, nil, Color(1, 1, 1, 0.5), 4 * math.sin(T * 0.028), 0, -20)
	else art("ma.d_hanging", o.X + 70, o.Y + 90, 40, nil, Color(1, 1, 1, 0.5)) end
	pose("ma.d_chest", o.X + 410, o.Y + 210, 46, nil, Color(1, 1, 1, 0.5), P(1, 1, 0, 0, 0, 0.5, 1))
	pose("ma.d_spider", o.X + 440, o.Y + 120 + math.sin(T * 0.02) * 3, 26, nil, Color(1, 1, 1, 0.5),
		P(1, 1, 6 * math.sin(T * 0.03), 0, 0, 0.5, 0))                 -- паук качается на нити
	-- логотип — того же размера и на том же месте, что на экране сложности и персонажа, и неподвижен (18.10: «А игре до
	-- сих пор в переходе вверху что то мигает непонятное» — при переходе он прыгал: 110 → 86 и сдвиг)
	art("logo", o.X + 58, o.Y + 27, 86)
	-- лист с пунктами
	art("ma.sheet", o.X + 240, o.Y + 140, 176, 214, nil, sway(2, 0.4))
	local sel = MainMenu.GetSelectedElement()
	if MF then MF.sel("game", sel) end
	local wob = MF and MF.wob("game", sel) or 0                -- выбранный пункт вздрагивает при смене выбора
	for i, it in ipairs(ITEMS) do
		local on = sel == i - 1
		local y = o.Y + 58 + (i - 1) * 30
		local dx = on and (math.sin(T * 0.12) * 1.5 + wob * 0.3) or 0
		if on then art("ma.highlight", o.X + 248, y - 2, 150, 20, Color(1, 1, 1, 0.8)) end
		local off = (i == 2 and not hasContinue()) or it.online
		art(boil(it[2], i), o.X + 176 + dx, y - 3, on and 20 or 17, nil, off and Color(0.55, 0.55, 0.55, 0.55)
			or (on and nil or Color(0.85, 0.83, 0.83, 1)), sway(i + 3, on and 3 or 0) + (on and wob * 2 or 0))
		text(it[1], o.X + 192 + dx, y + 2, on and "gL" or "gM", off and DISABLED or BLACK)
		if it.online then text("С МОДАМИ НЕДОСТУПЕН", o.X + 196 + HF.Width(it[1], on and "gL" or "gM"), y + 2, "gT", DISABLED) end
		if off then art("ma.highlight", o.X + 240, y - 1, 104, 2, Color(0.3, 0.27, 0.28, 0.7)) end   -- зачёркнуто
		if on then art("ma.cursor", o.X + 162 + dx, y - 3, 9) end
	end
	-- TAB: с модами ежедневное испытание недоступно — REPENTOGON открывает по TAB меню модов (проверено 18.10;
	-- слова пользователя: «Tab у тебя вообще открывает моды а не ежедневное испытание»)
	art(ART["hd.note_wide"] and "hd.note_wide" or "ma.note_pin", o.X + 400, o.Y + 66, 100, nil, nil, sway(4, 0.6))
	text("TAB —", o.X + 400, o.Y + 70, "gM", INK, "c")
	text("МЕНЮ МОДОВ", o.X + 400, o.Y + 81, "gS", INK, "c")
	-- забег для продолжения (18.10: «На продолжить когда наводишь он не показывает какой персонаж сейчас в забеге»):
	-- при наведении на «Продолжить» — бумажка с нашим рисунком персонажа забега. Персонажа узнаём по карточке игры:
	-- её слой Character / CharacterAlt берёт рисунок колеса — его место в листе сличается с колесом игры.
	local okC, cw = pcall(MainMenu.GetContinueWidgetSprite)
	local showing = okC and cw and cw:GetAnimation() ~= "Dissapear"
	if sel == 1 then                              -- наведено на «Продолжить»: карточка игры появилась — забег есть
		hoverT = hoverT + (LOCALFIXES.MenuDT or 1)
		if showing then contKnown[slotNo()] = true elseif hoverT > 40 then contKnown[slotNo()] = false end
	else
		hoverT = 0
	end
	contT = math.max(0, math.min(12, contT + (showing and 1 or -1) * (LOCALFIXES.MenuDT or 1)))
	if contT > 0 then
		local rpt = runType()
		local key = rpt and CS.CharKey and CS.CharKey(rpt) or continueKey(cw)
		local k = contT / 12
		local cx, cy = o.X + 82, o.Y + 140 + (1 - k) * 12
		art(ART["hd.note_sq"] and "hd.note_sq" or "ma.note_peach", cx, cy, 120, 132, Color(1, 1, 1, k), sway(6, 0.5))
		-- ниже булавки (крупная записка: булавка закрывает верх до ~17% высоты; 18.10: «текст снова наехал на булавки»)
		text("ВАШ ЗАБЕГ", cx, cy - 36, "gM", Color(INK.R, INK.G, INK.B, k), "c")
		if key and ART[key] then
			local a = ART[key]
			local sc = math.min(84 / a[2], 62 / a[3])
			art(key, cx, cy + 10, a[2] * sc, nil, Color(1, 1, 1, k))      -- персонаж неподвижен (только частицы)
		end
		local nm = rpt and CS.NameOf and CS.NameOf(rpt)
		if not key then text("?", cx, cy + 16, "gX", Color(INK.R, INK.G, INK.B, k), "c") end
		if nm then text(HF.upper(nm), cx, cy + 52, HF.Fit(HF.upper(nm), 100, { "gM", "gS" }), Color(INK.R, INK.G, INK.B, k), "c") end
	end
	if MF then MF.run("game", o) end
end

-- ------------------------------------------------------------------ статистика
-- Данные и номер страницы — у REPENTOGON (REPENTOGON.Extras.StatsMenu: страницы «Статистика игры», «Убито боссов»,
-- «Покупки», «Азарт», «Хаос», «Разное»; ←/→ листает он сам; подписи — по-русски через ru_rgon.lua); выбранный пункт —
-- StatsMenu.GetSelectedElement — номер пункта справа; проверено нажатием каждого 18.10 (пользователь: «Предметы
-- показывают концовки…»): 0 Предметы (меню 8), 1 Концовки (13), 2 Секреты (свой экран внутри статистики), 3 Бестиарий
-- (14), 4 Онлайн-награды (22, «Sins!»). Лист статистики не выбирается: ←/→ листают его всегда.
local STAT_ITEMS = { { "ПРЕДМЕТЫ", "ma.i_dice" }, { "КОНЦОВКИ", "ma.i_book" }, { "СЕКРЕТЫ", "ma.i_stars" },
	{ "БЕСТИАРИЙ", "cs.horned_skull" }, { "ОНЛАЙН-НАГРАДЫ", "ma.i_trophy" } }
local function drawStats(o)
	if StatsMenu.IsSecretsMenuVisible and StatsMenu.IsSecretsMenuVisible() then   -- «Секреты» — свой экран (menu_lists.lua)
		if S.drawSecrets then S.drawSecrets(o) end
		return
	end
	art(ART.bg_game and "bg_game" or "bg_wall", o.X + 240, o.Y + 135, 494, 284, nil, 0, nil, nil, true)
	if MF then MF.run("stats_back", o, { dust = 4, moth = 0.0008, fall = 0.0008 }) end
	art("cs.title_banner", o.X + 240, o.Y + 22, 150, nil, nil, sway(1, 0.3))
	text("СТАТИСТИКА", o.X + 236, o.Y + 26, "gL", INK, "c")
	local sel = StatsMenu.GetSelectedElement()
	-- лист с числами
	local R = REPENTOGON and REPENTOGON.Extras and REPENTOGON.Extras.StatsMenu
	local cx, cy = o.X + 140, o.Y + 148
	art("ma.sheet", cx, cy, 196, 212, nil, sway(2, 0.3))
	if R and R.Stats then
		local id = R.CurrentlyDisplayedCategoryID or 1
		local cat = R.Stats[id]
		if cat then
			local title = HF.upper(tostring(cat[1]))
			text(title, cx, cy - 78, HF.Fit(title, 130, { "gM", "gS" }), BLACK, "c")
			local pulse = math.sin(T * 0.1) * 1.5
			art("cs.arrow_l", cx - 78 - pulse, cy - 81, 9)
			art("cs.arrow_r", cx + 78 + pulse, cy - 81, 9)
			for k = 1, #R.Stats do        -- точки страниц
				art("cs.seg_full", cx + (k - (#R.Stats + 1) / 2) * 7, cy - 66, 4, 4, k == id and nil or Color(0.6, 0.6, 0.6, 0.6))
			end
			local y = cy - 52
			for _, st in ipairs(cat[2]) do
				local name = st[1]
				if type(name) == "table" then name = table.concat(name, " ") end
				name = HF.upper(tostring(name))
				local val = tostring(st[3] or "")
				if name ~= "" then
					text(name, cx - 82, y, HF.Fit(name, 120, { "gS", "gT" }), INK)
					text(val, cx + 84, y, "gS", BLACK, "r")
				end
				y = y + (name == "" and 6 or 12)
			end
		end
	end
	-- пункты справа
	local mx, my = o.X + 352, o.Y + 142
	art(ART["hd.note_sq"] and "hd.note_sq" or "ma.note_pin", mx, my, 150, 158, nil, sway(4, 0.4))
	if MF then MF.sel("stats", sel) end
	local wob = MF and MF.wob("stats", sel) or 0
	for i, it in ipairs(STAT_ITEMS) do
		local on = sel == i - 1
		local y = my - 44 + (i - 1) * 24
		local dx = on and (math.sin(T * 0.12) * 1.5 + wob * 0.3) or 0
		if on then art("ma.highlight", mx + 6, y - 2, 128, 20, Color(1, 1, 1, 0.8)) end
		art(it[2], mx - 52 + dx, y - 3, on and 18 or 15, nil, on and nil or Color(0.85, 0.83, 0.83, 1), on and wob * 2 or 0)
		text(it[1], mx - 38 + dx, y + 2, HF.Fit(it[1], 104, on and { "gL", "gM", "gS" } or { "gM", "gS" }), BLACK)
		if on then art("ma.cursor", mx - 66 + dx, y - 3, 8) end
	end
end

-- ------------------------------------------------------------------ переходы между меню — затуханием
-- (18.10: «переходы между меню надо сделать через затухание а не как сейчас перелистывание / А то сейчас не очень плавно
-- когда нажимаешь новый забег»): при смене меню камера игры сразу встаёт на новое место (MenuManager.SetViewPosition),
-- а экран проявляется из темноты.
local lastMenu, travel, fadeT = nil, nil, 99
local FADE = 14
local DRAWS = {}
local function arrived(m)
	local p = Isaac.WorldToMenuPosition(m, Vector(0, 0))
	return math.abs(p.X - 39) < 1.5 and math.abs(p.Y - 15) < 1.5
end
-- переход мгновенный, с небольшим затуханием (18.10: «У тебя переходы между меню должны быть мгновенные но с
-- затуханием небольшим / Сейчас у тебя он в моменте показывает старое меню вообще»): пока камера игры едет к новому
-- меню, новый экран сразу рисуется на месте (наши экраны — здесь, экран персонажа — по LOCALFIXES.MenuFixed),
-- старое меню не рисуется; экран коротко проявляется из полутьмы.
local function updateTravel()
	local m = MenuManager.GetActiveMenu()
	if lastMenu ~= nil and m ~= lastMenu then
		travel, fadeT = m, 0
		if MF and MF.page then MF.page() end                     -- переход между экранами — шорох бумаги
	end
	lastMenu = m
	if travel and (travel ~= m or arrived(m)) then travel = nil end
	LOCALFIXES.MenuFixed = travel
	return m
end
local function fadeOverlay()
	if fadeT < FADE then
		fadeT = fadeT + (LOCALFIXES.MenuDT or 1)
		local k = fadeT / FADE
		local a = 0.4 * (1 - k) ^ 1.5      -- мягко: резкое затемнение на 75% в первом кадре читалось как рывок
		art("bg_cursed", 240, 135, 494, 284, Color(0, 0, 0, a), 0, nil, nil, true)
	end
end

-- ------------------------------------------------------------------ отрисовка поверх меню игры
local ffSplashOff = false
local function killFFSplash()
	if ffSplashOff then return end
	local FF = FiendFolio
	if type(FF) == "table" and FF.SplashTextRender then
		pcall(FF.RemoveCallback, FF, ModCallbacks.MC_MAIN_MENU_RENDER, FF.SplashTextRender)
		ffSplashOff = true
	end
end
mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER, function()
	if not S.enabled or not (MenuManager.IsActive and MenuManager.IsActive()) then return end
	killFFSplash()
	T = T + (LOCALFIXES.MenuDT or 1)
	local ok, err = pcall(function()
		DRAWS[MainMenuType.TITLE], DRAWS[MainMenuType.SAVES], DRAWS[MainMenuType.GAME] = drawTitle, drawSaves, drawGame
		DRAWS[MainMenuType.STATS] = drawStats
		for m, f in pairs(S.extra) do DRAWS[m] = f end           -- экраны других файлов (menu_lists.lua: S.Register)
		local cur = updateTravel()
		local dbg = (LOCALFIXES.MenuDebug or 0) > 0 and {}           -- журнал решений по кадрам (проверка переходов)
		if travel then
			if DRAWS[cur] then DRAWS[cur](Vector(0, 0)) end   -- новый экран сразу на месте, старое меню не видно
			if dbg then dbg[#dbg + 1] = "travel " .. tostring(travel) .. (DRAWS[cur] and " draw0" or " nodraw") end
		else
			for m in pairs(DRAWS) do
				local o = origin(m)
				-- экран, который игра прокручивает камерой (список испытаний), пока открыт — стоит на месте (18.10: «когда
				-- листаешь эту менюшку испытания вниз вверх он показывает старое меню»); соседние экраны при этом не рисуются:
				-- камера игры уезжает вниз за выбором, и сосед вылезал снизу по камере (19.10: «У тебя управление в настройках
				-- вылезло неправильно» — «Управление» под листом «Настроек»)
				if m == cur and S.fixed[m] then o = Vector(0, 0) end
				if S.fixed[cur] and m ~= cur then o = Vector(99999, 99999) end
				if onScreen(o) then
					DRAWS[m](o)
					if dbg then dbg[#dbg + 1] = ("draw %d @%.0f,%.0f"):format(m, o.X, o.Y) end
				end
			end
		end
		fadeOverlay()
		if dbg then
			LOCALFIXES.MenuDebug = LOCALFIXES.MenuDebug - 1
			local o5 = Isaac.WorldToMenuPosition(MainMenuType.CHARACTER, Vector(0, 0))
			Isaac.DebugString(("[MD] fc=%d act=%d cur=%d %s o5=%.0f,%.0f"):format(Isaac.GetFrameCount(), MenuManager.GetActiveMenu(),
				cur, table.concat(dbg, "; "), o5.X, o5.Y))
		end
	end)
	if not ok and not S.err then
		S.err = true
		Isaac.DebugString("[localfixes] меню (титул/файлы/главное): " .. tostring(err))
	end
end)

function S.SetEnabled(v) S.enabled = v and true or false end
-- новый экран меню из другого файла: f(o) рисует экран меню m в его кадре 480×270 от начала o
S.extra, S.fixed = {}, {}
function S.Register(m, f, fixed)
	S.extra[m] = f
	S.fixed[m] = fixed and true or nil
end
S.T = function() return T end
return S
