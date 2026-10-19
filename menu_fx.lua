-- localfixes: эффекты меню — частицы-вырезки и движение элементов (18.10, слова пользователя: «Анимируй более детально
-- менюшки чтобы персонажи чуть двигались / Чтобы картинки на титульном меню и сохранениях чуть чуть двигались / Не
-- просто простые анимации типа плавно вверх вниз а прям полноценные»; «А это партиклов немного и движение элементов»;
-- «Частицы оформляй как мух на титульном / Что то типа летающих картонных вырезок»; «Если будет нужно больше частиц
-- чтобы соответствовать характерам персонажей то делай»).
--
-- Частицы — вырезки с белой каймой из листов Meshy (art_in/meshy/particles, particles2, particles3 → menu_pack: pa.*).
-- У каждого экрана свой список частиц (координаты — в кадре экрана 480×270, рисуются от его начала o, поэтому едут
-- вместе с камерой игры). Виды: пылинки и пепел (плавают), искры (поднимаются), падающие клочки, листья и перья
-- (кружат и переворачиваются), мотыльки (пролетают, машут крыльями), мухи (жужжат вокруг точки, садятся и сидят),
-- капли (падают), «всплывающие» (сердечки, ноты), «по орбите» (огоньки, тени, вещи вокруг персонажа), подброшенные
-- (подборы из мешка), искорки (мерцают), сбои (прыгают). Частицы персонажа — по его характеру (HERO ниже).
local C = LOCALFIXES.CharSelect
if not (C and C.art) then return end
local art, ART = C.art, C.ART
local FX = {}
LOCALFIXES.MenuFX = FX

local rnd = math.random
local function rr(a, b) return a + (b - a) * rnd() end
local function pick(t) return t[rnd(#t)] end
local LISTS = {}
local function list(id)
	local l = LISTS[id]
	if not l then l = {} LISTS[id] = l end
	return l
end
local function count(l, kind)
	local n = 0
	for _, p in ipairs(l) do if p.kind == kind then n = n + 1 end end
	return n
end

-- ------------------------------------------------------------------ виды частиц: step(p) → false, когда частица ушла
local STEP = {}
STEP.mote = function(p)                 -- пылинка / пепел: плывёт, чуть кружится
	p.x = p.x + p.vx + 0.05 * math.sin(p.age * 0.02 + p.ph)
	p.y = p.y + p.vy + 0.04 * math.sin(p.age * 0.017 + p.ph * 2)
	p.rot = p.rot + p.spin
	return p.age < p.life
end
STEP.ember = function(p)                -- искра: поднимается, дрожит, мерцает, гаснет
	p.y = p.y + p.vy
	p.x = p.x + 0.25 * math.sin(p.age * 0.08 + p.ph)
	p.flick = 0.65 + 0.35 * math.sin(p.age * 0.6 + p.ph)
	p.ws = 1 - 0.5 * math.max(0, (p.age - p.life * 0.6) / (p.life * 0.4))
	return p.age < p.life
end
STEP.fall = function(p)                 -- клочок, лист, перо: качается маятником и переворачивается
	p.sw = p.sw + p.sws
	p.x = p.x0 + p.amp * math.sin(p.sw)
	p.y = p.y + p.vy * (0.6 + 0.4 * math.cos(p.sw) ^ 2)
	p.rot = 22 * math.cos(p.sw)
	local f = math.cos(p.age * p.flip + p.ph)
	p.kx = (f >= 0 and 1 or -1) * math.max(0.15, math.abs(f))
	return p.y < 300 and p.age < p.life
end
STEP.moth = function(p)                 -- мотылёк (18.10: «У тебя мотыльки очень плохо летают»; «Типа два разных
	-- изображения создают плохую иллюзию анимации»): один рисунок; крылья складываются и раскрываются сжатием по
	-- размаху, тело повёрнуто по полёту; летит рывками — порхает, резко меняет направление, кружит у света, потом улетает
	p.flapPh = p.flapPh + p.flapSp
	p.kx = 0.28 + 0.72 * math.abs(math.cos(p.flapPh))
	p.jt = p.jt - 1
	if p.jt <= 0 then                                       -- рывок крыльями: новый толчок в случайную сторону
		local a = rr(0, 6.283)
		local f = rr(0.25, 0.7)
		p.vx, p.vy = p.vx + math.cos(a) * f, p.vy + math.sin(a) * f
		p.jt = math.floor(rr(4, 14))
	end
	local tx, ty
	if p.age > p.stay then                                  -- нагулялся — улетает за край
		tx, ty = p.exitX, p.ty or p.y
	else
		p.wt = p.wt - 1
		if p.wt <= 0 or not p.tx then
			local r = rr(4, p.R)
			local a = rr(0, 6.283)
			p.tx, p.ty, p.wt = p.lx + math.cos(a) * r, p.ly + math.sin(a) * r * 0.7, math.floor(rr(20, 60))
		end
		tx, ty = p.tx, p.ty
	end
	local dx, dy = tx - p.x, ty - p.y
	local d = math.sqrt(dx * dx + dy * dy) + 1e-3
	p.vx = (p.vx + dx / d * 0.09) * 0.93
	p.vy = (p.vy + dy / d * 0.09 + 0.012 * math.sin(p.flapPh)) * 0.93
	local sp = math.sqrt(p.vx * p.vx + p.vy * p.vy)
	if sp > 1.7 then p.vx, p.vy = p.vx / sp * 1.7, p.vy / sp * 1.7 end
	p.x, p.y = p.x + p.vx, p.y + p.vy
	local head = math.deg(math.atan(p.vy, p.vx)) + 90       -- рисунок смотрит вверх: голова — по полёту
	local dr = (head - p.rot + 540) % 360 - 180
	p.rot = (p.rot + dr * 0.15) % 360
	return p.x > -50 and p.x < 530 and p.y > -50 and p.y < 330
end
STEP.fly = function(p)                  -- муха: жужжит вокруг своей точки, иногда садится и сидит
	if p.land and p.land > 0 then
		p.land = p.land - 1
		p.buzz = nil
		if p.land % 40 < 6 then p.x = p.x + (rnd() - 0.5) * 0.6 end      -- переползает
		p.rot = 0
	else
		if not p.goLand and (not p.tx or (math.abs(p.tx - p.x) + math.abs(p.ty - p.y) < 4) or rnd() < 0.01) then
			local a, r = rr(0, 6.283), rr(0.2, 1) * p.R
			p.tx, p.ty = p.ax + math.cos(a) * r, p.ay + math.sin(a) * r * 0.6
		end
		p.vx = (p.vx + (p.tx - p.x) * 0.012 + rr(-0.25, 0.25)) * 0.9
		p.vy = (p.vy + (p.ty - p.y) * 0.012 + rr(-0.25, 0.25)) * 0.9
		p.x, p.y = p.x + p.vx, p.y + p.vy
		p.buzz = (p.age % 2 == 0) and 1 or 0                    -- крылья трепещут (верх рисунка), тело на месте
		p.kx = p.vx >= 0 and 1 or -1
		p.rot = math.max(-20, math.min(20, p.vx * 8))
		if p.canLand and not p.goLand and rnd() < 0.0025 then
			local sp = p.spots and p.spots[rnd(#p.spots)]
			if sp then p.goLand, p.tx, p.ty = true, sp[1] + rr(-(sp[3] or 0), sp[3] or 0), sp[2]
			else p.land = math.floor(rr(60, 170)) end
		end
		if p.goLand and math.abs(p.tx - p.x) + math.abs(p.ty - p.y) < 3 then
			p.goLand, p.land, p.x, p.y, p.vx, p.vy = false, math.floor(rr(60, 170)), p.tx, p.ty, 0, 0
		end
	end
	return p.ttl == nil or p.ttl > 0
end
STEP.drip = function(p)                 -- капля: падает с ускорением
	p.vy = p.vy + (p.g or 0.06)
	p.x, p.y = p.x + p.vx, p.y + p.vy
	return p.age < p.life
end
STEP.rise = function(p)                 -- всплывает и тает (сердечко, нота, душа)
	p.y = p.y + p.vy
	p.x = p.x0 + (p.amp or 3) * math.sin(p.age * 0.06 + p.ph)
	p.ws = math.min(1, p.age / 12)
	p.rot = (p.wob or 6) * math.sin(p.age * 0.05 + p.ph)
	return p.age < p.life
end
STEP.twinkle = function(p)              -- искорка: вспыхивает и гаснет на месте
	p.ws = math.max(0.05, math.sin(p.age / p.life * math.pi))
	p.rot = p.rot + 2
	return p.age < p.life
end
STEP.orbit = function(p)                -- по орбите вокруг персонажа; позади него — мельче и бледнее
	p.ang = p.ang + p.sp
	local s = math.sin(p.ang)
	p.x = p.ax + p.rx * math.cos(p.ang)
	p.y = p.ay + p.ry * s + 1.5 * math.sin(p.age * 0.07 + p.ph)
	p.ws = 0.8 + 0.2 * s
	p.dim = 0.65 + 0.35 * (s * 0.5 + 0.5)
	p.rot = (p.wob or 0) * math.sin(p.age * 0.05 + p.ph)
	return p.ttl > 0
end
STEP.toss = function(p)                 -- подброшено: летит дугой и падает; монета переворачивается, кость кувыркается
	p.vy = p.vy + 0.07
	p.x, p.y = p.x + p.vx, p.y + p.vy
	if p.gy and p.y > p.gy then p.y, p.vy, p.vx, p.spin = p.gy, -p.vy * 0.3, p.vx * 0.5, p.spin * 0.4 end
	if p.coin then
		local f = math.cos(p.age * 0.35)
		p.kx = (f >= 0 and 1 or -1) * math.max(0.12, math.abs(f))
		if p.gy and p.y >= p.gy - 0.5 and math.abs(p.vy) < 0.4 then p.coin = false p.kx = 1 end
	else
		p.rot = p.rot + p.spin
	end
	return p.age < p.life
end
STEP.hop = function(p)                  -- кузнечик, лягушка: сидит на земле, потом прыгает дугой (18.10: «Партиклы тоже
	-- обоснованно ставь чтобы кузнечики прыгали / Мухи летали и т.д»)
	if p.air then
		p.vy = p.vy + 0.12
		p.x, p.y = p.x + p.vx, p.y + p.vy
		p.rot = p.vx * 10 + p.vy * 4 * p.kx
		if p.y >= p.gy then p.y, p.air, p.wait, p.rot = p.gy, false, math.floor(rr(40, 130)), 0 end
		p.ws = 1
	else
		p.wait = p.wait - 1
		p.ws = p.wait < 8 and (0.92 + 0.01 * p.wait) or 1               -- приседает перед прыжком
		if p.wait <= 0 then
			local dir = (p.x < p.ax - p.R) and 1 or ((p.x > p.ax + p.R) and -1 or (rnd() < 0.5 and -1 or 1))
			p.vx, p.vy, p.air, p.kx = dir * rr(0.5, 1.1), -rr(1.6, 2.4), true, -dir
		end
	end
	if p.ttl then p.gy = p.gyNew or p.gy end
	return p.ttl == nil or p.ttl > 0
end
STEP.spider = function(p)               -- паук: спускается на нити, висит, покачиваясь, и уползает вверх
	local cyc = p.age % p.period
	local k
	if cyc < p.period * 0.35 then k = cyc / (p.period * 0.35)
	elseif cyc < p.period * 0.7 then k = 1
	else k = 1 - (cyc - p.period * 0.7) / (p.period * 0.3) end
	k = k * k * (3 - 2 * k)
	p.y = p.y0 + p.len * k
	p.x = p.x0 + math.sin(p.age * 0.03) * 1.5 * k
	p.rot = math.sin(p.age * 0.03) * 6
	return p.age < p.life
end
STEP.smoke = function(p)                -- дымок, облачко газа, кольцо дыма: поднимается, расплывается и тает
	p.y = p.y + p.vy
	p.x = p.x + p.vx + 0.15 * math.sin(p.age * 0.04 + p.ph)
	p.ws = 0.55 + 0.9 * (p.age / p.life)
	p.rot = p.rot + p.spin
	return p.age < p.life
end
STEP.pop = function(p)                  -- значок (злость, лампочка): выскакивает, держится, сжимается
	local k = p.age / p.life
	p.ws = k < 0.15 and (k / 0.15) * 1.25 or (k < 0.25 and 1.25 - (k - 0.15) * 2.5 or (k > 0.85 and (1 - k) / 0.15 or 1))
	p.rot = (p.wob or 0) * math.sin(p.age * 0.3)
	return p.age < p.life
end
STEP.glitch = function(p)               -- сбой: прыгает рывками рядом с точкой
	if p.age % 3 == 0 then
		p.x, p.y = p.ax + rr(-p.R, p.R), p.ay + rr(-p.R, p.R) * 0.8
		p.kx = rnd() < 0.5 and -1 or 1
		p.ws = rr(0.6, 1.3)
	end
	return p.age < p.life
end

local function add(id, p)
	p.age, p.rot, p.kx, p.ws, p.a = 0, p.rot or 0, p.kx or 1, p.ws or 1, p.a or 1
	p.ph = p.ph or rr(0, 6.283)
	local l = list(id)
	l[#l + 1] = p
	return p
end
FX.add = add

local function draw(l, o)
	local i = 1
	local dt = LOCALFIXES.MenuDT or 1          -- промежуточный кадр (144 к/с): частицы стоят, только рисуются
	while i <= #l do
		local p = l[i]
		local alive = true
		if dt > 0 then
			p.age = p.age + 1
			if p.ttl then p.ttl = p.ttl - 1 end
			alive = STEP[p.kind](p)
		end
		if alive then
			local fin = math.min(1, p.age / (p.fin or 20))
			local fout = p.life and math.min(1, (p.life - p.age) / (p.fout or 30)) or 1
			if p.ttl and p.ttl < 15 then fout = math.min(fout, p.ttl / 15) end
			local al = p.a * math.max(0, math.min(fin, fout)) * (p.flick or 1)
			local d = p.dim or 1
			local c = p.tint
			if p.thread then                                       -- нить паука
				local len = p.y - p.y0
				if len > 1 then art("ma.highlight", o.X + p.x, o.Y + p.y0 + len / 2 - 2, 0.6, len,
					Color(0.12, 0.1, 0.1, 0.55 * al)) end
			end
			local col = c and Color(c[1] * d, c[2] * d, c[3] * d, al) or Color(d, d, d, al)
			-- муха трепещет крыльями: целый рисунок чуть сжимается через кадр (без полос)
			local ky = (p.flap and p.buzz == 1) and 0.9 or 1
			art(p.img, o.X + p.x, o.Y + p.y + (1 - ky) * p.w * 0.25, p.w * (p.ws or 1), nil, col, p.rot, p.kx, ky)
			i = i + 1
		else
			table.remove(l, i)
		end
	end
end

-- ------------------------------------------------------------------ готовые частицы
local MOTES = { "pa.dust", "pa.ash" }
function FX.mote(id, x, y, img)
	return add(id, { kind = "mote", img = img or pick(MOTES), x = x or rr(0, 480), y = y or rr(0, 270),
		vx = rr(-0.12, 0.12), vy = rr(-0.06, 0.04), w = rr(3, 5), life = rr(500, 900), a = rr(0.45, 0.75),
		spin = rr(-0.4, 0.4), rot = rr(0, 360), fin = 60, fout = 60 })
end
function FX.ember(id, x, y, img)
	return add(id, { kind = "ember", img = img or "pa.ember", x = x or rr(10, 470), y = y or rr(240, 280),
		vy = rr(-0.5, -0.25), w = rr(3, 4.5), life = rr(150, 260), a = 0.9, fin = 10 })
end
local FALLS = { "pa.scrap", "pa.scrap_note", "pa.leaf", "pa.feather", "pa.scrap_burnt" }
function FX.fall(id, img, x, y)
	local x0 = x or rr(20, 460)
	return add(id, { kind = "fall", img = img or pick(FALLS), x = x0, x0 = x0, y = y or -15, vy = rr(0.22, 0.38),
		amp = rr(8, 16), sw = rr(0, 6.283), sws = rr(0.025, 0.04), flip = rr(0.03, 0.06), w = rr(9, 13), life = 2400,
		a = 0.95 })
end
-- мотылёк прилетает из-за края к свету (lx, ly — точка, у которой он кружит; без неё — случайное место)
function FX.moth(id, lx, ly)
	local dir = rnd() < 0.5 and 1 or -1
	local y = rr(30, 200)
	return add(id, { kind = "moth", img = "pa.moth_open", x = dir > 0 and -30 or 510, y = y, vx = dir * 1.2, vy = 0,
		lx = lx or rr(120, 360), ly = ly or rr(40, 160), R = lx and 26 or 45, w = 13, a = 1, fin = 1,
		flapPh = rr(0, 6.283), flapSp = rr(0.55, 0.75), jt = 0, wt = 0, stay = math.floor(rr(500, 1000)),
		exitX = dir > 0 and 540 or -60, rot = dir > 0 and 90 or -90 })
end
function FX.fly(id, ax, ay, R, opts)
	opts = opts or {}
	return add(id, { kind = "fly", img = opts.img or "pa.fly_up", flap = true,
		x = ax + rr(-R, R), y = ay + rr(-R, R) * 0.5, vx = 0, vy = 0, ax = ax, ay = ay, R = R, w = opts.w or 9, a = 1,
		canLand = opts.land ~= false, ttl = opts.ttl, tint = opts.tint, spots = opts.spots })
end
-- прыгун у земли gy вокруг точки ax (в пределах R)
function FX.hop(id, img, ax, gy, R, opts)
	opts = opts or {}
	return add(id, { kind = "hop", img = img, x = ax + rr(-R, R), y = gy, gy = gy, ax = ax, R = R, w = opts.w or 7,
		wait = math.floor(rr(10, 90)), kx = rnd() < 0.5 and 1 or -1, a = 1, ttl = opts.ttl })
end
-- паук на нити: спускается от y0 на len, висит, поднимается обратно (нить — тонкая тёмная черта)
function FX.spider(id, x, y0, len)
	return add(id, { kind = "spider", img = "pa.spider", x = x, x0 = x, y = y0, y0 = y0, len = len, w = 8,
		period = math.floor(rr(700, 1000)), life = 1000, a = 1, fin = 1, fout = 1, thread = true })
end
function FX.drip(id, img, x, y, opts)
	opts = opts or {}
	return add(id, { kind = "drip", img = img or "pa.tear", x = x, y = y, vx = opts.vx or rr(-0.15, 0.15),
		vy = opts.vy or rr(0, 0.2), g = opts.g, w = opts.w or 4, life = opts.life or 70, a = 0.95, fin = 6, fout = 20,
		tint = opts.tint })
end
function FX.rise(id, img, x, y, opts)
	opts = opts or {}
	return add(id, { kind = "rise", img = img, x = x, x0 = x, y = y, vy = opts.vy or rr(-0.35, -0.2), amp = opts.amp,
		w = opts.w or rr(5, 7), life = opts.life or rr(110, 170), a = opts.a or 0.95, wob = opts.wob, tint = opts.tint })
end
function FX.twinkle(id, img, x, y, w)
	return add(id, { kind = "twinkle", img = img or "pa.sparkle", x = x, y = y, w = w or rr(4, 6), life = rr(50, 90),
		rot = rr(0, 90), fin = 1, fout = 1 })
end
function FX.toss(id, img, x, y, gy)
	return add(id, { kind = "toss", img = img, x = x, y = y, vx = rr(-0.8, 0.8), vy = rr(-2.2, -1.4), spin = rr(-6, 6),
		w = rr(5, 7), life = gy and 110 or 75, a = 1, fin = 4, fout = 25, gy = gy, coin = img == "pa.penny" or img == "pa.silvercoin" })
end
function FX.smoke(id, img, x, y, opts)
	opts = opts or {}
	return add(id, { kind = "smoke", img = img or "pa.smoke", x = x, y = y, vx = opts.vx or rr(-0.08, 0.08),
		vy = opts.vy or rr(-0.3, -0.15), w = opts.w or rr(6, 9), life = opts.life or rr(120, 180), a = opts.a or 0.8,
		spin = rr(-0.5, 0.5), rot = rr(0, 360), fin = 15, fout = 50, tint = opts.tint })
end
function FX.pop(id, img, x, y, w, wob)
	return add(id, { kind = "pop", img = img, x = x, y = y, w = w or 7, life = 70, a = 1, fin = 1, fout = 1, wob = wob })
end
function FX.glitch(id, x, y, R)
	return add(id, { kind = "glitch", img = "pa.glitch", x = x, y = y, ax = x, ay = y, R = R or 20, w = rr(4, 8),
		life = math.floor(rr(6, 14)), a = 1, fin = 1, fout = 1 })
end

-- шаг и отрисовка частиц экрана; cfg — фон экрана: dust/embers — сколько держать, fall/moth — шанс за кадр
function FX.run(id, o, cfg)
	local l = list(id)
	if cfg and (LOCALFIXES.MenuDT or 1) > 0 then
		if cfg.dust and count(l, "mote") < cfg.dust and rnd() < 0.05 then FX.mote(id, nil, nil, cfg.dustImg) end
		if cfg.embers and count(l, "ember") < cfg.embers and rnd() < 0.04 then FX.ember(id, nil, nil, cfg.emberImg) end
		if cfg.fall and rnd() < cfg.fall and count(l, "fall") < 2 then FX.fall(id, cfg.fallImg and pick(cfg.fallImg)) end
		if cfg.moth and rnd() < cfg.moth and count(l, "moth") < 1 then
			FX.moth(id, cfg.light and cfg.light[1], cfg.light and cfg.light[2])
		end
	end
	draw(l, o)
end
function FX.clear(id) LISTS[id] = {} end

-- ------------------------------------------------------------------ звук выбора
-- (18.10: «Ну и нужно какой то звук добавить при выборе пунктов меню и наводки / Сейчас все тихое если листать»):
-- наведение на другой пункт — короткий шорох (звук меню игры, если она сама его не играет в этот кадр), переход между
-- экранами — перелистывание бумаги
local sfx = SFXManager()
local SELS = {}
local function playIfQuiet(id, vol, pitch)
	if not id then return end
	pcall(function()
		if not sfx:IsPlaying(id) then sfx:Play(id, vol or 0.8, 0, false, pitch or 1) end
	end)
end
function FX.sel(id, value)
	local old = SELS[id]
	SELS[id] = value
	if old ~= nil and old ~= value then
		playIfQuiet(SoundEffect.SOUND_MENU_SCROLL, 0.75, 0.95 + math.random() * 0.1)
		return true
	end
	return false
end
function FX.page()
	playIfQuiet(SoundEffect.SOUND_PAPER_OUT or SoundEffect.SOUND_BOOK_PAGE_TURN_12, 0.6, 1)
end

-- ------------------------------------------------------------------ движение элементов
-- выбранный элемент при смене выбора вздрагивает и успокаивается (пружина); возвращает поворот в градусах
local SPRING = {}
function FX.wob(id, sel)
	local s = SPRING[id]
	if not s then s = { a = 0, v = 0, sel = sel } SPRING[id] = s end
	if sel ~= s.sel then
		s.v = s.v + (rnd() < 0.5 and -1 or 1) * 2.4
		s.sel = sel
	end
	if (LOCALFIXES.MenuDT or 1) > 0 then
		s.v = s.v * 0.86 - s.a * 0.14
		s.a = s.a + s.v
	end
	return s.a
end
-- бумажка на булавке качается вокруг булавки (px, py — булавка от центра куска, в точках меню), а не вокруг центра
function FX.pinned(name, x, y, w, h, color, angle, px, py)
	local r = math.rad(angle or 0)
	local c, s = math.cos(r), math.sin(r)
	local ox, oy = -px, -py
	local nx, ny = x + px + ox * c - oy * s, y + py + ox * s + oy * c
	return art(name, nx, ny, w, h, color, angle)
end
-- моргание: 1 — глаз открыт, к 0,1 — закрыт (раз в несколько секунд, иногда дважды)
function FX.blink(t, seed)
	local ph = (t + math.floor((seed or 0) * 97)) % 260
	local function one(c) local d = math.abs(ph - c) return d < 5 and (0.1 + 0.9 * d / 5) or 1 end
	local k = one(5)
	if (math.floor((t + (seed or 0) * 97) / 260) % 3) == 1 then k = math.min(k, one(18)) end
	return k
end

-- ------------------------------------------------------------------ частицы персонажа — по характеру
-- (docs/sources/charselect_poses.md: позы и вещи; здесь — что вокруг них летает). box: x, y — центр рисунка, w, h —
-- его размер; t — кадр. Каждая запись — функция, которая изредка добавляет частицы в список "hero".
-- «удерживаемые» частицы (орбита, рой, прыгуны) живут, пока персонаж на экране: срок обновляется каждый кадр; KEEP
-- больше времени угасания (15 кадров), иначе они всё время были бы полупрозрачными
local KEEP = 30
local function head(b) return b.x, b.y - b.h * 0.28 end
local function orbitKeep(b, imgs, n, rx, ry, sp, w, wob)
	local l = list("hero")
	local have = 0
	for _, p in ipairs(l) do
		if p.kind == "orbit" then
			have = have + 1
			p.ttl, p.ax, p.ay = KEEP, b.x, b.y - b.h * 0.05
		end
	end
	for k = have + 1, n do
		add("hero", { kind = "orbit", img = imgs[(k - 1) % #imgs + 1], ax = b.x, ay = b.y - b.h * 0.05,
			rx = (rx or 0.62) * b.w, ry = (ry or 0.12) * b.h, ang = 6.283 * k / n, sp = sp or 0.012,
			w = w or 6, ttl = KEEP, a = 0.95, wob = wob or 8, x = b.x, y = b.y })
	end
end
local function ground(b) return b.y + b.h * 0.46 end
-- мухи вьются у головы и садятся на тело и на землю у ног
local function swarmKeep(b, img, n, R, w, land)
	local l = list("hero")
	local have = 0
	local hx, hy = b.x, b.y - b.h * 0.3
	local spots = { { b.x, b.y - b.h * 0.05, b.w * 0.25 }, { b.x + b.w * 0.4, ground(b), 6 }, { b.x - b.w * 0.4, ground(b), 6 } }
	for _, p in ipairs(l) do
		if p.kind == "fly" then have = have + 1 p.ttl, p.ax, p.ay, p.spots = KEEP, hx, hy, spots end
	end
	for _ = have + 1, n do
		FX.fly("hero", hx, hy, R or b.w * 0.45, { img = img, w = w or 7, ttl = KEEP, land = land, spots = spots })
	end
end
-- прыгуны (кузнечики, лягушки) у ног
local function hopKeep(b, img, n, w)
	local l = list("hero")
	local have = 0
	for _, p in ipairs(l) do
		if p.kind == "hop" and p.img == img then have = have + 1 p.ttl, p.ax, p.gyNew = KEEP, b.x, ground(b) end
	end
	for _ = have + 1, n do FX.hop("hero", img, b.x, ground(b), b.w * 0.55, { w = w or 7, ttl = KEEP }) end
end
local function every(t, n, off) return (t + (off or 0)) % n == 0 end
local TEAR, BLOOD = "pa.tear", "pa.blood"
local HERO = {
	-- игра: обычные
	isaac = function(b, t)                                      -- плачет: слёзы
		if every(t, 46) then local x, y = head(b) FX.drip("hero", TEAR, x + rr(-5, 5), y + 3, { w = 3.5 }) end
	end,
	magdalene = function(b, t)                                  -- молится над «Ням-сердцем»: сердечки поднимаются
		if every(t, 55) then FX.rise("hero", "pa.heart", b.x + rr(-8, 8), b.y - b.h * 0.1) end
	end,
	cain = function(b, t)                                       -- подбрасывает кроличью лапку: удача — клевер и лапка
		if every(t, 70) then FX.rise("hero", "pa.clover", b.x + rr(-0.4, 0.4) * b.w, b.y, { w = 5, wob = 12 }) end
		if every(t, 170) then FX.toss("hero", "pa.rabbitfoot", b.x + 8, b.y - b.h * 0.2, ground(b)) end
	end,
	judas = function(b, t)                                      -- крутит серебряник
		if every(t, 90) then FX.toss("hero", "pa.silvercoin", b.x + 10, b.y - b.h * 0.1, ground(b)) end
	end,
	bluebaby = function(b) swarmKeep(b, nil, 2, nil, 7) end,   -- рядом какашка, вьются мухи и садятся
	eve = function(b, t)                                        -- мёртвая птица: чёрные перья
		if every(t, 90) then FX.fall("hero", "pa.feather_black", b.x + rr(-0.5, 0.5) * b.w, b.y - b.h * 0.65) end
	end,
	samson = function(b, t)                                     -- в боевой стойке кричит: знак злости, пот
		if every(t, 80) then local x, y = head(b) FX.pop("hero", "pa.anger", x + rr(8, 14) * (rnd() < 0.5 and -1 or 1), y - 6, 7, 6) end
		if every(t, 45, 20) then local x, y = head(b) FX.toss("hero", "pa.sweat", x, y - 4) end
	end,
	azazel = function(b)                                        -- демон с крыльями летучей мыши: летучие мыши
		swarmKeep(b, "pa.bat", 2, nil, 7, false)
	end,
	lazarus = function(b, t)                                    -- воскрес: душа поднимается, пыль от савана
		if every(t, 80) then FX.rise("hero", "pa.soul", b.x + rr(-10, 10), b.y, { w = 7, vy = -0.25, a = 0.75 }) end
		if every(t, 50) then FX.smoke("hero", "pa.dust", b.x + rr(-0.4, 0.4) * b.w, b.y + b.h * 0.35, { w = 5, a = 0.5 }) end
	end,
	eden = function(b)                                          -- вокруг парят случайные вещи
		orbitKeep(b, { "pa.pill", "pa.penny", "pa.key", "pa.bone", "pa.bomb" }, 5, 0.66, 0.14, 0.009, 6, 20)
	end,
	thelost = function(b, t)                                    -- призрак: огоньки-души и белые перья
		orbitKeep(b, { "pa.wisp" }, 2, 0.6, 0.12, 0.014, 6, 6)
		if every(t, 110) then FX.fall("hero", "pa.feather", b.x + rr(-0.5, 0.5) * b.w, b.y - b.h * 0.6) end
	end,
	lilith = function(b) orbitKeep(b, { "pa.shadow" }, 2, 0.6, 0.12, 0.011, 7, 5) end,   -- демонята-тени
	keeper = function(b, t)                                     -- жадный: монеты
		if every(t, 70) then FX.toss("hero", "pa.penny", b.x + rr(-6, 6), b.y - b.h * 0.15, ground(b)) end
	end,
	apollyon = function(b) hopKeep(b, "pa.locust", 2, 8) end,  -- Аваддон: саранча прыгает у ног
	theforgotten = function(b, t)                               -- кости и голубая душа над ним
		orbitKeep(b, { "pa.soul" }, 1, 0.3, 0.06, 0.02, 8, 6)
		if every(t, 140) then FX.toss("hero", "pa.bone", b.x, b.y, ground(b)) end
	end,
	bethany = function(b) orbitKeep(b, { "pa.wisp" }, 3, 0.6, 0.13, 0.013, 6, 6) end,   -- огоньки-души
	jacob = function(b, t)                                      -- Исав злится, Иаков прячется
		if every(t, 90) then FX.pop("hero", "pa.anger", b.x + b.w * 0.25, b.y - b.h * 0.35, 7, 6) end
	end,
	-- игра: порченые
	isaac_b = function(b) orbitKeep(b, { "pa.pill", "pa.key", "pa.penny", "pa.bomb" }, 4, 0.6, 0.12, 0.008, 6, 10) end,
	magdalene_b = function(b, t)                                -- смертельные объятия: сердца
		if every(t, 40) then FX.rise("hero", t % 80 == 0 and "pa.blackheart" or "pa.heart", b.x + rr(-12, 12), b.y) end
	end,
	cain_b = function(b, t)                                     -- роется в мешке: высыпаются подборы
		if every(t, 45) then FX.toss("hero", pick({ "pa.penny", "pa.key", "pa.bomb", "pa.pill", "pa.soulheart" }), b.x, b.y, ground(b)) end
	end,
	judas_b = function(b) orbitKeep(b, { "pa.shadow" }, 3, 0.65, 0.14, 0.02, 7, 8) end,   -- мчится тенью
	bluebaby_b = function(b, t)
		swarmKeep(b, nil, 3, nil, 7)
		if every(t, 150) then FX.toss("hero", "pa.poop", b.x, b.y - b.h * 0.4, ground(b)) end
	end,
	eve_b = function(b) hopKeep(b, "pa.clot", 3, 7) end,       -- вокруг ползают сгустки крови
	samson_b = function(b, t)                                   -- берсерк: злость и пот
		if every(t, 50) then local x, y = head(b) FX.pop("hero", "pa.anger", x + rr(-14, 14), y - 8, 8, 8) end
		if every(t, 30, 10) then local x, y = head(b) FX.toss("hero", "pa.sweat", x, y - 4) end
	end,
	azazel_b = function(b, t)                                   -- сгорбился и кашляет: дымок, мыши
		if every(t, 60) then local x, y = head(b) FX.smoke("hero", "pa.smoke", x + 6, y + 6, { w = 5, a = 0.6 }) end
		swarmKeep(b, "pa.bat", 1, nil, 6, false)
	end,
	lazarus_b = function(b, t)                                  -- половина живая, половина мёртвая
		if every(t, 60) then FX.rise("hero", "pa.soul", b.x + rr(-12, 12), b.y, { w = 6, a = 0.7 }) end
		if every(t, 30) then FX.ember("hero", b.x + rr(-0.4, 0.4) * b.w, b.y + b.h * 0.4, "pa.ash") end
	end,
	eden_b = function(b, t)                                     -- глючит: сбои вокруг тела
		if every(t, 7) then FX.glitch("hero", b.x + rr(-0.4, 0.4) * b.w, b.y + rr(-0.45, 0.4) * b.h, 6) end
	end,
	thelost_b = function(b, t)                                  -- держит святую карту: огонёк и искорки
		orbitKeep(b, { "pa.wisp" }, 1, 0.5, 0.1, 0.015, 6, 6)
		if every(t, 35) then FX.twinkle("hero", "pa.sparkle", b.x + rr(-0.3, 0.3) * b.w, b.y + rr(-0.2, 0.2) * b.h) end
	end,
	lilith_b = function(b) orbitKeep(b, { "pa.shadow" }, 3, 0.62, 0.13, 0.013, 8, 6) end,
	keeper_b = function(b, t)                                   -- считает монеты
		if every(t, 50) then FX.toss("hero", "pa.penny", b.x + rr(-6, 6), b.y + b.h * 0.1, ground(b)) end
	end,
	apollyon_b = function(b)                                    -- рой красной саранчи Бездны летает, одна — прыгает
		swarmKeep(b, "pa.redfly_up", 4, nil, 7, false)
		hopKeep(b, "pa.locust", 1, 7)
	end,
	theforgotten_b = function(b) orbitKeep(b, { "pa.soul" }, 1, 0.45, 0.1, 0.012, 9, 6) end,
	bethany_b = function(b) orbitKeep(b, { "pa.flame_purple" }, 3, 0.6, 0.13, 0.013, 6, 6) end,
	jacob_b = function(b, t)                                    -- за ним — Тёмный Исав с огненными волосами
		orbitKeep(b, { "pa.shadow" }, 1, 0.45, 0.18, 0.01, 10, 4)
		if every(t, 20) then FX.ember("hero", b.x + rr(-0.4, 0.4) * b.w, b.y + b.h * 0.3) end
	end,
	-- Epiphany: потускневшие
	isaac_c = function(b, t)                                    -- плоть гниёт: мухи
		swarmKeep(b, nil, 2, nil, 6)
	end,
	magdalene_c = function(b, t)                                -- бешено бьётся сердце
		if every(t, 54) then FX.rise("hero", "pa.heart", b.x + rr(-6, 6), b.y - b.h * 0.1, { w = 7 }) end
	end,
	cain_c = function(b, t)                                     -- замахивается мешком: высыпаются монеты
		if every(t, 80) then FX.toss("hero", "pa.penny", b.x + b.w * 0.2, b.y - b.h * 0.1, ground(b)) end
	end,
	judas_c = function(b, t)                                    -- падает в свет: голубые сердца
		if every(t, 45) then FX.rise("hero", "pa.soulheart", b.x + rr(-10, 10), b.y, { a = 0.8 }) end
	end,
	bluebaby_c = function(b) swarmKeep(b, nil, 3, nil, 6) end,
	samson_c = function(b, t)
		if every(t, 60) then local x, y = head(b) FX.pop("hero", "pa.anger", x + rr(-14, 14), y - 8, 8, 8) end
	end,
	eden_c = function(b, t)
		if every(t, 10) then FX.glitch("hero", b.x + rr(-0.4, 0.4) * b.w, b.y + rr(-0.2, 0.45) * b.h, 6) end
	end,
	thelost_c = function(b) orbitKeep(b, { "pa.shadow" }, 2, 0.55, 0.12, 0.012, 7, 6) end,
	keeper_c = function(b, t)                                   -- золотая статуя: искорки
		if every(t, 18) then FX.twinkle("hero", "pa.sparkle", b.x + rr(-0.45, 0.45) * b.w, b.y + rr(-0.45, 0.4) * b.h) end
	end,
	-- Fiend Folio
	fiend = function(b, t)                                      -- у ног горит бомба: искры фитиля
		if every(t, 14) then FX.ember("hero", b.x + b.w * 0.3 + rr(-3, 3), b.y + b.h * 0.3) end
	end,
	fiend_b = function(b) orbitKeep(b, { "pa.shadow" }, 3, 0.62, 0.13, 0.012, 6, 6) end,   -- ползут тени-бесы
	classic_fiend = function(b, t)                              -- чёрное пламя вокруг
		if every(t, 12) then FX.ember("hero", b.x + rr(-0.45, 0.45) * b.w, b.y + b.h * 0.4, "pa.blackflame") end
	end,
	golem = function(b, t)                                      -- любуется самоцветом
		if every(t, 40) then FX.twinkle("hero", "pa.sparkle", b.x + rr(-0.3, 0.3) * b.w, b.y + rr(-0.1, 0.3) * b.h) end
		if every(t, 160) then FX.toss("hero", "pa.gem", b.x, b.y, ground(b)) end
	end,
	golem_b = function(b) orbitKeep(b, { "pa.wisp" }, 1, 0.4, 0.08, 0.012, 6, 4) end,   -- голубой шар
	friend = function(b, t)                                     -- целится из револьвера: дымок и гильзы
		if every(t, 120) then FX.smoke("hero", "pa.smoke", b.x + b.w * 0.4, b.y - b.h * 0.15, { w = 5 }) end
		if every(t, 120, 4) then FX.toss("hero", "pa.casing", b.x + b.w * 0.25, b.y - b.h * 0.1, ground(b)) end
	end,
	friend_b = function(b, t)                                   -- два пистолета
		if every(t, 60) then FX.smoke("hero", "pa.smoke", b.x + rr(-0.4, 0.4) * b.w, b.y - b.h * 0.1, { w = 5 }) end
		if every(t, 60, 4) then FX.toss("hero", "pa.casing", b.x, b.y - b.h * 0.1, ground(b)) end
	end,
	inaba = function(b, t)                                      -- застенчивая: искорка-сердечко изредка
		if every(t, 120) then FX.rise("hero", "pa.heart", b.x + rr(-8, 8), b.y - b.h * 0.2, { w = 4, a = 0.8 }) end
	end,
	inaba_b = function(b, t)                                    -- красный огонёк
		if every(t, 30) then FX.ember("hero", b.x + rr(-6, 6), b.y) end
	end,
	leah = function(b, t)
		if every(t, 70) then FX.rise("hero", "pa.heart", b.x + rr(-8, 8), b.y) end
	end,
	leah_b = function(b, t)                                     -- треснувшее сердце
		if every(t, 60) then FX.rise("hero", "pa.blackheart", b.x + rr(-8, 8), b.y) end
	end,
	peter = function(b, t)                                      -- золотой ключ блестит
		if every(t, 35) then FX.twinkle("hero", "pa.sparkle", b.x + rr(-0.3, 0.3) * b.w, b.y + rr(-0.3, 0.2) * b.h) end
	end,
	peter_b = function(b, t)                                    -- висит вниз головой: падают ключи и пыль
		if every(t, 140) then FX.toss("hero", "pa.key", b.x, b.y + b.h * 0.3, ground(b) + 6) end
	end,
	miriam = function(b, t)                                     -- танцует с бубном: ноты
		if every(t, 40) then FX.rise("hero", "pa.note", b.x + rr(-0.4, 0.4) * b.w, b.y - b.h * 0.2, { w = 6, wob = 15 }) end
	end,
	miriam_b = function(b) orbitKeep(b, { "pa.shadow", "pa.ash" }, 4, 0.6, 0.14, 0.025, 6, 10) end,   -- водоворот
	moses = function(b, t)                                      -- волны расступаются: брызги
		if every(t, 40) then FX.toss("hero", "pa.splash", b.x + rr(-0.5, 0.5) * b.w, b.y + b.h * 0.3) end
	end,
	moses_b = function(b)                                       -- казни: лягушки прыгают, мухи летают
		swarmKeep(b, nil, 2, nil, 6)
		hopKeep(b, "pa.frog", 2, 8)
	end,
	robot = function(b, t)                                      -- искрит антенна
		if every(t, 50) or every(t, 53) then local x, y = head(b) FX.ember("hero", x + rr(-4, 4), y - b.h * 0.12) end
	end,
	robot_b = function(b, t)                                    -- искрящие провода, дым
		if every(t, 16) then FX.ember("hero", b.x + rr(-0.3, 0.3) * b.w, b.y + rr(-0.1, 0.2) * b.h) end
		if every(t, 45) then FX.smoke("hero", "pa.smoke", b.x + rr(-10, 10), b.y - b.h * 0.2, { w = 6, a = 0.6 }) end
	end,
	joseph = function(b, t)                                     -- разноцветный плащ: радужные звёздочки
		if every(t, 30) then FX.twinkle("hero", "pa.rainbowstar", b.x + rr(-0.5, 0.5) * b.w, b.y + rr(-0.4, 0.3) * b.h) end
	end,
	joseph_b = function(b, t)                                   -- на дне тёмной ямы: пыль
		if every(t, 50) then FX.mote("hero", b.x + rr(-0.4, 0.4) * b.w, b.y + rr(-0.3, 0.3) * b.h) end
	end,
	slippy = function(b, t)                                     -- скользит по луже, за ним облачко газа
		if every(t, 40) then FX.smoke("hero", "pa.gas", b.x - b.w * 0.35, b.y + b.h * 0.25, { vx = -0.15, w = 6 }) end
	end,
	china = function(b, t)                                      -- держит треснувшие куски: отлетают осколки
		if every(t, 100) then FX.toss("hero", "pa.shard", b.x + rr(-0.3, 0.3) * b.w, b.y - b.h * 0.1, ground(b)) end
	end,
	craig = function(b, t)                                      -- вокруг светятся лампочки
		if every(t, 50) then FX.pop("hero", "pa.bulb", b.x + rr(-0.5, 0.5) * b.w, ground(b) - 2, 6) end
	end,
	image = function(b) orbitKeep(b, { "pa.wisp", "pa.soul", "pa.sparkle" }, 3, 0.6, 0.12, 0.012, 5, 6) end,   -- питомцы
	fend = function(b, t)                                       -- яростно моет пол: брызги и злость
		if every(t, 30) then FX.toss("hero", "pa.splash", b.x + rr(-0.4, 0.4) * b.w, b.y + b.h * 0.4) end
		if every(t, 110) then local x, y = head(b) FX.pop("hero", "pa.anger", x + 10, y - 6, 6, 6) end
	end,
	frond = function(b, t)                                      -- потеет от страха жёлтым потом
		if every(t, 25) then local x, y = head(b) FX.toss("hero", "pa.sweat", x + rr(-6, 6), y) end
	end,
	fient = function(b, t)                                      -- лежит с сигарой и пускает кольца дыма
		if every(t, 70) then local x, y = head(b) FX.smoke("hero", "pa.smokering", x + b.w * 0.25, y, { vy = -0.25, w = 6 }) end
	end,
	mi = function(b) hopKeep(b, "pa.paperminion", 3, 6) end,   -- за ней маршируют бумажные миньоны
	freezer = function(b, t)                                    -- сбои и ледяные осколки
		if every(t, 14) then FX.glitch("hero", b.x + rr(-0.45, 0.45) * b.w, b.y + rr(-0.4, 0.4) * b.h, 5) end
		if every(t, 60) then FX.toss("hero", "pa.ice", b.x + rr(-6, 6), b.y - b.h * 0.1, ground(b)) end
	end,
	peat = function(b, t)                                       -- лезет в драку: злость, пот
		if every(t, 70) then local x, y = head(b) FX.pop("hero", "pa.anger", x + 12, y - 8, 7, 6) end
		if every(t, 40, 15) then local x, y = head(b) FX.toss("hero", "pa.sweat", x - 6, y) end
	end,
}
local lastHero
-- частицы персонажа на экране выбора: key — ключ рисунка, x, y — центр рисунка, w, h — размер
function FX.hero(key, x, y, w, h, o, t)
	if key ~= lastHero then
		local l = list("hero")
		for i = #l, 1, -1 do if l[i].kind == "orbit" or l[i].kind == "fly" then table.remove(l, i) end end
		lastHero = key
	end
	local f = key and HERO[key]
	if f and (LOCALFIXES.MenuDT or 1) > 0 then f({ x = x - o.X, y = y - o.Y, w = w, h = h }, t) end
	FX.run("hero", o)
end
